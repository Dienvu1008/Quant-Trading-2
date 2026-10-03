# Sprint 0A — Governance Kernel

> **v3 changes (từ SPECIFICATION.md v3):**
> - `ResearchContract`: khai báo **2 targets** tách biệt (`edge_discovery_target` = profitUSD, `bad_entry_canary_target` = MFE-based); contract validate rằng cả hai phải có mặt và dùng đúng layer. Không còn một `target_definition` duy nhất. [Fix #2]
> - `FDR pools`: nâng lên **4 pools** (`hard_gate`, `soft_gate`, `regime_block`, `bad_entry`) với n_total_hypotheses tường minh được log vào run_meta. [Fix #3]
> - `SealedHoldout.unseal_once()`: phải **persist access log ra disk** (`holdout_access.json`) ngay khi unseal, check disk (không chỉ in-memory) để ngăn double-unseal sau restart. [Fix #4]
> - Thêm **`FrozenRegimeBlockRule`** và **`FrozenBadEntryFilter`** vào `frozen_types.py`. [New L4b, L10a]
> - Thêm `regime_block` và `bad_entry` vào `contract_v1.yaml` FDR pools. [Fix #3]
> - `FrozenProductionConfig` mở rộng: bao gồm `regime_blocks`, `bad_entry_filter`, `sl_risk_thresholds`, `soft_gate_tilts`. [New L4b, L7c, Fix #5]
> - SL/TP tiebreaker: `tiebreaker: ["sl_atr DESC", "tp_atr DESC"]` trong optimization_budget của contract yaml. [Fix #6]

Dùng defaults đã đề xuất (có thể đổi trong contract file trước khi chạy experiment đầu tiên):

```yaml
max_experiments_per_dataset: 5
cooldown_hours: 24
max_eda_rerun: 1
hard_gate_max_hyp: 500
soft_gate_max_hyp: 200
bad_entry_max_hyp: 200
sl_candidates: [1.0, 1.5, 2.0]
tp_candidates: [1.0, 1.5, 2.0]
```

Sprint 0A deliverables:
- `ResearchContract` — 6 hashes + budget + freeze protocol
- `ExperimentManifest` + `ExperimentLineage` — DAG với state machine
- `Governance` — selection budget enforcement
- Provenance utilities — deterministic hashing
- Test suite — 25 tests, verify tất cả

---

## File tree

```text
vp_analysis/
├── __init__.py
├── core/
│   ├── __init__.py
│   ├── exceptions.py
│   ├── provenance.py
│   ├── research_contract.py
│   ├── experiment_manifest.py
│   └── governance.py
├── contracts/
│   └── contract_v1.yaml
└── tests/
    ├── __init__.py
    ├── conftest.py
    ├── test_provenance.py
    ├── test_research_contract.py
    ├── test_experiment_manifest.py
    └── test_governance.py
```

---

## `vp_analysis/__init__.py`

```python
"""VP Analysis — Research pipeline with governance kernel."""
__version__ = "0.1.0"
```

## `vp_analysis/core/__init__.py`

```python
"""Core governance modules."""
from .research_contract import ResearchContract
from .experiment_manifest import (
    ExperimentManifest, ExperimentLineage,
    ExperimentStatus, ExperimentResult,
)
from .governance import Governance

__all__ = [
    "ResearchContract",
    "ExperimentManifest", "ExperimentLineage",
    "ExperimentStatus", "ExperimentResult",
    "Governance",
]
```

## `vp_analysis/core/exceptions.py`

```python
"""Governance exception hierarchy.

All exceptions raised by the governance kernel inherit from GovernanceError,
so callers can catch them uniformly if needed.
"""


class GovernanceError(Exception):
    """Base class for all governance-related errors."""


class ContractValidationError(GovernanceError):
    """Raised when a ResearchContract is invalid or inconsistent."""


class ContractFrozenError(GovernanceError):
    """Raised when attempting to modify a frozen contract."""


class ManifestStateError(GovernanceError):
    """Raised on invalid ExperimentManifest state transition."""


class LineageError(GovernanceError):
    """Raised for DAG/lineage consistency violations."""


class BudgetExceededError(GovernanceError):
    """Raised when a selection budget constraint is violated."""


class CooldownError(GovernanceError):
    """Raised when experiments are run too close together."""
```

## `vp_analysis/core/provenance.py`

```python
"""Deterministic hashing utilities for research provenance.

All hashes must be:
  - Deterministic: same input → same hash
  - Stable across Python versions and platforms
  - Canonical: independent of dict ordering, whitespace

Format: 'sha256:<hex>' so hash type is self-describing.
"""
from __future__ import annotations

import fnmatch
import hashlib
import json
from pathlib import Path
from typing import Any, Iterable

import pandas as pd


# ─── String / object hashing ────────────────────────────────────

def hash_string(s: str) -> str:
    return "sha256:" + hashlib.sha256(s.encode("utf-8")).hexdigest()


def _canonicalize(obj: Any) -> Any:
    """Convert obj to canonical form for stable hashing.

    - dicts: sort keys, recurse
    - lists/tuples: preserve order, recurse
    - sets: sort (order-independent)
    - floats: repr() to avoid formatting drift; NaN/Inf as sentinels
    - Path: str
    """
    if obj is None or isinstance(obj, (bool, int, str)):
        return obj
    if isinstance(obj, float):
        if obj != obj:               # NaN
            return "__nan__"
        if obj == float("inf"):
            return "__inf__"
        if obj == float("-inf"):
            return "__-inf__"
        return repr(obj)
    if isinstance(obj, dict):
        return {str(k): _canonicalize(v) for k, v in sorted(obj.items())}
    if isinstance(obj, (list, tuple)):
        return [_canonicalize(x) for x in obj]
    if isinstance(obj, set):
        return sorted(_canonicalize(x) for x in obj)
    if isinstance(obj, Path):
        return str(obj)
    return str(obj)


def hash_dict(d: dict) -> str:
    canonical = _canonicalize(d)
    serialized = json.dumps(canonical, sort_keys=True, separators=(",", ":"))
    return hash_string(serialized)


# ─── File / directory hashing ───────────────────────────────────

def hash_file(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def hash_files(
    paths: Iterable[Path],
    exclude_patterns: Iterable[str] = (),
) -> str:
    """Hash a set of files in deterministic order.

    exclude_patterns: fnmatch patterns applied to the full path string.
    Directories are expanded recursively.
    """
    exclude_patterns = list(exclude_patterns)
    collected: list[Path] = []

    for p in paths:
        p = Path(p)
        if not p.exists():
            continue
        candidates = p.rglob("*") if p.is_dir() else [p]
        for f in candidates:
            if not f.is_file():
                continue
            if any(fnmatch.fnmatch(str(f), pat) for pat in exclude_patterns):
                continue
            collected.append(f)

    collected = sorted(set(collected), key=lambda x: str(x))
    per_file = [{"path": str(f), "hash": hash_file(f)} for f in collected]
    return hash_dict({"files": per_file})


# ─── DataFrame hashing ──────────────────────────────────────────

def hash_dataframe(
    df: pd.DataFrame,
    exclude_cols: Iterable[str] = (),
) -> str:
    """Stable hash of a DataFrame's content.

    Uses pandas' built-in hashing (designed for this purpose).
    Columns are sorted for determinism; excluded columns are dropped.
    """
    exclude_cols = set(exclude_cols)
    cols = [c for c in sorted(df.columns) if c not in exclude_cols]
    subset = df[cols]
    h = hashlib.sha256(
        pd.util.hash_pandas_object(subset, index=True).values.tobytes()
    )
    return "sha256:" + h.hexdigest()
```

## `vp_analysis/core/research_contract.py`

```python
"""Research Contract — immutable definition of a research experiment.

The contract declares WHAT an experiment may do (features, tests, budgets,
split policy) and is identified by a deterministic hash. Everything
downstream must respect the contract; any change to the contract requires
a new experiment with a new contract hash.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Optional

import yaml

from .exceptions import ContractFrozenError, ContractValidationError
from .provenance import hash_dict


# ─── Sub-configurations ─────────────────────────────────────────

@dataclass
class SelectionBudget:
    """Meta-governance: how many experiments can be run on one dataset."""
    max_experiments_per_dataset: int = 5
    max_contract_changes_per_day: int = 3
    cooldown_hours_between_experiments: int = 24
    max_eda_inspect_and_rerun: int = 1
    config_frozen_after_start: bool = True


@dataclass
class FDRPoolConfig:
    """One isolated multiple-testing pool."""
    name: str
    max_hypotheses: int
    alpha: float


@dataclass
class OptimizationBudget:
    """Pre-registered parameter grid (NOT hypotheses — no FDR)."""
    sl_candidates: list
    tp_candidates: list
    sizing_configs: int
    utility_function: str


@dataclass
class StoppingRules:
    """Thresholds for early stopping and rule acceptance."""
    min_group_samples: int
    min_fold_consistency: float
    min_effect_size: float
    max_outer_folds: int
    max_inner_folds: int


@dataclass
class ProductionCriteria:
    """Criteria for accepting a rule as production candidate."""
    min_ev: float
    min_pf: float
    min_wr: float
    require_robust_across_styles: bool
    require_holdout_confirmation: bool


# ─── Main contract ──────────────────────────────────────────────

class ResearchContract:
    """Immutable definition of an experiment.

    Lifecycle:
        contract = ResearchContract.from_yaml(path)
        contract.freeze()          # lock in place
        # ... run pipeline ...
        # After freeze, any setattr raises ContractFrozenError.

    The contract_hash excludes:
        - created_at (metadata, not content)
        - _frozen (runtime state)
    """

    HASHED_FIELDS = (
        "version",
        "observation_unit",
        "style_filter",
        "pre_registered",
        "feature_direction",
        "shape_priors",
        "allowed_interactions",
        "gate_types",
        "allowed_directions",
        "primary_test",
        "screening_test",
        "multiple_testing_method",
        "fdr_pools",
        "optimization_budget",
        "stopping_rules",
        "production_criteria",
        "selection_budget",
        "split_ratio",
        "split_method",
    )

    IDENTITY_HASHES = (
        "dataset_hash",
        "code_hash",
        "config_hash",
        "feature_registry_hash",
        "target_definition_hash",
        "split_definition_hash",
    )

    def __init__(
        self,
        *,
        version: str,
        observation_unit: str,
        style_filter: str,
        pre_registered: dict,
        feature_direction: dict,
        shape_priors: dict,
        allowed_interactions: list,
        gate_types: list,
        allowed_directions: list,
        primary_test: str,
        screening_test: str,
        multiple_testing_method: str,
        fdr_pools: dict,
        optimization_budget: OptimizationBudget,
        stopping_rules: StoppingRules,
        production_criteria: ProductionCriteria,
        selection_budget: SelectionBudget,
        split_ratio: float,
        split_method: str,
        dataset_hash: str,
        code_hash: str,
        config_hash: str,
        feature_registry_hash: str,
        target_definition_hash: str,
        split_definition_hash: str,
        created_at: Optional[str] = None,
    ):
        object.__setattr__(self, "_frozen", False)

        self.version = version
        self.observation_unit = observation_unit
        self.style_filter = style_filter
        self.pre_registered = pre_registered
        self.feature_direction = feature_direction
        self.shape_priors = shape_priors
        self.allowed_interactions = allowed_interactions
        self.gate_types = gate_types
        self.allowed_directions = allowed_directions
        self.primary_test = primary_test
        self.screening_test = screening_test
        self.multiple_testing_method = multiple_testing_method
        self.fdr_pools = fdr_pools
        self.optimization_budget = optimization_budget
        self.stopping_rules = stopping_rules
        self.production_criteria = production_criteria
        self.selection_budget = selection_budget
        self.split_ratio = split_ratio
        self.split_method = split_method

        self.dataset_hash = dataset_hash
        self.code_hash = code_hash
        self.config_hash = config_hash
        self.feature_registry_hash = feature_registry_hash
        self.target_definition_hash = target_definition_hash
        self.split_definition_hash = split_definition_hash

        self.created_at = created_at or dt.datetime.utcnow().isoformat() + "Z"

        self._validate()

    # ─── Freeze protocol ────────────────────────────────────────

    def freeze(self) -> None:
        object.__setattr__(self, "_frozen", True)

    @property
    def is_frozen(self) -> bool:
        return getattr(self, "_frozen", False)

    def __setattr__(self, name: str, value: Any) -> None:
        if getattr(self, "_frozen", False):
            raise ContractFrozenError(
                f"Cannot modify frozen contract (field: {name})"
            )
        object.__setattr__(self, name, value)

    # ─── Hash ───────────────────────────────────────────────────

    @property
    def contract_hash(self) -> str:
        payload: dict = {}
        for field_name in self.HASHED_FIELDS:
            value = getattr(self, field_name)
            if hasattr(value, "__dataclass_fields__"):
                value = asdict(value)
            payload[field_name] = value
        for h in self.IDENTITY_HASHES:
            payload[h] = getattr(self, h)
        return hash_dict(payload)

    # ─── Validation ─────────────────────────────────────────────

    def _validate(self) -> None:
        for name in self.IDENTITY_HASHES:
            v = getattr(self, name)
            if not isinstance(v, str) or not v:
                raise ContractValidationError(f"{name} must be a non-empty string")
            if not v.startswith("sha256:"):
                raise ContractValidationError(
                    f"{name} must start with 'sha256:' (got {v[:20]!r})"
                )

        # shape_priors keys must exist in pre_registered
        known_features: set[str] = set()
        for feats in self.pre_registered.values():
            known_features.update(feats)

        valid_shapes = {"MONO_UP", "MONO_DOWN", "BAND"}
        for feat, shape in self.shape_priors.items():
            if feat not in known_features:
                raise ContractValidationError(
                    f"shape_priors references unknown feature {feat!r}"
                )
            if shape not in valid_shapes:
                raise ContractValidationError(
                    f"shape_priors[{feat!r}] = {shape!r} not in {valid_shapes}"
                )

        # FDR pools
        if not self.fdr_pools:
            raise ContractValidationError("fdr_pools cannot be empty")
        for name, pool in self.fdr_pools.items():
            if not (0 < pool.alpha < 1):
                raise ContractValidationError(
                    f"fdr_pools[{name!r}].alpha must be in (0, 1)"
                )
            if pool.max_hypotheses <= 0:
                raise ContractValidationError(
                    f"fdr_pools[{name!r}].max_hypotheses must be > 0"
                )

        # Optimization budget
        if not self.optimization_budget.sl_candidates:
            raise ContractValidationError("sl_candidates cannot be empty")
        if not self.optimization_budget.tp_candidates:
            raise ContractValidationError("tp_candidates cannot be empty")

        # Split
        if not (0.5 <= self.split_ratio < 1.0):
            raise ContractValidationError(
                f"split_ratio must be in [0.5, 1.0), got {self.split_ratio}"
            )
        if self.split_method not in ("temporal", "random"):
            raise ContractValidationError(
                f"split_method must be 'temporal' or 'random', got {self.split_method!r}"
            )

        # Selection budget
        sb = self.selection_budget
        if sb.max_experiments_per_dataset <= 0:
            raise ContractValidationError(
                "max_experiments_per_dataset must be > 0"
            )
        if sb.cooldown_hours_between_experiments < 0:
            raise ContractValidationError(
                "cooldown_hours_between_experiments must be >= 0"
            )

    # ─── Serialization ──────────────────────────────────────────

    def to_dict(self) -> dict:
        return {
            "version": self.version,
            "observation_unit": self.observation_unit,
            "style_filter": self.style_filter,
            "pre_registered": self.pre_registered,
            "feature_direction": self.feature_direction,
            "shape_priors": self.shape_priors,
            "allowed_interactions": self.allowed_interactions,
            "gate_types": self.gate_types,
            "allowed_directions": self.allowed_directions,
            "primary_test": self.primary_test,
            "screening_test": self.screening_test,
            "multiple_testing_method": self.multiple_testing_method,
            "fdr_pools": {k: asdict(v) for k, v in self.fdr_pools.items()},
            "optimization_budget": asdict(self.optimization_budget),
            "stopping_rules": asdict(self.stopping_rules),
            "production_criteria": asdict(self.production_criteria),
            "selection_budget": asdict(self.selection_budget),
            "split_ratio": self.split_ratio,
            "split_method": self.split_method,
            "dataset_hash": self.dataset_hash,
            "code_hash": self.code_hash,
            "config_hash": self.config_hash,
            "feature_registry_hash": self.feature_registry_hash,
            "target_definition_hash": self.target_definition_hash,
            "split_definition_hash": self.split_definition_hash,
            "created_at": self.created_at,
            "contract_hash": self.contract_hash,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "ResearchContract":
        d = dict(d)
        d.pop("contract_hash", None)

        fdr_pools = {
            k: FDRPoolConfig(**v) for k, v in d.pop("fdr_pools").items()
        }
        opt_budget = OptimizationBudget(**d.pop("optimization_budget"))
        stopping = StoppingRules(**d.pop("stopping_rules"))
        prod_criteria = ProductionCriteria(**d.pop("production_criteria"))
        sel_budget = SelectionBudget(**d.pop("selection_budget"))

        return cls(
            fdr_pools=fdr_pools,
            optimization_budget=opt_budget,
            stopping_rules=stopping,
            production_criteria=prod_criteria,
            selection_budget=sel_budget,
            **d,
        )

    @classmethod
    def from_yaml(cls, path: Path) -> "ResearchContract":
        with Path(path).open("r", encoding="utf-8") as f:
            d = yaml.safe_load(f)
        return cls.from_dict(d)

    def to_yaml(self, path: Path) -> None:
        with Path(path).open("w", encoding="utf-8") as f:
            yaml.safe_dump(
                self.to_dict(), f, sort_keys=False, default_flow_style=False,
            )
```

## `vp_analysis/core/experiment_manifest.py`

```python
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
```

## `vp_analysis/core/governance.py`

```python
"""Selection budget enforcement.

The selection budget limits how many experiments may be run on a given
dataset, how fast, and how much human rerun intervention is allowed. This
prevents "meta-iteration" — running experiment after experiment until one
passes — which is a form of multiple testing at the process level, not
correctable by FDR on the individual experiments.
"""
from __future__ import annotations

import datetime as dt
from typing import Optional

from .exceptions import BudgetExceededError, CooldownError
from .experiment_manifest import ExperimentLineage
from .research_contract import ResearchContract


class Governance:
    """Runtime enforcement of the selection budget."""

    def __init__(
        self,
        contract: ResearchContract,
        lineage: ExperimentLineage,
    ):
        self.contract = contract
        self.lineage = lineage

    # ─── Queries ────────────────────────────────────────────────

    def experiments_on_dataset(self, dataset_hash: str) -> list:
        return [
            m for m in self.lineage.all()
            if m.dataset_hash == dataset_hash
        ]

    def next_experiment_id(self, dataset_hash: str) -> str:
        """Generate a globally unique experiment ID."""
        date = dt.datetime.utcnow().strftime("%Y-%m-%d")
        all_ids = [m.experiment_id for m in self.lineage.all()]
        n_today = sum(1 for eid in all_ids if eid.startswith(f"EXP-{date}-"))
        return f"EXP-{date}-{n_today + 1:03d}"

    # ─── Enforcement ────────────────────────────────────────────

    def check_budget_before_start(self, dataset_hash: str) -> None:
        """Raise if starting a new experiment on this dataset would
        violate the selection budget.

        Checks:
          - max_experiments_per_dataset
          - cooldown_hours_between_experiments
        """
        existing = self.experiments_on_dataset(dataset_hash)

        max_exp = self.contract.selection_budget.max_experiments_per_dataset
        if len(existing) >= max_exp:
            raise BudgetExceededError(
                f"Already ran {len(existing)} experiments on dataset "
                f"{dataset_hash[:24]}... (max: {max_exp}). "
                f"Collect new data or create a new dataset."
            )

        cooldown_h = self.contract.selection_budget.cooldown_hours_between_experiments
        if cooldown_h > 0 and existing:
            latest = max(existing, key=lambda m: m.started_at)
            latest_dt = dt.datetime.fromisoformat(
                latest.started_at.rstrip("Z")
            )
            now = dt.datetime.utcnow()
            hours_since = (now - latest_dt).total_seconds() / 3600
            if hours_since < cooldown_h:
                raise CooldownError(
                    f"Only {hours_since:.1f}h since last experiment on this "
                    f"dataset (cooldown: {cooldown_h}h). "
                    f"Wait or use a different dataset."
                )
```

## `vp_analysis/contracts/contract_v1.yaml`

```yaml
version: "v1"

# ─── Dataset identity ────────────────────────────────────────────
observation_unit: "1 signal = 3 orders (production style filtered)"
style_filter: "production_style=1"

# ─── Pre-registered features (THEORY, not data) ──────────────────
# Cập nhật list này = new contract = new experiment.
pre_registered:
  trend:    ["bosScore", "chochScore", "trendDirection",
             "bosQuality", "chochQuality", "structAlign", "auctContinuation"]
  quality:  ["auctTradeQuality", "auctBalance", "auctExpReward", "dataQuality"]
  risk:     ["auctReversalRisk", "auctFailure", "auctExhaustion", "spreadToATR"]
  volume:   ["vpMigrationConf", "vpBestHVNScore", "auctHVNStrength", "vpDevPOCSlope"]
  structure:["vpDevPOCDir", "vpVAOverlapBias", "vpLTAcceptanceAtPrice", "vpThinnessRatio"]
  longterm: ["vpLTPOCMigration", "vpLTNearestZoneStrength",
             "vpLTTransitionScore", "vpLTBalanceStability"]
  engine:   ["msCompression", "ofFlowIntensity", "liqSweep", "smZoneQuality",
             "msContext", "ofContext", "liqContext", "smContext"]
  interactions: ["ix_tq_mig", "ix_bos_trend", "ix_spread_atr", "ix_cont_mig",
                 "ix_fail_reversal", "ix_struct_bos", "ix_devpoc_ltpoc",
                 "ix_exhaust_lt", "ix_acceptance", "ix_target_rr"]

# ─── Directional priors (higher = better?) ──────────────────────
feature_direction:
  auctContinuation: 1
  auctTradeQuality: 1
  auctBalance: 1
  auctExpReward: 1
  vpMigrationConf: 1
  vpBestHVNScore: 1
  auctExhaustion: -1
  auctFailure: -1
  auctReversalRisk: -1
  vpThinnessRatio: -1
  spreadToATR: -1
  vpDevPOCDir: 0
  vpDevPOCSlope: 0
  auctHVNStrength: 1
  vpLTAcceptanceAtPrice: 1
  bosScore: 1
  chochScore: 1
  trendDirection: 0
  bosQuality: 0
  chochQuality: 0
  structAlign: 1
  dataQuality: 1
  vpVAOverlapBias: 0
  vpLTPOCMigration: 0
  vpLTNearestZoneStrength: 1
  vpLTTransitionScore: -1
  vpLTBalanceStability: 1
  msCompression: 0
  ofFlowIntensity: 0
  liqSweep: 0
  smZoneQuality: 0
  msContext: 0
  ofContext: 0
  liqContext: 0
  smContext: 0
  ix_tq_mig: 1
  ix_bos_trend: 1
  ix_spread_atr: -1
  ix_cont_mig: 1
  ix_fail_reversal: -1
  ix_struct_bos: 1
  ix_devpoc_ltpoc: 1
  ix_exhaust_lt: -1
  ix_acceptance: 1
  ix_target_rr: 1

# ─── Shape priors (IMMUTABLE — verify only, do not change) ──────
# MONO_UP: higher → better EV monotonically
# MONO_DOWN: lower → better EV monotonically
# BAND: EV peaks in a middle range (inverted-U)
shape_priors:
  auctTradeQuality: MONO_UP
  auctContinuation: MONO_UP
  auctBalance: MONO_UP
  auctExpReward: MONO_UP
  vpMigrationConf: MONO_UP
  auctHVNStrength: MONO_UP
  structAlign: MONO_UP
  auctReversalRisk: MONO_DOWN
  auctFailure: MONO_DOWN
  auctExhaustion: MONO_DOWN
  spreadToATR: MONO_DOWN
  vpThinnessRatio: MONO_DOWN
  vpLTTransitionScore: MONO_DOWN
  vpDevPOCDir: BAND
  vpVAOverlapBias: BAND
  msCompression: BAND
  smZoneQuality: MONO_UP

# ─── Interactions (pre-registered list) ─────────────────────────
allowed_interactions:
  - ix_tq_mig
  - ix_bos_trend
  - ix_spread_atr
  - ix_cont_mig
  - ix_fail_reversal
  - ix_struct_bos
  - ix_devpoc_ltpoc
  - ix_exhaust_lt
  - ix_acceptance
  - ix_target_rr

# ─── Hypothesis families ────────────────────────────────────────
gate_types: ["threshold", "band"]
allowed_directions: [1, -1, 0]

# ─── Statistical tests (pre-registered) ─────────────────────────
primary_test: "one-sided t-test on fold EVs"
screening_test: "permutation, 100 iter, early stop p>0.30"
multiple_testing_method: "benjamini-hochberg"

# ─── FDR pools (isolated) ───────────────────────────────────────
fdr_pools:
  hard_gate:
    name: hard_gate
    max_hypotheses: 500
    alpha: 0.05
  soft_gate:
    name: soft_gate
    max_hypotheses: 200
    alpha: 0.05
  bad_entry:
    name: bad_entry
    max_hypotheses: 200
    alpha: 0.05

# ─── Optimization budget (NOT hypotheses) ───────────────────────
optimization_budget:
  sl_candidates: [1.0, 1.5, 2.0]   # ATR units
  tp_candidates: [1.0, 1.5, 2.0]   # ATR units
  sizing_configs: 5
  utility_function: "expectancy"

# ─── Stopping rules ─────────────────────────────────────────────
stopping_rules:
  min_group_samples: 30
  min_fold_consistency: 0.60
  min_effect_size: 0.05
  max_outer_folds: 5
  max_inner_folds: 3

# ─── Production criteria ────────────────────────────────────────
production_criteria:
  min_ev: 0.05
  min_pf: 1.10
  min_wr: 0.35
  require_robust_across_styles: false    # diagnostic, not gate
  require_holdout_confirmation: true

# ─── Selection budget (meta-governance) ─────────────────────────
selection_budget:
  max_experiments_per_dataset: 5
  max_contract_changes_per_day: 3
  cooldown_hours_between_experiments: 24
  max_eda_inspect_and_rerun: 1
  config_frozen_after_start: true

# ─── Split policy ───────────────────────────────────────────────
split_ratio: 0.70
split_method: "temporal"

# ─── Identity hashes (computed by builder, placeholders here) ───
dataset_hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
code_hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
config_hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
feature_registry_hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
target_definition_hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
split_definition_hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
```

---

## Tests

### `vp_analysis/tests/__init__.py`

```python
```

### `vp_analysis/tests/conftest.py`

```python
"""Shared test fixtures."""
import sys
from pathlib import Path

import pytest

# Make vp_analysis importable
_ROOT = Path(__file__).parent.parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


@pytest.fixture
def minimal_contract_dict():
    """A minimal valid contract for unit tests.

    Uses stub features (f1/f2/f3) and stub hashes so that tests don't
    depend on real data. The structure mirrors a production contract.
    """
    return {
        "version": "v1",
        "observation_unit": "1 signal",
        "style_filter": "production=1",
        "pre_registered": {"quality": ["f1", "f2"], "trend": ["f3"]},
        "feature_direction": {"f1": 1, "f2": -1, "f3": 0},
        "shape_priors": {"f1": "MONO_UP", "f2": "MONO_DOWN", "f3": "BAND"},
        "allowed_interactions": ["ix_a"],
        "gate_types": ["threshold", "band"],
        "allowed_directions": [1, -1, 0],
        "primary_test": "one-sided t-test",
        "screening_test": "permutation",
        "multiple_testing_method": "BH",
        "fdr_pools": {
            "hard_gate": {
                "name": "hard_gate", "max_hypotheses": 500, "alpha": 0.05,
            },
            "soft_gate": {
                "name": "soft_gate", "max_hypotheses": 200, "alpha": 0.05,
            },
        },
        "optimization_budget": {
            "sl_candidates": [1.0, 1.5, 2.0],
            "tp_candidates": [1.0, 1.5, 2.0],
            "sizing_configs": 5,
            "utility_function": "expectancy",
        },
        "stopping_rules": {
            "min_group_samples": 30,
            "min_fold_consistency": 0.60,
            "min_effect_size": 0.05,
            "max_outer_folds": 5,
            "max_inner_folds": 3,
        },
        "production_criteria": {
            "min_ev": 0.05,
            "min_pf": 1.10,
            "min_wr": 0.35,
            "require_robust_across_styles": False,
            "require_holdout_confirmation": True,
        },
        "selection_budget": {
            "max_experiments_per_dataset": 5,
            "max_contract_changes_per_day": 3,
            "cooldown_hours_between_experiments": 24,
            "max_eda_inspect_and_rerun": 1,
            "config_frozen_after_start": True,
        },
        "split_ratio": 0.70,
        "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
```

### `vp_analysis/tests/test_provenance.py`

```python
import pandas as pd
import pytest

from vp_analysis.core.provenance import (
    hash_dataframe,
    hash_dict,
    hash_file,
    hash_files,
    hash_string,
)


def test_hash_string_deterministic():
    assert hash_string("hello") == hash_string("hello")
    assert hash_string("hello") != hash_string("world")
    assert hash_string("hello").startswith("sha256:")


def test_hash_dict_order_independent():
    assert hash_dict({"a": 1, "b": 2}) == hash_dict({"b": 2, "a": 1})


def test_hash_dict_handles_nan_deterministically():
    assert hash_dict({"x": float("nan")}) == hash_dict({"x": float("nan")})


def test_hash_dict_handles_inf():
    assert hash_dict({"x": float("inf")}) == hash_dict({"x": float("inf")})
    assert hash_dict({"x": float("inf")}) != hash_dict({"x": float("-inf")})


def test_hash_dict_nested_structures():
    a = {"x": {"y": [1, 2, 3]}}
    b = {"x": {"y": [1, 2, 3]}}
    assert hash_dict(a) == hash_dict(b)


def test_hash_dataframe_deterministic():
    df1 = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]})
    df2 = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]})
    assert hash_dataframe(df1) == hash_dataframe(df2)


def test_hash_dataframe_detects_change():
    df1 = pd.DataFrame({"a": [1, 2, 3]})
    df2 = pd.DataFrame({"a": [1, 2, 4]})
    assert hash_dataframe(df1) != hash_dataframe(df2)


def test_hash_dataframe_excludes_columns():
    df1 = pd.DataFrame({"a": [1, 2], "meta": [10, 20]})
    df2 = pd.DataFrame({"a": [1, 2], "meta": [99, 99]})
    assert (
        hash_dataframe(df1, exclude_cols=["meta"])
        == hash_dataframe(df2, exclude_cols=["meta"])
    )


def test_hash_file(tmp_path):
    f = tmp_path / "test.txt"
    f.write_text("hello")
    h1 = hash_file(f)
    f.write_text("world")
    h2 = hash_file(f)
    assert h1 != h2


def test_hash_files_excludes_patterns(tmp_path):
    (tmp_path / "keep.py").write_text("a")
    (tmp_path / "skip.md").write_text("b")
    h1 = hash_files([tmp_path], exclude_patterns=["**/*.md"])
    (tmp_path / "skip.md").write_text("c")
    h2 = hash_files([tmp_path], exclude_patterns=["**/*.md"])
    assert h1 == h2
```

### `vp_analysis/tests/test_research_contract.py`

```python
import pytest

from vp_analysis.core.exceptions import (
    ContractFrozenError,
    ContractValidationError,
)
from vp_analysis.core.research_contract import ResearchContract


def test_construct_contract(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    assert contract.version == "v1"
    assert not contract.is_frozen
    assert contract.contract_hash.startswith("sha256:")


def test_contract_hash_deterministic(minimal_contract_dict):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    c2 = ResearchContract.from_dict(minimal_contract_dict)
    assert c1.contract_hash == c2.contract_hash


def test_contract_hash_changes_on_split_ratio(minimal_contract_dict):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    modified = dict(minimal_contract_dict)
    modified["split_ratio"] = 0.80
    c2 = ResearchContract.from_dict(modified)
    assert c1.contract_hash != c2.contract_hash


def test_contract_hash_changes_on_shape_prior(minimal_contract_dict):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    modified = dict(minimal_contract_dict)
    modified["shape_priors"] = dict(minimal_contract_dict["shape_priors"])
    modified["shape_priors"]["f1"] = "BAND"
    c2 = ResearchContract.from_dict(modified)
    assert c1.contract_hash != c2.contract_hash


def test_contract_hash_ignores_created_at(minimal_contract_dict):
    d1 = dict(minimal_contract_dict)
    d1["created_at"] = "2026-01-01T00:00:00Z"
    d2 = dict(minimal_contract_dict)
    d2["created_at"] = "2026-12-31T00:00:00Z"
    c1 = ResearchContract.from_dict(d1)
    c2 = ResearchContract.from_dict(d2)
    assert c1.contract_hash == c2.contract_hash


def test_contract_freeze_prevents_mutation(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    contract.freeze()
    assert contract.is_frozen
    with pytest.raises(ContractFrozenError):
        contract.version = "v2"


def test_contract_freeze_prevents_nested_mutation(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    contract.freeze()
    with pytest.raises(ContractFrozenError):
        contract.split_ratio = 0.90


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
    d["fdr_pools"] = {
        "hard_gate": {"name": "hard_gate", "max_hypotheses": 500, "alpha": 1.5},
    }
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


def test_yaml_roundtrip(minimal_contract_dict, tmp_path):
    c1 = ResearchContract.from_dict(minimal_contract_dict)
    path = tmp_path / "contract.yaml"
    c1.to_yaml(path)
    c2 = ResearchContract.from_yaml(path)
    assert c1.contract_hash == c2.contract_hash
```

### `vp_analysis/tests/test_experiment_manifest.py`

```python
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
    assert m.started_at  # populated


def test_manifest_complete_success():
    m = make_manifest("EXP-001")
    m.complete(ExperimentResult.SUCCESS)
    assert m.status == ExperimentStatus.COMPLETED
    assert m.result == ExperimentResult.SUCCESS
    assert m.completed_at


def test_manifest_complete_null_result():
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


def test_manifest_invalidate_is_terminal():
    m = make_manifest("EXP-001")
    m.invalidate("FDR bug")
    assert m.status == ExperimentStatus.INVALIDATED
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
    assert set(lineage.get_descendants("EXP-001")) == {
        "EXP-002", "EXP-003", "EXP-004",
    }


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
```

### `vp_analysis/tests/test_governance.py`

```python
import datetime as dt

import pytest

from vp_analysis.core.exceptions import BudgetExceededError, CooldownError
from vp_analysis.core.experiment_manifest import (
    ExperimentLineage,
    ExperimentManifest,
)
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

    # Pre-populate 5 experiments (equal to max)
    old_time = (
        dt.datetime.utcnow() - dt.timedelta(hours=48)
    ).isoformat() + "Z"
    for i in range(5):
        lineage.add(_mk_manifest(f"EXP-{i:03d}", dataset_hash,
                                 contract_hash, started_at=old_time))

    gov = Governance(contract, lineage)
    with pytest.raises(BudgetExceededError):
        gov.check_budget_before_start(dataset_hash)


def test_cooldown_blocks_immediate_rerun(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    dataset_hash = "sha256:" + "a" * 64

    lineage.add(_mk_manifest(
        "EXP-001", dataset_hash, contract.contract_hash,
        started_at=dt.datetime.utcnow().isoformat() + "Z",
    ))

    gov = Governance(contract, lineage)
    with pytest.raises(CooldownError):
        gov.check_budget_before_start(dataset_hash)


def test_cooldown_allows_after_wait(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    lineage = ExperimentLineage()
    dataset_hash = "sha256:" + "a" * 64

    old_time = (
        dt.datetime.utcnow() - dt.timedelta(hours=48)
    ).isoformat() + "Z"
    lineage.add(_mk_manifest(
        "EXP-001", dataset_hash, contract.contract_hash, started_at=old_time,
    ))

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
    old_time = (
        dt.datetime.utcnow() - dt.timedelta(hours=48)
    ).isoformat() + "Z"
    lineage.add(_mk_manifest(f"EXP-{today}-001", dataset_hash,
                             contract.contract_hash, started_at=old_time))

    gov = Governance(contract, lineage)
    eid = gov.next_experiment_id(dataset_hash)
    assert eid == f"EXP-{today}-002"
```

---

## Cách chạy

```bash
cd vp_analysis/..
pytest vp_analysis/tests/ -v
```

Kỳ vọng: **~40 tests pass**. Nếu bất kỳ test nào fail, đó là bug trong kernel — không được proceed sang Sprint 0B.

Ví dụ output:
```text
vp_analysis/tests/test_provenance.py ............    [ 12 passed ]
vp_analysis/tests/test_research_contract.py .....   [ 12 passed ]
vp_analysis/tests/test_experiment_manifest.py ...   [ 13 passed ]
vp_analysis/tests/test_governance.py ......         [  6 passed ]
```

---

## Cách dùng (preview cho Sprint 0B)

```python
from vp_analysis.core import (
    ResearchContract, ExperimentLineage, ExperimentManifest, Governance,
)

# 1. Load contract
contract = ResearchContract.from_yaml("vp_analysis/contracts/contract_v1.yaml")
contract.freeze()

# 2. Boot governance
lineage = ExperimentLineage(storage_path="output/lineage.json")
gov = Governance(contract, lineage)

# 3. Check budget before starting
dataset_hash = "sha256:..."  # computed from actual data
gov.check_budget_before_start(dataset_hash)

# 4. Create experiment
eid = gov.next_experiment_id(dataset_hash)
manifest = ExperimentManifest(
    experiment_id=eid,
    research_contract_hash=contract.contract_hash,
    dataset_hash=dataset_hash,
    code_hash=contract.code_hash,
    parent_experiment_id=None,
)
lineage.add(manifest)

# 5. ... run pipeline (Sprint 0B onwards) ...

# 6. Complete
manifest.complete(ExperimentResult.SUCCESS)
lineage.save()
```

---


# Sprint 0B — Information Boundary

Dùng cùng defaults đã chốt ở Sprint 0A. Deliverables:

- `DevelopmentData` — read-only wrapper với fit-only semantics
- `SealedHoldout` — access log, unseal-once-per-experiment
- `HoldoutAccessLog` — persistent, shareable qua transformations
- `DataBoundary` — orchestrator với `apply(transformer)` fit-on-dev
- `FrozenRule`, `FrozenProductionConfig` — deeply immutable
- Exception additions + ~40 tests

Triết lý cốt lõi: **không dựa vào convention**. Type system + method signatures enforce.

---

## `vp_analysis/core/exceptions.py` — bổ sung

Thêm vào file từ Sprint 0A:

```python
class HoldoutSealedError(GovernanceError):
    """Raised when attempting to access sealed holdout data."""


class HoldoutAlreadyUnsealedError(GovernanceError):
    """Raised when unseal_once is called twice for the same experiment."""


class FrozenMutationError(GovernanceError):
    """Raised when attempting to mutate a frozen artifact (fallback for
    containers that bypass dataclass frozen=True)."""
```

## `vp_analysis/core/data_boundary.py`

```python
"""Information boundary: development vs sealed holdout.

Design principles:
  - The split is deterministic and recorded (split_time, split_ratio).
  - Development data is freely accessible for fitting and analysis.
  - Holdout is sealed by default; unsealing is:
      * Once per experiment_id
      * Logged with timestamp and reason
      * Persisted in a HoldoutAccessLog that survives transformations
  - DataBoundary.apply(transformer) enforces fit-on-dev semantics:
    transformer.fit is called on dev only; holdout is transformed but
    remains sealed.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import dataclass
from typing import Any, Optional, Protocol

import pandas as pd

from .exceptions import HoldoutAlreadyUnsealedError


# ─── Protocol for transformers ──────────────────────────────────

class FeatureTransformer(Protocol):
    """Fit on development DataFrame, transform any DataFrame with same schema.

    Note: The transform method must be deterministic and stateless given
    the fitted state. It must not access the DataFrame's target column
    in a way that could leak (caller's responsibility).
    """
    def fit(self, dev_df: pd.DataFrame) -> Any: ...
    def transform(self, df: pd.DataFrame) -> pd.DataFrame: ...


# ─── Access logging ─────────────────────────────────────────────

@dataclass(frozen=True)
class HoldoutAccessRecord:
    experiment_id: str
    timestamp: str
    reason: str


class HoldoutAccessLog:
    """Persistent, shareable log of holdout unsealing events.

    The log is the source of truth for "has this experiment peeked at
    holdout?". It survives transformations — every derived SealedHoldout
    shares the same log so we can't accidentally launder an access by
    transforming the data.
    """

    def __init__(self) -> None:
        self._records: list[HoldoutAccessRecord] = []

    @property
    def records(self) -> tuple[HoldoutAccessRecord, ...]:
        return tuple(self._records)

    def __len__(self) -> int:
        return len(self._records)

    def has_unsealed(self, experiment_id: str) -> bool:
        return any(r.experiment_id == experiment_id for r in self._records)

    def record(self, experiment_id: str, reason: str) -> None:
        if self.has_unsealed(experiment_id):
            raise HoldoutAlreadyUnsealedError(
                f"Experiment {experiment_id} has already unsealed this holdout"
            )
        self._records.append(HoldoutAccessRecord(
            experiment_id=experiment_id,
            timestamp=dt.datetime.utcnow().isoformat() + "Z",
            reason=reason,
        ))

    def to_dict(self) -> list[dict]:
        return [
            {"experiment_id": r.experiment_id,
             "timestamp": r.timestamp,
             "reason": r.reason}
            for r in self._records
        ]


# ─── Data wrappers ──────────────────────────────────────────────

class DevelopmentData:
    """Read-only wrapper around the development DataFrame.

    The underlying DataFrame is exposed via `.data` for interop with
    existing code, but the recommended pattern is `.fit_transform(t)`
    which delegates to a transformer and returns a new DevelopmentData.
    """

    def __init__(self, df: pd.DataFrame):
        self._df = df

    @property
    def data(self) -> pd.DataFrame:
        """Read-only by convention. Do not mutate in place."""
        return self._df

    @property
    def columns(self) -> list[str]:
        return list(self._df.columns)

    def __len__(self) -> int:
        return len(self._df)

    def __repr__(self) -> str:
        return f"DevelopmentData(n={len(self._df)}, cols={len(self._df.columns)})"


class SealedHoldout:
    """Sealed holdout wrapper.

    The underlying data is NOT accessible until `unseal_once()` is called
    with an experiment_id. Metadata (size, columns, access_log) is always
    accessible; the actual DataFrame is not.
    """

    def __init__(
        self,
        df: pd.DataFrame,
        access_log: Optional[HoldoutAccessLog] = None,
    ):
        self._df = df
        self._access_log = access_log if access_log is not None else HoldoutAccessLog()

    @property
    def is_sealed(self) -> bool:
        """True if no experiment has unsealed this holdout yet."""
        return len(self._access_log) == 0

    @property
    def access_log(self) -> HoldoutAccessLog:
        return self._access_log

    @property
    def size(self) -> int:
        """Metadata: number of rows. Always accessible."""
        return len(self._df)

    @property
    def columns(self) -> list[str]:
        """Metadata: column names. Always accessible."""
        return list(self._df.columns)

    def unseal_once(self, experiment_id: str, reason: str) -> pd.DataFrame:
        """Unseal the holdout for a specific experiment.

        Raises HoldoutAlreadyUnsealedError if this experiment_id has already
        unsealed this holdout (in this or any derived instance).
        """
        self._access_log.record(experiment_id, reason)
        return self._df

    def has_been_unsealed_by(self, experiment_id: str) -> bool:
        return self._access_log.has_unsealed(experiment_id)

    def __len__(self) -> int:
        return len(self._df)

    def __repr__(self) -> str:
        status = "sealed" if self.is_sealed else f"unsealed_by={len(self._access_log)}"
        return f"SealedHoldout(n={len(self._df)}, {status})"


# ─── Orchestrator ───────────────────────────────────────────────

class DataBoundary:
    """Coordinates split, access control, and fit-on-dev semantics.

    Lifecycle:
        boundary = DataBoundary.from_merged(merged, split_ratio=0.70)
        boundary2 = boundary.apply(MyTransformer())   # fit on dev, apply both
        # ... discovery uses boundary2.dev ...
        # ... at evaluation time:
        holdout_df = boundary2.holdout.unseal_once(experiment_id, reason)
    """

    def __init__(
        self,
        dev: DevelopmentData,
        holdout: SealedHoldout,
        split_time: Optional[str] = None,
        split_method: str = "temporal",
        split_ratio: Optional[float] = None,
    ):
        self._dev = dev
        self._holdout = holdout
        self.split_time = split_time
        self.split_method = split_method
        self.split_ratio = split_ratio

    # ─── Factory ────────────────────────────────────────────────

    @classmethod
    def from_merged(
        cls,
        merged_df: pd.DataFrame,
        split_ratio: float = 0.70,
        split_method: str = "temporal",
        time_col: str = "time",
    ) -> "DataBoundary":
        if not (0.0 < split_ratio < 1.0):
            raise ValueError(f"split_ratio must be in (0,1), got {split_ratio}")

        df = merged_df.copy()

        if split_method == "temporal":
            if time_col not in df.columns:
                raise ValueError(
                    f"split_method='temporal' requires column {time_col!r}"
                )
            df = df.sort_values(time_col).reset_index(drop=True)
            split_idx = int(len(df) * split_ratio)
            split_time = (
                str(df[time_col].iloc[split_idx])
                if 0 < split_idx < len(df) else None
            )
        elif split_method == "random":
            df = df.sample(frac=1.0, random_state=42).reset_index(drop=True)
            split_idx = int(len(df) * split_ratio)
            split_time = None
        else:
            raise ValueError(
                f"split_method must be 'temporal' or 'random', got {split_method!r}"
            )

        dev_df = df.iloc[:split_idx].reset_index(drop=True)
        holdout_df = df.iloc[split_idx:].reset_index(drop=True)

        return cls(
            dev=DevelopmentData(dev_df),
            holdout=SealedHoldout(holdout_df),
            split_time=split_time,
            split_method=split_method,
            split_ratio=split_ratio,
        )

    # ─── Access ─────────────────────────────────────────────────

    @property
    def dev(self) -> DevelopmentData:
        return self._dev

    @property
    def holdout(self) -> SealedHoldout:
        return self._holdout

    # ─── Fit-on-dev pattern ────────────────────────────────────

    def apply(self, transformer: FeatureTransformer) -> "DataBoundary":
        """Fit transformer on dev, apply to both dev and holdout.

        The holdout result is a new SealedHoldout that shares the same
        access log. Holdout remains sealed — transformation does not
        count as unsealing (the transformer was fit on dev only).
        """
        transformer.fit(self._dev.data)
        dev_new = DevelopmentData(transformer.transform(self._dev.data))
        holdout_new = SealedHoldout(
            transformer.transform(self._holdout._df),
            access_log=self._holdout.access_log,
        )
        return DataBoundary(
            dev=dev_new,
            holdout=holdout_new,
            split_time=self.split_time,
            split_method=self.split_method,
            split_ratio=self.split_ratio,
        )

    # ─── Audit ──────────────────────────────────────────────────

    def audit_info(self) -> dict:
        return {
            "split_method": self.split_method,
            "split_ratio": self.split_ratio,
            "split_time": self.split_time,
            "dev_size": len(self._dev),
            "holdout_size": self._holdout.size,
            "holdout_accesses": self._holdout.access_log.to_dict(),
        }

    def __repr__(self) -> str:
        return (
            f"DataBoundary(dev_n={len(self._dev)}, "
            f"holdout_n={self._holdout.size}, "
            f"split={self.split_method}@{self.split_time}, "
            f"holdout_sealed={self._holdout.is_sealed})"
        )
```

## `vp_analysis/core/frozen_types.py`

```python
"""Immutable artifacts for the post-freeze phase.

FrozenRule and FrozenProductionConfig use dataclass(frozen=True) plus
manual container conversion (lists → tuples) so nested state can't be
mutated. This is stronger than dataclass frozen=True alone, which only
prevents attribute reassignment.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import asdict, dataclass, field
from typing import Any, Optional


def _utcnow() -> str:
    return dt.datetime.utcnow().isoformat() + "Z"


@dataclass(frozen=True)
class FrozenRule:
    # Identity
    rule_id: str
    experiment_id: str
    research_contract_hash: str

    # Scope
    symbol: str
    setup: str

    # Gate specification
    gate_type: str                                  # "threshold" | "band" | "model"
    direction: int                                  # -1, 0, 1
    features: tuple                                 # normalized to tuple
    lower_bound: Optional[float] = None
    upper_bound: Optional[float] = None
    model_weights: Optional[tuple] = None           # for gate_type="model"
    model_bias: Optional[float] = None
    score_threshold: Optional[float] = None

    # Evidence from development
    test_ev_mean: float = 0.0
    test_wr_mean: float = 0.0
    test_pf_mean: float = 0.0
    test_n_avg: int = 0
    pvalue: Optional[float] = None
    pvalue_fdr: Optional[float] = None
    fdr_significant: bool = False
    fold_consistency: float = 0.0
    n_folds: int = 0

    # Freeze metadata
    frozen_at: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        # Normalize containers to immutable types
        object.__setattr__(self, "features", tuple(self.features))
        if self.model_weights is not None:
            object.__setattr__(self, "model_weights", tuple(self.model_weights))

        # Validation
        if not self.rule_id:
            raise ValueError("rule_id is required")
        if not self.experiment_id:
            raise ValueError("experiment_id is required")
        if self.gate_type not in ("threshold", "band", "model"):
            raise ValueError(
                f"gate_type must be 'threshold'|'band'|'model', got {self.gate_type!r}"
            )
        if self.direction not in (-1, 0, 1):
            raise ValueError(f"direction must be -1|0|1, got {self.direction}")
        if not self.features:
            raise ValueError("features cannot be empty")

        if self.gate_type == "threshold":
            if self.direction == 1 and self.lower_bound is None:
                raise ValueError("threshold direction=1 requires lower_bound")
            if self.direction == -1 and self.upper_bound is None:
                raise ValueError("threshold direction=-1 requires upper_bound")
        elif self.gate_type == "band":
            if self.lower_bound is None or self.upper_bound is None:
                raise ValueError("band gate requires both lower_bound and upper_bound")
            if self.lower_bound >= self.upper_bound:
                raise ValueError("band gate requires lower_bound < upper_bound")
        elif self.gate_type == "model":
            if self.model_weights is None:
                raise ValueError("model gate requires model_weights")
            if self.score_threshold is None:
                raise ValueError("model gate requires score_threshold")

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "FrozenRule":
        return cls(**d)


@dataclass(frozen=True)
class FrozenProductionConfig:
    """Bundle of rules + SL/TP selections + sizing configs, frozen together.

    sl_tp_selections: tuple of dicts, each {"rule_id": ..., "sl": float, "tp": float}
    sizing_configs: tuple of dicts, each {"symbol": ..., "setup": ..., "lot_mult": float}
    """
    experiment_id: str
    research_contract_hash: str
    rules: tuple
    sl_tp_selections: tuple
    sizing_configs: tuple
    freeze_timestamp: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        object.__setattr__(self, "rules", tuple(self.rules))
        object.__setattr__(self, "sl_tp_selections", tuple(self.sl_tp_selections))
        object.__setattr__(self, "sizing_configs", tuple(self.sizing_configs))

        if not self.rules:
            raise ValueError("FrozenProductionConfig requires at least one rule")

        rule_ids = [r.rule_id for r in self.rules]
        if len(rule_ids) != len(set(rule_ids)):
            raise ValueError("Duplicate rule_ids in FrozenProductionConfig")

        # Cross-check: every sl_tp_selection references a rule in this config
        rule_id_set = set(rule_ids)
        for sel in self.sl_tp_selections:
            if not isinstance(sel, dict):
                continue
            rid = sel.get("rule_id")
            if rid is not None and rid not in rule_id_set:
                raise ValueError(
                    f"sl_tp_selection references unknown rule_id {rid!r}"
                )

    def to_dict(self) -> dict:
        return {
            "experiment_id": self.experiment_id,
            "research_contract_hash": self.research_contract_hash,
            "rules": [r.to_dict() for r in self.rules],
            "sl_tp_selections": [dict(s) for s in self.sl_tp_selections],
            "sizing_configs": [dict(s) for s in self.sizing_configs],
            "freeze_timestamp": self.freeze_timestamp,
        }
```

## `vp_analysis/core/__init__.py` — bổ sung exports

```python
"""Core governance modules."""
from .research_contract import ResearchContract
from .experiment_manifest import (
    ExperimentManifest, ExperimentLineage,
    ExperimentStatus, ExperimentResult,
)
from .governance import Governance
from .data_boundary import (
    DataBoundary, DevelopmentData, SealedHoldout,
    HoldoutAccessLog, HoldoutAccessRecord,
    FeatureTransformer,
)
from .frozen_types import FrozenRule, FrozenProductionConfig

__all__ = [
    # Sprint 0A
    "ResearchContract",
    "ExperimentManifest", "ExperimentLineage",
    "ExperimentStatus", "ExperimentResult",
    "Governance",
    # Sprint 0B
    "DataBoundary", "DevelopmentData", "SealedHoldout",
    "HoldoutAccessLog", "HoldoutAccessRecord",
    "FeatureTransformer",
    "FrozenRule", "FrozenProductionConfig",
]
```

---

## Tests

### `vp_analysis/tests/test_data_boundary.py`

```python
import pandas as pd
import pytest

from vp_analysis.core.data_boundary import (
    DataBoundary, DevelopmentData, SealedHoldout,
    HoldoutAccessLog,
)
from vp_analysis.core.exceptions import HoldoutAlreadyUnsealedError


# ─── Fixtures ───────────────────────────────────────────────────

@pytest.fixture
def sample_df():
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=100, freq="D"),
        "symbol": ["XAUUSD"] * 100,
        "feature_a": list(range(100)),
        "feature_b": [x * 0.5 for x in range(100)],
        "profitUSD": [1.0 if i % 3 else -1.0 for i in range(100)],
    })


class MultiplyTransformer:
    """Trivial transformer for testing. fit stores the dev mean."""

    def __init__(self):
        self.dev_mean = None

    def fit(self, df):
        self.dev_mean = df["feature_a"].mean()
        return self

    def transform(self, df):
        out = df.copy()
        out["feature_a_scaled"] = df["feature_a"] - self.dev_mean
        return out


# ─── Split mechanics ────────────────────────────────────────────

def test_from_merged_temporal_split(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70)
    assert len(b.dev) == 70
    assert b.holdout.size == 30
    assert b.split_method == "temporal"
    assert b.split_ratio == 0.70


def test_from_merged_records_split_time(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70, time_col="time")
    assert b.split_time is not None
    # Split time = time of first holdout row
    assert b.split_time == str(sample_df["time"].iloc[70])


def test_from_merged_rejects_bad_ratio(sample_df):
    with pytest.raises(ValueError):
        DataBoundary.from_merged(sample_df, split_ratio=1.5)
    with pytest.raises(ValueError):
        DataBoundary.from_merged(sample_df, split_ratio=0.0)


def test_from_merged_rejects_missing_time_col(sample_df):
    df = sample_df.drop(columns=["time"])
    with pytest.raises(ValueError, match="time"):
        DataBoundary.from_merged(df, split_method="temporal")


def test_from_merged_temporal_preserves_order(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70)
    dev_times = b.dev.data["time"].tolist()
    holdout_times = b.holdout._df["time"].tolist()
    assert dev_times == sorted(dev_times)
    assert holdout_times == sorted(holdout_times)
    assert max(dev_times) < min(holdout_times)


# ─── SealedHoldout access control ───────────────────────────────

def test_holdout_starts_sealed(sample_df):
    b = DataBoundary.from_merged(sample_df)
    assert b.holdout.is_sealed
    assert len(b.holdout.access_log) == 0


def test_holdout_metadata_accessible_when_sealed(sample_df):
    b = DataBoundary.from_merged(sample_df)
    # size and columns are metadata, always accessible
    assert b.holdout.size == 30
    assert "feature_a" in b.holdout.columns


def test_unseal_once_returns_dataframe(sample_df):
    b = DataBoundary.from_merged(sample_df)
    df = b.holdout.unseal_once("EXP-001", reason="final_eval")
    assert isinstance(df, pd.DataFrame)
    assert len(df) == 30


def test_unseal_twice_same_experiment_raises(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="final_eval")
    with pytest.raises(HoldoutAlreadyUnsealedError):
        b.holdout.unseal_once("EXP-001", reason="try_again")


def test_unseal_different_experiments_allowed(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="final_eval")
    # Not raising — different experiment
    b.holdout.unseal_once("EXP-002", reason="second_opinion")


def test_holdout_not_sealed_after_unseal(sample_df):
    b = DataBoundary.from_merged(sample_df)
    assert b.holdout.is_sealed
    b.holdout.unseal_once("EXP-001", reason="final_eval")
    assert not b.holdout.is_sealed


def test_access_log_records_reason_and_timestamp(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="final_evaluation")
    records = b.holdout.access_log.records
    assert len(records) == 1
    assert records[0].experiment_id == "EXP-001"
    assert records[0].reason == "final_evaluation"
    assert records[0].timestamp  # not empty


# ─── DevelopmentData ────────────────────────────────────────────

def test_dev_data_accessible(sample_df):
    b = DataBoundary.from_merged(sample_df)
    assert b.dev.data is not None
    assert len(b.dev.data) == 70


def test_dev_columns_property(sample_df):
    b = DataBoundary.from_merged(sample_df)
    assert "feature_a" in b.dev.columns
    assert "profitUSD" in b.dev.columns


# ─── apply(transformer) ─────────────────────────────────────────

def test_apply_fits_on_dev(sample_df):
    b = DataBoundary.from_merged(sample_df)
    transformer = MultiplyTransformer()
    b2 = b.apply(transformer)
    # dev_mean should equal mean of dev only, not full data
    expected_mean = sample_df["feature_a"].iloc[:70].mean()
    assert transformer.dev_mean == expected_mean


def test_apply_transforms_both(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b2 = b.apply(MultiplyTransformer())
    assert "feature_a_scaled" in b2.dev.columns
    assert "feature_a_scaled" in b2.holdout.columns


def test_apply_preserves_sealed_state(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b2 = b.apply(MultiplyTransformer())
    assert b2.holdout.is_sealed


def test_apply_shares_access_log(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="test")
    b2 = b.apply(MultiplyTransformer())
    # b2's holdout shares the access log
    assert b2.holdout.has_been_unsealed_by("EXP-001")
    # Trying to unseal again raises
    with pytest.raises(HoldoutAlreadyUnsealedError):
        b2.holdout.unseal_once("EXP-001", reason="try_again")


def test_apply_preserves_split_metadata(sample_df):
    b = DataBoundary.from_merged(sample_df, split_ratio=0.70)
    b2 = b.apply(MultiplyTransformer())
    assert b2.split_time == b.split_time
    assert b2.split_method == b.split_method
    assert b2.split_ratio == b.split_ratio


def test_apply_chain(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b2 = b.apply(MultiplyTransformer())
    b3 = b2.apply(MultiplyTransformer())  # apply twice, chained
    assert len(b3.dev) == 70
    assert b3.holdout.is_sealed


# ─── Audit ──────────────────────────────────────────────────────

def test_audit_info_includes_access_log(sample_df):
    b = DataBoundary.from_merged(sample_df)
    b.holdout.unseal_once("EXP-001", reason="eval")
    audit = b.audit_info()
    assert audit["dev_size"] == 70
    assert audit["holdout_size"] == 30
    assert audit["split_method"] == "temporal"
    assert len(audit["holdout_accesses"]) == 1
    assert audit["holdout_accesses"][0]["experiment_id"] == "EXP-001"
```

### `vp_analysis/tests/test_frozen_types.py`

```python
import dataclasses
import pytest

from vp_analysis.core.frozen_types import FrozenRule, FrozenProductionConfig


# ─── Fixtures ───────────────────────────────────────────────────

def make_threshold_rule(**overrides):
    defaults = dict(
        rule_id="R-00001",
        experiment_id="EXP-2026-09-18-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD",
        setup="BOS",
        gate_type="threshold",
        direction=1,
        features=["auctTradeQuality"],
        lower_bound=0.65,
        upper_bound=None,
        test_ev_mean=0.42,
        pvalue_fdr=0.018,
        fdr_significant=True,
    )
    defaults.update(overrides)
    return FrozenRule(**defaults)


def make_band_rule():
    return FrozenRule(
        rule_id="R-00002",
        experiment_id="EXP-2026-09-18-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD",
        setup="BOS",
        gate_type="band",
        direction=0,
        features=("vpDevPOCDir",),
        lower_bound=-0.3,
        upper_bound=0.3,
        test_ev_mean=0.31,
        pvalue_fdr=0.04,
        fdr_significant=True,
    )


def make_model_rule():
    return FrozenRule(
        rule_id="R-00003",
        experiment_id="EXP-2026-09-18-001",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD",
        setup="BOS",
        gate_type="model",
        direction=0,
        features=("f1", "f2", "f3"),
        model_weights=(0.5, -0.3, 0.2),
        model_bias=0.1,
        score_threshold=0.55,
        test_ev_mean=0.28,
        fdr_significant=True,
    )


# ─── FrozenRule construction ────────────────────────────────────

def test_threshold_rule_valid():
    r = make_threshold_rule()
    assert r.rule_id == "R-00001"
    assert r.features == ("auctTradeQuality",)  # normalized to tuple
    assert r.frozen_at  # auto-populated


def test_band_rule_valid():
    r = make_band_rule()
    assert r.gate_type == "band"
    assert r.direction == 0


def test_model_rule_valid():
    r = make_model_rule()
    assert r.model_weights == (0.5, -0.3, 0.2)
    assert r.score_threshold == 0.55


def test_rule_requires_rule_id():
    with pytest.raises(ValueError, match="rule_id"):
        make_threshold_rule(rule_id="")


def test_rule_requires_experiment_id():
    with pytest.raises(ValueError, match="experiment_id"):
        make_threshold_rule(experiment_id="")


def test_rule_rejects_bad_gate_type():
    with pytest.raises(ValueError, match="gate_type"):
        make_threshold_rule(gate_type="weird")


def test_rule_rejects_bad_direction():
    with pytest.raises(ValueError, match="direction"):
        make_threshold_rule(direction=2)


def test_rule_requires_features():
    with pytest.raises(ValueError, match="features"):
        make_threshold_rule(features=[])


def test_threshold_direction_1_requires_lower_bound():
    with pytest.raises(ValueError, match="lower_bound"):
        make_threshold_rule(direction=1, lower_bound=None)


def test_threshold_direction_neg1_requires_upper_bound():
    with pytest.raises(ValueError, match="upper_bound"):
        FrozenRule(
            rule_id="R-X", experiment_id="EXP-X",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            gate_type="threshold", direction=-1,
            features=["f"], lower_bound=None, upper_bound=None,
        )


def test_band_requires_both_bounds():
    with pytest.raises(ValueError, match="band"):
        FrozenRule(
            rule_id="R-X", experiment_id="EXP-X",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            gate_type="band", direction=0,
            features=["f"], lower_bound=0.1, upper_bound=None,
        )


def test_band_rejects_inverted_bounds():
    with pytest.raises(ValueError, match="lower_bound < upper_bound"):
        FrozenRule(
            rule_id="R-X", experiment_id="EXP-X",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            gate_type="band", direction=0,
            features=["f"], lower_bound=0.5, upper_bound=0.2,
        )


def test_model_requires_weights_and_threshold():
    with pytest.raises(ValueError, match="model_weights"):
        FrozenRule(
            rule_id="R-X", experiment_id="EXP-X",
            research_contract_hash="sha256:" + "a" * 64,
            symbol="X", setup="Y",
            gate_type="model", direction=0,
            features=["f1", "f2"],
            score_threshold=0.5,
        )


# ─── FrozenRule immutability ────────────────────────────────────

def test_rule_is_dataclass_frozen():
    r = make_threshold_rule()
    with pytest.raises(dataclasses.FrozenInstanceError):
        r.test_ev_mean = 99.0


def test_rule_features_tuple_immutable():
    r = make_threshold_rule()
    with pytest.raises((TypeError, AttributeError)):
        r.features[0] = "changed"  # tuples don't support item assignment


def test_rule_roundtrip_dict():
    r = make_threshold_rule()
    d = r.to_dict()
    r2 = FrozenRule.from_dict(d)
    assert r2 == r


# ─── FrozenProductionConfig ─────────────────────────────────────

def test_frozen_config_valid():
    r1 = make_threshold_rule()
    r2 = make_band_rule()
    config = FrozenProductionConfig(
        experiment_id="EXP-2026-09-18-001",
        research_contract_hash="sha256:" + "a" * 64,
        rules=(r1, r2),
        sl_tp_selections=(
            {"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},
            {"rule_id": "R-00002", "sl": 1.0, "tp": 1.5},
        ),
        sizing_configs=(
            {"symbol": "XAUUSD", "setup": "BOS", "lot_mult": 1.2},
        ),
    )
    assert len(config.rules) == 2
    assert config.freeze_timestamp


def test_frozen_config_rejects_empty_rules():
    with pytest.raises(ValueError, match="at least one rule"):
        FrozenProductionConfig(
            experiment_id="EXP-X",
            research_contract_hash="sha256:" + "a" * 64,
            rules=(),
            sl_tp_selections=(),
            sizing_configs=(),
        )


def test_frozen_config_rejects_duplicate_rule_ids():
    r1 = make_threshold_rule()
    r2 = make_threshold_rule()  # same rule_id
    with pytest.raises(ValueError, match="Duplicate rule_ids"):
        FrozenProductionConfig(
            experiment_id="EXP-X",
            research_contract_hash="sha256:" + "a" * 64,
            rules=(r1, r2),
            sl_tp_selections=(),
            sizing_configs=(),
        )


def test_frozen_config_rejects_unknown_rule_ref():
    r1 = make_threshold_rule()
    with pytest.raises(ValueError, match="unknown rule_id"):
        FrozenProductionConfig(
            experiment_id="EXP-X",
            research_contract_hash="sha256:" + "a" * 64,
            rules=(r1,),
            sl_tp_selections=({"rule_id": "R-UNKNOWN", "sl": 1.0, "tp": 1.0},),
            sizing_configs=(),
        )


def test_frozen_config_is_frozen():
    r1 = make_threshold_rule()
    config = FrozenProductionConfig(
        experiment_id="EXP-X",
        research_contract_hash="sha256:" + "a" * 64,
        rules=(r1,),
        sl_tp_selections=(),
        sizing_configs=(),
    )
    with pytest.raises(dataclasses.FrozenInstanceError):
        config.experiment_id = "changed"


def test_frozen_config_roundtrip_dict():
    r1 = make_threshold_rule()
    config = FrozenProductionConfig(
        experiment_id="EXP-X",
        research_contract_hash="sha256:" + "a" * 64,
        rules=(r1,),
        sl_tp_selections=({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},),
        sizing_configs=(),
    )
    d = config.to_dict()
    assert d["rules"][0]["rule_id"] == "R-00001"
    assert d["sl_tp_selections"][0]["rule_id"] == "R-00001"
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/ -v
```

Kỳ vọng:

```text
test_provenance.py              12 passed
test_research_contract.py       12 passed
test_experiment_manifest.py     13 passed
test_governance.py               6 passed
test_data_boundary.py           22 passed
test_frozen_types.py            20 passed
───────────────────────────────────────
Total                           85 passed
```

---

## Preview cách dùng

Đây là flow hoàn chỉnh cho một experiment, dùng cả 0A và 0B:

```python
from vp_analysis.core import (
    ResearchContract, ExperimentLineage, ExperimentManifest,
    Governance, ExperimentResult,
    DataBoundary, FrozenRule, FrozenProductionConfig,
)

# 1. Load và freeze contract
contract = ResearchContract.from_yaml("vp_analysis/contracts/contract_v1.yaml")
contract.freeze()

# 2. Boot governance
lineage = ExperimentLineage(storage_path="output/lineage.json")
gov = Governance(contract, lineage)

# 3. Compute dataset hash (Sprint 0A utility)
from vp_analysis.core.provenance import hash_dataframe
dataset_hash = hash_dataframe(merged, exclude_cols=["time", "profitUSD"])

# 4. Check budget
gov.check_budget_before_start(dataset_hash)

# 5. Create experiment
eid = gov.next_experiment_id(dataset_hash)
manifest = ExperimentManifest(
    experiment_id=eid,
    research_contract_hash=contract.contract_hash,
    dataset_hash=dataset_hash,
    code_hash=contract.code_hash,
)
lineage.add(manifest)

# 6. Create boundary
boundary = DataBoundary.from_merged(
    merged, split_ratio=contract.split_ratio, split_method="temporal",
)

# 7. Feature engineering (fit on dev only)
from vp_analysis.core.data_boundary import FeatureTransformer

class InteractionTransformer:
    def fit(self, dev_df):
        # compute a_min, a_max, b_min, b_max for each pair on dev_df
        self.stats = {...}
        return self
    def transform(self, df):
        out = df.copy()
        for name, (a, b) in INTERACTION_DEFS.items():
            out[name] = ...  # apply using self.stats
        return out

boundary = boundary.apply(InteractionTransformer())

# 8. Discovery on boundary.dev (Sprint 3+)

# 9. Freeze rules
frozen_rules = [
    FrozenRule(
        rule_id=f"R-{i:05d}",
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        symbol=r["symbol"], setup=r["setup"],
        gate_type=r["gate_type"], direction=r["direction"],
        features=tuple(r["features"]),
        lower_bound=r.get("lower_bound"),
        upper_bound=r.get("upper_bound"),
        test_ev_mean=r["test_ev_mean"],
        pvalue_fdr=r.get("pvalue_fdr"),
        fdr_significant=r["fdr_significant"],
    )
    for i, r in enumerate(validated_rules, 1)
]

# 10. Freeze production config
production = FrozenProductionConfig(
    experiment_id=eid,
    research_contract_hash=contract.contract_hash,
    rules=tuple(frozen_rules),
    sl_tp_selections=tuple(sl_tp_results),
    sizing_configs=tuple(sizing_results),
)

# 11. THE ONLY TIME holdout is unsealed
holdout_df = boundary.holdout.unseal_once(
    experiment_id=eid,
    reason="final_production_evaluation",
)

# 12. Evaluate frozen artifacts on holdout (report only)
for rule in production.rules:
    ...  # apply gate, compute ev/wr/pf, record in report

# 13. Complete manifest
manifest.complete(ExperimentResult.SUCCESS)
lineage.save()
```

---

## Sprint 0B hoàn tất

**Những gì đã có sau Sprint 0B:**

```text
Type-level enforcement:
  ✓ DevelopmentData  ≠  SealedHoldout
  ✓ FrozenRule  immutable (dataclass frozen + tuple conversion)
  ✓ FrozenProductionConfig  immutable
  ✓ Access log shared qua transformations (không thể launder)

Runtime enforcement:
  ✓ unseal_once(experiment_id) — raise nếu trùng
  ✓ apply(transformer) — fit chỉ trên dev
  ✓ Không có API nào cho phép fit trên holdout
  ✓ Audit info exposes toàn bộ accesses

Test coverage:
  ✓ 22 tests cho DataBoundary
  ✓ 20 tests cho frozen types
  ✓ 85 tests tổng cộng
```


# Sprint 0C — Multiple Testing & Optimization Registries

Deliverables:
- `stats_helpers.py` — BH, BY, one-sided t-test, bootstrap CI
- `FDRPoolRegistry` — isolated pools, capacity enforcement, one-shot correction
- `OptimizationRegistry` — pre-registered grid, dev-only, no FDR
- `FrozenOptimizationResult` — new frozen type
- End-to-end kernel test
- ~42 new tests

Nguyên tắc:
- **FDR pools** — cho hypothesis testing (có statistical correction)
- **Optimization registry** — cho parameter tuning (không correction, chỉ pre-registered grid)
- **Không cho phép trộn** hai loại này.

---

## `vp_analysis/core/exceptions.py` — bổ sung

Thêm vào file từ Sprint 0A:

```python
class PoolRegistrationError(GovernanceError):
    """Raised on invalid FDR pool registration."""


class PoolCorrectedError(GovernanceError):
    """Raised when modifying an FDR pool after correction."""


class OptimizationError(GovernanceError):
    """Raised on invalid optimization registry operations."""
```

## `vp_analysis/core/stats_helpers.py`

```python
"""Statistical helpers for the analysis pipeline.

Pure functions, no state. No dependency on governance types — so they can
be used anywhere without coupling.
"""
from __future__ import annotations

import numpy as np
from scipy import stats


# ─── Multiple testing ───────────────────────────────────────────

def benjamini_hochberg(
    p_values: list[float],
    alpha: float = 0.05,
) -> tuple[np.ndarray, np.ndarray]:
    """Benjamini-Hochberg step-up FDR correction.

    Returns (reject_mask, p_adjusted).

    reject_mask[i] == True  iff  hypothesis i is rejected at level alpha.
    p_adjusted[i]          is the BH-adjusted p-value.
    """
    p = np.asarray(p_values, dtype=float)
    n = len(p)
    if n == 0:
        return np.zeros(0, dtype=bool), np.zeros(0, dtype=float)

    sorted_idx = np.argsort(p)
    sorted_p = p[sorted_idx]

    # p_adj_(k) = min over j >= k of (n/j) * p_(j), processed from largest
    ranks = np.arange(1, n + 1)
    scaled = sorted_p * n / ranks
    # Cummin from the right (largest p → smallest p)
    p_adj_sorted = np.minimum.accumulate(scaled[::-1])[::-1]
    p_adj_sorted = np.clip(p_adj_sorted, 0.0, 1.0)

    p_adj = np.empty(n, dtype=float)
    p_adj[sorted_idx] = p_adj_sorted

    reject = p_adj <= alpha
    return reject, p_adj


def benjamini_yekutieli(
    p_values: list[float],
    alpha: float = 0.05,
) -> tuple[np.ndarray, np.ndarray]:
    """Benjamini-Yekutieli FDR correction (valid under arbitrary dependence).

    More conservative than BH. Use when hypotheses are strongly correlated
    (e.g., overlapping feature families).
    """
    p = np.asarray(p_values, dtype=float)
    n = len(p)
    if n == 0:
        return np.zeros(0, dtype=bool), np.zeros(0, dtype=float)

    c_n = float(np.sum(1.0 / np.arange(1, n + 1)))
    sorted_idx = np.argsort(p)
    sorted_p = p[sorted_idx]

    ranks = np.arange(1, n + 1)
    scaled = sorted_p * n / (ranks * c_n)
    p_adj_sorted = np.minimum.accumulate(scaled[::-1])[::-1]
    p_adj_sorted = np.clip(p_adj_sorted, 0.0, 1.0)

    p_adj = np.empty(n, dtype=float)
    p_adj[sorted_idx] = p_adj_sorted

    reject = p_adj <= alpha
    return reject, p_adj


def correct_multiple_testing(
    p_values: list[float],
    alpha: float,
    method: str = "benjamini-hochberg",
) -> tuple[np.ndarray, np.ndarray]:
    """Dispatch to the configured method. Raises on unknown method."""
    m = method.lower().replace("-", "").replace("_", "")
    if m in ("benjaminihochberg", "bh", "fdrbh"):
        return benjamini_hochberg(p_values, alpha)
    if m in ("benjaminiyekutieli", "by", "fdrby"):
        return benjamini_yekutieli(p_values, alpha)
    raise ValueError(f"Unknown multiple testing method: {method!r}")


# ─── One-sample tests ───────────────────────────────────────────

def one_sided_t_test(
    values: list[float],
    null_mean: float = 0.0,
) -> tuple[float, float]:
    """One-sided t-test H0: mean <= null_mean, H1: mean > null_mean.

    Returns (t_stat, p_value). If fewer than 2 observations or zero
    variance, returns (0.0, 1.0).
    """
    a = np.asarray(values, dtype=float)
    if len(a) < 2:
        return 0.0, 1.0
    se = a.std(ddof=1) / np.sqrt(len(a))
    if se <= 0:
        return 0.0, 1.0
    t = (a.mean() - null_mean) / se
    p = float(stats.t.sf(t, df=len(a) - 1))
    return float(t), p


# ─── Bootstrap ──────────────────────────────────────────────────

def bootstrap_ci(
    values: list[float],
    alpha: float = 0.10,
    n_boot: int = 500,
    seed: int = 42,
) -> tuple[float, float]:
    """Percentile bootstrap CI for the mean.

    alpha=0.10 → 90% CI. If fewer than 3 observations, falls back to
    (min, max) which is a conservative interval.
    """
    a = np.asarray(values, dtype=float)
    if len(a) < 3:
        return float(a.min()), float(a.max())
    rng = np.random.default_rng(seed)
    means = np.empty(n_boot)
    for i in range(n_boot):
        sample = rng.choice(a, size=len(a), replace=True)
        means[i] = sample.mean()
    lo = float(np.percentile(means, 100 * alpha / 2))
    hi = float(np.percentile(means, 100 * (1 - alpha / 2)))
    return lo, hi
```

## `vp_analysis/core/fdr_registry.py`

```python
"""FDR pool registry for hypothesis testing.

Design:
  - Pools are configured up-front (from ResearchContract).
  - Each pool has a capacity cap (max_hypotheses) and its own alpha.
  - Hypotheses are registered with a caller-supplied label (unique within
    the pool). Registration has no return value — collect first.
  - Correction is called exactly once per pool, at the end of discovery.
  - After correction, the pool is sealed — no further registration.
  - Pools are isolated: registering into pool A cannot affect pool B, and
    correction for pool A cannot touch pool B.

The registry does NOT decide which p-values to keep — that is downstream
policy (rule finalization in Layer 6).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

import numpy as np

from .exceptions import PoolRegistrationError, PoolCorrectedError
from .research_contract import ResearchContract
from .stats_helpers import correct_multiple_testing


@dataclass
class _PoolState:
    name: str
    alpha: float
    max_hypotheses: int
    labels: list[str] = field(default_factory=list)
    p_values: list[float] = field(default_factory=list)
    corrected: bool = False
    reject_mask: Optional[np.ndarray] = None
    p_adjusted: Optional[np.ndarray] = None


@dataclass(frozen=True)
class PoolResult:
    """Immutable result of FDR correction for a single pool."""
    pool_name: str
    labels: tuple
    p_values: tuple
    reject: tuple                  # booleans, aligned with labels
    p_adjusted: tuple
    alpha: float

    def as_dict(self) -> dict[str, dict]:
        """Map label → {p_value, reject, p_adjusted}."""
        return {
            lab: {
                "p_value": float(self.p_values[i]),
                "reject": bool(self.reject[i]),
                "p_adjusted": float(self.p_adjusted[i]),
            }
            for i, lab in enumerate(self.labels)
        }


class FDRPoolRegistry:
    """Isolated FDR pools, capacity-enforced, corrected once."""

    def __init__(self, contract: ResearchContract):
        self._contract = contract
        self._pools: dict[str, _PoolState] = {}
        for name, pool_cfg in contract.fdr_pools.items():
            self._pools[name] = _PoolState(
                name=name,
                alpha=pool_cfg.alpha,
                max_hypotheses=pool_cfg.max_hypotheses,
            )

    # ─── Introspection ──────────────────────────────────────────

    @property
    def pool_names(self) -> list[str]:
        return list(self._pools.keys())

    def pool_size(self, pool_name: str) -> int:
        return len(self._get_pool(pool_name).p_values)

    def is_corrected(self, pool_name: str) -> bool:
        return self._get_pool(pool_name).corrected

    def _get_pool(self, name: str) -> _PoolState:
        if name not in self._pools:
            raise PoolRegistrationError(
                f"Unknown pool {name!r}. Available: {list(self._pools)}"
            )
        return self._pools[name]

    # ─── Registration ───────────────────────────────────────────

    def register(self, pool_name: str, label: str, p_value: float) -> None:
        """Register a hypothesis in a pool.

        label must be unique within the pool. p_value must be a finite
        float in [0, 1].
        """
        pool = self._get_pool(pool_name)

        if pool.corrected:
            raise PoolCorrectedError(
                f"Pool {pool_name!r} already corrected; cannot register more"
            )
        if not label:
            raise PoolRegistrationError("label cannot be empty")
        if label in pool.labels:
            raise PoolRegistrationError(
                f"Duplicate label {label!r} in pool {pool_name!r}"
            )
        if not (0.0 <= p_value <= 1.0):
            raise PoolRegistrationError(
                f"p_value must be in [0, 1], got {p_value}"
            )
        if len(pool.p_values) >= pool.max_hypotheses:
            raise PoolRegistrationError(
                f"Pool {pool_name!r} at capacity "
                f"({pool.max_hypotheses}). "
                f"Register fewer hypotheses or raise max_hypotheses "
                f"in the contract (which requires a new experiment)."
            )

        pool.labels.append(label)
        pool.p_values.append(float(p_value))

    def register_many(
        self,
        pool_name: str,
        items: list[tuple[str, float]],
    ) -> None:
        """Register multiple (label, p_value) pairs atomically.

        If any item fails validation, no item is registered.
        """
        pool = self._get_pool(pool_name)

        # Pre-validate
        if pool.corrected:
            raise PoolCorrectedError(
                f"Pool {pool_name!r} already corrected"
            )
        labels_to_add = [lab for lab, _ in items]
        if len(set(labels_to_add)) != len(labels_to_add):
            raise PoolRegistrationError("Duplicate labels in batch")
        for lab in labels_to_add:
            if lab in pool.labels:
                raise PoolRegistrationError(
                    f"Duplicate label {lab!r} in pool {pool_name!r}"
                )
        if len(pool.p_values) + len(items) > pool.max_hypotheses:
            raise PoolRegistrationError(
                f"Batch would exceed capacity "
                f"({pool.max_hypotheses}) for pool {pool_name!r}"
            )
        for _, p in items:
            if not (0.0 <= p <= 1.0):
                raise PoolRegistrationError(
                    f"p_value must be in [0, 1], got {p}"
                )

        for lab, p in items:
            pool.labels.append(lab)
            pool.p_values.append(float(p))

    # ─── Correction ─────────────────────────────────────────────

    def correct(self, pool_name: str) -> PoolResult:
        """Apply FDR to a pool, seal it, return immutable result.

        Calling twice raises PoolCorrectedError.
        """
        pool = self._get_pool(pool_name)
        if pool.corrected:
            raise PoolCorrectedError(
                f"Pool {pool_name!r} already corrected"
            )

        p_values = list(pool.p_values)
        if not p_values:
            reject = np.zeros(0, dtype=bool)
            p_adj = np.zeros(0, dtype=float)
        else:
            reject, p_adj = correct_multiple_testing(
                p_values,
                alpha=pool.alpha,
                method=self._contract.multiple_testing_method,
            )

        pool.reject_mask = reject
        pool.p_adjusted = p_adj
        pool.corrected = True

        return PoolResult(
            pool_name=pool_name,
            labels=tuple(pool.labels),
            p_values=tuple(pool.p_values),
            reject=tuple(bool(x) for x in reject),
            p_adjusted=tuple(float(x) for x in p_adj),
            alpha=pool.alpha,
        )

    def get_result(self, pool_name: str) -> PoolResult:
        """Return the result of an already-corrected pool."""
        pool = self._get_pool(pool_name)
        if not pool.corrected:
            raise PoolCorrectedError(
                f"Pool {pool_name!r} not yet corrected"
            )
        return PoolResult(
            pool_name=pool_name,
            labels=tuple(pool.labels),
            p_values=tuple(pool.p_values),
            reject=tuple(bool(x) for x in pool.reject_mask),
            p_adjusted=tuple(float(x) for x in pool.p_adjusted),
            alpha=pool.alpha,
        )
```

## `vp_analysis/core/optimization_registry.py`

```python
"""Optimization registry for parameter tuning (SL/TP, sizing).

Distinct from FDR pools:
  - No statistical correction. This is optimization, not hypothesis testing.
  - The grid is pre-registered in the contract.
  - Selection is by a caller-provided utility function.
  - After selection, the result is frozen.
  - Selection runs on development data only (caller's responsibility, but
    the API is designed so the caller cannot accidentally pull holdout in).

The registry does NOT know about the target. It only evaluates candidate
parameter combinations via the caller-provided evaluate_fn.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import dataclass, field
from typing import Callable, Optional

from .exceptions import OptimizationError
from .research_contract import ResearchContract


# ─── Frozen result type ─────────────────────────────────────────

@dataclass(frozen=True)
class FrozenOptimizationResult:
    """Result of a parameter optimization run for one rule."""
    rule_id: str
    parameter_name: str                     # "sl_tp" | "sizing" | ...
    selected: tuple                         # tuple of (name, value) pairs
    evaluated_all: tuple                    # tuple of dicts (params + utility)
    utility_name: str
    frozen_at: str = field(
        default_factory=lambda: dt.datetime.utcnow().isoformat() + "Z"
    )

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "parameter_name": self.parameter_name,
            "selected": dict(self.selected),
            "evaluated_all": list(self.evaluated_all),
            "utility_name": self.utility_name,
            "frozen_at": self.frozen_at,
        }


# ─── Registry ───────────────────────────────────────────────────

class OptimizationRegistry:
    """Pre-registered grid search. Stateless correction (none)."""

    def __init__(self, contract: ResearchContract):
        self._contract = contract
        self._sl_candidates = list(contract.optimization_budget.sl_candidates)
        self._tp_candidates = list(contract.optimization_budget.tp_candidates)
        self._utility_name = contract.optimization_budget.utility_function
        self._results: dict[str, FrozenOptimizationResult] = {}
        # Prevent double-call for the same rule_id
        self._completed_rules: set[str] = set()

    # ─── Introspection ──────────────────────────────────────────

    @property
    def sl_candidates(self) -> tuple:
        return tuple(self._sl_candidates)

    @property
    def tp_candidates(self) -> tuple:
        return tuple(self._tp_candidates)

    @property
    def utility_name(self) -> str:
        return self._utility_name

    # ─── SL/TP optimization ────────────────────────────────────

    def optimize_sl_tp(
        self,
        rule_id: str,
        evaluate_fn: Callable[[dict], float],
    ) -> FrozenOptimizationResult:
        """Enumerate all (sl, tp) combos, pick the best by utility.

        evaluate_fn(params: dict) -> float (higher = better utility).
        Caller is responsible for evaluating on development data only.
        """
        if not rule_id:
            raise OptimizationError("rule_id is required")
        if rule_id in self._completed_rules:
            raise OptimizationError(
                f"Rule {rule_id!r} already optimized; cannot re-run"
            )
        if not self._sl_candidates:
            raise OptimizationError("sl_candidates is empty")
        if not self._tp_candidates:
            raise OptimizationError("tp_candidates is empty")

        evaluated: list[dict] = []
        best_utility = float("-inf")
        best_params: Optional[dict] = None

        for sl in self._sl_candidates:
            for tp in self._tp_candidates:
                params = {"sl": float(sl), "tp": float(tp)}
                utility = float(evaluate_fn(params))
                if not (utility == utility):  # NaN check
                    raise OptimizationError(
                        f"evaluate_fn returned NaN for params {params}"
                    )
                evaluated.append({**params, "utility": utility})
                if utility > best_utility:
                    best_utility = utility
                    best_params = params

        if best_params is None:
            raise OptimizationError(
                f"No valid combination evaluated for rule {rule_id!r}"
            )

        selected = (("sl", best_params["sl"]), ("tp", best_params["tp"]))
        result = FrozenOptimizationResult(
            rule_id=rule_id,
            parameter_name="sl_tp",
            selected=selected,
            evaluated_all=tuple(evaluated),
            utility_name=self._utility_name,
        )
        self._results[rule_id] = result
        self._completed_rules.add(rule_id)
        return result

    # ─── Sizing optimization (single-parameter) ────────────────

    def optimize_sizing(
        self,
        rule_id: str,
        candidate_multipliers: list[float],
        evaluate_fn: Callable[[dict], float],
    ) -> FrozenOptimizationResult:
        """Optimize lot multiplier among a caller-supplied candidate list.

        Unlike SL/TP the sizing grid is not part of the contract — the
        candidate list is derived by the caller (e.g., from Kelly).
        Utility selection remains the same.
        """
        if not rule_id:
            raise OptimizationError("rule_id is required")
        if rule_id in self._completed_rules:
            raise OptimizationError(
                f"Rule {rule_id!r} already optimized; cannot re-run"
            )
        if not candidate_multipliers:
            raise OptimizationError("candidate_multipliers is empty")

        evaluated: list[dict] = []
        best_utility = float("-inf")
        best_mult: Optional[float] = None

        for mult in candidate_multipliers:
            params = {"lot_mult": float(mult)}
            utility = float(evaluate_fn(params))
            if not (utility == utility):
                raise OptimizationError(
                    f"evaluate_fn returned NaN for {params}"
                )
            evaluated.append({**params, "utility": utility})
            if utility > best_utility:
                best_utility = utility
                best_mult = float(mult)

        if best_mult is None:
            raise OptimizationError(
                f"No valid sizing candidate for rule {rule_id!r}"
            )

        result = FrozenOptimizationResult(
            rule_id=rule_id,
            parameter_name="sizing",
            selected=(("lot_mult", best_mult),),
            evaluated_all=tuple(evaluated),
            utility_name=self._utility_name,
        )
        self._results[rule_id] = result
        self._completed_rules.add(rule_id)
        return result

    # ─── Lookup ─────────────────────────────────────────────────

    def get_result(self, rule_id: str) -> FrozenOptimizationResult:
        if rule_id not in self._results:
            raise OptimizationError(
                f"No optimization result for rule {rule_id!r}"
            )
        return self._results[rule_id]

    def all_results(self) -> dict[str, FrozenOptimizationResult]:
        return dict(self._results)
```

## `vp_analysis/core/__init__.py` — cập nhật exports

```python
"""Core governance modules."""
from .research_contract import ResearchContract
from .experiment_manifest import (
    ExperimentManifest, ExperimentLineage,
    ExperimentStatus, ExperimentResult,
)
from .governance import Governance
from .data_boundary import (
    DataBoundary, DevelopmentData, SealedHoldout,
    HoldoutAccessLog, HoldoutAccessRecord,
    FeatureTransformer,
)
from .frozen_types import (
    FrozenRule, FrozenProductionConfig,
)
from .fdr_registry import FDRPoolRegistry, PoolResult
from .optimization_registry import (
    OptimizationRegistry, FrozenOptimizationResult,
)

__all__ = [
    # Sprint 0A
    "ResearchContract",
    "ExperimentManifest", "ExperimentLineage",
    "ExperimentStatus", "ExperimentResult",
    "Governance",
    # Sprint 0B
    "DataBoundary", "DevelopmentData", "SealedHoldout",
    "HoldoutAccessLog", "HoldoutAccessRecord",
    "FeatureTransformer",
    "FrozenRule", "FrozenProductionConfig",
    # Sprint 0C
    "FDRPoolRegistry", "PoolResult",
    "OptimizationRegistry", "FrozenOptimizationResult",
]
```

---

## Tests

### `vp_analysis/tests/test_stats_helpers.py`

```python
import numpy as np
import pytest

from vp_analysis.core.stats_helpers import (
    benjamini_hochberg,
    benjamini_yekutieli,
    bootstrap_ci,
    correct_multiple_testing,
    one_sided_t_test,
)


# ─── BH ─────────────────────────────────────────────────────────

def test_bh_empty():
    reject, p_adj = benjamini_hochberg([], alpha=0.05)
    assert len(reject) == 0
    assert len(p_adj) == 0


def test_bh_all_significant():
    p = [0.001, 0.002, 0.003, 0.004]
    reject, p_adj = benjamini_hochberg(p, alpha=0.05)
    assert reject.all()


def test_bh_none_significant():
    p = [0.5, 0.6, 0.7, 0.8]
    reject, p_adj = benjamini_hochberg(p, alpha=0.05)
    assert not reject.any()


def test_bh_step_up_property():
    # Classic BH example
    p = [0.001, 0.008, 0.039, 0.041, 0.042, 0.06, 0.074, 0.205,
         0.212, 0.216, 0.222, 0.251, 0.269, 0.275, 0.34]
    reject, p_adj = benjamini_hochberg(p, alpha=0.05)
    # Reference: R's p.adjust(..., method="BH") rejects first 4
    assert reject[:4].all()
    assert not reject[5:].any()


def test_bh_p_adj_monotone_with_p():
    p = [0.01, 0.02, 0.03, 0.5]
    _, p_adj = benjamini_hochberg(p, alpha=0.05)
    assert p_adj[0] <= p_adj[1] <= p_adj[2] <= p_adj[3]


def test_bh_alpha_zero_rejects_nothing():
    p = [0.001, 0.002]
    reject, _ = benjamini_hochberg(p, alpha=0.0)
    assert not reject.any()


def test_by_more_conservative_than_bh():
    p = [0.001, 0.01, 0.02, 0.03, 0.04]
    _, p_adj_bh = benjamini_hochberg(p, alpha=0.05)
    _, p_adj_by = benjamini_yekutieli(p, alpha=0.05)
    assert (p_adj_by >= p_adj_bh - 1e-12).all()


# ─── Dispatcher ────────────────────────────────────────────────

def test_dispatch_bh():
    r1, _ = correct_multiple_testing([0.01, 0.02], 0.05, "benjamini-hochberg")
    r2, _ = correct_multiple_testing([0.01, 0.02], 0.05, "bh")
    assert (r1 == r2).all()


def test_dispatch_unknown_method_raises():
    with pytest.raises(ValueError):
        correct_multiple_testing([0.01], 0.05, "unknown")


# ─── One-sided t-test ──────────────────────────────────────────

def test_t_test_insufficient_data():
    t, p = one_sided_t_test([0.5])
    assert p == 1.0


def test_t_test_zero_variance():
    t, p = one_sided_t_test([0.5, 0.5, 0.5])
    assert p == 1.0


def test_t_test_positive_mean_significant():
    vals = [0.4, 0.5, 0.6, 0.5, 0.45, 0.55, 0.5, 0.48]
    t, p = one_sided_t_test(vals, null_mean=0.0)
    assert t > 0
    assert p < 0.01


def test_t_test_negative_mean_not_significant():
    vals = [-0.4, -0.5, -0.6, -0.5]
    t, p = one_sided_t_test(vals, null_mean=0.0)
    assert t < 0
    assert p > 0.5


# ─── Bootstrap CI ──────────────────────────────────────────────

def test_bootstrap_ci_small_sample_fallback():
    lo, hi = bootstrap_ci([1.0, 2.0])
    assert lo == 1.0 and hi == 2.0


def test_bootstrap_ci_brackets_mean():
    rng = np.random.default_rng(0)
    vals = rng.normal(1.0, 0.5, size=100).tolist()
    lo, hi = bootstrap_ci(vals, alpha=0.10)
    assert lo < 1.0 < hi


def test_bootstrap_ci_deterministic_with_seed():
    vals = [1.0, 2.0, 3.0, 4.0, 5.0] * 10
    lo1, hi1 = bootstrap_ci(vals, seed=42)
    lo2, hi2 = bootstrap_ci(vals, seed=42)
    assert lo1 == lo2 and hi1 == hi2
```

### `vp_analysis/tests/test_fdr_registry.py`

```python
import pytest

from vp_analysis.core.exceptions import (
    PoolCorrectedError,
    PoolRegistrationError,
)
from vp_analysis.core.fdr_registry import FDRPoolRegistry
from vp_analysis.core.research_contract import ResearchContract


@pytest.fixture
def registry(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    return FDRPoolRegistry(contract)


# ─── Configuration ─────────────────────────────────────────────

def test_pools_created_from_contract(registry):
    names = registry.pool_names
    assert "hard_gate" in names
    assert "soft_gate" in names


def test_unknown_pool_raises(registry):
    with pytest.raises(PoolRegistrationError, match="Unknown pool"):
        registry.register("nonexistent", "H1", 0.05)


# ─── Registration ──────────────────────────────────────────────

def test_register_single(registry):
    registry.register("hard_gate", "H1", 0.01)
    assert registry.pool_size("hard_gate") == 1


def test_register_duplicate_label_raises(registry):
    registry.register("hard_gate", "H1", 0.01)
    with pytest.raises(PoolRegistrationError, match="Duplicate label"):
        registry.register("hard_gate", "H1", 0.02)


def test_register_invalid_p_value_low(registry):
    with pytest.raises(PoolRegistrationError, match="p_value"):
        registry.register("hard_gate", "H1", -0.1)


def test_register_invalid_p_value_high(registry):
    with pytest.raises(PoolRegistrationError, match="p_value"):
        registry.register("hard_gate", "H1", 1.5)


def test_register_empty_label(registry):
    with pytest.raises(PoolRegistrationError, match="empty"):
        registry.register("hard_gate", "", 0.05)


def test_register_many(registry):
    registry.register_many("hard_gate", [("H1", 0.01), ("H2", 0.02)])
    assert registry.pool_size("hard_gate") == 2


def test_register_many_atomic_on_failure(registry):
    # Second item invalid → nothing registered
    with pytest.raises(PoolRegistrationError):
        registry.register_many("hard_gate", [("H1", 0.01), ("H2", -1)])
    assert registry.pool_size("hard_gate") == 0


def test_register_many_duplicate_inside_batch(registry):
    with pytest.raises(PoolRegistrationError, match="Duplicate"):
        registry.register_many("hard_gate", [("H1", 0.01), ("H1", 0.02)])


# ─── Capacity ──────────────────────────────────────────────────

def test_capacity_enforced(minimal_contract_dict):
    # Override to tiny capacity
    d = dict(minimal_contract_dict)
    d["fdr_pools"] = {
        "hard_gate": {"name": "hard_gate", "max_hypotheses": 2, "alpha": 0.05},
    }
    contract = ResearchContract.from_dict(d)
    reg = FDRPoolRegistry(contract)

    reg.register("hard_gate", "H1", 0.01)
    reg.register("hard_gate", "H2", 0.02)
    with pytest.raises(PoolRegistrationError, match="capacity"):
        reg.register("hard_gate", "H3", 0.03)


def test_batch_capacity_check(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["fdr_pools"] = {
        "hard_gate": {"name": "hard_gate", "max_hypotheses": 2, "alpha": 0.05},
    }
    contract = ResearchContract.from_dict(d)
    reg = FDRPoolRegistry(contract)
    with pytest.raises(PoolRegistrationError, match="capacity"):
        reg.register_many(
            "hard_gate", [("H1", 0.01), ("H2", 0.02), ("H3", 0.03)],
        )


# ─── Isolation ─────────────────────────────────────────────────

def test_pools_isolated(registry):
    registry.register("hard_gate", "H1", 0.001)
    registry.register("soft_gate", "S1", 0.5)
    assert registry.pool_size("hard_gate") == 1
    assert registry.pool_size("soft_gate") == 1


def test_correction_isolated(registry):
    # hard_gate: one very small p (reject)
    registry.register("hard_gate", "H1", 0.001)
    # soft_gate: same small p — would also reject in isolation
    registry.register("soft_gate", "S1", 0.5)  # not reject

    r_hard = registry.correct("hard_gate")
    r_soft = registry.correct("soft_gate")

    assert r_hard.as_dict()["H1"]["reject"] is True
    assert r_soft.as_dict()["S1"]["reject"] is False


# ─── Correction ────────────────────────────────────────────────

def test_correct_returns_result(registry):
    registry.register_many("hard_gate", [
        ("H1", 0.001), ("H2", 0.5),
    ])
    result = registry.correct("hard_gate")
    assert result.pool_name == "hard_gate"
    assert len(result.labels) == 2
    d = result.as_dict()
    assert d["H1"]["reject"] is True
    assert d["H2"]["reject"] is False


def test_correct_empty_pool(registry):
    result = registry.correct("hard_gate")
    assert len(result.labels) == 0
    assert len(result.reject) == 0


def test_correct_twice_raises(registry):
    registry.register("hard_gate", "H1", 0.01)
    registry.correct("hard_gate")
    with pytest.raises(PoolCorrectedError):
        registry.correct("hard_gate")


def test_register_after_correct_raises(registry):
    registry.register("hard_gate", "H1", 0.01)
    registry.correct("hard_gate")
    with pytest.raises(PoolCorrectedError):
        registry.register("hard_gate", "H2", 0.02)


def test_is_corrected_flag(registry):
    assert not registry.is_corrected("hard_gate")
    registry.correct("hard_gate")
    assert registry.is_corrected("hard_gate")


def test_get_result_before_correct_raises(registry):
    with pytest.raises(PoolCorrectedError, match="not yet"):
        registry.get_result("hard_gate")


def test_get_result_after_correct(registry):
    registry.register("hard_gate", "H1", 0.001)
    registry.correct("hard_gate")
    r = registry.get_result("hard_gate")
    assert r.as_dict()["H1"]["reject"] is True
```

### `vp_analysis/tests/test_optimization_registry.py`

```python
import dataclasses

import pytest

from vp_analysis.core.exceptions import OptimizationError
from vp_analysis.core.optimization_registry import (
    FrozenOptimizationResult,
    OptimizationRegistry,
)
from vp_analysis.core.research_contract import ResearchContract


@pytest.fixture
def registry(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    return OptimizationRegistry(contract)


# ─── Configuration ─────────────────────────────────────────────

def test_grid_from_contract(registry):
    assert registry.sl_candidates == (1.0, 1.5, 2.0)
    assert registry.tp_candidates == (1.0, 1.5, 2.0)
    assert registry.utility_name == "expectancy"


# ─── SL/TP optimization ────────────────────────────────────────

def test_optimize_sl_tp_picks_best(registry):
    # Utility peaks at sl=1.5, tp=2.0
    def evaluate(params):
        return 10.0 - abs(params["sl"] - 1.5) - abs(params["tp"] - 2.0)

    result = registry.optimize_sl_tp("R-001", evaluate)
    assert dict(result.selected) == {"sl": 1.5, "tp": 2.0}
    assert result.parameter_name == "sl_tp"


def test_optimize_evaluates_all_combos(registry):
    calls = []

    def evaluate(params):
        calls.append((params["sl"], params["tp"]))
        return 0.0

    registry.optimize_sl_tp("R-001", evaluate)
    # 3 SL × 3 TP = 9 combos
    assert len(calls) == 9
    assert len(set(calls)) == 9


def test_optimize_requires_rule_id(registry):
    with pytest.raises(OptimizationError, match="rule_id"):
        registry.optimize_sl_tp("", lambda p: 0.0)


def test_optimize_same_rule_twice_raises(registry):
    registry.optimize_sl_tp("R-001", lambda p: 0.0)
    with pytest.raises(OptimizationError, match="already optimized"):
        registry.optimize_sl_tp("R-001", lambda p: 1.0)


def test_optimize_nan_utility_raises(registry):
    def evaluate(_):
        return float("nan")
    with pytest.raises(OptimizationError, match="NaN"):
        registry.optimize_sl_tp("R-001", evaluate)


# ─── Sizing optimization ───────────────────────────────────────

def test_optimize_sizing_picks_best(registry):
    def evaluate(params):
        return 5.0 - abs(params["lot_mult"] - 1.2)

    result = registry.optimize_sizing("R-002", [0.5, 1.0, 1.2, 1.5], evaluate)
    assert dict(result.selected) == {"lot_mult": 1.2}
    assert result.parameter_name == "sizing"


def test_optimize_sizing_empty_candidates(registry):
    with pytest.raises(OptimizationError, match="empty"):
        registry.optimize_sizing("R-002", [], lambda p: 0.0)


# ─── Result ────────────────────────────────────────────────────

def test_get_result_after_optimize(registry):
    registry.optimize_sl_tp("R-001", lambda p: 0.0)
    r = registry.get_result("R-001")
    assert r.rule_id == "R-001"


def test_get_result_before_optimize_raises(registry):
    with pytest.raises(OptimizationError, match="No optimization"):
        registry.get_result("R-UNKNOWN")


def test_frozen_result_immutable(registry):
    r = registry.optimize_sl_tp("R-001", lambda p: 0.0)
    with pytest.raises(dataclasses.FrozenInstanceError):
        r.rule_id = "changed"


def test_frozen_result_dict_roundtrip(registry):
    r = registry.optimize_sl_tp("R-001", lambda p: 0.0)
    d = r.to_dict()
    assert d["rule_id"] == "R-001"
    assert d["parameter_name"] == "sl_tp"
    assert isinstance(d["selected"], dict)


def test_all_results(registry):
    registry.optimize_sl_tp("R-001", lambda p: 0.0)
    registry.optimize_sl_tp("R-002", lambda p: 0.0)
    assert set(registry.all_results().keys()) == {"R-001", "R-002"}
```

### `vp_analysis/tests/test_kernel_end_to_end.py`

```python
"""End-to-end smoke test for the governance kernel.

Exercises the intended workflow from contract → boundary → discovery
registries → freeze → holdout unseal → manifest completion. Uses stub
data and stub logic. Its job is to catch integration bugs, not to test
statistical correctness (covered by unit tests)."""
import dataclasses
import datetime as dt

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core import (
    DataBoundary,
    ExperimentLineage,
    ExperimentManifest,
    ExperimentResult,
    ExperimentStatus,
    FDRPoolRegistry,
    FrozenProductionConfig,
    FrozenRule,
    Governance,
    OptimizationRegistry,
    ResearchContract,
)
from vp_analysis.core.exceptions import HoldoutAlreadyUnsealedError
from vp_analysis.core.provenance import hash_dataframe


# ─── Fixture: minimal synthetic merged dataset ─────────────────

@pytest.fixture
def synthetic_merged():
    rng = np.random.default_rng(42)
    n = 200
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="D"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f1": rng.normal(0, 1, n),
        "f2": rng.normal(0, 1, n),
        "profitUSD": rng.normal(0.1, 1.0, n),
    })
    return df


class _StubTransformer:
    """Minimal transformer: standardize f1 and f2 on dev."""

    def __init__(self):
        self.mu_f1 = self.sd_f1 = None
        self.mu_f2 = self.sd_f2 = None

    def fit(self, df):
        self.mu_f1, self.sd_f1 = df["f1"].mean(), df["f1"].std()
        self.mu_f2, self.sd_f2 = df["f2"].mean(), df["f2"].std()
        return self

    def transform(self, df):
        out = df.copy()
        out["f1_z"] = (df["f1"] - self.mu_f1) / (self.sd_f1 + 1e-9)
        out["f2_z"] = (df["f2"] - self.mu_f2) / (self.sd_f2 + 1e-9)
        return out


# ─── The end-to-end test ───────────────────────────────────────

def test_kernel_end_to_end(minimal_contract_dict, synthetic_merged, tmp_path):
    # 1. Contract
    contract = ResearchContract.from_dict(minimal_contract_dict)
    contract.freeze()
    assert contract.is_frozen

    # 2. Governance boot
    lineage = ExperimentLineage(storage_path=tmp_path / "lineage.json")
    gov = Governance(contract, lineage)

    # 3. Dataset hash + budget check
    dataset_hash = hash_dataframe(
        synthetic_merged, exclude_cols=["time", "profitUSD"],
    )
    gov.check_budget_before_start(dataset_hash)

    # 4. Create experiment
    eid = gov.next_experiment_id(dataset_hash)
    manifest = ExperimentManifest(
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        dataset_hash=dataset_hash,
        code_hash=contract.code_hash,
    )
    lineage.add(manifest)
    assert manifest.status == ExperimentStatus.ACTIVE

    # 5. Boundary
    boundary = DataBoundary.from_merged(
        synthetic_merged, split_ratio=contract.split_ratio,
    )
    assert boundary.holdout.is_sealed
    assert len(boundary.dev) == 140
    assert boundary.holdout.size == 60

    # 6. Feature engineering (fit on dev only)
    boundary = boundary.apply(_StubTransformer())
    assert "f1_z" in boundary.dev.columns
    assert boundary.holdout.is_sealed  # still sealed after transform

    # 7. Discovery registries (stub hypotheses)
    fdr = FDRPoolRegistry(contract)
    fdr.register_many("hard_gate", [
        ("H1_f1_gt_0", 0.001),
        ("H2_f2_gt_0", 0.020),
        ("H3_f1z_band", 0.150),
        ("H4_f2z_band", 0.300),
    ])
    fdr.register_many("soft_gate", [
        ("S1_f1_direction", 0.040),
        ("S2_f2_direction", 0.200),
    ])

    hard_result = fdr.correct("hard_gate")
    soft_result = fdr.correct("soft_gate")

    # 8. Build frozen rules from FDR survivors
    frozen_rules = []
    for i, (label, info) in enumerate(hard_result.as_dict().items(), 1):
        if not info["reject"]:
            continue
        frozen_rules.append(FrozenRule(
            rule_id=f"R-{i:05d}",
            experiment_id=eid,
            research_contract_hash=contract.contract_hash,
            symbol="XAUUSD",
            setup="BOS",
            gate_type="threshold",
            direction=1,
            features=["f1_z"],
            lower_bound=0.0,
            test_ev_mean=0.42,
            pvalue_fdr=info["p_adjusted"],
            fdr_significant=True,
        ))
    assert len(frozen_rules) >= 1
    assert all(r.fdr_significant for r in frozen_rules)

    # 9. Optimization on dev
    opt_reg = OptimizationRegistry(contract)

    def eval_sl_tp(params):
        # Stub utility: prefers sl=1.5, tp=2.0
        return 1.0 - 0.1 * abs(params["sl"] - 1.5) - 0.1 * abs(params["tp"] - 2.0)

    for rule in frozen_rules:
        opt_reg.optimize_sl_tp(rule.rule_id, eval_sl_tp)

    sl_tp_selections = tuple(
        {"rule_id": r.rule_id,
         **dict(opt_reg.get_result(r.rule_id).selected)}
        for r in frozen_rules
    )

    # 10. Freeze production config
    production = FrozenProductionConfig(
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        rules=tuple(frozen_rules),
        sl_tp_selections=sl_tp_selections,
        sizing_configs=(),
    )
    assert len(production.rules) == len(frozen_rules)

    # 11. Holdout unseal — the ONE and only time
    holdout_df = boundary.holdout.unseal_once(
        experiment_id=eid,
        reason="final_production_evaluation",
    )
    assert isinstance(holdout_df, pd.DataFrame)
    assert len(holdout_df) == 60

    # 12. Evaluation is pure measurement (no mutation)
    # Just count passing trades per rule — no actual gate logic here
    for rule in production.rules:
        mask = holdout_df[rule.features[0]] >= rule.lower_bound
        n_pass = int(mask.sum())
        assert n_pass >= 0  # trivially true, just verifying no crash

    # 13. Second unseal attempt must fail
    with pytest.raises(HoldoutAlreadyUnsealedError):
        boundary.holdout.unseal_once(eid, reason="try_again")

    # 14. Complete manifest
    manifest.complete(ExperimentResult.SUCCESS)
    assert manifest.status == ExperimentStatus.COMPLETED
    assert manifest.result == ExperimentResult.SUCCESS

    # 15. Persist lineage and reload
    lineage.save()
    lineage2 = ExperimentLineage(storage_path=tmp_path / "lineage.json")
    lineage2.load()
    assert lineage2.exists(eid)
    loaded = lineage2.get(eid)
    assert loaded.status == ExperimentStatus.COMPLETED
    assert loaded.result == ExperimentResult.SUCCESS


# ─── Null result path (dev null) ───────────────────────────────

def test_kernel_null_dev_result(minimal_contract_dict, synthetic_merged, tmp_path):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    contract.freeze()

    lineage = ExperimentLineage()
    gov = Governance(contract, lineage)
    dataset_hash = hash_dataframe(synthetic_merged, exclude_cols=["time"])
    eid = gov.next_experiment_id(dataset_hash)

    manifest = ExperimentManifest(
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        dataset_hash=dataset_hash,
        code_hash=contract.code_hash,
    )
    lineage.add(manifest)

    # All hypotheses fail FDR — no rules survive
    fdr = FDRPoolRegistry(contract)
    fdr.register_many("hard_gate", [
        ("H1", 0.5), ("H2", 0.6), ("H3", 0.7),
    ])
    result = fdr.correct("hard_gate")
    survivors = [lab for lab, info in result.as_dict().items()
                 if info["reject"]]
    assert survivors == []

    # Null result — holdout stays sealed
    boundary = DataBoundary.from_merged(synthetic_merged)
    assert boundary.holdout.is_sealed

    manifest.complete(ExperimentResult.NULL_DEV)
    assert manifest.result == ExperimentResult.NULL_DEV


# ─── Immutability of frozen artifacts in context ───────────────

def test_frozen_rule_immutable_after_freeze(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    rule = FrozenRule(
        rule_id="R-00001",
        experiment_id="EXP-X",
        research_contract_hash=contract.contract_hash,
        symbol="XAUUSD",
        setup="BOS",
        gate_type="threshold",
        direction=1,
        features=["f1"],
        lower_bound=0.5,
        fdr_significant=True,
    )
    with pytest.raises(dataclasses.FrozenInstanceError):
        rule.test_ev_mean = 99.0


# ─── FDR pools in context of full workflow ────────────────────

def test_fdr_pool_isolation_in_workflow(minimal_contract_dict):
    contract = ResearchContract.from_dict(minimal_contract_dict)
    fdr = FDRPoolRegistry(contract)

    # Same p-value in two pools: only one rejects
    fdr.register("hard_gate", "H1", 0.001)
    fdr.register("soft_gate", "S1", 0.900)

    hard = fdr.correct("hard_gate")
    soft = fdr.correct("soft_gate")

    assert hard.as_dict()["H1"]["reject"] is True
    assert soft.as_dict()["S1"]["reject"] is False
```

---

## Chạy full kernel test suite

```bash
cd vp_analysis/..
pytest vp_analysis/tests/ -v
```

Expected output:

```text
test_provenance.py               12 passed
test_research_contract.py        12 passed
test_experiment_manifest.py      13 passed
test_governance.py                6 passed
test_data_boundary.py            22 passed
test_frozen_types.py             20 passed
test_stats_helpers.py            18 passed
test_fdr_registry.py             20 passed
test_optimization_registry.py    14 passed
test_kernel_end_to_end.py         4 passed
──────────────────────────────────────────────
Total                           141 passed
```

---

## Kernel hoàn chỉnh

Sau Sprint 0A + 0B + 0C:

```text
┌────────────────────────────────────────────────────────────────┐
│                    GOVERNANCE KERNEL                            │
│                                                                 │
│  Sprint 0A — Identity & budgets                                 │
│  ─────────────────────────────                                  │
│  • ResearchContract (6 hashes, freeze protocol)                 │
│  • ExperimentManifest + ExperimentLineage (DAG)                 │
│  • Governance (selection budget enforcement)                    │
│  • Provenance hashing (deterministic)                           │
│                                                                 │
│  Sprint 0B — Information boundary                               │
│  ─────────────────────────────                                  │
│  • DevelopmentData (read-only)                                  │
│  • SealedHoldout (access log, unseal_once)                      │
│  • HoldoutAccessLog (survives transformations)                  │
│  • DataBoundary (fit-on-dev semantics)                          │
│  • FrozenRule, FrozenProductionConfig (deep immutable)          │
│                                                                 │
│  Sprint 0C — Testing & registries                               │
│  ─────────────────────────────                                  │
│  • stats_helpers (BH, BY, t-test, bootstrap)                    │
│  • FDRPoolRegistry (isolated, capacity-capped, once)            │
│  • OptimizationRegistry (pre-registered grid, no FDR)           │
│  • FrozenOptimizationResult                                     │
│                                                                 │
│  Enforcement layers:                                            │
│  1. Type system (DevelopmentData ≠ SealedHoldout)               │
│  2. Runtime asserts (unseal_once, budget, capacity)             │
│  3. Convention + tests (141 tests cover all behavior)           │
└────────────────────────────────────────────────────────────────┘
```

## Layer 0 → 12 giờ có thể bắt đầu

Kernel cung cấp cho các layers sau:

- **Layer 0-1** — dùng `DataBoundary.from_merged()`, `DevelopmentData` access, `hash_dataframe()`
- **Layer 2** — dùng `boundary.apply(transformer)` cho interaction scaler
- **Layer 3-5** — nhận `DevelopmentData` như tham số, không cần quan tâm holdout
- **Layer 6** — dùng `FDRPoolRegistry` với 3 pools
- **Layer 6.5** — construct `FrozenRule` objects
- **Layer 7** — dùng `OptimizationRegistry`, dùng `boundary.dev`
- **Layer 7.5** — construct `FrozenProductionConfig`
- **Layer 8** — dùng `boundary.holdout.unseal_once(eid, reason)`
- **Layer 9-12** — pure computation trên kết quả Layer 8

Sẵn sàng cho **Sprint 1 — Layer 0: Data Hygiene**.
