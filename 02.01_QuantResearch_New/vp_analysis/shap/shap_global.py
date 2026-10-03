"""SHAP-A: Global Feature Importance.

Computes mean |SHAP value| per feature across all samples.
Outputs global_importance.csv and optionally a bar chart.

Hypothesis generation:
  - Top-K features by mean |SHAP| → suggest as L4/L5 gate candidates
  - Signed mean SHAP indicates direction (positive = higher values → higher target)
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd


def run_shap_a(
    explanation,         # SHAPExplanation
    dataset,             # SHAPDataset
    output_dir: Path,
    config=None,
) -> pd.DataFrame:
    """Run SHAP-A: Global importance analysis.

    Returns: DataFrame with columns [feature, category, mean_abs_shap, mean_shap, rank]
    Writes: global_importance.csv, global_importance.png (if output_plots=True)
    """
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    shap_values = explanation.shap_values   # (n_samples, n_features)
    feature_names = explanation.feature_names
    categories = dataset.meta.get("feature_categories", {})

    mean_abs = np.abs(shap_values).mean(axis=0)
    mean_signed = shap_values.mean(axis=0)
    std_abs = np.abs(shap_values).std(axis=0)

    df = pd.DataFrame({
        "feature": feature_names,
        "category": [categories.get(f, "unknown") for f in feature_names],
        "mean_abs_shap": mean_abs.tolist(),
        "mean_shap": mean_signed.tolist(),
        "std_shap": std_abs.tolist(),
    })
    df["rank"] = df["mean_abs_shap"].rank(ascending=False).astype(int)
    df = df.sort_values("rank").reset_index(drop=True)

    # Save CSV
    df.to_csv(output_dir / "global_importance.csv", index=False)

    # Generate plot
    if cfg.output_plots:
        _plot_global_importance(df, output_dir, cfg)

    print(f"  [SHAP-A] Global importance: top feature = {df.iloc[0]['feature']} "
          f"(mean|SHAP|={df.iloc[0]['mean_abs_shap']:.4f})")

    return df


def _plot_global_importance(df: pd.DataFrame, output_dir: Path, cfg) -> None:
    """Horizontal bar chart of top-20 features by mean |SHAP|."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return

    top_n = min(20, len(df))
    plot_df = df.head(top_n).copy().iloc[::-1]  # reverse for top-at-top orientation

    fig, ax = plt.subplots(figsize=(10, max(4, top_n * 0.35)))

    colors = ["#e74c3c" if v < 0 else "#3498db" for v in plot_df["mean_shap"]]
    bars = ax.barh(plot_df["feature"], plot_df["mean_abs_shap"], color=colors)

    ax.set_xlabel("Mean |SHAP value|")
    ax.set_title(f"SHAP-A: Global Feature Importance (Top {top_n})")
    ax.axvline(0, color="black", linewidth=0.5)

    # Add value labels
    for bar, val in zip(bars, plot_df["mean_abs_shap"]):
        ax.text(bar.get_width() + 0.0002, bar.get_y() + bar.get_height() / 2,
                f"{val:.4f}", va="center", fontsize=7)

    plt.tight_layout()
    fname = output_dir / f"global_importance.{cfg.plot_format}"
    plt.savefig(fname, dpi=cfg.plot_dpi, bbox_inches="tight")
    plt.close(fig)


def build_global_hypotheses(
    importance_df: pd.DataFrame,
    experiment_id: str,
    top_k: int = 15,
) -> List[Dict]:
    """Generate hypotheses from global importance ranking.

    Returns list of hypothesis dicts for HypothesisRegistry.
    """
    hypotheses = []
    for _, row in importance_df.head(top_k).iterrows():
        direction = 1 if float(row["mean_shap"]) >= 0 else -1
        # Infer suggested shape from direction (will be refined by SHAP-B)
        suggested_shape = "MONO_UP" if direction == 1 else "MONO_DOWN"

        hyp = {
            "source": "SHAP-A",
            "feature": row["feature"],
            "category": row["category"],
            "hypothesis_type": "global_importance",
            "suggested_direction": direction,
            "suggested_shape": suggested_shape,
            "evidence_strength": float(row["mean_abs_shap"]),
            "n_samples": None,  # set by caller
            "description": (
                f"Feature '{row['feature']}' ranked #{row['rank']} globally "
                f"(mean|SHAP|={row['mean_abs_shap']:.4f}, "
                f"mean_signed_SHAP={row['mean_shap']:.4f}). "
                "Validate as L4 gate candidate."
            ),
            "metadata": {
                "rank": int(row["rank"]),
                "mean_abs_shap": float(row["mean_abs_shap"]),
                "mean_shap": float(row["mean_shap"]),
                "std_shap": float(row.get("std_shap", 0.0)),
            },
        }
        hypotheses.append(hyp)
    return hypotheses
