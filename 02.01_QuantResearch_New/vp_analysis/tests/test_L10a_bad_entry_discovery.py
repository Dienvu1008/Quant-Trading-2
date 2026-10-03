"""Tests for Layer 10a — Bad Entry Discovery.

Key test strategy:
  - MFE canary label uses max(mfeATR across 3 styles) < threshold.
  - Features that predict low-MFE entries should be discovered.
  - Pure noise features should not be discovered.
  - n_total_hypotheses counts all screened hypotheses (for FDR padding).
  - Output files written correctly.
"""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L10a_bad_entry_discovery import (
    BadEntryDiscoveryConfig,
    _build_mfe_canary_labels,
    _screen_features,
    _test_region,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    return ResearchContract.from_dict(minimal_contract_dict)


def _make_3style_df(n_signals: int = 100, seed: int = 0,
                    bad_feature: bool = True) -> pd.DataFrame:
    """3 rows per signal (styles -1, 0, 1).

    If bad_feature=True: f_bad high → low MFE (bad entry label).
    f_noise is always random.
    """
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(n_signals):
        sig_id = f"SIG-{i:05d}"
        t = pd.Timestamp("2024-01-01") + pd.Timedelta(hours=i)
        f_bad = rng.uniform(0, 1)
        f_noise = rng.uniform(0, 1)
        entry_price = 2000.0

        # Bad entries have low MFE when f_bad is high
        if bad_feature and f_bad > 0.7:
            base_mfe = rng.uniform(0.1, 0.5)    # below 1.0 threshold
            base_profit = -0.5
        else:
            base_mfe = rng.uniform(1.2, 3.0)    # above 1.0 threshold
            base_profit = 0.5

        for style in (-1, 0, 1):
            mfe = base_mfe * rng.uniform(0.8, 1.2)
            mae = rng.uniform(0.3, 1.5)
            profit = base_profit + rng.normal(0, 0.2)
            rows.append({
                "signalId": sig_id,
                "trailStyle": style,
                "entryTime": t,
                "time": t,
                "symbol": "XAUUSD",
                "setupType": "BOS",
                "entryPrice": entry_price,
                "maeATR": mae,
                "mfeATR": mfe,
                "f_bad": f_bad,
                "f_noise": f_noise,
                "_profit": profit,
                "profitUSD": profit,
            })
    df = pd.DataFrame(rows)
    return df.sort_values("time").reset_index(drop=True)


# ══════════════════════════════════════════════════════════════════
# Canary label building
# ══════════════════════════════════════════════════════════════════

def test_canary_labels_bad_rate_nonzero(contract):
    """With bad_feature=True, some signals should get bad label."""
    df = _make_3style_df(n_signals=100, seed=0, bad_feature=True)
    cfg = BadEntryDiscoveryConfig(mfe_threshold_override=1.0)
    warnings = []
    stats, labels = _build_mfe_canary_labels(df, 1.0, cfg, warnings)
    assert stats.n_labeled == 100
    assert stats.n_bad > 0
    assert stats.n_good > 0
    assert 0 < stats.base_bad_rate < 1.0


def test_canary_labels_high_threshold_all_bad(contract):
    """Threshold of 100 ATR → all signals labeled bad."""
    df = _make_3style_df(n_signals=50, seed=1)
    cfg = BadEntryDiscoveryConfig(mfe_threshold_override=100.0)
    warnings = []
    stats, labels = _build_mfe_canary_labels(df, 100.0, cfg, warnings)
    assert stats.n_bad == stats.n_labeled
    assert stats.base_bad_rate == pytest.approx(1.0)


def test_canary_labels_zero_threshold_all_good(contract):
    """Threshold of 0 ATR → all signals labeled good."""
    df = _make_3style_df(n_signals=50, seed=2)
    cfg = BadEntryDiscoveryConfig(mfe_threshold_override=0.0)
    warnings = []
    stats, labels = _build_mfe_canary_labels(df, 0.0, cfg, warnings)
    assert stats.n_bad == 0
    assert stats.base_bad_rate == 0.0


def test_canary_uses_max_mfe_across_styles(contract):
    """Max MFE across 3 styles should be used, not first style."""
    rows = []
    # Signal where style=-1 has MFE=0.5 but style=1 has MFE=2.0
    for style, mfe in [(-1, 0.5), (0, 0.8), (1, 2.0)]:
        rows.append({
            "signalId": "SIG-X", "trailStyle": style,
            "mfeATR": mfe, "_profit": 0.1,
        })
    df = pd.DataFrame(rows)
    cfg = BadEntryDiscoveryConfig(mfe_threshold_override=1.0)
    warnings = []
    stats, labels = _build_mfe_canary_labels(df, 1.0, cfg, warnings)
    # max MFE = 2.0 >= 1.0 → signal is GOOD (label=0)
    assert labels.loc["SIG-X"] == 0


def test_canary_missing_mfe_column_warns(contract):
    df = _make_3style_df(n_signals=30).drop(columns=["mfeATR"])
    cfg = BadEntryDiscoveryConfig(mfe_threshold_override=1.0)
    warnings = []
    stats, labels = _build_mfe_canary_labels(df, 1.0, cfg, warnings)
    assert any("mfeATR" in w for w in warnings)
    assert stats.n_labeled == 0


# ══════════════════════════════════════════════════════════════════
# Feature screening
# ══════════════════════════════════════════════════════════════════

def test_screen_finds_predictive_feature(contract):
    """f_bad high extreme should have elevated bad rate."""
    df = _make_3style_df(n_signals=200, seed=0, bad_feature=True)
    cfg = BadEntryDiscoveryConfig(
        mfe_threshold_override=1.0, min_region_samples=10,
    )
    warnings = []
    stats, labels = _build_mfe_canary_labels(df, 1.0, cfg, warnings)

    # Build per-signal df
    per_sig = df.drop_duplicates(subset=["signalId"], keep="first").copy()
    per_sig["_is_bad"] = per_sig["signalId"].map(labels).fillna(0).astype(int)

    candidates = _screen_features(
        per_sig, ["f_bad", "f_noise"], stats.base_bad_rate, cfg,
    )
    # f_bad high extreme should appear with lift > 1
    hi_ext = [c for c in candidates
              if c.feature == "f_bad" and c.rule_type == "high_extreme"]
    assert len(hi_ext) >= 1
    assert hi_ext[0].lift > 1.0


def test_screen_noise_feature_low_lift(contract):
    """f_noise should not have systematic lift."""
    df = _make_3style_df(n_signals=200, seed=5, bad_feature=True)
    cfg = BadEntryDiscoveryConfig(
        mfe_threshold_override=1.0, min_region_samples=10,
    )
    warnings = []
    stats, labels = _build_mfe_canary_labels(df, 1.0, cfg, warnings)
    per_sig = df.drop_duplicates(subset=["signalId"], keep="first").copy()
    per_sig["_is_bad"] = per_sig["signalId"].map(labels).fillna(0).astype(int)

    candidates = _screen_features(
        per_sig, ["f_noise"], stats.base_bad_rate, cfg,
    )
    # Noise candidates should have p > 0.10 generally
    if candidates:
        # At least some should be non-significant
        avg_p = np.mean([c.pvalue for c in candidates])
        assert avg_p > 0.05  # not all significant for pure noise


def test_region_test_lift_calculation():
    """Test that lift = bad_rate_in_region / base_bad_rate."""
    y = np.array([1, 1, 1, 0, 0, 0, 0, 0, 0, 0])  # 3/10 = 0.3 in region
    mask = np.array([True] * 3 + [False] * 7)
    base_rate = 0.1  # base 10%
    cand = _test_region("f", "high_extreme", None, 0.8, mask, y, base_rate)
    assert cand.bad_rate_in_region == pytest.approx(1.0)  # 3/3 = 1.0
    assert cand.lift == pytest.approx(10.0)  # 1.0 / 0.1


# ══════════════════════════════════════════════════════════════════
# Full run integration
# ══════════════════════════════════════════════════════════════════

def test_full_run_discovers_bad_feature(contract):
    """Strong bad-entry signal should be discovered."""
    df = _make_3style_df(n_signals=200, seed=0, bad_feature=True)
    result = run(
        df, contract,
        available_features=["f_bad", "f_noise"],
        config=BadEntryDiscoveryConfig(
            mfe_threshold_override=1.0,
            min_region_samples=10,
            binom_alpha=0.20,
        ),
    )
    assert result.canary_stats.n_bad > 0
    assert result.n_total_hypotheses > 0
    # f_bad should appear in candidates
    feature_names = {c.feature for c in result.bad_entry_candidates}
    assert "f_bad" in feature_names


def test_full_run_noise_produces_no_filtered_candidates(contract):
    """Pure noise → no candidates should pass strict alpha."""
    df = _make_3style_df(n_signals=200, seed=99, bad_feature=False)
    result = run(
        df, contract,
        available_features=["f_noise"],
        config=BadEntryDiscoveryConfig(
            mfe_threshold_override=1.0,
            min_region_samples=10,
            binom_alpha=0.01,  # strict
        ),
    )
    # filter_spec should have no features passing strict alpha
    assert len(result.filter_spec["features"]) == 0


def test_n_total_hypotheses_correct(contract):
    """n_total_hypotheses = number of (feature, region) pairs tested."""
    df = _make_3style_df(n_signals=200, seed=0)
    result = run(
        df, contract,
        available_features=["f_bad", "f_noise"],
        config=BadEntryDiscoveryConfig(
            mfe_threshold_override=1.0, min_region_samples=5,
        ),
    )
    # Each feature can produce up to 3 candidates (low, high, mid)
    # So n_total_hypotheses <= 2 * 3 = 6
    assert 0 <= result.n_total_hypotheses <= 6


def test_full_run_mfe_threshold_from_contract(contract):
    """Without override, should use contract.bad_entry_canary_target."""
    df = _make_3style_df(n_signals=100, seed=0)
    result = run(
        df, contract,
        available_features=["f_bad"],
        config=BadEntryDiscoveryConfig(),  # no override → use contract
    )
    # Should run without crash; threshold defaults to 1.0 from contract def
    assert result.canary_stats.mfe_threshold == pytest.approx(1.0)


# ══════════════════════════════════════════════════════════════════
# Output files
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(contract, tmp_path):
    df = _make_3style_df(n_signals=100, seed=0, bad_feature=True)
    run(
        df, contract,
        available_features=["f_bad", "f_noise"],
        output_dir=tmp_path,
        config=BadEntryDiscoveryConfig(
            mfe_threshold_override=1.0, min_region_samples=5,
        ),
    )
    assert (tmp_path / "canary_labels.json").exists()
    assert (tmp_path / "composite_bad_filter_candidate.json").exists()
    assert (tmp_path / "L10a_summary.json").exists()


def test_summary_content(contract, tmp_path):
    df = _make_3style_df(n_signals=100, seed=0)
    run(
        df, contract,
        available_features=["f_bad"],
        output_dir=tmp_path,
        config=BadEntryDiscoveryConfig(mfe_threshold_override=1.0),
    )
    with (tmp_path / "L10a_summary.json").open() as fh:
        s = json.load(fh)
    assert "n_candidates_pre_fdr" in s
    assert "n_total_hypotheses" in s
    assert "canary_stats" in s


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_df_raises(contract):
    with pytest.raises(ValueError, match="empty"):
        run(pd.DataFrame(), contract, available_features=["f_bad"])


def test_insufficient_signals_skips_screening(contract):
    """Too few signals → screening skipped, no candidates."""
    df = _make_3style_df(n_signals=5)  # very few
    result = run(
        df, contract,
        available_features=["f_bad"],
        config=BadEntryDiscoveryConfig(
            mfe_threshold_override=1.0, min_region_samples=20,
        ),
    )
    assert len(result.bad_entry_candidates) == 0
    assert any("skipped" in w for w in result.warnings)


def test_no_available_features_returns_empty(contract):
    df = _make_3style_df(n_signals=100)
    result = run(
        df, contract,
        available_features=[],
        config=BadEntryDiscoveryConfig(mfe_threshold_override=1.0),
    )
    assert result.n_total_hypotheses == 0
    assert len(result.bad_entry_candidates) == 0
