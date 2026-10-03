import pytest

from vp_analysis.core.exceptions import (
    ContractFrozenError,
    ContractValidationError,
)
from vp_analysis.core.research_contract import ResearchContract


# ─── Construction & basic properties ────────────────────────────

def test_construct_contract(minimal_contract_dict):
    c = ResearchContract.from_dict(minimal_contract_dict)
    assert c.version == "v1"
    assert not c.is_frozen
    assert c.contract_hash.startswith("sha256:")


def test_contract_has_two_targets(minimal_contract_dict):
    c = ResearchContract.from_dict(minimal_contract_dict)
    assert c.edge_discovery_target["name"] == "profitUSD"
    assert "L4" in c.edge_discovery_target["used_by"]
    assert c.bad_entry_canary_target["name"] == "MFE-based entry quality"
    assert "L10a" in c.bad_entry_canary_target["used_by"]


def test_contract_has_four_fdr_pools(minimal_contract_dict):
    c = ResearchContract.from_dict(minimal_contract_dict)
    assert set(c.fdr_pools.keys()) == {"hard_gate", "soft_gate", "regime_block", "bad_entry"}


def test_optimization_budget_has_tiebreaker(minimal_contract_dict):
    c = ResearchContract.from_dict(minimal_contract_dict)
    assert c.optimization_budget.tiebreaker == ["sl_atr DESC", "tp_atr DESC"]


# ─── Hash stability ─────────────────────────────────────────────

def test_contract_hash_deterministic(minimal_contract_dict):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    c2 = ResearchContract.from_dict(minimal_contract_dict)
    assert c1.contract_hash == c2.contract_hash


def test_contract_hash_changes_on_split_ratio(minimal_contract_dict):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    d = dict(minimal_contract_dict)
    d["split_ratio"] = 0.80
    c2 = ResearchContract.from_dict(d)
    assert c1.contract_hash != c2.contract_hash


def test_contract_hash_changes_on_shape_prior(minimal_contract_dict):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    d = dict(minimal_contract_dict)
    d["shape_priors"] = dict(minimal_contract_dict["shape_priors"])
    d["shape_priors"]["f1"] = "BAND"
    c2 = ResearchContract.from_dict(d)
    assert c1.contract_hash != c2.contract_hash


def test_contract_hash_changes_on_target_change(minimal_contract_dict):
    """v3: targets are part of the hash."""
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    d = dict(minimal_contract_dict)
    d["edge_discovery_target"] = dict(d["edge_discovery_target"])
    d["edge_discovery_target"]["name"] = "mfeATR"
    c2 = ResearchContract.from_dict(d)
    assert c1.contract_hash != c2.contract_hash


def test_contract_hash_ignores_created_at(minimal_contract_dict):
    d1 = dict(minimal_contract_dict)
    d1["created_at"] = "2026-01-01T00:00:00Z"
    d2 = dict(minimal_contract_dict)
    d2["created_at"] = "2026-12-31T00:00:00Z"
    c1 = ResearchContract.from_dict(d1)
    c2 = ResearchContract.from_dict(d2)
    assert c1.contract_hash == c2.contract_hash


# ─── Freeze protocol ────────────────────────────────────────────

def test_contract_freeze_prevents_mutation(minimal_contract_dict):
    c = ResearchContract.from_dict(minimal_contract_dict)
    c.freeze()
    assert c.is_frozen
    with pytest.raises(ContractFrozenError):
        c.version = "v2"


def test_contract_freeze_prevents_any_field(minimal_contract_dict):
    c = ResearchContract.from_dict(minimal_contract_dict)
    c.freeze()
    with pytest.raises(ContractFrozenError):
        c.split_ratio = 0.90


# ─── Validation ─────────────────────────────────────────────────

def test_validation_rejects_missing_fdr_pool(minimal_contract_dict):
    """v3: all four pools must be present."""
    d = dict(minimal_contract_dict)
    pools = dict(d["fdr_pools"])
    del pools["regime_block"]
    d["fdr_pools"] = pools
    with pytest.raises(ContractValidationError, match="regime_block"):
        ResearchContract.from_dict(d)


def test_validation_rejects_missing_bad_entry_pool(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    pools = dict(d["fdr_pools"])
    del pools["bad_entry"]
    d["fdr_pools"] = pools
    with pytest.raises(ContractValidationError, match="bad_entry"):
        ResearchContract.from_dict(d)


def test_validation_rejects_missing_target(minimal_contract_dict):
    """v3: both targets are required."""
    d = dict(minimal_contract_dict)
    del d["edge_discovery_target"]
    with pytest.raises((ContractValidationError, TypeError)):
        ResearchContract.from_dict(d)


def test_validation_rejects_target_without_name(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["edge_discovery_target"] = {"definition": "some def"}
    with pytest.raises(ContractValidationError, match="name"):
        ResearchContract.from_dict(d)


def test_validation_rejects_unknown_shape_prior(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["shape_priors"] = {"f1": "WEIRD"}
    with pytest.raises(ContractValidationError):
        ResearchContract.from_dict(d)


def test_validation_rejects_orphan_shape_prior(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["shape_priors"] = {"unknown_feature": "MONO_UP"}
    with pytest.raises(ContractValidationError):
        ResearchContract.from_dict(d)


def test_validation_rejects_bad_fdr_alpha(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    pools = dict(d["fdr_pools"])
    pools["hard_gate"] = {"name": "hard_gate", "max_hypotheses": 500, "alpha": 1.5}
    d["fdr_pools"] = pools
    with pytest.raises(ContractValidationError):
        ResearchContract.from_dict(d)


def test_validation_rejects_bad_split_ratio(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["split_ratio"] = 0.20
    with pytest.raises(ContractValidationError):
        ResearchContract.from_dict(d)


def test_validation_rejects_malformed_hash(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["dataset_hash"] = "not-a-hash"
    with pytest.raises(ContractValidationError):
        ResearchContract.from_dict(d)


# ─── Serialization ──────────────────────────────────────────────

def test_yaml_roundtrip(minimal_contract_dict, tmp_path):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    path = tmp_path / "contract.yaml"
    c1.to_yaml(path)
    c2 = ResearchContract.from_yaml(path)
    assert c1.contract_hash == c2.contract_hash
    assert c2.edge_discovery_target["name"] == "profitUSD"
    assert c2.optimization_budget.tiebreaker == ["sl_atr DESC", "tp_atr DESC"]
