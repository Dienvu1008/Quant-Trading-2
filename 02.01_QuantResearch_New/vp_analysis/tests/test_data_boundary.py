import json

import pandas as pd
import pytest

from vp_analysis.core.data_boundary import (
    DataBoundary,
    DevelopmentData,
    HoldoutAccessLog,
    SealedHoldout,
)
from vp_analysis.core.exceptions import HoldoutAlreadyUnsealedError


# ─── Fixtures ───────────────────────────────────────────────────

@pytest.fixture
def sample_df():
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=100, freq="D"),
        "symbol": ["XAUUSD"] * 100,
        "feature_a": list(range(100)),
        "feature_b": [x * 0.5 for x in range(100)],
        "profitUSD": [1.0 if i % 3 else -1.0 for i in range(100)],
    })


class MultiplyTransformer:
    def __init__(self):
        self.dev_mean = None

    def fit(self, df):
        self.dev_mean = df["feature_a"].mean()

    def transform(self, df):
        out = df.copy()
        out["feature_a_scaled"] = df["feature_a"] - self.dev_mean
        return out


# ─── Split mechanics ────────────────────────────────────────────

def test_from_merged_temporal_split(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70)
    assert len(b.dev) == 70
    assert b.holdout.size == 30
    assert b.split_method == "temporal"


def test_from_merged_records_split_time(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70)
    assert b.split_time is not None
    assert b.split_time == str(sample_df["time"].iloc[70])


def test_from_merged_rejects_bad_ratio(sample_df):
    with pytest.raises(ValueError):
        DataBoundary.from_merged(sample_df, split_ratio=1.5)
    with pytest.raises(ValueError):
        DataBoundary.from_merged(sample_df, split_ratio=0.0)


def test_from_merged_rejects_missing_time_col(sample_df):
    df = sample_df.drop(columns=["time"])
    with pytest.raises(ValueError, match="time"):
        DataBoundary.from_merged(df, split_method="temporal")


def test_temporal_order_preserved(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70)
    dev_times = b.dev.data["time"].tolist()
    holdout_times = b.holdout._df["time"].tolist()
    assert dev_times == sorted(dev_times)
    assert max(dev_times) < min(holdout_times)


# ─── SealedHoldout access control ───────────────────────────────

def test_holdout_starts_sealed(sample_df):
    b = DataBoundary.from_merged(sample_df)
    assert b.holdout.is_sealed
    assert len(b.holdout.access_log) == 0


def test_holdout_metadata_accessible_when_sealed(sample_df):
    b = DataBoundary.from_merged(sample_df)
    assert b.holdout.size == 30
    assert "feature_a" in b.holdout.columns


def test_unseal_returns_dataframe(sample_df):
    b = DataBoundary.from_merged(sample_df)
    df = b.holdout.unseal_once("EXP-001", reason="final_eval")
    assert isinstance(df, pd.DataFrame)
    assert len(df) == 30


def test_unseal_twice_same_experiment_raises(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="final_eval")
    with pytest.raises(HoldoutAlreadyUnsealedError):
        b.holdout.unseal_once("EXP-001", reason="try_again")


def test_unseal_different_experiments_allowed(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="first")
    b.holdout.unseal_once("EXP-002", reason="second")
    assert len(b.holdout.access_log) == 2


def test_holdout_access_log_records(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="evaluation")
    r = b.holdout.access_log.records[0]
    assert r.experiment_id == "EXP-001"
    assert r.reason == "evaluation"
    assert r.timestamp


# ─── v3 Fix #4: persist access log to disk ──────────────────────

def test_persist_to_disk_writes_file(sample_df, tmp_path):
    b = DataBoundary.from_merged(sample_df)
    persist_path = tmp_path / "holdout_access.json"
    b.holdout.unseal_once("EXP-001", reason="eval", persist_path=persist_path)
    assert persist_path.exists()
    data = json.loads(persist_path.read_text())
    assert len(data) == 1
    assert data[0]["experiment_id"] == "EXP-001"


def test_persist_to_disk_prevents_double_unseal_after_restart(sample_df, tmp_path):
    """Simulates a crash-and-restart scenario."""
    persist_path = tmp_path / "holdout_access.json"
    # First run: unseal and persist
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="eval", persist_path=persist_path)
    # Restart: create a fresh SealedHoldout (no in-memory record)
    b2 = DataBoundary.from_merged(sample_df)
    assert b2.holdout.is_sealed  # fresh in-memory state
    # But disk file says experiment already unsealed
    with pytest.raises(HoldoutAlreadyUnsealedError):
        b2.holdout.unseal_once("EXP-001", reason="retry", persist_path=persist_path)


def test_persist_different_experiment_is_allowed(sample_df, tmp_path):
    persist_path = tmp_path / "holdout_access.json"
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="first", persist_path=persist_path)
    # EXP-002 is a different experiment — should be allowed
    b.holdout.unseal_once("EXP-002", reason="second", persist_path=persist_path)
    data = json.loads(persist_path.read_text())
    assert len(data) == 2


# ─── apply(transformer) ─────────────────────────────────────────

def test_apply_fits_on_dev(sample_df):
    b = DataBoundary.from_merged(sample_df)
    t = MultiplyTransformer()
    b.apply(t)
    expected = sample_df["feature_a"].iloc[:70].mean()
    assert t.dev_mean == expected


def test_apply_transforms_both(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b2 = b.apply(MultiplyTransformer())
    assert "feature_a_scaled" in b2.dev.columns
    assert "feature_a_scaled" in b2.holdout.columns


def test_apply_preserves_sealed_state(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b2 = b.apply(MultiplyTransformer())
    assert b2.holdout.is_sealed


def test_apply_shares_access_log(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="test")
    b2 = b.apply(MultiplyTransformer())
    assert b2.holdout.has_been_unsealed_by("EXP-001")
    with pytest.raises(HoldoutAlreadyUnsealedError):
        b2.holdout.unseal_once("EXP-001", reason="again")


def test_apply_preserves_split_metadata(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70)
    b2 = b.apply(MultiplyTransformer())
    assert b2.split_time == b.split_time
    assert b2.split_ratio == b.split_ratio


# ─── Audit ──────────────────────────────────────────────────────

def test_audit_info_complete(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="eval")
    info = b.audit_info()
    assert info["dev_size"] == 70
    assert info["holdout_size"] == 30
    assert info["split_method"] == "temporal"
    assert len(info["holdout_accesses"]) == 1
    assert info["holdout_accesses"][0]["experiment_id"] == "EXP-001"
