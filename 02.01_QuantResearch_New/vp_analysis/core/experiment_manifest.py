"""Experiment manifest and lineage DAG.

Every pipeline run creates an ExperimentManifest. Manifests are linked into
a lineage DAG so that:
  - Every experiment has a unique ID
  - Every experiment (except root) has a parent
  - Bug fixes create new experiments (never overwrite)
  - The full history is auditable via ancestor/descendant queries
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import asdict, dataclass
from enum import Enum
from pathlib import Path
from typing import Optional

from .exceptions import LineageError, ManifestStateError


class ExperimentStatus(str, Enum):
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    INVALIDATED = "INVALIDATED"
    SUPERSEDED = "SUPERSEDED"


class ExperimentResult(str, Enum):
    SUCCESS = "SUCCESS"
    NULL_DEV = "NULL_DEV"
    NULL_HOLDOUT = "NULL_HOLDOUT"
    INVALIDATED = "INVALIDATED"


TERMINAL_STATUSES = {ExperimentStatus.INVALIDATED, ExperimentStatus.SUPERSEDED}


@dataclass
class ExperimentManifest:
    experiment_id: str
    research_contract_hash: str
    dataset_hash: str
    code_hash: str
    status: ExperimentStatus = ExperimentStatus.ACTIVE
    parent_experiment_id: Optional[str] = None
    started_at: str = ""
    completed_at: Optional[str] = None
    result: Optional[ExperimentResult] = None
    reason_for_supersession: Optional[str] = None

    def __post_init__(self) -> None:
        if not self.experiment_id:
            raise ValueError("experiment_id is required")
        if not self.started_at:
            self.started_at = dt.datetime.utcnow().isoformat() + "Z"

    # ─── State transitions ──────────────────────────────────────

    def complete(self, result: ExperimentResult) -> None:
        if self.status != ExperimentStatus.ACTIVE:
            raise ManifestStateError(
                f"Cannot complete manifest in status {self.status.value}"
            )
        if result == ExperimentResult.INVALIDATED:
            raise ManifestStateError(
                "Use invalidate(reason) to mark a manifest INVALIDATED"
            )
        self.status = ExperimentStatus.COMPLETED
        self.result = result
        self.completed_at = dt.datetime.utcnow().isoformat() + "Z"

    def invalidate(self, reason: str) -> None:
        if self.status in TERMINAL_STATUSES:
            raise ManifestStateError(
                f"Cannot invalidate manifest in terminal status {self.status.value}"
            )
        self.status = ExperimentStatus.INVALIDATED
        self.result = ExperimentResult.INVALIDATED
        self.reason_for_supersession = reason
        self.completed_at = dt.datetime.utcnow().isoformat() + "Z"

    def supersede(self, reason: str) -> None:
        if self.status in TERMINAL_STATUSES:
            raise ManifestStateError(
                f"Cannot supersede manifest in terminal status {self.status.value}"
            )
        self.status = ExperimentStatus.SUPERSEDED
        self.reason_for_supersession = reason
        if not self.completed_at:
            self.completed_at = dt.datetime.utcnow().isoformat() + "Z"

    # ─── Serialization ──────────────────────────────────────────

    def to_dict(self) -> dict:
        d = asdict(self)
        d["status"] = self.status.value
        d["result"] = self.result.value if self.result else None
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "ExperimentManifest":
        d = dict(d)
        d["status"] = ExperimentStatus(d["status"])
        if d.get("result"):
            d["result"] = ExperimentResult(d["result"])
        return cls(**d)


class ExperimentLineage:
    """DAG of experiment manifests with persistence.

    Not thread-safe. Assumes single-writer access.
    """

    def __init__(self, storage_path: Optional[Path] = None):
        self.storage_path = Path(storage_path) if storage_path else None
        self._manifests: dict[str, ExperimentManifest] = {}

    # ─── Mutation ───────────────────────────────────────────────

    def add(self, manifest: ExperimentManifest) -> None:
        if manifest.experiment_id in self._manifests:
            raise LineageError(
                f"Experiment {manifest.experiment_id} already exists in lineage"
            )
        if manifest.parent_experiment_id:
            if manifest.parent_experiment_id not in self._manifests:
                raise LineageError(
                    f"Parent {manifest.parent_experiment_id} not in lineage"
                )
        self._manifests[manifest.experiment_id] = manifest

    # ─── Queries ────────────────────────────────────────────────

    def get(self, experiment_id: str) -> ExperimentManifest:
        if experiment_id not in self._manifests:
            raise LineageError(f"Experiment {experiment_id} not found")
        return self._manifests[experiment_id]

    def exists(self, experiment_id: str) -> bool:
        return experiment_id in self._manifests

    def all(self) -> list[ExperimentManifest]:
        return list(self._manifests.values())

    def get_ancestors(self, experiment_id: str) -> list[str]:
        """Return ancestor IDs, closest-first. Raises on cycle."""
        ancestors: list[str] = []
        current = self.get(experiment_id)
        visited = {experiment_id}
        while current.parent_experiment_id:
            parent = current.parent_experiment_id
            if parent in visited:
                raise LineageError(f"Cycle detected involving {parent}")
            visited.add(parent)
            ancestors.append(parent)
            current = self.get(parent)
        return ancestors

    def get_children(self, experiment_id: str) -> list[str]:
        return [
            m.experiment_id for m in self._manifests.values()
            if m.parent_experiment_id == experiment_id
        ]

    def get_descendants(self, experiment_id: str) -> list[str]:
        """BFS of all descendants."""
        descendants: list[str] = []
        queue = list(self.get_children(experiment_id))
        visited = {experiment_id}
        while queue:
            eid = queue.pop(0)
            if eid in visited:
                continue
            visited.add(eid)
            descendants.append(eid)
            queue.extend(self.get_children(eid))
        return descendants

    # ─── Consistency ────────────────────────────────────────────

    def verify_acyclic(self) -> None:
        """DFS cycle check. Raises LineageError if any cycle found."""
        WHITE, GRAY, BLACK = 0, 1, 2
        color = {eid: WHITE for eid in self._manifests}

        def visit(eid: str) -> None:
            color[eid] = GRAY
            parent = self._manifests[eid].parent_experiment_id
            if parent:
                if color[parent] == GRAY:
                    raise LineageError(f"Cycle detected involving {eid}")
                if color[parent] == WHITE:
                    visit(parent)
            color[eid] = BLACK

        for eid in list(self._manifests):
            if color[eid] == WHITE:
                visit(eid)

    # ─── Persistence ────────────────────────────────────────────

    def save(self, path: Optional[Path] = None) -> None:
        path = Path(path) if path else self.storage_path
        if not path:
            raise ValueError("No storage path provided")
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as f:
            json.dump(
                [m.to_dict() for m in self._manifests.values()],
                f, indent=2,
            )

    def load(self, path: Optional[Path] = None) -> None:
        path = Path(path) if path else self.storage_path
        if not path or not path.exists():
            return
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        self._manifests = {}
        for d in data:
            self._manifests[d["experiment_id"]] = ExperimentManifest.from_dict(d)
        self.verify_acyclic()
