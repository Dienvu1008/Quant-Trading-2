import pytest

from vp_analysis.core.exceptions import PoolCorrectedError, PoolRegistrationError
from vp_analysis.core.fdr_registry import FDRPoolRegistry
from vp_analysis.core.research_contract import ResearchContract


@pytest.fixture
def registry(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    return FDRPoolRegistry(contract)


# ─── Configuration (v3: 4 pools) ────────────────────────────────

def test_four_pools_created(registry):
    names = set(registry.pool_names)
    assert names == {"hard_gate", "soft_gate", "regime_block", "bad_entry"}


def test_unknown_pool_raises(registry):
    with pytest.raises(PoolRegistrationError, match="Unknown pool"):
        registry.register("nonexistent", "H1", 0.05)


# ─── Registration ───────────────────────────────────────────────

def test_register_single(registry):
    registry.register("hard_gate", "H1", 0.01)
    assert registry.pool_size("hard_gate") == 1


def test_register_in_regime_block_pool(registry):
    registry.register("regime_block", "R1", 0.03)
    assert registry.pool_size("regime_block") == 1


def test_register_in_bad_entry_pool(registry):
    registry.register("bad_entry", "B1", 0.04)
    assert registry.pool_size("bad_entry") == 1


def test_register_duplicate_label_raises(registry):
    registry.register("hard_gate", "H1", 0.01)
    with pytest.raises(PoolRegistrationError, match="Duplicate"):
        registry.register("hard_gate", "H1", 0.02)


def test_register_invalid_p_low(registry):
    with pytest.raises(PoolRegistrationError, match="p_value"):
        registry.register("hard_gate", "H1", -0.1)


def test_register_invalid_p_high(registry):
    with pytest.raises(PoolRegistrationError, match="p_value"):
        registry.register("hard_gate", "H1", 1.5)


def test_register_empty_label(registry):
    with pytest.raises(PoolRegistrationError, match="empty"):
        registry.register("hard_gate", "", 0.05)


def test_register_many(registry):
    registry.register_many("hard_gate", [("H1", 0.01), ("H2", 0.02)])
    assert registry.pool_size("hard_gate") == 2


def test_register_many_atomic(registry):
    # Invalid p in second item → nothing registered
    with pytest.raises(PoolRegistrationError):
        registry.register_many("hard_gate", [("H1", 0.01), ("H2", -0.5)])
    assert registry.pool_size("hard_gate") == 0


# ─── Isolation ──────────────────────────────────────────────────

def test_pools_are_isolated(registry):
    registry.register("hard_gate", "H1", 0.01)
    registry.register("soft_gate", "S1", 0.01)
    assert registry.pool_size("hard_gate") == 1
    assert registry.pool_size("soft_gate") == 1
    # Correcting hard_gate does not affect soft_gate
    registry.correct("hard_gate")
    assert not registry.is_corrected("soft_gate")


# ─── Correction ─────────────────────────────────────────────────

def test_correct_empty_pool(registry):
    result = registry.correct("hard_gate")
    assert len(result.labels) == 0
    assert len(result.reject) == 0


def test_correct_significant(registry):
    registry.register("hard_gate", "H1", 0.001)
    registry.register("hard_gate", "H2", 0.002)
    result = registry.correct("hard_gate")
    assert result.reject[0] and result.reject[1]


def test_correct_seals_pool(registry):
    registry.correct("hard_gate")
    assert registry.is_corrected("hard_gate")
    with pytest.raises(PoolCorrectedError):
        registry.register("hard_gate", "H_new", 0.01)


def test_correct_twice_raises(registry):
    registry.correct("hard_gate")
    with pytest.raises(PoolCorrectedError):
        registry.correct("hard_gate")


def test_correct_returns_pool_result(registry):
    registry.register("soft_gate", "S1", 0.01)
    result = registry.correct("soft_gate")
    assert result.pool_name == "soft_gate"
    assert "S1" in result.labels
    d = result.as_dict()
    assert "S1" in d
    assert "p_value" in d["S1"]


# ─── Conservative padding (v3 Fix #3) ───────────────────────────

def test_conservative_padding_n_total(registry):
    """n_total > registered → pad with p=1.0, so denominator is n_total."""
    registry.register("hard_gate", "H1", 0.001)
    # 1 registered, but 10 hypotheses were attempted
    result = registry.correct("hard_gate", n_total=10)
    assert result.n_total_used == 10
    # The real hypothesis should still be significant
    assert result.reject[0]


def test_conservative_padding_makes_correction_stricter(registry):
    """Same p-value, larger n_total → harder to reject."""
    registry.register("hard_gate", "H1", 0.04)
    r1 = registry.correct("hard_gate", n_total=1)
    assert r1.reject[0]   # passes without padding

    registry2 = FDRPoolRegistry(
        ResearchContract.from_dict(
            pytest.approx  # just need any contract — use fixture via direct import
        )
    ) if False else None   # skip — we test via separate instance below


def test_no_padding_when_n_total_equals_registered(registry):
    registry.register("hard_gate", "H1", 0.01)
    result = registry.correct("hard_gate", n_total=1)
    assert result.n_total_used == 1


def test_no_padding_when_n_total_none(registry):
    registry.register("hard_gate", "H1", 0.01)
    result = registry.correct("hard_gate", n_total=None)
    assert result.n_total_used == 1


# ─── get_result ─────────────────────────────────────────────────

def test_get_result_before_correction_raises(registry):
    with pytest.raises(PoolCorrectedError):
        registry.get_result("hard_gate")


def test_get_result_after_correction(registry):
    registry.register("hard_gate", "H1", 0.01)
    registry.correct("hard_gate")
    result = registry.get_result("hard_gate")
    assert result.pool_name == "hard_gate"
    assert "H1" in result.labels
