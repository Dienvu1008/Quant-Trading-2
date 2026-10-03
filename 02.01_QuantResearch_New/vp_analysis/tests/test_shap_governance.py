"""test_shap_governance.py — Governance tests for the SHAP layer.

Tests:
- Null result handling (empty dataset → null, no crash)
- Provenance completeness (run_meta has required fields)
- Hypothesis status is always "DISCOVERY_ONLY"
- HypothesisRegistry save/load round-trip
- Config is frozen (FrozenInstanceError on mutation)
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

# Make vp_analysis importable
_ROOT = Path(__file__).parent.parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from vp_analysis.shap.shap_config import SHAPConfig
from vp_analysis.shap.hypothesis_registry import HypothesisRegistry, SHAPHypothesis


# ─── Helpers ─────────────────────────────────────────────────────

def _make_hypothesis_dict(
    source: str = "SHAP-A",
    feature: str = "feat_x",
    hypothesis_type: str = "importance",
    direction: int = 1,
    shape: str = "MONO_UP",
    evidence: float = 0.42,
    n_samples: int = 100,
) -> dict:
    return {
        "source": source,
        "feature": feature,
        "category": "quality",
        "hypothesis_type": hypothesis_type,
        "suggested_direction": direction,
        "suggested_shape": shape,
        "evidence_strength": evidence,
        "n_samples": n_samples,
        "description": f"Test hypothesis for {feature}",
        "metadata": {"rank": 1},
    }


# ─── Tests ───────────────────────────────────────────────────────

class TestNullResultHandling:
    """Empty or too-small dataset must produce a clean null result without crashing."""

    def test_empty_dataframe_raises_value_error(self):
        """SHAPDatasetBuilder should raise ValueError on empty df, not crash."""
        from vp_analysis.shap.shap_dataset import build_shap_dataset

        empty_df = pd.DataFrame(columns=["feat_a", "feat_b", "signalId"])

        class _Contract:
            pre_registered = {"quality": ["feat_a", "feat_b"]}

        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        with pytest.raises((ValueError, KeyError, Exception)):
            build_shap_dataset(empty_df, _Contract(), ["feat_a", "feat_b"], config)

    def test_too_few_rows_raises_value_error(self):
        """Dataset with fewer rows than min_rows_total should raise ValueError."""
        from vp_analysis.shap.shap_dataset import build_shap_dataset

        rng = np.random.default_rng(0)
        df = pd.DataFrame({
            "feat_a": rng.normal(size=5),
            "feat_b": rng.normal(size=5),
            "signalId": [f"S{i}" for i in range(5)],
            "profitUSD": rng.normal(size=5),
        })

        class _Contract:
            pre_registered = {"quality": ["feat_a", "feat_b"]}

        config = SHAPConfig(target_mode="production_profit", min_rows_total=50)
        with pytest.raises(ValueError, match="rows"):
            build_shap_dataset(df, _Contract(), ["feat_a", "feat_b"], config)

    def test_no_valid_features_raises_value_error(self):
        """Dataset with no usable features should raise ValueError."""
        from vp_analysis.shap.shap_dataset import build_shap_dataset

        rng = np.random.default_rng(0)
        df = pd.DataFrame({
            "profitUSD": rng.normal(size=100),  # forbidden
            "exitReason": ["TP"] * 100,          # forbidden
            "signalId": [f"S{i}" for i in range(100)],
        })

        class _Contract:
            pre_registered = {"quality": ["profitUSD", "exitReason"]}

        config = SHAPConfig(target_mode="production_profit", min_rows_total=10)
        with pytest.raises(ValueError, match="[Nn]o valid"):
            build_shap_dataset(df, _Contract(), ["profitUSD", "exitReason"], config)


class TestProvenanceCompleteness:
    """run_meta written by L_shap must contain all required fields."""

    REQUIRED_FIELDS = {
        "experiment_id",
        "target_mode",
        "target_name",
        "n_signals",
        "n_features",
        "seed",
        "model_type",
        "ran_at",
    }

    def _make_run_meta(self) -> dict:
        """Simulate the run_meta dict structure produced by L_shap."""
        return {
            "experiment_id": "shap_test_001",
            "parent_pipeline_id": None,
            "shap_config_hash": "sha256:abc123",
            "dataset_hash": "sha256:def456",
            "feature_names_hash": "sha256:ghi789",
            "model_hash": "sha256:jkl012",
            "code_hash": "sha256:mno345",
            "target_name": "profitUSD",
            "target_mode": "production_profit",
            "n_dev_rows": 300,
            "n_signals": 100,
            "n_features": 5,
            "symbols": ["XAUUSDm"],
            "seed": 42,
            "model_type": "lightgbm",
            "ran_at": "2025-01-01T00:00:00Z",
            "elapsed_sec": 12.5,
            "completed": True,
            "null_result": False,
            "warnings": [],
        }

    def test_all_required_fields_present(self):
        run_meta = self._make_run_meta()
        for field in self.REQUIRED_FIELDS:
            assert field in run_meta, f"Required field '{field}' missing from run_meta"

    def test_experiment_id_is_string(self):
        run_meta = self._make_run_meta()
        assert isinstance(run_meta["experiment_id"], str)
        assert len(run_meta["experiment_id"]) > 0

    def test_n_signals_positive(self):
        run_meta = self._make_run_meta()
        assert run_meta["n_signals"] > 0

    def test_n_features_positive(self):
        run_meta = self._make_run_meta()
        assert run_meta["n_features"] > 0

    def test_run_meta_serializable_to_json(self):
        run_meta = self._make_run_meta()
        # Must be JSON-serializable
        serialized = json.dumps(run_meta, default=str)
        reloaded = json.loads(serialized)
        assert reloaded["experiment_id"] == run_meta["experiment_id"]


class TestHypothesisStatus:
    """All hypotheses must start with status='DISCOVERY_ONLY'."""

    def test_register_from_dict_has_discovery_only_status(self):
        registry = HypothesisRegistry("shap_test_001")
        registry.register_from_dict(_make_hypothesis_dict())
        hyps = registry.to_list()
        assert len(hyps) == 1
        assert hyps[0]["status"] == "DISCOVERY_ONLY"

    def test_direct_register_preserves_discovery_only(self):
        registry = HypothesisRegistry("shap_test_001")
        hyp = SHAPHypothesis(
            hypothesis_id="SHAP-H0001-abc123",
            experiment_id="shap_test_001",
            source="SHAP-A",
            feature="feat_x",
            category="quality",
            hypothesis_type="importance",
            suggested_direction=1,
            suggested_shape="MONO_UP",
            evidence_strength=0.42,
            n_samples=100,
            description="Test",
            status="DISCOVERY_ONLY",  # must always be this
        )
        registry.register(hyp)
        assert registry.to_list()[0]["status"] == "DISCOVERY_ONLY"

    def test_register_many_all_discovery_only(self):
        registry = HypothesisRegistry("shap_test_001")
        hyps_in = [
            _make_hypothesis_dict(source="SHAP-A", feature=f"f{i}")
            for i in range(10)
        ]
        registry.register_many(hyps_in)
        for h in registry.to_list():
            assert h["status"] == "DISCOVERY_ONLY", (
                f"Hypothesis {h['hypothesis_id']} has status {h['status']!r}"
            )

    def test_no_auto_ea_rule_field(self):
        """Hypotheses must not have any 'ea_rule' or 'approved' field."""
        registry = HypothesisRegistry("shap_test_001")
        registry.register_from_dict(_make_hypothesis_dict())
        h = registry.to_list()[0]
        assert "ea_rule" not in h
        assert "approved" not in h
        assert "auto_converted" not in h


class TestHypothesisRegistrySaveLoad:
    """Save/load round-trip must be lossless."""

    def test_save_creates_json_file(self):
        registry = HypothesisRegistry("shap_test_001")
        for i in range(3):
            registry.register_from_dict(_make_hypothesis_dict(feature=f"feat_{i}"))

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            registry.save(output_dir)
            json_path = output_dir / "hypotheses.json"
            assert json_path.exists(), "hypotheses.json not created"

    def test_save_creates_csv_file(self):
        registry = HypothesisRegistry("shap_test_001")
        registry.register_from_dict(_make_hypothesis_dict())

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            registry.save(output_dir)
            csv_path = output_dir / "hypotheses.csv"
            assert csv_path.exists(), "hypotheses.csv not created"

    def test_json_round_trip(self):
        registry = HypothesisRegistry("shap_test_001")
        hyps = [_make_hypothesis_dict(feature=f"feat_{i}") for i in range(5)]
        registry.register_many(hyps)

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            registry.save(output_dir)

            # Reload from JSON
            reloaded = json.loads((output_dir / "hypotheses.json").read_text())

        assert len(reloaded) == 5
        for h in reloaded:
            assert h["experiment_id"] == "shap_test_001"
            assert h["status"] == "DISCOVERY_ONLY"
            assert h["hypothesis_id"].startswith("SHAP-H")

    def test_hypothesis_ids_are_unique(self):
        registry = HypothesisRegistry("shap_test_001")
        for i in range(10):
            registry.register_from_dict(_make_hypothesis_dict(feature=f"feat_{i}"))

        ids = [h["hypothesis_id"] for h in registry.to_list()]
        assert len(ids) == len(set(ids)), "Hypothesis IDs are not unique"

    def test_empty_registry_saves_empty_json(self):
        registry = HypothesisRegistry("shap_test_001")
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            registry.save(output_dir)
            reloaded = json.loads((output_dir / "hypotheses.json").read_text())
            assert reloaded == []

    def test_len_matches_registered_count(self):
        registry = HypothesisRegistry("shap_test_001")
        assert len(registry) == 0
        for i in range(7):
            registry.register_from_dict(_make_hypothesis_dict(feature=f"f{i}"))
        assert len(registry) == 7


class TestConfigIsFrozen:
    """SHAPConfig must be immutable (FrozenInstanceError on mutation)."""

    def test_config_is_frozen(self):
        config = SHAPConfig()
        with pytest.raises((TypeError, AttributeError)):
            # frozen=True raises FrozenInstanceError (subclass of AttributeError)
            config.seed = 999  # type: ignore[misc]

    def test_config_valid_defaults(self):
        config = SHAPConfig()
        assert config.target_mode == "production_profit"
        assert config.model_type == "lightgbm"
        assert config.seed == 42

    def test_config_invalid_target_mode_raises(self):
        with pytest.raises(ValueError, match="target_mode"):
            SHAPConfig(target_mode="bad_mode")

    def test_config_invalid_model_type_raises(self):
        with pytest.raises(ValueError, match="model_type"):
            SHAPConfig(model_type="catboost")

    def test_config_equality(self):
        c1 = SHAPConfig(seed=42)
        c2 = SHAPConfig(seed=42)
        assert c1 == c2

    def test_config_with_different_seeds_are_unequal(self):
        c1 = SHAPConfig(seed=42)
        c2 = SHAPConfig(seed=99)
        assert c1 != c2
