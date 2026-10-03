"""Research Contract — immutable definition of a research experiment.

v3 changes:
  - Two explicit targets: edge_discovery_target (profitUSD, L4/L5/L4b/L7)
    and bad_entry_canary_target (MFE-based, L10a only). No single
    target_definition; both are stored and hashed.
  - Four FDR pools: hard_gate, soft_gate, regime_block, bad_entry.
  - OptimizationBudget includes tiebreaker for SL/TP selection.
  - _validate() enforces that fdr_pools contains all required pool names.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Optional

import yaml

from .exceptions import ContractFrozenError, ContractValidationError
from .provenance import hash_dict

# The four pools required by v3 spec (must ALL be present in every contract).
REQUIRED_FDR_POOLS = frozenset({"hard_gate", "soft_gate", "regime_block", "bad_entry"})


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
    """Pre-registered parameter grid (NOT hypotheses — no FDR).

    tiebreaker: ordered list of sort keys for SL/TP selection when
    multiple combos share the same utility. Format: "<field> DESC|ASC".
    Default ["sl_atr DESC", "tp_atr DESC"] means: prefer larger SL,
    then larger TP, to avoid choosing an SL that is too tight due to noise.
    """
    sl_candidates: list
    tp_candidates: list
    sizing_configs: int
    utility_function: str
    tiebreaker: list = None  # set in __post_init__

    def __post_init__(self):
        if self.tiebreaker is None:
            self.tiebreaker = ["sl_atr DESC", "tp_atr DESC"]


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
        contract.freeze()
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
        # v3: two targets are part of the hash
        "edge_discovery_target",
        "bad_entry_canary_target",
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
        # v3: two targets (required)
        edge_discovery_target: dict,
        bad_entry_canary_target: dict,
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

        # v3: two targets
        self.edge_discovery_target = edge_discovery_target
        self.bad_entry_canary_target = bad_entry_canary_target

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
        # Identity hashes
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

        # v3: all four FDR pools must be present
        if not self.fdr_pools:
            raise ContractValidationError("fdr_pools cannot be empty")
        missing_pools = REQUIRED_FDR_POOLS - set(self.fdr_pools.keys())
        if missing_pools:
            raise ContractValidationError(
                f"fdr_pools is missing required pools: {sorted(missing_pools)}. "
                f"v3 requires all of: {sorted(REQUIRED_FDR_POOLS)}"
            )
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

        # v3: both targets must be dicts with required keys
        for target_attr, layer_hint in [
            ("edge_discovery_target", "L4/L4b/L5/L7"),
            ("bad_entry_canary_target", "L10a"),
        ]:
            t = getattr(self, target_attr)
            if not isinstance(t, dict):
                raise ContractValidationError(
                    f"{target_attr} must be a dict"
                )
            for required_key in ("name", "definition"):
                if required_key not in t:
                    raise ContractValidationError(
                        f"{target_attr} must have key {required_key!r}"
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
            "edge_discovery_target": self.edge_discovery_target,
            "bad_entry_canary_target": self.bad_entry_canary_target,
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
        opt_budget_raw = d.pop("optimization_budget")
        opt_budget = OptimizationBudget(**opt_budget_raw)
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
