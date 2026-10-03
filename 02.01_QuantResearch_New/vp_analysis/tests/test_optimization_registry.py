import pytest

from vp_analysis.core.exceptions import OptimizationError
from vp_analysis.core.optimization_registry import (
    FrozenOptimizationResult,
    OptimizationRegistry,
    _apply_tiebreaker,
    _parse_tiebreaker,
)
from vp_analysis.core.research_contract import ResearchContract


@pytest.fixture
def registry(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    return OptimizationRegistry(contract)


# ─── Tiebreaker helpers (v3 Fix #6) ─────────────────────────────

def test_parse_tiebreaker_desc():
    specs = _parse_tiebreaker(["sl_atr DESC", "tp_atr DESC"])
    assert specs[0] == ("sl_atr", True)
    assert specs[1] == ("tp_atr", True)


def test_parse_tiebreaker_asc():
    specs = _parse_tiebreaker(["sl_atr ASC"])
    assert specs[0] == ("sl_atr", False)


def test_apply_tiebreaker_prefers_larger_sl():
    candidates = [
        {"sl": 1.0, "tp": 2.0, "utility": 5.0},
        {"sl": 1.5, "tp": 2.0, "utility": 5.0},
        {"sl": 2.0, "tp": 2.0, "utility": 5.0},
    ]
    specs = _parse_tiebreaker(["sl DESC"])
    best = _apply_tiebreaker(candidates, specs)
    assert best["sl"] == 2.0


def test_apply_tiebreaker_secondary_tp():
    candidates = [
        {"sl": 1.5, "tp": 1.0, "utility": 5.0},
        {"sl": 1.5, "tp": 2.0, "utility": 5.0},
    ]
    specs = _parse_tiebreaker(["sl DESC", "tp DESC"])
    best = _apply_tiebreaker(candidates, specs)
    assert best["tp"] == 2.0


def test_apply_tiebreaker_single_candidate():
    candidates = [{"sl": 1.0, "tp": 1.0, "utility": 3.0}]
    specs = _parse_tiebreaker(["sl DESC"])
    best = _apply_tiebreaker(candidates, specs)
    assert best["sl"] == 1.0


def test_apply_tiebreaker_empty_raises():
    with pytest.raises(OptimizationError, match="No candidates"):
        _apply_tiebreaker([], _parse_tiebreaker(["sl DESC"]))


# ─── Registry introspection ─────────────────────────────────────

def test_registry_candidates(registry):
    assert set(registry.sl_candidates) == {1.0, 1.5, 2.0}
    assert set(registry.tp_candidates) == {1.0, 1.5, 2.0}


def test_registry_tiebreaker(registry):
    assert registry.tiebreaker == ["sl_atr DESC", "tp_atr DESC"]


# ─── SL/TP optimization ─────────────────────────────────────────

def test_optimize_sl_tp_best_utility(registry):
    def evaluate(params):
        # Best utility at sl=2.0, tp=2.0
        return params["sl"] + params["tp"]

    result = registry.optimize_sl_tp("R-001", evaluate)
    assert result.rule_id == "R-001"
    assert result.parameter_name == "sl_tp"
    best = dict(result.selected)
    assert best["sl"] == 2.0
    assert best["tp"] == 2.0


def test_optimize_sl_tp_tiebreaker_applied(registry):
    """When all utilities equal, tiebreaker should prefer larger sl then tp."""
    def evaluate(params):
        return 1.0   # flat utility — all combos tied

    result = registry.optimize_sl_tp("R-001", evaluate)
    best = dict(result.selected)
    # Contract tiebreaker: sl DESC then tp DESC → prefer largest sl=2.0, tp=2.0
    assert best["sl"] == 2.0
    assert best["tp"] == 2.0
    assert result.tiebreaker_applied


def test_optimize_sl_tp_evaluates_all_combos(registry):
    calls = []

    def evaluate(params):
        calls.append((params["sl"], params["tp"]))
        return params["sl"] * params["tp"]

    registry.optimize_sl_tp("R-001", evaluate)
    # 3 SL × 3 TP = 9 combos
    assert len(calls) == 9


def test_optimize_sl_tp_cannot_rerun(registry):
    registry.optimize_sl_tp("R-001", lambda p: 1.0)
    with pytest.raises(OptimizationError, match="already optimized"):
        registry.optimize_sl_tp("R-001", lambda p: 1.0)


def test_optimize_sl_tp_nan_raises(registry):
    with pytest.raises(OptimizationError, match="NaN"):
        registry.optimize_sl_tp("R-001", lambda p: float("nan"))


def test_optimize_sl_tp_empty_rule_id(registry):
    with pytest.raises(OptimizationError, match="rule_id"):
        registry.optimize_sl_tp("", lambda p: 1.0)


# ─── Sizing optimization ─────────────────────────────────────────

def test_optimize_sizing_best(registry):
    mults = [0.5, 1.0, 1.2, 1.5]

    def evaluate(params):
        return params["lot_mult"]

    result = registry.optimize_sizing("R-002", mults, evaluate)
    assert dict(result.selected)["lot_mult"] == 1.5


def test_optimize_sizing_empty_candidates(registry):
    with pytest.raises(OptimizationError, match="empty"):
        registry.optimize_sizing("R-002", [], lambda p: 1.0)


# ─── Lookup ─────────────────────────────────────────────────────

def test_get_result_after_optimization(registry):
    registry.optimize_sl_tp("R-001", lambda p: p["sl"])
    result = registry.get_result("R-001")
    assert result.rule_id == "R-001"


def test_get_result_missing_raises(registry):
    with pytest.raises(OptimizationError, match="No optimization result"):
        registry.get_result("R-999")


def test_all_results_returns_dict(registry):
    registry.optimize_sl_tp("R-001", lambda p: 1.0)
    registry.optimize_sl_tp("R-002", lambda p: 2.0)
    all_r = registry.all_results()
    assert set(all_r.keys()) == {"R-001", "R-002"}


# ─── FrozenOptimizationResult ────────────────────────────────────

def test_frozen_result_to_dict(registry):
    registry.optimize_sl_tp("R-001", lambda p: p["sl"] + p["tp"])
    result = registry.get_result("R-001")
    d = result.to_dict()
    assert "rule_id" in d
    assert "selected" in d
    assert "evaluated_all" in d
    assert "tiebreaker_applied" in d
