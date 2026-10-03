"""shap_grouped.py — Per-(symbol, setup) SHAP analysis.

Instead of training one global model on all symbols and setups combined
(which averages out group-specific effects), this module:

1. Groups dev_df by (symbol, setupType)
2. For each group with enough signals: train model + compute SHAP
3. Aggregates cross-group summaries
4. Identifies group-specific vs universal feature importance
"""
from __future__ import annotations

import json
import time
import traceback
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd


@dataclass
class GroupSHAPResult:
    symbol: str
    setup: str
    group_key: str
    n_signals: int
    completed: bool
    null_reason: Optional[str]
    importance_df: Optional[pd.DataFrame] = None
    dependence_df: Optional[pd.DataFrame] = None
    local_df: Optional[pd.DataFrame] = None
    execution_df: Optional[pd.DataFrame] = None
    stability_df: Optional[pd.DataFrame] = None
    elapsed_sec: float = 0.0
    warnings: List[str] = field(default_factory=list)


@dataclass
class GroupedSHAPResult:
    experiment_id: str
    n_groups_total: int
    n_groups_completed: int
    n_groups_skipped: int
    group_results: List[GroupSHAPResult] = field(default_factory=list)
    cross_group_importance: Optional[pd.DataFrame] = None
    group_comparison_df: Optional[pd.DataFrame] = None
    universal_features: List[str] = field(default_factory=list)
    group_specific_features: List[str] = field(default_factory=list)
    n_hypotheses: int = 0
    elapsed_sec: float = 0.0
    warnings: List[str] = field(default_factory=list)


def run_grouped_shap(
    dev_df: pd.DataFrame,
    contract,
    available_features: List[str],
    config,
    output_dir: Path,
    experiment_id: str,
    registry=None,
) -> GroupedSHAPResult:
    """Run per-(symbol, setup) SHAP analysis."""
    from .shap_config import SHAPConfig
    from .shap_dataset import SHAPDatasetBuilder
    from .shap_model import fit_shap_model
    from .shap_explainer import compute_shap_values
    from .shap_global import run_shap_a, build_global_hypotheses
    from .shap_dependence import run_shap_b, build_dependence_hypotheses
    from .shap_local import run_shap_f, build_local_hypotheses
    from .shap_execution import run_shap_g, build_execution_hypotheses
    from .shap_stability import run_shap_h, build_stability_hypotheses

    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    t0 = time.time()

    sym_col = "symbol" if "symbol" in dev_df.columns else None
    stp_col = "setupType" if "setupType" in dev_df.columns else None

    if sym_col is None or stp_col is None:
        msg = "symbol or setupType column not found — cannot run grouped SHAP"
        print(f"  [SHAP-grouped] WARN: {msg}")
        return GroupedSHAPResult(
            experiment_id=experiment_id,
            n_groups_total=0, n_groups_completed=0, n_groups_skipped=0,
            warnings=[msg], elapsed_sec=time.time() - t0,
        )

    groups = list(dev_df.groupby([sym_col, stp_col]))
    n_groups_total = len(groups)
    min_sig = getattr(cfg, "min_group_signals", 100)
    print(f"  [SHAP-grouped] {n_groups_total} groups found, min_signals={min_sig}")

    group_results: List[GroupSHAPResult] = []
    all_importance_dfs: Dict[str, pd.DataFrame] = {}
    n_skipped = 0
    n_completed = 0
    all_warns: List[str] = []
    all_hyps: List[dict] = []

    for (sym, stp), grp_df in groups:
        group_key = f"{sym}|{stp}"
        safe_name = f"{sym}_{stp}".replace("/", "_").replace(" ", "_")
        grp_dir = output_dir / safe_name
        grp_t0 = time.time()

        # Deduplicate by signalId
        if "signalId" in grp_df.columns:
            grp_df = grp_df.drop_duplicates(subset=["signalId"], keep="first")
        n_sig = len(grp_df)

        if n_sig < min_sig:
            group_results.append(GroupSHAPResult(
                symbol=str(sym), setup=str(stp), group_key=group_key,
                n_signals=n_sig, completed=False,
                null_reason=f"Too few signals: {n_sig} < {min_sig}",
            ))
            n_skipped += 1
            continue

        grp_dir.mkdir(parents=True, exist_ok=True)
        print(f"  [SHAP-grouped] {group_key}: {n_sig} signals")

        try:
            builder = SHAPDatasetBuilder(
                dev_df=grp_df,
                contract=contract,
                available_features=available_features,
                config=cfg,
            )
            dataset = builder.build()

            if dataset.n_signals < getattr(cfg, "min_rows_total", 50):
                raise ValueError(f"Only {dataset.n_signals} rows after feature filtering")

            model = fit_shap_model(dataset, cfg)
            explanation = compute_shap_values(model, dataset.X, cfg)

            imp_df = None
            if cfg.run_shap_a:
                imp_df = run_shap_a(explanation, dataset, grp_dir / "shap_a", cfg)
                if imp_df is not None:
                    imp_df = imp_df.copy()
                    imp_df["group_key"] = group_key
                    imp_df["symbol"] = str(sym)
                    imp_df["setup"] = str(stp)
                    all_importance_dfs[group_key] = imp_df
                    hyps = build_global_hypotheses(imp_df, experiment_id=experiment_id, top_k=10)
                    for h in hyps:
                        h["n_samples"] = n_sig
                        h.setdefault("metadata", {}).update({"symbol": str(sym), "setup": str(stp), "group_key": group_key})
                    all_hyps.extend(hyps)

            dep_df = None
            if cfg.run_shap_b and imp_df is not None:
                dep_df = run_shap_b(explanation, dataset, imp_df, grp_dir / "shap_b", cfg)
                if dep_df is not None:
                    hyps_b = build_dependence_hypotheses(dep_df, experiment_id=experiment_id)
                    for h in hyps_b:
                        h.setdefault("metadata", {}).update({"symbol": str(sym), "setup": str(stp)})
                    all_hyps.extend(hyps_b)

            # SHAP-F: local explanations (winning/losing signals)
            local_df = None
            if cfg.run_shap_f:
                try:
                    local_df = run_shap_f(explanation, dataset, grp_dir / 'shap_f', cfg)
                    if local_df is not None:
                        hyps_f = build_local_hypotheses(local_df, experiment_id=experiment_id)
                        for h in hyps_f:
                            h.setdefault('metadata', {}).update({'symbol': str(sym), 'setup': str(stp)})
                        all_hyps.extend(hyps_f)
                except Exception as ef:
                    all_warns.append(f'{group_key} SHAP-F: {ef}')

            # SHAP-G: execution policy (3 trailing styles comparison)
            exec_df = None
            if cfg.run_shap_g:
                try:
                    exec_df = run_shap_g(dataset, contract, available_features, grp_dir / 'shap_g', cfg)
                    if exec_df is not None:
                        hyps_g = build_execution_hypotheses(exec_df, experiment_id=experiment_id)
                        for h in hyps_g:
                            h.setdefault('metadata', {}).update({'symbol': str(sym), 'setup': str(stp)})
                        all_hyps.extend(hyps_g)
                except Exception as eg:
                    all_warns.append(f'{group_key} SHAP-G: {eg}')

            # SHAP-H: feature stability analysis
            stab_df = None
            if cfg.run_shap_h:
                try:
                    stab_df = run_shap_h(explanation, dataset, model, grp_dir / 'shap_h', cfg)
                    if stab_df is not None:
                        hyps_h = build_stability_hypotheses(stab_df, experiment_id=experiment_id)
                        for h in hyps_h:
                            h.setdefault('metadata', {}).update({'symbol': str(sym), 'setup': str(stp)})
                        all_hyps.extend(hyps_h)
                except Exception as eh:
                    all_warns.append(f'{group_key} SHAP-H: {eh}')

            elapsed = time.time() - grp_t0
            group_results.append(GroupSHAPResult(
                symbol=str(sym), setup=str(stp), group_key=group_key,
                n_signals=n_sig, completed=True, null_reason=None,
                importance_df=imp_df, dependence_df=dep_df,
                local_df=local_df, execution_df=exec_df, stability_df=stab_df,
                elapsed_sec=elapsed, warnings=dataset.warnings,
            ))
            n_completed += 1
            print(f"  [SHAP-grouped] {group_key}: done ({elapsed:.1f}s)")

        except Exception as e:
            msg = f"{group_key}: {type(e).__name__}: {e}"
            all_warns.append(msg)
            print(f"  [SHAP-grouped] ERROR {msg}")
            group_results.append(GroupSHAPResult(
                symbol=str(sym), setup=str(stp), group_key=group_key,
                n_signals=n_sig, completed=False, null_reason=msg,
                warnings=[msg], elapsed_sec=time.time() - grp_t0,
            ))
            n_skipped += 1

    print(f"  [SHAP-grouped] Completed: {n_completed}/{n_groups_total} groups")

    cross_df = None
    comparison_df = None
    universal_features: List[str] = []
    group_specific_features: List[str] = []

    if all_importance_dfs:
        cross_df, comparison_df, universal_features, group_specific_features = \
            _aggregate_cross_group(all_importance_dfs, output_dir)

    if registry is not None and all_hyps:
        registry.register_many(all_hyps)

    summary = {
        "experiment_id": experiment_id,
        "n_groups_total": n_groups_total,
        "n_groups_completed": n_completed,
        "n_groups_skipped": n_skipped,
        "n_hypotheses": len(all_hyps),
        "universal_features": universal_features[:20],
        "group_specific_features": group_specific_features[:20],
        "warnings": all_warns,
        "elapsed_sec": round(time.time() - t0, 2),
    }
    with (output_dir / "grouped_summary.json").open("w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=2, default=str)

    return GroupedSHAPResult(
        experiment_id=experiment_id,
        n_groups_total=n_groups_total,
        n_groups_completed=n_completed,
        n_groups_skipped=n_skipped,
        group_results=group_results,
        cross_group_importance=cross_df,
        group_comparison_df=comparison_df,
        universal_features=universal_features,
        group_specific_features=group_specific_features,
        n_hypotheses=len(all_hyps),
        elapsed_sec=time.time() - t0,
        warnings=all_warns,
    )


def _aggregate_cross_group(
    importance_dfs: Dict[str, pd.DataFrame],
    output_dir: Path,
) -> Tuple[pd.DataFrame, pd.DataFrame, List[str], List[str]]:
    stacked = pd.concat(list(importance_dfs.values()), ignore_index=True)

    cross_df = (
        stacked.groupby("feature")["mean_abs_shap"]
        .agg(["mean", "std", "count"])
        .rename(columns={"mean": "mean_abs_shap_across_groups",
                         "std": "std_across_groups",
                         "count": "n_groups_present"})
        .reset_index()
    )
    cross_df["cv"] = (cross_df["std_across_groups"] /
                      cross_df["mean_abs_shap_across_groups"].clip(lower=1e-8))
    cross_df = cross_df.sort_values("mean_abs_shap_across_groups", ascending=False)
    cross_df["rank"] = range(1, len(cross_df) + 1)
    cross_df.to_csv(output_dir / "cross_group_importance.csv", index=False)

    pivot = stacked.pivot_table(
        index="feature", columns="group_key", values="mean_abs_shap", aggfunc="first"
    ).reset_index()
    pivot.to_csv(output_dir / "group_comparison_wide.csv", index=False)

    universal = cross_df[cross_df["cv"] < 0.5]["feature"].tolist()[:20]
    group_specific = cross_df[
        (cross_df["cv"] > 1.0) & (cross_df["n_groups_present"] >= 3)
    ]["feature"].tolist()[:20]

    print(f"  [SHAP-grouped] Universal: {len(universal)}, Group-specific: {len(group_specific)}")
    return cross_df, pivot, universal, group_specific
