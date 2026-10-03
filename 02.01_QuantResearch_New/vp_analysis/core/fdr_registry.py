"""FDR pool registry for hypothesis testing.

v3: four isolated pools (hard_gate, soft_gate, regime_block, bad_entry).

Design:
  - Pools are configured from ResearchContract (4 pools required).
  - Each pool has a capacity cap (max_hypotheses) and its own alpha.
  - Hypotheses are registered with a caller-supplied label (unique within
    the pool). Registration has no return value.
  - Conservative mode (default ON): the FDR denominator is padded to
    n_total_hypotheses (frozen at L1 in run_meta.json). This means the
    pool is padded with p=1.0 entries for hypotheses attempted but
    filtered out before FDR, keeping the correction conservative.
  - Correction is called exactly once per pool; pool is sealed afterward.
  - Pools are fully isolated: correcting one pool cannot affect another.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

import numpy as np

from .exceptions import PoolCorrectedError, PoolRegistrationError
from .research_contract import ResearchContract
from .stats_helpers import correct_multiple_testing


@dataclass
class _PoolState:
    name: str
    alpha: float
    max_hypotheses: int
    labels: list[str] = field(default_factory=list)
    p_values: list[float] = field(default_factory=list)
    corrected: bool = False
    reject_mask: Optional[np.ndarray] = None
    p_adjusted: Optional[np.ndarray] = None


@dataclass(frozen=True)
class PoolResult:
    """Immutable result of FDR correction for a single pool."""
    pool_name: str
    labels: tuple
    p_values: tuple
    reject: tuple           # booleans aligned with labels
    p_adjusted: tuple
    alpha: float
    n_total_used: int       # denominator actually used (after padding)

    def as_dict(self) -> dict[str, dict]:
        """Map label → {p_value, reject, p_adjusted}."""
        return {
            lab: {
                "p_value": float(self.p_values[i]),
                "reject": bool(self.reject[i]),
                "p_adjusted": float(self.p_adjusted[i]),
            }
            for i, lab in enumerate(self.labels)
        }


class FDRPoolRegistry:
    """Isolated FDR pools, capacity-enforced, corrected once.

    v3: four pools (hard_gate, soft_gate, regime_block, bad_entry).
    Conservative padding via n_total (from run_meta.json, frozen at L1).
    """

    def __init__(self, contract: ResearchContract):
        self._contract = contract
        self._method = contract.multiple_testing_method
        self._pools: dict[str, _PoolState] = {}
        for name, pool_cfg in contract.fdr_pools.items():
            self._pools[name] = _PoolState(
                name=name,
                alpha=pool_cfg.alpha,
                max_hypotheses=pool_cfg.max_hypotheses,
            )

    # ─── Introspection ──────────────────────────────────────────

    @property
    def pool_names(self) -> list[str]:
        return list(self._pools.keys())

    def pool_size(self, pool_name: str) -> int:
        return len(self._get_pool(pool_name).p_values)

    def is_corrected(self, pool_name: str) -> bool:
        return self._get_pool(pool_name).corrected

    def _get_pool(self, name: str) -> _PoolState:
        if name not in self._pools:
            raise PoolRegistrationError(
                f"Unknown pool {name!r}. Available: {sorted(self._pools)}"
            )
        return self._pools[name]

    # ─── Registration ───────────────────────────────────────────

    def register(self, pool_name: str, label: str, p_value: float) -> None:
        pool = self._get_pool(pool_name)
        if pool.corrected:
            raise PoolCorrectedError(
                f"Pool {pool_name!r} already corrected; cannot register more"
            )
        if not label:
            raise PoolRegistrationError("label cannot be empty")
        if label in pool.labels:
            raise PoolRegistrationError(
                f"Duplicate label {label!r} in pool {pool_name!r}"
            )
        if not (0.0 <= p_value <= 1.0):
            raise PoolRegistrationError(
                f"p_value must be in [0, 1], got {p_value}"
            )
        if len(pool.p_values) >= pool.max_hypotheses:
            raise PoolRegistrationError(
                f"Pool {pool_name!r} at capacity ({pool.max_hypotheses}). "
                f"Raise max_hypotheses in the contract (requires new experiment)."
            )
        pool.labels.append(label)
        pool.p_values.append(float(p_value))

    def register_many(
        self,
        pool_name: str,
        items: list[tuple[str, float]],
    ) -> None:
        """Register multiple (label, p_value) pairs atomically."""
        pool = self._get_pool(pool_name)
        if pool.corrected:
            raise PoolCorrectedError(f"Pool {pool_name!r} already corrected")

        # Pre-validate everything before mutating
        new_labels = [lab for lab, _ in items]
        if len(set(new_labels)) != len(new_labels):
            raise PoolRegistrationError("Duplicate labels in batch")
        for lab in new_labels:
            if lab in pool.labels:
                raise PoolRegistrationError(
                    f"Duplicate label {lab!r} in pool {pool_name!r}"
                )
        if len(pool.p_values) + len(items) > pool.max_hypotheses:
            raise PoolRegistrationError(
                f"Batch would exceed capacity ({pool.max_hypotheses}) "
                f"for pool {pool_name!r}"
            )
        for _, p in items:
            if not (0.0 <= p <= 1.0):
                raise PoolRegistrationError(
                    f"p_value must be in [0, 1], got {p}"
                )

        for lab, p in items:
            pool.labels.append(lab)
            pool.p_values.append(float(p))

    # ─── Correction ─────────────────────────────────────────────

    def correct(
        self,
        pool_name: str,
        n_total: Optional[int] = None,
    ) -> PoolResult:
        """Apply FDR to a pool, seal it, return immutable PoolResult.

        n_total (conservative padding):
            If provided and > len(registered p-values), the pool is padded
            with p=1.0 entries to make the denominator equal n_total. This
            keeps the correction conservative when many hypotheses were
            attempted but screened out before FDR.
            The value should come from run_meta["n_total_hypotheses"][pool_name]
            (frozen at L1). If None, no padding is applied.

        Raises PoolCorrectedError if called a second time.
        """
        pool = self._get_pool(pool_name)
        if pool.corrected:
            raise PoolCorrectedError(
                f"Pool {pool_name!r} already corrected"
            )

        registered_p = list(pool.p_values)
        registered_labels = list(pool.labels)

        # Conservative padding
        if n_total is not None and n_total > len(registered_p):
            n_pad = n_total - len(registered_p)
            padded_p = registered_p + [1.0] * n_pad
            padded_labels = registered_labels + [
                f"__pad_{i}" for i in range(n_pad)
            ]
        else:
            padded_p = registered_p
            padded_labels = registered_labels

        if padded_p:
            reject_all, p_adj_all = correct_multiple_testing(
                padded_p, alpha=pool.alpha, method=self._method
            )
        else:
            reject_all = np.zeros(0, dtype=bool)
            p_adj_all = np.zeros(0, dtype=float)

        # Keep only the registered (non-padding) results
        n_reg = len(registered_p)
        reject_reg = reject_all[:n_reg]
        p_adj_reg = p_adj_all[:n_reg]

        pool.reject_mask = reject_reg
        pool.p_adjusted = p_adj_reg
        pool.corrected = True

        return PoolResult(
            pool_name=pool_name,
            labels=tuple(registered_labels),
            p_values=tuple(registered_p),
            reject=tuple(bool(x) for x in reject_reg),
            p_adjusted=tuple(float(x) for x in p_adj_reg),
            alpha=pool.alpha,
            n_total_used=len(padded_p),
        )

    def get_result(self, pool_name: str) -> PoolResult:
        """Return the result of an already-corrected pool."""
        pool = self._get_pool(pool_name)
        if not pool.corrected:
            raise PoolCorrectedError(f"Pool {pool_name!r} not yet corrected")
        return PoolResult(
            pool_name=pool_name,
            labels=tuple(pool.labels),
            p_values=tuple(pool.p_values),
            reject=tuple(bool(x) for x in pool.reject_mask),
            p_adjusted=tuple(float(x) for x in pool.p_adjusted),
            alpha=pool.alpha,
            n_total_used=len(pool.p_values),
        )
