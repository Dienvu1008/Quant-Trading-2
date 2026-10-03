"""SHAP-F: Local Explanations.

Identify the feature drivers for the best and worst individual signals.

For each signal:
  - Compute per-row SHAP contribution (waterfall decomposition)
  - Identify top-K features driving the prediction

Aggregation:
  - Which features are consistently top drivers for winning signals?
  - Which features are consistently top drivers for losing signals?
  - Are the same features driving both? (→ potential false signal risk)
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd


def run_shap_f(
    explanation,         # SHAPExplanation
    dataset,             # SHAPDataset
    output_dir: Path,
    config=None,
) -> Optional[pd.DataFrame]:
    """Run SHAP-F: Local explanations for top/bottom signals.

    Returns: local_summary DataFrame or None.
    """
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    shap_values = explanation.shap_values   # (n_samples, n_features)
    feature_names = explanation.feature_names
    y = dataset.y.values
    X = dataset.X
    n_top = cfg.n_local_top

    # Rank by target
    sorted_idx = np.argsort(y)
    best_idx = sorted_idx[-n_top:][::-1]   # top-N highest target
    worst_idx = sorted_idx[:n_top]          # bottom-N lowest target

    def _build_local_df(indices, label: str) -> pd.DataFrame:
        rows = []
        for rank, idx in enumerate(indices):
            sv = shap_values[idx]            # (n_features,)
            # Top contributing features (by absolute SHAP)
            abs_sv = np.abs(sv)
            top5_idx = np.argsort(abs_sv)[-5:][::-1]
            row = {
                "rank": rank + 1,
                "target_value": float(y[idx]),
                "expected_value": float(explanation.expected_value),
                "shap_sum": float(sv.sum()),
                "label": label,
            }
            for k, fi in enumerate(top5_idx):
                row[f"feature_rank_{k+1}"] = feature_names[fi]
                row[f"shap_rank_{k+1}"] = round(float(sv[fi]), 5)

            # Add metadata columns from X if available
            for meta_col in ("signalId", "symbol", "setupType"):
                if meta_col in X.columns:
                    row[meta_col] = str(X.iloc[idx][meta_col]) if idx < len(X) else ""
            rows.append(row)
        return pd.DataFrame(rows)

    winning_df = _build_local_df(best_idx, "winning")
    losing_df = _build_local_df(worst_idx, "losing")

    winning_df.to_csv(output_dir / f"winning_top{n_top}.csv", index=False)
    losing_df.to_csv(output_dir / f"losing_top{n_top}.csv", index=False)

    # Aggregate: frequency of features in top-3 drivers
    summary = _local_frequency_summary(winning_df, losing_df, feature_names)
    summary.to_csv(output_dir / "local_summary.csv", index=False)

    # Plot (top features by frequency)
    if cfg.output_plots:
        _plot_local_summary(summary, output_dir, cfg)

    print(f"  [SHAP-F] Local: {n_top} winning + {n_top} losing signals analyzed")
    return summary


def _local_frequency_summary(
    winning_df: pd.DataFrame,
    losing_df: pd.DataFrame,
    feature_names: List[str],
) -> pd.DataFrame:
    """Count how often each feature appears in top-3 SHAP drivers."""
    def _count_appearances(df: pd.DataFrame) -> Dict[str, int]:
        counts: Dict[str, int] = {}
        for _, row in df.iterrows():
            for k in range(1, 4):
                col = f"feature_rank_{k}"
                if col in row and pd.notna(row[col]):
                    feat = str(row[col])
                    counts[feat] = counts.get(feat, 0) + 1
        return counts

    win_counts = _count_appearances(winning_df)
    lose_counts = _count_appearances(losing_df)

    all_feats = set(win_counts) | set(lose_counts)
    rows = []
    for feat in all_feats:
        rows.append({
            "feature": feat,
            "win_top3_freq": win_counts.get(feat, 0),
            "lose_top3_freq": lose_counts.get(feat, 0),
        })

    df = pd.DataFrame(rows)
    if df.empty:
        return df

    df["total_top3_freq"] = df["win_top3_freq"] + df["lose_top3_freq"]
    df["win_bias"] = df["win_top3_freq"] / (df["total_top3_freq"] + 1e-9)
    df = df.sort_values("total_top3_freq", ascending=False).reset_index(drop=True)
    return df


def _plot_local_summary(df: pd.DataFrame, output_dir: Path, cfg) -> None:
    """Bar chart: features that appear most often in top-3 SHAP drivers."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return

    top = df.head(15).copy().iloc[::-1]
    fig, ax = plt.subplots(figsize=(10, max(4, len(top) * 0.4)))
    win_vals = top["win_top3_freq"].tolist()
    lose_vals = top["lose_top3_freq"].tolist()
    features = top["feature"].tolist()
    y_pos = range(len(features))

    ax.barh(y_pos, win_vals, label="Winning signals", color="#27ae60", alpha=0.7)
    ax.barh(y_pos, [-v for v in lose_vals], label="Losing signals", color="#e74c3c", alpha=0.7)
    ax.set_yticks(list(y_pos))
    ax.set_yticklabels(features)
    ax.set_xlabel("Frequency in top-3 SHAP drivers")
    ax.set_title("SHAP-F: Local Explanations — Feature Driver Frequency")
    ax.legend()
    ax.axvline(0, color="black", linewidth=0.5)
    plt.tight_layout()
    plt.savefig(
        output_dir / f"local_summary.{cfg.plot_format}",
        dpi=cfg.plot_dpi, bbox_inches="tight"
    )
    plt.close(fig)


def build_local_hypotheses(
    local_summary_df: pd.DataFrame,
    experiment_id: str,
) -> List[Dict]:
    """Generate hypotheses from local explanation analysis."""
    hypotheses = []
    if local_summary_df is None or local_summary_df.empty:
        return []

    # Features that consistently drive winning signals but rarely losing
    win_dominant = local_summary_df[
        (local_summary_df["win_bias"] > 0.7) &
        (local_summary_df["win_top3_freq"] >= 3)
    ]

    for _, row in win_dominant.iterrows():
        hyp = {
            "source": "SHAP-F",
            "feature": row["feature"],
            "category": "unknown",
            "hypothesis_type": "local_winner_driver",
            "suggested_direction": 1,
            "suggested_shape": "MONO_UP",
            "evidence_strength": float(row["win_bias"]),
            "n_samples": int(row["win_top3_freq"]),
            "description": (
                f"Feature '{row['feature']}' drives winning signals "
                f"(win_bias={row['win_bias']:.2f}, "
                f"win_top3_freq={row['win_top3_freq']}). "
                "Strong candidate for L4 gate discovery."
            ),
            "metadata": {
                "win_top3_freq": int(row["win_top3_freq"]),
                "lose_top3_freq": int(row["lose_top3_freq"]),
                "win_bias": float(row["win_bias"]),
            },
        }
        hypotheses.append(hyp)
    return hypotheses
