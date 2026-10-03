"""Tests for Layer 1 - Boundary, feature availability, n_total_hypotheses."""
import json
import numpy as np
import pandas as pd
import pytest
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L1_boundary
from vp_analysis.layers.L1_boundary import FeatureAvailabilityCriteria

@pytest.fixture
def synthetic_merged():
    rng = np.random.default_rng(42); n = 200
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="D"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * 100 + ["CHOCH"] * 100,
        "auctRegime": rng.integers(0, 9, n),
        "auctTradeQuality": rng.normal(.5, .2, n),
        "vpMigrationConf": rng.normal(.3, .15, n),
        "auctBalance": [.5] * n,
        "auctExpReward": [float("nan") if i < 110 else .2 + (i-110)*0.001 for i in range(n)],
        "profitUSD": rng.normal(.1, 1., n)})

@pytest.fixture
def contract_features(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "quality": ["auctTradeQuality", "auctBalance", "auctExpReward"],
        "volume": ["vpMigrationConf", "missing_feature"]}
    d["shape_priors"] = {"auctTradeQuality":"MONO_UP","auctBalance":"MONO_UP",
        "auctExpReward":"MONO_UP","vpMigrationConf":"MONO_UP","missing_feature":"MONO_UP"}
    d["feature_direction"] = {"auctTradeQuality":1,"auctBalance":1,
        "auctExpReward":1,"vpMigrationConf":1,"missing_feature":1}
    return ResearchContract.from_dict(d)

def test_split_ratio(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    assert r.n_dev == 140 and r.n_holdout == 60 and r.split_ratio == 0.70

def test_split_time(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    assert r.split_time is not None
    assert r.split_time == str(synthetic_merged["time"].iloc[140])

def test_holdout_sealed(synthetic_merged, contract_features):
    assert L1_boundary.run(synthetic_merged, contract_features).boundary.holdout.is_sealed

def test_available_feature(synthetic_merged, contract_features):
    by = {e.feature:e for e in L1_boundary.run(synthetic_merged,contract_features).feature_availability}
    assert by["auctTradeQuality"].available and by["auctTradeQuality"].reason == ""

def test_missing_feature(synthetic_merged, contract_features):
    by = {e.feature:e for e in L1_boundary.run(synthetic_merged,contract_features).feature_availability}
    assert not by["missing_feature"].present and by["missing_feature"].reason == "missing"

def test_low_variance(synthetic_merged, contract_features):
    by = {e.feature:e for e in L1_boundary.run(synthetic_merged,contract_features).feature_availability}
    assert not by["auctBalance"].available and by["auctBalance"].reason == "low_variance"

def test_too_many_na(synthetic_merged, contract_features):
    by = {e.feature:e for e in L1_boundary.run(synthetic_merged,contract_features).feature_availability}
    assert not by["auctExpReward"].available and by["auctExpReward"].reason == "too_many_na"

def test_available_features_helper(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    avail = r.available_features()
    assert "auctTradeQuality" in avail and "auctBalance" not in avail

def test_counts(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    assert r.n_available == 2 and r.n_unavailable == 3

def test_availability_on_dev_only(contract_features):
    n = 200
    df = pd.DataFrame({"time":pd.date_range("2024-01-01",periods=n,freq="D"),
        "symbol":["XAUUSD"]*n,"setupType":["BOS"]*n,
        "auctTradeQuality":[.5]*140+list(np.random.RandomState(0).normal(0,10,60)),
        "vpMigrationConf":list(np.random.RandomState(1).normal(0,1,n)),
        "profitUSD":[.1]*n})
    r = L1_boundary.run(df, contract_features)
    by = {e.feature:e for e in r.feature_availability}
    assert not by["auctTradeQuality"].available and by["auctTradeQuality"].reason == "low_variance"

def test_n_total_keys(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    for k in ("hard_gate","soft_gate","regime_block"): assert k in r.n_total_hypotheses

def test_n_total_formula(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    ng = synthetic_merged.groupby(["symbol","setupType"]).ngroups
    assert r.n_total_hypotheses["hard_gate"] == r.n_available * ng

def test_n_total_in_run_meta(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    assert r.run_meta()["n_total_hypotheses"] == r.n_total_hypotheses

def test_dev_all_styles_none(synthetic_merged, contract_features):
    assert L1_boundary.run(synthetic_merged, contract_features).dev_all_styles is None

def test_dev_all_styles_split(synthetic_merged, contract_features):
    all_s = synthetic_merged.copy(); all_s["trailStyle"] = 1
    r = L1_boundary.run(synthetic_merged, contract_features, all_styles_df=all_s)
    assert r.dev_all_styles is not None
    st = pd.to_datetime(r.split_time)
    assert (pd.to_datetime(r.dev_all_styles["time"]) < st).all()

def test_dev_all_styles_smaller(synthetic_merged, contract_features):
    all_s = pd.concat([synthetic_merged]*3, ignore_index=True); all_s["trailStyle"] = 0
    r = L1_boundary.run(synthetic_merged, contract_features, all_styles_df=all_s)
    assert r.dev_all_styles is not None and len(r.dev_all_styles) < len(all_s)

def test_warning_for_missing(synthetic_merged, contract_features):
    r = L1_boundary.run(synthetic_merged, contract_features)
    assert any("missing_feature" in w for w in r.warnings)

def test_run_meta_json(synthetic_merged, contract_features, tmp_path):
    L1_boundary.run(synthetic_merged, contract_features, output_dir=tmp_path)
    assert (tmp_path/"run_meta.json").exists()
    meta = json.loads((tmp_path/"run_meta.json").read_text())
    assert meta["n_dev"] == 140 and "n_total_hypotheses" in meta

def test_csv_written(synthetic_merged, contract_features, tmp_path):
    L1_boundary.run(synthetic_merged, contract_features, output_dir=tmp_path)
    assert (tmp_path/"feature_availability.csv").exists()
    assert len(pd.read_csv(tmp_path/"feature_availability.csv")) == 5

def test_empty_raises(contract_features):
    with pytest.raises(ValueError, match="empty"):
        L1_boundary.run(pd.DataFrame(), contract_features)

def test_custom_criteria(minimal_contract_dict):
    n = 100
    df = pd.DataFrame({"time":pd.date_range("2024-01-01",periods=n,freq="D"),
        "feature_x":list(np.random.RandomState(0).normal(0,.001,n)),"profitUSD":[.1]*n})
    d = dict(minimal_contract_dict)
    d["pre_registered"]={"cat":["feature_x"]}; d["shape_priors"]={"feature_x":"MONO_UP"}
    d["feature_direction"]={"feature_x":1}
    c = ResearchContract.from_dict(d)
    assert L1_boundary.run(df, c).feature_availability[0].available
    assert not L1_boundary.run(df, c, criteria=FeatureAvailabilityCriteria(min_std=0.01)).feature_availability[0].available
