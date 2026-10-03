"""Tests for Layer 2 - Feature engineering."""
import json
import numpy as np
import pandas as pd
import pytest
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L1_boundary, L2_feature_engineering
from vp_analysis.layers.L2_feature_engineering import InteractionTransformer

MINI = (("ix_tq_mig","auctTradeQuality","vpMigrationConf"),("ix_bos_trend","bosQuality","structAlign"))

@pytest.fixture
def df200():
    rng = np.random.default_rng(7); n = 200
    return pd.DataFrame({"time":pd.date_range("2024-01-01",periods=n,freq="D"),
        "auctTradeQuality":rng.uniform(0,1,n),"vpMigrationConf":rng.uniform(0,1,n),
        "bosQuality":rng.uniform(-1,1,n),"structAlign":rng.uniform(0,1,n),
        "profitUSD":rng.normal(.1,1.,n)})

@pytest.fixture
def mini_contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"]={"quality":["auctTradeQuality","vpMigrationConf"],"trend":["bosQuality","structAlign"]}
    d["shape_priors"]={"auctTradeQuality":"MONO_UP","vpMigrationConf":"MONO_UP","bosQuality":"BAND","structAlign":"MONO_UP"}
    d["feature_direction"]={"auctTradeQuality":1,"vpMigrationConf":1,"bosQuality":0,"structAlign":1}
    return ResearchContract.from_dict(d)

def test_transform_before_fit():
    t = InteractionTransformer((("ix_a","f1","f2"),))
    with pytest.raises(RuntimeError, match="before fit"):
        t.transform(pd.DataFrame({"f1":[1],"f2":[2]}))

def test_fit_uses_dev_only(df200):
    dev = df200.iloc[:140].copy(); full = df200.copy(); full.loc[190,"auctTradeQuality"] = 1e6
    t = InteractionTransformer(MINI); t.fit(dev)
    s = {x.interaction_name:x for x in t.stats}["ix_tq_mig"]
    assert s.a_max <= dev["auctTradeQuality"].max() + 1e-9

def test_bounded_0_1(df200):
    t = InteractionTransformer(MINI); t.fit(df200.iloc[:140]); out = t.transform(df200)
    for name in ("ix_tq_mig","ix_bos_trend"): assert (out[name]>=0).all() and (out[name]<=1).all()

def test_outlier_clipped(df200):
    df = df200.copy(); df.loc[190,"auctTradeQuality"] = 1e6
    t = InteractionTransformer(MINI); t.fit(df.iloc[:140]); out = t.transform(df)
    assert out.loc[190,"ix_tq_mig"] <= 1.0

def test_exact_formula(df200):
    dev = df200.iloc[:140]
    t = InteractionTransformer((("ix_tq_mig","auctTradeQuality","vpMigrationConf"),))
    t.fit(dev); s = t.stats[0]; out = t.transform(dev)
    a_n = ((dev["auctTradeQuality"]-s.a_min)/(s.a_max-s.a_min)).clip(0,1)
    b_n = ((dev["vpMigrationConf"]-s.b_min)/(s.b_max-s.b_min)).clip(0,1)
    np.testing.assert_allclose(out["ix_tq_mig"].values, (a_n*b_n).values, rtol=1e-5)

def test_missing_zero_and_warning():
    df = pd.DataFrame({"time":pd.date_range("2024-01-01",periods=20),
        "auctTradeQuality":np.random.rand(20),"vpMigrationConf":np.random.rand(20)})
    t = InteractionTransformer(MINI); t.fit(df); out = t.transform(df)
    assert (out["ix_bos_trend"] == 0.0).all()
    assert any("ix_bos_trend" in w for w in t.warnings)

def test_degenerate_zero():
    df = pd.DataFrame({"a":[.5]*20,"b":np.random.rand(20)})
    t = InteractionTransformer((("ix_x","a","b"),)); t.fit(df)
    assert not t.stats[0].present and t.stats[0].reason == "degenerate_range"
    assert (t.transform(df)["ix_x"] == 0.0).all()

def test_deterministic(df200):
    t = InteractionTransformer(MINI); t.fit(df200.iloc[:140])
    np.testing.assert_array_equal(t.transform(df200)["ix_tq_mig"].values,
                                  t.transform(df200)["ix_tq_mig"].values)

def test_run_adds_interactions(df200, mini_contract):
    l1 = L1_boundary.run(df200, mini_contract)
    l2 = L2_feature_engineering.run(l1, interaction_defs=MINI)
    assert "ix_tq_mig" in l2.boundary.dev.columns
    assert "ix_tq_mig" in l2.boundary.holdout.columns
    assert l2.boundary.holdout.is_sealed

def test_run_counts(df200, mini_contract):
    l1 = L1_boundary.run(df200, mini_contract)
    l2 = L2_feature_engineering.run(l1, interaction_defs=MINI)
    assert l2.n_interactions_computed == 2 and l2.fit_source == "development"

def test_run_skipped_missing(mini_contract):
    df = pd.DataFrame({"time":pd.date_range("2024-01-01",periods=50),
        "auctTradeQuality":np.random.rand(50),"profitUSD":np.zeros(50)})
    l1 = L1_boundary.run(df, mini_contract)
    l2 = L2_feature_engineering.run(l1, interaction_defs=(("ix_tq_mig","auctTradeQuality","vpMigrationConf"),))
    assert l2.n_interactions_computed == 0 and l2.n_interactions_skipped == 1

def test_dev_all_styles_transformed(df200, mini_contract):
    all_s = df200.copy(); all_s["trailStyle"] = 1
    l1 = L1_boundary.run(df200, mini_contract, all_styles_df=all_s)
    l2 = L2_feature_engineering.run(l1, interaction_defs=MINI)
    assert l2.dev_all_styles_fe is not None and "ix_tq_mig" in l2.dev_all_styles_fe.columns

def test_dev_all_styles_none(df200, mini_contract):
    l1 = L1_boundary.run(df200, mini_contract)
    l2 = L2_feature_engineering.run(l1, interaction_defs=MINI)
    assert l2.dev_all_styles_fe is None

def test_output_written(df200, mini_contract, tmp_path):
    l1 = L1_boundary.run(df200, mini_contract)
    L2_feature_engineering.run(l1, output_dir=tmp_path, interaction_defs=MINI)
    assert (tmp_path/"interaction_stats.json").exists()
    p = json.loads((tmp_path/"interaction_stats.json").read_text())
    assert p["fit_source"] == "development" and p["n_computed"] == 2

def test_holdout_still_sealed(df200, mini_contract):
    l1 = L1_boundary.run(df200, mini_contract)
    l2 = L2_feature_engineering.run(l1, interaction_defs=MINI)
    assert l2.boundary.holdout.is_sealed
