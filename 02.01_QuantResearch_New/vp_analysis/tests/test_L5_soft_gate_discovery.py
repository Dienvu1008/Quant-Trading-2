"""Tests for Layer 5 — Soft Gate Discovery."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L5_soft_gate_discovery
from vp_analysis.layers.L5_soft_gate_discovery import (
    SoftGateConfig,
    _extract_directions,
    _permutation_soft_gate,
    _test_soft_gate,
    _build_feature_category_map,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def soft_contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "cat_a": ["f_signal_up", "f_signal_down"],
        "cat_b": ["f_noise"],
    }
    d["feature_direction"] = {
        "f_signal_up": 1, "f_signal_down": -1, "f_noise": 0,
    }
    d["shape_priors"] = {
        "f_signal_up": "MONO_UP",
        "f_signal_down": "MONO_DOWN",
        "f_noise": "MONO_UP",
    }
    return ResearchContract.from_dict(d)


def _make_soft_signal_df(n: int = 400, seed: int = 0, strength: float = 0.8) -> pd.DataFrame:
    """f_signal_up positively correlated with profit.
    f_signal_down negatively correlated. f_noise independent.
    """
    rng = np.random.default_rng(seed)
    f_up = rng.uniform(0, 1, n)
    f_down = rng.uniform(0, 1, n)
    f_noise = rng.uniform(0, 1, n)
    noise = rng.normal(0, 0.4, n)
    profit = (
        strength * (f_up - 0.5)
        - strength * (f_down - 0.5)
        + noise
    )
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal_up": f_up,
        "f_signal_down": f_down,
        "f_noise": f_noise,
        "_profit": profit,
    })


def _make_pure_noise_df(n: int = 400, seed: int = 42) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal_up": rng.uniform(0, 1, n),
        "f_signal_down": rng.uniform(0, 1, n),
        "f_noise": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })


# ══════════════════════════════════════════════════════════════════
# Direction extraction
# ══════════════════════════════════════════════════════════════════

def test_direction_positive_signal(soft_contract):
    df = _make_soft_signal_df(n=400, seed=0)
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, _ = _extract_directions(
        df, ["f_signal_up", "f_signal_down", "f_noise"],
        feature_cat, SoftGateConfig(),
    )
    by_name = {d.feature: d for d in directions}
    assert by_name["f_signal_up"].direction == 1
    assert by_name["f_signal_up"].dev_spearman_rho > 0


def test_direction_negative_signal(soft_contract):
    df = _make_soft_signal_df(n=400, seed=0)
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, _ = _extract_directions(
        df, ["f_signal_up", "f_signal_down", "f_noise"],
        feature_cat, SoftGateConfig(),
    )
    by_name = {d.feature: d for d in directions}
    assert by_name["f_signal_down"].direction == -1
    assert by_name["f_signal_down"].dev_spearman_rho < 0


def test_direction_constant_feature_skipped(soft_contract):
    df = _make_soft_signal_df(n=400, seed=0)
    df["f_const"] = 0.5
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, warnings = _extract_directions(
        df, ["f_const"], feature_cat, SoftGateConfig(),
    )
    assert len(directions) == 0
    assert any("zero variance" in w for w in warnings)


def test_direction_min_samples_skipped(soft_contract):
    df = _make_soft_signal_df(n=20, seed=0)
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, warnings = _extract_directions(
        df, ["f_signal_up"], feature_cat,
        SoftGateConfig(min_total_samples=100),
    )
    assert len(directions) == 0
    assert any("valid rows" in w for w in warnings)


# ══════════════════════════════════════════════════════════════════
# Permutation test
# ══════════════════════════════════════════════════════════════════

def test_permutation_significant_when_signal_present():
    rng = np.random.default_rng(0)
    n = 200
    signal = rng.uniform(0, 1, n)
    profits = signal * 2.0 + rng.normal(0, 0.5, n)
    med = float(np.median(signal))
    top = signal > med
    bot = signal < med
    obs_lift = float(profits[top].mean() - profits[bot].mean())
    p = _permutation_soft_gate(
        profits, top, bot, obs_lift,
        SoftGateConfig(perm_iterations=500, seed=0),
    )
    assert p < 0.05, f"Expected p < 0.05 for strong signal, got {p:.4f}"


def test_permutation_not_significant_when_no_signal():
    rng = np.random.default_rng(1)
    n = 200
    signal = rng.uniform(0, 1, n)
    profits = rng.normal(0, 1, n)
    med = float(np.median(signal))
    top = signal > med
    bot = signal < med
    obs_lift = float(profits[top].mean() - profits[bot].mean())
    p = _permutation_soft_gate(
        profits, top, bot, obs_lift,
        SoftGateConfig(perm_iterations=500, seed=1),
    )
    assert p > 0.10, f"Expected p > 0.10 for noise, got {p:.4f}"


# ══════════════════════════════════════════════════════════════════
# Full discovery integration
# ══════════════════════════════════════════════════════════════════

def test_discovers_strong_soft_signal(soft_contract):
    """Strong signal (strength=1.5) should be discovered at perm_alpha=0.05."""
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down", "f_noise"],
        config=SoftGateConfig(perm_alpha=0.05),
    )
    candidate_features = {c.feature for c in result.candidates}
    assert "f_signal_up" in candidate_features, (
        f"f_signal_up not found in {candidate_features}"
    )
    assert "f_signal_down" in candidate_features, (
        f"f_signal_down not found in {candidate_features}"
    )


def test_noise_not_discovered(soft_contract):
    """Pure noise should not produce candidates at strict alpha=0.01."""
    df = _make_pure_noise_df(n=600, seed=42)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down", "f_noise"],
        config=SoftGateConfig(perm_alpha=0.01),
    )
    assert len(result.candidates) == 0, (
        f"Expected 0 candidates on noise, got {len(result.candidates)}: "
        f"{[c.feature for c in result.candidates]}"
    )


def test_direction_frozen_in_candidates(soft_contract):
    """Direction in each candidate must match what _extract_directions computed."""
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down"],
        config=SoftGateConfig(perm_alpha=0.05),
    )
    dir_lookup = {d.feature: d for d in result.directions}
    for c in result.candidates:
        assert c.direction == dir_lookup[c.feature].direction, (
            f"{c.feature}: candidate direction={c.direction} "
            f"!= extracted direction={dir_lookup[c.feature].direction}"
        )


# ══════════════════════════════════════════════════════════════════
# Holdout untouched invariant
# ══════════════════════════════════════════════════════════════════

def test_L5_never_touches_holdout(soft_contract):
    """L5 operates only on the passed dev_df. Verify candidate row counts
    don't exceed what we passed in.
    """
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up"],
        config=SoftGateConfig(perm_alpha=0.10),
    )
    for c in result.candidates:
        assert c.n_total <= len(df), (
            f"n_total={c.n_total} > len(df)={len(df)} — impossible if only dev used"
        )
        assert c.n_top + c.n_bottom <= c.n_total


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(soft_contract, tmp_path):
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down", "f_noise"],
        output_dir=tmp_path,
        config=SoftGateConfig(perm_alpha=0.10),
    )
    assert (tmp_path / "soft_gate_directions.csv").exists()
    assert (tmp_path / "soft_gate_discovery_summary.json").exists()
    with (tmp_path / "soft_gate_discovery_summary.json").open() as fh:
        summary = json.load(fh)
    assert summary["n_features_evaluated"] == 3


def test_candidates_csv_written_when_significant(soft_contract, tmp_path):
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down"],
        output_dir=tmp_path,
        config=SoftGateConfig(perm_alpha=0.10),
    )
    if result.candidates:
        assert (tmp_path / "soft_gate_candidates.csv").exists()
        df_out = pd.read_csv(tmp_path / "soft_gate_candidates.csv")
        expected_cols = {
            "symbol", "setup", "feature", "direction",
            "ev_top", "ev_bottom", "ev_lift",
            "perm_pvalue", "n_top", "n_bottom",
        }
        assert expected_cols.issubset(set(df_out.columns))


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_df_raises(soft_contract):
    with pytest.raises(ValueError, match="empty"):
        L5_soft_gate_discovery.run(
            pd.DataFrame(), soft_contract,
            available_features=["f_signal_up"],
        )


def test_missing_profit_column_raises(soft_contract):
    df = _make_soft_signal_df(n=200).drop(columns=["_profit"])
    with pytest.raises(ValueError, match="_profit"):
        L5_soft_gate_discovery.run(
            df, soft_contract, available_features=["f_signal_up"],
        )


def test_no_usable_features_returns_empty(soft_contract):
    df = _make_soft_signal_df(n=200)
    result = L5_soft_gate_discovery.run(
        df, soft_contract, available_features=["missing_feature"],
    )
    assert result.n_features_evaluated == 0
    assert len(result.candidates) == 0
    assert any("No usable features" in w for w in result.warnings)


def test_small_group_skipped(soft_contract):
    """Group smaller than min_total_samples generates a warning."""
    df = _make_soft_signal_df(n=200, seed=0).iloc[:30].copy()
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up"],
        config=SoftGateConfig(min_total_samples=100),
    )
    assert any("skipped" in w for w in result.warnings)
