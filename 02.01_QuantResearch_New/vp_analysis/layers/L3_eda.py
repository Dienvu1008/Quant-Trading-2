"""Layer 3 — EDA & Shape Verification.

Runs on DEVELOPMENT data only.

Responsibilities:
  1. EV-by-bin analysis for every available feature.
  2. Shape classification: MONO_UP / MONO_DOWN / BAND / U_SHAPE / FLAT / INSUFFICIENT.
  3. Verify against contract's SHAPE_PRIORS. Mismatches are flagged but
     do NOT change the prior — L4's search strategy is governed by the
     prior. Changing the prior requires a new contract / new experiment.
  4. Correlation matrix + redundant-pair detection (|rho| > threshold).
  5. Temporal stability (block-wise mean and std).
  6. Baseline statistics (WR, EV, PF, MAE/MFE means).

This layer is descriptive. It does not select rules, tune parameters, or
touch holdout.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

import numpy as np
import pandas as pd
from scipy import stats


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class EDAConfig:
    n_bins: int = 10
    min_bin_samples: int = 10
    # Monotone classification thresholds
    monotone_rho_threshold: float = 0.60
    monotone_pvalue: float = 0.10
    # Band classification: peak must exceed mean(edges) by this many
    # standard deviations of the bin means
    band_peak_sigma: float = 0.50
    # Correlation
    correlation_threshold: float = 0.70
    # Temporal stability
    n_temporal_blocks: int = 5
    min_block_samples: int = 10
    # Report caps
    max_redundant_pairs_in_report: int = 200


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class FeatureShapeAnalysis:
    feature: str
    category: str
    prior_shape: str
    observed_shape: str
    match: bool
    spearman_rho: float
    spearman_pvalue: float
    bin_edges: tuple
    bin_means: tuple
    bin_counts: tuple
    peak_bin_idx: Optional[int]
    overall_ev: float
    overall_n: int

    def to_dict(self) -> dict:
        return {
            "feature": self.feature,
            "category": self.category,
            "prior_shape": self.prior_shape,
            "observed_shape": self.observed_shape,
            "match": self.match,
            "spearman_rho": round(self.spearman_rho, 4),
            "spearman_pvalue": round(self.spearman_pvalue, 6),
            "bin_edges": [round(e, 6) for e in self.bin_edges],
            "bin_means": [round(m, 6) if not np.isnan(m) else None
                          for m in self.bin_means],
            "bin_counts": list(self.bin_counts),
            "peak_bin_idx": self.peak_bin_idx,
            "overall_ev": round(self.overall_ev, 6),
            "overall_n": self.overall_n,
        }


@dataclass(frozen=True)
class RedundantPair:
    feature_a: str
    feature_b: str
    rho: float

    def to_dict(self) -> dict:
        return {
            "feature_a": self.feature_a,
            "feature_b": self.feature_b,
            "spearman_rho": round(self.rho, 4),
        }


@dataclass(frozen=True)
class StabilityEntry:
    feature: str
    block_means: tuple
    block_stds: tuple
    cv: float          # coefficient of variation of block means
    unstable: bool     # cv > 1.0 means blocks differ by more than 100%

    def to_dict(self) -> dict:
        return {
            "feature": self.feature,
            "block_means": [round(m, 6) if not np.isnan(m) else None
                            for m in self.block_means],
            "block_stds": [round(s, 6) if not np.isnan(s) else None
                           for s in self.block_stds],
            "cv": round(self.cv, 4) if not np.isnan(self.cv) else None,
            "unstable": self.unstable,
        }


@dataclass(frozen=True)
class LayerThreeResult:
    shape_analyses: tuple
    redundant_pairs: tuple
    stability: tuple
    baseline: dict
    n_features_analyzed: int
    n_shape_match: int
    n_shape_mismatch: int
    n_prior_unspecified: int
    mismatch_rate: float
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_features_analyzed": self.n_features_analyzed,
            "n_shape_match": self.n_shape_match,
            "n_shape_mismatch": self.n_shape_mismatch,
            "n_prior_unspecified": self.n_prior_unspecified,
            "mismatch_rate": round(self.mismatch_rate, 4),
            "n_redundant_pairs": len(self.redundant_pairs),
            "n_unstable_features": sum(
                1 for s in self.stability if s.unstable
            ),
            "warnings": list(self.warnings),
            "baseline": self.baseline,
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_df: pd.DataFrame,
    contract,
    available_features: Iterable[str],
    output_dir: Optional[Path] = None,
    config: Optional[EDAConfig] = None,
) -> LayerThreeResult:
    """Execute Layer 3.

    dev_df must be the development DataFrame only.
    available_features should come from L1 (feature availability on dev).
    """
    cfg = config or EDAConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if dev_df is None or len(dev_df) == 0:
        raise ValueError("L3: dev_df is empty")

    avail = [f for f in available_features if f in dev_df.columns]
    if not avail:
        raise ValueError("L3: no available features present in dev_df")

    # Map feature → category
    feature_category = _build_feature_category_map(contract.pre_registered)

    # ─── Shape analysis ─────────────────────────────────────────
    shape_analyses: list[FeatureShapeAnalysis] = []
    warnings: list[str] = []
    for feat in avail:
        cat = feature_category.get(feat, "unknown")
        prior = contract.shape_priors.get(feat, None)
        analysis = _analyze_shape(dev_df, feat, cat, prior, cfg)
        shape_analyses.append(analysis)

    n_prior_unspec = sum(
        1 for a in shape_analyses if a.prior_shape is None
    )
    n_match = sum(
        1 for a in shape_analyses if a.match is True
    )
    n_mismatch = sum(
        1 for a in shape_analyses if a.match is False
    )
    denom = n_match + n_mismatch
    mismatch_rate = (n_mismatch / denom) if denom > 0 else 0.0

    for a in shape_analyses:
        if a.match is False:
            warnings.append(
                f"SHAPE_PRIOR mismatch: {a.feature!r} "
                f"prior={a.prior_shape!r}, observed={a.observed_shape!r} "
                f"(rho={a.spearman_rho:.3f}, p={a.spearman_pvalue:.4f})"
            )
        elif a.observed_shape == "INSUFFICIENT":
            warnings.append(
                f"Shape for {a.feature!r} could not be determined: "
                f"too few valid bins"
            )

    # ─── Correlation ────────────────────────────────────────────
    corr_matrix = _compute_correlation(dev_df, avail)
    redundant = _find_redundant_pairs(corr_matrix, cfg)
    if len(redundant) > cfg.max_redundant_pairs_in_report:
        warnings.append(
            f"Redundant pair count {len(redundant)} exceeds report "
            f"cap {cfg.max_redundant_pairs_in_report}; truncated."
        )
        redundant = tuple(redundant[:cfg.max_redundant_pairs_in_report])

    # ─── Temporal stability ─────────────────────────────────────
    stability = _compute_stability(dev_df, avail, cfg)

    # ─── Baseline stats ─────────────────────────────────────────
    baseline = _compute_baseline(dev_df)

    result = LayerThreeResult(
        shape_analyses=tuple(shape_analyses),
        redundant_pairs=tuple(redundant),
        stability=tuple(stability),
        baseline=baseline,
        n_features_analyzed=len(shape_analyses),
        n_shape_match=n_match,
        n_shape_mismatch=n_mismatch,
        n_prior_unspecified=n_prior_unspec,
        mismatch_rate=mismatch_rate,
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, corr_matrix, Path(output_dir))

    return result


# ─── Shape classification ────────────────────────────────────────

def _analyze_shape(
    df: pd.DataFrame,
    feature: str,
    category: str,
    prior: Optional[str],
    cfg: EDAConfig,
) -> FeatureShapeAnalysis:
    vals = pd.to_numeric(df[feature], errors="coerce")
    profits = pd.to_numeric(df["_profit"], errors="coerce")

    # Drop rows with NaN in feature or profit
    valid = vals.notna() & profits.notna()
    vals = vals[valid]
    profits = profits[valid]
    n_total = len(vals)

    if n_total < cfg.min_bin_samples * 3:
        return FeatureShapeAnalysis(
            feature=feature, category=category,
            prior_shape=prior, observed_shape="INSUFFICIENT",
            match=None,
            spearman_rho=float("nan"), spearman_pvalue=float("nan"),
            bin_edges=(), bin_means=(), bin_counts=(),
            peak_bin_idx=None, overall_ev=float("nan"), overall_n=n_total,
        )

    # Quantile bins on feature
    try:
        bin_edges = np.quantile(
            vals.values, np.linspace(0.0, 1.0, cfg.n_bins + 1),
        )
    except Exception:
        return FeatureShapeAnalysis(
            feature=feature, category=category,
            prior_shape=prior, observed_shape="INSUFFICIENT",
            match=None,
            spearman_rho=float("nan"), spearman_pvalue=float("nan"),
            bin_edges=(), bin_means=(), bin_counts=(),
            peak_bin_idx=None, overall_ev=float("nan"), overall_n=n_total,
        )

    # Make edges unique (constant feature → duplicate edges)
    unique_edges = np.unique(bin_edges)
    if len(unique_edges) < 3:
        return FeatureShapeAnalysis(
            feature=feature, category=category,
            prior_shape=prior, observed_shape="INSUFFICIENT",
            match=None,
            spearman_rho=float("nan"), spearman_pvalue=float("nan"),
            bin_edges=tuple(bin_edges), bin_means=(), bin_counts=(),
            peak_bin_idx=None,
            overall_ev=float(profits.mean()), overall_n=n_total,
        )

    # Bin assignment via digitize. Inner bins are half-open [lo, hi);
    # last bin includes the right edge.
    bin_idx = np.digitize(vals.values, bin_edges[1:-1], right=False)
    bin_idx = np.clip(bin_idx, 0, len(bin_edges) - 2)

    bin_means = np.full(cfg.n_bins, np.nan)
    bin_counts = np.zeros(cfg.n_bins, dtype=int)
    profits_arr = profits.values

    for b in range(cfg.n_bins):
        mask = bin_idx == b
        n_b = int(mask.sum())
        bin_counts[b] = n_b
        if n_b >= cfg.min_bin_samples:
            bin_means[b] = float(profits_arr[mask].mean())

    # Spearman on (bin_index, bin_mean) over valid bins
    valid_bins = ~np.isnan(bin_means)
    if valid_bins.sum() < 3:
        rho, pval = float("nan"), float("nan")
    else:
        x = np.arange(cfg.n_bins)[valid_bins]
        y = bin_means[valid_bins]
        rho, pval = stats.spearmanr(x, y)
        rho = float(rho) if not np.isnan(rho) else 0.0
        pval = float(pval) if not np.isnan(pval) else 1.0

    observed, peak_idx = _classify_shape(
        bin_means, bin_counts, rho, pval, cfg,
    )

    # Match: only if prior is defined AND observed is a concrete shape
    if prior is None:
        match: Optional[bool] = None
    elif observed in ("INSUFFICIENT", "FLAT"):
        match = None  # can't assert mismatch on a non-decision
    else:
        match = (observed == prior)

    return FeatureShapeAnalysis(
        feature=feature, category=category,
        prior_shape=prior, observed_shape=observed,
        match=match,
        spearman_rho=rho, spearman_pvalue=pval,
        bin_edges=tuple(float(e) for e in bin_edges),
        bin_means=tuple(float(m) for m in bin_means),
        bin_counts=tuple(int(c) for c in bin_counts),
        peak_bin_idx=peak_idx,
        overall_ev=float(profits_arr.mean()), overall_n=n_total,
    )


def _classify_shape(
    bin_means: np.ndarray,
    bin_counts: np.ndarray,
    rho: float,
    pval: float,
    cfg: EDAConfig,
) -> tuple[str, Optional[int]]:
    """Return (shape_label, peak_bin_idx)."""
    valid = ~np.isnan(bin_means)
    if valid.sum() < 3:
        return "INSUFFICIENT", None

    y = bin_means[valid]
    n_valid = len(y)

    # Monotone?
    if not np.isnan(rho) and not np.isnan(pval) and pval < cfg.monotone_pvalue:
        if rho >= cfg.monotone_rho_threshold:
            return "MONO_UP", None
        if rho <= -cfg.monotone_rho_threshold:
            return "MONO_DOWN", None

    # Band (inverted-U): peak meaningfully above edges
    peak_idx_valid = int(np.argmax(y))
    peak_ev = float(y[peak_idx_valid])
    edge_mean = float((y[0] + y[-1]) / 2.0)
    y_std = float(y.std(ddof=1)) if n_valid >= 2 else 0.0

    # Need an interior peak for band
    interior_peak = 1 <= peak_idx_valid <= (n_valid - 2)

    if y_std > 1e-9 and interior_peak:
        if (peak_ev - edge_mean) > cfg.band_peak_sigma * y_std:
            # Map valid-index peak back to original bin index
            valid_positions = np.where(valid)[0]
            return "BAND", int(valid_positions[peak_idx_valid])

    # U-shape: edges meaningfully above middle
    mid_start = n_valid // 3
    mid_end = 2 * n_valid // 3
    if mid_end > mid_start:
        mid_mean = float(y[mid_start:mid_end].mean())
        if y_std > 1e-9 and (edge_mean - mid_mean) > cfg.band_peak_sigma * y_std:
            return "U_SHAPE", None

    return "FLAT", None


# ─── Correlation ─────────────────────────────────────────────────

def _compute_correlation(
    df: pd.DataFrame, features: list[str],
) -> pd.DataFrame:
    """Spearman correlation matrix over available features."""
    sub = df[features].apply(pd.to_numeric, errors="coerce")
    return sub.corr(method="spearman")


def _find_redundant_pairs(
    corr_matrix: pd.DataFrame,
    cfg: EDAConfig,
) -> list[RedundantPair]:
    """Upper-triangle pairs with |rho| > threshold, sorted by |rho| desc."""
    features = list(corr_matrix.columns)
    pairs: list[RedundantPair] = []
    for i, fa in enumerate(features):
        for fb in features[i + 1:]:
            rho = corr_matrix.loc[fa, fb]
            if pd.isna(rho):
                continue
            if abs(rho) > cfg.correlation_threshold:
                pairs.append(RedundantPair(fa, fb, float(rho)))
    pairs.sort(key=lambda p: -abs(p.rho))
    return pairs


# ─── Temporal stability ──────────────────────────────────────────

def _compute_stability(
    df: pd.DataFrame,
    features: list[str],
    cfg: EDAConfig,
) -> list[StabilityEntry]:
    n = len(df)
    n_blocks = cfg.n_temporal_blocks
    block_size = n // n_blocks
    if block_size < cfg.min_block_samples:
        return []

    results: list[StabilityEntry] = []
    for feat in features:
        vals = pd.to_numeric(df[feat], errors="coerce")
        block_means: list[float] = []
        block_stds: list[float] = []
        for b in range(n_blocks):
            start = b * block_size
            end = (b + 1) * block_size if b < n_blocks - 1 else n
            block = vals.iloc[start:end].dropna()
            if len(block) >= 2:
                block_means.append(float(block.mean()))
                block_stds.append(float(block.std(ddof=1)))
            else:
                block_means.append(float("nan"))
                block_stds.append(float("nan"))

        means_arr = np.array(block_means)
        valid = ~np.isnan(means_arr)
        if valid.sum() < 2:
            cv = float("nan")
            unstable = False
        else:
            m = float(means_arr[valid].mean())
            s = float(means_arr[valid].std(ddof=1))
            if abs(m) > 1e-9:
                cv = s / abs(m)
            else:
                cv = 0.0 if s < 1e-9 else float("inf")
            unstable = (not np.isnan(cv)) and (cv > 1.0)

        results.append(StabilityEntry(
            feature=feat,
            block_means=tuple(block_means),
            block_stds=tuple(block_stds),
            cv=cv,
            unstable=unstable,
        ))
    return results


# ─── Baseline ────────────────────────────────────────────────────

def _compute_baseline(df: pd.DataFrame) -> dict:
    profits = pd.to_numeric(df["_profit"], errors="coerce").dropna()
    if len(profits) == 0:
        return {}

    wins = profits[profits > 0]
    losses = profits[profits < 0]

    pos_sum = float(wins.sum()) if len(wins) else 0.0
    neg_sum = float(abs(losses.sum())) if len(losses) else 0.0
    pf = (pos_sum / neg_sum) if neg_sum > 0 else float("inf")

    out = {
        "n": int(len(profits)),
        "wr": round(float((profits > 0).mean()), 4),
        "ev": round(float(profits.mean()), 4),
        "pf": round(pf, 4) if pf != float("inf") else None,
        "std": round(float(profits.std(ddof=1)) if len(profits) > 1 else 0.0, 4),
    }

    # Optional MAE/MFE means if columns present
    if "maeATR" in df.columns:
        mae = pd.to_numeric(df["maeATR"], errors="coerce").dropna()
        if len(mae):
            out["mae_atr_mean"] = round(float(mae.mean()), 4)
    if "mfeATR" in df.columns:
        mfe = pd.to_numeric(df["mfeATR"], errors="coerce").dropna()
        if len(mfe):
            out["mfe_atr_mean"] = round(float(mfe.mean()), 4)

    return out


# ─── Helpers ─────────────────────────────────────────────────────

def _build_feature_category_map(pre_registered: dict) -> dict:
    out: dict[str, str] = {}
    for cat, features in pre_registered.items():
        for f in features:
            out[f] = cat
    return out


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(
    result: LayerThreeResult,
    corr_matrix: pd.DataFrame,
    output_dir: Path,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    # Shape analysis
    pd.DataFrame(
        [a.to_dict() for a in result.shape_analyses]
    ).to_csv(output_dir / "feature_shape_analysis.csv", index=False)

    # Shape mismatch report — only mismatches
    mismatches = [a for a in result.shape_analyses if a.match is False]
    if mismatches:
        pd.DataFrame(
            [a.to_dict() for a in mismatches]
        ).to_csv(output_dir / "shape_mismatch_report.csv", index=False)

    # Correlation matrix (long upper-triangle form)
    rows = []
    feats = list(corr_matrix.columns)
    for i, fa in enumerate(feats):
        for fb in feats[i + 1:]:
            rho = corr_matrix.loc[fa, fb]
            if pd.isna(rho):
                continue
            rows.append({
                "feature_a": fa, "feature_b": fb,
                "spearman_rho": round(float(rho), 4),
            })
    if rows:
        pd.DataFrame(rows).to_csv(
            output_dir / "feature_correlation_matrix.csv", index=False,
        )

    # Redundant pairs
    if result.redundant_pairs:
        pd.DataFrame(
            [p.to_dict() for p in result.redundant_pairs]
        ).to_csv(output_dir / "redundant_feature_pairs.csv", index=False)

    # Stability
    if result.stability:
        pd.DataFrame(
            [s.to_dict() for s in result.stability]
        ).to_csv(output_dir / "feature_stability.csv", index=False)

    # Baseline
    with (output_dir / "baseline_stats.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.baseline, f, indent=2, default=str)

    # Summary
    with (output_dir / "layer_three_summary.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.summary_dict(), f, indent=2, default=str)
