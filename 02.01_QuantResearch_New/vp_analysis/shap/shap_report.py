"""shap_report.py — SHAP analysis report generator.

Produces shap_summary.md from analysis artifacts.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Optional
import datetime as dt


def build_shap_summary(
    experiment_id: str,
    output_dir: Path,
    run_meta: dict,
    n_signals: int,
    n_features: int,
) -> str:
    """Build a markdown summary of the SHAP analysis run."""
    output_dir = Path(output_dir)
    lines = [
        f"# SHAP Analysis Report — {experiment_id}",
        f"",
        f"Generated: {dt.datetime.utcnow().isoformat()}Z",
        f"",
        f"## 1. Dataset",
        f"",
        f"| Field | Value |",
        f"|-------|-------|",
        f"| Experiment ID | `{experiment_id}` |",
        f"| Signals (deduplicated) | {n_signals} |",
        f"| Features | {n_features} |",
        f"| Target mode | `{run_meta.get('target_mode', 'N/A')}` |",
        f"| Target | `{run_meta.get('target_name', 'N/A')}` |",
        f"| Model | `{run_meta.get('model_type', 'N/A')}` |",
        f"| Seed | `{run_meta.get('seed', 'N/A')}` |",
        f"| Ran at | `{run_meta.get('ran_at', 'N/A')}` |",
        f"",
    ]

    # Global importance
    gi_path = output_dir / "global_importance.csv"
    if gi_path.exists():
        try:
            import pandas as pd
            gi = pd.read_csv(gi_path).head(20)
            lines += ["## 2. Global Feature Importance (Top 20)", ""]
            lines += ["| Rank | Feature | Mean |SHAP| |", "|------|---------|------------|"]
            for _, row in gi.iterrows():
                lines.append(f"| {int(row.get('rank', 0))} | {row['feature']} | {row['mean_abs_shap']:.4f} |")
            lines.append("")
        except Exception:
            lines += ["## 2. Global Feature Importance", "", "_See global_importance.csv_", ""]
    else:
        lines += ["## 2. Global Feature Importance", "", "_Not computed._", ""]

    # Dependence summary
    dep_path = output_dir / "shap_b" / "dependence_summary.csv"
    if dep_path.exists():
        try:
            import pandas as pd
            dep = pd.read_csv(dep_path)
            shape_counts = dep["shape_detected"].value_counts().to_dict()
            lines += ["## 3. Dependence Shape Summary", ""]
            for shape, count in sorted(shape_counts.items(), key=lambda x: -x[1]):
                lines.append(f"- **{shape}**: {count} feature(s)")
            lines.append("")
        except Exception:
            lines += ["## 3. Dependence Shape Summary", "", "_See shap_b/dependence_summary.csv_", ""]
    else:
        lines += ["## 3. Dependence Shape Summary", "", "_Not computed._", ""]

    # Style comparison
    style_path = output_dir / "shap_g" / "entry_quality_features.csv"
    if style_path.exists():
        try:
            import pandas as pd
            eq = pd.read_csv(style_path)
            lines += [f"## 7. Entry Quality Features ({len(eq)} features with CV < 0.30)", ""]
            if not eq.empty:
                lines += ["| Feature | CV across styles |", "|---------|-----------------|"]
                for _, row in eq.head(15).iterrows():
                    lines.append(f"| {row['feature']} | {row.get('cv_across_styles', 'N/A'):.3f} |")
            lines.append("")
        except Exception:
            lines += ["## 7. Entry Quality Features", "", "_See shap_g/entry_quality_features.csv_", ""]
    else:
        lines += ["## 7. Entry Quality Features", "", "_Not computed._", ""]

    # Stability summary
    stab_path = output_dir / "shap_h" / "stability_summary.csv"
    if stab_path.exists():
        try:
            import pandas as pd
            stab = pd.read_csv(stab_path)
            mean_stab = float(stab["mean_stability"].mean()) if "mean_stability" in stab.columns else 0.0
            lines += [f"## 8. Stability Analysis (mean stability = {mean_stab:.3f})", ""]
            lines += ["_See shap_h/stability_summary.csv_", ""]
        except Exception:
            lines += ["## 8. Stability Analysis", "", "_See shap_h/stability_summary.csv_", ""]
    else:
        lines += ["## 8. Stability Analysis", "", "_Not computed._", ""]

    # Hypotheses
    hyp_path = output_dir / "hypotheses.json"
    if hyp_path.exists():
        try:
            hyps = json.loads(hyp_path.read_text())
            lines += [f"## 9. Hypotheses ({len(hyps)} discovered)", ""]
            if hyps:
                lines += ["| ID | Source | Feature | Type | Shape | Evidence |",
                           "|----|--------|---------|------|-------|----------|"]
                for h in hyps[:30]:
                    lines.append(
                        f"| {h['hypothesis_id']} | {h['source']} | {h['feature']} "
                        f"| {h['hypothesis_type']} | {h['suggested_shape']} "
                        f"| {h['evidence_strength']:.3f} |"
                    )
                if len(hyps) > 30:
                    lines.append(f"... and {len(hyps)-30} more. See hypotheses.json")
            else:
                lines += ["_No hypotheses generated — null result._"]
            lines.append("")
        except Exception:
            lines += ["## 9. Hypotheses", "", "_See hypotheses.json_", ""]

    lines += [
        "## 10. Validation Status",
        "",
        "All hypotheses above have status `DISCOVERY_ONLY`.",
        "They must pass through the existing L4/L5/L6 FDR validation pipeline",
        "before being considered for production use.",
        "",
        "**No SHAP-derived rules are automatically added to the EA.**",
        "",
        "---",
        f"*Report generated by SHAP Analysis Layer v4 — {experiment_id}*",
    ]

    summary = "\n".join(lines)
    (output_dir / "shap_summary.md").write_text(summary, encoding="utf-8")
    print(f"  [Report] shap_summary.md written to {output_dir}")
    return summary


def run_shap_report(output_dir: Path, experiment_id: str) -> None:
    """Load run_meta and build report."""
    output_dir = Path(output_dir)
    run_meta_path = output_dir / "run_meta.json"
    run_meta = {}
    if run_meta_path.exists():
        run_meta = json.loads(run_meta_path.read_text())

    n_signals = run_meta.get("n_signals", 0)
    n_features = run_meta.get("n_features", 0)
    build_shap_summary(experiment_id, output_dir, run_meta, n_signals, n_features)
