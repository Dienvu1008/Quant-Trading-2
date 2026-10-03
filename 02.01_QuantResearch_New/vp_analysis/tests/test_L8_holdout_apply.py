"""Tests for Layer 8 — Holdout Apply (Report Only)."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.data_boundary import SealedHoldout
from vp_analysis.core.frozen_types import FrozenProductionConfig, FrozenRule
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L8_holdout_apply import (
    HoldoutConfig,
    _evaluate_rule,
    _evaluate_sl_tp,
    _evaluate_sizing,
    _filter_by_rule,
    _simulate_sl_tp,
    run,
)


# ─── Helpers ─────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    return ResearchContract.from_dict(minimal_contract_dict)


def _make_frozen_rule(
    rule_id: str = "R-00001",
    feature: str = "f_signal",
    lower: float = 0.6,
    direction: int = 1,
    gate_type: str = "threshold",
    dev_ev: float = 0.30,
    dev_wr: float = 0.55,
    dev_pf: float = 1.5,
) -> FrozenRule:
    return FrozenRule(
        rule_id=rule_id, experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD", setup="BOS",
        gate_type=gate_type, direction=direction,
        features=(feature,),
        lower_bound=lower, upper_bound=None,
        test_ev_mean=dev_ev, test_wr_mean=dev_wr, test_pf_mean=dev_pf,
        test_n_avg=50, pvalue=0.01, pvalue_fdr=0.02,
        fdr_significant=True, fold_consistency=0.8, n_folds=4,
    )


def _make_holdout_df(
    n: int = 300,
    seed: int = 0,
    signal_strength: float = 1.0,
    include_time: bool = True,
) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    f = rng.uniform(0, 1, n)
    mae = rng.uniform(0.3, 2.5, n)
    mfe = rng.uniform(0.5, 3.0, n)
    noise = rng.normal(0, 0.3, n)
    profit = np.where(f > 0.6, signal_strength, -0.5) + noise
    data: dict = {
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": f,
        "maeATR": mae,
        "mfeATR": mfe,
        "_profit": profit,
    }
    if include_time:
        data["time"] = pd.date_range("2025-01-01", periods=n, freq="h")
    return pd.DataFrame(data)


def _make_production_config(
    rules,
    sl_tp=None,
    sizing=None,
) -> FrozenProductionConfig:
    return FrozenProductionConfig(
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        rules=tuple(rules),
        sl_tp_selections=tuple(sl_tp or ()),
        sizing_configs=tuple(sizing or ()),
    )


# ══════════════════════════════════════════════════════════════════
# Unseal protocol
# ══════════════════════════════════════════════════════════════════

def test_unseal_once_succeeds(contract):
    df = _make_holdout_df(n=300)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()])

    assert holdout.is_sealed
    run(holdout, config, contract, experiment_id="EXP-TEST")
    assert not holdout.is_sealed


def test_second_unseal_raises(contract):
    df = _make_holdout_df(n=300)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()])

    run(holdout, config, contract, experiment_id="EXP-TEST")
    with pytest.raises(RuntimeError, match="failed to unseal"):
        run(holdout, config, contract, experiment_id="EXP-TEST")


def test_different_experiment_can_unseal(contract):
    """Different experiment_id → kernel allows (no disk persistence in test)."""
    df = _make_holdout_df(n=300)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()])

    run(holdout, config, contract, experiment_id="EXP-A")
    # Different experiment_id: kernel allows since is_sealed check uses
    # per-experiment logic
    run(holdout, config, contract, experiment_id="EXP-B")


# ══════════════════════════════════════════════════════════════════
# Rule evaluation
# ══════════════════════════════════════════════════════════════════

def test_rule_evaluation_runs(contract):
    df = _make_holdout_df(n=300, signal_strength=1.5)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule(dev_ev=0.30)])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert result.n_rules_evaluated == 1
    ev = result.rule_evaluations[0]
    assert ev.n_gated > 0


def test_rule_evaluation_insufficient_trades(contract):
    df = _make_holdout_df(n=50)
    holdout = SealedHoldout(df)
    # Rule that gates very few trades
    config = _make_production_config(
        [_make_frozen_rule(lower=0.99)],
    )
    result = run(
        holdout, config, contract, experiment_id="EXP-TEST",
        config=HoldoutConfig(min_gated_trades=100),
    )
    ev = result.rule_evaluations[0]
    assert ev.reason.startswith("insufficient")
    assert not ev.holdout_confirmed


def test_rule_confirmed_when_holdout_matches_dev(contract):
    """Strong signal on holdout → should confirm."""
    df = _make_holdout_df(n=400, seed=0, signal_strength=1.0)
    holdout = SealedHoldout(df)
    # Set dev_ev low so holdout easily beats it
    config = _make_production_config([_make_frozen_rule(dev_ev=0.05, dev_wr=0.3)])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    ev = result.rule_evaluations[0]
    assert ev.holdout_confirmed


def test_rule_not_confirmed_when_degraded(contract):
    """No signal on holdout → degraded."""
    df = _make_holdout_df(n=400, seed=0, signal_strength=0.0)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule(dev_ev=1.0, dev_wr=0.70)])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    ev = result.rule_evaluations[0]
    assert not ev.holdout_confirmed
    assert any(
        kw in ev.reason
        for kw in ("ev_degraded", "ev_nonpositive", "pf_low", "wr_degraded")
    )


# ══════════════════════════════════════════════════════════════════
# Frozen artifacts immutability
# ══════════════════════════════════════════════════════════════════

def test_frozen_rule_not_mutated(contract):
    df = _make_holdout_df(n=300)
    holdout = SealedHoldout(df)
    rule = _make_frozen_rule()
    ev_before = rule.test_ev_mean
    config = _make_production_config([rule])

    run(holdout, config, contract, experiment_id="EXP-TEST")
    assert rule.test_ev_mean == ev_before


def test_production_config_not_mutated(contract):
    df = _make_holdout_df(n=300)
    holdout = SealedHoldout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])
    rules_before = len(config.rules)

    run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(config.rules) == rules_before


# ══════════════════════════════════════════════════════════════════
# Null result
# ══════════════════════════════════════════════════════════════════

def test_null_result_when_all_fail(contract):
    """No signal on holdout + strict thresholds → null result."""
    df = _make_holdout_df(n=400, seed=0, signal_strength=0.0)
    holdout = SealedHoldout(df)
    rules = [
        _make_frozen_rule(rule_id="R-00001", dev_ev=1.0, dev_wr=0.80),
        _make_frozen_rule(rule_id="R-00002", dev_ev=1.0, dev_wr=0.80),
    ]
    config = _make_production_config(rules)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert result.null_result
    assert result.n_rules_confirmed == 0
    assert any("NULL RESULT" in w for w in result.warnings)


def test_no_null_result_when_some_pass(contract):
    """Strong signal + low dev_ev threshold → should confirm."""
    df = _make_holdout_df(n=400, seed=0, signal_strength=1.5)
    holdout = SealedHoldout(df)
    rules = [_make_frozen_rule(dev_ev=0.05, dev_wr=0.30)]
    config = _make_production_config(rules)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    if result.n_rules_confirmed > 0:
        assert not result.null_result


# ══════════════════════════════════════════════════════════════════
# SL/TP evaluation
# ══════════════════════════════════════════════════════════════════

def test_sl_tp_evaluation_runs(contract):
    df = _make_holdout_df(n=400, signal_strength=1.5)
    holdout = SealedHoldout(df)
    rule = _make_frozen_rule(dev_ev=0.3, dev_wr=0.5)
    sl_tp = ({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},)
    config = _make_production_config([rule], sl_tp=sl_tp)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sl_tp_evaluations) == 1
    ev = result.sl_tp_evaluations[0]
    assert ev.sl == pytest.approx(1.5)
    assert ev.tp == pytest.approx(2.0)
    assert ev.n_gated > 0


def test_sl_tp_skipped_without_selection(contract):
    df = _make_holdout_df(n=300)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()], sl_tp=None)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sl_tp_evaluations) == 0


def test_sl_tp_skipped_without_mae_mfe(contract):
    df = _make_holdout_df(n=400).drop(columns=["maeATR", "mfeATR"])
    holdout = SealedHoldout(df)
    rule = _make_frozen_rule()
    sl_tp = ({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},)
    config = _make_production_config([rule], sl_tp=sl_tp)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sl_tp_evaluations) == 0


def test_simulate_sl_tp_consistency():
    """L8 simulation must match L7 logic."""
    profits = np.array([1.0, -0.5, 0.8])
    mae = np.array([0.5, 2.0, 0.3])
    mfe = np.array([1.5, 0.5, 2.5])
    sim = _simulate_sl_tp(profits, mae, mfe, sl=1.5, tp=2.0)
    # Row 0: mae=0.5 < sl=1.5, mfe=1.5 < tp=2.0 → original 1.0
    # Row 1: mae=2.0 >= sl=1.5 → stopped out -1.5
    # Row 2: mae=0.3 < sl=1.5, mfe=2.5 >= tp=2.0 → TP hit +2.0
    np.testing.assert_allclose(sim, [1.0, -1.5, 2.0])


# ══════════════════════════════════════════════════════════════════
# Sizing evaluation
# ══════════════════════════════════════════════════════════════════

def test_sizing_evaluation_runs(contract):
    df = _make_holdout_df(n=400, signal_strength=1.5)
    holdout = SealedHoldout(df)
    rule = _make_frozen_rule(dev_ev=0.3)
    sizing = ({"rule_id": "R-00001", "lot_mult": 1.2},)
    config = _make_production_config([rule], sizing=sizing)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sizing_evaluations) == 1
    ev = result.sizing_evaluations[0]
    assert ev.lot_mult == pytest.approx(1.2)
    assert ev.n_gated > 0


def test_sizing_skipped_without_config(contract):
    df = _make_holdout_df(n=400)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()], sizing=None)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sizing_evaluations) == 0


# ══════════════════════════════════════════════════════════════════
# Degradation analysis
# ══════════════════════════════════════════════════════════════════

def test_degradation_analysis_runs(contract):
    df = _make_holdout_df(n=400, signal_strength=1.5, include_time=True)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule(dev_ev=0.3)])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.degradation_analyses) == 1
    d = result.degradation_analyses[0]
    assert d.rule_id == "R-00001"
    assert len(d.buckets) == 4


def test_degradation_skipped_without_time(contract):
    df = _make_holdout_df(n=400, include_time=False)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.degradation_analyses) == 0


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(contract, tmp_path):
    df = _make_holdout_df(n=400, signal_strength=1.5)
    holdout = SealedHoldout(df)
    rule = _make_frozen_rule(dev_ev=0.3, dev_wr=0.5)
    sl_tp = ({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},)
    sizing = ({"rule_id": "R-00001", "lot_mult": 1.2},)
    config = _make_production_config([rule], sl_tp=sl_tp, sizing=sizing)

    run(holdout, config, contract, experiment_id="EXP-TEST",
        output_dir=tmp_path)

    assert (tmp_path / "holdout_evaluation.csv").exists()
    assert (tmp_path / "sl_tp_holdout_report.csv").exists()
    assert (tmp_path / "sizing_holdout_report.csv").exists()
    assert (tmp_path / "holdout_degradation.csv").exists()
    assert (tmp_path / "holdout_summary.json").exists()


def test_summary_json_content(contract, tmp_path):
    df = _make_holdout_df(n=300, signal_strength=1.5)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule(dev_ev=0.3, dev_wr=0.5)])

    run(holdout, config, contract, experiment_id="EXP-TEST",
        output_dir=tmp_path)

    with (tmp_path / "holdout_summary.json").open() as fh:
        s = json.load(fh)
    assert s["experiment_id"] == "EXP-TEST"
    assert s["n_rules_evaluated"] == 1
    assert "overall_confirmation_rate" in s


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_missing_experiment_id_raises(contract):
    df = _make_holdout_df(n=100)
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()])

    with pytest.raises(ValueError, match="experiment_id"):
        run(holdout, config, contract, experiment_id="")


def test_wrong_config_type_raises(contract):
    df = _make_holdout_df(n=100)
    holdout = SealedHoldout(df)

    with pytest.raises(TypeError, match="FrozenProductionConfig"):
        run(holdout, {"not": "a config"}, contract, experiment_id="EXP-TEST")


def test_empty_holdout_raises(contract):
    holdout = SealedHoldout(pd.DataFrame())
    config = _make_production_config([_make_frozen_rule()])

    with pytest.raises((ValueError, RuntimeError)):
        run(holdout, config, contract, experiment_id="EXP-TEST")


def test_holdout_without_profit_column_raises(contract):
    df = _make_holdout_df(n=100).drop(columns=["_profit"])
    holdout = SealedHoldout(df)
    config = _make_production_config([_make_frozen_rule()])

    with pytest.raises(ValueError, match="_profit|profitUSD"):
        run(holdout, config, contract, experiment_id="EXP-TEST")


def test_filter_by_rule_missing_feature():
    df = pd.DataFrame({"other_feat": [0.5, 0.6]})
    rule = _make_frozen_rule(feature="f_signal")
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 0
