"""Layer 6 — Multiple Testing + Rule Freeze.

Takes L4 and L5 discovery outputs, applies FDR correction to two
isolated pools, re-checks economic criteria against the contract's
production_criteria, and freezes surviving hard gates as FrozenRule
objects.

Design:
  - Hard gate pool:  candidates from L4, p-value = t-test p on fold EVs.
  - Soft gate pool:  candidates from L5, p-value = permutation p (dev).

  Conservative mode (default ON):
      The FDR pool size is padded to the total number of hypotheses
      that L4 attempted (feature × group combos), with padding entries
      at p=1.0. This prevents the FDR correction from becoming
      artificially lenient when many weak candidates were filtered by
      economic screens in L4.

  Economic re-check:
      After FDR, every surviving candidate is re-checked against the
      contract's production_criteria (min_ev, min_pf, min_wr). This is
      a final, contract-level gate that is independent of L4's internal
      config.

  Soft gates are NOT frozen as FrozenRule objects — they are tilts,
  not gates. They are exported as validated candidates for downstream
  sizing / tilt logic.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import pandas as pd

from ..core.fdr_registry import FDRPoolRegistry, PoolResult
from ..core.frozen_types import FrozenRule


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class MultipleTestingConfig:
    # FDR pool names (must match contract.fdr_pools)
    hard_gate_pool: str = "hard_gate"
    soft_gate_pool: str = "soft_gate"

    # Conservative mode: pad pool to n_features_searched
    conservative_fdr: bool = True

    # Economic re-check overrides (None → use contract.production_criteria)
    override_min_ev: Optional[float] = None
    override_min_pf: Optional[float] = None
    override_min_wr: Optional[float] = None

    # Whether to re-verify ci_low > 0 for hard gates
    require_ci_low_positive: bool = True


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class ValidatedCandidate:
    """A candidate that passed FDR + economic re-check."""
    label: str
    pool_name: str
    p_value: float
    p_adjusted: float
    candidate_dict: dict       # serialized candidate for provenance

    def to_dict(self) -> dict:
        return {
            "label": self.label,
            "pool_name": self.pool_name,
            "p_value": round(self.p_value, 6),
            "p_adjusted": round(self.p_adjusted, 6),
            **self.candidate_dict,
        }


@dataclass(frozen=True)
class LayerSixResult:
    experiment_id: str
    research_contract_hash: str

    hard_gate_fdr: PoolResult
    soft_gate_fdr: PoolResult

    validated_hard_gates: tuple       # of ValidatedCandidate
    validated_soft_gates: tuple       # of ValidatedCandidate
    frozen_rules: tuple               # of FrozenRule

    n_hard_gate_inputs: int
    n_soft_gate_inputs: int
    n_hard_gate_validated: int
    n_soft_gate_validated: int
    n_frozen_rules: int

    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "experiment_id": self.experiment_id,
            "research_contract_hash": self.research_contract_hash,
            "ran_at": self.ran_at,
            "n_hard_gate_inputs": self.n_hard_gate_inputs,
            "n_soft_gate_inputs": self.n_soft_gate_inputs,
            "n_hard_gate_validated": self.n_hard_gate_validated,
            "n_soft_gate_validated": self.n_soft_gate_validated,
            "n_frozen_rules": self.n_frozen_rules,
            "hard_gate_pool_size": len(self.hard_gate_fdr.labels),
            "soft_gate_pool_size": len(self.soft_gate_fdr.labels),
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    l4_result,               # LayerFourResult
    l5_result,               # LayerFiveResult
    contract,
    experiment_id: str,
    output_dir: Optional[Path] = None,
    config: Optional[MultipleTestingConfig] = None,
) -> LayerSixResult:
    """Execute Layer 6.

    Preconditions:
      - contract is frozen
      - l4_result.candidates were derived from dev data only
      - l5_result.candidates were derived from dev data only
    """
    cfg = config or MultipleTestingConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if not experiment_id:
        raise ValueError("L6: experiment_id is required")

    warnings: list[str] = []

    hard_candidates = list(l4_result.candidates)
    soft_candidates = list(l5_result.candidates)

    # ─── 1. Build labels ────────────────────────────────────────
    hard_labeled = _label_hard_candidates(hard_candidates)
    soft_labeled = _label_soft_candidates(soft_candidates)

    # ─── 2. Populate FDR pools ──────────────────────────────────
    fdr = FDRPoolRegistry(contract)

    # Hard gate pool — pad to n_features_searched if conservative
    hard_pool_target = len(hard_labeled)
    if cfg.conservative_fdr and l4_result.n_features_searched > hard_pool_target:
        hard_pool_target = l4_result.n_features_searched
    _populate_pool(fdr, cfg.hard_gate_pool, hard_labeled, hard_pool_target, warnings)

    # Soft gate pool — pad to n_directions if conservative
    soft_pool_target = len(soft_labeled)
    n_soft_searched = len(l5_result.directions)
    if cfg.conservative_fdr and n_soft_searched > soft_pool_target:
        soft_pool_target = n_soft_searched
    _populate_pool(fdr, cfg.soft_gate_pool, soft_labeled, soft_pool_target, warnings)

    # ─── 3. Apply FDR ───────────────────────────────────────────
    hard_fdr_result = fdr.correct(cfg.hard_gate_pool)
    soft_fdr_result = fdr.correct(cfg.soft_gate_pool)

    # ─── 4. Economic re-check thresholds ────────────────────────
    min_ev = (
        cfg.override_min_ev
        if cfg.override_min_ev is not None
        else contract.production_criteria.min_ev
    )
    min_pf = (
        cfg.override_min_pf
        if cfg.override_min_pf is not None
        else contract.production_criteria.min_pf
    )
    min_wr = (
        cfg.override_min_wr
        if cfg.override_min_wr is not None
        else contract.production_criteria.min_wr
    )

    # ─── 5. Filter validated candidates ─────────────────────────
    validated_hard = _filter_hard_gates(
        hard_labeled, hard_fdr_result, min_ev, min_pf, min_wr,
        cfg.require_ci_low_positive,
    )
    validated_soft = _filter_soft_gates(
        soft_labeled, soft_fdr_result, min_ev, min_wr,
    )

    # ─── 6. Construct FrozenRules for hard gates ─────────────────
    frozen_rules = _build_frozen_rules(validated_hard, contract, experiment_id)

    result = LayerSixResult(
        experiment_id=experiment_id,
        research_contract_hash=contract.contract_hash,
        hard_gate_fdr=hard_fdr_result,
        soft_gate_fdr=soft_fdr_result,
        validated_hard_gates=tuple(validated_hard),
        validated_soft_gates=tuple(validated_soft),
        frozen_rules=tuple(frozen_rules),
        n_hard_gate_inputs=len(hard_candidates),
        n_soft_gate_inputs=len(soft_candidates),
        n_hard_gate_validated=len(validated_hard),
        n_soft_gate_validated=len(validated_soft),
        n_frozen_rules=len(frozen_rules),
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Labeling ────────────────────────────────────────────────────

def _label_hard_candidates(candidates) -> list[tuple[str, float, object]]:
    """Return (label, p_value, candidate) list."""
    return [
        (f"{c.symbol}|{c.setup}|{c.feature}", float(c.ttest_pvalue), c)
        for c in candidates
    ]


def _label_soft_candidates(candidates) -> list[tuple[str, float, object]]:
    return [
        (f"{c.symbol}|{c.setup}|{c.feature}", float(c.perm_pvalue), c)
        for c in candidates
    ]


# ─── Pool population ─────────────────────────────────────────────

def _populate_pool(
    fdr: FDRPoolRegistry,
    pool_name: str,
    labeled: list[tuple[str, float, object]],
    target_size: int,
    warnings: list[str],
) -> None:
    """Register real candidates then pad with p=1.0 placeholders to
    reach target_size (conservative FDR mode)."""
    registered = 0
    for label, p_value, _ in labeled:
        try:
            fdr.register(pool_name, label, p_value)
            registered += 1
        except Exception as e:
            warnings.append(
                f"Failed to register {label!r} in pool {pool_name!r}: {e}"
            )

    n_pad = target_size - registered
    for i in range(max(0, n_pad)):
        try:
            fdr.register(pool_name, f"_pad_{i:04d}", 1.0)
        except Exception as e:
            warnings.append(
                f"Failed to register placeholder in pool {pool_name!r}: {e}"
            )
            break


# ─── Filtering ───────────────────────────────────────────────────

def _filter_hard_gates(
    labeled: list[tuple[str, float, object]],
    fdr_result: PoolResult,
    min_ev: float,
    min_pf: float,
    min_wr: float,
    require_ci_low_positive: bool,
) -> list[ValidatedCandidate]:
    """Return candidates that pass FDR + economic re-check."""
    label_to_cand = {lab: cand for lab, _, cand in labeled}
    result_map = fdr_result.as_dict()

    validated: list[ValidatedCandidate] = []
    for label, info in result_map.items():
        if not info["reject"]:
            continue
        if label.startswith("_pad_"):
            continue
        cand = label_to_cand.get(label)
        if cand is None:
            continue

        # Economic re-check
        if cand.mean_ev < min_ev:
            continue
        if cand.mean_pf < min_pf:
            continue
        if cand.mean_wr < min_wr:
            continue
        if require_ci_low_positive and cand.ci_low <= 0:
            continue

        validated.append(ValidatedCandidate(
            label=label,
            pool_name=fdr_result.pool_name,
            p_value=info["p_value"],
            p_adjusted=info["p_adjusted"],
            candidate_dict=cand.to_dict(),
        ))
    return validated


def _filter_soft_gates(
    labeled: list[tuple[str, float, object]],
    fdr_result: PoolResult,
    min_ev: float,
    min_wr: float,
) -> list[ValidatedCandidate]:
    """Soft gates pass FDR + positive lift + ev_top >= min_ev + wr_top >= min_wr."""
    label_to_cand = {lab: cand for lab, _, cand in labeled}
    result_map = fdr_result.as_dict()

    validated: list[ValidatedCandidate] = []
    for label, info in result_map.items():
        if not info["reject"]:
            continue
        if label.startswith("_pad_"):
            continue
        cand = label_to_cand.get(label)
        if cand is None:
            continue

        if cand.ev_lift <= 0:
            continue
        if cand.ev_top < min_ev:
            continue
        if cand.wr_top < min_wr:
            continue

        validated.append(ValidatedCandidate(
            label=label,
            pool_name=fdr_result.pool_name,
            p_value=info["p_value"],
            p_adjusted=info["p_adjusted"],
            candidate_dict=cand.to_dict(),
        ))
    return validated


# ─── FrozenRule construction ─────────────────────────────────────

def _build_frozen_rules(
    validated_hard: list[ValidatedCandidate],
    contract,
    experiment_id: str,
) -> list[FrozenRule]:
    """Construct FrozenRule objects with sequential unique rule_ids."""
    rules: list[FrozenRule] = []
    for i, vc in enumerate(validated_hard, 1):
        cd = vc.candidate_dict
        rules.append(FrozenRule(
            rule_id=f"R-{i:05d}",
            experiment_id=experiment_id,
            research_contract_hash=contract.contract_hash,
            symbol=cd["symbol"],
            setup=cd["setup"],
            gate_type=cd["gate_type"],
            direction=cd["direction"],
            features=(cd["feature"],),
            lower_bound=cd.get("lower"),
            upper_bound=cd.get("upper"),
            test_ev_mean=float(cd["mean_ev"]),
            test_wr_mean=float(cd["mean_wr"]),
            test_pf_mean=float(cd["mean_pf"]),
            test_n_avg=int(cd["mean_n"]),
            pvalue=float(cd["ttest_pvalue"]),
            pvalue_fdr=vc.p_adjusted,
            fdr_significant=True,
            fold_consistency=float(cd["fold_consistency"]),
            n_folds=int(cd["n_folds"]),
        ))
    return rules


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerSixResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    # FDR summary
    with (output_dir / "fdr_summary.json").open("w", encoding="utf-8") as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)

    def _pool_to_rows(fdr_res: PoolResult) -> list[dict]:
        return [
            {
                "label": lab,
                "p_value": float(p),
                "reject": bool(rej),
                "p_adjusted": float(padj),
            }
            for lab, p, rej, padj in zip(
                fdr_res.labels, fdr_res.p_values,
                fdr_res.reject, fdr_res.p_adjusted,
            )
        ]

    # Hard gate FDR table
    if result.hard_gate_fdr.labels:
        pd.DataFrame(_pool_to_rows(result.hard_gate_fdr)).to_csv(
            output_dir / "fdr_hard_gate.csv", index=False,
        )

    # Soft gate FDR table — always write even if empty for downstream
    soft_rows = _pool_to_rows(result.soft_gate_fdr)
    pd.DataFrame(soft_rows if soft_rows else []).to_csv(
        output_dir / "fdr_soft_gate.csv", index=False,
    )

    # Frozen rules JSON
    if result.frozen_rules:
        with (output_dir / "frozen_rules.json").open("w", encoding="utf-8") as fh:
            json.dump(
                [r.to_dict() for r in result.frozen_rules],
                fh, indent=2, default=str,
            )

    # Validated hard gates CSV
    if result.validated_hard_gates:
        pd.DataFrame(
            [vc.to_dict() for vc in result.validated_hard_gates]
        ).to_csv(output_dir / "validated_hard_gates.csv", index=False)

    # Validated soft gates CSV
    if result.validated_soft_gates:
        pd.DataFrame(
            [vc.to_dict() for vc in result.validated_soft_gates]
        ).to_csv(output_dir / "validated_soft_gates.csv", index=False)
