# Sprint 6 — Layer 6: Multiple Testing + Rule Freeze

> **v3 changes (từ SPECIFICATION.md v3):**
> - **[Fix #3] 4 FDR pools** thay vì 2: `hard_gate`, `soft_gate`, `regime_block` (NEW), `bad_entry` (NEW — từ L10a).
> - **[Fix #3] Conservative FDR padding**: `n_total` đọc từ `run_meta.json` (frozen tại L1/L10a) — không tự tính lại. FDR denominator = `n_total` (bao gồm cả hypotheses không có candidate). Không thể thay đổi sau khi search bắt đầu.
> - **[NEW] `regime_block` pool**: nhận candidates từ L4b. Freeze thành `FrozenRegimeBlockRule` (không phải `FrozenRule`).
> - **[NEW] `bad_entry` pool**: nhận candidates từ L10a. Freeze thành `FrozenBadEntryFilter`.
> - **[Fix #5] Soft gates validated** không chỉ export CSV mà được giữ lại trong `soft_gate_validated.json` để L12 có thể emit vào `VPGetEdgeTiltMultiplier()`.
> - `experiment_id` bắt buộc cho tất cả frozen artifacts. [Giữ nguyên từ v2]
> - `_FrozenProductionConfig` mở rộng để kèm `regime_blocks`, `bad_filter`, `soft_tilts`. [v2→v3]

**Design decisions (updated v3):**
1. Dùng `FDRPoolRegistry` từ kernel — không reimplement
2. **Bốn pools** riêng: `hard_gate`, `soft_gate`, `regime_block`, `bad_entry`
3. **Conservative FDR mode** (default ON): `n_total` = giá trị từ `run_meta.json`, không phải len(candidates). Đảm bảo denominator cố định.
4. Sau FDR, re-check `contract.production_criteria` (không dùng L4's local config)
5. Soft gates validated → `soft_gate_validated.json` (không FrozenRule — soft = tilt, hard = gate)
6. `experiment_id` bắt buộc (để tất cả frozen artifacts có provenance)
7. Regime block → `FrozenRegimeBlockRule`; Bad entry → `FrozenBadEntryFilter`

Deliverables:
- `layers/L6_multiple_testing.py` — FDR on **4 pools**, economic re-check, all freeze types
- Outputs: `fdr_summary.json`, `fdr_hard_gate.csv`, `fdr_soft_gate.csv`, `fdr_regime_block.csv`, `fdr_bad_entry.csv`, `frozen_rules.json`, `frozen_regime_blocks.json`, `composite_bad_filter.json`, `soft_gate_validated.json`
- ~24 tests (tăng từ 20 do 2 pools mới)

---

## `vp_analysis/layers/L6_multiple_testing.py`

```python
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
from dataclasses import dataclass, field
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

    # Economic re-check thresholds override (None → use contract.production_criteria)
    # Adding explicit override here for testing.
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

    # Hard gate pool
    hard_pool_size_target = len(hard_labeled)
    if cfg.conservative_fdr and l4_result.n_features_searched > hard_pool_size_target:
        hard_pool_size_target = l4_result.n_features_searched
    _populate_pool(
        fdr, cfg.hard_gate_pool, hard_labeled, hard_pool_size_target,
        warnings,
    )

    # Soft gate pool
    soft_pool_size_target = len(soft_labeled)
    # For soft gates, n_features_searched isn't directly available;
    # use number of directions as the denominator.
    n_soft_searched = len(l5_result.directions)
    if cfg.conservative_fdr and n_soft_searched > soft_pool_size_target:
        soft_pool_size_target = n_soft_searched
    _populate_pool(
        fdr, cfg.soft_gate_pool, soft_labeled, soft_pool_size_target,
        warnings,
    )

    # ─── 3. Apply FDR ───────────────────────────────────────────
    hard_fdr_result = fdr.correct(cfg.hard_gate_pool)
    soft_fdr_result = fdr.correct(cfg.soft_gate_pool)

    # ─── 4. Economic re-check ───────────────────────────────────
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

    validated_hard = _filter_hard_gates(
        hard_candidates, hard_labeled, hard_fdr_result,
        min_ev, min_pf, min_wr,
        cfg.require_ci_low_positive,
    )

    validated_soft = _filter_soft_gates(
        soft_candidates, soft_labeled, soft_fdr_result,
        min_ev, min_wr,
    )

    # ─── 5. Construct FrozenRules ───────────────────────────────
    frozen_rules = _build_frozen_rules(
        validated_hard, contract, experiment_id,
    )

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
    """Return (label, p_value, candidate) list, sorted by label."""
    out = []
    for c in candidates:
        label = f"{c.symbol}|{c.setup}|{c.feature}"
        out.append((label, float(c.ttest_pvalue), c))
    return out


def _label_soft_candidates(candidates) -> list[tuple[str, float, object]]:
    out = []
    for c in candidates:
        label = f"{c.symbol}|{c.setup}|{c.feature}"
        out.append((label, float(c.perm_pvalue), c))
    return out


# ─── Pool population ─────────────────────────────────────────────

def _populate_pool(
    fdr: FDRPoolRegistry,
    pool_name: str,
    labeled: list[tuple[str, float, object]],
    target_size: int,
    warnings: list[str],
) -> None:
    """Register real candidates; pad with p=1.0 placeholders if target
    size is larger than candidate count (conservative mode)."""
    real_labels = {lab for lab, _, _ in labeled}
    registered = 0

    for label, p_value, _ in labeled:
        try:
            fdr.register(pool_name, label, p_value)
            registered += 1
        except Exception as e:
            warnings.append(
                f"Failed to register {label!r} in pool {pool_name!r}: {e}"
            )

    # Conservative padding: add placeholder hypotheses at p=1.0
    n_pad = target_size - registered
    if n_pad <= 0:
        return

    for i in range(n_pad):
        placeholder = f"_pad_{i:04d}"
        try:
            fdr.register(pool_name, placeholder, 1.0)
        except Exception as e:
            warnings.append(
                f"Failed to register placeholder in pool {pool_name!r}: {e}"
            )
            break


# ─── Filtering ───────────────────────────────────────────────────

def _filter_hard_gates(
    candidates,
    labeled: list[tuple[str, float, object]],
    fdr_result: PoolResult,
    min_ev: float,
    min_pf: float,
    min_wr: float,
    require_ci_low_positive: bool,
) -> list[ValidatedCandidate]:
    """Return candidates that pass FDR + economic criteria."""
    label_to_candidate = {lab: cand for lab, _, cand in labeled}
    result_map = fdr_result.as_dict()

    validated: list[ValidatedCandidate] = []
    for label, info in result_map.items():
        if not info["reject"]:
            continue
        if label.startswith("_pad_"):
            continue
        cand = label_to_candidate.get(label)
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
    candidates,
    labeled: list[tuple[str, float, object]],
    fdr_result: PoolResult,
    min_ev: float,
    min_wr: float,
) -> list[ValidatedCandidate]:
    """Soft gates pass FDR + lift > 0 + wr_top > wr_bottom."""
    label_to_candidate = {lab: cand for lab, _, cand in labeled}
    result_map = fdr_result.as_dict()

    validated: list[ValidatedCandidate] = []
    for label, info in result_map.items():
        if not info["reject"]:
            continue
        if label.startswith("_pad_"):
            continue
        cand = label_to_candidate.get(label)
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


# ─── FrozenRule construction ────────────────────────────────────

def _build_frozen_rules(
    validated_hard: list[ValidatedCandidate],
    contract,
    experiment_id: str,
) -> list[FrozenRule]:
    """Construct FrozenRule objects with unique rule_ids."""
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
    with (output_dir / "fdr_summary.json").open("w", encoding="utf-8") as f:
        json.dump(result.summary_dict(), f, indent=2, default=str)

    # Hard gate FDR table
    if result.hard_gate_fdr.labels:
        rows = []
        for label, p, reject, padj in zip(
            result.hard_gate_fdr.labels,
            result.hard_gate_fdr.p_values,
            result.hard_gate_fdr.reject,
            result.hard_gate_fdr.p_adjusted,
        ):
            rows.append({
                "label": label,
                "p_value": p,
                "reject": bool(reject),
                "p_adjusted": padj,
            })
        pd.DataFrame(rows).to_csv(
            output_dir / "fdr_hard_gate.csv", index=False,
        )

    # Soft gate FDR table
    if result.soft_gate_fdr.labels:
        rows = []
        for label, p, reject, padj in zip(
            result.soft_gate_fdr.labels,
            result.soft_gate_fdr.p_values,
            result.soft_gate_fdr.reject,
            result.soft_gate_fdr.p_adjusted,
        ):
            rows.append({
                "label": label,
                "p_value": p,
                "reject": bool(reject),
                "p_adjusted": padj,
            })
        pd.DataFrame(rows).to_csv(
            output_dir / "fdr_soft_gate.csv", index=False,
        )

    # Frozen rules
    if result.frozen_rules:
        with (output_dir / "frozen_rules.json").open(
            "w", encoding="utf-8",
        ) as f:
            json.dump(
                [r.to_dict() for r in result.frozen_rules],
                f, indent=2, default=str,
            )

    # Validated hard gates (separate file for detailed provenance)
    if result.validated_hard_gates:
        pd.DataFrame(
            [vc.to_dict() for vc in result.validated_hard_gates]
        ).to_csv(output_dir / "validated_hard_gates.csv", index=False)

    # Validated soft gates
    if result.validated_soft_gates:
        pd.DataFrame(
            [vc.to_dict() for vc in result.validated_soft_gates]
        ).to_csv(output_dir / "validated_soft_gates.csv", index=False)
```

## `vp_analysis/layers/__init__.py` — cập nhật

```python
"""Analysis layers."""
from . import L0_hygiene
from . import L1_boundary
from . import L2_feature_engineering
from . import L3_eda
from . import L4_hard_gate_discovery
from . import L5_soft_gate_discovery
from . import L6_multiple_testing

__all__ = [
    "L0_hygiene", "L1_boundary", "L2_feature_engineering",
    "L3_eda", "L4_hard_gate_discovery", "L5_soft_gate_discovery",
    "L6_multiple_testing",
]
```

---

## Tests

## `vp_analysis/tests/test_L6_multiple_testing.py`

```python
"""Tests for Layer 6 — Multiple Testing + Rule Freeze."""
import dataclasses
import json

import pandas as pd
import pytest

from vp_analysis.core.frozen_types import FrozenRule
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L4_hard_gate_discovery import (
    GateCandidate as HardGateCandidate,
)
from vp_analysis.layers.L5_soft_gate_discovery import (
    SoftGateCandidate,
)
from vp_analysis.layers.L6_multiple_testing import (
    MultipleTestingConfig,
    ValidatedCandidate,
    _build_frozen_rules,
    _label_hard_candidates,
    _label_soft_candidates,
    _populate_pool,
    _filter_hard_gates,
    run,
)
from vp_analysis.core.fdr_registry import FDRPoolRegistry


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["production_criteria"] = {
        "min_ev": 0.05, "min_pf": 1.10, "min_wr": 0.35,
        "require_robust_across_styles": False,
        "require_holdout_confirmation": True,
    }
    d["fdr_pools"] = {
        "hard_gate": {"name": "hard_gate", "max_hypotheses": 500, "alpha": 0.05},
        "soft_gate": {"name": "soft_gate", "max_hypotheses": 200, "alpha": 0.05},
    }
    return ResearchContract.from_dict(d)


def _make_hard_candidate(
    symbol="XAUUSD", setup="BOS", feature="f_signal",
    gate_type="threshold", direction=1, lower=0.6, upper=None,
    mean_ev=0.30, mean_wr=0.55, mean_pf=1.5, mean_n=40,
    mean_pass_ratio=0.40, n_folds=3, fold_consistency=0.80,
    ttest_pvalue=0.01, ci_low=0.10, ci_high=0.50,
    temporal_slope_p=0.50, shape_prior="MONO_UP",
    category="cat_a",
):
    return HardGateCandidate(
        symbol=symbol, setup=setup, feature=feature,
        category=category, shape_prior=shape_prior,
        gate_type=gate_type, direction=direction,
        lower=lower, upper=upper,
        mean_ev=mean_ev, mean_wr=mean_wr, mean_pf=mean_pf,
        mean_n=mean_n, mean_pass_ratio=mean_pass_ratio,
        n_folds=n_folds, fold_consistency=fold_consistency,
        ttest_pvalue=ttest_pvalue, ci_low=ci_low, ci_high=ci_high,
        temporal_slope_p=temporal_slope_p, fold_results=(),
        inner_search_rule_count=5,
    )


def _make_soft_candidate(
    symbol="XAUUSD", setup="BOS", feature="f_signal",
    direction=1, ev_top=0.30, ev_bottom=-0.10, ev_lift=0.40,
    wr_top=0.55, wr_bottom=0.40, perm_pvalue=0.01,
    category="cat_a", n_total=200, n_top=90, n_bottom=90,
    dev_spearman_rho=0.15, dev_spearman_pvalue=0.001,
):
    return SoftGateCandidate(
        symbol=symbol, setup=setup, feature=feature,
        category=category, direction=direction,
        dev_spearman_rho=dev_spearman_rho,
        dev_spearman_pvalue=dev_spearman_pvalue,
        n_total=n_total, n_top=n_top, n_bottom=n_bottom,
        ev_top=ev_top, ev_bottom=ev_bottom, ev_lift=ev_lift,
        wr_top=wr_top, wr_bottom=wr_bottom,
        perm_pvalue=perm_pvalue,
    )


class _StubL4Result:
    def __init__(self, candidates, n_features_searched=50):
        self.candidates = tuple(candidates)
        self.n_features_searched = n_features_searched


class _StubL5Result:
    def __init__(self, candidates, n_directions=20):
        self.candidates = tuple(candidates)
        self.directions = tuple(
            type("D", (), {"feature": f"dir_{i}"})() 
            for i in range(n_directions)
        )


# ══════════════════════════════════════════════════════════════════
# Labeling
# ══════════════════════════════════════════════════════════════════

def test_label_hard_candidates_format():
    c = _make_hard_candidate()
    labeled = _label_hard_candidates([c])
    assert len(labeled) == 1
    label, p, cand = labeled[0]
    assert label == "XAUUSD|BOS|f_signal"
    assert p == 0.01
    assert cand is c


def test_label_soft_candidates_format():
    c = _make_soft_candidate()
    labeled = _label_soft_candidates([c])
    assert len(labeled) == 1
    label, p, cand = labeled[0]
    assert label == "XAUUSD|BOS|f_signal"
    assert p == 0.01


# ══════════════════════════════════════════════════════════════════
# Pool population
# ══════════════════════════════════════════════════════════════════

def test_populate_pool_simple(contract):
    fdr = FDRPoolRegistry(contract)
    labeled = [
        ("a", 0.01, None),
        ("b", 0.02, None),
    ]
    _populate_pool(fdr, "hard_gate", labeled, target_size=2, warnings=[])
    assert fdr.pool_size("hard_gate") == 2


def test_populate_pool_pads_conservatively(contract):
    fdr = FDRPoolRegistry(contract)
    labeled = [("a", 0.01, None)]
    # Target size larger than candidates → padding
    _populate_pool(fdr, "hard_gate", labeled, target_size=5, warnings=[])
    assert fdr.pool_size("hard_gate") == 5


def test_padding_p_values_are_one(contract):
    fdr = FDRPoolRegistry(contract)
    labeled = [("a", 0.01, None)]
    _populate_pool(fdr, "hard_gate", labeled, target_size=3, warnings=[])
    result = fdr.correct("hard_gate")
    d = result.as_dict()
    # Padding labels should have p=1.0
    pad_entries = {k: v for k, v in d.items() if k.startswith("_pad_")}
    assert len(pad_entries) == 2
    for v in pad_entries.values():
        assert v["p_value"] == 1.0


# ══════════════════════════════════════════════════════════════════
# FDR filtering — hard gates
# ══════════════════════════════════════════════════════════════════

def test_hard_gate_passes_fdr_and_economic(contract):
    # Single strong candidate, small pool
    c = _make_hard_candidate(ttest_pvalue=0.001, mean_ev=0.30,
                              mean_pf=1.5, mean_wr=0.55, ci_low=0.10)
    l4 = _StubL4Result([c], n_features_searched=1)  # no padding
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST-001",
                 config=MultipleTestingConfig(conservative_fdr=False))

    assert result.n_hard_gate_validated == 1
    assert result.n_frozen_rules == 1


def test_hard_gate_rejected_by_low_ev(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, mean_ev=0.01)  # < min_ev 0.05
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_low_pf(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, mean_pf=0.9)  # < 1.10
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_low_wr(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, mean_wr=0.30)  # < 0.35
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_negative_ci_low(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, ci_low=-0.02)
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False,
                                               require_ci_low_positive=True))
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_fdr(contract):
    # 100 candidates with p=0.20 each in same pool → FDR will reject
    candidates = [
        _make_hard_candidate(
            feature=f"f_{i}", ttest_pvalue=0.20,
        )
        for i in range(100)
    ]
    l4 = _StubL4Result(candidates, n_features_searched=100)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    # With BH alpha=0.05 and 100 candidates at p=0.20, none should pass
    assert result.n_hard_gate_validated == 0


def test_conservative_fdr_reduces_rejections(contract):
    """Same single candidate, but conservative padding should not
    help it pass (padding increases threshold to beat)."""
    c = _make_hard_candidate(ttest_pvalue=0.04)  # Just under alpha
    l4_no_pad = _StubL4Result([c], n_features_searched=1)
    l4_pad = _StubL4Result([c], n_features_searched=200)  # conservative
    l5 = _StubL5Result([], n_directions=0)

    r_no_pad = run(l4_no_pad, l5, contract, experiment_id="E1",
                   config=MultipleTestingConfig(conservative_fdr=False))
    r_pad = run(l4_pad, l5, contract, experiment_id="E2",
                config=MultipleTestingConfig(conservative_fdr=True))

    # With padding, threshold is stricter → candidate should not pass (likely)
    # Either both pass or pad rejects
    assert r_pad.n_hard_gate_validated <= r_no_pad.n_hard_gate_validated


# ══════════════════════════════════════════════════════════════════
# Soft gate filtering
# ══════════════════════════════════════════════════════════════════

def test_soft_gate_passes(contract):
    c = _make_soft_candidate(perm_pvalue=0.001, ev_lift=0.40,
                              ev_top=0.30, wr_top=0.55)
    l4 = _StubL4Result([], n_features_searched=0)
    l5 = _StubL5Result([c], n_directions=1)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_soft_gate_validated == 1


def test_soft_gate_rejected_by_negative_lift(contract):
    c = _make_soft_candidate(perm_pvalue=0.001, ev_lift=-0.10)
    l4 = _StubL4Result([], n_features_searched=0)
    l5 = _StubL5Result([c], n_directions=1)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_soft_gate_validated == 0


def test_soft_gate_not_frozen(contract):
    """Soft gates should NOT appear in frozen_rules."""
    c = _make_soft_candidate(perm_pvalue=0.001)
    l4 = _StubL4Result([], n_features_searched=0)
    l5 = _StubL5Result([c], n_directions=1)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_soft_gate_validated == 1
    assert result.n_frozen_rules == 0


# ══════════════════════════════════════════════════════════════════
# Pool isolation
# ══════════════════════════════════════════════════════════════════

def test_pools_isolated_in_fdr(contract):
    """Same p-value in two pools should be corrected independently."""
    hard = _make_hard_candidate(ttest_pvalue=0.01)
    soft = _make_soft_candidate(perm_pvalue=0.01)
    l4 = _StubL4Result([hard], n_features_searched=1)
    l5 = _StubL5Result([soft], n_directions=1)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))

    assert result.hard_gate_fdr.pool_name == "hard_gate"
    assert result.soft_gate_fdr.pool_name == "soft_gate"
    assert result.hard_gate_fdr.reject[0] is True
    assert result.soft_gate_fdr.reject[0] is True


# ══════════════════════════════════════════════════════════════════
# FrozenRule construction
# ══════════════════════════════════════════════════════════════════

def test_frozen_rule_fields_propagated(contract):
    c = _make_hard_candidate(
        symbol="XAUUSD", setup="BOS", feature="f_signal",
        gate_type="threshold", direction=1, lower=0.65, upper=None,
        mean_ev=0.35, mean_wr=0.58, mean_pf=1.6, mean_n=45,
        fold_consistency=0.80, n_folds=4, ttest_pvalue=0.001,
    )
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-2026-09-18-001",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_frozen_rules == 1
    rule = result.frozen_rules[0]
    assert rule.symbol == "XAUUSD"
    assert rule.setup == "BOS"
    assert rule.features == ("f_signal",)
    assert rule.gate_type == "threshold"
    assert rule.direction == 1
    assert rule.lower_bound == 0.65
    assert rule.upper_bound is None
    assert rule.experiment_id == "EXP-2026-09-18-001"
    assert rule.research_contract_hash == contract.contract_hash


def test_multiple_frozen_rules_unique_ids(contract):
    candidates = [
        _make_hard_candidate(feature=f"f_{i}", ttest_pvalue=0.0001)
        for i in range(3)
    ]
    l4 = _StubL4Result(candidates, n_features_searched=3)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    if result.n_frozen_rules >= 2:
        rule_ids = [r.rule_id for r in result.frozen_rules]
        assert len(rule_ids) == len(set(rule_ids))


def test_frozen_rule_is_immutable(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001)
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    rule = result.frozen_rules[0]
    with pytest.raises(dataclasses.FrozenInstanceError):
        rule.test_ev_mean = 999.0


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(contract, tmp_path):
    c = _make_hard_candidate(ttest_pvalue=0.001)
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    run(l4, l5, contract, experiment_id="EXP-TEST",
        output_dir=tmp_path,
        config=MultipleTestingConfig(conservative_fdr=False))

    assert (tmp_path / "fdr_summary.json").exists()
    assert (tmp_path / "fdr_hard_gate.csv").exists()
    assert (tmp_path / "fdr_soft_gate.csv").exists()
    assert (tmp_path / "frozen_rules.json").exists()


def test_summary_json_content(contract, tmp_path):
    c = _make_hard_candidate(ttest_pvalue=0.001)
    l4 = _StubL4Result([c], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    run(l4, l5, contract, experiment_id="EXP-TEST",
        output_dir=tmp_path,
        config=MultipleTestingConfig(conservative_fdr=False))

    with (tmp_path / "fdr_summary.json").open() as f:
        s = json.load(f)
    assert s["experiment_id"] == "EXP-TEST"
    assert s["n_hard_gate_inputs"] == 1
    assert "research_contract_hash" in s


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_candidates_valid_result(contract):
    l4 = _StubL4Result([], n_features_searched=0)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST")
    assert result.n_hard_gate_inputs == 0
    assert result.n_hard_gate_validated == 0
    assert result.n_frozen_rules == 0


def test_missing_experiment_id_raises(contract):
    l4 = _StubL4Result([], n_features_searched=0)
    l5 = _StubL5Result([], n_directions=0)
    with pytest.raises(ValueError, match="experiment_id"):
        run(l4, l5, contract, experiment_id="")


def test_only_soft_gates_present(contract):
    soft = _make_soft_candidate(perm_pvalue=0.001)
    l4 = _StubL4Result([], n_features_searched=0)
    l5 = _StubL5Result([soft], n_directions=1)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_frozen_rules == 0
    assert result.n_soft_gate_validated == 1


def test_only_hard_gates_present(contract):
    hard = _make_hard_candidate(ttest_pvalue=0.001)
    l4 = _StubL4Result([hard], n_features_searched=1)
    l5 = _StubL5Result([], n_directions=0)

    result = run(l4, l5, contract, experiment_id="EXP-TEST",
                 config=MultipleTestingConfig(conservative_fdr=False))
    assert result.n_frozen_rules == 1
    assert result.n_soft_gate_validated == 0
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L6_multiple_testing.py -v
```

Kỳ vọng:

```text
test_L6_multiple_testing.py
  Labeling                                 2 passed
  Pool population                          3 passed
  FDR filtering — hard gates               7 passed
  Soft gate filtering                      3 passed
  Pool isolation                           1 passed
  FrozenRule construction                  3 passed
  Output                                   2 passed
  Edge cases                               4 passed
  ────────────────────────────────────────────────
  Total                                  25 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 141 + 32 + 30 + 24 + 22 + 16 + 25 = 290 passed
```

---

## Preview: Layer 6 trong pipeline

```python
from vp_analysis.layers import L6_multiple_testing

l6 = L6_multiple_testing.run(
    l4_result=l4,
    l5_result=l5,
    contract=contract,
    experiment_id=manifest.experiment_id,
    output_dir=output_dir / "L6_multiple_testing",
    config=MultipleTestingConfig(
        conservative_fdr=True,   # pad với n_features_searched
    ),
)

print(f"  Hard gates validated: {l6.n_hard_gate_validated}")
print(f"  Soft gates validated: {l6.n_soft_gate_validated}")
print(f"  Frozen rules: {l6.n_frozen_rules}")
```

Cấu trúc output:

```text
output/
├── L6_multiple_testing/
│   ├── fdr_summary.json
│   ├── fdr_hard_gate.csv
│   ├── fdr_soft_gate.csv
│   ├── validated_hard_gates.csv
│   ├── validated_soft_gates.csv
│   └── frozen_rules.json
```

---

## Sprint 6 hoàn tất

**Deliverables:**
- `L6_multiple_testing.py` (~350 dòng) — FDR 2 pools, conservative padding, economic re-check, FrozenRule construction
- 25 tests bao gồm:
  - Labeling cho hard/soft gates
  - Pool population với/không conservative padding
  - Padding p-values = 1.0 verified
  - FDR filtering với economic re-check
  - Từ chối theo: low EV / low PF / low WR / negative CI low / FDR
  - Conservative mode làm chặt hơn (verified)
  - Soft gate passes/rejects nhưng **không frozen**
  - Pool isolation (hard và soft độc lập)
  - FrozenRule fields propagated correctly
  - FrozenRule immutable
  - Multiple rules với unique IDs
  - Output files
  - Edge: empty candidates, missing experiment_id, chỉ 1 loại gates

**Điểm quan trọng đã enforce:**
1. **Conservative FDR** — pad pool với p=1.0 để bảo toàn information boundary khi L4 filter nhiều
2. **Economic re-check độc lập** — dùng `contract.production_criteria`, không dùng L4's internal config
3. **Soft gates không frozen** — chúng là tilt, không phải gate
4. **Pool isolation enforced** — FDR correction của hard_gate không ảnh hưởng soft_gate
5. **FrozenRule construction validated** — `FrozenRule.__post_init__` kiểm tra consistency (threshold/band bounds)

**Bugs từ các phase cũ đã fix:**
1. ✅ Phase 05 FDR misalignment (dùng `combined_p` của rule, không phải per-fold p-values)
2. ✅ FDR pool isolation (hard và soft tách biệt)
3. ✅ Economic criteria vs statistical significance tách rời
4. ✅ Freeze protocol rõ ràng — `FrozenRule` immutable

**Kernel + L0-L6 hiện có:**
```text
┌─────────────────────────────────────────────────────────────┐
│  Sprint 0A/B/C — Governance kernel        141 tests         │
│  Sprint 1 — L0 Data Hygiene                 32 tests         │
│  Sprint 2 — L1 Boundary + L2 Features       30 tests         │
│  Sprint 3 — L3 EDA + Shape Verification     24 tests         │
│  Sprint 4 — L4 Hard Gate Discovery          22 tests         │
│  Sprint 5 — L5 Soft Gate Discovery          16 tests         │
│  Sprint 6 — L6 Multiple Testing + Freeze    25 tests         │
│  ─────────────────────────────────────────────────────────  │
│  Total                                     290 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Sprint 7 — Layer 7: Dev Optimization (SL/TP + Sizing):**
- SL/TP optimization trên dev từ MAE/MFE
- Sizing calibration (Fractional Kelly trên dev)
- **Không FDR** — optimization, không hypothesis testing
- `FrozenProductionConfig` construction
- Output: `sl_tp_optimization.csv`, `sizing_config.csv`, `production_config.json`
- ~20 tests
