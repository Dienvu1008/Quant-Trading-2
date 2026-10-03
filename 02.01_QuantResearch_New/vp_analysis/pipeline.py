"""Pipeline orchestrator.

Runs the full L0 → L11 sequence for one experiment.

Public API:
    result = run_pipeline(
        merged_df,     # combined DataFrame (3-style)
        contract,      # frozen ResearchContract
        manifest,      # ExperimentManifest
        lineage,       # ExperimentLineage
        config,        # PipelineConfig (or None for defaults)
        output_dir,    # root output dir
    )
"""
from __future__ import annotations

import datetime as dt
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import pandas as pd

from .core.experiment_manifest import (
    ExperimentLineage,
    ExperimentManifest,
    ExperimentResult,
    ExperimentStatus,
)
from .core.research_contract import ResearchContract
from .layers import (
    L0_hygiene,
    L1_boundary,
    L2_feature_engineering,
    L3_eda,
    L4_hard_gate_discovery,
    L5_soft_gate_discovery,
    L6_multiple_testing,
    L7_dev_optimization,
    L8_holdout_apply,
    L9_attribution,
    L10_bad_entry,
    L10a_bad_entry_discovery,
    L10a_bad_entry_discovery,
    L10a_bad_entry_discovery,
    L11_null_protocol,
)
from .pipeline_config import PipelineConfig


# ─── Result type ─────────────────────────────────────────────────

@dataclass
class PipelineResult:
    experiment_id: str
    completed: bool
    halted_at: Optional[str]
    halt_reason: Optional[str]

    l0: object = None
    l1: object = None
    l2: object = None
    l3: object = None
    l4: object = None
    l5: object = None
    l6: object = None
    l7: object = None
    l8: object = None
    l9: object = None
    l10: object = None
    l10a: object = None
    l10a: object = None
    l10a: object = None
    l11: object = None

    outcome: Optional[str] = None
    elapsed_sec: float = 0.0
    output_dir: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "experiment_id": self.experiment_id,
            "completed": self.completed,
            "halted_at": self.halted_at,
            "halt_reason": self.halt_reason,
            "outcome": self.outcome,
            "elapsed_sec": round(self.elapsed_sec, 2),
            "output_dir": self.output_dir,
        }


# ─── Public API ──────────────────────────────────────────────────

def run_pipeline(
    merged_df: pd.DataFrame,
    contract: ResearchContract,
    manifest: ExperimentManifest,
    lineage: ExperimentLineage,
    config: Optional[PipelineConfig] = None,
    output_dir: Optional[Path] = None,
) -> PipelineResult:
    """Execute the full analysis pipeline (L0 → L11)."""
    cfg = config or PipelineConfig()
    t0 = time.time()
    eid = manifest.experiment_id

    out_root = Path(output_dir) if output_dir else Path("output")
    exp_dir = out_root / "experiments" / eid
    exp_dir.mkdir(parents=True, exist_ok=True)

    result = PipelineResult(
        experiment_id=eid, completed=False,
        halted_at=None, halt_reason=None,
        output_dir=str(exp_dir),
    )

    # Register manifest if not already in lineage
    if not lineage.exists(eid):
        lineage.add(manifest)

    # ─── L0: Hygiene ────────────────────────────────────────────
    l0 = _safe_step("L0_hygiene", lambda: L0_hygiene.run(
        merged_df, config=cfg.hygiene,
        output_dir=exp_dir / "L0_hygiene",
    ), result, exp_dir)
    if l0 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l0 = l0

    if l0.should_halt and cfg.halt_on_L0_fail:
        result.halted_at = "L0_hygiene"
        result.halt_reason = l0.reason_for_halt
        try:
            manifest.invalidate(f"L0 halt: {l0.reason_for_halt}")
        except Exception:
            pass
        _save_summary(result, exp_dir)
        return _finalize(result, manifest, lineage, t0)

    # ─── L1: Boundary ───────────────────────────────────────────
    l1 = _safe_step("L1_boundary", lambda: L1_boundary.run(
        merged_df, contract,
        output_dir=exp_dir / "L1_boundary",
        criteria=cfg.feature_availability,
    ), result, exp_dir)
    if l1 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l1 = l1

    if l1.n_available < cfg.min_available_features and cfg.halt_on_insufficient_features:
        result.halted_at = "L1_boundary"
        result.halt_reason = (
            f"Only {l1.n_available} available features "
            f"(< {cfg.min_available_features})"
        )
        try:
            manifest.invalidate(result.halt_reason)
        except Exception:
            pass
        _save_summary(result, exp_dir)
        return _finalize(result, manifest, lineage, t0)

    # ─── L2: Feature engineering ────────────────────────────────
    l2 = _safe_step("L2_feature_engineering", lambda: L2_feature_engineering.run(
        l1, output_dir=exp_dir / "L2_feature_engineering",
    ), result, exp_dir)
    if l2 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l2 = l2

    dev_df = l2.boundary.dev.data

    # Keep original 3-style dev data for L10 canary labeling BEFORE any transform
    # L10 needs: all 3 trailStyles per signal + exitReason column intact
    dev_df_3style = dev_df  # reference to original — not copied (read-only in L10)

    # Prepare discovery DataFrame according to target_mode
    dev_df = _prepare_discovery_df(dev_df, cfg)

    # ─── L3: EDA ────────────────────────────────────────────────
    l3 = _safe_step("L3_eda", lambda: L3_eda.run(
        dev_df, contract,
        available_features=l1.available_features(),
        output_dir=exp_dir / "L3_eda",
        config=cfg.eda,
    ), result, exp_dir)
    if l3 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l3 = l3

    # ─── L_SHAP: SHAP Analysis (optional) ───────────────────────
    if cfg.run_shap and cfg.shap is not None:
        from .layers.L_shap import run_shap_layer
        _shap = _safe_step("L_shap", lambda: run_shap_layer(
            dev_df=dev_df,
            dev_df_3style=dev_df_3style,
            contract=contract,
            available_features=list(l1.available_features()),
            config=cfg.shap,
            output_dir=exp_dir / "L_shap",
        ), result, exp_dir)
        # shap result is informational — never halts pipeline

    # ─── L4: Hard gate discovery ────────────────────────────────
    l4 = _safe_step("L4_hard_gate_discovery", lambda: L4_hard_gate_discovery.run(
        dev_df, contract,
        available_features=l1.available_features(),
        output_dir=exp_dir / "L4_hard_gates",
        config=cfg.hard_gate,
    ), result, exp_dir)
    if l4 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l4 = l4

    # ─── L5: Soft gate discovery ────────────────────────────────
    if cfg.run_soft_gates:
        l5 = _safe_step("L5_soft_gate_discovery", lambda: L5_soft_gate_discovery.run(
            dev_df, contract,
            available_features=l1.available_features(),
            output_dir=exp_dir / "L5_soft_gates",
            config=cfg.soft_gate,
        ), result, exp_dir)
        if l5 is None:
            return _finalize(result, manifest, lineage, t0)
        result.l5 = l5
    else:
        result.l5 = _empty_l5()

    # ─── L6: Multiple testing + freeze ──────────────────────────
    l6 = _safe_step("L6_multiple_testing", lambda: L6_multiple_testing.run(
        l4_result=l4,
        l5_result=result.l5,
        contract=contract,
        experiment_id=eid,
        output_dir=exp_dir / "L6_multiple_testing",
        config=cfg.multiple_testing,
    ), result, exp_dir)
    if l6 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l6 = l6

    # ─── L7: Dev optimization ───────────────────────────────────
    if cfg.run_dev_optimization and len(l6.frozen_rules) > 0:
        l7 = _safe_step("L7_dev_optimization", lambda: L7_dev_optimization.run(
            dev_df, list(l6.frozen_rules), contract,
            experiment_id=eid,
            output_dir=exp_dir / "L7_optimization",
            config=cfg.optimization,
        ), result, exp_dir)
        if l7 is None:
            return _finalize(result, manifest, lineage, t0)
        result.l7 = l7
    else:
        result.l7 = None

    # ─── L8: Holdout apply ──────────────────────────────────────
    if result.l7 is not None:
        production_config = result.l7.production_config
        l8 = _safe_step("L8_holdout_apply", lambda: L8_holdout_apply.run(
            sealed_holdout=l2.boundary.holdout,
            production_config=production_config,
            contract=contract,
            experiment_id=eid,
            output_dir=exp_dir / "L8_holdout",
            config=cfg.holdout,
        ), result, exp_dir)
        if l8 is None:
            return _finalize(result, manifest, lineage, t0)
        result.l8 = l8

    # ─── L9: Attribution ────────────────────────────────────────
    if cfg.run_attribution and result.l8 is not None:
        holdout_df = _peek_holdout(l2.boundary)
        if holdout_df is not None:
            l9 = _safe_step("L9_attribution", lambda: L9_attribution.run(
                holdout_df,
                result.l7.production_config,
                output_dir=exp_dir / "L9_attribution",
                config=cfg.attribution,
            ), result, exp_dir)
            if l9 is not None:
                result.l9 = l9

    # ─── L10: Bad entry ─────────────────────────────────────────
    if cfg.run_bad_entry:
        holdout_df_for_l10 = None
        if result.l8 is not None:
            holdout_df_for_l10 = _peek_holdout(l2.boundary)
        l10 = _safe_step("L10_bad_entry", lambda: L10_bad_entry.run(
            dev_df_3style, contract, experiment_id=eid,
            available_features=list(l1.available_features()),
            holdout_df=holdout_df_for_l10,
            output_dir=exp_dir / "L10_bad_entry",
            config=cfg.bad_entry,
        ), result, exp_dir)
        if l10 is not None:
            result.l10 = l10

    # ─── L10a: MFE-based bad entry discovery ────────────────────
    if cfg.run_bad_entry_discovery:
        l10a = _safe_step("L10a_bad_entry_discovery",
            lambda: L10a_bad_entry_discovery.run(
                dev_df_3style, contract,
                available_features=list(l1.available_features()),
                output_dir=exp_dir / "L10a_bad_entry",
                config=cfg.bad_entry_discovery,
            ), result, exp_dir)
        if l10a is not None:
            result.l10a = l10a

    # ─── L11: Null protocol ─────────────────────────────────────
    l11 = _safe_step("L11_null_protocol", lambda: L11_null_protocol.run(
        experiment_id=eid,
        l6_result=result.l6,
        l8_result=result.l8,
        output_dir=exp_dir / "L11_result",
    ), result, exp_dir)
    if l11 is not None:
        result.l11 = l11
        result.outcome = l11.outcome

    # ─── Complete ───────────────────────────────────────────────
    _complete_manifest(manifest, result, lineage)
    result.completed = True
    _save_summary(result, exp_dir)

    return _finalize(result, manifest, lineage, t0)


# ─── Helpers ─────────────────────────────────────────────────────

def _prepare_discovery_df(merged_df: pd.DataFrame, cfg: "PipelineConfig") -> pd.DataFrame:
    """Prepare the DataFrame for L4/L5 gate discovery.

    In 'production_profit' mode (default):
        Returns dev_df unchanged — _profit = profitUSD of production style.
        All 3 style rows are present but L4 treats each row independently.

    In 'all_styles_win' mode:
        1. Deduplicates by signalId (1 row per signal) to remove 3x inflation.
           Uses first occurrence per signal (features are identical across styles).
        2. Replaces _profit with _all_styles_win (binary: 1=all profitable, 0=not).
           This makes L4/L5 discover gates that predict genuine entry quality,
           independent of trailing style.
        3. Also replaces _profit with _all_styles_loss for a secondary run if needed.

    Returns the modified DataFrame ready for L1 → L4 → L5.
    """
    if cfg.target_mode == "production_profit":
        return merged_df

    if cfg.target_mode != "all_styles_win":
        import warnings as _warnings
        _warnings.warn(f"Unknown target_mode {cfg.target_mode!r}, using production_profit")
        return merged_df

    # ── all_styles_win mode ──────────────────────────────────────
    df = merged_df.copy()

    if "_all_styles_win" not in df.columns:
        print("  [WARN] _all_styles_win not in data — falling back to production_profit")
        return df

    # Dedup by signalId: keep 1 row per signal (features identical across styles)
    if "signalId" in df.columns:
        n_before = len(df)
        df = df.drop_duplicates(subset=["signalId"], keep="first").reset_index(drop=True)
        n_after = len(df)
        print(f"  [ALL_STYLES_WIN] Deduped {n_before} → {n_after} rows (1 per signal)")
    else:
        print("  [WARN] signalId not in data — dedup skipped (may inflate stats)")

    # Swap _profit → _all_styles_win (binary 0/1 target)
    df["_profit"] = df["_all_styles_win"].astype(float)

    base_rate = float(df["_profit"].mean())
    print(f"  [ALL_STYLES_WIN] target=_all_styles_win, base_rate={base_rate:.2%}, n={len(df)}")
    return df


def _safe_step(name: str, fn, result: PipelineResult, exp_dir: Path):
    """Execute one layer, capturing exceptions as halt."""
    try:
        return fn()
    except Exception as e:
        result.halted_at = name
        result.halt_reason = f"{type(e).__name__}: {e}"
        _save_summary(result, exp_dir)
        return None


def _finalize(
    result: PipelineResult,
    manifest: ExperimentManifest,
    lineage: ExperimentLineage,
    t0: float,
) -> PipelineResult:
    result.elapsed_sec = time.time() - t0
    try:
        if lineage.storage_path:
            lineage.save()
    except Exception:
        pass
    return result


def _complete_manifest(
    manifest: ExperimentManifest,
    result: PipelineResult,
    lineage: ExperimentLineage,
) -> None:
    if manifest.status != ExperimentStatus.ACTIVE:
        return
    outcome_map = {
        "SUCCESS": ExperimentResult.SUCCESS,
        "NULL_DEV": ExperimentResult.NULL_DEV,
        "NULL_HOLDOUT": ExperimentResult.NULL_HOLDOUT,
    }
    exp_result = outcome_map.get(result.outcome, ExperimentResult.SUCCESS)
    try:
        manifest.complete(exp_result)
    except Exception:
        pass


def _save_summary(result: PipelineResult, exp_dir: Path) -> None:
    try:
        with (exp_dir / "pipeline_summary.json").open("w", encoding="utf-8") as fh:
            json.dump(result.to_dict(), fh, indent=2, default=str)
    except Exception:
        pass


def _peek_holdout(boundary) -> Optional[pd.DataFrame]:
    """Return the holdout DataFrame only if already unsealed by L8."""
    holdout = boundary.holdout
    if holdout.is_sealed:
        return None
    return getattr(holdout, "_df", None)


def _empty_l5():
    """Stub L5 result when soft gates are disabled."""
    from .layers.L5_soft_gate_discovery import LayerFiveResult
    return LayerFiveResult(
        directions=(), candidates=(),
        n_features_evaluated=0, n_candidates=0,
        warnings=("soft gates disabled",),
        n_dev_rows=0,
        ran_at=dt.datetime.utcnow().isoformat() + "Z",
    )
