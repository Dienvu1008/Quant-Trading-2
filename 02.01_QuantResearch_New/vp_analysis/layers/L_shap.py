"""L_shap.py — SHAP Analysis pipeline layer.

Runs after L3 EDA on dev_df, before L4.
Produces SHAP-based feature hypotheses (DISCOVERY_ONLY — never auto-EA rules).

Rules:
- Only uses dev_df — NEVER touches holdout
- NEVER uses post-entry columns (profitUSD, MFE, MAE, exitReason, etc.)
  Those exclusions are enforced by SHAPDatasetBuilder / SHAP_FORBIDDEN_FEATURES
- Gracefully degrades if `shap` or model packages are not installed

Usage from pipeline:
    from .layers.L_shap import run_shap_layer
    _shap = run_shap_layer(
        dev_df=dev_df,
        dev_df_3style=dev_df_3style,
        contract=contract,
        available_features=list(l1.available_features()),
        config=cfg.shap,
        output_dir=exp_dir / "L_shap",
    )
"""
from __future__ import annotations

import datetime as dt
import json
import time
import traceback
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd


# ─── Result ──────────────────────────────────────────────────────

@dataclass
class LayerSHAPResult:
    """Result of the SHAP analysis layer."""
    experiment_id: str
    completed: bool
    null_result: bool
    null_reason: Optional[str]

    n_signals: int = 0
    n_features: int = 0
    n_hypotheses: int = 0

    # Per-analysis results (None if not run or failed)
    shap_a_df: Optional[pd.DataFrame] = None   # global importance
    shap_b_df: Optional[pd.DataFrame] = None   # dependence shapes
    shap_c_df: Optional[pd.DataFrame] = None   # interactions
    shap_d_df: Optional[pd.DataFrame] = None   # trigger-conditional
    shap_e_df: Optional[pd.DataFrame] = None   # regime-conditional
    shap_f_df: Optional[pd.DataFrame] = None   # local explanations
    shap_g_df: Optional[pd.DataFrame] = None   # execution policy
    shap_h_df: Optional[pd.DataFrame] = None   # stability

    warnings: List[str] = field(default_factory=list)
    output_dir: Optional[str] = None
    elapsed_sec: float = 0.0


# ─── Public entry point ──────────────────────────────────────────

def run_shap_layer(
    dev_df: pd.DataFrame,
    dev_df_3style: pd.DataFrame,
    contract,
    available_features: List[str],
    config,               # SHAPConfig
    output_dir: Path,
    experiment_id: Optional[str] = None,
    parent_pipeline_id: Optional[str] = None,
) -> LayerSHAPResult:
    """Run the full SHAP analysis layer.

    Parameters
    ----------
    dev_df            : development set (may be filtered by _prepare_discovery_df)
    dev_df_3style     : original 3-style dev data (for SHAP-G style comparison)
    contract          : ResearchContract
    available_features: list of pre-registered feature names
    config            : SHAPConfig
    output_dir        : where to write outputs
    experiment_id     : optional override; auto-generated if None
    parent_pipeline_id: optional parent experiment ID

    Returns
    -------
    LayerSHAPResult — always, even on failure (completed=False, null_result=True)
    """
    t0 = time.time()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Generate experiment ID if not provided
    if experiment_id is None:
        ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
        experiment_id = f"shap_{ts}"

    # ── Guard: shap package available? ──────────────────────────
    try:
        import shap as _shap_pkg  # noqa: F401
    except ImportError:
        msg = (
            "shap package not installed — SHAP layer skipped. "
            "Install with: pip install shap"
        )
        print(f"  [L_shap] WARN: {msg}")
        return LayerSHAPResult(
            experiment_id=experiment_id,
            completed=False,
            null_result=True,
            null_reason=msg,
            warnings=[msg],
            output_dir=str(output_dir),
            elapsed_sec=time.time() - t0,
        )

    # ── Guard: model package available? ─────────────────────────
    try:
        _check_model_package(config.model_type)
    except ImportError as e:
        msg = str(e)
        print(f"  [L_shap] WARN: {msg}")
        return LayerSHAPResult(
            experiment_id=experiment_id,
            completed=False,
            null_result=True,
            null_reason=msg,
            warnings=[msg],
            output_dir=str(output_dir),
            elapsed_sec=time.time() - t0,
        )

    # ── Build dataset ────────────────────────────────────────────
    # Pass dev_df_3style so SHAPDatasetBuilder has all 3 trailing styles
    # (needed for SHAP-G style comparison). The builder deduplicates by
    # signalId internally for signal-level analyses (SHAP-A through SHAP-H).
    try:
        from ..shap.shap_dataset import build_shap_dataset
        dataset = build_shap_dataset(
            dev_df=dev_df_3style,
            contract=contract,
            available_features=available_features,
            config=config,
        )
    except Exception as e:
        msg = f"SHAPDatasetBuilder failed: {e}"
        print(f"  [L_shap] ERROR: {msg}")
        _write_null_result(output_dir, experiment_id, msg)
        return LayerSHAPResult(
            experiment_id=experiment_id,
            completed=False,
            null_result=True,
            null_reason=msg,
            warnings=[msg],
            output_dir=str(output_dir),
            elapsed_sec=time.time() - t0,
        )

    # ── Minimum rows check ───────────────────────────────────────
    if dataset.n_signals < config.min_rows_total:
        msg = (
            f"Too few signals after deduplication: {dataset.n_signals} "
            f"< min_rows_total={config.min_rows_total}"
        )
        print(f"  [L_shap] NULL: {msg}")
        _write_null_result(output_dir, experiment_id, msg)
        return LayerSHAPResult(
            experiment_id=experiment_id,
            completed=True,
            null_result=True,
            null_reason=msg,
            n_signals=dataset.n_signals,
            n_features=dataset.n_features,
            warnings=dataset.warnings + [msg],
            output_dir=str(output_dir),
            elapsed_sec=time.time() - t0,
        )

    print(
        f"  [L_shap] Dataset ready: {dataset.n_signals} signals, "
        f"{dataset.n_features} features, target={dataset.target_name}"
    )

    # ── Fit model ────────────────────────────────────────────────
    try:
        from ..shap.shap_model import fit_shap_model
        shap_model = fit_shap_model(dataset, config)
    except Exception as e:
        msg = f"Model fitting failed: {e}"
        print(f"  [L_shap] ERROR: {msg}")
        _write_null_result(output_dir, experiment_id, msg)
        return LayerSHAPResult(
            experiment_id=experiment_id,
            completed=False,
            null_result=True,
            null_reason=msg,
            n_signals=dataset.n_signals,
            n_features=dataset.n_features,
            warnings=dataset.warnings + [msg],
            output_dir=str(output_dir),
            elapsed_sec=time.time() - t0,
        )

    # Save model
    try:
        shap_model.save(output_dir / "model")
    except Exception as e:
        print(f"  [L_shap] WARN: Could not save model: {e}")

    # ── Compute SHAP values ──────────────────────────────────────
    try:
        from ..shap.shap_explainer import compute_shap_values
        explanation = compute_shap_values(shap_model, dataset.X, config)
    except Exception as e:
        msg = f"SHAP computation failed: {e}"
        print(f"  [L_shap] ERROR: {msg}")
        _write_null_result(output_dir, experiment_id, msg)
        return LayerSHAPResult(
            experiment_id=experiment_id,
            completed=False,
            null_result=True,
            null_reason=msg,
            n_signals=dataset.n_signals,
            n_features=dataset.n_features,
            warnings=dataset.warnings + [msg],
            output_dir=str(output_dir),
            elapsed_sec=time.time() - t0,
        )

    # ── Build provenance ─────────────────────────────────────────
    run_meta = _build_run_meta(
        experiment_id=experiment_id,
        parent_pipeline_id=parent_pipeline_id,
        dataset=dataset,
        shap_model=shap_model,
        config=config,
        output_dir=output_dir,
    )

    # ── Run analyses ─────────────────────────────────────────────
    from ..shap.hypothesis_registry import HypothesisRegistry
    registry = HypothesisRegistry(experiment_id)
    result_kwargs: Dict[str, Any] = {}
    warnings_all: List[str] = list(dataset.warnings)

    # ── GROUPED mode: per-(symbol, setup) analysis ───────────────
    if getattr(config, "run_grouped", True):
        print(f"  [L_shap] Running per-(symbol, setup) grouped SHAP analysis")
        try:
            from ..shap.shap_grouped import run_grouped_shap
            grouped_result = run_grouped_shap(
                dev_df=dev_df_3style,       # use full 3-style data for grouping
                contract=contract,
                available_features=available_features,
                config=config,
                output_dir=output_dir / "grouped",
                experiment_id=experiment_id,
                registry=registry,
            )
            result_kwargs["shap_a_df"] = grouped_result.cross_group_importance
            warnings_all.extend(grouped_result.warnings)
            # Note: SHAP-F/G/H now run per-group inside shap_grouped.py

            # Null result if no groups completed
            if grouped_result.n_groups_completed == 0:
                msg = "All groups skipped (insufficient data or errors)"
                print(f"  [L_shap] NULL: {msg}")
                _write_null_result(output_dir, experiment_id, msg)
                return LayerSHAPResult(
                    experiment_id=experiment_id,
                    completed=True, null_result=True, null_reason=msg,
                    n_signals=dataset.n_signals, n_features=dataset.n_features,
                    warnings=warnings_all, output_dir=str(output_dir),
                    elapsed_sec=time.time() - t0,
                )

        except Exception as e:
            msg = f"Grouped SHAP failed: {e}\n{traceback.format_exc()}"
            warnings_all.append(msg[:500])
            print(f"  [L_shap] ERROR: {msg[:300]}")
            # Fall through to global analysis as fallback
            result_kwargs = {}
            _run_global_analyses(
                explanation, dataset, shap_model, config, output_dir,
                registry, warnings_all, result_kwargs, available_features, contract
            )
    else:
        # GLOBAL mode (original behavior)
        _run_global_analyses(
            explanation, dataset, shap_model, config, output_dir,
            registry, warnings_all, result_kwargs, available_features, contract
        )

    # ── Save hypotheses ──────────────────────────────────────────
    registry.save(output_dir)

    # ── Save run_meta ────────────────────────────────────────────
    elapsed = time.time() - t0
    run_meta_dict = dict(run_meta)
    run_meta_dict.update({
        "completed": True,
        "null_result": False,
        "warnings": warnings_all,
        "elapsed_sec": round(elapsed, 2),
        "n_hypotheses": len(registry),
    })
    with (output_dir / "run_meta.json").open("w", encoding="utf-8") as fh:
        json.dump(run_meta_dict, fh, indent=2, default=str)

    # ── Write report ─────────────────────────────────────────────
    try:
        from ..shap.shap_report import build_shap_summary
        build_shap_summary(
            experiment_id=experiment_id,
            output_dir=output_dir,
            run_meta=run_meta_dict,
            n_signals=dataset.n_signals,
            n_features=dataset.n_features,
        )
    except Exception as e:
        print(f"  [L_shap] WARN: Report generation failed: {e}")

    print(
        f"  [L_shap] Complete: {len(registry)} hypotheses, "
        f"{round(elapsed, 1)}s → {output_dir}"
    )

    return LayerSHAPResult(
        experiment_id=experiment_id,
        completed=True,
        null_result=False,
        null_reason=None,
        n_signals=dataset.n_signals,
        n_features=dataset.n_features,
        n_hypotheses=len(registry),
        warnings=warnings_all,
        output_dir=str(output_dir),
        elapsed_sec=elapsed,
        **result_kwargs,
    )


# ─── Per-analysis helpers ─────────────────────────────────────────

def _run_analysis_a(explanation, dataset, config, output_dir, registry, n_signals, warns):
    if not config.run_shap_a:
        return None
    try:
        from ..shap.shap_global import run_shap_a, build_global_hypotheses
        df = run_shap_a(explanation, dataset, output_dir / "shap_a", config)
        hyps = build_global_hypotheses(df, experiment_id="", top_k=15)
        for h in hyps:
            h["n_samples"] = n_signals
        registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-A failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_analysis_b(explanation, dataset, shap_a_df, config, output_dir, registry, warns):
    if not config.run_shap_b or shap_a_df is None:
        return None
    try:
        from ..shap.shap_dependence import run_shap_b, build_dependence_hypotheses
        df = run_shap_b(explanation, dataset, shap_a_df, output_dir / "shap_b", config)
        hyps = build_dependence_hypotheses(df, experiment_id="")
        registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-B failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_analysis_c(explanation, dataset, config, output_dir, registry, n_signals, warns):
    if not config.run_shap_c:
        return None
    try:
        from ..shap.shap_interaction import run_shap_c, build_interaction_hypotheses
        df = run_shap_c(explanation, dataset, output_dir / "shap_c", config)
        if df is not None:
            hyps = build_interaction_hypotheses(df, experiment_id="")
            for h in hyps:
                h["n_samples"] = n_signals
            registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-C failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_analysis_d(explanation, dataset, shap_model, shap_a_df, config, output_dir, registry, warns):
    if not config.run_shap_d or shap_a_df is None:
        return None
    try:
        from ..shap.shap_conditional import run_shap_d, build_conditional_hypotheses
        df = run_shap_d(explanation, dataset, shap_model, shap_a_df, output_dir / "shap_d", config)
        if df is not None:
            hyps = build_conditional_hypotheses(df, experiment_id="", analysis_type="trigger")
            registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-D failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_analysis_e(explanation, dataset, shap_model, shap_a_df, config, output_dir, registry, warns):
    if not config.run_shap_e or shap_a_df is None:
        return None
    try:
        from ..shap.shap_conditional import run_shap_e, build_conditional_hypotheses
        df = run_shap_e(explanation, dataset, shap_model, shap_a_df, output_dir / "shap_e", config)
        if df is not None:
            hyps = build_conditional_hypotheses(df, experiment_id="", analysis_type="regime")
            registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-E failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_analysis_f(explanation, dataset, config, output_dir, registry, warns):
    if not config.run_shap_f:
        return None
    try:
        from ..shap.shap_local import run_shap_f, build_local_hypotheses
        df = run_shap_f(explanation, dataset, output_dir / "shap_f", config)
        if df is not None:
            hyps = build_local_hypotheses(df, experiment_id="")
            registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-F failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_analysis_g(dataset, contract, available_features, config, output_dir, registry, warns):
    if not config.run_shap_g:
        return None
    try:
        from ..shap.shap_execution import run_shap_g, build_execution_hypotheses
        df = run_shap_g(dataset, contract, available_features, output_dir / "shap_g", config)
        if df is not None:
            hyps = build_execution_hypotheses(df, experiment_id="")
            registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-G failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_analysis_h(explanation, dataset, shap_model, config, output_dir, registry, warns):
    if not config.run_shap_h:
        return None
    try:
        from ..shap.shap_stability import run_shap_h, build_stability_hypotheses
        df = run_shap_h(explanation, dataset, shap_model, output_dir / "shap_h", config)
        if df is not None:
            hyps = build_stability_hypotheses(df, experiment_id="")
            registry.register_many(hyps)
        return df
    except Exception as e:
        msg = f"SHAP-H failed: {e}\n{traceback.format_exc()}"
        warns.append(msg)
        print(f"  [L_shap] WARN: {msg[:200]}")
        return None


def _run_global_analyses(
    explanation, dataset, shap_model, config, output_dir,
    registry, warnings_all, result_kwargs, available_features, contract
):
    """Run all SHAP analyses on the global (pooled) dataset."""
    shap_a_df = _run_analysis_a(explanation, dataset, config, output_dir, registry, dataset.n_signals, warnings_all)
    result_kwargs['shap_a_df'] = shap_a_df
    result_kwargs['shap_b_df'] = _run_analysis_b(explanation, dataset, shap_a_df, config, output_dir, registry, warnings_all)
    result_kwargs['shap_c_df'] = _run_analysis_c(explanation, dataset, config, output_dir, registry, dataset.n_signals, warnings_all)
    result_kwargs['shap_d_df'] = _run_analysis_d(explanation, dataset, shap_model, shap_a_df, config, output_dir, registry, warnings_all)
    result_kwargs['shap_e_df'] = _run_analysis_e(explanation, dataset, shap_model, shap_a_df, config, output_dir, registry, warnings_all)
    result_kwargs['shap_f_df'] = _run_analysis_f(explanation, dataset, config, output_dir, registry, warnings_all)
    result_kwargs['shap_g_df'] = _run_analysis_g(dataset, contract, available_features, config, output_dir, registry, warnings_all)
    result_kwargs['shap_h_df'] = _run_analysis_h(explanation, dataset, shap_model, config, output_dir, registry, warnings_all)


# ─── Utilities ────────────────────────────────────────────────────

def _check_model_package(model_type: str) -> None:
    """Raise ImportError if the requested model library is missing."""
    if model_type == "lightgbm":
        try:
            import lightgbm  # noqa: F401
        except ImportError:
            raise ImportError(
                "lightgbm not installed — SHAP layer skipped. "
                "Install with: pip install lightgbm"
            )
    elif model_type == "xgboost":
        try:
            import xgboost  # noqa: F401
        except ImportError:
            raise ImportError(
                "xgboost not installed — SHAP layer skipped. "
                "Install with: pip install xgboost"
            )


def _build_run_meta(
    experiment_id: str,
    parent_pipeline_id: Optional[str],
    dataset,
    shap_model,
    config,
    output_dir: Path,
) -> dict:
    """Build a run_meta dictionary (without full SHAPRunMeta to avoid circular deps)."""
    from ..shap.shap_provenance import (
        hash_config,
        hash_dataframe_sample,
        hash_feature_list,
        hash_model,
        hash_module_files,
    )
    from dataclasses import asdict

    try:
        config_dict = asdict(config)
    except Exception:
        config_dict = {}

    module_dir = Path(__file__).parent.parent / "shap"

    return {
        "experiment_id": experiment_id,
        "parent_pipeline_id": parent_pipeline_id,
        "shap_config_hash": hash_config(config_dict),
        "dataset_hash": hash_dataframe_sample(dataset.X),
        "feature_names_hash": hash_feature_list(dataset.feature_names),
        "model_hash": hash_model(shap_model.model),
        "code_hash": hash_module_files(module_dir),
        "target_name": dataset.target_name,
        "target_mode": dataset.target_mode,
        "n_dev_rows": dataset.n_rows_before_dedup,
        "n_signals": dataset.n_signals,
        "n_features": dataset.n_features,
        "symbols": list(
            dataset.meta.get("symbols", [])
        ),
        "seed": config.seed,
        "model_type": config.model_type,
        "ran_at": dt.datetime.utcnow().isoformat() + "Z",
        "elapsed_sec": 0.0,
        "completed": False,
        "null_result": False,
        "warnings": [],
    }


def _write_null_result(output_dir: Path, experiment_id: str, reason: str) -> None:
    """Write a minimal run_meta.json for null results."""
    meta = {
        "experiment_id": experiment_id,
        "completed": True,
        "null_result": True,
        "null_reason": reason,
        "ran_at": dt.datetime.utcnow().isoformat() + "Z",
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / "run_meta.json").open("w", encoding="utf-8") as fh:
        json.dump(meta, fh, indent=2)
