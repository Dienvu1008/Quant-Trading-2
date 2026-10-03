"""Shared test fixtures for Sprint 0."""
import sys
from pathlib import Path

import pytest

# Make vp_analysis importable from anywhere
_ROOT = Path(__file__).parent.parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


@pytest.fixture
def minimal_contract_dict():
    """A minimal valid contract for unit tests.

    Uses stub features (f1/f2/f3) and stub hashes.
    v3: includes 4 FDR pools (hard_gate, soft_gate, regime_block, bad_entry),
    2 targets (edge_discovery_target, bad_entry_canary_target), and
    SL/TP tiebreaker in optimization_budget.
    """
    return {
        "version": "v1",
        "observation_unit": "1 trade (production_style filtered) per signal",
        "style_filter": "production_style=1",
        "pre_registered": {"quality": ["f1", "f2"], "trend": ["f3"]},
        "feature_direction": {"f1": 1, "f2": -1, "f3": 0},
        "shape_priors": {"f1": "MONO_UP", "f2": "MONO_DOWN", "f3": "BAND"},
        "allowed_interactions": ["ix_a"],
        "gate_types": ["threshold", "band"],
        "allowed_directions": [1, -1, 0],
        "primary_test": "one-sided t-test",
        "screening_test": "permutation",
        "multiple_testing_method": "benjamini-hochberg",
        # v3: 4 isolated FDR pools
        "fdr_pools": {
            "hard_gate": {
                "name": "hard_gate", "max_hypotheses": 500, "alpha": 0.05,
            },
            "soft_gate": {
                "name": "soft_gate", "max_hypotheses": 200, "alpha": 0.05,
            },
            "regime_block": {
                "name": "regime_block", "max_hypotheses": 200, "alpha": 0.05,
            },
            "bad_entry": {
                "name": "bad_entry", "max_hypotheses": 200, "alpha": 0.05,
            },
        },
        # v3: 2 targets
        "edge_discovery_target": {
            "name": "profitUSD",
            "definition": "profitUSD of production-style trade",
            "used_by": ["L4", "L4b", "L5", "L7"],
        },
        "bad_entry_canary_target": {
            "name": "MFE-based entry quality",
            "definition": "MFE_max_across_3_styles >= 1.0 ATR",
            "used_by": ["L10a"],
        },
        # v3: tiebreaker in optimization_budget
        "optimization_budget": {
            "sl_candidates": [1.0, 1.5, 2.0],
            "tp_candidates": [1.0, 1.5, 2.0],
            "sizing_configs": 5,
            "utility_function": "expectancy",
            "tiebreaker": ["sl_atr DESC", "tp_atr DESC"],
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
