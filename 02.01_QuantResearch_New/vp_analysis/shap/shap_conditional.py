"""SHAP-D and SHAP-E: Conditional SHAP Analysis.

SHAP-D: Trigger-conditional
    Slice dataset by setupType (EA trigger ID).
    For each trigger with sufficient samples, compute subset SHAP values.
    Compare importance profile vs global profile.
    Identify features that are trigger-specific vs universal.

SHAP-E: Regime-conditional
    Slice dataset by auctRegime (0-8).
    Same analysis as SHAP-D but for market regimes.
    Flag features that switch sign across regimes (interaction effect).
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from scipy import stats


# ─── Shared subset SHAP computation ─────────────────────────────

def _compute_subset_shap(
    shap_model,
    X_subset: pd.DataFrame,
    feature_names: List[str],
    config,
    background_X: Optional[pd.DataFrame] = None,
) -> Optional[np.ndarray]:
    """Compute SHAP values for a subset using the already-fitted model."""
    if len(X_subset) < 5:
        return None
    try:
        import shap
        X_arr = X_subset[feature_names].values.astype(np.float32)
        if background_X is not None:
            n_bg = min(config.shap_max_samples, len(background_X))
            rng = np.random.default_rng(config.seed)
            bg_idx = rng.choice(len(background_X), size=n_bg, replace=False)
            bg = background_X.iloc[bg_idx][feature_names].values.astype(np.float32)
            explainer = shap.TreeExplainer(shap_model.model, data=bg,
                                           feature_perturbation="interventional")
        else:
            explainer = shap.TreeExplainer(shap_model.model)

        raw = explainer.shap_values(X_arr)
        if isinstance(raw, list):
            sv = raw[1] if len(raw) == 2 else raw[0]
        else:
            sv = raw
        return np.array(sv, dtype=np.float32)
    except Exception as e:
        print(f"    [WARN] Subset SHAP failed: {e}")
        return None


def _importance_from_shap(sv: np.ndarray, feature_names: List[str]) -> pd.Series:
    """Mean |SHAP| per feature."""
    mean_abs = np.abs(sv).mean(axis=0)
    return pd.Series(mean_abs, index=feature_names)


def _rank_correlation_vs_global(
    subset_importance: pd.Series,
    global_df: pd.DataFrame,
) -> float:
    """Spearman rank correlation between subset and global importance."""
    global_imp = global_df.set_index("feature")["mean_abs_shap"].reindex(subset_importance.index).fillna(0)
    r, _ = stats.spearmanr(subset_importance.values, global_imp.values)
    return float(r) if not np.isnan(r) else 0.0


# ─── SHAP-D: Trigger-conditional ────────────────────────────────

def run_shap_d(
    explanation,              # SHAPExplanation from full dataset
    dataset,                  # SHAPDataset
    shap_model,               # SHAPModel (for recomputation per subset)
    global_importance_df: pd.DataFrame,
    output_dir: Path,
    config=None,
) -> Optional[pd.DataFrame]:
    """Run SHAP-D: Trigger-conditional SHAP.

    Returns: comparison DataFrame or None.
    """
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    X = dataset.X
    feature_names = dataset.feature_names

    # setupType column must be in original dev_df (not necessarily in X)
    # We reconstruct the signal_df with setupType for slicing
    # X index aligns with signal-level rows
    if "setupType" not in X.columns:
        print("  [SHAP-D] setupType column not in X — skipping trigger-conditional")
        return None

    triggers = sorted(X["setupType"].dropna().unique().tolist())
    if not triggers:
        print("  [SHAP-D] No setupType values found")
        return None

    comparison_rows = []
    for trigger in triggers:
        mask = X["setupType"] == trigger
        n = int(mask.sum())
        if n < cfg.min_trigger_samples:
            print(f"  [SHAP-D] Trigger {trigger}: {n} samples < {cfg.min_trigger_samples} min — skipped")
            continue

        X_sub = X[mask]
        feat_cols = [f for f in feature_names if f in X_sub.columns and f != "setupType"]
        sv = _compute_subset_shap(shap_model, X_sub[feat_cols], feat_cols, cfg, X[feat_cols])
        if sv is None:
            continue

        imp = _importance_from_shap(sv, feat_cols)
        rank_corr = _rank_correlation_vs_global(imp, global_importance_df[global_importance_df["feature"].isin(feat_cols)])

        # Save per-trigger CSV
        trigger_df = imp.reset_index()
        trigger_df.columns = ["feature", "mean_abs_shap"]
        trigger_df["rank"] = trigger_df["mean_abs_shap"].rank(ascending=False).astype(int)
        trigger_str = str(trigger).replace("/", "_").replace(" ", "_")
        trigger_df.to_csv(output_dir / f"{trigger_str}_importance.csv", index=False)

        comparison_rows.append({
            "trigger": trigger,
            "n_samples": n,
            "rank_corr_vs_global": round(rank_corr, 4),
            "top_feature": trigger_df.iloc[0]["feature"] if not trigger_df.empty else "",
            "top_shap": float(trigger_df.iloc[0]["mean_abs_shap"]) if not trigger_df.empty else 0.0,
        })

    if not comparison_rows:
        print("  [SHAP-D] No triggers met minimum sample requirement")
        return None

    comparison_df = pd.DataFrame(comparison_rows)
    comparison_df.to_csv(output_dir / "trigger_comparison.csv", index=False)
    print(f"  [SHAP-D] Analyzed {len(comparison_rows)}/{len(triggers)} triggers")
    return comparison_df


# ─── SHAP-E: Regime-conditional ─────────────────────────────────

REGIME_NAMES = {
    0: "BALANCED_ROTATION", 1: "COMPRESSION", 2: "TREND_INITIATION",
    3: "TREND_CONTINUATION", 4: "RE_ACCUMULATION", 5: "EXHAUSTION",
    6: "FAILED_AUCTION", 7: "EXCESS", 8: "CHAOTIC",
}


def run_shap_e(
    explanation,
    dataset,
    shap_model,
    global_importance_df: pd.DataFrame,
    output_dir: Path,
    config=None,
) -> Optional[pd.DataFrame]:
    """Run SHAP-E: Regime-conditional SHAP.

    Returns: comparison DataFrame or None.
    """
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    X = dataset.X
    feature_names = dataset.feature_names

    regime_col = None
    for col in ("auctRegime", "regimeName"):
        if col in X.columns:
            regime_col = col
            break

    if regime_col is None:
        print("  [SHAP-E] auctRegime/regimeName not in X — skipping")
        return None

    regimes = sorted(X[regime_col].dropna().unique().tolist())
    comparison_rows = []

    for regime_val in regimes:
        mask = X[regime_col] == regime_val
        n = int(mask.sum())
        if n < cfg.min_regime_samples:
            continue

        X_sub = X[mask]
        feat_cols = [f for f in feature_names if f in X_sub.columns and f not in (regime_col, "setupType")]
        sv = _compute_subset_shap(shap_model, X_sub[feat_cols], feat_cols, cfg, X[feat_cols])
        if sv is None:
            continue

        imp = _importance_from_shap(sv, feat_cols)
        regime_name = REGIME_NAMES.get(int(regime_val) if str(regime_val).isdigit() else -1, str(regime_val))
        rank_corr = _rank_correlation_vs_global(imp, global_importance_df[global_importance_df["feature"].isin(feat_cols)])

        # Signed mean SHAP per feature (for sign-flip detection)
        mean_signed = pd.Series(sv.mean(axis=0), index=feat_cols)

        regime_df = pd.DataFrame({
            "feature": feat_cols,
            "mean_abs_shap": imp.values,
            "mean_shap_signed": mean_signed.values,
        })
        regime_df["rank"] = regime_df["mean_abs_shap"].rank(ascending=False).astype(int)

        safe_name = str(regime_name).replace(" ", "_")
        regime_df.to_csv(output_dir / f"{safe_name}_importance.csv", index=False)

        comparison_rows.append({
            "regime_val": regime_val,
            "regime_name": regime_name,
            "n_samples": n,
            "rank_corr_vs_global": round(rank_corr, 4),
            "top_feature": regime_df.iloc[0]["feature"] if not regime_df.empty else "",
            "top_shap": float(regime_df.iloc[0]["mean_abs_shap"]) if not regime_df.empty else 0.0,
        })

    if not comparison_rows:
        print("  [SHAP-E] No regimes met minimum sample requirement")
        return None

    comparison_df = pd.DataFrame(comparison_rows)

    # Sign-flip analysis: features that change sign across regimes
    sign_flip_analysis = _detect_sign_flips(output_dir, comparison_df["regime_name"].tolist())
    if sign_flip_analysis is not None:
        sign_flip_analysis.to_csv(output_dir / "regime_sign_flips.csv", index=False)

    comparison_df.to_csv(output_dir / "regime_comparison.csv", index=False)
    print(f"  [SHAP-E] Analyzed {len(comparison_rows)}/{len(regimes)} regimes")
    return comparison_df


def _detect_sign_flips(output_dir: Path, regime_names: list) -> Optional[pd.DataFrame]:
    """Read per-regime CSVs and detect features with sign flips."""
    dfs = []
    for name in regime_names:
        safe = str(name).replace(" ", "_")
        p = output_dir / f"{safe}_importance.csv"
        if p.exists():
            df = pd.read_csv(p)
            df["regime"] = name
            dfs.append(df)

    if len(dfs) < 2:
        return None

    combined = pd.concat(dfs, ignore_index=True)
    if "mean_shap_signed" not in combined.columns:
        return None

    pivot = combined.pivot_table(
        index="feature", columns="regime", values="mean_shap_signed", aggfunc="first"
    )

    # Sign flip = at least one positive and one negative across regimes
    def has_flip(row):
        vals = row.dropna().values
        return bool((vals > 0).any() and (vals < 0).any())

    flip_mask = pivot.apply(has_flip, axis=1)
    if not flip_mask.any():
        return None

    flip_df = pivot[flip_mask].reset_index()
    flip_df.insert(1, "has_sign_flip", True)
    return flip_df


def build_conditional_hypotheses(
    trigger_df: Optional[pd.DataFrame],
    regime_df: Optional[pd.DataFrame],
    experiment_id: str,
) -> List[Dict]:
    """Generate hypotheses from conditional analysis."""
    hypotheses = []

    if trigger_df is not None:
        for _, row in trigger_df.iterrows():
            if float(row["rank_corr_vs_global"]) < 0.7:  # meaningfully different
                hyp = {
                    "source": "SHAP-D",
                    "feature": row["top_feature"],
                    "category": "unknown",
                    "hypothesis_type": "trigger_conditional",
                    "suggested_direction": 1,
                    "suggested_shape": "MONO_UP",
                    "evidence_strength": float(row["top_shap"]),
                    "n_samples": int(row["n_samples"]),
                    "description": (
                        f"Trigger {row['trigger']}: importance profile diverges from global "
                        f"(rank_corr={row['rank_corr_vs_global']:.3f}). "
                        f"Top feature: {row['top_feature']}. "
                        "Consider trigger-specific gate in L4."
                    ),
                    "metadata": {
                        "trigger": str(row["trigger"]),
                        "rank_corr_vs_global": float(row["rank_corr_vs_global"]),
                    },
                }
                hypotheses.append(hyp)

    if regime_df is not None:
        for _, row in regime_df.iterrows():
            if float(row["rank_corr_vs_global"]) < 0.6:
                hyp = {
                    "source": "SHAP-E",
                    "feature": row["top_feature"],
                    "category": "unknown",
                    "hypothesis_type": "regime_conditional",
                    "suggested_direction": 1,
                    "suggested_shape": "MONO_UP",
                    "evidence_strength": float(row["top_shap"]),
                    "n_samples": int(row["n_samples"]),
                    "description": (
                        f"Regime {row['regime_name']}: importance profile diverges from global "
                        f"(rank_corr={row['rank_corr_vs_global']:.3f}). "
                        "Feature importance is regime-conditional."
                    ),
                    "metadata": {
                        "regime_name": str(row["regime_name"]),
                        "regime_val": str(row["regime_val"]),
                        "rank_corr_vs_global": float(row["rank_corr_vs_global"]),
                    },
                }
                hypotheses.append(hyp)

    return hypotheses
