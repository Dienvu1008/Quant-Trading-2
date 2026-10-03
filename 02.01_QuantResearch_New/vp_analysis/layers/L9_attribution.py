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
    mae_mfe_tolerance: float = 0.20      # relative range tolerance


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class EntryExitAttribution:
    rule_id: str
    n_trades: int
    mae_atr_mean: float
    mfe_atr_mean: float
    mfe_mae_ratio: float
    profit_mean: float
    exit_capture_ratio: float
    entry_quality: str   # "strong" | "moderate" | "weak"

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
    ev_by_style: dict
    n_by_style: dict
    trail_rescues_negative_entry: bool
    best_style: Optional[int]
    ev_spread: Optional[float]

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "ev_by_style": {
                k: (round(v, 6) if v is not None else None)
                for k, v in self.ev_by_style.items()
            },
            "n_by_style": dict(self.n_by_style),
            "trail_rescues_negative_entry": self.trail_rescues_negative_entry,
            "best_style": self.best_style,
            "ev_spread": (round(self.ev_spread, 6) if self.ev_spread is not None else None),
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
            "mae_by_style": {
                k: (round(v, 6) if v is not None else None)
                for k, v in self.mae_by_style.items()
            },
            "mfe_by_style": {
                k: (round(v, 6) if v is not None else None)
                for k, v in self.mfe_by_style.items()
            },
            "mae_consistent": self.mae_consistent,
            "mfe_consistent": self.mfe_consistent,
            "mae_range_pct": (round(self.mae_range_pct, 6) if self.mae_range_pct is not None else None),
            "mfe_range_pct": (round(self.mfe_range_pct, 6) if self.mfe_range_pct is not None else None),
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
    """Attribution analysis on (already-unsealed) holdout. Read-only."""
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
                "skipped exit policy analysis"
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


# ─── Entry vs Exit ───────────────────────────────────────────────

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

    profits_v = profits[valid]
    mae_v = mae[valid]
    mfe_v = mfe[valid]

    mae_mean = float(mae_v.mean())
    mfe_mean = float(mfe_v.mean())
    profit_mean = float(profits_v.mean())
    ratio = mfe_mean / (mae_mean + 1e-9)

    capture = float(np.clip(profit_mean / mfe_mean, -1.0, 2.0)) if mfe_mean > 1e-9 else 0.0

    if ratio >= cfg.strong_entry_ratio:
        quality = "strong"
    elif ratio >= cfg.moderate_entry_ratio:
        quality = "moderate"
    else:
        quality = "weak"

    return EntryExitAttribution(
        rule_id=rule.rule_id, n_trades=n,
        mae_atr_mean=mae_mean, mfe_atr_mean=mfe_mean,
        mfe_mae_ratio=ratio, profit_mean=profit_mean,
        exit_capture_ratio=capture, entry_quality=quality,
    )


# ─── Exit policy decomposition ───────────────────────────────────

def _exit_policy_decomposition(
    rule: FrozenRule,
    gated: pd.DataFrame,
    cfg: AttributionConfig,
    style_col: str,
) -> Optional[ExitPolicyDecomposition]:
    styles_num = pd.to_numeric(gated[style_col], errors="coerce")
    styles = styles_num.dropna().unique()
    if len(styles) < 2:
        return None

    ev_by_style: dict[str, Optional[float]] = {}
    n_by_style: dict[str, int] = {}

    for s in sorted(styles):
        key = str(int(s))
        sub = gated[styles_num == s]
        n_by_style[key] = int(len(sub))
        if len(sub) < cfg.min_style_trades:
            ev_by_style[key] = None
            continue
        profits = pd.to_numeric(sub["_profit"], errors="coerce").dropna()
        ev_by_style[key] = float(profits.mean()) if len(profits) > 0 else None

    valid_evs = {k: v for k, v in ev_by_style.items() if v is not None}
    if len(valid_evs) < 2:
        return ExitPolicyDecomposition(
            rule_id=rule.rule_id, ev_by_style=ev_by_style,
            n_by_style=n_by_style, trail_rescues_negative_entry=False,
            best_style=None, ev_spread=None,
        )

    ev_vals = list(valid_evs.values())
    best_key = max(valid_evs, key=valid_evs.__getitem__)
    spread = max(ev_vals) - min(ev_vals)
    has_negative = any(v < 0 for v in valid_evs.values())
    has_positive = any(v > 0 for v in valid_evs.values())
    rescues = has_negative and has_positive

    try:
        best_int: Optional[int] = int(best_key.lstrip("-") if best_key.lstrip("-").isdigit() else "0")
        # Re-parse properly
        best_int = int(best_key)
    except (ValueError, AttributeError):
        best_int = None

    return ExitPolicyDecomposition(
        rule_id=rule.rule_id, ev_by_style=ev_by_style,
        n_by_style=n_by_style, trail_rescues_negative_entry=rescues,
        best_style=best_int, ev_spread=spread,
    )


# ─── Cross-style consistency ─────────────────────────────────────

def _cross_style_consistency(
    rule: FrozenRule,
    gated: pd.DataFrame,
    cfg: AttributionConfig,
    style_col: str,
) -> Optional[CrossStyleConsistency]:
    if "maeATR" not in gated.columns or "mfeATR" not in gated.columns:
        return None

    styles_num = pd.to_numeric(gated[style_col], errors="coerce")
    styles = styles_num.dropna().unique()
    if len(styles) < 2:
        return None

    mae_by_style: dict[str, Optional[float]] = {}
    mfe_by_style: dict[str, Optional[float]] = {}

    for s in sorted(styles):
        key = str(int(s))
        sub = gated[styles_num == s]
        if len(sub) < cfg.min_style_trades:
            mae_by_style[key] = None
            mfe_by_style[key] = None
            continue
        mae_vals = pd.to_numeric(sub["maeATR"], errors="coerce").dropna()
        mfe_vals = pd.to_numeric(sub["mfeATR"], errors="coerce").dropna()
        mae_by_style[key] = float(mae_vals.mean()) if len(mae_vals) else None
        mfe_by_style[key] = float(mfe_vals.mean()) if len(mfe_vals) else None

    mae_valid = [v for v in mae_by_style.values() if v is not None]
    mfe_valid = [v for v in mfe_by_style.values() if v is not None]

    mae_range = _relative_range(mae_valid)
    mfe_range = _relative_range(mfe_valid)

    mae_consistent = mae_range is not None and mae_range <= cfg.mae_mfe_tolerance
    mfe_consistent = mfe_range is not None and mfe_range <= cfg.mae_mfe_tolerance

    return CrossStyleConsistency(
        rule_id=rule.rule_id,
        mae_by_style=mae_by_style, mfe_by_style=mfe_by_style,
        mae_consistent=mae_consistent, mfe_consistent=mfe_consistent,
        mae_range_pct=mae_range, mfe_range_pct=mfe_range,
    )


def _relative_range(vals: list[float]) -> Optional[float]:
    if len(vals) < 2:
        return None
    lo, hi = min(vals), max(vals)
    if abs(hi) < 1e-12:
        return 0.0
    return (hi - lo) / abs(hi)


# ─── Rule filter (consistent with L7, L8) ────────────────────────

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
    with (output_dir / "attribution_summary.json").open("w", encoding="utf-8") as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)
