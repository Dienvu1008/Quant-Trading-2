"""Layer 8 — Holdout Apply (Report Only).

First and only place the sealed holdout is unsealed. Everything here is
read-only with respect to frozen artifacts: rules, SL/TP selections, and
sizing configs are consumed, never mutated.

Produces:
  - Per-rule evaluation on holdout
  - SL/TP simulation report on holdout
  - Sizing confirmation report
  - Degradation analysis (holdout vs dev)

No FDR, no discovery, no optimization. This layer answers a single
question: "how do the frozen artifacts behave on data they have never
seen?"
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

from ..core.frozen_types import FrozenProductionConfig, FrozenRule


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class HoldoutConfig:
    # Minimum trades for a rule to be evaluable
    min_gated_trades: int = 20

    # Confirmation thresholds (relative to dev)
    ev_degradation_factor: float = 0.50   # holdout_ev >= factor * dev_ev
    pf_min: float = 1.00
    wr_degradation_factor: float = 0.80   # holdout_wr >= factor * dev_wr

    # SL/TP evaluation
    min_sl_tp_trades: int = 20
    sl_tp_degradation_factor: float = 0.50

    # Sizing evaluation
    min_sizing_trades: int = 20

    # Degradation analysis
    n_time_buckets: int = 4
    min_bucket_trades: int = 10
    degradation_slope_alpha: float = 0.10

    # Randomness
    seed: int = 42


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class RuleEvaluation:
    rule_id: str
    symbol: str
    setup: str
    dev_ev: float
    dev_wr: float
    n_holdout_total: int
    n_gated: int
    n_pass_ratio: float
    holdout_ev: float
    holdout_wr: float
    holdout_pf: float
    degradation_ratio: Optional[float]
    holdout_confirmed: bool
    reason: str

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "symbol": self.symbol,
            "setup": self.setup,
            "dev_ev": round(self.dev_ev, 6),
            "dev_wr": round(self.dev_wr, 6),
            "n_holdout_total": int(self.n_holdout_total),
            "n_gated": int(self.n_gated),
            "n_pass_ratio": round(self.n_pass_ratio, 6),
            "holdout_ev": round(self.holdout_ev, 6),
            "holdout_wr": round(self.holdout_wr, 6),
            "holdout_pf": round(self.holdout_pf, 6),
            "degradation_ratio": (
                round(self.degradation_ratio, 6)
                if self.degradation_ratio is not None else None
            ),
            "holdout_confirmed": self.holdout_confirmed,
            "reason": self.reason,
        }


@dataclass(frozen=True)
class SLTPEvaluation:
    rule_id: str
    sl: float
    tp: float
    n_gated: int
    dev_ev_baseline: float
    holdout_ev_unadjusted: float
    holdout_ev_simulated: float
    holdout_pf: float
    degradation_ratio: Optional[float]
    confirmed: bool
    reason: str

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "sl": round(self.sl, 6),
            "tp": round(self.tp, 6),
            "n_gated": int(self.n_gated),
            "dev_ev_baseline": round(self.dev_ev_baseline, 6),
            "holdout_ev_unadjusted": round(self.holdout_ev_unadjusted, 6),
            "holdout_ev_simulated": round(self.holdout_ev_simulated, 6),
            "holdout_pf": round(self.holdout_pf, 6),
            "degradation_ratio": (
                round(self.degradation_ratio, 6)
                if self.degradation_ratio is not None else None
            ),
            "confirmed": self.confirmed,
            "reason": self.reason,
        }


@dataclass(frozen=True)
class SizingEvaluation:
    rule_id: str
    lot_mult: float
    n_gated: int
    holdout_ev: float
    holdout_wr: float
    dev_ev: float
    confirmed: bool
    reason: str

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "lot_mult": round(self.lot_mult, 6),
            "n_gated": int(self.n_gated),
            "holdout_ev": round(self.holdout_ev, 6),
            "holdout_wr": round(self.holdout_wr, 6),
            "dev_ev": round(self.dev_ev, 6),
            "confirmed": self.confirmed,
            "reason": self.reason,
        }


@dataclass(frozen=True)
class DegradationAnalysis:
    rule_id: str
    dev_ev: float
    holdout_ev: float
    slope_p: Optional[float]
    buckets: tuple

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "dev_ev": round(self.dev_ev, 6),
            "holdout_ev": round(self.holdout_ev, 6),
            "slope_p": (
                round(self.slope_p, 6) if self.slope_p is not None else None
            ),
            "buckets": list(self.buckets),
        }


@dataclass(frozen=True)
class LayerEightResult:
    experiment_id: str
    rule_evaluations: tuple
    sl_tp_evaluations: tuple
    sizing_evaluations: tuple
    degradation_analyses: tuple

    n_rules_evaluated: int
    n_rules_confirmed: int
    n_rules_insufficient: int
    n_sl_tp_confirmed: int
    n_sizing_confirmed: int

    overall_confirmation_rate: float
    null_result: bool
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "experiment_id": self.experiment_id,
            "ran_at": self.ran_at,
            "n_rules_evaluated": self.n_rules_evaluated,
            "n_rules_confirmed": self.n_rules_confirmed,
            "n_rules_insufficient": self.n_rules_insufficient,
            "n_sl_tp_confirmed": self.n_sl_tp_confirmed,
            "n_sizing_confirmed": self.n_sizing_confirmed,
            "overall_confirmation_rate": round(
                self.overall_confirmation_rate, 4,
            ),
            "null_result": self.null_result,
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    sealed_holdout,
    production_config: FrozenProductionConfig,
    contract,
    experiment_id: str,
    output_dir: Optional[Path] = None,
    config: Optional[HoldoutConfig] = None,
) -> LayerEightResult:
    """Evaluate frozen artifacts on the sealed holdout (one-time unseal)."""
    cfg = config or HoldoutConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if not experiment_id:
        raise ValueError("L8: experiment_id is required")
    if not isinstance(production_config, FrozenProductionConfig):
        raise TypeError("L8: production_config must be FrozenProductionConfig")

    warnings: list[str] = []

    # ─── Unseal (one-time, kernel-enforced) ─────────────────────
    try:
        holdout_df = sealed_holdout.unseal_once(
            experiment_id=experiment_id,
            reason="layer_8_final_evaluation",
        )
    except Exception as e:
        raise RuntimeError(f"L8: failed to unseal holdout: {e}")

    if holdout_df is None or len(holdout_df) == 0:
        raise ValueError("L8: holdout is empty after unseal")

    # Normalise profit column
    if "_profit" not in holdout_df.columns:
        if "profitUSD" in holdout_df.columns:
            holdout_df = holdout_df.copy()
            holdout_df["_profit"] = pd.to_numeric(
                holdout_df["profitUSD"], errors="coerce",
            )
        else:
            raise ValueError(
                "L8: holdout has no '_profit' nor 'profitUSD' column"
            )

    # ─── Per-rule evaluation ─────────────────────────────────────
    rule_evals: list[RuleEvaluation] = []
    for rule in production_config.rules:
        ev = _evaluate_rule(holdout_df, rule, cfg)
        rule_evals.append(ev)

    # ─── SL/TP evaluation ────────────────────────────────────────
    sl_tp_evals: list[SLTPEvaluation] = []
    sl_tp_lookup = {
        s["rule_id"]: s
        for s in production_config.sl_tp_selections
        if isinstance(s, dict) and "rule_id" in s
    }
    for rule in production_config.rules:
        sel = sl_tp_lookup.get(rule.rule_id)
        if sel is None:
            continue
        ev = _evaluate_sl_tp(holdout_df, rule, sel, cfg)
        if ev is not None:
            sl_tp_evals.append(ev)

    # ─── Sizing evaluation ───────────────────────────────────────
    sizing_evals: list[SizingEvaluation] = []
    sizing_lookup = {
        s["rule_id"]: s
        for s in production_config.sizing_configs
        if isinstance(s, dict) and "rule_id" in s
    }
    for rule in production_config.rules:
        sel = sizing_lookup.get(rule.rule_id)
        if sel is None:
            continue
        ev = _evaluate_sizing(holdout_df, rule, sel, cfg)
        if ev is not None:
            sizing_evals.append(ev)

    # ─── Degradation analysis ────────────────────────────────────
    degradations: list[DegradationAnalysis] = []
    for rule in production_config.rules:
        d = _degradation_analysis(holdout_df, rule, cfg)
        if d is not None:
            degradations.append(d)

    # ─── Aggregate ───────────────────────────────────────────────
    n_confirmed = sum(1 for e in rule_evals if e.holdout_confirmed)
    n_insufficient = sum(
        1 for e in rule_evals if e.reason.startswith("insufficient")
    )
    n_rules = len(rule_evals)
    confirmation_rate = (n_confirmed / n_rules) if n_rules > 0 else 0.0
    null_result = (n_rules > 0 and n_confirmed == 0)

    if null_result:
        warnings.append(
            f"NULL RESULT: 0/{n_rules} rules confirmed on holdout. "
            "Holdout remains sealed for future experiments."
        )

    result = LayerEightResult(
        experiment_id=experiment_id,
        rule_evaluations=tuple(rule_evals),
        sl_tp_evaluations=tuple(sl_tp_evals),
        sizing_evaluations=tuple(sizing_evals),
        degradation_analyses=tuple(degradations),
        n_rules_evaluated=n_rules,
        n_rules_confirmed=n_confirmed,
        n_rules_insufficient=n_insufficient,
        n_sl_tp_confirmed=sum(1 for e in sl_tp_evals if e.confirmed),
        n_sizing_confirmed=sum(1 for e in sizing_evals if e.confirmed),
        overall_confirmation_rate=confirmation_rate,
        null_result=null_result,
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Rule evaluation ─────────────────────────────────────────────

def _evaluate_rule(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    cfg: HoldoutConfig,
) -> RuleEvaluation:
    gated = _filter_by_rule(holdout_df, rule)
    n_gated = len(gated)
    n_total = len(holdout_df)
    pass_ratio = (n_gated / n_total) if n_total else 0.0

    def _insufficient(reason: str) -> RuleEvaluation:
        return RuleEvaluation(
            rule_id=rule.rule_id, symbol=rule.symbol, setup=rule.setup,
            dev_ev=rule.test_ev_mean, dev_wr=rule.test_wr_mean,
            n_holdout_total=n_total, n_gated=n_gated,
            n_pass_ratio=pass_ratio,
            holdout_ev=0.0, holdout_wr=0.0, holdout_pf=0.0,
            degradation_ratio=None,
            holdout_confirmed=False, reason=reason,
        )

    if n_gated < cfg.min_gated_trades:
        return _insufficient(
            f"insufficient_trades({n_gated}<{cfg.min_gated_trades})"
        )

    profits = pd.to_numeric(gated["_profit"], errors="coerce").dropna().values
    if len(profits) == 0:
        return _insufficient("no_valid_profits")

    ev = float(profits.mean())
    wr = float((profits > 0).mean())
    pos = profits[profits > 0].sum()
    neg = abs(profits[profits < 0].sum())
    pf = float(pos / neg) if neg > 0 else 999.0

    ratio: Optional[float] = (
        ev / rule.test_ev_mean if rule.test_ev_mean > 1e-9 else None
    )

    reasons: list[str] = []
    if rule.test_ev_mean > 1e-9:
        threshold_ev = rule.test_ev_mean * cfg.ev_degradation_factor
        if ev < threshold_ev:
            reasons.append(
                f"ev_degraded({ev:.4f} < {threshold_ev:.4f})"
            )
    elif ev <= 0:
        reasons.append(f"ev_nonpositive({ev:.4f})")

    if pf < cfg.pf_min:
        reasons.append(f"pf_low({pf:.3f} < {cfg.pf_min})")

    if rule.test_wr_mean > 1e-9:
        threshold_wr = rule.test_wr_mean * cfg.wr_degradation_factor
        if wr < threshold_wr:
            reasons.append(
                f"wr_degraded({wr:.3f} < {threshold_wr:.3f})"
            )

    confirmed = len(reasons) == 0
    return RuleEvaluation(
        rule_id=rule.rule_id, symbol=rule.symbol, setup=rule.setup,
        dev_ev=rule.test_ev_mean, dev_wr=rule.test_wr_mean,
        n_holdout_total=n_total, n_gated=n_gated, n_pass_ratio=pass_ratio,
        holdout_ev=ev, holdout_wr=wr, holdout_pf=min(pf, 999.0),
        degradation_ratio=ratio,
        holdout_confirmed=confirmed,
        reason="ok" if confirmed else "; ".join(reasons),
    )


# ─── SL/TP evaluation ────────────────────────────────────────────

def _evaluate_sl_tp(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    selection: dict,
    cfg: HoldoutConfig,
) -> Optional[SLTPEvaluation]:
    gated = _filter_by_rule(holdout_df, rule)
    if len(gated) < cfg.min_sl_tp_trades:
        return None
    if "maeATR" not in gated.columns or "mfeATR" not in gated.columns:
        return None

    sl = float(selection["sl"])
    tp = float(selection["tp"])

    profits = pd.to_numeric(gated["_profit"], errors="coerce").values
    mae = pd.to_numeric(gated["maeATR"], errors="coerce").values
    mfe = pd.to_numeric(gated["mfeATR"], errors="coerce").values
    valid = ~np.isnan(profits) & ~np.isnan(mae) & ~np.isnan(mfe)
    if valid.sum() < cfg.min_sl_tp_trades:
        return None

    profits_v = profits[valid]
    mae_v = mae[valid]
    mfe_v = mfe[valid]

    ev_unadj = float(profits_v.mean())
    sim = _simulate_sl_tp(profits_v, mae_v, mfe_v, sl, tp)
    ev_sim = float(sim.mean())
    pos = sim[sim > 0].sum()
    neg = abs(sim[sim < 0].sum())
    pf = float(pos / neg) if neg > 0 else 999.0

    ratio: Optional[float] = (
        ev_sim / rule.test_ev_mean if rule.test_ev_mean > 1e-9 else None
    )

    reasons: list[str] = []
    if ev_sim <= 0:
        reasons.append(f"simulated_ev_nonpositive({ev_sim:.4f})")
    if pf < cfg.pf_min:
        reasons.append(f"pf_low({pf:.3f})")
    if rule.test_ev_mean > 1e-9:
        threshold = rule.test_ev_mean * cfg.sl_tp_degradation_factor
        if ev_sim < threshold:
            reasons.append(f"ev_degraded({ev_sim:.4f} < {threshold:.4f})")

    confirmed = len(reasons) == 0
    return SLTPEvaluation(
        rule_id=rule.rule_id, sl=sl, tp=tp, n_gated=int(valid.sum()),
        dev_ev_baseline=rule.test_ev_mean,
        holdout_ev_unadjusted=ev_unadj,
        holdout_ev_simulated=ev_sim,
        holdout_pf=min(pf, 999.0),
        degradation_ratio=ratio,
        confirmed=confirmed,
        reason="ok" if confirmed else "; ".join(reasons),
    )


def _simulate_sl_tp(
    profits: np.ndarray, mae: np.ndarray, mfe: np.ndarray,
    sl: float, tp: float,
) -> np.ndarray:
    """Consistent with L7 simulation logic."""
    stopped = mae >= sl
    hit_tp = (~stopped) & (mfe >= tp)
    sim = profits.copy()
    sim[stopped] = -sl
    sim[hit_tp] = tp
    return sim


# ─── Sizing evaluation ───────────────────────────────────────────

def _evaluate_sizing(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    selection: dict,
    cfg: HoldoutConfig,
) -> Optional[SizingEvaluation]:
    gated = _filter_by_rule(holdout_df, rule)
    if len(gated) < cfg.min_sizing_trades:
        return None

    profits = pd.to_numeric(gated["_profit"], errors="coerce").dropna().values
    if len(profits) == 0:
        return None

    ev = float(profits.mean())
    wr = float((profits > 0).mean())
    lot_mult = float(selection.get("lot_mult", 1.0))

    reasons: list[str] = []
    if ev <= 0:
        reasons.append(f"ev_nonpositive({ev:.4f})")
    if wr <= 0:
        reasons.append(f"wr_zero({wr:.4f})")

    confirmed = len(reasons) == 0
    return SizingEvaluation(
        rule_id=rule.rule_id, lot_mult=lot_mult,
        n_gated=int(len(profits)),
        holdout_ev=ev, holdout_wr=wr, dev_ev=rule.test_ev_mean,
        confirmed=confirmed,
        reason="ok" if confirmed else "; ".join(reasons),
    )


# ─── Degradation analysis ────────────────────────────────────────

def _degradation_analysis(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    cfg: HoldoutConfig,
) -> Optional[DegradationAnalysis]:
    gated = _filter_by_rule(holdout_df, rule)
    min_needed = cfg.min_bucket_trades * cfg.n_time_buckets
    if len(gated) < min_needed:
        return None

    time_col = None
    for c in ("time", "entryTime"):
        if c in gated.columns:
            time_col = c
            break
    if time_col is None:
        return None

    gated = gated.copy()
    gated["_profit"] = pd.to_numeric(gated["_profit"], errors="coerce")
    gated = gated.dropna(subset=["_profit", time_col])
    if len(gated) < min_needed:
        return None

    gated = gated.sort_values(time_col).reset_index(drop=True)
    n = len(gated)
    bucket_size = n // cfg.n_time_buckets

    buckets: list[dict] = []
    bucket_evs: list[float] = []
    for i in range(cfg.n_time_buckets):
        start = i * bucket_size
        end = (i + 1) * bucket_size if i < cfg.n_time_buckets - 1 else n
        sub = gated.iloc[start:end]
        if len(sub) < cfg.min_bucket_trades:
            buckets.append({"bucket_idx": i, "n": int(len(sub)), "ev": None})
            continue
        ev_b = float(sub["_profit"].mean())
        bucket_evs.append(ev_b)
        buckets.append({"bucket_idx": i, "n": int(len(sub)), "ev": round(ev_b, 6)})

    slope_p: Optional[float] = None
    if len(bucket_evs) >= 3:
        x = np.arange(len(bucket_evs))
        y = np.array(bucket_evs)
        slope, _, _, p_two, _ = stats.linregress(x, y)
        slope_p = float(p_two / 2) if slope < 0 else 1.0

    holdout_ev = float(gated["_profit"].mean())
    return DegradationAnalysis(
        rule_id=rule.rule_id,
        dev_ev=rule.test_ev_mean,
        holdout_ev=holdout_ev,
        slope_p=slope_p,
        buckets=tuple(buckets),
    )


# ─── Rule filter (consistent with L7) ────────────────────────────

def _filter_by_rule(df: pd.DataFrame, rule: FrozenRule) -> pd.DataFrame:
    if not rule.features:
        return df.iloc[0:0]

    if rule.gate_type == "threshold":
        feat = rule.features[0]
        if feat not in df.columns:
            return df.iloc[0:0]
        vals = pd.to_numeric(df[feat], errors="coerce").fillna(0.0).values
        mask = vals >= rule.lower_bound if rule.direction == 1 else vals <= rule.upper_bound
        return df[mask]

    if rule.gate_type == "band":
        feat = rule.features[0]
        if feat not in df.columns:
            return df.iloc[0:0]
        vals = pd.to_numeric(df[feat], errors="coerce").fillna(0.0).values
        mask = (vals >= rule.lower_bound) & (vals <= rule.upper_bound)
        return df[mask]

    if rule.gate_type == "model":
        missing = [f for f in rule.features if f not in df.columns]
        if missing:
            return df.iloc[0:0]
        X = df[list(rule.features)].fillna(0.0).values.astype(float)
        w = np.array(rule.model_weights, dtype=float)
        scores = X @ w + float(rule.model_bias)
        mask = scores >= float(rule.score_threshold)
        return df[mask]

    return df.iloc[0:0]


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerEightResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    if result.rule_evaluations:
        pd.DataFrame(
            [e.to_dict() for e in result.rule_evaluations]
        ).to_csv(output_dir / "holdout_evaluation.csv", index=False)

    if result.sl_tp_evaluations:
        pd.DataFrame(
            [e.to_dict() for e in result.sl_tp_evaluations]
        ).to_csv(output_dir / "sl_tp_holdout_report.csv", index=False)

    if result.sizing_evaluations:
        pd.DataFrame(
            [e.to_dict() for e in result.sizing_evaluations]
        ).to_csv(output_dir / "sizing_holdout_report.csv", index=False)

    if result.degradation_analyses:
        pd.DataFrame(
            [d.to_dict() for d in result.degradation_analyses]
        ).to_csv(output_dir / "holdout_degradation.csv", index=False)

    with (output_dir / "holdout_summary.json").open(
        "w", encoding="utf-8",
    ) as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)
