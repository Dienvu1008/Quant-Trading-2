"""Layer 11 — Null Result Protocol.

Pure logic layer: classifies an experiment's outcome into one of:
  - SUCCESS:      >= 1 rule confirmed on holdout
  - NULL_DEV:     0 validated rules after L6
  - NULL_HOLDOUT: 0 rules confirmed on holdout (but >=1 validated)

No data access. Consumes L6 + L8 results.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Optional


class ExperimentOutcome(str, Enum):
    SUCCESS = "SUCCESS"
    NULL_DEV = "NULL_DEV"
    NULL_HOLDOUT = "NULL_HOLDOUT"
    INCONCLUSIVE = "INCONCLUSIVE"


@dataclass(frozen=True)
class LayerElevenResult:
    experiment_id: str
    outcome: str
    n_frozen_rules: int
    n_holdout_confirmed: int
    n_soft_gates: int
    allowed_actions: tuple
    forbidden_actions: tuple
    message: str
    ran_at: str

    def to_dict(self) -> dict:
        return {
            "experiment_id": self.experiment_id,
            "outcome": self.outcome,
            "n_frozen_rules": int(self.n_frozen_rules),
            "n_holdout_confirmed": int(self.n_holdout_confirmed),
            "n_soft_gates": int(self.n_soft_gates),
            "allowed_actions": list(self.allowed_actions),
            "forbidden_actions": list(self.forbidden_actions),
            "message": self.message,
            "ran_at": self.ran_at,
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    experiment_id: str,
    l6_result,
    l8_result=None,
    output_dir: Optional[Path] = None,
) -> LayerElevenResult:
    """Classify experiment outcome. No data access."""
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if not experiment_id:
        raise ValueError("L11: experiment_id is required")

    n_frozen = len(l6_result.frozen_rules) if l6_result else 0
    n_soft = len(l6_result.validated_soft_gates) if l6_result else 0

    # Dev null: nothing survived L6
    if n_frozen == 0 and n_soft == 0:
        result = _null_dev(experiment_id, n_frozen, n_soft, ran_at)
    elif n_frozen == 0 and n_soft > 0:
        # Only soft gates; no hard gate holdout needed
        result = LayerElevenResult(
            experiment_id=experiment_id,
            outcome=ExperimentOutcome.SUCCESS.value,
            n_frozen_rules=0,
            n_holdout_confirmed=0,
            n_soft_gates=n_soft,
            allowed_actions=(
                "deploy_soft_gates_as_tilt",
                "collect_more_data_for_hard_gate_experiment",
            ),
            forbidden_actions=(
                "rerun_same_contract_on_same_dataset",
                "modify_shape_priors_after_seeing_result",
            ),
            message=(
                f"Only {n_soft} soft gate(s) survived; no hard gates to "
                "evaluate on holdout."
            ),
            ran_at=ran_at,
        )
    elif l8_result is None:
        # Hard gates frozen but holdout not evaluated yet
        result = LayerElevenResult(
            experiment_id=experiment_id,
            outcome=ExperimentOutcome.INCONCLUSIVE.value,
            n_frozen_rules=n_frozen,
            n_holdout_confirmed=0,
            n_soft_gates=n_soft,
            allowed_actions=("run_layer_8_to_evaluate_on_holdout",),
            forbidden_actions=(),
            message="Hard gates frozen but holdout not yet evaluated.",
            ran_at=ran_at,
        )
    else:
        n_confirmed = l8_result.n_rules_confirmed
        if n_confirmed == 0:
            result = _null_holdout(experiment_id, n_frozen, n_confirmed, n_soft, ran_at)
        else:
            result = _success(experiment_id, n_frozen, n_confirmed, n_soft, ran_at)

    if output_dir is not None:
        write_result(result, output_dir)

    return result


def write_result(result: LayerElevenResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / "experiment_result.json").open("w", encoding="utf-8") as fh:
        json.dump(result.to_dict(), fh, indent=2, default=str)


# ─── Outcome builders ────────────────────────────────────────────

def _success(
    experiment_id: str, n_frozen: int, n_confirmed: int,
    n_soft: int, ran_at: str,
) -> LayerElevenResult:
    return LayerElevenResult(
        experiment_id=experiment_id,
        outcome=ExperimentOutcome.SUCCESS.value,
        n_frozen_rules=n_frozen,
        n_holdout_confirmed=n_confirmed,
        n_soft_gates=n_soft,
        allowed_actions=(
            "deploy_confirmed_rules_to_production",
            "start_new_experiment_on_new_dataset",
        ),
        forbidden_actions=(
            "rerun_same_contract_on_same_dataset",
            "modify_rules_after_seeing_holdout",
            "modify_sl_tp_after_seeing_holdout",
            "modify_shape_priors_after_seeing_result",
            "add_features_after_seeing_holdout",
        ),
        message=f"SUCCESS: {n_confirmed}/{n_frozen} rules confirmed on holdout.",
        ran_at=ran_at,
    )


def _null_dev(
    experiment_id: str, n_frozen: int, n_soft: int, ran_at: str,
) -> LayerElevenResult:
    return LayerElevenResult(
        experiment_id=experiment_id,
        outcome=ExperimentOutcome.NULL_DEV.value,
        n_frozen_rules=n_frozen,
        n_holdout_confirmed=0,
        n_soft_gates=n_soft,
        allowed_actions=(
            "archive_experiment_as_null",
            "collect_more_data",
            "design_new_experiment_with_new_contract",
        ),
        forbidden_actions=(
            "unseal_holdout",
            "rerun_same_contract_on_same_dataset",
            "tune_thresholds_after_seeing_null",
            "modify_shape_priors_after_seeing_null",
            "add_features_after_seeing_null",
        ),
        message="NULL_DEV: no rules survived FDR at L6. Holdout remains sealed.",
        ran_at=ran_at,
    )


def _null_holdout(
    experiment_id: str, n_frozen: int, n_confirmed: int,
    n_soft: int, ran_at: str,
) -> LayerElevenResult:
    return LayerElevenResult(
        experiment_id=experiment_id,
        outcome=ExperimentOutcome.NULL_HOLDOUT.value,
        n_frozen_rules=n_frozen,
        n_holdout_confirmed=n_confirmed,
        n_soft_gates=n_soft,
        allowed_actions=(
            "archive_experiment_as_null",
            "collect_more_data",
            "diagnose_degradation_in_layer_8_report",
            "design_new_experiment_with_new_contract",
        ),
        forbidden_actions=(
            "rerun_same_contract_on_same_dataset",
            "modify_rules_after_seeing_holdout",
            "modify_sl_tp_after_seeing_holdout",
            "modify_shape_priors_after_seeing_holdout",
            "add_features_after_seeing_holdout",
        ),
        message=(
            f"NULL_HOLDOUT: 0/{n_frozen} rules confirmed on holdout. "
            "Holdout remains consumed for this experiment."
        ),
        ran_at=ran_at,
    )
