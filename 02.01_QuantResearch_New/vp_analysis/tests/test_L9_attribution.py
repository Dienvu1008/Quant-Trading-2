"""Tests for Layer 9 — Attribution."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.frozen_types import FrozenProductionConfig, FrozenRule
from vp_analysis.layers.L9_attribution import (
    AttributionConfig,
    _cross_style_consistency,
    _entry_exit_attribution,
    _exit_policy_decomposition,
    _relative_range,
    run,
)


# ─── Helpers ─────────────────────────────────────────────────────

def _make_rule(rule_id="R-00001", feature="f_signal", lower=0.5):
    return FrozenRule(
        rule_id=rule_id, experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD", setup="BOS",
        gate_type="threshold", direction=1,
        features=(feature,), lower_bound=lower, upper_bound=None,
        fdr_significant=True,
    )


def _make_prod_config(rules):
    return FrozenProductionConfig(
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        rules=tuple(rules), sl_tp_selections=(), sizing_configs=(),
    )


def _make_holdout(n=400, seed=0):
    rng = np.random.default_rng(seed)
    f = rng.uniform(0, 1, n)
    styles = rng.choice([-1, 0, 1], size=n)
    mae = rng.uniform(0.3, 2.0, n)
    mfe = rng.uniform(0.5, 2.5, n)
    profit = np.where(f > 0.5, 1.0, -0.5) + rng.normal(0, 0.3, n)
    return pd.DataFrame({
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": f, "trailStyle": styles,
        "maeATR": mae, "mfeATR": mfe, "_profit": profit,
        "time": pd.date_range("2025-01-01", periods=n, freq="h"),
    })


# ══════════════════════════════════════════════════════════════════
# Entry vs Exit attribution
# ══════════════════════════════════════════════════════════════════

def test_entry_exit_runs():
    df = _make_holdout(n=400)
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    ee = _entry_exit_attribution(rule, gated, AttributionConfig())
    assert ee is not None
    assert ee.n_trades > 0
    assert ee.mfe_mae_ratio > 0


def test_entry_exit_strong_classification():
    """MFE >> MAE → 'strong' entry."""
    rng = np.random.default_rng(1)
    n = 200
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "maeATR": np.full(n, 0.5),
        "mfeATR": np.full(n, 2.0),  # ratio = 4.0 ≥ 2.0
        "_profit": rng.normal(0.5, 0.3, n),
    })
    rule = _make_rule()
    ee = _entry_exit_attribution(rule, df, AttributionConfig())
    assert ee.entry_quality == "strong"


def test_entry_exit_weak_classification():
    """MAE > MFE → 'weak' entry."""
    rng = np.random.default_rng(2)
    n = 200
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "maeATR": np.full(n, 1.5),
        "mfeATR": np.full(n, 0.5),  # ratio ≈ 0.33
        "_profit": rng.normal(-0.2, 0.3, n),
    })
    rule = _make_rule()
    ee = _entry_exit_attribution(rule, df, AttributionConfig())
    assert ee.entry_quality == "weak"


def test_entry_exit_skipped_without_mae_mfe():
    df = _make_holdout(n=200).drop(columns=["maeATR", "mfeATR"])
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    ee = _entry_exit_attribution(rule, gated, AttributionConfig())
    assert ee is None


# ══════════════════════════════════════════════════════════════════
# Exit policy decomposition
# ══════════════════════════════════════════════════════════════════

def test_exit_policy_three_styles():
    df = _make_holdout(n=400)
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    ep = _exit_policy_decomposition(
        rule, gated, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert ep is not None
    assert len(ep.ev_by_style) >= 2


def test_exit_policy_rescues_detection():
    """Style -1 EV < 0, style 1 EV > 0 → rescues=True."""
    rng = np.random.default_rng(3)
    n = 300
    styles = rng.choice([-1, 0, 1], size=n)
    profit = np.where(styles == -1, -0.5, 1.0) + rng.normal(0, 0.2, n)
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "trailStyle": styles,
        "_profit": profit,
    })
    rule = _make_rule()
    ep = _exit_policy_decomposition(
        rule, df, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert ep is not None
    assert ep.trail_rescues_negative_entry is True


def test_exit_policy_no_rescue_when_all_positive():
    """All styles positive → no rescue."""
    rng = np.random.default_rng(0)
    n = 300
    styles = rng.choice([-1, 0, 1], size=n)
    profit = np.abs(rng.normal(0.5, 0.2, n))  # all positive
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "trailStyle": styles,
        "_profit": profit,
    })
    rule = _make_rule()
    ep = _exit_policy_decomposition(
        rule, df, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    if ep:
        assert not ep.trail_rescues_negative_entry


# ══════════════════════════════════════════════════════════════════
# Cross-style consistency
# ══════════════════════════════════════════════════════════════════

def test_cross_style_consistency_runs():
    df = _make_holdout(n=400)
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    sc = _cross_style_consistency(
        rule, gated, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert sc is not None


def test_cross_style_identical_values_consistent():
    """Identical MAE/MFE across styles → consistent."""
    rng = np.random.default_rng(4)
    n = 200
    styles = rng.choice([-1, 0, 1], size=n)
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "trailStyle": styles,
        "maeATR": np.full(n, 1.0),
        "mfeATR": np.full(n, 1.5),
        "_profit": rng.normal(0.3, 0.2, n),
    })
    rule = _make_rule()
    sc = _cross_style_consistency(
        rule, df, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert sc is not None
    assert sc.mae_consistent
    assert sc.mfe_consistent


def test_relative_range_same_values():
    assert _relative_range([1.0, 1.0, 1.0]) == pytest.approx(0.0)


def test_relative_range_spread():
    assert _relative_range([1.0, 2.0]) == pytest.approx(0.5)


def test_relative_range_single():
    assert _relative_range([1.0]) is None


# ══════════════════════════════════════════════════════════════════
# Integration
# ══════════════════════════════════════════════════════════════════

def test_full_run_writes_outputs(tmp_path):
    df = _make_holdout(n=400)
    rule = _make_rule()
    config = _make_prod_config([rule])
    run(df, config, output_dir=tmp_path)
    assert (tmp_path / "entry_exit_attribution.csv").exists()
    assert (tmp_path / "exit_policy_decomposition.csv").exists()
    assert (tmp_path / "style_consistency.csv").exists()
    assert (tmp_path / "attribution_summary.json").exists()


def test_empty_holdout_raises():
    rule = _make_rule()
    config = _make_prod_config([rule])
    with pytest.raises(ValueError, match="empty"):
        run(pd.DataFrame(), config)


def test_missing_style_column_warns():
    df = _make_holdout(n=200).drop(columns=["trailStyle"])
    rule = _make_rule()
    config = _make_prod_config([rule])
    result = run(df, config)
    assert any("trailStyle" in w for w in result.warnings)
