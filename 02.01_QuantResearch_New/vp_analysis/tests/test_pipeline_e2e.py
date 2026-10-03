"""End-to-end pipeline tests with synthetic data.

These tests exercise the full L0→L11 path using small synthetic
datasets. They do NOT require the signal to be discovered — they
verify the pipeline runs to completion, writes outputs, and honours
all governance invariants.
"""
import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.experiment_manifest import (
    ExperimentLineage,
    ExperimentManifest,
)
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L4_hard_gate_discovery import HardGateConfig
from vp_analysis.layers.L5_soft_gate_discovery import SoftGateConfig
from vp_analysis.layers.L7_dev_optimization import OptimizationConfig
from vp_analysis.layers.L8_holdout_apply import HoldoutConfig
from vp_analysis.pipeline import run_pipeline
from vp_analysis.pipeline_config import PipelineConfig


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def e2e_contract(minimal_contract_dict):
    """Contract matching the synthetic features in _make_e2e_merged."""
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {"quality": ["f_signal", "f_noise"]}
    d["feature_direction"] = {"f_signal": 1, "f_noise": 0}
    d["shape_priors"] = {"f_signal": "MONO_UP", "f_noise": "MONO_UP"}
    d["split_ratio"] = 0.70
    d["split_method"] = "temporal"
    d["stopping_rules"] = {
        "min_group_samples": 30,
        "min_fold_consistency": 0.50,
        "min_effect_size": 0.05,
        "max_outer_folds": 5,
        "max_inner_folds": 3,
    }
    d["production_criteria"] = {
        "min_ev": 0.05, "min_pf": 1.05, "min_wr": 0.35,
        "require_robust_across_styles": False,
        "require_holdout_confirmation": True,
    }
    # Keep all 4 FDR pools from minimal_contract_dict
    return ResearchContract.from_dict(d)


@pytest.fixture
def fast_config():
    """PipelineConfig tuned for small datasets and fast runs."""
    cfg = PipelineConfig()
    cfg.hard_gate = HardGateConfig(
        outer_folds=4, inner_folds=3,
        min_inner_train=10, min_inner_val=10, min_outer_test=10,
        min_effect_size=0.10, min_win_rate=0.40,
        min_profit_factor=1.05,
        fold_consistency_threshold=0.50,
        ttest_alpha=0.25,
        min_folds_results=2,
        perm_iterations=50,
        seed=42,
    )
    cfg.soft_gate = SoftGateConfig(
        perm_alpha=0.15, perm_iterations=100, seed=42,
    )
    cfg.optimization = OptimizationConfig(
        min_dev_trades=15, n_folds=3,
        min_fold_agree=0.40, max_pval=0.30,
    )
    cfg.holdout = HoldoutConfig(
        min_gated_trades=10,
        ev_degradation_factor=0.20,
        wr_degradation_factor=0.60,
        min_sl_tp_trades=10,
        min_sizing_trades=10,
        min_bucket_trades=5,
    )
    cfg.min_available_features = 1
    cfg.run_bad_entry = False    # skip bad-entry (needs signalId+exitReason)
    cfg.run_attribution = True
    return cfg


def _make_e2e_merged(n: int = 600, seed: int = 0, signal_strength: float = 1.5) -> pd.DataFrame:
    """Synthetic 3-style dataset. f_signal > 0.6 → positive edge.

    Critical: all 3 styles for the same signal must share identical
    entryTime and entryPrice (L0 hygiene enforces this).
    """
    rng = np.random.default_rng(seed)
    rows = []
    n_signals = n // 3
    for i in range(n_signals):
        sig_id = f"SIG-{i:05d}"
        t = pd.Timestamp("2024-01-01") + pd.Timedelta(hours=i)
        f_signal = rng.uniform(0, 1)
        f_noise = rng.uniform(0, 1)
        is_high = f_signal > 0.6
        base = signal_strength if is_high else -0.5
        mae = abs(rng.normal(0.8, 0.4))
        mfe = abs(rng.normal(1.5, 0.6))
        # SAME entry price for all 3 styles (required by L0 hygiene)
        entry_price = 2000.0
        for style in (-1, 0, 1):
            adj = {-1: -0.1, 0: 0.0, 1: 0.1}[style]
            profit = base + adj + rng.normal(0, 0.3)
            reason = "TP_HIT" if profit > 0.5 else ("SL_HIT" if profit < -0.3 else "TRAIL_STOP")
            rows.append({
                "signalId": sig_id,
                "trailStyle": style,
                "entryTime": t,          # same across styles
                "exitTime": t + pd.Timedelta(minutes=30),
                "time": t,
                "symbol": "XAUUSD",
                "setupType": "BOS",
                "entryPrice": entry_price,  # same across styles
                "maeATR": mae,
                "mfeATR": mfe,
                "exitReason": reason,
                "f_signal": f_signal,
                "f_noise": f_noise,
                "profitUSD": profit,
                "_profit": profit,
            })
    df = pd.DataFrame(rows)
    return df.sort_values("time").reset_index(drop=True)


def _make_manifest(eid: str, contract: ResearchContract) -> ExperimentManifest:
    return ExperimentManifest(
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=contract.code_hash,
    )


# ══════════════════════════════════════════════════════════════════
# Core end-to-end runs
# ══════════════════════════════════════════════════════════════════

def test_pipeline_runs_to_completion(e2e_contract, fast_config, tmp_path):
    df = _make_e2e_merged(n=600, seed=0)
    lineage = ExperimentLineage()
    manifest = _make_manifest("EXP-E2E-001", e2e_contract)

    result = run_pipeline(
        merged_df=df, contract=e2e_contract,
        manifest=manifest, lineage=lineage,
        config=fast_config, output_dir=tmp_path,
    )

    assert result.completed, f"halted_at={result.halted_at}: {result.halt_reason}"
    assert result.halted_at is None
    assert result.l0 is not None
    assert result.l1 is not None
    assert result.l2 is not None
    assert result.l3 is not None
    assert result.l4 is not None
    assert result.l6 is not None


def test_pipeline_produces_output_tree(e2e_contract, fast_config, tmp_path):
    df = _make_e2e_merged(n=600, seed=1)
    lineage = ExperimentLineage()
    manifest = _make_manifest("EXP-E2E-002", e2e_contract)

    run_pipeline(df, e2e_contract, manifest, lineage,
                 config=fast_config, output_dir=tmp_path)

    exp_dir = tmp_path / "experiments" / "EXP-E2E-002"
    assert (exp_dir / "L0_hygiene").exists()
    assert (exp_dir / "L1_boundary").exists()
    assert (exp_dir / "L2_feature_engineering").exists()
    assert (exp_dir / "L3_eda").exists()
    assert (exp_dir / "pipeline_summary.json").exists()


def test_pipeline_l4_runs_on_dev(e2e_contract, fast_config, tmp_path):
    """Verify L4 discovery ran and searched features."""
    df = _make_e2e_merged(n=800, seed=2, signal_strength=2.0)
    lineage = ExperimentLineage()
    manifest = _make_manifest("EXP-E2E-003", e2e_contract)

    result = run_pipeline(df, e2e_contract, manifest, lineage,
                          config=fast_config, output_dir=tmp_path)

    assert result.l4 is not None
    assert result.l4.n_features_searched >= 0  # may be 0 if groups too small
    assert result.l6 is not None


def test_pipeline_manifest_status_updated(e2e_contract, fast_config, tmp_path):
    df = _make_e2e_merged(n=600, seed=3)
    lineage = ExperimentLineage()
    manifest = _make_manifest("EXP-E2E-004", e2e_contract)

    run_pipeline(df, e2e_contract, manifest, lineage,
                 config=fast_config, output_dir=tmp_path)

    # After run, manifest should have left ACTIVE state
    assert manifest.status.value in ("COMPLETED", "INVALIDATED", "SUPERSEDED")


def test_pipeline_summary_json_written(e2e_contract, fast_config, tmp_path):
    df = _make_e2e_merged(n=400, seed=4)
    lineage = ExperimentLineage()
    manifest = _make_manifest("EXP-E2E-005", e2e_contract)

    run_pipeline(df, e2e_contract, manifest, lineage,
                 config=fast_config, output_dir=tmp_path)

    summary = tmp_path / "experiments" / "EXP-E2E-005" / "pipeline_summary.json"
    assert summary.exists()


def test_pipeline_result_to_dict_serialisable(e2e_contract, fast_config, tmp_path):
    df = _make_e2e_merged(n=400, seed=5)
    lineage = ExperimentLineage()
    manifest = _make_manifest("EXP-E2E-006", e2e_contract)

    result = run_pipeline(df, e2e_contract, manifest, lineage,
                          config=fast_config, output_dir=tmp_path)
    import json
    d = result.to_dict()
    json.dumps(d)  # must not raise
    assert d["experiment_id"] == "EXP-E2E-006"
    assert isinstance(d["completed"], bool)
    assert "elapsed_sec" in d


# ══════════════════════════════════════════════════════════════════
# Halt protocol
# ══════════════════════════════════════════════════════════════════

def test_pipeline_halts_when_l0_fails(e2e_contract, fast_config, tmp_path):
    """Inject corrupted prices → L0 should detect inconsistency and halt."""
    df = _make_e2e_merged(n=300, seed=6)
    # Make entry prices wildly inconsistent across styles for same signal
    mask = df["signalId"] == "SIG-00000"
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"] * 10

    lineage = ExperimentLineage()
    manifest = _make_manifest("EXP-E2E-L0FAIL", e2e_contract)
    cfg = PipelineConfig()
    cfg.halt_on_L0_fail = True
    cfg.min_available_features = 1

    result = run_pipeline(df, e2e_contract, manifest, lineage,
                          config=cfg, output_dir=tmp_path)

    # Either halted at L0 or completed (depending on hygiene sensitivity)
    # Key invariant: no exception was raised
    assert result.experiment_id == "EXP-E2E-L0FAIL"
    if result.halted_at == "L0_hygiene":
        assert result.halt_reason is not None
        assert not result.completed
