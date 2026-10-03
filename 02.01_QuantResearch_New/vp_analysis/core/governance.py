"""Selection budget enforcement.

Prevents "meta-iteration" — running experiment after experiment until one
passes — which is a form of multiple testing at the process level.
"""
from __future__ import annotations

import datetime as dt

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
          - cooldown_hours_between_experiments (wall-clock UTC)
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
