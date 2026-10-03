"""SHAP-B: Dependence Analysis.

For each feature (top-N by global importance), analyze the SHAP value vs
feature value relationship to classify the shape:
  - MONO_UP:    SHAP increases with feature value (r > 0.5, p < 0.05)
  - MONO_DOWN:  SHAP decreases with feature value (r < -0.5, p < 0.05)
  - BAND:       SHAP peaks in the middle (U-inverted shape)
  - SATURATION: SHAP plateaus above/below threshold
  - NONLINEAR:  Complex but structured relationship
  - FLAT:       No discernible pattern (|r| < 0.2, shap_range small)

The detected shape serves as input for the hypothesis_registry suggested_shape
and L4 shape_prior for gate search.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from scipy import stats


# ─── Shape detection ─────────────────────────────────────────────

def _detect_shape(feature_vals: np.ndarray, shap_vals: np.ndarray) -> Tuple[str, float, float]:
    """Classify the SHAP dependence shape.

    Returns: (shape_name, spearman_r, p_value)
    """
    # Remove NaN
    mask = ~(np.isnan(feature_vals) | np.isnan(shap_vals))
    fv = feature_vals[mask]
    sv = shap_vals[mask]

    if len(fv) < 10:
        return "FLAT", 0.0, 1.0

    # Spearman correlation (monotonic)
    r, p = stats.spearmanr(fv, sv)
    r = float(r) if not np.isnan(r) else 0.0
    p = float(p) if not np.isnan(p) else 1.0

    # Monotonic?
    if abs(r) > 0.5 and p < 0.05:
        return ("MONO_UP" if r > 0 else "MONO_DOWN"), r, p

    # Band detection: split into 3 quantile buckets
    # If middle bucket has higher mean SHAP than both tails → BAND
    q33 = float(np.quantile(fv, 0.33))
    q67 = float(np.quantile(fv, 0.67))
    low_mask = fv <= q33
    mid_mask = (fv > q33) & (fv <= q67)
    hi_mask = fv > q67

    if mid_mask.sum() >= 5 and low_mask.sum() >= 5 and hi_mask.sum() >= 5:
        low_ev = float(sv[low_mask].mean())
        mid_ev = float(sv[mid_mask].mean())
        hi_ev = float(sv[hi_mask].mean())

        if mid_ev > low_ev and mid_ev > hi_ev:
            # Middle bucket best → BAND
            improvement = mid_ev - max(low_ev, hi_ev)
            if improvement > 0.02:  # must be meaningful
                return "BAND", r, p

        # Saturation: monotonic but flattens
        # Check if top-20% and top-30% have similar mean SHAP
        q80 = float(np.quantile(fv, 0.80))
        q70 = float(np.quantile(fv, 0.70))
        top_20 = sv[fv >= q80]
        top_30 = sv[fv >= q70]
        if len(top_20) >= 5 and len(top_30) >= 5:
            # If adding bottom 10% of "top" doesn't change EV much → saturated
            diff = abs(float(top_20.mean()) - float(top_30.mean()))
            if diff < 0.01 and abs(r) > 0.3:
                return "SATURATION", r, p

    # Range-based nonlinearity check
    shap_range = float(sv.max() - sv.min())
    if shap_range > 0.05 and abs(r) < 0.3:
        return "NONLINEAR", r, p

    return "FLAT", r, p


# ─── Public API ──────────────────────────────────────────────────

def run_shap_b(
    explanation,         # SHAPExplanation
    dataset,             # SHAPDataset
    global_importance_df: pd.DataFrame,
    output_dir: Path,
    config=None,
) -> pd.DataFrame:
    """Run SHAP-B: Dependence analysis for top-N features.

    Returns: summary DataFrame with shape detection per feature.
    """
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    shap_values = explanation.shap_values   # (n_samples, n_features)
    feature_names = explanation.feature_names
    X = dataset.X

    # Top-N features by global importance
    top_features = global_importance_df.head(cfg.n_dependence_top)["feature"].tolist()

    rows = []
    for feat in top_features:
        if feat not in feature_names:
            continue
        fidx = feature_names.index(feat)
        fv = X[feat].values.astype(float)
        sv = shap_values[:, fidx].astype(float)

        shape, r, p = _detect_shape(fv, sv)
        shap_range = float(np.abs(sv).max() - np.abs(sv).min()) if len(sv) > 0 else 0.0
        n = int((~np.isnan(fv)).sum())

        rows.append({
            "feature": feat,
            "shape_detected": shape,
            "spearman_r": round(r, 4),
            "p_value": round(p, 6),
            "shap_range": round(float(np.abs(sv).max() - np.abs(sv).min()), 4),
            "mean_shap": round(float(sv.mean()), 4),
            "n": n,
        })

        # Per-feature CSV
        feat_df = pd.DataFrame({"feature_value": fv, "shap_value": sv})
        feat_df.to_csv(output_dir / f"{feat}_dependence.csv", index=False)

        # Plot
        if cfg.output_plots:
            _plot_dependence(feat, fv, sv, shape, output_dir, cfg)

    summary_df = pd.DataFrame(rows)
    if not summary_df.empty:
        summary_df.to_csv(output_dir / "dependence_summary.csv", index=False)

    shapes_found = summary_df["shape_detected"].value_counts().to_dict() if not summary_df.empty else {}
    print(f"  [SHAP-B] Dependence shapes: {shapes_found}")

    return summary_df


def _plot_dependence(
    feature: str,
    fv: np.ndarray,
    sv: np.ndarray,
    shape: str,
    output_dir: Path,
    cfg,
) -> None:
    """Scatter plot of feature value vs SHAP value."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return

    fig, ax = plt.subplots(figsize=(7, 4))
    mask = ~(np.isnan(fv) | np.isnan(sv))
    ax.scatter(fv[mask], sv[mask], alpha=0.3, s=8, c="#3498db")
    ax.axhline(0, color="red", linewidth=0.8, linestyle="--")
    ax.set_xlabel(f"{feature} value")
    ax.set_ylabel("SHAP value")
    ax.set_title(f"SHAP-B Dependence: {feature} ({shape})")
    plt.tight_layout()
    plt.savefig(
        output_dir / f"{feature}_dependence.{cfg.plot_format}",
        dpi=cfg.plot_dpi, bbox_inches="tight"
    )
    plt.close(fig)


def build_dependence_hypotheses(
    dependence_df: pd.DataFrame,
    experiment_id: str,
) -> List[Dict]:
    """Generate hypotheses from dependence shape analysis."""
    hypotheses = []
    shape_to_direction = {
        "MONO_UP": 1, "MONO_DOWN": -1,
        "BAND": 0, "SATURATION": 1,
        "NONLINEAR": 0, "FLAT": 0,
    }

    for _, row in dependence_df.iterrows():
        shape = row["shape_detected"]
        if shape in ("FLAT",):
            continue  # no hypothesis from flat features

        direction = shape_to_direction.get(shape, 0)
        r = float(row["spearman_r"])
        if r < 0 and shape == "SATURATION":
            direction = -1

        hyp = {
            "source": "SHAP-B",
            "feature": row["feature"],
            "category": "unknown",  # caller enriches
            "hypothesis_type": "dependence_shape",
            "suggested_direction": direction,
            "suggested_shape": shape,
            "evidence_strength": abs(float(row["spearman_r"])),
            "n_samples": int(row["n"]),
            "description": (
                f"Feature '{row['feature']}' shows {shape} SHAP dependence "
                f"(Spearman r={r:.3f}, p={row['p_value']:.4f}). "
                f"Suggested L4 shape_prior: {shape}."
            ),
            "metadata": {
                "spearman_r": float(row["spearman_r"]),
                "p_value": float(row["p_value"]),
                "shap_range": float(row["shap_range"]),
            },
        }
        hypotheses.append(hyp)
    return hypotheses
