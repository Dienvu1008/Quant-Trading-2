"""Tests for Layer 4b — Regime Block Discovery.

Key test strategy:
  - Inject a regime with genuinely negative EV → verify it is found.
  - Pure noise → verify nothing is found with strict thresholds.
  - Verify n_total mismatch warning fires when run_meta disagrees.
  - Test _apply_block_mask for all 4 rule types.
  - Test permutation test significance/non-significance.
  - Output roundtrip and file existence checks.
"""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.layers import L4b_regime_block_discovery as L4b
from vp_analysis.layers.L4b_regime_block_discovery import (
    RegimeBlockConfig,
    _apply_block_mask,
    _perm_test_block,
)


# ─── Helpers ─────────────────────────────────────────────────────

def _make_regime_df(n_per_regime: int = 80, seed: int = 0) -> pd.DataFrame:
    """Three regimes: FAILED_AUCTION has very negative EV, others positive.
    Regimes are interleaved across time so each walk-forward fold sees all of them.
    """
    rng = np.random.default_rng(seed)
    regimes = {
        "FAILED_AUCTION":     -8.0,   # genuinely bad regime
        "TREND_CONTINUATION":  3.0,
        "BALANCED_ROTATION":   0.5,
    }
    rows = []
    for reg, mean_profit in regimes.items():
        for _ in range(n_per_regime):
            rows.append({
                "symbol": "X",
                "setupType": "BO",
                "regimeName": reg,
                "_session": "1",
                "_ltBin": "LT_LOW",
                "auctFailure": 0.2,
                "_profit": mean_profit + rng.normal(0, 3),
            })
    df = pd.DataFrame(rows)
    # Shuffle so regimes are interleaved across time (critical for WF folds)
    df = df.sample(frac=1, random_state=int(seed)).reset_index(drop=True)
    df["time"] = pd.date_range("2024-01-01", periods=len(df), freq="5min")
    return df.sort_values("time").reset_index(drop=True)


def _make_noise_df(n: int = 300, seed: int = 42) -> pd.DataFrame:
    """No relationship between regime and profit. Interleaved across time."""
    rng = np.random.default_rng(seed)
    regimes = ["FAILED_AUCTION", "TREND_CONTINUATION", "BALANCED_ROTATION"]
    rows = [
        {
            "symbol": "X", "setupType": "BO",
            "regimeName": rng.choice(regimes),
            "_session": "1", "_ltBin": "LT_LOW",
            "auctFailure": 0.2,
            "_profit": rng.normal(0, 3),
        }
        for _ in range(n)
    ]
    df = pd.DataFrame(rows)
    df["time"] = pd.date_range("2024-01-01", periods=n, freq="5min")
    return df.sort_values("time").reset_index(drop=True)


def _run_meta(n_total: int = 50) -> dict:
    return {"n_total_hypotheses": {"regime_block": n_total}}


# ══════════════════════════════════════════════════════════════════
# Unit: _apply_block_mask
# ══════════════════════════════════════════════════════════════════

def test_apply_block_mask_auction_regime():
    n = 6
    regime = np.array(["A", "B", "A", "B", "A", "B"])
    rule = {"type": "auction_regime", "condition": "A", "key": "BO|regime|A"}
    mask = _apply_block_mask(
        np.full(n, "BO"), regime,
        np.full(n, "1"), np.zeros(n), np.full(n, "LT_LOW"),
        rule,
    )
    np.testing.assert_array_equal(mask, [True, False, True, False, True, False])


def test_apply_block_mask_auction_failure():
    n = 4
    fail = np.array([0.2, 0.8, 0.3, 0.9])
    rule = {
        "type": "auction_failure", "condition": "auctFailure>0.5",
        "key": "BO|failure",
    }
    mask = _apply_block_mask(
        np.full(n, "BO"), np.full(n, "X"),
        np.full(n, "1"), fail, np.full(n, "LT_LOW"),
        rule,
    )
    np.testing.assert_array_equal(mask, [False, True, False, True])


def test_apply_block_mask_regime_session():
    n = 4
    regime = np.array(["A", "A", "B", "A"])
    session = np.array(["1", "2", "1", "1"])
    rule = {
        "type": "regime_session", "condition": "A+1",
        "key": "BO|regime_sess|A+1",
    }
    mask = _apply_block_mask(
        np.full(n, "BO"), regime,
        session, np.zeros(n), np.full(n, "LT_LOW"),
        rule,
    )
    np.testing.assert_array_equal(mask, [True, False, False, True])


def test_apply_block_mask_regime_lt():
    n = 4
    regime = np.array(["A", "A", "B", "A"])
    lt = np.array(["LT_HIGH", "LT_LOW", "LT_HIGH", "LT_HIGH"])
    rule = {
        "type": "regime_lt_transition", "condition": "A+LT_HIGH",
        "key": "BO|regime_lt|A+LT_HIGH",
    }
    mask = _apply_block_mask(
        np.full(n, "BO"), regime,
        np.full(n, "1"), np.zeros(n), lt,
        rule,
    )
    np.testing.assert_array_equal(mask, [True, False, False, True])


def test_apply_block_mask_unknown_type_returns_false():
    n = 3
    rule = {"type": "unknown_rule", "condition": "X", "key": "k"}
    mask = _apply_block_mask(
        np.full(n, "BO"), np.full(n, "X"),
        np.full(n, "1"), np.zeros(n), np.full(n, "LT_LOW"),
        rule,
    )
    assert not mask.any()


# ══════════════════════════════════════════════════════════════════
# Unit: permutation test
# ══════════════════════════════════════════════════════════════════

def test_perm_test_block_clearly_negative():
    """Very negative blocked group → p should be very small."""
    rng = np.random.default_rng(0)
    profits = np.concatenate([
        rng.normal(-5, 1, 50),    # first 50: very negative = "blocked"
        rng.normal(2, 1, 200),    # rest: positive
    ])
    observed = float(profits[:50].mean())
    p = _perm_test_block(profits, 50, observed, RegimeBlockConfig(perm_iterations=300))
    assert p < 0.05, f"Expected p < 0.05 for clearly negative blocked group, got {p:.4f}"


def test_perm_test_block_not_significant():
    """Pure noise blocked group → p should be large."""
    rng = np.random.default_rng(1)
    profits = rng.normal(0, 2, 200)
    observed = float(profits[:50].mean())
    p = _perm_test_block(profits, 50, observed, RegimeBlockConfig(perm_iterations=300))
    assert p > 0.15, f"Expected p > 0.15 for noise, got {p:.4f}"


# ══════════════════════════════════════════════════════════════════
# Integration: signal discovery
# ══════════════════════════════════════════════════════════════════

def test_discovers_bad_regime():
    """FAILED_AUCTION with EV=-8 should be discovered."""
    df = _make_regime_df(n_per_regime=100, seed=0)
    cfg = RegimeBlockConfig(
        outer_folds=4,
        min_train_samples=10, min_val_samples=8, min_block_samples=8,
        min_pass_samples=8,
        min_ev_improvement=0.5,
        fold_consistency_threshold=0.60,
    )
    result = L4b.run(df, _run_meta(), config=cfg)
    blocked_conditions = [c.condition for c in result.candidates]
    assert "FAILED_AUCTION" in blocked_conditions, (
        f"FAILED_AUCTION not found, got: {blocked_conditions}"
    )
    fa = next(c for c in result.candidates if c.condition == "FAILED_AUCTION")
    assert fa.mean_blocked_ev < 0
    assert fa.mean_lift > 0


def test_noise_not_discovered():
    """Pure noise should produce no candidates with strict thresholds."""
    df = _make_noise_df(n=400, seed=99)
    cfg = RegimeBlockConfig(
        min_ev_improvement=1.0,        # very strict
        fold_consistency_threshold=0.80,
    )
    result = L4b.run(df, _run_meta(), config=cfg)
    assert len(result.candidates) == 0, (
        f"Expected 0 candidates on noise, got {len(result.candidates)}: "
        f"{[c.condition for c in result.candidates]}"
    )


def test_n_total_mismatch_warning():
    """Provide run_meta with wildly different n_total → should trigger warning."""
    df = _make_regime_df(n_per_regime=60, seed=5)
    meta = {"n_total_hypotheses": {"regime_block": 1000}}
    result = L4b.run(df, meta)
    has_warning = any("differs from run_meta" in w for w in result.warnings)
    assert has_warning, f"Expected mismatch warning, got warnings: {result.warnings}"


def test_small_group_skipped():
    """Group with too few rows → warning, no crash."""
    df = _make_regime_df(n_per_regime=3, seed=0)  # 9 rows total, far below threshold
    result = L4b.run(df, _run_meta())
    assert any("skipped" in w for w in result.warnings)
    assert len(result.candidates) == 0


def test_missing_regime_column_falls_back():
    """No regimeName or auctRegime → layer should not crash, just find nothing."""
    rng = np.random.default_rng(7)
    df = pd.DataFrame({
        "symbol": ["X"] * 200,
        "setupType": ["BO"] * 200,
        "_profit": rng.normal(0, 1, 200),
        "time": pd.date_range("2024-01-01", periods=200, freq="5min"),
    })
    # No regime column at all → regimeName defaults to "UNKNOWN"
    result = L4b.run(df, _run_meta())
    # Should complete without crash; no candidates expected
    assert isinstance(result.candidates, tuple)


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_df_raises():
    with pytest.raises(ValueError, match="empty"):
        L4b.run(pd.DataFrame(), _run_meta())


def test_missing_profit_column_raises():
    df = _make_regime_df().drop(columns=["_profit"])
    with pytest.raises(ValueError, match="_profit"):
        L4b.run(df, _run_meta())


def test_n_hypotheses_attempted_positive():
    """n_hypotheses_attempted should reflect enumerated hypotheses."""
    df = _make_regime_df(n_per_regime=100, seed=0)
    result = L4b.run(df, _run_meta())
    assert result.n_hypotheses_attempted > 0


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_output_dict_roundtrip():
    df = _make_regime_df(n_per_regime=80, seed=2)
    cfg = RegimeBlockConfig(
        min_ev_improvement=0.5, fold_consistency_threshold=0.60,
        outer_folds=4, min_train_samples=10, min_val_samples=8,
        min_block_samples=8, min_pass_samples=8,
    )
    result = L4b.run(df, _run_meta(), config=cfg)
    if result.candidates:
        d = result.candidates[0].to_dict()
        for key in [
            "symbol", "setup", "rule_type", "condition",
            "mean_blocked_ev", "mean_lift", "combined_p",
            "fold_consistency", "n_folds",
        ]:
            assert key in d, f"Missing key in to_dict(): {key}"


def test_outputs_written(tmp_path):
    df = _make_regime_df(n_per_regime=80, seed=3)
    cfg = RegimeBlockConfig(
        min_ev_improvement=0.5, fold_consistency_threshold=0.60,
        outer_folds=4, min_train_samples=10, min_val_samples=8,
        min_block_samples=8, min_pass_samples=8,
    )
    L4b.run(df, _run_meta(), output_dir=tmp_path, config=cfg)
    assert (tmp_path / "regime_block_discovery_summary.json").exists()
    with (tmp_path / "regime_block_discovery_summary.json").open() as fh:
        s = json.load(fh)
    assert "n_candidates" in s
    assert "n_hypotheses_attempted" in s
    assert "warnings" in s


def test_candidate_csv_columns(tmp_path):
    df = _make_regime_df(n_per_regime=100, seed=0)
    cfg = RegimeBlockConfig(
        min_ev_improvement=0.5, fold_consistency_threshold=0.60,
        outer_folds=4, min_train_samples=10, min_val_samples=8,
        min_block_samples=8, min_pass_samples=8,
    )
    result = L4b.run(df, _run_meta(), output_dir=tmp_path, config=cfg)
    if result.candidates:
        csv_path = tmp_path / "regime_block_candidates.csv"
        assert csv_path.exists()
        df_out = pd.read_csv(csv_path)
        expected = {
            "symbol", "setup", "rule_type", "condition",
            "mean_blocked_ev", "mean_pass_ev", "mean_lift",
            "fold_consistency", "combined_p",
        }
        assert expected.issubset(set(df_out.columns))


# ══════════════════════════════════════════════════════════════════
# Summary dict
# ══════════════════════════════════════════════════════════════════

def test_summary_dict_keys():
    df = _make_regime_df(n_per_regime=80, seed=0)
    result = L4b.run(df, _run_meta())
    s = result.summary_dict()
    for key in ["ran_at", "n_hypotheses_attempted", "n_candidates",
                "n_symbols", "n_setups", "warnings"]:
        assert key in s, f"Missing key in summary_dict: {key}"
