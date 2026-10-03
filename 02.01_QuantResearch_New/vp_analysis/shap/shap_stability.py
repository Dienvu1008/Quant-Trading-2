"""SHAP-H: Feature Stability Analysis.

Measures how stable SHAP feature rankings are across:
1. Temporal folds  — does importance rank change over time?
2. Symbols         — does importance rank differ across instruments?
3. Triggers        — does importance rank differ across setup types?
4. Random folds    — bootstrap stability (subsample sensitivity)

Low stability = SHAP importance is unreliable, hypothesis should be
downweighted or treated with extra caution.

Output: Spearman rank correlation heatmap + stability_summary.csv
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd
from scipy import stats


def _spearman_rank_corr(imp_a: pd.Series, imp_b: pd.Series) -> float:
    """Spearman rank correlation between two importance Series (same index)."""
    shared = imp_a.index.intersection(imp_b.index)
    if len(shared) < 3:
        return float("nan")
    a = imp_a.reindex(shared).fillna(0)
    b = imp_b.reindex(shared).fillna(0)
    r, _ = stats.spearmanr(a.values, b.values)
    return float(r) if not np.isnan(r) else float("nan")


def _mean_abs_shap_per_feature(sv: np.ndarray, feature_names: list) -> pd.Series:
    return pd.Series(np.abs(sv).mean(axis=0), index=feature_names)


def run_shap_h(
    explanation,         # SHAPExplanation (global)
    dataset,             # SHAPDataset
    shap_model,          # SHAPModel
    output_dir: Path,
    config=None,
) -> Optional[pd.DataFrame]:
    """Run SHAP-H: Stability analysis across multiple dimensions."""
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    feature_names = explanation.feature_names
    global_imp = _mean_abs_shap_per_feature(explanation.shap_values, feature_names)

    all_stability: Dict[str, pd.Series] = {}  # feature → stability scores

    # 1. Temporal stability
    temp_corrs = _temporal_stability(explanation, dataset, shap_model, cfg, output_dir)
    if temp_corrs is not None:
        all_stability["temporal"] = temp_corrs

    # 2. Symbol stability
    sym_corrs = _symbol_stability(explanation, dataset, shap_model, cfg, output_dir)
    if sym_corrs is not None:
        all_stability["symbol"] = sym_corrs

    # 3. Trigger stability
    trig_corrs = _trigger_stability(explanation, dataset, shap_model, cfg, output_dir)
    if trig_corrs is not None:
        all_stability["trigger"] = trig_corrs

    # 4. Bootstrap / fold stability
    boot_corrs = _fold_stability(explanation, dataset, shap_model, cfg, output_dir)
    if boot_corrs is not None:
        all_stability["fold"] = boot_corrs

    if not all_stability:
        print("  [SHAP-H] No stability dimensions could be computed")
        return None

    # Build summary table: feature × stability_dimension
    summary_df = pd.DataFrame(all_stability)
    summary_df.index.name = "feature"
    summary_df["mean_stability"] = summary_df.mean(axis=1, skipna=True)
    summary_df = summary_df.sort_values("mean_stability", ascending=False)
    summary_df.reset_index(inplace=True)
    summary_df.to_csv(output_dir / "stability_summary.csv", index=False)

    if cfg.output_plots:
        _plot_stability(summary_df, output_dir, cfg)

    mean_stab = float(summary_df["mean_stability"].mean())
    print(f"  [SHAP-H] Stability: {len(all_stability)} dimensions, "
          f"mean stability = {mean_stab:.3f}")
    return summary_df


def _recompute_shap_on_subset(
    shap_model, X_sub: pd.DataFrame, feature_names: list, cfg
) -> Optional[np.ndarray]:
    """Recompute SHAP values for a subset using the global model."""
    if len(X_sub) < 5:
        return None
    try:
        import shap
        X_arr = X_sub[feature_names].values.astype(np.float32)
        explainer = shap.TreeExplainer(shap_model.model)
        raw = explainer.shap_values(X_arr)
        if isinstance(raw, list):
            sv = raw[1] if len(raw) == 2 else raw[0]
        else:
            sv = raw
        return np.array(sv, dtype=np.float32)
    except Exception:
        return None


def _temporal_stability(explanation, dataset, shap_model, cfg, output_dir: Path):
    """Temporal fold stability."""
    X = dataset.X
    feature_names = explanation.feature_names
    n = len(X)
    n_folds = cfg.stability_n_folds

    if n < n_folds * 20:
        return None

    fold_size = n // n_folds
    fold_imps = []
    for i in range(n_folds):
        start = i * fold_size
        end = start + fold_size
        sv = _recompute_shap_on_subset(shap_model, X.iloc[start:end], feature_names, cfg)
        if sv is None:
            continue
        fold_imps.append(_mean_abs_shap_per_feature(sv, feature_names))

    if len(fold_imps) < 2:
        return None

    global_imp = _mean_abs_shap_per_feature(explanation.shap_values, feature_names)
    per_feature_corrs = {}
    for feat in feature_names:
        vals = [float(imp.get(feat, 0.0)) for imp in fold_imps]
        # Stability = rank correlation of importance across folds vs global
        corrs = [_spearman_rank_corr(
            pd.Series({f: float(imp.get(f, 0)) for f in feature_names}),
            global_imp
        ) for imp in fold_imps]
        per_feature_corrs[feat] = float(np.nanmean(corrs))

    result = pd.Series(per_feature_corrs)
    result.to_csv(output_dir / "temporal_stability.csv")
    return result


def _symbol_stability(explanation, dataset, shap_model, cfg, output_dir: Path):
    """Symbol-level stability."""
    X = dataset.X
    feature_names = explanation.feature_names

    if "symbol" not in X.columns:
        return None
    symbols = X["symbol"].dropna().unique()
    if len(symbols) < 2:
        return None

    sym_imps = []
    for sym in symbols:
        sub = X[X["symbol"] == sym]
        sv = _recompute_shap_on_subset(shap_model, sub, feature_names, cfg)
        if sv is None:
            continue
        sym_imps.append(_mean_abs_shap_per_feature(sv, feature_names))

    if len(sym_imps) < 2:
        return None

    global_imp = _mean_abs_shap_per_feature(explanation.shap_values, feature_names)
    corrs = {feat: float(np.nanmean([
        _spearman_rank_corr(imp, global_imp) for imp in sym_imps
    ])) for feat in feature_names}

    result = pd.Series(corrs)
    result.to_csv(output_dir / "symbol_stability.csv")
    return result


def _trigger_stability(explanation, dataset, shap_model, cfg, output_dir: Path):
    """Trigger-level stability."""
    X = dataset.X
    feature_names = explanation.feature_names

    if "setupType" not in X.columns:
        return None
    triggers = X["setupType"].dropna().unique()
    if len(triggers) < 2:
        return None

    trig_imps = []
    for trig in triggers:
        sub = X[X["setupType"] == trig]
        if len(sub) < cfg.min_trigger_samples:
            continue
        sv = _recompute_shap_on_subset(shap_model, sub, feature_names, cfg)
        if sv is None:
            continue
        trig_imps.append(_mean_abs_shap_per_feature(sv, feature_names))

    if len(trig_imps) < 2:
        return None

    global_imp = _mean_abs_shap_per_feature(explanation.shap_values, feature_names)
    corrs = {feat: float(np.nanmean([
        _spearman_rank_corr(imp, global_imp) for imp in trig_imps
    ])) for feat in feature_names}

    result = pd.Series(corrs)
    result.to_csv(output_dir / "trigger_stability.csv")
    return result


def _fold_stability(explanation, dataset, shap_model, cfg, output_dir: Path):
    """Bootstrap fold stability (5 x 80% subsamples)."""
    X = dataset.X
    feature_names = explanation.feature_names
    n = len(X)

    if n < 40:
        return None

    rng = np.random.default_rng(cfg.seed)
    n_boot = 5
    sub_size = int(n * 0.8)

    boot_imps = []
    for _ in range(n_boot):
        idx = rng.choice(n, size=sub_size, replace=False)
        sv = _recompute_shap_on_subset(shap_model, X.iloc[idx], feature_names, cfg)
        if sv is None:
            continue
        boot_imps.append(_mean_abs_shap_per_feature(sv, feature_names))

    if len(boot_imps) < 2:
        return None

    global_imp = _mean_abs_shap_per_feature(explanation.shap_values, feature_names)
    corrs = {feat: float(np.nanmean([
        _spearman_rank_corr(imp, global_imp) for imp in boot_imps
    ])) for feat in feature_names}

    result = pd.Series(corrs)
    result.to_csv(output_dir / "fold_stability.csv")
    return result


def _plot_stability(summary_df: pd.DataFrame, output_dir: Path, cfg) -> None:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        import matplotlib.colors as mcolors
    except ImportError:
        return

    top = summary_df.head(20)
    dim_cols = [c for c in top.columns if c not in ("feature", "mean_stability")]
    if not dim_cols:
        return

    data = top[dim_cols].values
    fig, ax = plt.subplots(figsize=(max(6, len(dim_cols) * 1.5), max(5, len(top) * 0.4)))
    im = ax.imshow(data, aspect="auto", cmap="RdYlGn", vmin=-1, vmax=1)
    ax.set_yticks(range(len(top)))
    ax.set_yticklabels(top["feature"].tolist())
    ax.set_xticks(range(len(dim_cols)))
    ax.set_xticklabels(dim_cols, rotation=30)
    ax.set_title("SHAP-H: Feature Stability (Spearman r vs global)")
    plt.colorbar(im, ax=ax)
    plt.tight_layout()
    plt.savefig(
        output_dir / f"stability_heatmap.{cfg.plot_format}",
        dpi=cfg.plot_dpi, bbox_inches="tight"
    )
    plt.close(fig)


def build_stability_hypotheses(
    stability_df: Optional[pd.DataFrame],
    experiment_id: str,
    high_stability_threshold: float = 0.6,
) -> List[Dict]:
    """Generate stability-aware annotations for existing hypotheses."""
    if stability_df is None or stability_df.empty:
        return []

    hypotheses = []
    for _, row in stability_df.iterrows():
        mean_stab = float(row.get("mean_stability", 0.0))
        if mean_stab >= high_stability_threshold:
            hyp = {
                "source": "SHAP-H",
                "feature": row["feature"],
                "category": "unknown",
                "hypothesis_type": "stability_confirmed",
                "suggested_direction": 0,
                "suggested_shape": "MONO_UP",
                "evidence_strength": mean_stab,
                "n_samples": None,
                "description": (
                    f"Feature '{row['feature']}' has high SHAP stability "
                    f"(mean_stability={mean_stab:.3f} across time/symbol/trigger/fold). "
                    "Hypothesis from other SHAP analyses is more reliable."
                ),
                "metadata": {"mean_stability": mean_stab},
            }
            hypotheses.append(hyp)
    return hypotheses
