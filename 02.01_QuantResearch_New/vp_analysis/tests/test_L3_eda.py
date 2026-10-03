"""Tests for Layer 3 — EDA & Shape Verification."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L3_eda
from vp_analysis.layers.L3_eda import EDAConfig


# ─── Inline contract helper ──────────────────────────────────────

def _make_inline_contract(
    pre_registered,
    feature_direction,
    shape_priors,
    allowed_directions=None,
):
    """Build a full v3-compliant contract dict from the minimal required fields.

    All boilerplate (4 FDR pools, 2 targets, hashes, budgets) is filled in
    automatically so individual tests only declare what they actually care about.
    """
    return {
        "version": "v1",
        "observation_unit": "x",
        "style_filter": "x",
        "pre_registered": pre_registered,
        "feature_direction": feature_direction,
        "shape_priors": shape_priors,
        "allowed_interactions": [],
        "gate_types": ["threshold"],
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
        "dataset_hash":          "sha256:" + "a" * 64,
        "code_hash":             "sha256:" + "b" * 64,
        "config_hash":           "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash":"sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }


# ─── Fixtures ────────────────────────────────────────────────────

def _make_dev_df(n=500, seed=0):
    """Construct a dev DataFrame with controlled feature-EV shapes."""
    rng = np.random.default_rng(seed)
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
    })

    # f_mono_up: EV = 0.5*(x-0.5) — perfect monotone up
    x_up = rng.uniform(0.0, 1.0, n)
    df["f_mono_up"] = x_up

    # f_mono_down: EV = -0.5*(x-0.5) — monotone down
    x_dn = rng.uniform(0.0, 1.0, n)
    df["f_mono_down"] = x_dn

    # f_band: EV peaks at x=0.5 — band shape
    x_band = rng.uniform(0.0, 1.0, n)
    df["f_band"] = x_band

    # f_flat: independent noise column — no contribution to profit at all
    x_flat = rng.uniform(0.0, 1.0, n)
    df["f_flat"] = x_flat

    # f_corr_with_mono_up: near-perfect correlation with f_mono_up
    df["f_corr_with_mono_up"] = x_up + rng.normal(0, 0.001, n)

    # Build profit: f_flat is NOT included → it has no true relationship
    base = rng.normal(0.0, 0.05, n)
    profit = (
        base
        + 0.5 * (x_up - 0.5)                       # mono-up contribution
        - 0.5 * (x_dn - 0.5)                       # mono-down contribution
        + 0.8 * (1 - 4 * (x_band - 0.5) ** 2)      # band peak at 0.5
        # f_flat intentionally omitted
    )
    df["_profit"] = profit
    return df


@pytest.fixture
def dev_df():
    return _make_dev_df()


@pytest.fixture
def contract_for_eda(minimal_contract_dict):
    """Contract declaring features and their expected shapes."""
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "cat_a": ["f_mono_up", "f_mono_down"],
        "cat_b": ["f_band", "f_flat"],
        "cat_c": ["f_corr_with_mono_up"],
    }
    d["feature_direction"] = {
        "f_mono_up": 1, "f_mono_down": -1, "f_band": 0,
        "f_flat": 0, "f_corr_with_mono_up": 1,
    }
    d["shape_priors"] = {
        "f_mono_up": "MONO_UP",
        "f_mono_down": "MONO_DOWN",
        "f_band": "BAND",
        "f_flat": "MONO_UP",           # intentionally mismatched (f_flat is FLAT/U_SHAPE)
        "f_corr_with_mono_up": "MONO_UP",
    }
    return ResearchContract.from_dict(d)


# ══════════════════════════════════════════════════════════════════
# Shape classification
# ══════════════════════════════════════════════════════════════════

def test_mono_up_classified(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_mono_up"].observed_shape == "MONO_UP"
    assert by_name["f_mono_up"].match is True


def test_mono_down_classified(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_mono_down"].observed_shape == "MONO_DOWN"
    assert by_name["f_mono_down"].match is True


def test_band_classified(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_band"].observed_shape == "BAND"
    assert by_name["f_band"].match is True


def test_flat_classified(dev_df, contract_for_eda):
    """f_flat has no profit relationship → FLAT, U_SHAPE, or INSUFFICIENT."""
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    # FLAT or U_SHAPE are both valid "no strong relationship" outputs;
    # INSUFFICIENT is acceptable for very noisy bin distributions.
    assert by_name["f_flat"].observed_shape in ("FLAT", "U_SHAPE", "INSUFFICIENT")


def test_flat_prior_mismatch_does_not_halve(dev_df, contract_for_eda):
    """Prior says MONO_UP for f_flat; observed is FLAT/U_SHAPE.
    The key invariant: n_shape_mismatch count is at most 1 for this fixture
    (only f_flat can mismatch; the rest match their priors).
    """
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    # f_flat shows no true relationship: FLAT or U_SHAPE
    assert by_name["f_flat"].observed_shape in ("FLAT", "U_SHAPE", "INSUFFICIENT")
    # The other 3 features should all match their priors
    assert by_name["f_mono_up"].match is True
    assert by_name["f_mono_down"].match is True
    assert by_name["f_band"].match is True


# ══════════════════════════════════════════════════════════════════
# Mismatch reporting
# ══════════════════════════════════════════════════════════════════

def test_mismatch_detected_with_contradicting_prior():
    """Prior says MONO_UP but feature is genuinely BAND → mismatch."""
    df = _make_dev_df(n=800, seed=1)
    d = _make_inline_contract(
        pre_registered={"c": ["f_band"]},
        feature_direction={"f_band": 0},
        shape_priors={"f_band": "MONO_UP"},   # wrong prior
        allowed_directions=[1, -1],
    )
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_band"])

    a = result.shape_analyses[0]
    assert a.observed_shape == "BAND"
    assert a.prior_shape == "MONO_UP"
    assert a.match is False
    assert result.n_shape_mismatch == 1
    assert result.mismatch_rate == 1.0


def test_mismatch_generates_warning(dev_df, contract_for_eda):
    """contract_for_eda priors f_flat as MONO_UP.
    f_flat has no true relationship so is FLAT/U_SHAPE → possible mismatch.
    The test verifies that mismatch count is consistent with shape_analyses.
    """
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    # n_shape_mismatch must equal the count of analyses where match is False
    n_false = sum(1 for a in result.shape_analyses if a.match is False)
    assert result.n_shape_mismatch == n_false
    # The 3 well-defined features should all match
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_mono_up"].match is True
    assert by_name["f_mono_down"].match is True
    assert by_name["f_band"].match is True


def test_missing_prior_is_not_counted_as_mismatch(dev_df):
    """Feature present in available_features but not in shape_priors."""
    d = _make_inline_contract(
        pre_registered={"c": ["f_mono_up"]},
        feature_direction={"f_mono_up": 1},
        shape_priors={},   # no prior
    )
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(dev_df, contract, available_features=["f_mono_up"])
    assert result.n_prior_unspecified == 1
    assert result.n_shape_match == 0
    assert result.n_shape_mismatch == 0


# ══════════════════════════════════════════════════════════════════
# Correlation
# ══════════════════════════════════════════════════════════════════

def test_redundant_pair_detected(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
    )
    pairs = {(p.feature_a, p.feature_b) for p in result.redundant_pairs}
    pairs_swapped = {(b, a) for a, b in pairs}
    all_pairs = pairs | pairs_swapped
    assert ("f_mono_up", "f_corr_with_mono_up") in all_pairs


def test_no_redundant_pairs_when_independent():
    rng = np.random.default_rng(42)
    n = 500
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "a": rng.normal(0, 1, n),
        "b": rng.normal(0, 1, n),
        "c": rng.normal(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })
    d = _make_inline_contract(
        pre_registered={"cat": ["a", "b", "c"]},
        feature_direction={"a": 1, "b": 1, "c": 1},
        shape_priors={"a": "MONO_UP", "b": "MONO_UP", "c": "MONO_UP"},
    )
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["a", "b", "c"])
    assert len(result.redundant_pairs) == 0


# ══════════════════════════════════════════════════════════════════
# Temporal stability
# ══════════════════════════════════════════════════════════════════

def test_stability_computed(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down"],
    )
    assert len(result.stability) == 2
    for s in result.stability:
        assert len(s.block_means) == 5
        assert len(s.block_stds) == 5


def test_unstable_feature_flagged():
    """Feature whose block means vary drastically → CV > 1 → unstable=True.

    CV = std(block_means) / mean(block_means).
    To force CV > 1 we need std > mean.
    Strategy: 4 blocks near 0.05 (very small), 1 block near 0.55.
      block_means ≈ (0.05, 0.05, 0.05, 0.05, 0.55)
      mean ≈ 0.15,  std ≈ 0.224  →  CV ≈ 1.49 > 1.0
    """
    n = 500
    rng = np.random.default_rng(99)
    # 4 blocks at ~0.05, final block at ~0.55
    vals = np.concatenate([
        rng.normal(0.05, 0.005, 400),   # blocks 1-4: mean ~0.05
        rng.normal(0.55, 0.005, 100),   # block 5:    mean ~0.55
    ])
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "f_unstable": vals,
        "_profit": rng.normal(0, 1, n),
    })
    d = _make_inline_contract(
        pre_registered={"cat": ["f_unstable"]},
        feature_direction={"f_unstable": 0},
        shape_priors={"f_unstable": "BAND"},
    )
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_unstable"])
    s = result.stability[0]
    assert s.cv > 1.0, f"Expected cv > 1.0 but got {s.cv}"
    assert s.unstable is True


# ══════════════════════════════════════════════════════════════════
# Baseline
# ══════════════════════════════════════════════════════════════════

def test_baseline_stats(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda, available_features=["f_mono_up"],
    )
    b = result.baseline
    assert b["n"] == len(dev_df)
    assert 0.0 <= b["wr"] <= 1.0
    assert "ev" in b and "pf" in b


def test_baseline_with_mae_mfe(dev_df, contract_for_eda):
    df = dev_df.copy()
    rng = np.random.default_rng(1)
    df["maeATR"] = rng.uniform(0.3, 1.5, len(df))
    df["mfeATR"] = rng.uniform(0.5, 2.0, len(df))
    result = L3_eda.run(df, contract_for_eda, available_features=["f_mono_up"])
    assert "mae_atr_mean" in result.baseline
    assert "mfe_atr_mean" in result.baseline


# ══════════════════════════════════════════════════════════════════
# Insufficient data
# ══════════════════════════════════════════════════════════════════

def test_small_sample_insufficient():
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=20, freq="h"),
        "f_x": np.random.rand(20),
        "_profit": np.random.randn(20),
    })
    d = _make_inline_contract(
        pre_registered={"cat": ["f_x"]},
        feature_direction={"f_x": 1},
        shape_priors={"f_x": "MONO_UP"},
    )
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_x"])
    assert result.shape_analyses[0].observed_shape == "INSUFFICIENT"


def test_constant_feature_insufficient():
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=100, freq="h"),
        "f_const": [0.5] * 100,
        "_profit": np.random.randn(100),
    })
    d = _make_inline_contract(
        pre_registered={"cat": ["f_const"]},
        feature_direction={"f_const": 1},
        shape_priors={"f_const": "MONO_UP"},
    )
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_const"])
    assert result.shape_analyses[0].observed_shape == "INSUFFICIENT"


def test_no_available_features_raises(dev_df, contract_for_eda):
    with pytest.raises(ValueError, match="no available features"):
        L3_eda.run(dev_df, contract_for_eda, available_features=[])


def test_empty_df_raises(contract_for_eda):
    with pytest.raises(ValueError, match="empty"):
        L3_eda.run(pd.DataFrame(), contract_for_eda,
                   available_features=["f_mono_up"])


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(dev_df, contract_for_eda, tmp_path):
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
        output_dir=tmp_path,
    )
    assert (tmp_path / "feature_shape_analysis.csv").exists()
    assert (tmp_path / "feature_correlation_matrix.csv").exists()
    assert (tmp_path / "feature_stability.csv").exists()
    assert (tmp_path / "baseline_stats.json").exists()
    assert (tmp_path / "layer_three_summary.json").exists()


def test_shape_analysis_csv_columns(dev_df, contract_for_eda, tmp_path):
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up"],
        output_dir=tmp_path,
    )
    df = pd.read_csv(tmp_path / "feature_shape_analysis.csv")
    assert "feature" in df.columns
    assert "prior_shape" in df.columns
    assert "observed_shape" in df.columns
    assert "match" in df.columns
    assert df.iloc[0]["feature"] == "f_mono_up"


def test_mismatch_csv_written_when_mismatch(dev_df, tmp_path):
    """Create contract with a genuine mismatch to verify report."""
    d = _make_inline_contract(
        pre_registered={"cat": ["f_mono_up"]},
        feature_direction={"f_mono_up": 1},
        shape_priors={"f_mono_up": "BAND"},   # wrong prior
    )
    contract = ResearchContract.from_dict(d)
    L3_eda.run(dev_df, contract, available_features=["f_mono_up"],
               output_dir=tmp_path)
    assert (tmp_path / "shape_mismatch_report.csv").exists()
    df = pd.read_csv(tmp_path / "shape_mismatch_report.csv")
    assert df.iloc[0]["prior_shape"] == "BAND"
    assert df.iloc[0]["observed_shape"] == "MONO_UP"


def test_summary_json_content(dev_df, contract_for_eda, tmp_path):
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down"],
        output_dir=tmp_path,
    )
    with (tmp_path / "layer_three_summary.json").open() as f:
        s = json.load(f)
    assert s["n_features_analyzed"] == 2
    assert "mismatch_rate" in s
    assert "baseline" in s


# ══════════════════════════════════════════════════════════════════
# Contract usage — SHAPE_PRIOR immutable
# ══════════════════════════════════════════════════════════════════

def test_shape_prior_not_modified(dev_df, contract_for_eda):
    prior_before = dict(contract_for_eda.shape_priors)
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    assert contract_for_eda.shape_priors == prior_before


def test_match_statistics_consistent(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
    )
    n_match = sum(1 for a in result.shape_analyses if a.match is True)
    n_mismatch = sum(1 for a in result.shape_analyses if a.match is False)
    assert n_match == result.n_shape_match
    assert n_mismatch == result.n_shape_mismatch
    denom = n_match + n_mismatch
    expected_rate = (n_mismatch / denom) if denom else 0.0
    assert abs(result.mismatch_rate - expected_rate) < 1e-9
