"""test_shap_dataset.py — Tests for SHAPDatasetBuilder.

Covers:
- signalId grouping (no signal counted 3x)
- 3-style handling (signal-level view deduplication)
- target construction for all 3 target modes
- leakage exclusion (profit/MFE/MAE/exitReason not in features)
- missing signalId handling

Synthetic data: 100 signals × 3 styles = 300 rows.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

# Make vp_analysis importable
_ROOT = Path(__file__).parent.parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from vp_analysis.shap.shap_dataset import (
    SHAP_FORBIDDEN_FEATURES,
    SHAPDataset,
    build_shap_dataset,
)
from vp_analysis.shap.shap_config import SHAPConfig


# ─── Fixtures ────────────────────────────────────────────────────

N_SIGNALS = 100
N_STYLES = 3
FEATURE_COLS = ["feat_a", "feat_b", "feat_c", "feat_d", "feat_e"]


def _make_3style_df(n_signals: int = N_SIGNALS, include_signal_id: bool = True) -> pd.DataFrame:
    """Create synthetic 3-style dataframe: n_signals × 3 styles = n_signals*3 rows."""
    rng = np.random.default_rng(42)
    rows = []
    for i in range(n_signals):
        sig_id = f"SIG-{i:04d}" if include_signal_id else None
        # Feature values are identical across styles for the same signal
        feat_vals = {f: float(rng.normal()) for f in FEATURE_COLS}
        for style in [-1, 0, 1]:
            row = dict(feat_vals)
            if sig_id is not None:
                row["signalId"] = sig_id
            row["trailStyle"] = style
            row["profitUSD"] = float(rng.normal(loc=0.5 * (style + 1)))
            row["exitReason"] = rng.choice(["TP", "SL", "TRAIL"])
            row["mfeATR"] = float(rng.exponential(1.0))
            row["maeATR"] = float(rng.exponential(0.5))
            row["symbol"] = "XAUUSDm"
            row["setupType"] = rng.choice(["BOS", "CHOCH"])
            row["_all_styles_win"] = 1 if rng.random() > 0.5 else 0
            row["_consensus_profit"] = float(rng.normal(0.3))
            rows.append(row)

    return pd.DataFrame(rows)


class _MinimalContract:
    """Stub contract for testing."""
    def __init__(self, feature_names):
        self.pre_registered = {"quality": feature_names}


# ─── Tests ───────────────────────────────────────────────────────

class TestSignalIdGrouping:
    """No signal should be counted 3× in signal-level view."""

    def test_dedup_reduces_to_n_signals(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        # Signal-level view must have N_SIGNALS rows, not N_SIGNALS * 3
        assert dataset.n_signals == N_SIGNALS, (
            f"Expected {N_SIGNALS} signals, got {dataset.n_signals}"
        )
        assert len(dataset.X) == N_SIGNALS
        assert len(dataset.y) == N_SIGNALS

    def test_n_rows_before_dedup_is_full(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        assert dataset.n_rows_before_dedup == N_SIGNALS * N_STYLES

    def test_no_duplicate_signal_ids_in_X(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        # signalId should not appear in feature matrix
        assert "signalId" not in dataset.X.columns


class TestStyleViewDeduplication:
    """Style view (for SHAP-G) should keep all 3 style rows, signal view dedups."""

    def test_style_df_has_all_rows(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(
            target_mode="production_profit",
            run_shap_g=True,
            min_rows_total=10,
        )
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        # style_df keeps all rows (3 per signal)
        assert dataset.style_df is not None
        assert len(dataset.style_df) == N_SIGNALS * N_STYLES

    def test_style_df_has_trail_style_column(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(
            target_mode="production_profit",
            run_shap_g=True,
            min_rows_total=10,
        )
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        assert "trailStyle" in dataset.style_df.columns

    def test_signal_view_is_deduplicated(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(
            target_mode="production_profit",
            run_shap_g=True,
            min_rows_total=10,
        )
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        # Signal-level view is smaller than style view
        assert len(dataset.X) < len(dataset.style_df)
        assert len(dataset.X) == N_SIGNALS


class TestTargetConstruction:
    """Target must be correctly constructed for each mode."""

    def test_production_profit_target(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        assert dataset.target_mode == "production_profit"
        assert dataset.target_name in ("profitUSD", "_profit")
        assert len(dataset.y) == N_SIGNALS

    def test_all_styles_win_target(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="all_styles_win", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        assert dataset.target_mode == "all_styles_win"
        # Binary target: values must be 0 or 1
        unique_vals = set(dataset.y.unique())
        assert unique_vals.issubset({0.0, 1.0, 0, 1})

    def test_consensus_profit_target(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="consensus_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        assert dataset.target_mode == "consensus_profit"
        assert len(dataset.y) == N_SIGNALS

    def test_all_modes_have_correct_length(self):
        df = _make_3style_df()
        contract = _MinimalContract(FEATURE_COLS)
        for mode in ("production_profit", "all_styles_win", "consensus_profit"):
            config = SHAPConfig(target_mode=mode, min_rows_total=10)
            dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)
            assert len(dataset.y) == N_SIGNALS, f"Mode {mode}: expected {N_SIGNALS}, got {len(dataset.y)}"


class TestLeakageExclusion:
    """Post-entry columns must never appear in X."""

    FORBIDDEN = ["profitUSD", "mfeATR", "maeATR", "exitReason"]

    def test_forbidden_columns_not_in_X(self):
        # Add forbidden columns to feature list (they should be stripped)
        all_features = FEATURE_COLS + self.FORBIDDEN
        df = _make_3style_df()
        contract = _MinimalContract(all_features)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, all_features, config)

        for col in self.FORBIDDEN:
            assert col not in dataset.X.columns, (
                f"Forbidden column '{col}' found in X.columns"
            )

    def test_forbidden_columns_not_in_feature_names(self):
        all_features = FEATURE_COLS + self.FORBIDDEN
        df = _make_3style_df()
        contract = _MinimalContract(all_features)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, all_features, config)

        for col in self.FORBIDDEN:
            assert col not in dataset.feature_names, (
                f"Forbidden column '{col}' found in feature_names"
            )

    def test_consensus_target_not_in_X(self):
        """Consensus targets must also be excluded from features."""
        consensus_cols = ["_all_styles_win", "_consensus_profit"]
        all_features = FEATURE_COLS + consensus_cols
        df = _make_3style_df()
        contract = _MinimalContract(all_features)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, all_features, config)

        for col in consensus_cols:
            assert col not in dataset.X.columns, (
                f"Consensus target '{col}' should not appear in X"
            )

    def test_shap_forbidden_features_constant_covers_leakage_columns(self):
        """The SHAP_FORBIDDEN_FEATURES constant must cover all known leakage columns."""
        must_include = {"profitUSD", "mfeATR", "maeATR", "exitReason",
                        "_all_styles_win", "_consensus_profit", "signalId"}
        missing = must_include - SHAP_FORBIDDEN_FEATURES
        assert not missing, (
            f"SHAP_FORBIDDEN_FEATURES is missing: {missing}"
        )


class TestMissingSignalId:
    """Missing signalId should warn but not crash (may inflate counts)."""

    def test_builds_without_signal_id(self):
        df = _make_3style_df(include_signal_id=False)
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        assert dataset is not None
        assert isinstance(dataset, SHAPDataset)

    def test_warning_issued_for_missing_signal_id(self):
        df = _make_3style_df(include_signal_id=False)
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        # Should have a warning about missing signalId
        has_warning = any("signalId" in w.lower() for w in dataset.warnings)
        assert has_warning, f"Expected signalId warning, got: {dataset.warnings}"

    def test_without_signal_id_keeps_all_rows(self):
        """Without dedup, all N*3 rows are kept."""
        df = _make_3style_df(n_signals=50, include_signal_id=False)
        contract = _MinimalContract(FEATURE_COLS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, FEATURE_COLS, config)

        # No dedup applied → all rows kept
        assert dataset.n_signals == 50 * 3
