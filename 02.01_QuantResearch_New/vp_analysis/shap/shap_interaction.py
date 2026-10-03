"""SHAP-C: Interaction Analysis.

Uses SHAP interaction values (from TreeExplainer.shap_interaction_values)
to identify pairs of features with significant joint effects.

Cross-engine interactions are especially interesting because they reveal
compound signals that single-feature gates would miss.

NOTE: interaction values computation is expensive (O(n*f^2)). Disabled by
default (run_shap_c=False). Enable explicitly in SHAPConfig.
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd


# Engine category prefixes (for cross-engine detection)
_ENGINE_PREFIXES = {
    "vp": "volume_profile",
    "auct": "auction",
    "vpLT": "vp_longterm",
    "ms": "microstructure",
    "of": "orderflow",
    "liq": "liquidity",
    "sm": "smartmoney",
    "bos": "structure",
    "choch": "structure",
    "struct": "structure",
    "trend": "structure",
    "ix_": "interaction",
    "spread": "market",
    "atr": "market",
    "RR": "setup",
}


def _get_engine(feature: str) -> str:
    """Heuristic: which engine/category does this feature belong to?"""
    for prefix, engine in sorted(_ENGINE_PREFIXES.items(), key=lambda x: -len(x[0])):
        if feature.startswith(prefix):
            return engine
    return "unknown"


def run_shap_c(
    explanation,         # SHAPExplanation
    dataset,             # SHAPDataset
    output_dir: Path,
    config=None,
) -> Optional[pd.DataFrame]:
    """Run SHAP-C: Interaction analysis.

    Returns: DataFrame with top interaction pairs, or None if interaction
             values were not computed.
    """
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if explanation.interaction_values is None:
        print("  [SHAP-C] Interaction values not computed (run_shap_c=False or failed)")
        return None

    iv = explanation.interaction_values   # (n_samples, n_features, n_features)
    feature_names = explanation.feature_names
    n_features = len(feature_names)

    # Mean absolute interaction per pair (upper triangle only, excluding diagonal)
    rows = []
    for i in range(n_features):
        for j in range(i + 1, n_features):
            interaction_vals = iv[:, i, j]
            mean_abs = float(np.abs(interaction_vals).mean())
            mean_signed = float(interaction_vals.mean())
            engine_a = _get_engine(feature_names[i])
            engine_b = _get_engine(feature_names[j])
            cross_engine = engine_a != engine_b and "unknown" not in (engine_a, engine_b)

            rows.append({
                "feature_a": feature_names[i],
                "feature_b": feature_names[j],
                "engine_a": engine_a,
                "engine_b": engine_b,
                "cross_engine": cross_engine,
                "mean_abs_interaction": round(mean_abs, 6),
                "mean_interaction": round(mean_signed, 6),
            })

    if not rows:
        print("  [SHAP-C] No interaction pairs computed")
        return None

    df = pd.DataFrame(rows)
    df["rank"] = df["mean_abs_interaction"].rank(ascending=False).astype(int)
    df = df.sort_values("rank").reset_index(drop=True)

    # Save
    df.to_csv(output_dir / "interactions.csv", index=False)

    # Cross-engine subset
    cross_df = df[df["cross_engine"]].head(20)
    cross_df.to_csv(output_dir / "cross_engine_interactions.csv", index=False)

    if cfg.output_plots:
        _plot_interactions(df.head(20), output_dir, cfg)

    top = df.iloc[0] if len(df) > 0 else None
    if top is not None:
        print(f"  [SHAP-C] Top interaction: {top['feature_a']} × {top['feature_b']} "
              f"(mean|interaction|={top['mean_abs_interaction']:.4f}, "
              f"cross_engine={top['cross_engine']})")

    return df


def _plot_interactions(df: pd.DataFrame, output_dir: Path, cfg) -> None:
    """Bar chart of top interaction pairs."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return

    labels = [f"{r['feature_a']} × {r['feature_b']}" for _, r in df.iterrows()]
    values = df["mean_abs_interaction"].tolist()
    colors = ["#e74c3c" if r["cross_engine"] else "#3498db" for _, r in df.iterrows()]

    fig, ax = plt.subplots(figsize=(10, max(4, len(df) * 0.35)))
    ax.barh(labels[::-1], values[::-1], color=colors[::-1])
    ax.set_xlabel("Mean |SHAP interaction|")
    ax.set_title("SHAP-C: Top Feature Interactions (red=cross-engine)")
    plt.tight_layout()
    plt.savefig(
        output_dir / f"interactions.{cfg.plot_format}",
        dpi=cfg.plot_dpi, bbox_inches="tight"
    )
    plt.close(fig)


def build_interaction_hypotheses(
    interaction_df: pd.DataFrame,
    experiment_id: str,
    top_k: int = 10,
) -> List[Dict]:
    """Generate hypotheses from interaction analysis."""
    if interaction_df is None or interaction_df.empty:
        return []

    # Focus on cross-engine interactions in top-K
    cross_df = interaction_df[interaction_df["cross_engine"]].head(top_k)
    if cross_df.empty:
        cross_df = interaction_df.head(top_k)

    hypotheses = []
    for _, row in cross_df.iterrows():
        hyp = {
            "source": "SHAP-C",
            "feature": f"{row['feature_a']}×{row['feature_b']}",
            "category": "interaction",
            "hypothesis_type": "interaction",
            "suggested_direction": 1,
            "suggested_shape": "BAND",
            "evidence_strength": float(row["mean_abs_interaction"]),
            "n_samples": None,
            "description": (
                f"Interaction between '{row['feature_a']}' ({row['engine_a']}) and "
                f"'{row['feature_b']}' ({row['engine_b']}) — "
                f"mean|interaction|={row['mean_abs_interaction']:.4f}. "
                "Consider pre-registering as interaction feature."
            ),
            "metadata": {
                "feature_a": row["feature_a"],
                "feature_b": row["feature_b"],
                "engine_a": row["engine_a"],
                "engine_b": row["engine_b"],
                "cross_engine": bool(row["cross_engine"]),
                "mean_abs_interaction": float(row["mean_abs_interaction"]),
            },
        }
        hypotheses.append(hyp)
    return hypotheses
