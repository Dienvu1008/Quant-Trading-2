"""Leak detection tests.

Verify that the pipeline's information boundary is structurally enforced:

  1. Holdout stays sealed when no rules survive L6
  2. InteractionTransformer is fit on dev only (not holdout)
  3. FDR pools are fully isolated
  4. L1 feature availability is computed from dev only
  5. Holdout cannot be unsealed twice for the same experiment
"""
import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.data_boundary import DataBoundary
from vp_analysis.core.exceptions import HoldoutAlreadyUnsealedError
from vp_analysis.core.experiment_manifest import (
    ExperimentLineage,
    ExperimentManifest,
)
from vp_analysis.core.fdr_registry import FDRPoolRegistry
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L1_boundary import run as l1_run
from vp_analysis.layers.L1_boundary import FeatureAvailabilityCriteria
from vp_analysis.layers.L2_feature_engineering import InteractionTransformer
from vp_analysis.pipeline import run_pipeline
from vp_analysis.pipeline_config import PipelineConfig


# ─── Helpers ─────────────────────────────────────────────────────

def _make_noise_df(n: int = 400, seed: int = 0) -> pd.DataFrame:
    """Pure noise — no discoverable signal.

    Uses consistent entryPrice per signalId to pass L0 hygiene.
    """
    rng = np.random.default_rng(seed)
    n_signals = n // 3
    rows = []
    for i in range(n_signals):
        sig_id = f"SIG-{i}"
        t = pd.Timestamp("2024-01-01") + pd.Timedelta(hours=i)
        entry_price = 2000.0  # same for all styles
        for style in (-1, 0, 1):
            rows.append({
                "time": t,
                "symbol": "XAUUSD",
                "setupType": "BOS",
                "entryTime": t,
                "exitTime": t + pd.Timedelta(minutes=30),
                "entryPrice": entry_price,
                "exitReason": "TRAIL_STOP",
                "signalId": sig_id,
                "trailStyle": style,
                "maeATR": abs(rng.normal(1, 0.5)),
                "mfeATR": abs(rng.normal(1.5, 0.5)),
                "f_a": rng.uniform(0, 1),
                "f_b": rng.uniform(0, 1),
                "profitUSD": rng.normal(0, 1),
                "_profit": rng.normal(0, 1),
            })
    df = pd.DataFrame(rows)
    return df.sort_values("time").reset_index(drop=True)


def _make_noise_contract(minimal_contract_dict: dict) -> ResearchContract:
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {"cat": ["f_a", "f_b"]}
    d["feature_direction"] = {"f_a": 1, "f_b": 1}
    d["shape_priors"] = {"f_a": "MONO_UP", "f_b": "MONO_UP"}
    d["split_ratio"] = 0.70
    return ResearchContract.from_dict(d)


# ══════════════════════════════════════════════════════════════════
# 1. Holdout stays sealed when no rules survive
# ══════════════════════════════════════════════════════════════════

def test_holdout_sealed_when_no_rules_survive(minimal_contract_dict, tmp_path):
    df = _make_noise_df(n=400, seed=0)
    contract = _make_noise_contract(minimal_contract_dict)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-LEAK-001",
        research_contract_hash=contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=contract.code_hash,
    )

    # Use strict config so noise produces 0 candidates
    from vp_analysis.layers.L4_hard_gate_discovery import HardGateConfig
    from vp_analysis.layers.L6_multiple_testing import MultipleTestingConfig
    cfg = PipelineConfig()
    cfg.hard_gate = HardGateConfig(
        min_effect_size=0.50, ttest_alpha=0.01,
        fold_consistency_threshold=0.80, min_folds_results=4,
    )
    cfg.multiple_testing = MultipleTestingConfig(conservative_fdr=True)
    cfg.min_available_features = 1
    cfg.run_bad_entry = False

    result = run_pipeline(df, contract, manifest, lineage,
                          config=cfg, output_dir=tmp_path)

    # When 0 frozen rules → L7 skipped → L8 skipped → holdout stays sealed
    if result.l2 is not None:
        l6_has_rules = result.l6 is not None and len(result.l6.frozen_rules) > 0
        if not l6_has_rules:
            # Holdout must still be sealed
            assert result.l2.boundary.holdout.is_sealed


# ══════════════════════════════════════════════════════════════════
# 2. InteractionTransformer fitted on dev only
# ══════════════════════════════════════════════════════════════════

def test_interaction_scaler_fits_dev_only():
    """Stats computed on dev (first 70 rows), not on holdout rows 70–100."""
    rng = np.random.default_rng(1)
    n = 100
    df = pd.DataFrame({
        "a": rng.uniform(0, 1, n),
        "b": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })
    dev = df.iloc[:70]

    transformer = InteractionTransformer((("ix_ab", "a", "b"),))
    transformer.fit(dev)

    s = transformer.stats[0]
    # a_max must equal dev's a_max (≤ full df's a_max)
    assert s.a_max == pytest.approx(dev["a"].max(), rel=1e-6)
    assert s.a_max <= df["a"].max() + 1e-9


def test_interaction_scaler_ignores_holdout_outlier():
    """Huge outlier in holdout rows must NOT affect stats."""
    rng = np.random.default_rng(2)
    n = 100
    a_vals = rng.uniform(0, 1, n)
    a_vals[95] = 1e6  # massive outlier in "holdout" slice

    df = pd.DataFrame({
        "a": a_vals,
        "b": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })
    dev = df.iloc[:70]  # outlier NOT in dev

    transformer = InteractionTransformer((("ix_ab", "a", "b"),))
    transformer.fit(dev)

    s = transformer.stats[0]
    assert s.a_max <= 1.0 + 1e-9, (
        f"Outlier leaked into fit: a_max={s.a_max}"
    )


# ══════════════════════════════════════════════════════════════════
# 3. Holdout cannot be unsealed twice (same experiment)
# ══════════════════════════════════════════════════════════════════

def test_holdout_cannot_be_unsealed_twice():
    """Kernel raises on second unseal for the same experiment_id."""
    rng = np.random.default_rng(3)
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=100, freq="h"),
        "a": rng.uniform(0, 1, 100),
        "profitUSD": rng.normal(0, 1, 100),
    })
    boundary = DataBoundary.from_merged(df)
    boundary.holdout.unseal_once("EXP-001", reason="test")

    with pytest.raises(HoldoutAlreadyUnsealedError):
        boundary.holdout.unseal_once("EXP-001", reason="second_attempt")


# ══════════════════════════════════════════════════════════════════
# 4. FDR pools are isolated
# ══════════════════════════════════════════════════════════════════

def test_fdr_pools_are_isolated(minimal_contract_dict):
    """Registering p=0.001 in pool_a and p=0.90 in pool_b must produce
    independent corrections — pool_a rejects, pool_b does not.

    Uses the existing hard_gate / soft_gate pools from minimal_contract_dict
    to avoid contract validation errors (all 4 pools required by v3).
    """
    d = dict(minimal_contract_dict)
    # hard_gate ← small p (should reject), soft_gate ← large p (should not)
    contract = ResearchContract.from_dict(d)
    fdr = FDRPoolRegistry(contract)

    fdr.register("hard_gate", "H1", 0.001)
    fdr.register("soft_gate", "H1", 0.900)

    ra = fdr.correct("hard_gate")
    rb = fdr.correct("soft_gate")

    assert ra.as_dict()["H1"]["reject"] is True
    assert rb.as_dict()["H1"]["reject"] is False


# ══════════════════════════════════════════════════════════════════
# 5. Feature availability uses dev only
# ══════════════════════════════════════════════════════════════════

def test_feature_availability_uses_dev_only(minimal_contract_dict):
    """Feature with zero variance in dev is marked unavailable,
    even if holdout rows have high variance."""
    n = 200
    # First 140 rows (dev): feature 'a' is constant.
    # Last 60 rows (holdout): feature 'a' varies wildly.
    a_vals = [0.5] * 140 + list(np.random.RandomState(0).normal(0, 5, 60))
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "a": a_vals,
        "profitUSD": np.zeros(n),
        "_profit": np.zeros(n),
    })

    d = dict(minimal_contract_dict)
    d["pre_registered"] = {"cat": ["a"]}
    d["feature_direction"] = {"a": 1}
    d["shape_priors"] = {"a": "MONO_UP"}
    d["split_ratio"] = 0.70
    contract = ResearchContract.from_dict(d)

    result = l1_run(df, contract)
    entries = {e.feature: e for e in result.feature_availability}

    assert "a" in entries
    assert entries["a"].available is False
    assert entries["a"].reason == "low_variance"


# ══════════════════════════════════════════════════════════════════
# 6. Pipeline doesn't crash on empty result (structural safety)
# ══════════════════════════════════════════════════════════════════

def test_pipeline_result_is_always_returned(minimal_contract_dict, tmp_path):
    """Even with noise data, run_pipeline always returns a PipelineResult."""
    df = _make_noise_df(n=300, seed=99)
    contract = _make_noise_contract(minimal_contract_dict)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-LEAK-STRUCT",
        research_contract_hash=contract.contract_hash,
        dataset_hash="sha256:" + "z" * 64,
        code_hash=contract.code_hash,
    )

    cfg = PipelineConfig()
    cfg.min_available_features = 1
    cfg.run_bad_entry = False

    result = run_pipeline(df, contract, manifest, lineage,
                          config=cfg, output_dir=tmp_path)

    # Must always return a PipelineResult without raising
    assert hasattr(result, "experiment_id")
    assert hasattr(result, "completed")
    assert hasattr(result, "elapsed_sec")
    assert result.elapsed_sec >= 0
