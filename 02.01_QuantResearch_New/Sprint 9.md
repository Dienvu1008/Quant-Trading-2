# Sprint 9 — Layers 9, 10, 11: Attribution + Bad Entry + Null Protocol

> **v3 changes (từ SPECIFICATION.md v3):**
> - **[Fix #1] L10 đã được tách**: L10a (discovery) chuyển sang Sprint 5. L10b (holdout eval) chuyển sang Sprint 8. Sprint 9 **không còn L10**.
> - Sprint 9 giờ chỉ bao gồm: L9 (Attribution) + L11 (Null Protocol).
> - L9 không thay đổi logic, chỉ nhận thêm input từ `frozen_regime_blocks` (để attribute theo regime blocks nếu cần).

Deliverables:
- `layers/L9_attribution.py` — Entry vs Exit, Exit policy decomposition, Cross-style consistency
- `layers/L11_null_protocol.py` — Case detection, experiment result classification
- Outputs: `entry_exit_attribution.csv`, `exit_policy_decomposition.csv`, `style_consistency.csv`, `experiment_result.json`
- ~22 tests (giảm từ 28 do L10 đã chuyển sang Sprint 5 và 8)

**Nguyên tắc:**
- L9: chỉ chạy sau khi L8 đã unseal → holdout available. Read-only attribution.
- L10a: đã chuyển sang Sprint 5 (discovery trên dev).
- L10b: đã chuyển sang Sprint 8.4 (holdout eval).
- L11: pure logic — không đọc data.

---

## `vp_analysis/layers/L9_attribution.py`

```python
"""Layer 9 — Attribution.

Read-only post-freeze analysis using the (already unsealed) holdout.

Three sub-analyses per rule:
  1. Entry vs Exit attribution (MAE/MFE based)
  2. Exit policy decomposition (3 trailing styles)
  3. Cross-style MAE/MFE consistency

No mutation of rules, production config, or holdout.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

from ..core.frozen_types import FrozenProductionConfig, FrozenRule


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class AttributionConfig:
    min_trades: int = 20
    strong_entry_ratio: float = 2.0      # MFE / MAE >= 2.0 → strong
    moderate_entry_ratio: float = 1.2
    min_style_trades: int = 15
    # Cross-style MAE/MFE tolerance (relative)
    mae_mfe_tolerance: float = 0.20


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class EntryExitAttribution:
    rule_id: str
    n_trades: int
    mae_atr_mean: float
    mfe_atr_mean: float
    mfe_mae_ratio: float
    profit_mean: float
    exit_capture_ratio: float       # profit / mfe_proxy (clipped)
    entry_quality: str              # "strong" | "moderate" | "weak" | "unknown"

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "n_trades": int(self.n_trades),
            "mae_atr_mean": round(self.mae_atr_mean, 6),
            "mfe_atr_mean": round(self.mfe_atr_mean, 6),
            "mfe_mae_ratio": round(self.mfe_mae_ratio, 6),
            "profit_mean": round(self.profit_mean, 6),
            "exit_capture_ratio": round(self.exit_capture_ratio, 6),
            "entry_quality": self.entry_quality,
        }


@dataclass(frozen=True)
class ExitPolicyDecomposition:
    rule_id: str
    ev_by_style: dict          # str(style) -> float or None
    n_by_style: dict
    trail_rescues_negative_entry: bool
    best_style: Optional[int]  # key of max EV
    ev_spread: Optional[float] # max - min (only non-None)

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "ev_by_style": {k: (round(v, 6) if v is not None else None)
                            for k, v in self.ev_by_style.items()},
            "n_by_style": dict(self.n_by_style),
            "trail_rescues_negative_entry": self.trail_rescues_negative_entry,
            "best_style": self.best_style,
            "ev_spread": (round(self.ev_spread, 6)
                          if self.ev_spread is not None else None),
        }


@dataclass(frozen=True)
class CrossStyleConsistency:
    rule_id: str
    mae_by_style: dict
    mfe_by_style: dict
    mae_consistent: bool
    mfe_consistent: bool
    mae_range_pct: Optional[float]
    mfe_range_pct: Optional[float]

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "mae_by_style": {k: (round(v, 6) if v is not None else None)
                             for k, v in self.mae_by_style.items()},
            "mfe_by_style": {k: (round(v, 6) if v is not None else None)
                             for k, v in self.mfe_by_style.items()},
            "mae_consistent": self.mae_consistent,
            "mfe_consistent": self.mfe_consistent,
            "mae_range_pct": (round(self.mae_range_pct, 6)
                              if self.mae_range_pct is not None else None),
            "mfe_range_pct": (round(self.mfe_range_pct, 6)
                              if self.mfe_range_pct is not None else None),
        }


@dataclass(frozen=True)
class LayerNineResult:
    entry_exit: tuple
    exit_policy: tuple
    style_consistency: tuple
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_entry_exit": len(self.entry_exit),
            "n_exit_policy": len(self.exit_policy),
            "n_style_consistency": len(self.style_consistency),
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    holdout_df: pd.DataFrame,
    production_config: FrozenProductionConfig,
    output_dir: Optional[Path] = None,
    config: Optional[AttributionConfig] = None,
    style_column: str = "trailStyle",
) -> LayerNineResult:
    """Attribution analysis on holdout. Read-only."""
    cfg = config or AttributionConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"
    warnings: list[str] = []

    if holdout_df is None or len(holdout_df) == 0:
        raise ValueError("L9: holdout_df is empty")

    entry_exit: list[EntryExitAttribution] = []
    exit_policy: list[ExitPolicyDecomposition] = []
    consistency: list[CrossStyleConsistency] = []

    for rule in production_config.rules:
        gated = _filter_by_rule(holdout_df, rule)

        if len(gated) >= cfg.min_trades:
            ee = _entry_exit_attribution(rule, gated, cfg)
            if ee is not None:
                entry_exit.append(ee)

        if style_column in gated.columns:
            ep = _exit_policy_decomposition(rule, gated, cfg, style_column)
            if ep is not None:
                exit_policy.append(ep)

            sc = _cross_style_consistency(rule, gated, cfg, style_column)
            if sc is not None:
                consistency.append(sc)
        else:
            warnings.append(
                f"Rule {rule.rule_id}: no {style_column!r} column, "
                f"skipped exit policy analysis"
            )

    result = LayerNineResult(
        entry_exit=tuple(entry_exit),
        exit_policy=tuple(exit_policy),
        style_consistency=tuple(consistency),
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Entry vs Exit ──────────────────────────────────────────────

def _entry_exit_attribution(
    rule: FrozenRule,
    gated: pd.DataFrame,
    cfg: AttributionConfig,
) -> Optional[EntryExitAttribution]:
    if "maeATR" not in gated.columns or "mfeATR" not in gated.columns:
        return None

    profits = pd.to_numeric(gated["_profit"], errors="coerce").values
    mae = pd.to_numeric(gated["maeATR"], errors="coerce").values
    mfe = pd.to_numeric(gated["mfeATR"], errors="coerce").values

    valid = ~np.isnan(profits) & ~np.isnan(mae) & ~np.isnan(mfe)
    n = int(valid.sum())
    if n < cfg.min_trades:
        return None

    profits = profits[valid]
    mae = mae[valid]
    mfe = mfe[valid]

    mae_mean = float(mae.mean())
    mfe_mean = float(mfe.mean())
    profit_mean = float(profits.mean())

    ratio = mfe_mean / (mae_mean + 1e-9)

    # Exit capture: how much of MFE ended as realized profit (bounded)
    if mfe_mean > 1e-9:
        capture = float(np.clip(profit_mean / mfe_mean, -1.0, 2.0))
    else:
        capture = 0.0

    if ratio >= cfg.strong_entry_ratio:
        quality = "strong"
    elif ratio >= cfg.moderate_entry_ratio:
        quality = "moderate"
    else:
        quality = "weak"

    return EntryExitAttribution(
        rule_id=rule.rule_id,
        n_trades=n,
        mae_atr_mean=mae_mean,
        mfe_atr_mean=mfe_mean,
        mfe_mae_ratio=ratio,
        profit_mean=profit_mean,
        exit_capture_ratio=capture,
        entry_quality=quality,
    )


# ─── Exit policy decomposition ──────────────────────────────────

def _exit_policy_decomposition(
    rule: FrozenRule,
    gated: pd.DataFrame,
    cfg: AttributionConfig,
    style_col: str,
) -> Optional[ExitPolicyDecomposition]:
    styles = pd.to_numeric(gated[style_col], errors="coerce").dropna().unique()
    if len(styles) < 2:
        return None

    ev_by_style: dict[str, Optional[float]] = {}
    n_by_style: dict[str, int] = {}

    for s in sorted(styles):
        sub = gated[pd.to_numeric(gated[style_col], errors="coerce") == s]
        n = len(sub)
        n_by_style[str(int(s))] = int(n)
        if n < cfg.min_style_trades:
            ev_by_style[str(int(s))] = None
            continue
        profits = pd.to_numeric(sub["_profit"], errors="coerce").dropna()
        if len(profits) == 0:
            ev_by_style[str(int(s))] = None
        else:
            ev_by_style[str(int(s))] = float(profits.mean())

    # Determine rescues flag
    valid_evs = {k: v for k, v in ev_by_style.items() if v is not None}
    if len(valid_evs) < 2:
        return ExitPolicyDecomposition(
            rule_id=rule.rule_id,
            ev_by_style=ev_by_style,
            n_by_style=n_by_style,
            trail_rescues_negative_entry=False,
            best_style=None,
            ev_spread=None,
        )

    # Assume style key "-1" = no-trail if present; otherwise use min EV style
    ev_vals = list(valid_evs.values())
    best_style = max(valid_evs, key=valid_evs.get)
    spread = max(ev_vals) - min(ev_vals)

    # Trail rescues negative entry:
    # - some style has EV < 0
    # - another style has EV > 0
    has_negative = any(v < 0 for v in valid_evs.values())
    has_positive = any(v > 0 for v in valid_evs.values())
    rescues = has_negative and has_positive

    return ExitPolicyDecomposition(
        rule_id=rule.rule_id,
        ev_by_style=ev_by_style,
        n_by_style=n_by_style,
        trail_rescues_negative_entry=rescues,
        best_style=int(best_style) if best_style.lstrip("-").isdigit() else None,
        ev_spread=spread,
    )


# ─── Cross-style consistency ────────────────────────────────────

def _cross_style_consistency(
    rule: FrozenRule,
    gated: pd.DataFrame,
    cfg: AttributionConfig,
    style_col: str,
) -> Optional[CrossStyleConsistency]:
    if "maeATR" not in gated.columns or "mfeATR" not in gated.columns:
        return None

    styles = pd.to_numeric(gated[style_col], errors="coerce").dropna().unique()
    if len(styles) < 2:
        return None

    mae_by_style: dict[str, Optional[float]] = {}
    mfe_by_style: dict[str, Optional[float]] = {}

    for s in sorted(styles):
        sub = gated[pd.to_numeric(gated[style_col], errors="coerce") == s]
        if len(sub) < cfg.min_style_trades:
            mae_by_style[str(int(s))] = None
            mfe_by_style[str(int(s))] = None
            continue
        mae_vals = pd.to_numeric(sub["maeATR"], errors="coerce").dropna()
        mfe_vals = pd.to_numeric(sub["mfeATR"], errors="coerce").dropna()
        mae_by_style[str(int(s))] = float(mae_vals.mean()) if len(mae_vals) else None
        mfe_by_style[str(int(s))] = float(mfe_vals.mean()) if len(mfe_vals) else None

    mae_vals = [v for v in mae_by_style.values() if v is not None]
    mfe_vals = [v for v in mfe_by_style.values() if v is not None]

    mae_range_pct = _relative_range(mae_vals)
    mfe_range_pct = _relative_range(mfe_vals)

    mae_consistent = (
        mae_range_pct is not None and mae_range_pct <= cfg.mae_mfe_tolerance
    )
    mfe_consistent = (
        mfe_range_pct is not None and mfe_range_pct <= cfg.mae_mfe_tolerance
    )

    return CrossStyleConsistency(
        rule_id=rule.rule_id,
        mae_by_style=mae_by_style,
        mfe_by_style=mfe_by_style,
        mae_consistent=mae_consistent,
        mfe_consistent=mfe_consistent,
        mae_range_pct=mae_range_pct,
        mfe_range_pct=mfe_range_pct,
    )


def _relative_range(vals: list[float]) -> Optional[float]:
    if len(vals) < 2:
        return None
    lo, hi = min(vals), max(vals)
    if abs(hi) < 1e-12:
        return 0.0
    return (hi - lo) / abs(hi)


# ─── Rule filter (shared with L7, L8) ───────────────────────────

def _filter_by_rule(df: pd.DataFrame, rule: FrozenRule) -> pd.DataFrame:
    if not rule.features:
        return df.iloc[0:0]

    if rule.gate_type == "threshold":
        feat = rule.features[0]
        if feat not in df.columns:
            return df.iloc[0:0]
        vals = pd.to_numeric(df[feat], errors="coerce").fillna(0.0).values
        if rule.direction == 1:
            return df[vals >= rule.lower_bound]
        return df[vals <= rule.upper_bound]

    if rule.gate_type == "band":
        feat = rule.features[0]
        if feat not in df.columns:
            return df.iloc[0:0]
        vals = pd.to_numeric(df[feat], errors="coerce").fillna(0.0).values
        return df[(vals >= rule.lower_bound) & (vals <= rule.upper_bound)]

    return df.iloc[0:0]


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerNineResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    if result.entry_exit:
        pd.DataFrame([e.to_dict() for e in result.entry_exit]).to_csv(
            output_dir / "entry_exit_attribution.csv", index=False,
        )

    if result.exit_policy:
        pd.DataFrame([e.to_dict() for e in result.exit_policy]).to_csv(
            output_dir / "exit_policy_decomposition.csv", index=False,
        )

    if result.style_consistency:
        pd.DataFrame([e.to_dict() for e in result.style_consistency]).to_csv(
            output_dir / "style_consistency.csv", index=False,
        )

    with (output_dir / "attribution_summary.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.summary_dict(), f, indent=2, default=str)
```

## `vp_analysis/layers/L10_bad_entry.py`

```python
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

    # Screening
    min_extreme_samples: int = 20
    percentile_low: float = 10.0
    percentile_high: float = 90.0
    percentile_band_low: float = 30.0
    percentile_band_high: float = 70.0
    binom_alpha: float = 0.05

    # Composite filter
    min_votes: int = 2

    # Holdout eval
    min_holdout_trades: int = 20


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class CanaryLabelsResult:
    n_signals: int
    n_complete: int
    label_counts: dict       # label -> count
    n_bad: int
    n_good: int
    n_neutral: int
    bad_rate: float          # n_bad / n_complete

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
            "n_bad_features_fdr": sum(
                1 for f in self.bad_features if f.fdr_reject
            ),
            "n_bad_features_total": len(self.bad_features),
            "min_votes": self.filter_spec.get("min_votes"),
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
            f"bad-entry screening skipped"
        )
        return LayerTenResult(
            canary=canary,
            bad_features=(),
            filter_spec={"features": [], "min_votes": cfg.min_votes},
            holdout_report=None,
            warnings=tuple(warnings),
            ran_at=ran_at,
        )

    # ─── 2. Bad entry feature screening (dev) ───────────────────
    if available_features is None:
        # Auto-detect numeric columns
        exclude = {cfg.signal_id_col, cfg.style_col,
                   cfg.exit_reason_col, "_profit", "time"}
        available_features = [
            c for c in dev_df.columns
            if c not in exclude
            and pd.api.types.is_numeric_dtype(dev_df[c])
        ]

    dev_signals = _attach_signal_labels(dev_df, signal_labels, cfg)
    bad_features_raw = _screen_bad_entry_features(
        dev_signals, available_features, cfg,
    )

    # Apply FDR
    bad_features = _apply_fdr_to_bad_features(
        bad_features_raw, contract, cfg, warnings,
    )

    # ─── 3. Composite filter spec ───────────────────────────────
    confirmed = [f for f in bad_features if f.fdr_reject]
    filter_spec = {
        "features": [
            {
                "feature": f.feature,
                "rule_type": f.rule_type,
                "threshold_low": f.threshold_low,
                "threshold_high": f.threshold_high,
            }
            for f in confirmed
        ],
        "min_votes": cfg.min_votes,
    }

    # ─── 4. Holdout evaluation ──────────────────────────────────
    holdout_report = None
    if holdout_df is not None and len(holdout_df) > 0 and filter_spec["features"]:
        holdout_report = _evaluate_filter_on_holdout(
            holdout_df, filter_spec, cfg,
        )

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


# ─── Canary labeling ────────────────────────────────────────────

def _build_canary_labels(
    dev_df: pd.DataFrame,
    cfg: BadEntryConfig,
) -> tuple[CanaryLabelsResult, pd.Series]:
    """Return (aggregate result, per-signalId label Series)."""
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
        counts[lab] = counts.get(lab, 0) + 1

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

    if sl_count == 3:
        return "catastrophic"
    if sl_count == 2:
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


# ─── Feature screening ──────────────────────────────────────────

def _attach_signal_labels(
    dev_df: pd.DataFrame,
    signal_labels: pd.Series,
    cfg: BadEntryConfig,
) -> pd.DataFrame:
    df = dev_df.copy()
    df["_canary_label"] = df[cfg.signal_id_col].map(signal_labels)
    df["_is_bad"] = df["_canary_label"].isin(
        ["catastrophic", "bad"]
    ).astype(int)
    return df


def _screen_bad_entry_features(
    dev_signals: pd.DataFrame,
    features: list[str],
    cfg: BadEntryConfig,
) -> list[BadEntryFeature]:
    """One row per signal (dev). Returns raw candidates (pre-FDR)."""
    if dev_signals.empty:
        return []

    # Deduplicate to one row per signalId (use first row)
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

        # low extreme
        thr_lo = float(np.percentile(v, cfg.percentile_low))
        mask = v <= thr_lo
        out.append(_test_region(
            feat, "low_extreme", thr_lo, None,
            mask, y, base_rate,
        ))

        # high extreme
        thr_hi = float(np.percentile(v, cfg.percentile_high))
        mask = v >= thr_hi
        out.append(_test_region(
            feat, "high_extreme", None, thr_hi,
            mask, y, base_rate,
        ))

        # mid band
        lo_b = float(np.percentile(v, cfg.percentile_band_low))
        hi_b = float(np.percentile(v, cfg.percentile_band_high))
        mask = (v >= lo_b) & (v <= hi_b)
        out.append(_test_region(
            feat, "mid_band", lo_b, hi_b,
            mask, y, base_rate,
        ))

    return [f for f in out if f.n_pass >= cfg.min_extreme_samples]


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
            n_pass=n_pass,
            bad_rate_in_region=0.0, base_bad_rate=base_rate,
            lift=0.0, pvalue=1.0, fdr_reject=False,
        )

    bad_in = int(y[mask].sum())
    rate = bad_in / n_pass
    lift = rate / base_rate if base_rate > 0 else 0.0

    result = stats.binomtest(bad_in, n_pass, p=base_rate, alternative="greater")
    pval = float(result.pvalue) if not np.isnan(result.pvalue) else 1.0

    return BadEntryFeature(
        feature=feature, rule_type=rule_type,
        threshold_low=thr_lo, threshold_high=thr_hi,
        n_pass=n_pass,
        bad_rate_in_region=float(rate),
        base_bad_rate=float(base_rate),
        lift=float(lift),
        pvalue=pval,
        fdr_reject=False,
    )


def _apply_fdr_to_bad_features(
    features: list[BadEntryFeature],
    contract,
    cfg: BadEntryConfig,
    warnings: list[str],
) -> list[BadEntryFeature]:
    if not features:
        return []

    # FDR pool: "bad_entry" from contract
    pool_name = "bad_entry"
    if pool_name not in contract.fdr_pools:
        warnings.append(
            f"FDR pool {pool_name!r} not in contract; skipping FDR"
        )
        return features

    fdr = FDRPoolRegistry(contract)
    for i, f in enumerate(features):
        label = f"{f.feature}|{f.rule_type}|{i}"
        try:
            fdr.register(pool_name, label, f.pvalue)
        except Exception as e:
            warnings.append(f"FDR registration failed for {label!r}: {e}")
            return features

    try:
        result = fdr.correct(pool_name)
    except Exception as e:
        warnings.append(f"FDR correction failed: {e}")
        return features

    res = result.as_dict()
    out: list[BadEntryFeature] = []
    for i, f in enumerate(features):
        label = f"{f.feature}|{f.rule_type}|{i}"
        info = res.get(label, {})
        out.append(BadEntryFeature(
            feature=f.feature, rule_type=f.rule_type,
            threshold_low=f.threshold_low, threshold_high=f.threshold_high,
            n_pass=f.n_pass, bad_rate_in_region=f.bad_rate_in_region,
            base_bad_rate=f.base_bad_rate, lift=f.lift, pvalue=f.pvalue,
            fdr_reject=bool(info.get("reject", False)),
        ))
    return out


# ─── Holdout evaluation ─────────────────────────────────────────

def _evaluate_filter_on_holdout(
    holdout_df: pd.DataFrame,
    filter_spec: dict,
    cfg: BadEntryConfig,
) -> Optional[BadFilterHoldoutReport]:
    features = filter_spec.get("features", [])
    min_votes = filter_spec.get("min_votes", 2)

    if not features or "_profit" not in holdout_df.columns:
        return None

    # Dedup to per-signal
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
        if rt == "low_extreme":
            votes += (vals <= f["threshold_low"]).astype(int)
        elif rt == "high_extreme":
            votes += (vals >= f["threshold_high"]).astype(int)
        elif rt == "mid_band":
            votes += (
                (vals >= f["threshold_low"]) & (vals <= f["threshold_high"])
            ).astype(int)

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

    # Filter confirmed if flagged trades really are worse
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

    with (output_dir / "canary_labels.json").open("w", encoding="utf-8") as f:
        json.dump(result.canary.to_dict(), f, indent=2, default=str)

    if result.bad_features:
        pd.DataFrame(
            [f.to_dict() for f in result.bad_features]
        ).to_csv(output_dir / "bad_entry_features.csv", index=False)

    with (output_dir / "composite_bad_filter.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.filter_spec, f, indent=2, default=str)

    if result.holdout_report is not None:
        pd.DataFrame([result.holdout_report.to_dict()]).to_csv(
            output_dir / "bad_filter_holdout_report.csv", index=False,
        )

    with (output_dir / "bad_entry_summary.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.summary_dict(), f, indent=2, default=str)
```

## `vp_analysis/layers/L11_null_protocol.py`

```python
"""Layer 11 — Null Result Protocol.

Pure logic layer: classifies an experiment's outcome into one of:
  - SUCCESS:            >= 1 rule confirmed on holdout
  - NULL_DEV:           0 validated rules after L6
  - NULL_HOLDOUT:       0 rules confirmed on holdout (but >=1 validated)

No data access. Consumes L6 + L8 results.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Optional


class ExperimentOutcome(str, Enum):
    SUCCESS = "SUCCESS"
    NULL_DEV = "NULL_DEV"
    NULL_HOLDOUT = "NULL_HOLDOUT"
    INCONCLUSIVE = "INCONCLUSIVE"   # unexpected state


@dataclass(frozen=True)
class LayerElevenResult:
    experiment_id: str
    outcome: str
    n_frozen_rules: int
    n_holdout_confirmed: int
    n_soft_gates: int
    allowed_actions: tuple
    forbidden_actions: tuple
    message: str
    ran_at: str

    def to_dict(self) -> dict:
        return {
            "experiment_id": self.experiment_id,
            "outcome": self.outcome,
            "n_frozen_rules": int(self.n_frozen_rules),
            "n_holdout_confirmed": int(self.n_holdout_confirmed),
            "n_soft_gates": int(self.n_soft_gates),
            "allowed_actions": list(self.allowed_actions),
            "forbidden_actions": list(self.forbidden_actions),
            "message": self.message,
            "ran_at": self.ran_at,
        }


def run(
    experiment_id: str,
    l6_result,                    # LayerSixResult or None
    l8_result=None,               # LayerEightResult or None
    output_dir: Optional[Path] = None,
) -> LayerElevenResult:
    """Classify outcome. No data access."""
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if not experiment_id:
        raise ValueError("L11: experiment_id is required")

    n_frozen = len(l6_result.frozen_rules) if l6_result else 0
    n_soft = (
        len(l6_result.validated_soft_gates) if l6_result else 0
    )

    # Dev null: no rules survived L6
    if n_frozen == 0 and n_soft == 0:
        return _null_dev(experiment_id, n_frozen, n_soft, ran_at)

    if n_frozen == 0 and n_soft > 0:
        # Only soft gates survived; no hard gates to evaluate on holdout
        return LayerElevenResult(
            experiment_id=experiment_id,
            outcome=ExperimentOutcome.SUCCESS.value,
            n_frozen_rules=0,
            n_holdout_confirmed=0,
            n_soft_gates=n_soft,
            allowed_actions=(
                "deploy_soft_gates_as_tilt",
                "collect_more_data_for_hard_gate_experiment",
            ),
            forbidden_actions=(
                "rerun_same_contract_on_same_dataset",
                "modify_shape_priors_after_seeing_result",
            ),
            message=(
                f"Only {n_soft} soft gate(s) survived; no hard gates to "
                f"evaluate on holdout."
            ),
            ran_at=ran_at,
        )

    # Have hard gates; check holdout
    if l8_result is None:
        return LayerElevenResult(
            experiment_id=experiment_id,
            outcome=ExperimentOutcome.INCONCLUSIVE.value,
            n_frozen_rules=n_frozen,
            n_holdout_confirmed=0,
            n_soft_gates=n_soft,
            allowed_actions=("run_layer_8_to_evaluate_on_holdout",),
            forbidden_actions=(),
            message="Hard gates frozen but holdout not yet evaluated.",
            ran_at=ran_at,
        )

    n_confirmed = l8_result.n_rules_confirmed

    if n_confirmed == 0:
        return _null_holdout(
            experiment_id, n_frozen, n_confirmed, n_soft, ran_at,
        )

    return _success(
        experiment_id, n_frozen, n_confirmed, n_soft, ran_at,
    )


def _success(
    experiment_id: str, n_frozen: int, n_confirmed: int,
    n_soft: int, ran_at: str,
) -> LayerElevenResult:
    return LayerElevenResult(
        experiment_id=experiment_id,
        outcome=ExperimentOutcome.SUCCESS.value,
        n_frozen_rules=n_frozen,
        n_holdout_confirmed=n_confirmed,
        n_soft_gates=n_soft,
        allowed_actions=(
            "deploy_confirmed_rules_to_production",
            "start_new_experiment_on_new_dataset",
        ),
        forbidden_actions=(
            "rerun_same_contract_on_same_dataset",
            "modify_rules_after_seeing_holdout",
            "modify_shape_priors_after_seeing_result",
            "add_features_after_seeing_holdout",
        ),
        message=(
            f"SUCCESS: {n_confirmed}/{n_frozen} rules confirmed on holdout."
        ),
        ran_at=ran_at,
    )


def _null_dev(
    experiment_id: str, n_frozen: int, n_soft: int, ran_at: str,
) -> LayerElevenResult:
    return LayerElevenResult(
        experiment_id=experiment_id,
        outcome=ExperimentOutcome.NULL_DEV.value,
        n_frozen_rules=n_frozen,
        n_holdout_confirmed=0,
        n_soft_gates=n_soft,
        allowed_actions=(
            "archive_experiment_as_null",
            "collect_more_data",
            "design_new_experiment_with_new_contract",
        ),
        forbidden_actions=(
            "unseal_holdout",
            "rerun_same_contract_on_same_dataset",
            "tune_thresholds_after_seeing_null",
            "modify_shape_priors_after_seeing_null",
            "add_features_after_seeing_null",
        ),
        message=(
            "NULL_DEV: no rules survived FDR at L6. Holdout remains sealed."
        ),
        ran_at=ran_at,
    )


def _null_holdout(
    experiment_id: str, n_frozen: int, n_confirmed: int,
    n_soft: int, ran_at: str,
) -> LayerElevenResult:
    return LayerElevenResult(
        experiment_id=experiment_id,
        outcome=ExperimentOutcome.NULL_HOLDOUT.value,
        n_frozen_rules=n_frozen,
        n_holdout_confirmed=n_confirmed,
        n_soft_gates=n_soft,
        allowed_actions=(
            "archive_experiment_as_null",
            "collect_more_data",
            "diagnose_degradation_in_layer_8_report",
            "design_new_experiment_with_new_contract",
        ),
        forbidden_actions=(
            "rerun_same_contract_on_same_dataset",
            "modify_rules_after_seeing_holdout",
            "modify_sl_tp_after_seeing_holdout",
            "modify_shape_priors_after_seeing_holdout",
            "add_features_after_seeing_holdout",
        ),
        message=(
            f"NULL_HOLDOUT: 0/{n_frozen} rules confirmed on holdout. "
            f"Holdout remains consumed for this experiment."
        ),
        ran_at=ran_at,
    )


def write_result(result: LayerElevenResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / "experiment_result.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.to_dict(), f, indent=2, default=str)
```

## `vp_analysis/layers/__init__.py` — cập nhật

```python
"""Analysis layers."""
from . import L0_hygiene
from . import L1_boundary
from . import L2_feature_engineering
from . import L3_eda
from . import L4_hard_gate_discovery
from . import L5_soft_gate_discovery
from . import L6_multiple_testing
from . import L7_dev_optimization
from . import L8_holdout_apply
from . import L9_attribution
from . import L10_bad_entry
from . import L11_null_protocol

__all__ = [
    "L0_hygiene", "L1_boundary", "L2_feature_engineering",
    "L3_eda", "L4_hard_gate_discovery", "L5_soft_gate_discovery",
    "L6_multiple_testing", "L7_dev_optimization", "L8_holdout_apply",
    "L9_attribution", "L10_bad_entry", "L11_null_protocol",
]
```

---

## Tests

## `vp_analysis/tests/test_L9_attribution.py`

```python
"""Tests for Layer 9 — Attribution."""
import json
import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.frozen_types import (
    FrozenProductionConfig, FrozenRule,
)
from vp_analysis.layers.L9_attribution import (
    AttributionConfig,
    _cross_style_consistency,
    _entry_exit_attribution,
    _exit_policy_decomposition,
    _relative_range,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

def _make_rule(rule_id="R-00001", feature="f_signal", lower=0.5):
    return FrozenRule(
        rule_id=rule_id, experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD", setup="BOS",
        gate_type="threshold", direction=1,
        features=(feature,), lower_bound=lower, upper_bound=None,
        fdr_significant=True,
    )


def _make_config(rules):
    return FrozenProductionConfig(
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        rules=tuple(rules), sl_tp_selections=(), sizing_configs=(),
    )


def _make_holdout(n=400, seed=0):
    rng = np.random.default_rng(seed)
    f = rng.uniform(0, 1, n)
    styles = rng.choice([-1, 0, 1], size=n)
    mae = rng.uniform(0.3, 2.0, n)
    mfe = rng.uniform(0.5, 2.5, n)
    profit = np.where(f > 0.5, 1.0, -0.5) + rng.normal(0, 0.3, n)
    return pd.DataFrame({
        "symbol": ["XAUUSD"] * n, "setupType": ["BOS"] * n,
        "f_signal": f, "trailStyle": styles,
        "maeATR": mae, "mfeATR": mfe, "_profit": profit,
        "time": pd.date_range("2025-01-01", periods=n, freq="h"),
    })


# ══════════════════════════════════════════════════════════════════
# Entry vs Exit attribution
# ══════════════════════════════════════════════════════════════════

def test_entry_exit_runs():
    df = _make_holdout(n=400)
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    ee = _entry_exit_attribution(rule, gated, AttributionConfig())
    assert ee is not None
    assert ee.n_trades > 0
    assert ee.mfe_mae_ratio > 0


def test_entry_exit_strong_classification():
    """When MFE >> MAE, entry should be 'strong'."""
    rng = np.random.default_rng(1)
    n = 200
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "maeATR": np.full(n, 0.5),
        "mfeATR": np.full(n, 2.0),  # ratio 4.0
        "_profit": rng.normal(0.5, 0.3, n),
    })
    rule = _make_rule()
    ee = _entry_exit_attribution(rule, df, AttributionConfig())
    assert ee.entry_quality == "strong"


def test_entry_exit_weak_classification():
    rng = np.random.default_rng(2)
    n = 200
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "maeATR": np.full(n, 1.5),
        "mfeATR": np.full(n, 0.5),  # ratio 0.33
        "_profit": rng.normal(-0.2, 0.3, n),
    })
    rule = _make_rule()
    ee = _entry_exit_attribution(rule, df, AttributionConfig())
    assert ee.entry_quality == "weak"


def test_entry_exit_skipped_without_mae_mfe():
    df = _make_holdout(n=200).drop(columns=["maeATR", "mfeATR"])
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    ee = _entry_exit_attribution(rule, gated, AttributionConfig())
    assert ee is None


# ══════════════════════════════════════════════════════════════════
# Exit policy decomposition
# ══════════════════════════════════════════════════════════════════

def test_exit_policy_three_styles():
    df = _make_holdout(n=400)
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    ep = _exit_policy_decomposition(
        rule, gated, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert ep is not None
    assert len(ep.ev_by_style) >= 2


def test_exit_policy_rescues_detection():
    """Synthetic: style -1 EV < 0, style 1 EV > 0 → rescues=True."""
    rng = np.random.default_rng(3)
    n = 300
    f = rng.uniform(0.5, 1.0, n)
    styles = rng.choice([-1, 0, 1], size=n)
    # Style -1 negative, others positive
    profit = np.where(styles == -1, -0.5, 1.0) + rng.normal(0, 0.2, n)
    df = pd.DataFrame({
        "f_signal": f, "trailStyle": styles, "_profit": profit,
    })
    rule = _make_rule()
    ep = _exit_policy_decomposition(
        rule, df, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert ep.trail_rescues_negative_entry is True


def test_exit_policy_no_rescue_when_all_positive():
    df = _make_holdout(n=400, seed=0)
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    ep = _exit_policy_decomposition(
        rule, gated, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    if ep:
        # All styles positive (signal > 0.5 → positive EV)
        # Rescues requires one negative → should be False
        assert not ep.trail_rescues_negative_entry


# ══════════════════════════════════════════════════════════════════
# Cross-style consistency
# ══════════════════════════════════════════════════════════════════

def test_cross_style_consistency_runs():
    df = _make_holdout(n=400)
    rule = _make_rule()
    gated = df[df["f_signal"] >= 0.5]
    sc = _cross_style_consistency(
        rule, gated, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert sc is not None


def test_cross_style_identical_values_consistent():
    """When MAE/MFE identical across styles, must be consistent."""
    rng = np.random.default_rng(4)
    n = 200
    styles = rng.choice([-1, 0, 1], size=n)
    df = pd.DataFrame({
        "f_signal": rng.uniform(0.5, 1.0, n),
        "trailStyle": styles,
        "maeATR": np.full(n, 1.0),
        "mfeATR": np.full(n, 1.5),
        "_profit": rng.normal(0.3, 0.2, n),
    })
    rule = _make_rule()
    sc = _cross_style_consistency(
        rule, df, AttributionConfig(min_style_trades=10), "trailStyle",
    )
    assert sc.mae_consistent
    assert sc.mfe_consistent


def test_relative_range():
    assert _relative_range([1.0, 1.0, 1.0]) == 0.0
    assert abs(_relative_range([1.0, 2.0]) - 0.5) < 1e-9
    assert _relative_range([1.0]) is None


# ══════════════════════════════════════════════════════════════════
# Integration
# ══════════════════════════════════════════════════════════════════

def test_full_run(tmp_path):
    df = _make_holdout(n=400)
    rule = _make_rule()
    config = _make_config([rule])
    result = run(df, config, output_dir=tmp_path)
    assert (tmp_path / "entry_exit_attribution.csv").exists()
    assert (tmp_path / "exit_policy_decomposition.csv").exists()
    assert (tmp_path / "style_consistency.csv").exists()
    assert (tmp_path / "attribution_summary.json").exists()


def test_empty_holdout_raises():
    rule = _make_rule()
    config = _make_config([rule])
    with pytest.raises(ValueError):
        run(pd.DataFrame(), config)


def test_missing_style_column_warns():
    df = _make_holdout(n=200).drop(columns=["trailStyle"])
    rule = _make_rule()
    config = _make_config([rule])
    result = run(df, config)
    assert any("trailStyle" in w for w in result.warnings)
```

## `vp_analysis/tests/test_L10_bad_entry.py`

```python
"""Tests for Layer 10 — Bad Entry Analysis."""
import json
import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L10_bad_entry import (
    BadEntryConfig,
    _build_canary_labels,
    _classify_canary,
    _evaluate_filter_on_holdout,
    _screen_bad_entry_features,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["fdr_pools"] = {
        "bad_entry": {"name": "bad_entry",
                       "max_hypotheses": 500, "alpha": 0.05},
        "hard_gate": {"name": "hard_gate",
                       "max_hypotheses": 500, "alpha": 0.05},
        "soft_gate": {"name": "soft_gate",
                       "max_hypotheses": 200, "alpha": 0.05},
    }
    return ResearchContract.from_dict(d)


def _make_dev_3style(n_signals=100, seed=0):
    """3 styles per signal. Feature f_bad predicts bad outcomes."""
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(n_signals):
        sig_id = f"SIG-{i:05d}"
        f_bad = rng.uniform(0, 1)
        # Bad signal → most styles hit SL
        if f_bad > 0.7:
            reasons = ["SL_HIT", "SL_HIT", "SL_HIT"]
        elif f_bad > 0.5:
            reasons = ["SL_HIT", "SL_HIT", "TP_HIT"]
        elif f_bad > 0.3:
            reasons = ["SL_HIT", "TP_HIT", "TP_HIT"]
        else:
            reasons = ["TP_HIT", "TP_HIT", "TP_HIT"]
        for style, reason in zip([-1, 0, 1], reasons):
            rows.append({
                "signalId": sig_id,
                "trailStyle": style,
                "exitReason": reason,
                "f_bad": f_bad,
                "f_noise": rng.uniform(0, 1),
                "profitUSD": 1.0 if reason == "TP_HIT" else -1.0,
                "_profit": 1.0 if reason == "TP_HIT" else -1.0,
                "time": pd.Timestamp("2024-01-01") + pd.Timedelta(hours=i),
            })
    return pd.DataFrame(rows)


# ══════════════════════════════════════════════════════════════════
# Canary labels
# ══════════════════════════════════════════════════════════════════

def test_canary_catastrophic():
    row = pd.Series([-1, 0, 1], index=["-1", "0", "1"])
    # Simulate 3 rows with SL_HIT
    row = pd.Series({"a": "SL_HIT", "b": "SL_HIT", "c": "SL_HIT"})
    cfg = BadEntryConfig()
    assert _classify_canary(row, cfg) == "catastrophic"


def test_canary_excellent():
    row = pd.Series({"a": "TP_HIT", "b": "TP_HIT", "c": "TP_HIT"})
    assert _classify_canary(row, BadEntryConfig()) == "excellent"


def test_canary_incomplete():
    row = pd.Series({"a": "SL_HIT", "b": None})
    assert _classify_canary(row, BadEntryConfig()) is None


def test_canary_aggregate(contract):
    df = _make_dev_3style(n_signals=100)
    canary, _ = _build_canary_labels(df, BadEntryConfig())
    assert canary.n_signals == 100
    assert canary.n_complete == 100
    # Expect mixture
    assert canary.n_bad > 0
    assert canary.n_good > 0


# ══════════════════════════════════════════════════════════════════
# Bad entry screening
# ══════════════════════════════════════════════════════════════════

def test_screen_finds_bad_feature(contract):
    df = _make_dev_3style(n_signals=200)
    canary, labels = _build_canary_labels(df, BadEntryConfig())
    df = df.copy()
    df["_canary_label"] = df["signalId"].map(labels)
    df["_is_bad"] = df["_canary_label"].isin(
        ["catastrophic", "bad"]
    ).astype(int)

    features = _screen_bad_entry_features(
        df, ["f_bad", "f_noise"], BadEntryConfig(min_extreme_samples=15),
    )
    # f_bad high_extreme should have lift > 1
    bad_f = [f for f in features
             if f.feature == "f_bad" and f.rule_type == "high_extreme"]
    assert len(bad_f) >= 1
    assert bad_f[0].lift > 1.0


# ══════════════════════════════════════════════════════════════════
# Full run
# ══════════════════════════════════════════════════════════════════

def test_full_run_no_holdout(contract, tmp_path):
    dev = _make_dev_3style(n_signals=100)
    result = run(dev, contract, experiment_id="EXP-TEST",
                 available_features=["f_bad", "f_noise"],
                 output_dir=tmp_path)
    assert (tmp_path / "canary_labels.json").exists()
    assert (tmp_path / "bad_entry_features.csv").exists()
    assert (tmp_path / "composite_bad_filter.json").exists()


def test_full_run_with_holdout(contract, tmp_path):
    dev = _make_dev_3style(n_signals=150, seed=0)
    holdout = _make_dev_3style(n_signals=100, seed=1)
    result = run(dev, contract, experiment_id="EXP-TEST",
                 available_features=["f_bad", "f_noise"],
                 holdout_df=holdout,
                 output_dir=tmp_path)
    if result.filter_spec.get("features"):
        # Should have evaluated filter on holdout
        assert (tmp_path / "bad_filter_holdout_report.csv").exists()


def test_insufficient_canary_returns_empty(contract):
    dev = _make_dev_3style(n_signals=20)
    result = run(dev, contract, experiment_id="EXP-TEST",
                 available_features=["f_bad"])
    # Too few signals for screening
    assert len(result.bad_features) == 0


# ══════════════════════════════════════════════════════════════════
# Holdout evaluation of filter
# ══════════════════════════════════════════════════════════════════

def test_evaluate_filter_on_holdout():
    """Simulate: filter flags bad trades, they have lower EV."""
    rng = np.random.default_rng(5)
    n = 200
    f_bad = rng.uniform(0, 1, n)
    profit = np.where(f_bad > 0.7, -1.0, 0.5) + rng.normal(0, 0.2, n)
    df = pd.DataFrame({
        "signalId": [f"SIG-{i}" for i in range(n)],
        "f_bad": f_bad, "_profit": profit,
    })
    filter_spec = {
        "features": [{
            "feature": "f_bad", "rule_type": "high_extreme",
            "threshold_high": 0.7, "threshold_low": None,
        }],
        "min_votes": 1,
    }
    report = _evaluate_filter_on_holdout(df, filter_spec, BadEntryConfig())
    assert report is not None
    assert report.filter_confirmed  # flagged have negative EV


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_dev_raises(contract):
    with pytest.raises(ValueError, match="empty"):
        run(pd.DataFrame(), contract, experiment_id="EXP-TEST")


def test_missing_experiment_id_raises(contract):
    dev = _make_dev_3style(n_signals=100)
    with pytest.raises(ValueError, match="experiment_id"):
        run(dev, contract, experiment_id="")
```

## `vp_analysis/tests/test_L11_null_protocol.py`

```python
"""Tests for Layer 11 — Null Protocol."""
import json
import pytest

from vp_analysis.layers.L11_null_protocol import (
    ExperimentOutcome,
    LayerElevenResult,
    run,
    write_result,
)


# ─── Stubs ───────────────────────────────────────────────────────

class _StubL6:
    def __init__(self, n_frozen=0, n_soft=0):
        self.frozen_rules = tuple(
            object() for _ in range(n_frozen)
        )
        self.validated_soft_gates = tuple(
            object() for _ in range(n_soft)
        )


class _StubL8:
    def __init__(self, n_confirmed=0):
        self.n_rules_confirmed = n_confirmed


# ══════════════════════════════════════════════════════════════════
# Case classification
# ══════════════════════════════════════════════════════════════════

def test_null_dev_when_no_frozen_rules():
    l6 = _StubL6(n_frozen=0, n_soft=0)
    result = run("EXP-TEST", l6)
    assert result.outcome == ExperimentOutcome.NULL_DEV.value
    assert any("unseal_holdout" in a for a in result.forbidden_actions)


def test_null_holdout_when_frozen_but_none_confirmed():
    l6 = _StubL6(n_frozen=3, n_soft=0)
    l8 = _StubL8(n_confirmed=0)
    result = run("EXP-TEST", l6, l8)
    assert result.outcome == ExperimentOutcome.NULL_HOLDOUT.value


def test_success_when_some_confirmed():
    l6 = _StubL6(n_frozen=3, n_soft=1)
    l8 = _StubL8(n_confirmed=2)
    result = run("EXP-TEST", l6, l8)
    assert result.outcome == ExperimentOutcome.SUCCESS.value
    assert result.n_holdout_confirmed == 2


def test_soft_only_success_path():
    l6 = _StubL6(n_frozen=0, n_soft=2)
    l8 = None
    result = run("EXP-TEST", l6, l8)
    assert result.outcome == ExperimentOutcome.SUCCESS.value
    assert result.n_soft_gates == 2


def test_inconclusive_when_holdout_not_run():
    l6 = _StubL6(n_frozen=2, n_soft=0)
    result = run("EXP-TEST", l6, None)
    assert result.outcome == ExperimentOutcome.INCONCLUSIVE.value


# ══════════════════════════════════════════════════════════════════
# Forbidden actions
# ══════════════════════════════════════════════════════════════════

def test_null_dev_forbids_rerun():
    l6 = _StubL6()
    result = run("EXP-TEST", l6)
    assert any("rerun" in a for a in result.forbidden_actions)
    assert any("tune_thresholds" in a for a in result.forbidden_actions)


def test_null_holdout_forbids_modify_rules():
    l6 = _StubL6(n_frozen=1)
    l8 = _StubL8(n_confirmed=0)
    result = run("EXP-TEST", l6, l8)
    assert any("modify_rules" in a for a in result.forbidden_actions)


def test_success_forbids_modify_after_holdout():
    l6 = _StubL6(n_frozen=1)
    l8 = _StubL8(n_confirmed=1)
    result = run("EXP-TEST", l6, l8)
    assert any("modify_rules" in a for a in result.forbidden_actions)


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_write_result(tmp_path):
    l6 = _StubL6(n_frozen=1)
    l8 = _StubL8(n_confirmed=1)
    result = run("EXP-TEST", l6, l8)
    write_result(result, tmp_path)
    assert (tmp_path / "experiment_result.json").exists()
    with (tmp_path / "experiment_result.json").open() as f:
        d = json.load(f)
    assert d["outcome"] == ExperimentOutcome.SUCCESS.value


def test_missing_experiment_id_raises():
    l6 = _StubL6()
    with pytest.raises(ValueError, match="experiment_id"):
        run("", l6)
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L9_attribution.py \
       vp_analysis/tests/test_L10_bad_entry.py \
       vp_analysis/tests/test_L11_null_protocol.py -v
```

Kỳ vọng:

```text
test_L9_attribution.py     11 passed
test_L10_bad_entry.py      10 passed
test_L11_null_protocol.py   9 passed
────────────────────────────────
Total                      30 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 348 + 30 = 378 passed
```

---

## Sprint 9 hoàn tất

**Deliverables:**
- `L9_attribution.py` — Entry/Exit attribution, exit policy decomposition, cross-style consistency
- `L10_bad_entry.py` — Canary labels (7-level), bad feature screening với FDR, composite filter, holdout evaluation
- `L11_null_protocol.py` — Outcome classification (4 loại), allowed/forbidden actions
- 30 tests

**Điểm quan trọng:**
1. **L9 read-only** — không mutate gì cả, chỉ measurement
2. **L10 tách dev/holdout** — canary labels + screening trên dev, evaluate filter trên holdout (đã unsealed bởi L8)
3. **L10 có FDR pool riêng** — `bad_entry` pool tách biệt khỏi `hard_gate` và `soft_gate`
4. **L10 filter confirmed** = flagged EV < unflagged EV AND flagged EV < 0
5. **L11 pure logic** — không đọc data, chỉ classify outcome và enumerate allowed/forbidden actions
6. **Null protocol** rõ ràng:
   - `NULL_DEV` → không unseal holdout
   - `NULL_HOLDOUT` → đã unseal, không rerun
   - `SUCCESS` → deploy, không rerun

**Kernel + L0-L11 hiện có:**
```text
┌─────────────────────────────────────────────────────────────┐
│  Sprint 0A/B/C — Governance kernel        141 tests         │
│  Sprint 1 — L0 Data Hygiene                 32 tests         │
│  Sprint 2 — L1 Boundary + L2 Features       30 tests         │
│  Sprint 3 — L3 EDA + Shape Verification     24 tests         │
│  Sprint 4 — L4 Hard Gate Discovery          22 tests         │
│  Sprint 5 — L5 Soft Gate Discovery          16 tests         │
│  Sprint 6 — L6 Multiple Testing + Freeze    25 tests         │
│  Sprint 7 — L7 Dev Optimization             32 tests         │
│  Sprint 8 — L8 Holdout Apply                26 tests         │
│  Sprint 9 — L9+L10+L11 Attribution/Bad/Null 30 tests         │
│  ─────────────────────────────────────────────────────────  │
│  Total                                     378 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Sprint 10 (final) — Orchestrator + End-to-End:**

Sprint cuối cùng kết nối tất cả layers thành pipeline duy nhất:
- `pipeline.py` — orchestrator chạy L0 → L11 với contract, manifest, governance
- Config yaml loading
- CLI entry point
- End-to-end test với synthetic dataset biết ground truth
- Leak detection test (inject fake leak, verify catch)
- Output: `output/experiments/{experiment_id}/` với tất cả subdirs
- ~10 tests end-to-end
