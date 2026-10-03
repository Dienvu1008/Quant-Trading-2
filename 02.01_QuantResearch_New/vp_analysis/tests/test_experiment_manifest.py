import pytest

from vp_analysis.core.exceptions import LineageError, ManifestStateError
from vp_analysis.core.experiment_manifest import (
    ExperimentLineage,
    ExperimentManifest,
    ExperimentResult,
    ExperimentStatus,
)


def make_manifest(eid, parent=None):
    return ExperimentManifest(
        experiment_id=eid,
        research_contract_hash="sha256:" + "a" * 64,
        dataset_hash="sha256:" + "b" * 64,
        code_hash="sha256:" + "c" * 64,
        parent_experiment_id=parent,
    )


# ─── Manifest state machine ─────────────────────────────────────

def test_manifest_initial_state():
    m = make_manifest("EXP-001")
    assert m.status == ExperimentStatus.ACTIVE
    assert m.result is None
    assert m.started_at


def test_manifest_complete_success():
    m = make_manifest("EXP-001")
    m.complete(ExperimentResult.SUCCESS)
    assert m.status == ExperimentStatus.COMPLETED
    assert m.result == ExperimentResult.SUCCESS
    assert m.completed_at


def test_manifest_complete_null_dev():
    m = make_manifest("EXP-001")
    m.complete(ExperimentResult.NULL_DEV)
    assert m.result == ExperimentResult.NULL_DEV


def test_manifest_complete_null_holdout():
    m = make_manifest("EXP-001")
    m.complete(ExperimentResult.NULL_HOLDOUT)
    assert m.result == ExperimentResult.NULL_HOLDOUT


def test_manifest_cannot_complete_twice():
    m = make_manifest("EXP-001")
    m.complete(ExperimentResult.SUCCESS)
    with pytest.raises(ManifestStateError):
        m.complete(ExperimentResult.SUCCESS)


def test_manifest_cannot_use_invalidated_in_complete():
    m = make_manifest("EXP-001")
    with pytest.raises(ManifestStateError):
        m.complete(ExperimentResult.INVALIDATED)


def test_manifest_invalidate():
    m = make_manifest("EXP-001")
    m.invalidate("FDR bug")
    assert m.status == ExperimentStatus.INVALIDATED
    assert m.result == ExperimentResult.INVALIDATED
    assert m.reason_for_supersession == "FDR bug"


def test_manifest_invalidate_is_terminal():
    m = make_manifest("EXP-001")
    m.invalidate("bug")
    with pytest.raises(ManifestStateError):
        m.invalidate("another")
    with pytest.raises(ManifestStateError):
        m.complete(ExperimentResult.SUCCESS)


def test_manifest_supersede():
    m = make_manifest("EXP-001")
    m.complete(ExperimentResult.SUCCESS)
    m.supersede("replaced by v2")
    assert m.status == ExperimentStatus.SUPERSEDED
    assert m.reason_for_supersession == "replaced by v2"


def test_manifest_supersede_active():
    m = make_manifest("EXP-001")
    m.supersede("overridden")
    assert m.status == ExperimentStatus.SUPERSEDED


def test_manifest_serialization_roundtrip():
    m = make_manifest("EXP-001")
    m.complete(ExperimentResult.SUCCESS)
    d = m.to_dict()
    m2 = ExperimentManifest.from_dict(d)
    assert m2.experiment_id == "EXP-001"
    assert m2.status == ExperimentStatus.COMPLETED
    assert m2.result == ExperimentResult.SUCCESS


# ─── Lineage DAG ────────────────────────────────────────────────

def test_lineage_add_and_get():
    lineage = ExperimentLineage()
    m = make_manifest("EXP-001")
    lineage.add(m)
    assert lineage.exists("EXP-001")
    assert lineage.get("EXP-001") is m


def test_lineage_rejects_duplicate_id():
    lineage = ExperimentLineage()
    lineage.add(make_manifest("EXP-001"))
    with pytest.raises(LineageError):
        lineage.add(make_manifest("EXP-001"))


def test_lineage_rejects_missing_parent():
    lineage = ExperimentLineage()
    with pytest.raises(LineageError):
        lineage.add(make_manifest("EXP-002", parent="EXP-001"))


def test_lineage_ancestors():
    lineage = ExperimentLineage()
    lineage.add(make_manifest("EXP-001"))
    lineage.add(make_manifest("EXP-002", parent="EXP-001"))
    lineage.add(make_manifest("EXP-003", parent="EXP-002"))
    assert lineage.get_ancestors("EXP-003") == ["EXP-002", "EXP-001"]


def test_lineage_descendants():
    lineage = ExperimentLineage()
    lineage.add(make_manifest("EXP-001"))
    lineage.add(make_manifest("EXP-002", parent="EXP-001"))
    lineage.add(make_manifest("EXP-003", parent="EXP-001"))
    lineage.add(make_manifest("EXP-004", parent="EXP-002"))
    assert set(lineage.get_descendants("EXP-001")) == {"EXP-002", "EXP-003", "EXP-004"}


def test_lineage_verify_acyclic_passes():
    lineage = ExperimentLineage()
    lineage.add(make_manifest("EXP-001"))
    lineage.add(make_manifest("EXP-002", parent="EXP-001"))
    lineage.verify_acyclic()  # no raise


def test_lineage_save_load_roundtrip(tmp_path):
    lineage = ExperimentLineage()
    lineage.add(make_manifest("EXP-001"))
    lineage.add(make_manifest("EXP-002", parent="EXP-001"))
    path = tmp_path / "lineage.json"
    lineage.save(path)
    lineage2 = ExperimentLineage()
    lineage2.load(path)
    assert lineage2.exists("EXP-001")
    assert lineage2.exists("EXP-002")
    assert lineage2.get("EXP-002").parent_experiment_id == "EXP-001"
