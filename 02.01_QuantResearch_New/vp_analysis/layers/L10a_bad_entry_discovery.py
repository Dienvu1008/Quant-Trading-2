"""Layer 10a — Bad Entry Discovery (Development Phase).

Runs on dev_all_styles (3-style development subset) BEFORE L6 so that
p-values can enter the FDR pool 'bad_entry' at L6.

The "bad entry" canary target is MFE-based (not profitUSD):
    canary_bad = 1   if MFE_max_across_3_styles < threshold
    canary_bad = 0   otherwise

Rationale: a genuinely poor entry will fail to reach even a modest MFE
across ALL three trailing styles. This is a more robust label than a
single-style profit outcome because it is exit-policy-independent.

Pipeline:
  1. For each signal (signalId), compute max(mfeATR) across its 3 styles.
  2. Label as "bad entry" if max_mfe < contract.bad_entry_canary_target threshold.
  3. Screen features: for each feature region, binomial test whether
     bad_rate_in_region > base_bad_rate.
  4. Candidates with p < alpha go to L6 FDR pool 'bad_entry'.
  5. n_total_bad hypotheses is logged for L6 conservative FDR padding.

Output:
  - LayerTenAResult with bad_entry_candidates (not yet FDR'd)
  - n_total_hypotheses_bad (count of hypotheses tested)
  - canary_labels.csv, bad_entry_features.csv, composite_bad_filter_candidate.json
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from scipy import stats


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class BadEntryDiscoveryConfig:
    # MFE canary threshold — overrides contract.bad_entry_canary_target
    # if set; otherwise contract value is used
    mfe_threshold_override: Optional[float] = None

    # Column names
    signal_id_col: str = "signalId"
    style_col: str = "trailStyle"
    mfe_col: str = "mfeATR"

    # Feature region screening
    percentile_low: float = 10.0      # bottom X% of feature = "low extreme"
    percentile_high: float = 90.0     # top X%
    percentile_band_low: float = 30.0
    percentile_band_high: float = 70.0
    min_region_samples: int = 15      # min trades in region to test
    binom_alpha: float = 0.10         # pre-FDR threshold (liberal)

    # Group columns (for per-symbol/setup analysis)
    symbol_col: str = "symbol"
    setup_col: str = "setupType"
    min_group_signals: int = 30  # min labeled signals in group to run per-group

    # Composite filter
    min_votes: int = 1                # votes needed to flag bad entry


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class CanaryLabelStats:
    n_signals: int
    n_labeled: int    # signals with all 3 styles present
    n_bad: int
    n_good: int
    base_bad_rate: float
    mfe_threshold: float

    def to_dict(self) -> dict:
        return {
            "n_signals": int(self.n_signals),
            "n_labeled": int(self.n_labeled),
            "n_bad": int(self.n_bad),
            "n_good": int(self.n_good),
            "base_bad_rate": round(self.base_bad_rate, 6),
            "mfe_threshold": round(self.mfe_threshold, 6),
        }


@dataclass(frozen=True)
class BadEntryCandidate:
    """One candidate bad-entry rule (pre-FDR). Goes into FDR pool 'bad_entry'."""
    feature: str
    rule_type: str        # "low_extreme" | "high_extreme" | "mid_band"
    threshold_low: Optional[float]
    threshold_high: Optional[float]
    n_pass: int
    bad_rate_in_region: float
    base_bad_rate: float
    lift: float           # bad_rate_in_region / base_bad_rate
    pvalue: float         # binomial test p-value (pre-FDR)
    fdr_reject: bool = False

    def to_dict(self) -> dict:
        return {
            "feature": self.feature,
            "rule_type": self.rule_type,
            "threshold_low": (round(self.threshold_low, 6)
                              if self.threshold_low is not None else None),
            "threshold_high": (round(self.threshold_high, 6)
                               if self.threshold_high is not None else None),
            "n_pass": int(self.n_pass),
            "bad_rate_in_region": round(self.bad_rate_in_region, 6),
            "base_bad_rate": round(self.base_bad_rate, 6),
            "lift": round(self.lift, 6),
            "pvalue": round(self.pvalue, 6),
            "fdr_reject": self.fdr_reject,
        }


@dataclass(frozen=True)
class LayerTenAResult:
    canary_stats: CanaryLabelStats
    bad_entry_candidates: tuple    # of BadEntryCandidate (pre-FDR)
    n_total_hypotheses: int        # for L6 conservative FDR padding
    filter_spec: dict              # composite filter spec
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "canary_stats": self.canary_stats.to_dict(),
            "n_candidates_pre_fdr": len(self.bad_entry_candidates),
            "n_total_hypotheses": self.n_total_hypotheses,
            "filter_spec_features": len(self.filter_spec.get("features", [])),
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_all_styles_df: pd.DataFrame,
    contract,
    available_features,
    output_dir: Optional[Path] = None,
    config: Optional[BadEntryDiscoveryConfig] = None,
) -> LayerTenAResult:
    """Execute Layer 10a on 3-style development data.

    dev_all_styles_df: production-style dev with all 3 trailStyles per signal.
    contract: must have bad_entry_canary_target defined.
    available_features: features to screen (from L1).

    Returns candidates with p-values for FDR pool 'bad_entry' at L6.
    Does NOT touch holdout.
    """
    cfg = config or BadEntryDiscoveryConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"
    warnings: list[str] = []

    if dev_all_styles_df is None or len(dev_all_styles_df) == 0:
        raise ValueError("L10a: dev_all_styles_df is empty")

    # Resolve MFE threshold from contract or override
    mfe_threshold = _resolve_mfe_threshold(contract, cfg, warnings)

    # ─── 1. Build MFE-based canary labels ───────────────────────
    canary_stats, per_signal_labels = _build_mfe_canary_labels(
        dev_all_styles_df, mfe_threshold, cfg, warnings,
    )

    if canary_stats.n_labeled < cfg.min_region_samples * 3:
        warnings.append(
            f"Only {canary_stats.n_labeled} labeled signals; "
            "bad-entry screening skipped (insufficient data)"
        )
        return _empty_result(canary_stats, warnings, ran_at)

    if canary_stats.base_bad_rate <= 0.0 or canary_stats.base_bad_rate >= 1.0:
        warnings.append(
            f"base_bad_rate={canary_stats.base_bad_rate:.3f} is degenerate; "
            "bad-entry screening skipped"
        )
        return _empty_result(canary_stats, warnings, ran_at)

    # ─── 2. Attach labels to dev data (one row per signal) ──────
    per_signal_df = _build_per_signal_df(
        dev_all_styles_df, per_signal_labels, available_features, cfg,
    )

    # ─── 3. Screen features via binomial test ───────────────────
    usable = [f for f in available_features
              if f in per_signal_df.columns]
    candidates_raw = _screen_features(
        per_signal_df, usable, canary_stats.base_bad_rate, cfg,
    )

    n_total_hypotheses = len(candidates_raw)

    # ─── 4. Filter by pre-FDR alpha ─────────────────────────────
    candidates_passing = [
        c for c in candidates_raw if c.pvalue <= cfg.binom_alpha
    ]

    # ─── 5. Build composite filter spec (global + per-group) ──────
    # Global filter from all data
    global_filter = {
        "features": [
            {"feature": c.feature, "rule_type": c.rule_type,
             "threshold_low": c.threshold_low, "threshold_high": c.threshold_high}
            for c in candidates_passing
        ],
        "min_votes": cfg.min_votes,
    }

    # Per-(symbol, setup) groups — same approach as L10
    group_filters: dict = {}
    has_group_cols = (
        cfg.symbol_col in dev_all_styles_df.columns and
        cfg.setup_col in dev_all_styles_df.columns
    )
    if has_group_cols:
        for (sym, stp), grp_df in dev_all_styles_df.groupby(
            [cfg.symbol_col, cfg.setup_col]
        ):
            group_key = f"{sym}|{stp}"
            grp_canary, grp_labels = _build_mfe_canary_labels(
                grp_df, mfe_threshold, cfg, [],
            )
            if grp_canary.n_labeled < cfg.min_group_signals:
                continue
            if grp_canary.base_bad_rate <= 0.0 or grp_canary.base_bad_rate >= 1.0:
                continue
            grp_per_sig = _build_per_signal_df(
                grp_df, grp_labels, available_features, cfg,
            )
            grp_usable = [f for f in available_features if f in grp_per_sig.columns]
            grp_cands_raw = _screen_features(
                grp_per_sig, grp_usable, grp_canary.base_bad_rate, cfg,
            )
            grp_passing = [c for c in grp_cands_raw if c.pvalue <= cfg.binom_alpha]
            if grp_passing:
                group_filters[group_key] = {
                    "features": [
                        {"feature": c.feature, "rule_type": c.rule_type,
                         "threshold_low": c.threshold_low, "threshold_high": c.threshold_high}
                        for c in grp_passing
                    ],
                    "min_votes": cfg.min_votes,
                }
    n_groups = len(group_filters)
    print(f"  [L10a] {n_groups} per-group MFE filters, {len(candidates_passing)} global rules")

    filter_spec = {
        "groups": group_filters,
        "global_fallback": global_filter,
        "min_votes": cfg.min_votes,
        "mfe_threshold": mfe_threshold,
    }

    result = LayerTenAResult(
        canary_stats=canary_stats,
        bad_entry_candidates=tuple(candidates_raw),   # all, for FDR pool
        n_total_hypotheses=n_total_hypotheses,
        filter_spec=filter_spec,
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Canary labeling ─────────────────────────────────────────────

def _resolve_mfe_threshold(contract, cfg: BadEntryDiscoveryConfig,
                           warnings: list[str]) -> float:
    if cfg.mfe_threshold_override is not None:
        return float(cfg.mfe_threshold_override)
    # Use contract.bad_entry_canary_target definition
    try:
        target = contract.bad_entry_canary_target
        # Definition: "MFE_max_across_3_styles >= 1.0 ATR"
        # Extract numeric from definition if possible; default to 1.0
        defn = target.get("definition", "")
        # Try to parse "... >= X.X ATR" pattern
        import re
        m = re.search(r">=\s*([0-9.]+)", defn)
        if m:
            return float(m.group(1))
    except Exception:
        pass
    warnings.append(
        "Could not parse MFE threshold from contract.bad_entry_canary_target; "
        "defaulting to 1.0 ATR"
    )
    return 1.0


def _build_mfe_canary_labels(
    df: pd.DataFrame,
    mfe_threshold: float,
    cfg: BadEntryDiscoveryConfig,
    warnings: list[str],
) -> tuple[CanaryLabelStats, pd.Series]:
    """Label each signal: bad=1 if max(mfeATR across styles) < threshold.

    Returns (stats, Series indexed by signalId with values 0/1).
    """
    if cfg.signal_id_col not in df.columns:
        warnings.append(
            f"Column {cfg.signal_id_col!r} not found; "
            "using row index as signal ID"
        )
        df = df.copy()
        df[cfg.signal_id_col] = df.index.astype(str)

    if cfg.mfe_col not in df.columns:
        warnings.append(
            f"Column {cfg.mfe_col!r} not found; canary labeling unavailable"
        )
        empty_stats = CanaryLabelStats(
            n_signals=0, n_labeled=0, n_bad=0, n_good=0,
            base_bad_rate=0.0, mfe_threshold=mfe_threshold,
        )
        return empty_stats, pd.Series(dtype=float)

    # Aggregate: max MFE per signal across all styles
    mfe_numeric = pd.to_numeric(df[cfg.mfe_col], errors="coerce")
    df_copy = df[[cfg.signal_id_col]].copy()
    df_copy["_mfe"] = mfe_numeric

    max_mfe = df_copy.groupby(cfg.signal_id_col)["_mfe"].max()
    n_signals = int(len(max_mfe))
    n_labeled = int(max_mfe.notna().sum())

    # bad = max_mfe < threshold (entry never reached even modest MFE)
    bad_label = (max_mfe < mfe_threshold).astype(int)
    bad_label = bad_label[max_mfe.notna()]

    n_bad = int(bad_label.sum())
    n_good = n_labeled - n_bad
    base_bad_rate = n_bad / n_labeled if n_labeled > 0 else 0.0

    stats = CanaryLabelStats(
        n_signals=n_signals,
        n_labeled=n_labeled,
        n_bad=n_bad,
        n_good=n_good,
        base_bad_rate=base_bad_rate,
        mfe_threshold=mfe_threshold,
    )
    return stats, bad_label


def _build_per_signal_df(
    df: pd.DataFrame,
    per_signal_labels: pd.Series,
    available_features,
    cfg: BadEntryDiscoveryConfig,
) -> pd.DataFrame:
    """Build one-row-per-signal DataFrame with canary label + features."""
    # Take first row per signal (features are the same for all styles)
    per_sig = df.drop_duplicates(
        subset=[cfg.signal_id_col], keep="first",
    ).set_index(cfg.signal_id_col)

    per_sig = per_sig.copy()
    per_sig["_is_bad"] = per_signal_labels.reindex(per_sig.index).fillna(0).astype(int)

    # Keep only available feature columns + label
    keep_cols = ["_is_bad"] + [
        f for f in available_features if f in per_sig.columns
    ]
    return per_sig[keep_cols].reset_index()


# ─── Feature screening ───────────────────────────────────────────

def _screen_features(
    per_signal_df: pd.DataFrame,
    features: list[str],
    base_bad_rate: float,
    cfg: BadEntryDiscoveryConfig,
) -> list[BadEntryCandidate]:
    """Screen each feature for bad-entry predictiveness via binomial test."""
    if "_is_bad" not in per_signal_df.columns:
        return []

    y = per_signal_df["_is_bad"].values.astype(int)
    out: list[BadEntryCandidate] = []

    for feat in features:
        if feat not in per_signal_df.columns:
            continue
        vals = pd.to_numeric(per_signal_df[feat], errors="coerce")
        valid = vals.notna()
        v = vals[valid].values
        yv = y[valid.values]

        if len(v) < cfg.min_region_samples * 2:
            continue
        if float(np.std(v)) < 1e-12:
            continue

        # Low extreme
        thr_lo = float(np.percentile(v, cfg.percentile_low))
        mask = v <= thr_lo
        cand = _test_region(feat, "low_extreme", thr_lo, None, mask, yv, base_bad_rate)
        if cand.n_pass >= cfg.min_region_samples:
            out.append(cand)

        # High extreme
        thr_hi = float(np.percentile(v, cfg.percentile_high))
        mask = v >= thr_hi
        cand = _test_region(feat, "high_extreme", None, thr_hi, mask, yv, base_bad_rate)
        if cand.n_pass >= cfg.min_region_samples:
            out.append(cand)

        # Mid band
        lo_b = float(np.percentile(v, cfg.percentile_band_low))
        hi_b = float(np.percentile(v, cfg.percentile_band_high))
        if lo_b < hi_b:
            mask = (v >= lo_b) & (v <= hi_b)
            cand = _test_region(feat, "mid_band", lo_b, hi_b, mask, yv, base_bad_rate)
            if cand.n_pass >= cfg.min_region_samples:
                out.append(cand)

    return out


def _test_region(
    feature: str,
    rule_type: str,
    thr_lo: Optional[float],
    thr_hi: Optional[float],
    mask: np.ndarray,
    y: np.ndarray,
    base_rate: float,
) -> BadEntryCandidate:
    n_pass = int(mask.sum())
    if n_pass < 2:
        return BadEntryCandidate(
            feature=feature, rule_type=rule_type,
            threshold_low=thr_lo, threshold_high=thr_hi,
            n_pass=n_pass, bad_rate_in_region=0.0,
            base_bad_rate=base_rate, lift=0.0, pvalue=1.0,
        )

    bad_in = int(y[mask].sum())
    rate = bad_in / n_pass
    lift = rate / base_rate if base_rate > 0 else 0.0

    binom_res = stats.binomtest(bad_in, n_pass, p=base_rate, alternative="greater")
    pval = float(binom_res.pvalue) if not np.isnan(binom_res.pvalue) else 1.0

    return BadEntryCandidate(
        feature=feature, rule_type=rule_type,
        threshold_low=thr_lo, threshold_high=thr_hi,
        n_pass=n_pass,
        bad_rate_in_region=float(rate),
        base_bad_rate=float(base_rate),
        lift=float(lift),
        pvalue=pval,
    )


# ─── Helpers ─────────────────────────────────────────────────────

def _empty_result(
    canary_stats: CanaryLabelStats,
    warnings: list[str],
    ran_at: str,
) -> LayerTenAResult:
    return LayerTenAResult(
        canary_stats=canary_stats,
        bad_entry_candidates=(),
        n_total_hypotheses=0,
        filter_spec={"features": [], "min_votes": 1},
        warnings=tuple(warnings),
        ran_at=ran_at,
    )


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerTenAResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with (output_dir / "canary_labels.json").open("w", encoding="utf-8") as fh:
        json.dump(result.canary_stats.to_dict(), fh, indent=2, default=str)

    if result.bad_entry_candidates:
        pd.DataFrame(
            [c.to_dict() for c in result.bad_entry_candidates]
        ).to_csv(output_dir / "bad_entry_features.csv", index=False)

    with (output_dir / "composite_bad_filter_candidate.json").open(
        "w", encoding="utf-8",
    ) as fh:
        json.dump(result.filter_spec, fh, indent=2, default=str)

    with (output_dir / "L10a_summary.json").open("w", encoding="utf-8") as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)
