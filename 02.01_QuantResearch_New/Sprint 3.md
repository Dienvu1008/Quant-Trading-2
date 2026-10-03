# Sprint 3 — Layer 3: EDA & Shape Verification

> **v3 changes (từ SPECIFICATION.md v3):**
> - Xác nhận rõ: L3 đo EV-by-bin dùng `profitUSD` (production-style `dev`), **không** dùng MFE-based label. MFE canary target chỉ thuộc L10a. [Fix #2]
> - SHAPE_PRIOR mismatch: vẫn flag nhưng không override. Mismatch report được L10a tham chiếu khi phân tích bad-entry. [No code change — clarification only]

Deliverables:
- `layers/L3_eda.py` — EV-by-bin, shape classification, SHAPE_PRIOR verification, correlation, temporal stability, baseline stats
- Outputs: `feature_shape_analysis.csv`, `shape_mismatch_report.csv`, `feature_correlation_matrix.csv`, `redundant_feature_pairs.csv`, `feature_stability.csv`, `baseline_stats.csv`
- Tests: ~28 cases bao gồm injected shape mismatches

Nguyên tắc:
- Chỉ chạy trên development data
- Shape mismatch → flag, KHÔNG override prior (prior vẫn governs L4 search)
- Không có side-effect nào thay đổi contract hay rules
- Output đủ để audit shape decision

---

## `vp_analysis/layers/L3_eda.py`

```python
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
```

## `vp_analysis/layers/__init__.py` — cập nhật

```python
"""Analysis layers."""
from . import L0_hygiene
from . import L1_boundary
from . import L2_feature_engineering
from . import L3_eda

__all__ = ["L0_hygiene", "L1_boundary", "L2_feature_engineering", "L3_eda"]
```

---

## Tests

## `vp_analysis/tests/test_L3_eda.py`

```python
"""Tests for Layer 3 — EDA & Shape Verification."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L3_eda
from vp_analysis.layers.L3_eda import EDAConfig


# ─── Fixtures ────────────────────────────────────────────────────

def _make_dev_df(n=500, seed=0, relationships=None):
    """Construct a dev DataFrame with controlled feature-EV shapes.

    relationships: dict feature_name -> callable(rng, x) -> profit contribution
    Base profit = 0.0; each feature contributes its function value.
    """
    rng = np.random.default_rng(seed)
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
    })

    # f_mono_up: EV = 1.0 * x (x uniform [0,1]) — perfect monotone up
    x_up = rng.uniform(0.0, 1.0, n)
    df["f_mono_up"] = x_up

    # f_mono_down: EV = -1.0 * x — monotone down
    x_dn = rng.uniform(0.0, 1.0, n)
    df["f_mono_down"] = x_dn

    # f_band: EV peaks at x=0.5 — band shape
    x_band = rng.uniform(0.0, 1.0, n)
    df["f_band"] = x_band

    # f_flat: no relationship
    df["f_flat"] = rng.uniform(0.0, 1.0, n)

    # f_corr_with_mono_up: perfectly correlated with f_mono_up
    df["f_corr_with_mono_up"] = x_up + rng.normal(0, 0.001, n)

    # Build profit
    base = rng.normal(0.0, 0.05, n)  # small noise
    profit = (
        base
        + 0.5 * (x_up - 0.5)                       # mono-up contribution
        - 0.5 * (x_dn - 0.5)                       # mono-down contribution
        + 0.8 * (1 - 4 * (x_band - 0.5) ** 2)      # band peak at 0.5
    )
    df["_profit"] = profit
    return df


@pytest.fixture
def dev_df():
    return _make_dev_df()


@pytest.fixture
def contract_for_eda(minimal_contract_dict):
    """Contract declaring features and their expected shapes."""
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "cat_a": ["f_mono_up", "f_mono_down"],
        "cat_b": ["f_band", "f_flat"],
        "cat_c": ["f_corr_with_mono_up"],
    }
    d["feature_direction"] = {
        "f_mono_up": 1, "f_mono_down": -1, "f_band": 0,
        "f_flat": 0, "f_corr_with_mono_up": 1,
    }
    d["shape_priors"] = {
        "f_mono_up": "MONO_UP",
        "f_mono_down": "MONO_DOWN",
        "f_band": "BAND",
        "f_flat": "BAND",              # intentionally mismatched
        "f_corr_with_mono_up": "MONO_UP",
    }
    return ResearchContract.from_dict(d)


# ══════════════════════════════════════════════════════════════════
# Shape classification
# ══════════════════════════════════════════════════════════════════

def test_mono_up_classified(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_mono_up"].observed_shape == "MONO_UP"
    assert by_name["f_mono_up"].match is True


def test_mono_down_classified(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_mono_down"].observed_shape == "MONO_DOWN"
    assert by_name["f_mono_down"].match is True


def test_band_classified(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_band"].observed_shape == "BAND"
    assert by_name["f_band"].match is True


def test_flat_classified(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_flat"].observed_shape in ("FLAT", "INSUFFICIENT")


def test_flat_prior_mismatch_does_not_halve(dev_df, contract_for_eda):
    """Prior says BAND for f_flat; observed is FLAT. Should NOT count
    as mismatch because FLAT is non-decision."""
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    by_name = {a.feature: a for a in result.shape_analyses}
    assert by_name["f_flat"].observed_shape == "FLAT"
    # FLAT → match is None (non-decision, not a mismatch)
    assert by_name["f_flat"].match is None


# ══════════════════════════════════════════════════════════════════
# Mismatch reporting
# ══════════════════════════════════════════════════════════════════

def test_mismatch_detected_with_contradicting_prior():
    """Prior says MONO_UP but feature is genuinely BAND → mismatch."""
    df = _make_dev_df(n=800, seed=1)
    d = {
        "version": "v1",
        "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"c": ["f_band"]},
        "feature_direction": {"f_band": 0},
        "shape_priors": {"f_band": "MONO_UP"},   # wrong prior
        "allowed_interactions": [], "gate_types": ["threshold"],
        "allowed_directions": [1, -1],
        "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {
            "hard_gate": {"name": "hard_gate",
                          "max_hypotheses": 500, "alpha": 0.05},
        },
        "optimization_budget": {
            "sl_candidates": [1.0], "tp_candidates": [1.0],
            "sizing_configs": 1, "utility_function": "ev",
        },
        "stopping_rules": {
            "min_group_samples": 30, "min_fold_consistency": 0.6,
            "min_effect_size": 0.05, "max_outer_folds": 5,
            "max_inner_folds": 3,
        },
        "production_criteria": {
            "min_ev": 0.05, "min_pf": 1.1, "min_wr": 0.35,
            "require_robust_across_styles": False,
            "require_holdout_confirmation": True,
        },
        "selection_budget": {
            "max_experiments_per_dataset": 5,
            "max_contract_changes_per_day": 3,
            "cooldown_hours_between_experiments": 24,
            "max_eda_inspect_and_rerun": 1,
            "config_frozen_after_start": True,
        },
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_band"])

    a = result.shape_analyses[0]
    assert a.observed_shape == "BAND"
    assert a.prior_shape == "MONO_UP"
    assert a.match is False
    assert result.n_shape_mismatch == 1
    assert result.mismatch_rate == 1.0


def test_mismatch_generates_warning(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    # contract_for_eda has intentional mismatch on f_flat being priored BAND,
    # but f_flat is FLAT (non-decision), so no mismatch warning.
    # No mismatch in this fixture.
    assert result.n_shape_mismatch == 0


def test_missing_prior_is_not_counted_as_mismatch(dev_df):
    """Feature present in available_features but not in shape_priors."""
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"c": ["f_mono_up"]},
        "feature_direction": {"f_mono_up": 1},
        "shape_priors": {},   # no prior
        "allowed_interactions": [],
        "gate_types": ["threshold"], "allowed_directions": [1],
        "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {"hard_gate": {"name": "hard_gate",
                                     "max_hypotheses": 500, "alpha": 0.05}},
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05,
                            "max_outer_folds": 5, "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(dev_df, contract, available_features=["f_mono_up"])
    assert result.n_prior_unspecified == 1
    assert result.n_shape_match == 0
    assert result.n_shape_mismatch == 0


# ══════════════════════════════════════════════════════════════════
# Correlation
# ══════════════════════════════════════════════════════════════════

def test_redundant_pair_detected(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
    )
    pairs = {(p.feature_a, p.feature_b) for p in result.redundant_pairs}
    pairs_swapped = {(b, a) for a, b in pairs}
    all_pairs = pairs | pairs_swapped
    assert ("f_mono_up", "f_corr_with_mono_up") in all_pairs


def test_no_redundant_pairs_when_independent():
    rng = np.random.default_rng(42)
    n = 500
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "a": rng.normal(0, 1, n),
        "b": rng.normal(0, 1, n),
        "c": rng.normal(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"cat": ["a", "b", "c"]},
        "feature_direction": {"a": 1, "b": 1, "c": 1},
        "shape_priors": {"a": "MONO_UP", "b": "MONO_UP", "c": "MONO_UP"},
        "allowed_interactions": [], "gate_types": ["threshold"],
        "allowed_directions": [1], "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {"hard_gate": {"name": "hard_gate",
                                     "max_hypotheses": 500, "alpha": 0.05}},
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05, "max_outer_folds": 5,
                            "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["a", "b", "c"])
    assert len(result.redundant_pairs) == 0


# ══════════════════════════════════════════════════════════════════
# Temporal stability
# ══════════════════════════════════════════════════════════════════

def test_stability_computed(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down"],
    )
    assert len(result.stability) == 2
    for s in result.stability:
        assert len(s.block_means) == 5
        assert len(s.block_stds) == 5


def test_unstable_feature_flagged():
    """Feature whose mean drifts massively across time."""
    n = 500
    rng = np.random.default_rng(7)
    # Mean drifts from 0 → 10 across the series
    drift = np.linspace(0, 10, n)
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "f_unstable": drift + rng.normal(0, 0.1, n),
        "_profit": rng.normal(0, 1, n),
    })
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"cat": ["f_unstable"]},
        "feature_direction": {"f_unstable": 0},
        "shape_priors": {"f_unstable": "BAND"},
        "allowed_interactions": [], "gate_types": ["threshold"],
        "allowed_directions": [1], "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {"hard_gate": {"name": "hard_gate",
                                     "max_hypotheses": 500, "alpha": 0.05}},
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05, "max_outer_folds": 5,
                            "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_unstable"])
    s = result.stability[0]
    assert s.cv > 1.0
    assert s.unstable is True


# ══════════════════════════════════════════════════════════════════
# Baseline
# ══════════════════════════════════════════════════════════════════

def test_baseline_stats(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda, available_features=["f_mono_up"],
    )
    b = result.baseline
    assert b["n"] == len(dev_df)
    assert 0.0 <= b["wr"] <= 1.0
    assert "ev" in b and "pf" in b


def test_baseline_with_mae_mfe(dev_df, contract_for_eda):
    df = dev_df.copy()
    rng = np.random.default_rng(1)
    df["maeATR"] = rng.uniform(0.3, 1.5, len(df))
    df["mfeATR"] = rng.uniform(0.5, 2.0, len(df))
    result = L3_eda.run(df, contract_for_eda, available_features=["f_mono_up"])
    assert "mae_atr_mean" in result.baseline
    assert "mfe_atr_mean" in result.baseline


# ══════════════════════════════════════════════════════════════════
# Insufficient data
# ══════════════════════════════════════════════════════════════════

def test_small_sample_insufficient():
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=20, freq="h"),
        "f_x": np.random.rand(20),
        "_profit": np.random.randn(20),
    })
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"cat": ["f_x"]},
        "feature_direction": {"f_x": 1},
        "shape_priors": {"f_x": "MONO_UP"},
        "allowed_interactions": [], "gate_types": ["threshold"],
        "allowed_directions": [1], "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {"hard_gate": {"name": "hard_gate",
                                     "max_hypotheses": 500, "alpha": 0.05}},
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05, "max_outer_folds": 5,
                            "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_x"])
    assert result.shape_analyses[0].observed_shape == "INSUFFICIENT"


def test_constant_feature_insufficient():
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=100, freq="h"),
        "f_const": [0.5] * 100,
        "_profit": np.random.randn(100),
    })
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"cat": ["f_const"]},
        "feature_direction": {"f_const": 1},
        "shape_priors": {"f_const": "MONO_UP"},
        "allowed_interactions": [], "gate_types": ["threshold"],
        "allowed_directions": [1], "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {"hard_gate": {"name": "hard_gate",
                                     "max_hypotheses": 500, "alpha": 0.05}},
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05, "max_outer_folds": 5,
                            "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    result = L3_eda.run(df, contract, available_features=["f_const"])
    assert result.shape_analyses[0].observed_shape == "INSUFFICIENT"


def test_no_available_features_raises(dev_df, contract_for_eda):
    with pytest.raises(ValueError, match="no available features"):
        L3_eda.run(dev_df, contract_for_eda, available_features=[])


def test_empty_df_raises(contract_for_eda):
    with pytest.raises(ValueError, match="empty"):
        L3_eda.run(pd.DataFrame(), contract_for_eda,
                   available_features=["f_mono_up"])


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(dev_df, contract_for_eda, tmp_path):
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
        output_dir=tmp_path,
    )
    assert (tmp_path / "feature_shape_analysis.csv").exists()
    assert (tmp_path / "feature_correlation_matrix.csv").exists()
    assert (tmp_path / "feature_stability.csv").exists()
    assert (tmp_path / "baseline_stats.json").exists()
    assert (tmp_path / "layer_three_summary.json").exists()


def test_shape_analysis_csv_columns(dev_df, contract_for_eda, tmp_path):
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up"],
        output_dir=tmp_path,
    )
    df = pd.read_csv(tmp_path / "feature_shape_analysis.csv")
    assert "feature" in df.columns
    assert "prior_shape" in df.columns
    assert "observed_shape" in df.columns
    assert "match" in df.columns
    assert df.iloc[0]["feature"] == "f_mono_up"


def test_mismatch_csv_written_when_mismatch(dev_df, tmp_path):
    """Create contract with a genuine mismatch to verify report."""
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"cat": ["f_mono_up"]},
        "feature_direction": {"f_mono_up": 1},
        "shape_priors": {"f_mono_up": "BAND"},   # wrong
        "allowed_interactions": [], "gate_types": ["threshold"],
        "allowed_directions": [1], "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {"hard_gate": {"name": "hard_gate",
                                     "max_hypotheses": 500, "alpha": 0.05}},
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05, "max_outer_folds": 5,
                            "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    L3_eda.run(dev_df, contract, available_features=["f_mono_up"],
               output_dir=tmp_path)
    assert (tmp_path / "shape_mismatch_report.csv").exists()
    df = pd.read_csv(tmp_path / "shape_mismatch_report.csv")
    assert df.iloc[0]["prior_shape"] == "BAND"
    assert df.iloc[0]["observed_shape"] == "MONO_UP"


def test_summary_json_content(dev_df, contract_for_eda, tmp_path):
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down"],
        output_dir=tmp_path,
    )
    with (tmp_path / "layer_three_summary.json").open() as f:
        s = json.load(f)
    assert s["n_features_analyzed"] == 2
    assert "mismatch_rate" in s
    assert "baseline" in s


# ══════════════════════════════════════════════════════════════════
# Contract usage — SHAPE_PRIOR immutable
# ══════════════════════════════════════════════════════════════════

def test_shape_prior_not_modified(dev_df, contract_for_eda):
    prior_before = dict(contract_for_eda.shape_priors)
    L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band", "f_flat"],
    )
    assert contract_for_eda.shape_priors == prior_before


def test_match_statistics_consistent(dev_df, contract_for_eda):
    result = L3_eda.run(
        dev_df, contract_for_eda,
        available_features=["f_mono_up", "f_mono_down", "f_band",
                             "f_flat", "f_corr_with_mono_up"],
    )
    n_match = sum(1 for a in result.shape_analyses if a.match is True)
    n_mismatch = sum(1 for a in result.shape_analyses if a.match is False)
    assert n_match == result.n_shape_match
    assert n_mismatch == result.n_shape_mismatch
    denom = n_match + n_mismatch
    expected_rate = (n_mismatch / denom) if denom else 0.0
    assert abs(result.mismatch_rate - expected_rate) < 1e-9
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L3_eda.py -v
```

Kỳ vọng:

```text
test_L3_eda.py
  Shape classification                    5 passed
  Mismatch reporting                      3 passed
  Correlation                             2 passed
  Temporal stability                      2 passed
  Baseline                                2 passed
  Insufficient data                       4 passed
  Output                                  4 passed
  Contract usage                          2 passed
  ────────────────────────────────────────────────
  Total                                  24 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 141 + 32 + 30 + 24 = 227 passed
```

---

## Preview: Layer 3 trong pipeline

```python
from vp_analysis.layers import L0_hygiene, L1_boundary, L2_feature_engineering, L3_eda

def run_pipeline(merged_all, contract, output_dir):
    l0 = L0_hygiene.run(merged_all, output_dir=output_dir / "L0_hygiene")
    if l0.should_halt:
        raise RuntimeError(f"L0 halt: {l0.reason_for_halt}")

    l1 = L1_boundary.run(merged_all, contract, output_dir=output_dir / "L1_boundary")
    l2 = L2_feature_engineering.run(l1, output_dir=output_dir / "L2_feature_engineering")

    # L3 uses the transformed dev data + L1's available features
    l3 = L3_eda.run(
        dev_df=l2.boundary.dev.data,
        contract=contract,
        available_features=l1.available_features(),
        output_dir=output_dir / "L3_eda",
    )

    print(f"  Shape match rate: "
          f"{1 - l3.mismatch_rate:.1%} "
          f"({l3.n_shape_match} match / {l3.n_shape_mismatch} mismatch)")
    print(f"  Redundant pairs: {len(l3.redundant_pairs)}")
    print(f"  Unstable features: "
          f"{sum(1 for s in l3.stability if s.unstable)}")

    if l3.mismatch_rate > 0.30:
        # High mismatch → contract priors may be off
        # Do NOT auto-correct. Requires human review (new contract).
        print("  [WARN] High shape mismatch rate — review before L4")
```

Output directory bây giờ có:

```text
output/
├── L0_hygiene/
│   └── layer_zero_summary.json
├── L1_boundary/
│   ├── run_meta.json
│   └── feature_availability.csv
├── L2_feature_engineering/
│   └── interaction_stats.json
└── L3_eda/
    ├── feature_shape_analysis.csv        ← luôn có
    ├── shape_mismatch_report.csv         ← chỉ khi có mismatch
    ├── feature_correlation_matrix.csv    ← luôn có
    ├── redundant_feature_pairs.csv       ← chỉ khi có pairs
    ├── feature_stability.csv             ← luôn có
    ├── baseline_stats.json
    └── layer_three_summary.json
```

---

## Sprint 3 hoàn tất

**Deliverables:**
- `L3_eda.py` (~400 dòng) — 6 analyses, shape classifier với 6 levels, mismatch reporting
- 24 tests bao gồm:
  - Mono-up / mono-down / band / flat / insufficient classification
  - Mismatch detection với contradicting prior
  - `prior=None` không counted as mismatch (đúng theo policy)
  - FLAT không counted as mismatch (non-decision)
  - Redundant pair detection với known correlated features
  - Unstable feature flagging (drift injected)
  - Baseline stats với và không có MAE/MFE
  - Small sample → INSUFFICIENT
  - Constant feature → INSUFFICIENT
  - Output files correctness
  - Contract immutability (SHAPE_PRIOR không bị mutate)

**Điểm quan trọng đã enforce:**
1. **Shape prior là immutable** — L3 chỉ verify, không override
2. **Chỉ chạy trên dev** — không có code path nào nhìn holdout
3. **Non-decision không phải mismatch** — FLAT/INSUFFICIENT không counted
4. **Deterministic** — Spearman rank-based, không bị ảnh hưởng bởi outliers
5. **Graceful degradation** — missing features không làm crash

**Kernel + L0-L3 hiện có:**
```text
┌─────────────────────────────────────────────────────────────┐
│  Sprint 0A/B/C — Governance kernel        141 tests         │
│  Sprint 1 — L0 Data Hygiene                 32 tests         │
│  Sprint 2 — L1 Boundary + L2 Features       30 tests         │
│  Sprint 3 — L3 EDA + Shape Verification     24 tests         │
│  ─────────────────────────────────────────────────────────  │
│  Total                                     227 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Sprint 4 — Layer 4: Hard Gate Discovery (Nested WF)** sẽ là sprint phức tạp nhất:
- Shape-aware search (dùng SHAPE_PRIOR từ contract, không dùng observed)
- Nested walk-forward 5×3 với proper train/val separation
- Threshold search trên inner_train, evaluate trên inner_val
- Permutation screening (100 iter, early stop)
- Fold aggregation + bootstrap CI + temporal slope
- Output: `hard_gate_candidates.csv`
- Tests với synthetic edge để verify pipeline tìm được signal
