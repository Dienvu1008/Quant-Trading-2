"""Tests for Layer 6 — Multiple Testing + Rule Freeze."""
import dataclasses
import json

import pandas as pd
import pytest

from vp_analysis.core.fdr_registry import FDRPoolRegistry
from vp_analysis.core.frozen_types import FrozenRule
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L4_hard_gate_discovery import GateCandidate as HardGateCandidate
from vp_analysis.layers.L5_soft_gate_discovery import SoftGateCandidate
from vp_analysis.layers.L6_multiple_testing import (
    MultipleTestingConfig,
    ValidatedCandidate,
    _build_frozen_rules,
    _label_hard_candidates,
    _label_soft_candidates,
    _populate_pool,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["production_criteria"] = {
        "min_ev": 0.05, "min_pf": 1.10, "min_wr": 0.35,
        "require_robust_across_styles": False,
        "require_holdout_confirmation": True,
    }
    # Use the 4-pool format from minimal_contract_dict (already has all 4 pools)
    return ResearchContract.from_dict(d)


def _make_hard_candidate(
    symbol="XAUUSD", setup="BOS", feature="f_signal",
    gate_type="threshold", direction=1, lower=0.60, upper=None,
    mean_ev=0.30, mean_wr=0.55, mean_pf=1.50, mean_n=40,
    mean_pass_ratio=0.40, n_folds=3, fold_consistency=0.80,
    ttest_pvalue=0.01, ci_low=0.10, ci_high=0.50,
    temporal_slope_p=0.50, shape_prior="MONO_UP", category="cat_a",
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


class _StubL4:
    def __init__(self, candidates, n_features_searched=50):
        self.candidates = tuple(candidates)
        self.n_features_searched = n_features_searched


class _StubL5:
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
    assert p == pytest.approx(0.01)
    assert cand is c


def test_label_soft_candidates_format():
    c = _make_soft_candidate()
    labeled = _label_soft_candidates([c])
    assert len(labeled) == 1
    label, p, cand = labeled[0]
    assert label == "XAUUSD|BOS|f_signal"
    assert p == pytest.approx(0.01)


# ══════════════════════════════════════════════════════════════════
# Pool population
# ══════════════════════════════════════════════════════════════════

def test_populate_pool_simple(contract):
    fdr = FDRPoolRegistry(contract)
    labeled = [("a", 0.01, None), ("b", 0.02, None)]
    _populate_pool(fdr, "hard_gate", labeled, target_size=2, warnings=[])
    assert fdr.pool_size("hard_gate") == 2


def test_populate_pool_pads_conservatively(contract):
    fdr = FDRPoolRegistry(contract)
    labeled = [("a", 0.01, None)]
    _populate_pool(fdr, "hard_gate", labeled, target_size=5, warnings=[])
    assert fdr.pool_size("hard_gate") == 5


def test_padding_p_values_are_one(contract):
    fdr = FDRPoolRegistry(contract)
    labeled = [("a", 0.01, None)]
    _populate_pool(fdr, "hard_gate", labeled, target_size=3, warnings=[])
    result = fdr.correct("hard_gate")
    d = result.as_dict()
    pad_entries = {k: v for k, v in d.items() if k.startswith("_pad_")}
    assert len(pad_entries) == 2
    for v in pad_entries.values():
        assert v["p_value"] == pytest.approx(1.0)


# ══════════════════════════════════════════════════════════════════
# FDR filtering — hard gates
# ══════════════════════════════════════════════════════════════════

def test_hard_gate_passes_fdr_and_economic(contract):
    c = _make_hard_candidate(
        ttest_pvalue=0.001, mean_ev=0.30, mean_pf=1.5,
        mean_wr=0.55, ci_low=0.10,
    )
    result = run(
        _StubL4([c], n_features_searched=1),
        _StubL5([], n_directions=0),
        contract, experiment_id="EXP-001",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_hard_gate_validated == 1
    assert result.n_frozen_rules == 1


def test_hard_gate_rejected_by_low_ev(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, mean_ev=0.01)  # < 0.05
    result = run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_low_pf(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, mean_pf=0.90)  # < 1.10
    result = run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_low_wr(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, mean_wr=0.30)  # < 0.35
    result = run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_negative_ci_low(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001, ci_low=-0.02)
    result = run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(
            conservative_fdr=False, require_ci_low_positive=True,
        ),
    )
    assert result.n_hard_gate_validated == 0


def test_hard_gate_rejected_by_fdr(contract):
    """100 candidates at p=0.20 each → BH FDR at alpha=0.05 rejects all."""
    candidates = [
        _make_hard_candidate(feature=f"f_{i}", ttest_pvalue=0.20)
        for i in range(100)
    ]
    result = run(
        _StubL4(candidates, 100), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_hard_gate_validated == 0


def test_conservative_fdr_reduces_rejections(contract):
    """Conservative padding makes threshold stricter — padded result
    should validate <= non-padded result for same candidate."""
    c = _make_hard_candidate(ttest_pvalue=0.04)
    r_no_pad = run(
        _StubL4([c], n_features_searched=1), _StubL5([], 0), contract,
        experiment_id="E1",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    r_pad = run(
        _StubL4([c], n_features_searched=200), _StubL5([], 0), contract,
        experiment_id="E2",
        config=MultipleTestingConfig(conservative_fdr=True),
    )
    assert r_pad.n_hard_gate_validated <= r_no_pad.n_hard_gate_validated


# ══════════════════════════════════════════════════════════════════
# Soft gate filtering
# ══════════════════════════════════════════════════════════════════

def test_soft_gate_passes(contract):
    c = _make_soft_candidate(perm_pvalue=0.001, ev_lift=0.40,
                              ev_top=0.30, wr_top=0.55)
    result = run(
        _StubL4([], 0), _StubL5([c], n_directions=1), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_soft_gate_validated == 1


def test_soft_gate_rejected_by_negative_lift(contract):
    c = _make_soft_candidate(perm_pvalue=0.001, ev_lift=-0.10)
    result = run(
        _StubL4([], 0), _StubL5([c], 1), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_soft_gate_validated == 0


def test_soft_gate_not_frozen(contract):
    """Soft gates must NOT appear in frozen_rules."""
    c = _make_soft_candidate(perm_pvalue=0.001)
    result = run(
        _StubL4([], 0), _StubL5([c], 1), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_soft_gate_validated == 1
    assert result.n_frozen_rules == 0


# ══════════════════════════════════════════════════════════════════
# Pool isolation
# ══════════════════════════════════════════════════════════════════

def test_pools_isolated_in_fdr(contract):
    """Hard and soft pools corrected independently."""
    hard = _make_hard_candidate(ttest_pvalue=0.01)
    soft = _make_soft_candidate(perm_pvalue=0.01)
    result = run(
        _StubL4([hard], 1), _StubL5([soft], 1), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.hard_gate_fdr.pool_name == "hard_gate"
    assert result.soft_gate_fdr.pool_name == "soft_gate"
    # Both single entries at p=0.01 should survive BH at alpha=0.05
    assert result.hard_gate_fdr.reject[0] is True
    assert result.soft_gate_fdr.reject[0] is True


# ══════════════════════════════════════════════════════════════════
# FrozenRule construction
# ══════════════════════════════════════════════════════════════════

def test_frozen_rule_fields_propagated(contract):
    c = _make_hard_candidate(
        symbol="XAUUSD", setup="BOS", feature="f_signal",
        gate_type="threshold", direction=1, lower=0.65, upper=None,
        mean_ev=0.35, mean_wr=0.58, mean_pf=1.60, mean_n=45,
        fold_consistency=0.80, n_folds=4, ttest_pvalue=0.001,
    )
    result = run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP-2026-09-18-001",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_frozen_rules == 1
    rule = result.frozen_rules[0]
    assert rule.symbol == "XAUUSD"
    assert rule.setup == "BOS"
    assert rule.features == ("f_signal",)
    assert rule.gate_type == "threshold"
    assert rule.direction == 1
    assert rule.lower_bound == pytest.approx(0.65)
    assert rule.upper_bound is None
    assert rule.experiment_id == "EXP-2026-09-18-001"
    assert rule.research_contract_hash == contract.contract_hash


def test_multiple_frozen_rules_unique_ids(contract):
    candidates = [
        _make_hard_candidate(feature=f"f_{i}", ttest_pvalue=0.0001)
        for i in range(3)
    ]
    result = run(
        _StubL4(candidates, 3), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    if result.n_frozen_rules >= 2:
        rule_ids = [r.rule_id for r in result.frozen_rules]
        assert len(rule_ids) == len(set(rule_ids))


def test_frozen_rule_is_immutable(contract):
    c = _make_hard_candidate(ttest_pvalue=0.001)
    result = run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    rule = result.frozen_rules[0]
    with pytest.raises((dataclasses.FrozenInstanceError, AttributeError)):
        rule.test_ev_mean = 999.0


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(contract, tmp_path):
    c = _make_hard_candidate(ttest_pvalue=0.001)
    run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP-TEST",
        output_dir=tmp_path,
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert (tmp_path / "fdr_summary.json").exists()
    assert (tmp_path / "fdr_hard_gate.csv").exists()
    assert (tmp_path / "fdr_soft_gate.csv").exists()
    assert (tmp_path / "frozen_rules.json").exists()


def test_summary_json_content(contract, tmp_path):
    c = _make_hard_candidate(ttest_pvalue=0.001)
    run(
        _StubL4([c], 1), _StubL5([], 0), contract,
        experiment_id="EXP-TEST",
        output_dir=tmp_path,
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    with (tmp_path / "fdr_summary.json").open() as fh:
        s = json.load(fh)
    assert s["experiment_id"] == "EXP-TEST"
    assert s["n_hard_gate_inputs"] == 1
    assert "research_contract_hash" in s


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_candidates_valid_result(contract):
    result = run(
        _StubL4([], 0), _StubL5([], 0), contract,
        experiment_id="EXP-TEST",
    )
    assert result.n_hard_gate_inputs == 0
    assert result.n_hard_gate_validated == 0
    assert result.n_frozen_rules == 0


def test_missing_experiment_id_raises(contract):
    with pytest.raises(ValueError, match="experiment_id"):
        run(_StubL4([], 0), _StubL5([], 0), contract, experiment_id="")


def test_only_soft_gates_present(contract):
    soft = _make_soft_candidate(perm_pvalue=0.001)
    result = run(
        _StubL4([], 0), _StubL5([soft], 1), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_frozen_rules == 0
    assert result.n_soft_gate_validated == 1


def test_only_hard_gates_present(contract):
    hard = _make_hard_candidate(ttest_pvalue=0.001)
    result = run(
        _StubL4([hard], 1), _StubL5([], 0), contract,
        experiment_id="EXP",
        config=MultipleTestingConfig(conservative_fdr=False),
    )
    assert result.n_frozen_rules == 1
    assert result.n_soft_gate_validated == 0
