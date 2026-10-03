"""Layer 10 — Bad Entry Analysis.

Two-phase approach:
  Phase 1 (dev): Build canary labels from 3-style exit reasons.
                 Screen features for bad-entry prediction (binomial test).
  Phase 2 (holdout): Evaluate the composite filter on holdout data.

Canary labels are DERIVED DIAGNOSTICS, not ground truth. They depend
on exit policy decisions. Documented limitation.
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

from ..core.fdr_registry import FDRPoolRegistry


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class BadEntryConfig:
    signal_id_col: str = "signalId"
    style_col: str = "trailStyle"
    exit_reason_col: str = "exitReason"
    bad_exit_reasons: tuple = ("SL_HIT",)
    good_exit_reasons: tuple = ("TP_HIT",)

    # Group columns
    symbol_col: str = "symbol"
    setup_col: str = "setupType"
    min_group_signals: int = 30  # min complete signals in a group to run per-group screening

    # Screening
    min_extreme_samples: int = 20
    percentile_low: float = 10.0
    percentile_high: float = 90.0
    percentile_band_low: float = 30.0
    percentile_band_high: float = 70.0
    binom_alpha: float = 0.05

    # Bad entry canary threshold
    # 1 = any SL hit counts (strict — ~85% signals flagged bad)
    # 2 = majority SL required (current default — ~79% flagged bad)
    bad_sl_threshold: int = 2

    # Composite filter
    min_votes: int = 2

    # Holdout eval
    min_holdout_trades: int = 20


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class CanaryLabelsResult:
    n_signals: int
    n_complete: int
    label_counts: dict
    n_bad: int
    n_good: int
    n_neutral: int
    bad_rate: float

    def to_dict(self) -> dict:
        return {
            "n_signals": int(self.n_signals),
            "n_complete": int(self.n_complete),
            "label_counts": dict(self.label_counts),
            "n_bad": int(self.n_bad),
            "n_good": int(self.n_good),
            "n_neutral": int(self.n_neutral),
            "bad_rate": round(self.bad_rate, 6),
        }


@dataclass(frozen=True)
class BadEntryFeature:
    feature: str
    rule_type: str           # "low_extreme" | "high_extreme" | "mid_band"
    threshold_low: Optional[float]
    threshold_high: Optional[float]
    n_pass: int
    bad_rate_in_region: float
    base_bad_rate: float
    lift: float
    pvalue: float
    fdr_reject: bool

    def to_dict(self) -> dict:
        return {
            "feature": self.feature,
            "rule_type": self.rule_type,
            "threshold_low": (round(self.threshold_low, 6) if self.threshold_low is not None else None),
            "threshold_high": (round(self.threshold_high, 6) if self.threshold_high is not None else None),
            "n_pass": int(self.n_pass),
            "bad_rate_in_region": round(self.bad_rate_in_region, 6),
            "base_bad_rate": round(self.base_bad_rate, 6),
            "lift": round(self.lift, 6),
            "pvalue": round(self.pvalue, 6),
            "fdr_reject": self.fdr_reject,
        }


@dataclass(frozen=True)
class BadFilterHoldoutReport:
    n_holdout: int
    n_flagged_bad: int
    ev_flagged: float
    ev_unflagged: float
    ev_lift: float
    wr_flagged: float
    wr_unflagged: float
    filter_confirmed: bool

    def to_dict(self) -> dict:
        return {
            "n_holdout": int(self.n_holdout),
            "n_flagged_bad": int(self.n_flagged_bad),
            "ev_flagged": round(self.ev_flagged, 6),
            "ev_unflagged": round(self.ev_unflagged, 6),
            "ev_lift": round(self.ev_lift, 6),
            "wr_flagged": round(self.wr_flagged, 6),
            "wr_unflagged": round(self.wr_unflagged, 6),
            "filter_confirmed": self.filter_confirmed,
        }


@dataclass(frozen=True)
class LayerTenResult:
    canary: CanaryLabelsResult
    bad_features: tuple
    filter_spec: dict
    holdout_report: Optional[BadFilterHoldoutReport]
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "canary": self.canary.to_dict(),
            "n_bad_features_fdr": sum(1 for f in self.bad_features if f.fdr_reject),
            "n_bad_features_total": len(self.bad_features),
            "min_votes": self.filter_spec.get("min_votes"),
            "n_group_filters": len(self.filter_spec.get("groups", {})),
            "n_global_fallback_features": len(
                self.filter_spec.get("global_fallback", {}).get("features", [])
            ),
            "filter_confirmed": (
                self.holdout_report.filter_confirmed
                if self.holdout_report else None
            ),
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_df: pd.DataFrame,
    contract,
    experiment_id: str,
    available_features=None,
    holdout_df: Optional[pd.DataFrame] = None,
    output_dir: Optional[Path] = None,
    config: Optional[BadEntryConfig] = None,
) -> LayerTenResult:
    """Execute Layer 10.

    dev_df: development data with exit info per (signalId, trailStyle).
    holdout_df: optional; if provided (already unsealed by L8), evaluate
                composite filter on it.
    """
    cfg = config or BadEntryConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"
    warnings: list[str] = []

    if dev_df is None or len(dev_df) == 0:
        raise ValueError("L10: dev_df is empty")
    if not experiment_id:
        raise ValueError("L10: experiment_id is required")

    # ─── 1. Canary labels (dev) ─────────────────────────────────
    canary, signal_labels = _build_canary_labels(dev_df, cfg)

    if canary.n_complete < cfg.min_extreme_samples * 3:
        warnings.append(
            f"Only {canary.n_complete} complete signals; "
            "bad-entry screening skipped"
        )
        return LayerTenResult(
            canary=canary,
            bad_features=(),
            filter_spec={"groups": {}, "global_fallback": {"features": [], "min_votes": cfg.min_votes}, "min_votes": cfg.min_votes},
            holdout_report=None,
            warnings=tuple(warnings),
            ran_at=ran_at,
        )

    # ─── 2. Feature screening (dev) ─────────────────────────────
    if available_features is None:
        exclude = {cfg.signal_id_col, cfg.style_col,
                   cfg.exit_reason_col, "_profit", "time",
                   "_consensus_profit", "_all_styles_win",
                   "_all_styles_loss", "_style_agree_count"}
        available_features = [
            c for c in dev_df.columns
            if c not in exclude
            and pd.api.types.is_numeric_dtype(dev_df[c])
        ]

    # ─── 2a. Global screening (fallback for groups with insufficient data) ──
    dev_signals_global = _attach_signal_labels(dev_df, signal_labels, cfg)
    global_features_raw = _screen_bad_entry_features(
        dev_signals_global, list(available_features), cfg,
    )
    global_features = _apply_fdr_to_bad_features(
        global_features_raw, contract, cfg, warnings,
    )
    global_confirmed = [f for f in global_features if f.fdr_reject]
    global_filter = {
        "features": [
            {
                "feature": f.feature,
                "rule_type": f.rule_type,
                "threshold_low": f.threshold_low,
                "threshold_high": f.threshold_high,
            }
            for f in global_confirmed
        ],
        "min_votes": cfg.min_votes,
    }

    # ─── 2b. Per-group screening ─────────────────────────────────
    group_filters: dict = {}
    has_group_cols = (
        cfg.symbol_col in dev_df.columns and cfg.setup_col in dev_df.columns
    )
    if has_group_cols:
        for (sym, stp), grp_df in dev_df.groupby(
            [cfg.symbol_col, cfg.setup_col]
        ):
            group_key = f"{sym}|{stp}"
            grp_canary, grp_labels = _build_canary_labels(grp_df, cfg)
            if grp_canary.n_complete < cfg.min_group_signals:
                continue  # not enough data → use global fallback
            grp_signals = _attach_signal_labels(grp_df, grp_labels, cfg)
            grp_features_raw = _screen_bad_entry_features(
                grp_signals, list(available_features), cfg,
            )
            grp_features = _apply_fdr_to_bad_features(
                grp_features_raw, contract, cfg, warnings,
            )
            grp_confirmed = [f for f in grp_features if f.fdr_reject]
            if grp_confirmed:
                group_filters[group_key] = {
                    "features": [
                        {
                            "feature": f.feature,
                            "rule_type": f.rule_type,
                            "threshold_low": f.threshold_low,
                            "threshold_high": f.threshold_high,
                        }
                        for f in grp_confirmed
                    ],
                    "min_votes": cfg.min_votes,
                }

    # ─── 3. Build combined filter_spec ──────────────────────────
    filter_spec = {
        "groups": group_filters,
        "global_fallback": global_filter,
        "min_votes": cfg.min_votes,
    }
    # Keep bad_features as the global list for backward-compat CSV/FDR output
    bad_features = global_features
    n_groups = len(group_filters)
    n_global = len(global_confirmed)
    print(f"  [L10] {n_groups} per-group filters, {n_global} global fallback rules")

    # ─── 4. Holdout evaluation ───────────────────────────────────
    holdout_report = None
    if holdout_df is not None and len(holdout_df) > 0 and global_filter["features"]:
        holdout_report = _evaluate_filter_on_holdout(holdout_df, filter_spec, cfg)

    result = LayerTenResult(
        canary=canary,
        bad_features=tuple(bad_features),
        filter_spec=filter_spec,
        holdout_report=holdout_report,
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Canary labeling ─────────────────────────────────────────────

def _build_canary_labels(
    dev_df: pd.DataFrame,
    cfg: BadEntryConfig,
) -> tuple[CanaryLabelsResult, pd.Series]:
    if cfg.signal_id_col not in dev_df.columns or cfg.style_col not in dev_df.columns:
        empty = CanaryLabelsResult(
            n_signals=0, n_complete=0, label_counts={},
            n_bad=0, n_good=0, n_neutral=0, bad_rate=0.0,
        )
        return empty, pd.Series(dtype=object)

    pivot = dev_df.pivot_table(
        index=cfg.signal_id_col,
        columns=cfg.style_col,
        values=cfg.exit_reason_col,
        aggfunc="first",
    )

    labels = pivot.apply(lambda row: _classify_canary(row, cfg), axis=1)

    counts: dict[str, int] = {}
    for lab in labels.dropna():
        counts[str(lab)] = counts.get(str(lab), 0) + 1

    n_complete = int(labels.notna().sum())
    n_bad = sum(counts.get(l, 0) for l in ("catastrophic", "bad"))
    n_good = sum(counts.get(l, 0) for l in ("excellent", "good"))
    n_neutral = n_complete - n_bad - n_good

    result = CanaryLabelsResult(
        n_signals=int(len(pivot)),
        n_complete=n_complete,
        label_counts=counts,
        n_bad=n_bad, n_good=n_good, n_neutral=n_neutral,
        bad_rate=(n_bad / n_complete) if n_complete > 0 else 0.0,
    )
    return result, labels


def _classify_canary(row: pd.Series, cfg: BadEntryConfig) -> Optional[str]:
    reasons = [r for r in row.values if pd.notna(r)]
    if len(reasons) < 3:
        return None

    sl_count = sum(1 for r in reasons if r in cfg.bad_exit_reasons)
    tp_count = sum(1 for r in reasons if r in cfg.good_exit_reasons)

    # sl_count >= cfg.bad_sl_threshold: entry is bad.
    # threshold=1: any SL hit → strict filter (blocks ~85% signals)
    # threshold=2: majority SL required → balanced filter (blocks ~79%)
    if sl_count == 3:
        return "catastrophic"
    if sl_count >= cfg.bad_sl_threshold:
        return "bad"
    if sl_count == 1 and tp_count == 0:
        return "mixed_bad"
    if tp_count == 3:
        return "excellent"
    if tp_count == 2:
        return "good"
    if tp_count == 1 and sl_count == 0:
        return "mixed_good"
    return "neutral"


# ─── Feature screening ───────────────────────────────────────────

def _attach_signal_labels(
    dev_df: pd.DataFrame,
    signal_labels: pd.Series,
    cfg: BadEntryConfig,
) -> pd.DataFrame:
    df = dev_df.copy()
    if cfg.signal_id_col in df.columns and len(signal_labels) > 0:
        df["_canary_label"] = df[cfg.signal_id_col].map(signal_labels)
    else:
        df["_canary_label"] = None
    df["_is_bad"] = df["_canary_label"].isin(["catastrophic", "bad"]).astype(int)
    return df


def _screen_bad_entry_features(
    dev_signals: pd.DataFrame,
    features: list[str],
    cfg: BadEntryConfig,
) -> list[BadEntryFeature]:
    if dev_signals.empty or "_is_bad" not in dev_signals.columns:
        return []

    # One row per signal
    if cfg.signal_id_col in dev_signals.columns:
        per_signal = dev_signals.drop_duplicates(
            subset=[cfg.signal_id_col], keep="first",
        ).reset_index(drop=True)
    else:
        per_signal = dev_signals.reset_index(drop=True)

    y_bad = per_signal["_is_bad"].values
    base_rate = float(y_bad.mean())
    if base_rate <= 0.0 or base_rate >= 1.0:
        return []

    out: list[BadEntryFeature] = []
    for feat in features:
        if feat not in per_signal.columns:
            continue
        vals = pd.to_numeric(per_signal[feat], errors="coerce")
        valid = vals.notna()
        v = vals[valid].values
        y = y_bad[valid.values]

        if len(v) < cfg.min_extreme_samples * 2:
            continue
        if np.std(v) < 1e-12:
            continue

        thr_lo = float(np.percentile(v, cfg.percentile_low))
        mask = v <= thr_lo
        cand = _test_region(feat, "low_extreme", thr_lo, None, mask, y, base_rate)
        if cand.n_pass >= cfg.min_extreme_samples:
            out.append(cand)

        thr_hi = float(np.percentile(v, cfg.percentile_high))
        mask = v >= thr_hi
        cand = _test_region(feat, "high_extreme", None, thr_hi, mask, y, base_rate)
        if cand.n_pass >= cfg.min_extreme_samples:
            out.append(cand)

        lo_b = float(np.percentile(v, cfg.percentile_band_low))
        hi_b = float(np.percentile(v, cfg.percentile_band_high))
        mask = (v >= lo_b) & (v <= hi_b)
        cand = _test_region(feat, "mid_band", lo_b, hi_b, mask, y, base_rate)
        if cand.n_pass >= cfg.min_extreme_samples:
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
) -> BadEntryFeature:
    n_pass = int(mask.sum())
    if n_pass < 2:
        return BadEntryFeature(
            feature=feature, rule_type=rule_type,
            threshold_low=thr_lo, threshold_high=thr_hi,
            n_pass=n_pass, bad_rate_in_region=0.0, base_bad_rate=base_rate,
            lift=0.0, pvalue=1.0, fdr_reject=False,
        )

    bad_in = int(y[mask].sum())
    rate = bad_in / n_pass
    lift = rate / base_rate if base_rate > 0 else 0.0

    binom_result = stats.binomtest(bad_in, n_pass, p=base_rate, alternative="greater")
    pval = float(binom_result.pvalue) if not np.isnan(binom_result.pvalue) else 1.0

    return BadEntryFeature(
        feature=feature, rule_type=rule_type,
        threshold_low=thr_lo, threshold_high=thr_hi,
        n_pass=n_pass, bad_rate_in_region=float(rate),
        base_bad_rate=float(base_rate), lift=float(lift),
        pvalue=pval, fdr_reject=False,
    )


def _apply_fdr_to_bad_features(
    features: list[BadEntryFeature],
    contract,
    cfg: BadEntryConfig,
    warnings: list[str],
) -> list[BadEntryFeature]:
    if not features:
        return []

    pool_name = "bad_entry"
    if pool_name not in contract.fdr_pools:
        warnings.append(
            f"FDR pool {pool_name!r} not in contract; skipping FDR"
        )
        return features

    fdr = FDRPoolRegistry(contract)
    labels_used: list[str] = []
    for i, f in enumerate(features):
        label = f"{f.feature}|{f.rule_type}|{i}"
        labels_used.append(label)
        try:
            fdr.register(pool_name, label, f.pvalue)
        except Exception as e:
            warnings.append(f"FDR registration failed for {label!r}: {e}")
            return features

    try:
        fdr_result = fdr.correct(pool_name)
    except Exception as e:
        warnings.append(f"FDR correction failed: {e}")
        return features

    res = fdr_result.as_dict()
    out: list[BadEntryFeature] = []
    for i, f in enumerate(features):
        label = labels_used[i]
        info = res.get(label, {})
        out.append(BadEntryFeature(
            feature=f.feature, rule_type=f.rule_type,
            threshold_low=f.threshold_low, threshold_high=f.threshold_high,
            n_pass=f.n_pass, bad_rate_in_region=f.bad_rate_in_region,
            base_bad_rate=f.base_bad_rate, lift=f.lift, pvalue=f.pvalue,
            fdr_reject=bool(info.get("reject", False)),
        ))
    return out


# ─── Holdout evaluation ──────────────────────────────────────────

def _evaluate_filter_on_holdout(
    holdout_df: pd.DataFrame,
    filter_spec: dict,
    cfg: BadEntryConfig,
) -> Optional[BadFilterHoldoutReport]:
    # Support both old format {"features": [...]} and new format {"groups": ..., "global_fallback": ...}
    if "global_fallback" in filter_spec:
        features = filter_spec["global_fallback"].get("features", [])
    else:
        features = filter_spec.get("features", [])
    min_votes = filter_spec.get("min_votes", 2)

    if not features or "_profit" not in holdout_df.columns:
        return None

    if cfg.signal_id_col in holdout_df.columns:
        per_signal = holdout_df.drop_duplicates(
            subset=[cfg.signal_id_col], keep="first",
        ).reset_index(drop=True)
    else:
        per_signal = holdout_df.reset_index(drop=True)

    votes = np.zeros(len(per_signal), dtype=int)
    for f in features:
        feat = f["feature"]
        if feat not in per_signal.columns:
            continue
        vals = pd.to_numeric(per_signal[feat], errors="coerce").fillna(0.0).values
        rt = f["rule_type"]
        thr_lo = f.get("threshold_low")
        thr_hi = f.get("threshold_high")
        if rt == "low_extreme" and thr_lo is not None:
            votes += (vals <= thr_lo).astype(int)
        elif rt == "high_extreme" and thr_hi is not None:
            votes += (vals >= thr_hi).astype(int)
        elif rt == "mid_band" and thr_lo is not None and thr_hi is not None:
            votes += ((vals >= thr_lo) & (vals <= thr_hi)).astype(int)

    flagged = votes >= min_votes
    n_flagged = int(flagged.sum())
    if n_flagged < cfg.min_holdout_trades:
        return None

    profits = pd.to_numeric(per_signal["_profit"], errors="coerce").values
    valid = ~np.isnan(profits)
    if valid.sum() < cfg.min_holdout_trades:
        return None

    flagged_valid = flagged & valid
    unflagged_valid = (~flagged) & valid

    if flagged_valid.sum() == 0 or unflagged_valid.sum() == 0:
        return None

    ev_flagged = float(profits[flagged_valid].mean())
    ev_unflagged = float(profits[unflagged_valid].mean())
    wr_flagged = float((profits[flagged_valid] > 0).mean())
    wr_unflagged = float((profits[unflagged_valid] > 0).mean())

    confirmed = (ev_flagged < ev_unflagged) and (ev_flagged < 0)

    return BadFilterHoldoutReport(
        n_holdout=int(valid.sum()),
        n_flagged_bad=n_flagged,
        ev_flagged=ev_flagged,
        ev_unflagged=ev_unflagged,
        ev_lift=ev_unflagged - ev_flagged,
        wr_flagged=wr_flagged,
        wr_unflagged=wr_unflagged,
        filter_confirmed=confirmed,
    )


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerTenResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with (output_dir / "canary_labels.json").open("w", encoding="utf-8") as fh:
        json.dump(result.canary.to_dict(), fh, indent=2, default=str)

    if result.bad_features:
        pd.DataFrame([f.to_dict() for f in result.bad_features]).to_csv(
            output_dir / "bad_entry_features.csv", index=False,
        )

    with (output_dir / "composite_bad_filter.json").open("w", encoding="utf-8") as fh:
        json.dump(result.filter_spec, fh, indent=2, default=str)

    if result.holdout_report is not None:
        pd.DataFrame([result.holdout_report.to_dict()]).to_csv(
            output_dir / "bad_filter_holdout_report.csv", index=False,
        )

    with (output_dir / "bad_entry_summary.json").open("w", encoding="utf-8") as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)
