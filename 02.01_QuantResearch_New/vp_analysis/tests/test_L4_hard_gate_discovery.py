"""Tests for Layer 4 — Hard Gate Discovery.

Key test strategy:
  - Build synthetic data with KNOWN signal (feature genuinely predicts EV).
  - Verify pipeline discovers the signal.
  - Build synthetic data with NO signal → verify nothing is discovered.
  - Test inner/outer separation (verify threshold learned on train).
  - Test shape-aware search (MONO_UP uses only direction=+1).
"""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L4_hard_gate_discovery
from vp_analysis.layers.L4_hard_gate_discovery import (
    HardGateConfig,
    ThresholdRuleSpec,
    _apply_rule,
    _search_threshold,
    _search_band,
    _temporal_slope_p,
)


# ─── Inline contract helper ──────────────────────────────────────

def _make_inline_contract(
    pre_registered,
    feature_direction,
    shape_priors,
    allowed_directions=None,
    gate_types=None,
):
    """Full v3-compliant contract dict — all boilerplate auto-filled."""
    return {
        "version": "v1",
        "observation_unit": "x",
        "style_filter": "x",
        "pre_registered": pre_registered,
        "feature_direction": feature_direction,
        "shape_priors": shape_priors,
        "allowed_interactions": [],
        "gate_types": gate_types if gate_types is not None else ["threshold"],
        "allowed_directions": allowed_directions if allowed_directions is not None else [1],
        "primary_test": "t",
        "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {
            "hard_gate":    {"name": "hard_gate",    "max_hypotheses": 500, "alpha": 0.05},
            "soft_gate":    {"name": "soft_gate",    "max_hypotheses": 200, "alpha": 0.05},
            "regime_block": {"name": "regime_block", "max_hypotheses": 200, "alpha": 0.05},
            "bad_entry":    {"name": "bad_entry",    "max_hypotheses": 200, "alpha": 0.05},
        },
        "edge_discovery_target": {
            "name": "profitUSD",
            "definition": "profitUSD of production-style trade",
            "used_by": ["L4", "L4b", "L5", "L7"],
        },
        "bad_entry_canary_target": {
            "name": "MFE-based entry quality",
            "definition": "MFE_max_across_3_styles >= 1.0 ATR",
            "used_by": ["L10a"],
        },
        "optimization_budget": {
            "sl_candidates": [1.0],
            "tp_candidates": [1.0],
            "sizing_configs": 1,
            "utility_function": "ev",
        },
        "stopping_rules": {
            "min_group_samples": 30,
            "min_fold_consistency": 0.6,
            "min_effect_size": 0.05,
            "max_outer_folds": 5,
            "max_inner_folds": 3,
        },
        "production_criteria": {
            "min_ev": 0.05, "min_pf": 1.1, "min_wr": 0.35,
            "require_robust_across_styles": False,
            "require_holdout_confirmation": True,
        },
        "selection_budget": {
            "max_experiments_per_dataset": 5,
            "max_contract_changes_per_day": 3,
            "cooldown_hours_between_experiments": 24,
            "max_eda_inspect_and_rerun": 1,
            "config_frozen_after_start": True,
        },
        "split_ratio": 0.70,
        "split_method": "temporal",
        "dataset_hash":           "sha256:" + "a" * 64,
        "code_hash":              "sha256:" + "b" * 64,
        "config_hash":            "sha256:" + "c" * 64,
        "feature_registry_hash":  "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash":  "sha256:" + "f" * 64,
    }


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def base_contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "cat_a": ["f_signal", "f_noise"],
    }
    d["feature_direction"] = {"f_signal": 1, "f_noise": 0}
    d["shape_priors"] = {
        "f_signal": "MONO_UP",
        "f_noise": "MONO_UP",
    }
    return ResearchContract.from_dict(d)


def _make_signal_df(n=400, seed=0, signal_strength=0.8):
    """f_signal uniformly random. profit = signal_strength*(f_signal>0.6) + noise.
    f_noise is pure noise.
    """
    rng = np.random.default_rng(seed)
    f_signal = rng.uniform(0, 1, n)
    f_noise = rng.uniform(0, 1, n)
    noise = rng.normal(0, 0.5, n)
    is_high = (f_signal > 0.6).astype(float)
    profit = signal_strength * is_high - 0.3 * (1 - is_high) + noise
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": f_signal,
        "f_noise": f_noise,
        "_profit": profit,
    })


def _make_noise_df(n=400, seed=42):
    """No relationship between any feature and profit."""
    rng = np.random.default_rng(seed)
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": rng.uniform(0, 1, n),
        "f_noise": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })


# ══════════════════════════════════════════════════════════════════
# Unit tests — search primitives
# ══════════════════════════════════════════════════════════════════

def test_search_threshold_mono_up_finds_high_side():
    rng = np.random.default_rng(0)
    vals = rng.uniform(0, 1, 200)
    profits = np.where(vals > 0.7, 1.0, -0.5)
    rule = _search_threshold(vals, profits, direction=+1, cfg=HardGateConfig())
    assert rule is not None
    assert rule.gate_type == "threshold"
    assert rule.direction == 1
    assert rule.lower > 0.5  # threshold should be somewhere meaningful
    assert rule.upper is None


def test_search_threshold_mono_down_finds_low_side():
    rng = np.random.default_rng(1)
    vals = rng.uniform(0, 1, 200)
    profits = np.where(vals < 0.3, 1.0, -0.5)
    rule = _search_threshold(vals, profits, direction=-1, cfg=HardGateConfig())
    assert rule is not None
    assert rule.direction == -1
    assert rule.upper < 0.5
    assert rule.lower is None


def test_search_threshold_none_when_no_signal():
    rng = np.random.default_rng(2)
    vals = rng.uniform(0, 1, 200)
    profits = rng.normal(0, 1, 200)
    # Require big EV — very unlikely to find a valid threshold
    rule = _search_threshold(
        vals, profits, direction=+1,
        cfg=HardGateConfig(min_effect_size=0.5),
    )
    assert rule is None


def test_search_band_finds_interior_peak():
    """Band EV is strongly positive in [0.3, 0.7], negative outside.
    Values outside band: EV ≈ -1.0. Values inside [0.3,0.7]: EV ≈ +1.0.
    The band search should find a rule covering the interior.
    """
    rng = np.random.default_rng(3)
    n = 400
    vals = rng.uniform(0, 1, n)
    # Clear step function: inside band [0.3, 0.7] → profit +1, outside → -1
    inside = ((vals >= 0.3) & (vals <= 0.7)).astype(float)
    profits = inside * 2.0 - 1.0 + rng.normal(0, 0.1, n)
    # EV inside ≈ +1.0, well above min_effect_size=0.1
    rule = _search_band(vals, profits, cfg=HardGateConfig(min_effect_size=0.10))
    assert rule is not None
    assert rule.gate_type == "band"
    assert rule.lower < 0.5 < rule.upper


def test_apply_rule_threshold_up():
    vals = np.array([0.1, 0.5, 0.9])
    rule = ThresholdRuleSpec("threshold", 1, 0.5, None)
    mask = _apply_rule(vals, rule)
    np.testing.assert_array_equal(mask, [False, True, True])


def test_apply_rule_threshold_down():
    vals = np.array([0.1, 0.5, 0.9])
    rule = ThresholdRuleSpec("threshold", -1, None, 0.5)
    mask = _apply_rule(vals, rule)
    np.testing.assert_array_equal(mask, [True, True, False])


def test_apply_rule_band():
    vals = np.array([0.1, 0.5, 0.9])
    rule = ThresholdRuleSpec("band", 0, 0.3, 0.7)
    mask = _apply_rule(vals, rule)
    np.testing.assert_array_equal(mask, [False, True, False])


def test_temporal_slope_p_decay_detected():
    # Decreasing trend
    evs = [1.0, 0.8, 0.5, 0.2, -0.1]
    p = _temporal_slope_p(evs)
    assert p < 0.5


def test_temporal_slope_p_flat():
    evs = [0.5, 0.5, 0.5, 0.5]
    p = _temporal_slope_p(evs)
    assert p == 1.0  # no negative slope


# ══════════════════════════════════════════════════════════════════
# Integration — signal discovery
# ══════════════════════════════════════════════════════════════════

def test_discovers_signal(base_contract):
    """Synthetic signal should be discovered with reasonable config."""
    df = _make_signal_df(n=600, seed=0, signal_strength=1.0)
    cfg = HardGateConfig(
        outer_folds=5, inner_folds=3,
        min_inner_train=15, min_inner_val=15, min_outer_test=15,
        min_effect_size=0.10, min_win_rate=0.40, min_profit_factor=1.05,
        fold_consistency_threshold=0.60, ttest_alpha=0.10,
        min_folds_results=2,
    )
    result = L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal", "f_noise"],
        config=cfg,
    )
    # f_signal should be among candidates
    signal_candidates = [c for c in result.candidates if c.feature == "f_signal"]
    assert len(signal_candidates) >= 1


def test_noise_not_discovered(base_contract):
    """Pure noise should produce no candidates with strict thresholds."""
    df = _make_noise_df(n=600, seed=42)
    cfg = HardGateConfig(
        min_effect_size=0.20, ttest_alpha=0.01,
        fold_consistency_threshold=0.80,
        min_folds_results=3,
    )
    result = L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal", "f_noise"],
        config=cfg,
    )
    assert len(result.candidates) == 0


def test_shape_aware_search_mono_up_only_positive_direction(base_contract):
    """Verify MONO_UP produces only direction=+1 rules (never -1)."""
    df = _make_signal_df(n=600, seed=1)
    result = L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal"],
        config=HardGateConfig(min_effect_size=0.05, ttest_alpha=0.20),
    )
    for c in result.candidates:
        if c.shape_prior == "MONO_UP":
            assert c.direction == 1


def test_shape_aware_search_band_only():
    """Verify BAND prior → only band rules (direction=0)."""
    rng = np.random.default_rng(7)
    n = 600
    f_band = rng.uniform(0, 1, n)
    # Peak EV at 0.5
    profit = -((f_band - 0.5) ** 2) * 8 + rng.normal(0, 0.2, n)
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_band": f_band,
        "_profit": profit,
    })
    d = _make_inline_contract(
        pre_registered={"cat": ["f_band"]},
        feature_direction={"f_band": 0},
        shape_priors={"f_band": "BAND"},
        allowed_directions=[0],
        gate_types=["band"],
    )
    contract = ResearchContract.from_dict(d)
    result = L4_hard_gate_discovery.run(
        df, contract, available_features=["f_band"],
        config=HardGateConfig(
            min_effect_size=0.10, ttest_alpha=0.20,
            fold_consistency_threshold=0.50,
        ),
    )
    # Every candidate should be a band
    for c in result.candidates:
        assert c.gate_type == "band"
        assert c.direction == 0


def test_features_without_shape_prior_ignored(base_contract):
    """Feature not in shape_priors should be silently skipped."""
    df = _make_signal_df(n=400, seed=0)
    df["f_orphan"] = np.random.rand(400)
    result = L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal", "f_orphan"],
        config=HardGateConfig(min_effect_size=0.05),
    )
    assert all(c.feature != "f_orphan" for c in result.candidates)


# ══════════════════════════════════════════════════════════════════
# Inner/outer separation invariant
# ══════════════════════════════════════════════════════════════════

def test_inner_outer_separation_causal():
    """Signal injected only into the future (test fold) should NOT be
    discovered — threshold is learned on past data where no signal exists.
    """
    n = 600
    rng = np.random.default_rng(9)
    f = rng.uniform(0, 1, n)
    # First 70%: random. Last 30%: strong signal
    profit = np.zeros(n)
    profit[:420] = rng.normal(0, 1, 420)
    profit[420:] = np.where(f[420:] > 0.6, 2.0, -1.0)

    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": f,
        "_profit": profit,
    })
    d = _make_inline_contract(
        pre_registered={"cat": ["f_signal"]},
        feature_direction={"f_signal": 1},
        shape_priors={"f_signal": "MONO_UP"},
    )
    contract = ResearchContract.from_dict(d)
    result = L4_hard_gate_discovery.run(
        df, contract, available_features=["f_signal"],
        config=HardGateConfig(
            min_effect_size=0.20, ttest_alpha=0.05,
            fold_consistency_threshold=0.60,
        ),
    )
    # Should NOT find this signal — threshold was learned on earlier
    # data where no signal exists
    assert len(result.candidates) == 0


# ══════════════════════════════════════════════════════════════════
# Grouping
# ══════════════════════════════════════════════════════════════════

def test_multiple_symbols_discovered_separately(base_contract):
    """Each (symbol, setup) group gets its own discovery."""
    df1 = _make_signal_df(n=400, seed=0)
    df2 = _make_signal_df(n=400, seed=1)
    df2 = df2.copy()
    df2["symbol"] = "EURUSD"
    df = pd.concat([df1, df2], ignore_index=True)

    result = L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal"],
        config=HardGateConfig(min_effect_size=0.10, ttest_alpha=0.20),
    )
    symbols = {c.symbol for c in result.candidates}
    # At least one symbol should appear as a group
    assert "XAUUSD" in symbols or "EURUSD" in symbols


def test_small_group_skipped(base_contract):
    """Group with too few rows generates a warning."""
    df = _make_signal_df(n=20, seed=0)
    result = L4_hard_gate_discovery.run(
        df, base_contract, available_features=["f_signal"],
    )
    assert any("skipped" in w for w in result.warnings)


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(base_contract, tmp_path):
    df = _make_signal_df(n=600, seed=0)
    L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal", "f_noise"],
        output_dir=tmp_path,
        config=HardGateConfig(min_effect_size=0.05, ttest_alpha=0.30),
    )
    assert (tmp_path / "hard_gate_discovery_summary.json").exists()
    with (tmp_path / "hard_gate_discovery_summary.json").open() as fh:
        summary = json.load(fh)
    assert "n_features_searched" in summary
    assert "warnings" in summary


def test_candidate_csv_columns(base_contract, tmp_path):
    df = _make_signal_df(n=600, seed=0)
    result = L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal"],
        output_dir=tmp_path,
        config=HardGateConfig(min_effect_size=0.05, ttest_alpha=0.30),
    )
    if result.candidates:
        df_out = pd.read_csv(tmp_path / "hard_gate_candidates.csv")
        expected_cols = {
            "symbol", "setup", "feature", "gate_type", "direction",
            "lower", "upper", "mean_ev", "mean_wr", "mean_pf",
            "n_folds", "fold_consistency", "ttest_pvalue",
            "ci_low", "ci_high", "temporal_slope_p",
        }
        assert expected_cols.issubset(set(df_out.columns))


def test_fold_details_csv_written(base_contract, tmp_path):
    df = _make_signal_df(n=600, seed=0)
    result = L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal"],
        output_dir=tmp_path,
        config=HardGateConfig(min_effect_size=0.05, ttest_alpha=0.30),
    )
    if result.candidates:
        assert (tmp_path / "fold_details.csv").exists()
        fd = pd.read_csv(tmp_path / "fold_details.csv")
        assert "feature" in fd.columns
        assert "fold_idx" in fd.columns
        assert "ev" in fd.columns


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_df_raises(base_contract):
    with pytest.raises(ValueError, match="empty"):
        L4_hard_gate_discovery.run(
            pd.DataFrame(), base_contract,
            available_features=["f_signal"],
        )


def test_missing_profit_column_raises(base_contract):
    df = _make_signal_df(n=100).drop(columns=["_profit"])
    with pytest.raises(ValueError, match="_profit"):
        L4_hard_gate_discovery.run(
            df, base_contract, available_features=["f_signal"],
        )


def test_no_usable_features_returns_empty(base_contract):
    df = _make_signal_df(n=200)
    df["f_orphan"] = np.random.rand(200)
    result = L4_hard_gate_discovery.run(
        df, base_contract, available_features=["f_orphan"],
    )
    assert result.n_features_searched == 0
    assert len(result.candidates) == 0
    assert any("No features" in w for w in result.warnings)


# ══════════════════════════════════════════════════════════════════
# Contract immutability
# ══════════════════════════════════════════════════════════════════

def test_contract_not_mutated(base_contract):
    priors_before = dict(base_contract.shape_priors)
    df = _make_signal_df(n=400, seed=0)
    L4_hard_gate_discovery.run(
        df, base_contract,
        available_features=["f_signal"],
        config=HardGateConfig(min_effect_size=0.05),
    )
    assert base_contract.shape_priors == priors_before
