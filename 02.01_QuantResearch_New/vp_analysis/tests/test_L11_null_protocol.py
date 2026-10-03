"""Tests for Layer 11 — Null Protocol."""
import json

import pytest

from vp_analysis.layers.L11_null_protocol import (
    ExperimentOutcome,
    LayerElevenResult,
    run,
    write_result,
)


# ─── Stubs ───────────────────────────────────────────────────────

class _StubL6:
    def __init__(self, n_frozen=0, n_soft=0):
        self.frozen_rules = tuple(object() for _ in range(n_frozen))
        self.validated_soft_gates = tuple(object() for _ in range(n_soft))


class _StubL8:
    def __init__(self, n_confirmed=0):
        self.n_rules_confirmed = n_confirmed


# ══════════════════════════════════════════════════════════════════
# Outcome classification
# ══════════════════════════════════════════════════════════════════

def test_null_dev_when_nothing_survived():
    l6 = _StubL6(n_frozen=0, n_soft=0)
    result = run("EXP-TEST", l6)
    assert result.outcome == ExperimentOutcome.NULL_DEV.value
    assert any("unseal_holdout" in a for a in result.forbidden_actions)


def test_null_holdout_when_frozen_but_none_confirmed():
    l6 = _StubL6(n_frozen=3, n_soft=0)
    l8 = _StubL8(n_confirmed=0)
    result = run("EXP-TEST", l6, l8)
    assert result.outcome == ExperimentOutcome.NULL_HOLDOUT.value
    assert result.n_frozen_rules == 3
    assert result.n_holdout_confirmed == 0


def test_success_when_some_confirmed():
    l6 = _StubL6(n_frozen=3, n_soft=1)
    l8 = _StubL8(n_confirmed=2)
    result = run("EXP-TEST", l6, l8)
    assert result.outcome == ExperimentOutcome.SUCCESS.value
    assert result.n_holdout_confirmed == 2
    assert result.n_soft_gates == 1


def test_soft_only_success_path():
    l6 = _StubL6(n_frozen=0, n_soft=2)
    result = run("EXP-TEST", l6, None)
    assert result.outcome == ExperimentOutcome.SUCCESS.value
    assert result.n_soft_gates == 2
    assert result.n_frozen_rules == 0


def test_inconclusive_when_holdout_not_run():
    l6 = _StubL6(n_frozen=2, n_soft=0)
    result = run("EXP-TEST", l6, None)
    assert result.outcome == ExperimentOutcome.INCONCLUSIVE.value


# ══════════════════════════════════════════════════════════════════
# Forbidden actions
# ══════════════════════════════════════════════════════════════════

def test_null_dev_forbids_rerun_and_tuning():
    l6 = _StubL6()
    result = run("EXP-TEST", l6)
    assert any("rerun" in a for a in result.forbidden_actions)
    assert any("tune_thresholds" in a for a in result.forbidden_actions)


def test_null_holdout_forbids_modify_rules():
    l6 = _StubL6(n_frozen=1)
    l8 = _StubL8(n_confirmed=0)
    result = run("EXP-TEST", l6, l8)
    assert any("modify_rules" in a for a in result.forbidden_actions)


def test_success_forbids_modify_after_holdout():
    l6 = _StubL6(n_frozen=1)
    l8 = _StubL8(n_confirmed=1)
    result = run("EXP-TEST", l6, l8)
    assert any("modify_rules" in a for a in result.forbidden_actions)
    assert any("modify_sl_tp" in a for a in result.forbidden_actions)


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_write_result(tmp_path):
    l6 = _StubL6(n_frozen=1)
    l8 = _StubL8(n_confirmed=1)
    result = run("EXP-TEST", l6, l8)
    write_result(result, tmp_path)
    assert (tmp_path / "experiment_result.json").exists()
    with (tmp_path / "experiment_result.json").open() as fh:
        d = json.load(fh)
    assert d["outcome"] == ExperimentOutcome.SUCCESS.value


def test_run_with_output_dir(tmp_path):
    l6 = _StubL6(n_frozen=0)
    result = run("EXP-TEST", l6, output_dir=tmp_path)
    assert (tmp_path / "experiment_result.json").exists()


# ══════════════════════════════════════════════════════════════════
# Edge case
# ══════════════════════════════════════════════════════════════════

def test_missing_experiment_id_raises():
    l6 = _StubL6()
    with pytest.raises(ValueError, match="experiment_id"):
        run("", l6)
