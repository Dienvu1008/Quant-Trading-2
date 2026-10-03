import dataclasses

import pytest

from vp_analysis.core.frozen_types import (
    FrozenBadEntryFilter,
    FrozenProductionConfig,
    FrozenRegimeBlockRule,
    FrozenRule,
    FrozenSLRiskThreshold,
    FrozenSoftGateTilt,
)


# ─── Helpers ────────────────────────────────────────────────────

def _threshold_rule(**kw):
    defaults = dict(
        rule_id="R-00001",
        experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD",
        setup="BOS",
        gate_type="threshold",
        direction=1,
        features=["auctTradeQuality"],
        lower_bound=0.65,
        test_ev_mean=0.42,
        fdr_significant=True,
    )
    defaults.update(kw)
    return FrozenRule(**defaults)


# ─── FrozenRule ─────────────────────────────────────────────────

def test_threshold_rule_valid():
    r = _threshold_rule()
    assert r.rule_id == "R-00001"
    assert r.features == ("auctTradeQuality",)   # tuple-normalised
    assert r.frozen_at


def test_band_rule_valid():
    r = FrozenRule(
        rule_id="R-002", experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="Y",
        gate_type="band", direction=0,
        features=("f",), lower_bound=-0.3, upper_bound=0.3,
    )
    assert r.gate_type == "band"


def test_model_rule_valid():
    r = FrozenRule(
        rule_id="R-003", experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="Y",
        gate_type="model", direction=0,
        features=("f1", "f2"),
        model_weights=(0.5, -0.3),
        score_threshold=0.55,
    )
    assert r.model_weights == (0.5, -0.3)


def test_rule_immutable():
    r = _threshold_rule()
    with pytest.raises(dataclasses.FrozenInstanceError):
        r.test_ev_mean = 99.0


def test_rule_rejects_empty_rule_id():
    with pytest.raises(ValueError, match="rule_id"):
        _threshold_rule(rule_id="")


def test_rule_rejects_bad_gate_type():
    with pytest.raises(ValueError, match="gate_type"):
        _threshold_rule(gate_type="weird")


def test_rule_rejects_bad_direction():
    with pytest.raises(ValueError, match="direction"):
        _threshold_rule(direction=5)


def test_rule_rejects_empty_features():
    with pytest.raises(ValueError, match="features"):
        _threshold_rule(features=[])


def test_threshold_direction_1_requires_lower():
    with pytest.raises(ValueError, match="lower_bound"):
        _threshold_rule(direction=1, lower_bound=None)


def test_band_rejects_inverted_bounds():
    with pytest.raises(ValueError, match="lower_bound < upper_bound"):
        FrozenRule(
            rule_id="R-X", experiment_id="E", research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y", gate_type="band", direction=0,
            features=["f"], lower_bound=0.5, upper_bound=0.2,
        )


def test_rule_roundtrip():
    r = _threshold_rule()
    r2 = FrozenRule.from_dict(r.to_dict())
    assert r2 == r


# ─── FrozenRegimeBlockRule ───────────────────────────────────────

def test_regime_block_rule_valid():
    r = FrozenRegimeBlockRule(
        rule_id="RB-001", experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="BOS",
        rule_type="auction_regime", condition="FAILED_AUCTION",
        mean_blocked_ev=-8.0, mean_pass_ev=3.0, mean_lift=11.0,
        mean_wr_blocked=0.25, mean_n_blocked=40, n_folds=4,
        fold_consistency=0.75, combined_p=0.002,
        fdr_significant=True,
    )
    assert r.rule_type == "auction_regime"
    assert r.frozen_at


def test_regime_block_rule_rejects_bad_type():
    with pytest.raises(ValueError, match="rule_type"):
        FrozenRegimeBlockRule(
            rule_id="RB-X", experiment_id="E",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            rule_type="invalid_type", condition="X",
            mean_blocked_ev=-1.0, mean_pass_ev=1.0, mean_lift=2.0,
            mean_wr_blocked=0.3, mean_n_blocked=10, n_folds=2,
            fold_consistency=0.6, combined_p=0.05,
        )


def test_regime_block_rule_immutable():
    r = FrozenRegimeBlockRule(
        rule_id="RB-001", experiment_id="E",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="Y",
        rule_type="auction_regime", condition="FAILED_AUCTION",
        mean_blocked_ev=-5.0, mean_pass_ev=2.0, mean_lift=7.0,
        mean_wr_blocked=0.3, mean_n_blocked=20, n_folds=3,
        fold_consistency=0.7, combined_p=0.01,
    )
    with pytest.raises(dataclasses.FrozenInstanceError):
        r.mean_blocked_ev = 99.0


# ─── FrozenBadEntryFilter ────────────────────────────────────────

def test_bad_entry_filter_valid():
    f = FrozenBadEntryFilter(
        filter_id="BF-001", experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="BOS",
        bad_entry_rules=[{"feature": "auctFailure", "threshold": 0.7}],
        n_required=1,
    )
    assert f.filter_id == "BF-001"
    assert len(f.bad_entry_rules) == 1


def test_bad_entry_filter_rejects_empty_rules():
    with pytest.raises(ValueError, match="bad_entry_rules"):
        FrozenBadEntryFilter(
            filter_id="BF-X", experiment_id="E",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y", bad_entry_rules=[], n_required=1,
        )


def test_bad_entry_filter_rejects_n_required_zero():
    with pytest.raises(ValueError, match="n_required"):
        FrozenBadEntryFilter(
            filter_id="BF-X", experiment_id="E",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            bad_entry_rules=[{"f": "x"}], n_required=0,
        )


# ─── FrozenSoftGateTilt ──────────────────────────────────────────

def test_soft_gate_tilt_valid():
    t = FrozenSoftGateTilt(
        tilt_id="SG-001", experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="BOS",
        feature="auctContinuation", direction=1,
        threshold=0.5, tilt_below=0.7, tilt_above=1.0,
    )
    assert t.tilt_below == 0.7


def test_soft_gate_tilt_rejects_bad_multiplier():
    with pytest.raises(ValueError, match="tilt_below"):
        FrozenSoftGateTilt(
            tilt_id="X", experiment_id="E",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            feature="f", direction=1, tilt_below=0.0, tilt_above=1.0,
        )


# ─── FrozenSLRiskThreshold ───────────────────────────────────────

def test_sl_risk_threshold_valid():
    t = FrozenSLRiskThreshold(
        threshold_id="SLT-001", experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="BOS",
        feature="spreadToATR", direction="above", threshold_value=0.15,
        dev_sl_lift=0.08, sl_risk_multiplier=0.5,
    )
    assert t.direction == "above"


def test_sl_risk_threshold_rejects_bad_direction():
    with pytest.raises(ValueError, match="direction"):
        FrozenSLRiskThreshold(
            threshold_id="X", experiment_id="E",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            feature="f", direction="sideways", threshold_value=0.1,
        )


def test_sl_risk_threshold_rejects_bad_multiplier():
    with pytest.raises(ValueError, match="sl_risk_multiplier"):
        FrozenSLRiskThreshold(
            threshold_id="X", experiment_id="E",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            feature="f", direction="above", threshold_value=0.1,
            sl_risk_multiplier=1.5,
        )


# ─── FrozenProductionConfig ──────────────────────────────────────

def test_frozen_config_valid_extended():
    """v3: config can include regime_blocks, bad_filter, sl_risk, soft tilts."""
    r = _threshold_rule()
    rb = FrozenRegimeBlockRule(
        rule_id="RB-001", experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="BOS",
        rule_type="auction_regime", condition="FAILED_AUCTION",
        mean_blocked_ev=-5.0, mean_pass_ev=2.0, mean_lift=7.0,
        mean_wr_blocked=0.3, mean_n_blocked=20, n_folds=3,
        fold_consistency=0.7, combined_p=0.01,
    )
    config = FrozenProductionConfig(
        experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        rules=(r,),
        regime_blocks=(rb,),
        sl_tp_selections=({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},),
        sizing_configs=({"symbol": "X", "setup": "BOS", "lot_mult": 1.2},),
    )
    assert len(config.regime_blocks) == 1
    assert config.freeze_timestamp


def test_frozen_config_rejects_empty_rules():
    with pytest.raises(ValueError, match="at least one"):
        FrozenProductionConfig(
            experiment_id="X", research_contract_hash="sha256:" + "a" * 64,
            rules=(),
        )


def test_frozen_config_rejects_duplicate_rule_ids():
    r1 = _threshold_rule()
    r2 = _threshold_rule()   # same rule_id
    with pytest.raises(ValueError, match="Duplicate"):
        FrozenProductionConfig(
            experiment_id="X", research_contract_hash="sha256:" + "a" * 64,
            rules=(r1, r2),
        )


def test_frozen_config_rejects_unknown_rule_ref():
    r = _threshold_rule()
    with pytest.raises(ValueError, match="unknown rule_id"):
        FrozenProductionConfig(
            experiment_id="X", research_contract_hash="sha256:" + "a" * 64,
            rules=(r,),
            sl_tp_selections=({"rule_id": "R-UNKNOWN", "sl": 1.0, "tp": 1.0},),
        )


def test_frozen_config_immutable():
    r = _threshold_rule()
    config = FrozenProductionConfig(
        experiment_id="X", research_contract_hash="sha256:" + "a" * 64,
        rules=(r,),
    )
    with pytest.raises(dataclasses.FrozenInstanceError):
        config.experiment_id = "Y"


def test_frozen_config_to_dict_includes_v3_fields():
    r = _threshold_rule()
    config = FrozenProductionConfig(
        experiment_id="EXP-001",
        research_contract_hash="sha256:" + "a" * 64,
        rules=(r,),
    )
    d = config.to_dict()
    assert "regime_blocks" in d
    assert "bad_entry_filter" in d
    assert "sl_risk_thresholds" in d
    assert "soft_gate_tilts" in d
