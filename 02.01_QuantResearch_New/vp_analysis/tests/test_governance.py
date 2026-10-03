import datetime as dt

import pytest

from vp_analysis.core.exceptions import BudgetExceededError, CooldownError
from vp_analysis.core.experiment_manifest import ExperimentLineage, ExperimentManifest
from vp_analysis.core.governance import Governance
from vp_analysis.core.research_contract import ResearchContract


def _mk_manifest(eid, dataset_hash, contract_hash, started_at=None):
    return ExperimentManifest(
        experiment_id=eid,
        research_contract_hash=contract_hash,
        dataset_hash=dataset_hash,
        code_hash="sha256:" + "c" * 64,
        started_at=started_at or dt.datetime.utcnow().isoformat() + "Z",
    )


def test_first_experiment_allowed(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    gov = Governance(contract, lineage)
    gov.check_budget_before_start("sha256:" + "a" * 64)  # no raise


def test_budget_blocks_after_max_experiments(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    dataset_hash = "sha256:" + "a" * 64
    contract_hash = contract.contract_hash
    old_time = (dt.datetime.utcnow() - dt.timedelta(hours=48)).isoformat() + "Z"
    for i in range(5):
        lineage.add(_mk_manifest(f"EXP-{i:03d}", dataset_hash, contract_hash,
                                 started_at=old_time))
    gov = Governance(contract, lineage)
    with pytest.raises(BudgetExceededError):
        gov.check_budget_before_start(dataset_hash)


def test_cooldown_blocks_immediate_rerun(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    dataset_hash = "sha256:" + "a" * 64
    lineage.add(_mk_manifest("EXP-001", dataset_hash, contract.contract_hash))
    gov = Governance(contract, lineage)
    with pytest.raises(CooldownError):
        gov.check_budget_before_start(dataset_hash)


def test_cooldown_allows_after_wait(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    dataset_hash = "sha256:" + "a" * 64
    old_time = (dt.datetime.utcnow() - dt.timedelta(hours=48)).isoformat() + "Z"
    lineage.add(_mk_manifest("EXP-001", dataset_hash, contract.contract_hash,
                             started_at=old_time))
    gov = Governance(contract, lineage)
    gov.check_budget_before_start(dataset_hash)  # no raise


def test_next_experiment_id_format(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    gov = Governance(contract, lineage)
    eid = gov.next_experiment_id("sha256:" + "a" * 64)
    today = dt.datetime.utcnow().strftime("%Y-%m-%d")
    assert eid == f"EXP-{today}-001"


def test_next_experiment_id_increments(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    dataset_hash = "sha256:" + "a" * 64
    today = dt.datetime.utcnow().strftime("%Y-%m-%d")
    old_time = (dt.datetime.utcnow() - dt.timedelta(hours=48)).isoformat() + "Z"
    lineage.add(_mk_manifest(f"EXP-{today}-001", dataset_hash,
                             contract.contract_hash, started_at=old_time))
    gov = Governance(contract, lineage)
    eid = gov.next_experiment_id(dataset_hash)
    assert eid == f"EXP-{today}-002"
