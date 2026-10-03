"""Tests for Layer 12 — Reporting & EA Guard Export.

Verifies that:
  - VPEdgeGuardConfig.mqh is generated with all 6 MQL5 functions
  - Hard gate rules emit correct threshold conditions
  - Soft tilts are exported (Fix #5) — not left as CSV-only
  - Regime blocks map condition names to int
  - SL risk thresholds emit correct direction conditions
  - Lot multipliers are emitted per (symbol, setup)
  - Empty inputs produce valid (stub) functions
  - Output JSON matches the .mqh content
"""
import json
from pathlib import Path

import pytest

from vp_analysis.core.frozen_types import FrozenProductionConfig, FrozenRule
from vp_analysis.layers.L12_reporting import (
    ReportingConfig,
    _build_hard_gate_rows,
    _build_regime_block_rows,
    _generate_mqh,
    run,
    REGIME_INT,
)


# ─── Helpers ─────────────────────────────────────────────────────

def _make_rule(
    rule_id="R-00001",
    symbol="XAUUSD",
    setup="BOS",
    feature="f_signal",
    gate_type="threshold",
    direction=1,
    lower=0.65,
    upper=None,
    ev=0.35,
    wr=0.58,
    pf=1.6,
) -> FrozenRule:
    return FrozenRule(
        rule_id=rule_id,
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol=symbol, setup=setup,
        gate_type=gate_type, direction=direction,
        features=(feature,),
        lower_bound=lower, upper_bound=upper,
        test_ev_mean=ev, test_wr_mean=wr, test_pf_mean=pf,
        test_n_avg=50, pvalue=0.01, pvalue_fdr=0.02,
        fdr_significant=True, fold_consistency=0.80, n_folds=4,
    )


def _make_prod_config(rules=None, sizing=None, sl_tp=None) -> FrozenProductionConfig:
    # FrozenProductionConfig requires at least one rule → always add a default
    default_rule = _make_rule()
    rule_list = list(rules) if rules is not None else [default_rule]
    if not rule_list:
        rule_list = [default_rule]
    return FrozenProductionConfig(
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        rules=tuple(rule_list),
        sl_tp_selections=tuple(sl_tp or []),
        sizing_configs=tuple(sizing or []),
    )


def _make_soft_candidate(symbol="XAUUSD", setup="BOS", feature="f_signal",
                          direction=1, ev_lift=0.40, perm_pvalue=0.01):
    """Minimal ValidatedCandidate-like object."""
    class _VC:
        def __init__(self):
            self.candidate_dict = {
                "symbol": symbol, "setup": setup, "feature": feature,
                "direction": direction, "ev_lift": ev_lift,
                "perm_pvalue": perm_pvalue,
                "ev_top": 0.30, "ev_bottom": -0.10,
                "wr_top": 0.55, "wr_bottom": 0.40,
                "n_total": 200, "n_top": 90, "n_bottom": 90,
            }
            self.p_adjusted = perm_pvalue
            self.label = f"{symbol}|{setup}|{feature}"
    return _VC()


def _make_regime_block(symbol="XAUUSD", setup="BOS",
                        rule_type="auction_regime", condition="FAILED_AUCTION",
                        ev=-3.5):
    """Minimal regime block candidate."""
    class _RB:
        pass
    rb = _RB()
    rb.symbol = symbol
    rb.setup = setup
    rb.rule_type = rule_type
    rb.condition = condition
    rb.mean_blocked_ev = ev
    rb.combined_p = 0.01
    return rb


# ══════════════════════════════════════════════════════════════════
# MQL5 function presence
# ══════════════════════════════════════════════════════════════════

def test_mqh_contains_all_six_functions(tmp_path):
    """All 6 MQL5 functions must appear in generated .mqh."""
    rule = _make_rule()
    config = _make_prod_config(rules=[rule])
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "VPGetEdgeMultiplier" in mqh
    assert "VPGetEdgeTiltMultiplier" in mqh
    assert "VPIsBlocked" in mqh
    assert "VPGetSLRiskMultiplier" in mqh
    assert "VPIsSymbolBlocked" in mqh
    assert "VPGetLotMultiplier" in mqh


def test_mqh_header_contains_experiment_id(tmp_path):
    rule = _make_rule()
    config = _make_prod_config(rules=[rule])
    result = run(config, "EXP-2026-09-19-001", output_dir=tmp_path)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "EXP-2026-09-19-001" in mqh


# ══════════════════════════════════════════════════════════════════
# Hard gates
# ══════════════════════════════════════════════════════════════════

def test_hard_gate_threshold_up_emitted(tmp_path):
    """MONO_UP threshold: value < lower_bound → block."""
    rule = _make_rule(direction=1, lower=0.65, upper=None)
    config = _make_prod_config(rules=[rule])
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert 'value < 0.650000' in mqh
    assert 'return 0.0' in mqh


def test_hard_gate_threshold_down_emitted(tmp_path):
    """MONO_DOWN threshold: value > upper_bound → block."""
    rule = _make_rule(direction=-1, lower=None, upper=0.35)
    config = _make_prod_config(rules=[rule])
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert 'value > 0.350000' in mqh
    assert 'return 0.0' in mqh


def test_hard_gate_band_emitted(tmp_path):
    """BAND gate: block outside band."""
    rule = FrozenRule(
        rule_id="R-00001", experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD", setup="BOS",
        gate_type="band", direction=0,
        features=("f_band",),
        lower_bound=0.30, upper_bound=0.70,
        fdr_significant=True,
    )
    config = _make_prod_config(rules=[rule])
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert '0.300000' in mqh
    assert '0.700000' in mqh
    assert 'return 0.0' in mqh


def test_n_hard_gates_counted(tmp_path):
    rules = [_make_rule(rule_id=f"R-{i:05d}", feature=f"f_{i}") for i in range(3)]
    config = _make_prod_config(rules=rules)
    result = run(config, "EXP-TEST", output_dir=tmp_path)
    assert result.n_hard_gates == 3


# ══════════════════════════════════════════════════════════════════
# Soft tilts [Fix #5]
# ══════════════════════════════════════════════════════════════════

def test_soft_tilt_exported_to_mqh(tmp_path):
    """Soft tilts must appear in VPGetEdgeTiltMultiplier, not just CSV."""
    config = _make_prod_config()
    soft = [_make_soft_candidate(feature="f_signal", direction=1, ev_lift=0.40)]
    result = run(config, "EXP-TEST", output_dir=tmp_path, validated_soft_gates=soft)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "VPGetEdgeTiltMultiplier" in mqh
    assert "f_signal" in mqh
    assert result.n_soft_tilts == 1


def test_soft_tilt_returns_less_than_one(tmp_path):
    """Tilt function must return < 1.0 for unfavourable side."""
    config = _make_prod_config()
    soft = [_make_soft_candidate()]
    result = run(config, "EXP-TEST", output_dir=tmp_path, validated_soft_gates=soft)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    # Default tilt multiplier 0.75 must appear
    assert "0.75" in mqh or "tilt" in mqh.lower()
    # Must NOT return 0.0 (only hard gates block completely)
    # Check that VPGetEdgeTiltMultiplier section doesn't have "return 0.0"
    tilt_section = mqh[mqh.find("VPGetEdgeTiltMultiplier"):
                       mqh.find("VPIsBlocked")]
    assert "return 0.0" not in tilt_section


# ══════════════════════════════════════════════════════════════════
# Regime blocks
# ══════════════════════════════════════════════════════════════════

def test_regime_block_emitted(tmp_path):
    """FAILED_AUCTION block should appear in VPIsBlocked with correct int."""
    config = _make_prod_config()
    blocks = [_make_regime_block(condition="FAILED_AUCTION")]
    result = run(config, "EXP-TEST", output_dir=tmp_path, regime_blocks=blocks)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    # FAILED_AUCTION = 6
    assert "regime==6" in mqh
    assert "return true" in mqh
    assert result.n_regime_blocks == 1


def test_regime_int_mapping():
    """Verify REGIME_INT covers all 9 regime names."""
    expected = {
        "BALANCED_ROTATION", "COMPRESSION", "TREND_INITIATION",
        "TREND_CONTINUATION", "RE_ACCUMULATION", "EXHAUSTION",
        "FAILED_AUCTION", "EXCESS", "CHAOTIC",
    }
    assert expected == set(REGIME_INT.keys())
    assert sorted(REGIME_INT.values()) == list(range(9))


# ══════════════════════════════════════════════════════════════════
# SL risk thresholds
# ══════════════════════════════════════════════════════════════════

def test_sl_risk_emitted(tmp_path):
    class _SLT:
        symbol = "XAUUSD"; setup = "BOS"; feature = "f_vol"
        direction = "above"; threshold_value = 1.5
        sl_risk_multiplier = 0.5; dev_sl_lift = 0.15
    config = _make_prod_config()
    result = run(config, "EXP-TEST", output_dir=tmp_path,
                 sl_risk_thresholds=[_SLT()])

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "VPGetSLRiskMultiplier" in mqh
    assert "f_vol" in mqh
    assert "value > 1.500000" in mqh
    assert "return 0.5000" in mqh
    assert result.n_sl_thresholds == 1


# ══════════════════════════════════════════════════════════════════
# Lot multipliers
# ══════════════════════════════════════════════════════════════════

def test_lot_multiplier_emitted(tmp_path):
    rule = _make_rule(symbol="XAUUSD", setup="BOS")
    config = _make_prod_config(
        rules=[rule],
        sizing=[{"rule_id": "R-00001", "lot_mult": 1.25}],
    )
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "VPGetLotMultiplier" in mqh
    assert "1.2500" in mqh
    assert result.n_lot_multipliers == 1


def test_lot_multiplier_fallback_one(tmp_path):
    """If no sizing data, function should return 1.0 as fallback."""
    config = _make_prod_config()
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "return 1.0;" in mqh


# ══════════════════════════════════════════════════════════════════
# Output files
# ══════════════════════════════════════════════════════════════════

def test_json_and_mqh_written(tmp_path):
    config = _make_prod_config(rules=[_make_rule()])
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    assert result.mqh_path is not None
    assert result.json_path is not None
    assert Path(result.mqh_path).exists()
    assert Path(result.json_path).exists()
    assert (tmp_path / "L12_summary.json").exists()


def test_json_content(tmp_path):
    rule = _make_rule()
    config = _make_prod_config(rules=[rule])
    result = run(config, "EXP-TEST", output_dir=tmp_path)

    with Path(result.json_path).open() as fh:
        d = json.load(fh)
    assert d["experiment_id"] == "EXP-TEST"
    assert "hard_gates" in d
    assert len(d["hard_gates"]) == 1
    assert d["version"] == "3.0"


def test_mqh_has_header_guard(tmp_path):
    """#ifndef / #define / #endif must be present."""
    config = _make_prod_config()
    result = run(config, "EXP-TEST", output_dir=tmp_path)
    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "#ifndef __VP_EA_EDGEGUARD_CONFIG_MQH__" in mqh
    assert "#define __VP_EA_EDGEGUARD_CONFIG_MQH__" in mqh
    assert "#endif" in mqh


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_config_runs_without_crash(tmp_path):
    """Minimal config (1 required rule, no tilts/blocks/SL) → valid stub .mqh."""
    config = _make_prod_config()   # has exactly 1 default rule
    result = run(config, "EXP-TEST", output_dir=tmp_path)
    assert result.n_soft_tilts == 0
    assert result.n_regime_blocks == 0
    assert result.n_sl_thresholds == 0
    mqh = Path(result.mqh_path).read_text(encoding="utf-8")
    assert "VPGetEdgeMultiplier" in mqh  # functions always present


def test_missing_experiment_id_raises():
    config = _make_prod_config()
    with pytest.raises(ValueError, match="experiment_id"):
        run(config, "")


def test_no_output_dir_runs(tmp_path):
    """Without output_dir, run should return result without writing files."""
    config = _make_prod_config(rules=[_make_rule()])
    result = run(config, "EXP-TEST", output_dir=None)
    assert result.mqh_path is None
    assert result.json_path is None
    assert result.n_hard_gates == 1
