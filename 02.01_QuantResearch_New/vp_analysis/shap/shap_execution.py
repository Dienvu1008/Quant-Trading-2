"""SHAP-G: Entry Edge vs Exit Policy Analysis.

Trains one SHAP model per trailing style (-1, 0, 1) and compares
feature importance profiles across styles.

Interpretation:
  - Features with low CV across styles = entry quality signals
    (importance consistent regardless of how the trade exits)
  - Features with high CV across styles = exit policy confounds
    (importance depends on how the trade was managed)

Only entry-quality features (low CV) make good L4 gate candidates.
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd


TRAIL_STYLE_LABELS = {-1: "no_trail", 0: "conservative", 1: "expansion"}


def run_shap_g(
    dataset,             # SHAPDataset (has style_df)
    contract,
    available_features: List[str],
    output_dir: Path,
    config=None,
) -> Optional[pd.DataFrame]:
    """Run SHAP-G: per-style SHAP models and entry quality detection."""
    from .shap_config import SHAPConfig
    from .shap_dataset import SHAP_FORBIDDEN_FEATURES
    from .shap_model import fit_shap_model
    from .shap_explainer import compute_shap_values

    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    style_df = dataset.style_df
    if style_df is None:
        print("  [SHAP-G] style_df not available — skipping")
        return None

    if "trailStyle" not in style_df.columns or "profitUSD" not in style_df.columns:
        print("  [SHAP-G] Missing trailStyle or profitUSD in style_df — skipping")
        return None

    feature_names = dataset.feature_names
    feat_cols = [f for f in feature_names if f in style_df.columns]
    if not feat_cols:
        print("  [SHAP-G] No feature columns in style_df — skipping")
        return None

    styles = sorted(style_df["trailStyle"].dropna().unique())
    style_importances: Dict[str, pd.Series] = {}

    for style_val in styles:
        style_label = TRAIL_STYLE_LABELS.get(int(style_val), str(style_val))
        sub = style_df[style_df["trailStyle"] == style_val].copy()
        n = len(sub)

        if n < cfg.min_rows_total:
            print(f"  [SHAP-G] Style {style_label}: {n} rows < min — skipped")
            continue

        # Build minimal dataset for this style
        X_sub = sub[feat_cols].copy()
        for col in feat_cols:
            X_sub[col] = pd.to_numeric(X_sub[col], errors="coerce").astype(np.float32)
            med = float(X_sub[col].median())
            X_sub[col] = X_sub[col].fillna(med if not np.isnan(med) else 0.0)

        y_sub = pd.to_numeric(sub["profitUSD"], errors="coerce").fillna(0.0).astype(np.float32)

        # Create a minimal SHAPDataset-like object
        class _MiniDataset:
            def __init__(self):
                self.X = X_sub.reset_index(drop=True)
                self.y = y_sub.reset_index(drop=True)
                self.feature_names = feat_cols
                self.target_name = "profitUSD"
                self.target_mode = "production_profit"
                self.n_signals = n
                self.min_rows_total = cfg.min_rows_total

        mini = _MiniDataset()
        try:
            style_model = fit_shap_model(mini, cfg)
            style_expl = compute_shap_values(style_model, X_sub.reset_index(drop=True), cfg)
            mean_abs_shap = np.abs(style_expl.shap_values).mean(axis=0)
            style_importances[style_label] = pd.Series(mean_abs_shap, index=feat_cols)

            # Save per-style importance
            style_df_out = pd.DataFrame({
                "feature": feat_cols,
                "mean_abs_shap": mean_abs_shap.tolist(),
                "n": n,
                "style": style_label,
            })
            style_df_out.to_csv(output_dir / f"style_{style_label}_importance.csv", index=False)
            print(f"  [SHAP-G] Style {style_label}: n={n}, top={feat_cols[int(np.argmax(mean_abs_shap))]}")

        except Exception as e:
            print(f"  [SHAP-G] Style {style_label} SHAP failed: {e}")

    if len(style_importances) < 2:
        print("  [SHAP-G] Too few styles to compare — skipping")
        return None

    # Build comparison table
    result_rows = []
    for feat in feat_cols:
        vals = {s: float(imp.get(feat, 0.0)) for s, imp in style_importances.items()}
        arr = np.array(list(vals.values()))
        cv = float(arr.std() / (arr.mean() + 1e-9))
        row = {"feature": feat}
        for s, v in vals.items():
            row[f"shap_{s}"] = round(v, 6)
        row["cv_across_styles"] = round(cv, 4)
        row["consistent_entry_feature"] = cv < 0.30
        result_rows.append(row)

    if not result_rows:
        return None

    comparison_df = pd.DataFrame(result_rows)
    comparison_df = comparison_df.sort_values("cv_across_styles").reset_index(drop=True)
    comparison_df.to_csv(output_dir / "style_comparison.csv", index=False)

    # Entry quality features (low CV across styles)
    entry_quality = comparison_df[comparison_df["consistent_entry_feature"]].copy()
    entry_quality.to_csv(output_dir / "entry_quality_features.csv", index=False)

    if cfg.output_plots:
        _plot_style_comparison(comparison_df, style_importances, output_dir, cfg)

    n_entry = int(comparison_df["consistent_entry_feature"].sum())
    print(f"  [SHAP-G] {n_entry}/{len(comparison_df)} features are entry-quality "
          f"(CV < 0.30 across styles)")
    return comparison_df


def _plot_style_comparison(
    comparison_df: pd.DataFrame,
    style_importances: Dict,
    output_dir: Path,
    cfg,
) -> None:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return

    top20 = comparison_df.head(20)
    features = top20["feature"].tolist()
    styles = sorted(style_importances.keys())
    n = len(features)
    bar_width = 0.8 / max(len(styles), 1)
    colors = ["#3498db", "#e74c3c", "#2ecc71"]

    fig, ax = plt.subplots(figsize=(12, max(5, n * 0.4)))
    for i, style in enumerate(styles):
        col = f"shap_{style}"
        if col in top20.columns:
            vals = top20[col].fillna(0).tolist()
            offsets = [j + (i - len(styles) / 2) * bar_width for j in range(n)]
            ax.barh(offsets, vals, height=bar_width,
                    label=style, color=colors[i % len(colors)], alpha=0.8)

    ax.set_yticks(range(n))
    ax.set_yticklabels(features)
    ax.set_xlabel("Mean |SHAP value|")
    ax.set_title("SHAP-G: Feature Importance by Trailing Style")
    ax.legend(title="Style")
    plt.tight_layout()
    plt.savefig(
        output_dir / f"style_comparison.{cfg.plot_format}",
        dpi=cfg.plot_dpi, bbox_inches="tight"
    )
    plt.close(fig)


def build_execution_hypotheses(
    comparison_df: Optional[pd.DataFrame],
    experiment_id: str,
) -> List[Dict]:
    """Generate hypotheses from execution policy analysis."""
    if comparison_df is None or comparison_df.empty:
        return []

    hypotheses = []
    entry_quality = comparison_df[comparison_df.get("consistent_entry_feature", False)]
    for _, row in entry_quality.iterrows():
        hyp = {
            "source": "SHAP-G",
            "feature": row["feature"],
            "category": "unknown",
            "hypothesis_type": "entry_quality",
            "suggested_direction": 1,
            "suggested_shape": "MONO_UP",
            "evidence_strength": float(1.0 - row.get("cv_across_styles", 1.0)),
            "n_samples": None,
            "description": (
                f"Feature '{row['feature']}' shows consistent importance across "
                f"all 3 trailing styles (CV={row['cv_across_styles']:.3f} < 0.30). "
                "Strong entry quality signal — good L4 gate candidate."
            ),
            "metadata": {
                "cv_across_styles": float(row["cv_across_styles"]),
                "consistent_entry_feature": True,
            },
        }
        hypotheses.append(hyp)
    return hypotheses
