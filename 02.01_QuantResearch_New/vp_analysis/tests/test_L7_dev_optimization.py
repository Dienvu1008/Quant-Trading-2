"""Tests for Layer 7 — Dev Optimization (SL/TP + Sizing)."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.frozen_types import FrozenRule
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L7_dev_optimization import (
    OptimizationConfig,
    _calibrate_sizing,
    _filter_by_rule,
    _fold_sign_agreement,
    _kelly_to_mult,
    _simulate_sl_tp,
    _utility,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["optimization_budget"] = {
        "sl_candidates": [1.0, 1.5, 2.0],
        "tp_candidates": [1.0, 1.5, 2.0],
        "sizing_configs": 5,
        "utility_function": "expectancy",
    }
    return ResearchContract.from_dict(d)


def _make_dev_df(n: int = 500, seed: int = 0, signal_strength: float = 1.5) -> pd.DataFrame:
    """f_signal > 0.6 → positive edge trade."""
    rng = np.random.default_rng(seed)
    f = rng.uniform(0, 1, n)
    mae = rng.uniform(0.3, 2.5, n)
    mfe = rng.uniform(0.5, 3.0, n)
    noise = rng.normal(0, 0.3, n)
    profit = np.where(f > 0.6, signal_strength, -0.5) + noise
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": f,
        "maeATR": mae,
        "mfeATR": mfe,
        "_profit": profit,
    })


def _make_frozen_rule(
    rule_id: str = "R-00001",
    feature: str = "f_signal",
    lower: float = 0.6,
    direction: int = 1,
    gate_type: str = "threshold",
) -> FrozenRule:
    return FrozenRule(
        rule_id=rule_id,
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD", setup="BOS",
        gate_type=gate_type, direction=direction,
        features=(feature,),
        lower_bound=lower, upper_bound=None,
        test_ev_mean=0.30, test_wr_mean=0.55, test_pf_mean=1.5,
        test_n_avg=50, pvalue=0.01, pvalue_fdr=0.02,
        fdr_significant=True, fold_consistency=0.8, n_folds=4,
    )


# ══════════════════════════════════════════════════════════════════
# Unit: rule filter
# ══════════════════════════════════════════════════════════════════

def test_filter_threshold_up():
    df = pd.DataFrame({"f_signal": [0.1, 0.5, 0.9]})
    rule = _make_frozen_rule(lower=0.5, direction=1)
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 2


def test_filter_threshold_down():
    df = pd.DataFrame({"f": [0.1, 0.5, 0.9]})
    rule = FrozenRule(
        rule_id="R-X", experiment_id="E",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="Y",
        gate_type="threshold", direction=-1,
        features=("f",), lower_bound=None, upper_bound=0.5,
        fdr_significant=True,
    )
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 2


def test_filter_band():
    df = pd.DataFrame({"f": [0.1, 0.5, 0.9]})
    rule = FrozenRule(
        rule_id="R-X", experiment_id="E",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="Y",
        gate_type="band", direction=0,
        features=("f",), lower_bound=0.3, upper_bound=0.7,
        fdr_significant=True,
    )
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 1


# ══════════════════════════════════════════════════════════════════
# Unit: SL/TP simulation
# ══════════════════════════════════════════════════════════════════

def test_simulate_stopped_out():
    """MAE >= SL → stopped out."""
    sim = _simulate_sl_tp(
        np.array([1.0]), np.array([2.0]), np.array([0.5]),
        sl=1.5, tp=2.0,
    )
    assert sim[0] == pytest.approx(-1.5)


def test_simulate_tp_hit():
    """MAE < SL, MFE >= TP → TP hit."""
    sim = _simulate_sl_tp(
        np.array([0.5]), np.array([0.3]), np.array([2.5]),
        sl=1.5, tp=2.0,
    )
    assert sim[0] == pytest.approx(2.0)


def test_simulate_original_stands():
    """Neither MAE nor MFE triggers → original profit."""
    sim = _simulate_sl_tp(
        np.array([0.5]), np.array([0.5]), np.array([1.0]),
        sl=1.5, tp=2.0,
    )
    assert sim[0] == pytest.approx(0.5)


def test_simulate_uses_all_trades():
    """Verify simulation handles both winners and losers correctly."""
    profits = np.array([1.0, -0.5, 0.8, -1.0])
    mae = np.array([0.5, 2.0, 0.3, 3.0])
    mfe = np.array([1.5, 0.5, 2.5, 0.5])
    sim = _simulate_sl_tp(profits, mae, mfe, sl=1.5, tp=2.0)
    # Row 0: MFE 1.5 < TP 2.0, MAE 0.5 < SL 1.5 → original 1.0
    # Row 1: MAE 2.0 >= SL 1.5 → -1.5
    # Row 2: MFE 2.5 >= TP 2.0 → +2.0
    # Row 3: MAE 3.0 >= SL 1.5 → -1.5
    expected = np.array([1.0, -1.5, 2.0, -1.5])
    np.testing.assert_allclose(sim, expected)


def test_utility_expectancy():
    assert _utility(np.array([1.0, 2.0, 3.0]), "expectancy") == pytest.approx(2.0)


def test_utility_sharpe_proxy_zero_std():
    assert _utility(np.array([1.0, 1.0, 1.0]), "sharpe_proxy") == pytest.approx(0.0)


# ══════════════════════════════════════════════════════════════════
# SL/TP optimization integration
# ══════════════════════════════════════════════════════════════════

def test_sl_tp_optimization_runs(contract):
    df = _make_dev_df(n=500, seed=0)
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    assert result.n_sl_tp_optimized == 1
    sol = result.sl_tp_solutions[0]
    assert sol.rule_id == "R-00001"
    assert sol.sl in contract.optimization_budget.sl_candidates
    assert sol.tp in contract.optimization_budget.tp_candidates
    assert sol.n_gated_trades > 0


def test_sl_tp_skipped_when_mae_mfe_missing(contract):
    df = _make_dev_df(n=500).drop(columns=["maeATR", "mfeATR"])
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    assert result.n_sl_tp_optimized == 0
    assert any("SL/TP optimization skipped" in w for w in result.warnings)


def test_sl_tp_skipped_when_disabled(contract):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(
        df, [rule], contract, experiment_id="EXP-TEST",
        config=OptimizationConfig(use_sl_tp_optimization=False),
    )
    assert result.n_sl_tp_optimized == 0


# ══════════════════════════════════════════════════════════════════
# Sizing calibration
# ══════════════════════════════════════════════════════════════════

def test_sizing_runs_for_signal(contract):
    """Strong signal → sizing should run and produce a result."""
    df = _make_dev_df(n=800, seed=0, signal_strength=2.0)
    rule = _make_frozen_rule()
    result = run(
        df, [rule], contract, experiment_id="EXP-TEST",
        config=OptimizationConfig(
            min_dev_trades=30, max_pval=0.20, min_fold_agree=0.50,
        ),
    )
    assert len(result.sizing_solutions) == 1
    sol = result.sizing_solutions[0]
    assert sol.n_gated_trades > 0
    assert 0.5 <= sol.lot_mult <= 1.5


def test_sizing_neutral_for_no_signal(contract):
    """Pure noise → not_significant → neutral multiplier."""
    rng = np.random.default_rng(42)
    n = 500
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": rng.uniform(0, 1, n),
        "maeATR": rng.uniform(0.3, 2.5, n),
        "mfeATR": rng.uniform(0.5, 3.0, n),
        "_profit": rng.normal(0, 1, n),
    })
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST",
                 config=OptimizationConfig(min_dev_trades=30))
    sol = result.sizing_solutions[0]
    assert not sol.validated
    assert sol.lot_mult == pytest.approx(1.0)


def test_sizing_skipped_insufficient_trades(contract):
    """Impossible min_dev_trades → no sizing generated."""
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(
        df, [rule], contract, experiment_id="EXP-TEST",
        config=OptimizationConfig(min_dev_trades=10_000),
    )
    assert len(result.sizing_solutions) == 0


def test_sizing_respects_min_max_bounds(contract):
    df = _make_dev_df(n=800, seed=0, signal_strength=5.0)
    rule = _make_frozen_rule()
    result = run(
        df, [rule], contract, experiment_id="EXP-TEST",
        config=OptimizationConfig(
            min_dev_trades=30, max_pval=0.50, min_fold_agree=0.20,
            min_mult=0.5, max_mult=1.5,
        ),
    )
    if result.sizing_solutions:
        sol = result.sizing_solutions[0]
        assert 0.5 <= sol.lot_mult <= 1.5


# ══════════════════════════════════════════════════════════════════
# Kelly mapping
# ══════════════════════════════════════════════════════════════════

def test_kelly_to_mult_neutral():
    cfg = OptimizationConfig(kelly_fraction=0.25)
    assert _kelly_to_mult(0.0, cfg) == pytest.approx(1.0)


def test_kelly_to_mult_positive_max():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    assert _kelly_to_mult(0.25, cfg) == pytest.approx(1.5)


def test_kelly_to_mult_positive_half():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    assert _kelly_to_mult(0.125, cfg) == pytest.approx(1.25)


def test_kelly_to_mult_negative_min():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    assert _kelly_to_mult(-0.25, cfg) == pytest.approx(0.5)


def test_kelly_to_mult_negative_half():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    assert _kelly_to_mult(-0.125, cfg) == pytest.approx(0.75)


def test_kelly_to_mult_clipped():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    assert _kelly_to_mult(1.0, cfg) == pytest.approx(1.5)
    assert _kelly_to_mult(-1.0, cfg) == pytest.approx(0.5)


# ══════════════════════════════════════════════════════════════════
# Fold agreement
# ══════════════════════════════════════════════════════════════════

def test_fold_agreement_all_positive():
    rng = np.random.default_rng(0)
    profits = rng.normal(0.5, 1.0, 400)
    cfg = OptimizationConfig(n_folds=4)
    agree = _fold_sign_agreement(profits, kelly_reference=0.1, cfg=cfg)
    assert 0.0 <= agree <= 1.0


def test_fold_agreement_zero_reference():
    profits = np.array([0.1, -0.1] * 100)
    cfg = OptimizationConfig(n_folds=4)
    assert _fold_sign_agreement(profits, 0.0, cfg) == pytest.approx(0.0)


def test_fold_agreement_small_sample():
    profits = np.array([0.1, 0.2])
    cfg = OptimizationConfig(n_folds=4)
    assert _fold_sign_agreement(profits, 0.1, cfg) == pytest.approx(0.0)


# ══════════════════════════════════════════════════════════════════
# FrozenProductionConfig
# ══════════════════════════════════════════════════════════════════

def test_production_config_built(contract):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    cfg = result.production_config
    assert cfg.experiment_id == "EXP-TEST"
    assert len(cfg.rules) == 1


def test_sl_tp_selection_references_valid_rule(contract):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    rule_ids = {r.rule_id for r in result.production_config.rules}
    for sel in result.production_config.sl_tp_selections:
        assert sel["rule_id"] in rule_ids


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(contract, tmp_path):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    run(df, [rule], contract, experiment_id="EXP-TEST", output_dir=tmp_path)
    assert (tmp_path / "sl_tp_optimization.csv").exists()
    assert (tmp_path / "sizing_configs.csv").exists()
    assert (tmp_path / "production_config.json").exists()
    assert (tmp_path / "optimization_summary.json").exists()


def test_summary_json_content(contract, tmp_path):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    run(df, [rule], contract, experiment_id="EXP-TEST", output_dir=tmp_path)
    with (tmp_path / "optimization_summary.json").open() as fh:
        s = json.load(fh)
    assert s["n_rules"] == 1
    assert "n_sl_tp_optimized" in s


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_df_raises(contract):
    with pytest.raises(ValueError, match="empty"):
        run(pd.DataFrame(), [_make_frozen_rule()], contract,
            experiment_id="EXP-TEST")


def test_missing_profit_raises(contract):
    df = _make_dev_df(n=500).drop(columns=["_profit"])
    with pytest.raises(ValueError, match="_profit"):
        run(df, [_make_frozen_rule()], contract, experiment_id="EXP-TEST")


def test_missing_experiment_id_raises(contract):
    df = _make_dev_df(n=500)
    with pytest.raises(ValueError, match="experiment_id"):
        run(df, [_make_frozen_rule()], contract, experiment_id="")


def test_no_rules_raises(contract):
    df = _make_dev_df(n=500)
    with pytest.raises(ValueError, match="no frozen rules"):
        run(df, [], contract, experiment_id="EXP-TEST")


def test_rule_with_no_gated_trades_skipped(contract):
    """Rule threshold > max value → no gated trades → warning."""
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule(lower=5.0)  # f_signal max is ~1.0 → nothing passes
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    assert result.n_sl_tp_optimized == 0
    assert any("only" in w for w in result.warnings)
