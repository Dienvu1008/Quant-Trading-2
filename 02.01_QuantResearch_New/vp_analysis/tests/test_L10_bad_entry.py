"""Tests for Layer 10 — Bad Entry Analysis."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L10_bad_entry import (
    BadEntryConfig,
    _build_canary_labels,
    _classify_canary,
    _evaluate_filter_on_holdout,
    _screen_bad_entry_features,
    run,
)


# ─── Helpers ─────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    # Ensure bad_entry pool present (minimal_contract_dict already has all 4)
    return ResearchContract.from_dict(d)


def _make_dev_3style(n_signals=100, seed=0):
    """3 rows per signal (one per trailStyle). f_bad predicts SL-hit."""
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(n_signals):
        sig_id = f"SIG-{i:05d}"
        f_bad = rng.uniform(0, 1)
        if f_bad > 0.7:
            reasons = ["SL_HIT", "SL_HIT", "SL_HIT"]
        elif f_bad > 0.5:
            reasons = ["SL_HIT", "SL_HIT", "TP_HIT"]
        elif f_bad > 0.3:
            reasons = ["SL_HIT", "TP_HIT", "TP_HIT"]
        else:
            reasons = ["TP_HIT", "TP_HIT", "TP_HIT"]
        for style, reason in zip([-1, 0, 1], reasons):
            rows.append({
                "signalId": sig_id,
                "trailStyle": style,
                "exitReason": reason,
                "f_bad": f_bad,
                "f_noise": rng.uniform(0, 1),
                "_profit": 1.0 if reason == "TP_HIT" else -1.0,
                "time": pd.Timestamp("2024-01-01") + pd.Timedelta(hours=i),
            })
    return pd.DataFrame(rows)


# ══════════════════════════════════════════════════════════════════
# Canary labels
# ══════════════════════════════════════════════════════════════════

def test_canary_catastrophic():
    row = pd.Series({"a": "SL_HIT", "b": "SL_HIT", "c": "SL_HIT"})
    assert _classify_canary(row, BadEntryConfig()) == "catastrophic"


def test_canary_excellent():
    row = pd.Series({"a": "TP_HIT", "b": "TP_HIT", "c": "TP_HIT"})
    assert _classify_canary(row, BadEntryConfig()) == "excellent"


def test_canary_bad_two_sl():
    row = pd.Series({"a": "SL_HIT", "b": "SL_HIT", "c": "TP_HIT"})
    assert _classify_canary(row, BadEntryConfig()) == "bad"


def test_canary_incomplete_returns_none():
    row = pd.Series({"a": "SL_HIT", "b": None})
    assert _classify_canary(row, BadEntryConfig()) is None


def test_canary_aggregate(contract):
    df = _make_dev_3style(n_signals=100)
    canary, _ = _build_canary_labels(df, BadEntryConfig())
    assert canary.n_signals == 100
    assert canary.n_complete == 100
    assert canary.n_bad > 0
    assert canary.n_good > 0


# ══════════════════════════════════════════════════════════════════
# Bad entry screening
# ══════════════════════════════════════════════════════════════════

def test_screen_finds_bad_feature(contract):
    """f_bad high_extreme should have lift > 1."""
    df = _make_dev_3style(n_signals=200)
    canary, labels = _build_canary_labels(df, BadEntryConfig())
    df2 = df.copy()
    df2["_canary_label"] = df2["signalId"].map(labels)
    df2["_is_bad"] = df2["_canary_label"].isin(["catastrophic", "bad"]).astype(int)

    features = _screen_bad_entry_features(
        df2, ["f_bad", "f_noise"],
        BadEntryConfig(min_extreme_samples=15),
    )
    high_ext = [f for f in features
                if f.feature == "f_bad" and f.rule_type == "high_extreme"]
    assert len(high_ext) >= 1
    assert high_ext[0].lift > 1.0


# ══════════════════════════════════════════════════════════════════
# Full run
# ══════════════════════════════════════════════════════════════════

def test_full_run_no_holdout(contract, tmp_path):
    dev = _make_dev_3style(n_signals=100)
    result = run(dev, contract, experiment_id="EXP-TEST",
                 available_features=["f_bad", "f_noise"],
                 output_dir=tmp_path)
    assert (tmp_path / "canary_labels.json").exists()
    assert (tmp_path / "bad_entry_summary.json").exists()
    assert result.canary.n_signals == 100


def test_full_run_with_holdout(contract, tmp_path):
    dev = _make_dev_3style(n_signals=150, seed=0)
    holdout = _make_dev_3style(n_signals=100, seed=1)
    result = run(dev, contract, experiment_id="EXP-TEST",
                 available_features=["f_bad", "f_noise"],
                 holdout_df=holdout, output_dir=tmp_path)
    # If filter has features, holdout report may exist
    assert (tmp_path / "composite_bad_filter.json").exists()


def test_insufficient_canary_skips_screening(contract):
    """Too few signals → no features screened."""
    dev = _make_dev_3style(n_signals=15)  # < min_extreme_samples*3 = 60
    result = run(dev, contract, experiment_id="EXP-TEST",
                 available_features=["f_bad"])
    assert len(result.bad_features) == 0
    assert any("skipped" in w for w in result.warnings)


# ══════════════════════════════════════════════════════════════════
# Holdout filter evaluation
# ══════════════════════════════════════════════════════════════════

def test_evaluate_filter_confirmed():
    """Filter flags high f_bad → those trades have negative EV."""
    rng = np.random.default_rng(5)
    n = 200
    f_bad = rng.uniform(0, 1, n)
    profit = np.where(f_bad > 0.7, -1.0, 0.5) + rng.normal(0, 0.2, n)
    df = pd.DataFrame({
        "signalId": [f"SIG-{i}" for i in range(n)],
        "f_bad": f_bad,
        "_profit": profit,
    })
    filter_spec = {
        "features": [{
            "feature": "f_bad",
            "rule_type": "high_extreme",
            "threshold_high": 0.7,
            "threshold_low": None,
        }],
        "min_votes": 1,
    }
    report = _evaluate_filter_on_holdout(
        df, filter_spec, BadEntryConfig(min_holdout_trades=10),
    )
    assert report is not None
    assert report.filter_confirmed


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_dev_raises(contract):
    with pytest.raises(ValueError, match="empty"):
        run(pd.DataFrame(), contract, experiment_id="EXP-TEST")


def test_missing_experiment_id_raises(contract):
    dev = _make_dev_3style(n_signals=100)
    with pytest.raises(ValueError, match="experiment_id"):
        run(dev, contract, experiment_id="")
