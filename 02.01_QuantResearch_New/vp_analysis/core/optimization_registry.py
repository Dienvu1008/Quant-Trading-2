"""Optimization registry for parameter tuning (SL/TP, sizing).

Distinct from FDR pools:
  - No statistical correction. This is optimization, not hypothesis testing.
  - The SL/TP grid is pre-registered in the contract.
  - v3 Fix #6: when multiple (sl, tp) combos share the same utility,
    a tiebreaker is applied. Default: prefer larger SL, then larger TP,
    to avoid noise-driven preference for small SL values.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import dataclass, field
from typing import Callable, Optional

from .exceptions import OptimizationError
from .research_contract import ResearchContract


# ─── Frozen result type ─────────────────────────────────────────

@dataclass(frozen=True)
class FrozenOptimizationResult:
    """Result of a parameter optimization run for one rule."""
    rule_id: str
    parameter_name: str          # "sl_tp" | "sizing"
    selected: tuple              # tuple of (name, value) pairs
    evaluated_all: tuple         # tuple of dicts (params + utility)
    utility_name: str
    tiebreaker_applied: bool = False
    frozen_at: str = field(
        default_factory=lambda: dt.datetime.utcnow().isoformat() + "Z"
    )

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "parameter_name": self.parameter_name,
            "selected": dict(self.selected),
            "evaluated_all": list(self.evaluated_all),
            "utility_name": self.utility_name,
            "tiebreaker_applied": self.tiebreaker_applied,
            "frozen_at": self.frozen_at,
        }


# ─── Tiebreaker ─────────────────────────────────────────────────

def _parse_tiebreaker(tiebreaker: list[str]) -> list[tuple[str, bool]]:
    """Parse ["sl_atr DESC", "tp_atr DESC"] → [(field, reverse), ...].

    reverse=True means prefer larger values (DESC), False means prefer
    smaller (ASC).
    """
    parsed = []
    for spec in tiebreaker:
        parts = spec.strip().split()
        field_name = parts[0]
        direction = parts[1].upper() if len(parts) > 1 else "ASC"
        parsed.append((field_name, direction == "DESC"))
    return parsed


def _apply_tiebreaker(
    candidates: list[dict],
    tiebreaker_specs: list[tuple[str, bool]],
) -> dict:
    """Select the best candidate from those sharing the highest utility.

    candidates: list of param dicts (each has "sl", "tp", "utility").
    tiebreaker_specs: [(field, reverse), ...] — sorted left to right.
    """
    if not candidates:
        raise OptimizationError("No candidates to apply tiebreaker to")
    if len(candidates) == 1:
        return candidates[0]

    best = candidates[:]
    for field_name, reverse in tiebreaker_specs:
        if not best:
            break
        # Map field aliases: "sl_atr" → "sl", "tp_atr" → "tp"
        key = field_name.replace("_atr", "")
        vals = [c.get(key, 0.0) for c in best]
        target = max(vals) if reverse else min(vals)
        best = [c for c in best if abs(c.get(key, 0.0) - target) < 1e-12]

    return best[0] if best else candidates[0]


# ─── Registry ───────────────────────────────────────────────────

class OptimizationRegistry:
    """Pre-registered grid search. No FDR correction."""

    def __init__(self, contract: ResearchContract):
        self._contract = contract
        self._sl_candidates = list(contract.optimization_budget.sl_candidates)
        self._tp_candidates = list(contract.optimization_budget.tp_candidates)
        self._utility_name = contract.optimization_budget.utility_function
        self._tiebreaker_raw = list(contract.optimization_budget.tiebreaker or [])
        self._tiebreaker = _parse_tiebreaker(self._tiebreaker_raw)
        self._results: dict[str, FrozenOptimizationResult] = {}
        self._completed_rules: set[str] = set()

    # ─── Introspection ──────────────────────────────────────────

    @property
    def sl_candidates(self) -> tuple:
        return tuple(self._sl_candidates)

    @property
    def tp_candidates(self) -> tuple:
        return tuple(self._tp_candidates)

    @property
    def utility_name(self) -> str:
        return self._utility_name

    @property
    def tiebreaker(self) -> list[str]:
        return list(self._tiebreaker_raw)

    # ─── SL/TP optimization ─────────────────────────────────────

    def optimize_sl_tp(
        self,
        rule_id: str,
        evaluate_fn: Callable[[dict], float],
    ) -> FrozenOptimizationResult:
        """Enumerate all (sl, tp) combos, pick the best by utility.

        v3 Fix #6: when multiple combos share the highest utility, the
        tiebreaker from the contract is applied (default: sl↑, tp↑).

        evaluate_fn(params: dict) -> float (higher = better).
        Caller is responsible for evaluating on development data only.
        """
        if not rule_id:
            raise OptimizationError("rule_id is required")
        if rule_id in self._completed_rules:
            raise OptimizationError(
                f"Rule {rule_id!r} already optimized; cannot re-run"
            )
        if not self._sl_candidates:
            raise OptimizationError("sl_candidates is empty")
        if not self._tp_candidates:
            raise OptimizationError("tp_candidates is empty")

        evaluated: list[dict] = []
        best_utility = float("-inf")

        for sl in self._sl_candidates:
            for tp in self._tp_candidates:
                params = {"sl": float(sl), "tp": float(tp)}
                utility = float(evaluate_fn(params))
                if utility != utility:  # NaN guard
                    raise OptimizationError(
                        f"evaluate_fn returned NaN for params {params}"
                    )
                evaluated.append({**params, "utility": utility})
                if utility > best_utility:
                    best_utility = utility

        if not evaluated:
            raise OptimizationError(
                f"No valid combination evaluated for rule {rule_id!r}"
            )

        # v3 Fix #6: collect all combos at the peak utility, then tiebreak
        top = [e for e in evaluated if abs(e["utility"] - best_utility) < 1e-12]
        tiebreaker_applied = len(top) > 1
        best = _apply_tiebreaker(top, self._tiebreaker)

        selected = (("sl", best["sl"]), ("tp", best["tp"]))
        result = FrozenOptimizationResult(
            rule_id=rule_id,
            parameter_name="sl_tp",
            selected=selected,
            evaluated_all=tuple(evaluated),
            utility_name=self._utility_name,
            tiebreaker_applied=tiebreaker_applied,
        )
        self._results[rule_id] = result
        self._completed_rules.add(rule_id)
        return result

    # ─── Sizing optimization ────────────────────────────────────

    def optimize_sizing(
        self,
        rule_id: str,
        candidate_multipliers: list[float],
        evaluate_fn: Callable[[dict], float],
    ) -> FrozenOptimizationResult:
        """Optimize lot multiplier among a caller-supplied candidate list."""
        if not rule_id:
            raise OptimizationError("rule_id is required")
        if rule_id in self._completed_rules:
            raise OptimizationError(
                f"Rule {rule_id!r} already optimized; cannot re-run"
            )
        if not candidate_multipliers:
            raise OptimizationError("candidate_multipliers is empty")

        evaluated: list[dict] = []
        best_utility = float("-inf")
        best_mult: Optional[float] = None

        for mult in candidate_multipliers:
            params = {"lot_mult": float(mult)}
            utility = float(evaluate_fn(params))
            if utility != utility:
                raise OptimizationError(f"evaluate_fn returned NaN for {params}")
            evaluated.append({**params, "utility": utility})
            if utility > best_utility:
                best_utility = utility
                best_mult = float(mult)

        if best_mult is None:
            raise OptimizationError(
                f"No valid sizing candidate for rule {rule_id!r}"
            )

        result = FrozenOptimizationResult(
            rule_id=rule_id,
            parameter_name="sizing",
            selected=(("lot_mult", best_mult),),
            evaluated_all=tuple(evaluated),
            utility_name=self._utility_name,
        )
        self._results[rule_id] = result
        self._completed_rules.add(rule_id)
        return result

    # ─── Lookup ─────────────────────────────────────────────────

    def get_result(self, rule_id: str) -> FrozenOptimizationResult:
        if rule_id not in self._results:
            raise OptimizationError(
                f"No optimization result for rule {rule_id!r}"
            )
        return self._results[rule_id]

    def all_results(self) -> dict[str, FrozenOptimizationResult]:
        return dict(self._results)
