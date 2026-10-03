"""test_shap_leakage.py — Leakage prevention tests for the SHAP layer.

Tests:
- FORBIDDEN_FEATURES list (profit, MFE, MAE, exitReason, etc.) never appear in X
- consensus targets (_all_styles_win, _consensus_profit) never appear in X
- Post-entry columns excluded from feature set
- Verify with explicit assertion on SHAPDataset.feature_names
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
    SHAP_WARN_FEATURES,
    build_shap_dataset,
)
from vp_analysis.shap.shap_config import SHAPConfig


# ─── Helpers ─────────────────────────────────────────────────────

N_ROWS = 120  # 40 signals × 3 styles

CLEAN_FEATURES = ["feat_a", "feat_b", "feat_c", "feat_d", "feat_e"]

# All leakage columns that must NEVER appear in X
LEAKAGE_COLUMNS = [
    "profitUSD",   # direct outcome
    "_profit",     # alias
    "win",         # binary outcome
    "mfeATR",      # post-entry MFE
    "maeATR",      # post-entry MAE
    "exitReason",  # post-entry exit type
    "exitTime",    # post-entry timing
    "_all_styles_win",     # cross-style consensus
    "_all_styles_loss",
    "_consensus_profit",   # cross-style mean
    "_style_agree_count",
    "signalId",    # grouping key
    "trailStyle",  # structural key
]


def _make_df_with_leakage(n_rows: int = N_ROWS) -> pd.DataFrame:
    """Create a dataframe containing both clean and leakage columns."""
    rng = np.random.default_rng(0)
    n_signals = n_rows // 3

    rows = []
    for i in range(n_signals):
        feat_vals = {f: float(rng.normal()) for f in CLEAN_FEATURES}
        for style in [-1, 0, 1]:
            row = dict(feat_vals)
            row["signalId"] = f"SIG-{i:04d}"
            row["trailStyle"] = style
            row["profitUSD"] = float(rng.normal())
            row["_profit"] = row["profitUSD"]
            row["win"] = 1 if row["profitUSD"] > 0 else 0
            row["mfeATR"] = float(rng.exponential(1.0))
            row["maeATR"] = float(rng.exponential(0.5))
            row["exitReason"] = rng.choice(["TP", "SL", "TRAIL"])
            row["exitTime"] = "2025-01-01T10:00:00"
            row["_all_styles_win"] = int(rng.random() > 0.5)
            row["_all_styles_loss"] = 1 - row["_all_styles_win"]
            row["_consensus_profit"] = float(rng.normal(0.3))
            row["_style_agree_count"] = rng.integers(0, 4)
            row["symbol"] = "XAUUSDm"
            row["setupType"] = "BOS"
            rows.append(row)

    return pd.DataFrame(rows)


class _ContractAllCols:
    """Contract that naively pre-registers everything — leakage should still be stripped."""
    def __init__(self, all_col_names):
        self.pre_registered = {"quality": list(all_col_names)}


# ─── Tests ───────────────────────────────────────────────────────

class TestForbiddenFeaturesNeverInX:
    """Core leakage test: every forbidden column must be absent from X."""

    def test_no_leakage_columns_in_X(self):
        df = _make_df_with_leakage()
        # Register ALL columns (including leakage) — builder should strip them
        all_cols = [c for c in df.columns if c not in ("symbol",)]
        contract = _ContractAllCols(all_cols)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, all_cols, config)

        for col in LEAKAGE_COLUMNS:
            assert col not in dataset.X.columns, (
                f"LEAKAGE: '{col}' found in dataset.X.columns"
            )

    def test_no_leakage_in_feature_names(self):
        df = _make_df_with_leakage()
        all_cols = list(df.columns)
        contract = _ContractAllCols(all_cols)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, all_cols, config)

        for col in LEAKAGE_COLUMNS:
            assert col not in dataset.feature_names, (
                f"LEAKAGE: '{col}' found in dataset.feature_names"
            )

    def test_only_clean_features_in_X(self):
        """The X matrix must only contain legitimate feature columns."""
        df = _make_df_with_leakage()
        contract = _ContractAllCols(CLEAN_FEATURES + LEAKAGE_COLUMNS)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, CLEAN_FEATURES + LEAKAGE_COLUMNS, config)

        # Every column in X must be from CLEAN_FEATURES
        for col in dataset.X.columns:
            assert col in CLEAN_FEATURES, (
                f"Unexpected column '{col}' found in X (not in CLEAN_FEATURES)"
            )

    def test_explicit_feature_names_match_X_columns(self):
        """dataset.feature_names must exactly match dataset.X.columns."""
        df = _make_df_with_leakage()
        contract = _ContractAllCols(CLEAN_FEATURES)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, CLEAN_FEATURES, config)

        assert list(dataset.feature_names) == list(dataset.X.columns), (
            "feature_names does not match X.columns"
        )

    def test_n_features_matches_X_shape(self):
        df = _make_df_with_leakage()
        contract = _ContractAllCols(CLEAN_FEATURES)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, CLEAN_FEATURES, config)

        assert dataset.n_features == dataset.X.shape[1]
        assert dataset.n_features == len(dataset.feature_names)


class TestConsensusTargetsExcluded:
    """Consensus target columns must be excluded regardless of registration."""

    def test_all_styles_win_excluded_from_X(self):
        df = _make_df_with_leakage()
        cols_with_consensus = CLEAN_FEATURES + ["_all_styles_win", "_consensus_profit"]
        contract = _ContractAllCols(cols_with_consensus)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, cols_with_consensus, config)

        assert "_all_styles_win" not in dataset.X.columns
        assert "_consensus_profit" not in dataset.X.columns

    def test_consensus_not_in_features_when_used_as_target(self):
        """When _all_styles_win is the target, it must not also appear in X."""
        df = _make_df_with_leakage()
        cols_with_consensus = CLEAN_FEATURES + ["_all_styles_win"]
        contract = _ContractAllCols(cols_with_consensus)
        config = SHAPConfig(target_mode="all_styles_win", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, cols_with_consensus, config)

        # Used as target — must NOT be in X
        assert "_all_styles_win" not in dataset.X.columns
        assert dataset.target_name == "_all_styles_win"


class TestPostEntryColumnsExcluded:
    """All post-entry columns must be stripped from the feature set."""

    POST_ENTRY_COLS = {
        "profitUSD", "_profit", "win",
        "mfeATR", "maeATR",
        "exitReason", "exitTime",
    }

    def test_post_entry_cols_not_in_X(self):
        df = _make_df_with_leakage()
        all_cols = CLEAN_FEATURES + list(self.POST_ENTRY_COLS)
        contract = _ContractAllCols(all_cols)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, all_cols, config)

        for col in self.POST_ENTRY_COLS:
            assert col not in dataset.X.columns, (
                f"Post-entry column '{col}' found in X"
            )

    def test_post_entry_not_in_feature_names(self):
        df = _make_df_with_leakage()
        all_cols = CLEAN_FEATURES + list(self.POST_ENTRY_COLS)
        contract = _ContractAllCols(all_cols)
        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        dataset = build_shap_dataset(df, contract, all_cols, config)

        for col in self.POST_ENTRY_COLS:
            assert col not in dataset.feature_names, (
                f"Post-entry column '{col}' found in feature_names"
            )


class TestForbiddenFeatureSetCompleteness:
    """SHAP_FORBIDDEN_FEATURES must be a frozenset and cover all known leakage."""

    def test_is_frozenset(self):
        assert isinstance(SHAP_FORBIDDEN_FEATURES, frozenset), (
            "SHAP_FORBIDDEN_FEATURES must be a frozenset for immutability"
        )

    def test_covers_profit_column(self):
        assert "profitUSD" in SHAP_FORBIDDEN_FEATURES

    def test_covers_mfe_mae(self):
        assert "mfeATR" in SHAP_FORBIDDEN_FEATURES
        assert "maeATR" in SHAP_FORBIDDEN_FEATURES

    def test_covers_exit_reason(self):
        assert "exitReason" in SHAP_FORBIDDEN_FEATURES

    def test_covers_consensus_targets(self):
        assert "_all_styles_win" in SHAP_FORBIDDEN_FEATURES
        assert "_consensus_profit" in SHAP_FORBIDDEN_FEATURES

    def test_covers_structural_keys(self):
        assert "signalId" in SHAP_FORBIDDEN_FEATURES
        assert "trailStyle" in SHAP_FORBIDDEN_FEATURES

    def test_warn_features_is_frozenset(self):
        assert isinstance(SHAP_WARN_FEATURES, frozenset)
