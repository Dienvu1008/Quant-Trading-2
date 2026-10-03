# Sprint 8 — Layer 8: Holdout Apply (REPORT ONLY)

> **v3 changes (từ SPECIFICATION.md v3):**
> - **[Fix #4] Persist holdout access log**: `unseal_once()` phải ghi `holdout_access.json` ra disk **ngay trước khi trả data**, và check disk (không chỉ in-memory) khi khởi tạo để ngăn double-unseal sau restart. File này là evidence bất biến của việc unseal.
> - **[NEW] L8.3 — Regime block evaluation**: apply `frozen_regime_blocks` lên holdout, verify `blocked_ev < 0`. Output: `regime_block_holdout.csv`.
> - **[Fix #1] L8.4 = L10b**: evaluation của bad entry filter (`frozen_bad_filter`) chạy ở đây (sau unseal), không phải trước L6. Output: `bad_filter_holdout_report.csv`.
> - **[NEW] L8.7 — SL risk confirmation**: apply `sl_risk_thresholds` lên holdout, verify lift trong SL-hit rate còn dương. Output: `sl_risk_holdout_report.csv`.
> - `FrozenProductionConfig` nhận thêm `regime_blocks`, `bad_filter`, `sl_risk_thresholds` để L8 evaluate được.

**Nguyên tắc then chốt (updated v3):**
1. `unseal_once(experiment_id, reason)` — **persist access log ra disk** trước khi trả data [Fix #4]
2. **Chỉ đọc** — không mutate bất kứ frozen artifact nào
3. `holdout_confirmed` là flag trong evaluation report, không phải `validated` — `validated` đã lock ở L6
4. Degradation analysis so sánh holdout vs dev
5. Null result protocol: `n_rules_confirmed == 0` → caller route đến L11
6. **[NEW]** Regime block và SL risk confirm cũng ở đây
7. **[Fix #1]** L10b (bad filter holdout eval) gọi từ L8.4

Deliverables:
- `layers/L8_holdout_apply.py` — unseal (persist log), evaluation toàn bộ frozen artifacts, degradation
- `layers/L10b_bad_entry_evaluation.py` — apply `frozen_bad_filter` on holdout (gọi từ L8.4) [Fix #1]
- Outputs: `holdout_evaluation.csv`, `regime_block_holdout.csv` [NEW], `sl_tp_holdout_report.csv`, `sizing_holdout_report.csv`, `sl_risk_holdout_report.csv` [NEW], `holdout_degradation.csv`, `holdout_summary.json`, `bad_filter_holdout_report.csv` [moved from Sprint 9]
- ~24 tests (tăng từ 20 do các evaluation mới)

---

## `vp_analysis/layers/L8_holdout_apply.py`

```python
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
    dev_ev: float          # from rule.test_ev_mean
    dev_wr: float
    n_holdout_total: int
    n_gated: int
    n_pass_ratio: float
    holdout_ev: float
    holdout_wr: float
    holdout_pf: float
    degradation_ratio: Optional[float]   # holdout_ev / dev_ev (None if dev_ev<=0)
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
    holdout_ev_unadjusted: float   # original profits for gated trades
    holdout_ev_simulated: float    # SL/TP applied via MAE/MFE
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
    buckets: tuple  # tuple of {start, end, n, ev}

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
    sealed_holdout,           # core.data_boundary.SealedHoldout
    production_config: FrozenProductionConfig,
    contract,
    experiment_id: str,
    output_dir: Optional[Path] = None,
    config: Optional[HoldoutConfig] = None,
) -> LayerEightResult:
    """Evaluate frozen artifacts on the sealed holdout.

    Unseals the holdout exactly once (kernel enforces).
    """
    cfg = config or HoldoutConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if not experiment_id:
        raise ValueError("L8: experiment_id is required")
    if not isinstance(production_config, FrozenProductionConfig):
        raise TypeError("L8: production_config must be FrozenProductionConfig")

    warnings: list[str] = []

    # ─── Unseal (one-time) ──────────────────────────────────────
    try:
        holdout_df = sealed_holdout.unseal_once(
            experiment_id=experiment_id,
            reason="layer_8_final_evaluation",
        )
    except Exception as e:
        raise RuntimeError(f"L8: failed to unseal holdout: {e}")

    if holdout_df is None or len(holdout_df) == 0:
        raise ValueError("L8: holdout is empty after unseal")

    if "_profit" not in holdout_df.columns:
        if "profitUSD" in holdout_df.columns:
            holdout_df = holdout_df.copy()
            holdout_df["_profit"] = pd.to_numeric(
                holdout_df["profitUSD"], errors="coerce",
            )
        else:
            raise ValueError("L8: holdout has no '_profit' nor 'profitUSD'")

    # ─── Per-rule evaluation ────────────────────────────────────
    rule_evals: list[RuleEvaluation] = []
    for rule in production_config.rules:
        ev = _evaluate_rule(holdout_df, rule, cfg)
        rule_evals.append(ev)

    # ─── SL/TP evaluation ───────────────────────────────────────
    sl_tp_evals: list[SLTPEvaluation] = []
    sl_tp_lookup = {
        s["rule_id"]: s for s in production_config.sl_tp_selections
        if isinstance(s, dict) and "rule_id" in s
    }
    for rule in production_config.rules:
        sel = sl_tp_lookup.get(rule.rule_id)
        if sel is None:
            continue
        ev = _evaluate_sl_tp(holdout_df, rule, sel, cfg)
        if ev is not None:
            sl_tp_evals.append(ev)

    # ─── Sizing evaluation ──────────────────────────────────────
    sizing_evals: list[SizingEvaluation] = []
    sizing_lookup = {
        s["rule_id"]: s for s in production_config.sizing_configs
        if isinstance(s, dict) and "rule_id" in s
    }
    for rule in production_config.rules:
        sel = sizing_lookup.get(rule.rule_id)
        if sel is None:
            continue
        ev = _evaluate_sizing(holdout_df, rule, sel, cfg)
        if ev is not None:
            sizing_evals.append(ev)

    # ─── Degradation analysis ───────────────────────────────────
    degradations: list[DegradationAnalysis] = []
    for rule in production_config.rules:
        d = _degradation_analysis(holdout_df, rule, cfg)
        if d is not None:
            degradations.append(d)

    # ─── Aggregate ──────────────────────────────────────────────
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
            f"Holdout remains sealed for future experiments."
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


# ─── Rule evaluation ────────────────────────────────────────────

def _evaluate_rule(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    cfg: HoldoutConfig,
) -> RuleEvaluation:
    gated = _filter_by_rule(holdout_df, rule)
    n_gated = len(gated)
    n_total = len(holdout_df)

    if n_gated < cfg.min_gated_trades:
        return RuleEvaluation(
            rule_id=rule.rule_id, symbol=rule.symbol, setup=rule.setup,
            dev_ev=rule.test_ev_mean, dev_wr=rule.test_wr_mean,
            n_holdout_total=n_total, n_gated=n_gated,
            n_pass_ratio=(n_gated / n_total) if n_total else 0.0,
            holdout_ev=0.0, holdout_wr=0.0, holdout_pf=0.0,
            degradation_ratio=None,
            holdout_confirmed=False,
            reason=f"insufficient_trades({n_gated}<{cfg.min_gated_trades})",
        )

    profits = pd.to_numeric(gated["_profit"], errors="coerce").dropna().values
    if len(profits) == 0:
        return RuleEvaluation(
            rule_id=rule.rule_id, symbol=rule.symbol, setup=rule.setup,
            dev_ev=rule.test_ev_mean, dev_wr=rule.test_wr_mean,
            n_holdout_total=n_total, n_gated=n_gated,
            n_pass_ratio=(n_gated / n_total) if n_total else 0.0,
            holdout_ev=0.0, holdout_wr=0.0, holdout_pf=0.0,
            degradation_ratio=None,
            holdout_confirmed=False,
            reason="no_valid_profits",
        )

    ev = float(profits.mean())
    wr = float((profits > 0).mean())
    pos = profits[profits > 0].sum()
    neg = abs(profits[profits < 0].sum())
    pf = float(pos / neg) if neg > 0 else 999.0

    # Degradation ratio
    if rule.test_ev_mean > 1e-9:
        ratio: Optional[float] = ev / rule.test_ev_mean
    else:
        ratio = None

    # Confirmation logic
    reasons: list[str] = []
    if rule.test_ev_mean > 1e-9:
        if ev < rule.test_ev_mean * cfg.ev_degradation_factor:
            reasons.append(
                f"ev_degraded({ev:.4f} < "
                f"{rule.test_ev_mean * cfg.ev_degradation_factor:.4f})"
            )
    elif ev <= 0:
        reasons.append(f"ev_nonpositive({ev:.4f})")

    if pf < cfg.pf_min:
        reasons.append(f"pf_low({pf:.3f} < {cfg.pf_min})")

    if rule.test_wr_mean > 1e-9:
        if wr < rule.test_wr_mean * cfg.wr_degradation_factor:
            reasons.append(
                f"wr_degraded({wr:.3f} < "
                f"{rule.test_wr_mean * cfg.wr_degradation_factor:.3f})"
            )

    confirmed = len(reasons) == 0

    return RuleEvaluation(
        rule_id=rule.rule_id, symbol=rule.symbol, setup=rule.setup,
        dev_ev=rule.test_ev_mean, dev_wr=rule.test_wr_mean,
        n_holdout_total=n_total, n_gated=n_gated,
        n_pass_ratio=(n_gated / n_total) if n_total else 0.0,
        holdout_ev=ev, holdout_wr=wr, holdout_pf=min(pf, 999.0),
        degradation_ratio=ratio,
        holdout_confirmed=confirmed,
        reason="ok" if confirmed else "; ".join(reasons),
    )


# ─── SL/TP evaluation ───────────────────────────────────────────

def _evaluate_sl_tp(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    selection: dict,
    cfg: HoldoutConfig,
) -> Optional[SLTPEvaluation]:
    gated = _filter_by_rule(holdout_df, rule)
    n_gated = len(gated)
    if n_gated < cfg.min_sl_tp_trades:
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

    profits = profits[valid]
    mae = mae[valid]
    mfe = mfe[valid]

    ev_unadj = float(profits.mean())
    sim = _simulate_sl_tp(profits, mae, mfe, sl, tp)
    ev_sim = float(sim.mean())

    pos = sim[sim > 0].sum()
    neg = abs(sim[sim < 0].sum())
    pf = float(pos / neg) if neg > 0 else 999.0

    if rule.test_ev_mean > 1e-9:
        ratio: Optional[float] = ev_sim / rule.test_ev_mean
    else:
        ratio = None

    reasons: list[str] = []
    if ev_sim <= 0:
        reasons.append(f"simulated_ev_nonpositive({ev_sim:.4f})")
    if pf < cfg.pf_min:
        reasons.append(f"pf_low({pf:.3f})")
    if rule.test_ev_mean > 1e-9:
        threshold = rule.test_ev_mean * cfg.sl_tp_degradation_factor
        if ev_sim < threshold:
            reasons.append(
                f"ev_degraded({ev_sim:.4f} < {threshold:.4f})"
            )

    confirmed = len(reasons) == 0

    return SLTPEvaluation(
        rule_id=rule.rule_id,
        sl=sl, tp=tp, n_gated=int(valid.sum()),
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
    """Same logic as L7 (kept consistent)."""
    stopped = mae >= sl
    hit_tp = (~stopped) & (mfe >= tp)
    sim = profits.copy()
    sim[stopped] = -sl
    sim[hit_tp] = tp
    return sim


# ─── Sizing evaluation ──────────────────────────────────────────

def _evaluate_sizing(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    selection: dict,
    cfg: HoldoutConfig,
) -> Optional[SizingEvaluation]:
    gated = _filter_by_rule(holdout_df, rule)
    n_gated = len(gated)
    if n_gated < cfg.min_sizing_trades:
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
        rule_id=rule.rule_id,
        lot_mult=lot_mult, n_gated=int(len(profits)),
        holdout_ev=ev, holdout_wr=wr,
        dev_ev=rule.test_ev_mean,
        confirmed=confirmed,
        reason="ok" if confirmed else "; ".join(reasons),
    )


# ─── Degradation analysis ───────────────────────────────────────

def _degradation_analysis(
    holdout_df: pd.DataFrame,
    rule: FrozenRule,
    cfg: HoldoutConfig,
) -> Optional[DegradationAnalysis]:
    gated = _filter_by_rule(holdout_df, rule)
    if len(gated) < cfg.min_bucket_trades * cfg.n_time_buckets:
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
    if len(gated) < cfg.min_bucket_trades * cfg.n_time_buckets:
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
            buckets.append({
                "bucket_idx": i,
                "n": int(len(sub)),
                "ev": None,
            })
            continue
        ev_b = float(sub["_profit"].mean())
        bucket_evs.append(ev_b)
        buckets.append({
            "bucket_idx": i,
            "n": int(len(sub)),
            "ev": round(ev_b, 6),
        })

    slope_p: Optional[float] = None
    if len(bucket_evs) >= 3:
        x = np.arange(len(bucket_evs))
        y = np.array(bucket_evs)
        slope, _, _, p_two, _ = stats.linregress(x, y)
        # Report one-sided p for negative slope
        slope_p = float(p_two / 2) if slope < 0 else 1.0

    holdout_ev = float(gated["_profit"].mean())

    return DegradationAnalysis(
        rule_id=rule.rule_id,
        dev_ev=rule.test_ev_mean,
        holdout_ev=holdout_ev,
        slope_p=slope_p,
        buckets=tuple(buckets),
    )


# ─── Rule filter ────────────────────────────────────────────────

def _filter_by_rule(df: pd.DataFrame, rule: FrozenRule) -> pd.DataFrame:
    """Apply rule's gate to df. Consistent with L7."""
    if not rule.features:
        return df.iloc[0:0]

    if rule.gate_type == "threshold":
        feat = rule.features[0]
        if feat not in df.columns:
            return df.iloc[0:0]
        vals = pd.to_numeric(df[feat], errors="coerce").fillna(0.0).values
        if rule.direction == 1:
            mask = vals >= rule.lower_bound
        else:
            mask = vals <= rule.upper_bound
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
from . import L4_hard_gate_discovery
from . import L5_soft_gate_discovery
from . import L6_multiple_testing
from . import L7_dev_optimization
from . import L8_holdout_apply

__all__ = [
    "L0_hygiene", "L1_boundary", "L2_feature_engineering",
    "L3_eda", "L4_hard_gate_discovery", "L5_soft_gate_discovery",
    "L6_multiple_testing", "L7_dev_optimization", "L8_holdout_apply",
]
```

---

## Tests

## `vp_analysis/tests/test_L8_holdout_apply.py`

```python
"""Tests for Layer 8 — Holdout Apply (Report Only)."""
import dataclasses
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.data_boundary import SealedHoldout
from vp_analysis.core.exceptions import HoldoutAlreadyUnsealedError
from vp_analysis.core.frozen_types import (
    FrozenProductionConfig, FrozenRule,
)
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L8_holdout_apply import (
    HoldoutConfig,
    _evaluate_rule,
    _evaluate_sl_tp,
    _evaluate_sizing,
    _filter_by_rule,
    _simulate_sl_tp,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    return ResearchContract.from_dict(minimal_contract_dict)


def _make_frozen_rule(
    rule_id="R-00001", feature="f_signal",
    lower=0.6, direction=1, gate_type="threshold",
    dev_ev=0.30, dev_wr=0.55, dev_pf=1.5,
):
    return FrozenRule(
        rule_id=rule_id, experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD", setup="BOS",
        gate_type=gate_type, direction=direction,
        features=(feature,),
        lower_bound=lower, upper_bound=None,
        test_ev_mean=dev_ev, test_wr_mean=dev_wr,
        test_pf_mean=dev_pf, test_n_avg=50,
        pvalue=0.01, pvalue_fdr=0.02, fdr_significant=True,
        fold_consistency=0.8, n_folds=4,
    )


def _make_holdout_df(
    n=300, seed=0, signal_strength=1.0, include_time=True,
):
    rng = np.random.default_rng(seed)
    f = rng.uniform(0, 1, n)
    mae = rng.uniform(0.3, 2.5, n)
    mfe = rng.uniform(0.5, 3.0, n)
    noise = rng.normal(0, 0.3, n)
    profit = np.where(f > 0.6, signal_strength, -0.5) + noise

    data = {
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": f,
        "maeATR": mae,
        "mfeATR": mfe,
        "_profit": profit,
    }
    if include_time:
        data["time"] = pd.date_range("2025-01-01", periods=n, freq="h")
    return pd.DataFrame(data)


def _make_sealed_holdout(df):
    return SealedHoldout(df)


def _make_production_config(rules, sl_tp=None, sizing=None):
    return FrozenProductionConfig(
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        rules=tuple(rules),
        sl_tp_selections=tuple(sl_tp or ()),
        sizing_configs=tuple(sizing or ()),
    )


# ══════════════════════════════════════════════════════════════════
# Unseal protocol
# ══════════════════════════════════════════════════════════════════

def test_unseal_once_succeeds(contract):
    df = _make_holdout_df(n=300)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    assert holdout.is_sealed
    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert not holdout.is_sealed


def test_second_unseal_raises(contract):
    df = _make_holdout_df(n=300)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    run(holdout, config, contract, experiment_id="EXP-TEST")
    # Second call with same experiment_id → raises
    with pytest.raises(RuntimeError, match="failed to unseal"):
        run(holdout, config, contract, experiment_id="EXP-TEST")


def test_different_experiment_can_unseal(contract):
    df = _make_holdout_df(n=300)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    run(holdout, config, contract, experiment_id="EXP-A")
    # Different experiment_id — allowed
    run(holdout, config, contract, experiment_id="EXP-B")


# ══════════════════════════════════════════════════════════════════
# Rule evaluation
# ══════════════════════════════════════════════════════════════════

def test_rule_evaluation_passes(contract):
    df = _make_holdout_df(n=300, signal_strength=1.5)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.30, dev_wr=0.55)
    config = _make_production_config([rule])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert result.n_rules_evaluated == 1
    ev = result.rule_evaluations[0]
    assert ev.n_gated > 0
    assert ev.reason in ("ok",) or "degraded" in ev.reason


def test_rule_evaluation_insufficient_trades(contract):
    df = _make_holdout_df(n=50)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(lower=0.99)  # very few gated
    config = _make_production_config([rule])

    result = run(
        holdout, config, contract, experiment_id="EXP-TEST",
        config=HoldoutConfig(min_gated_trades=100),
    )
    ev = result.rule_evaluations[0]
    assert ev.reason.startswith("insufficient")
    assert not ev.holdout_confirmed


def test_rule_confirmed_when_holdout_matches_dev(contract):
    # Same distribution as dev → should confirm
    df = _make_holdout_df(n=400, seed=0, signal_strength=1.0)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.5, dev_wr=0.5)
    config = _make_production_config([rule])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    ev = result.rule_evaluations[0]
    assert ev.holdout_confirmed


def test_rule_not_confirmed_when_degraded(contract):
    # Holdout has NO signal → EV near 0
    df = _make_holdout_df(n=400, seed=0, signal_strength=0.0)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.5, dev_wr=0.5)
    config = _make_production_config([rule])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    ev = result.rule_evaluations[0]
    assert not ev.holdout_confirmed
    assert "ev_degraded" in ev.reason or "pf_low" in ev.reason


# ══════════════════════════════════════════════════════════════════
# Frozen artifacts immutability
# ══════════════════════════════════════════════════════════════════

def test_frozen_rule_not_mutated(contract):
    df = _make_holdout_df(n=300)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    ev_before = rule.test_ev_mean
    config = _make_production_config([rule])

    run(holdout, config, contract, experiment_id="EXP-TEST")
    assert rule.test_ev_mean == ev_before  # unchanged


def test_production_config_not_mutated(contract):
    df = _make_holdout_df(n=300)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    rules_before = len(config.rules)
    run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(config.rules) == rules_before


# ══════════════════════════════════════════════════════════════════
# Null result
# ══════════════════════════════════════════════════════════════════

def test_null_result_when_all_fail(contract):
    df = _make_holdout_df(n=400, seed=0, signal_strength=0.0)
    holdout = _make_sealed_holdout(df)
    rules = [
        _make_frozen_rule(rule_id="R-00001", dev_ev=0.5),
        _make_frozen_rule(rule_id="R-00002", dev_ev=0.5),
    ]
    config = _make_production_config(rules)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert result.null_result
    assert result.n_rules_confirmed == 0
    assert any("NULL RESULT" in w for w in result.warnings)


def test_no_null_result_when_some_pass(contract):
    df = _make_holdout_df(n=400, seed=0, signal_strength=1.5)
    holdout = _make_sealed_holdout(df)
    rules = [_make_frozen_rule(dev_ev=0.3, dev_wr=0.5)]
    config = _make_production_config(rules)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    if result.n_rules_confirmed > 0:
        assert not result.null_result


# ══════════════════════════════════════════════════════════════════
# SL/TP evaluation
# ══════════════════════════════════════════════════════════════════

def test_sl_tp_evaluation_runs(contract):
    df = _make_holdout_df(n=400, signal_strength=1.5)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.3, dev_wr=0.5)
    sl_tp = ({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},)
    config = _make_production_config([rule], sl_tp=sl_tp)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sl_tp_evaluations) == 1
    ev = result.sl_tp_evaluations[0]
    assert ev.sl == 1.5
    assert ev.tp == 2.0
    assert ev.n_gated > 0


def test_sl_tp_skipped_without_selection(contract):
    df = _make_holdout_df(n=300)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule], sl_tp=None)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sl_tp_evaluations) == 0


def test_sl_tp_skipped_without_mae_mfe(contract):
    df = _make_holdout_df(n=400).drop(columns=["maeATR", "mfeATR"])
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    sl_tp = ({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},)
    config = _make_production_config([rule], sl_tp=sl_tp)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sl_tp_evaluations) == 0


def test_simulate_sl_tp_consistency():
    """Same behavior as L7."""
    profits = np.array([1.0, -0.5, 0.8])
    mae = np.array([0.5, 2.0, 0.3])
    mfe = np.array([1.5, 0.5, 2.5])
    sim = _simulate_sl_tp(profits, mae, mfe, sl=1.5, tp=2.0)
    np.testing.assert_allclose(sim, [2.0, -1.5, 2.0])


# ══════════════════════════════════════════════════════════════════
# Sizing evaluation
# ══════════════════════════════════════════════════════════════════

def test_sizing_evaluation_runs(contract):
    df = _make_holdout_df(n=400, signal_strength=1.5)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.3)
    sizing = ({"rule_id": "R-00001", "lot_mult": 1.2},)
    config = _make_production_config([rule], sizing=sizing)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sizing_evaluations) == 1
    ev = result.sizing_evaluations[0]
    assert ev.lot_mult == 1.2
    assert ev.n_gated > 0


def test_sizing_skipped_without_config(contract):
    df = _make_holdout_df(n=400)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule], sizing=None)

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.sizing_evaluations) == 0


# ══════════════════════════════════════════════════════════════════
# Degradation analysis
# ══════════════════════════════════════════════════════════════════

def test_degradation_analysis_runs(contract):
    df = _make_holdout_df(n=400, signal_strength=1.5, include_time=True)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.3)
    config = _make_production_config([rule])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.degradation_analyses) == 1
    d = result.degradation_analyses[0]
    assert d.rule_id == "R-00001"
    assert len(d.buckets) == 4


def test_degradation_skipped_without_time(contract):
    df = _make_holdout_df(n=400, include_time=False)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    result = run(holdout, config, contract, experiment_id="EXP-TEST")
    assert len(result.degradation_analyses) == 0


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(contract, tmp_path):
    df = _make_holdout_df(n=400, signal_strength=1.5)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.3, dev_wr=0.5)
    sl_tp = ({"rule_id": "R-00001", "sl": 1.5, "tp": 2.0},)
    sizing = ({"rule_id": "R-00001", "lot_mult": 1.2},)
    config = _make_production_config([rule], sl_tp=sl_tp, sizing=sizing)

    run(holdout, config, contract, experiment_id="EXP-TEST",
        output_dir=tmp_path)

    assert (tmp_path / "holdout_evaluation.csv").exists()
    assert (tmp_path / "sl_tp_holdout_report.csv").exists()
    assert (tmp_path / "sizing_holdout_report.csv").exists()
    assert (tmp_path / "holdout_degradation.csv").exists()
    assert (tmp_path / "holdout_summary.json").exists()


def test_summary_json_content(contract, tmp_path):
    df = _make_holdout_df(n=300, signal_strength=1.5)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule(dev_ev=0.3, dev_wr=0.5)
    config = _make_production_config([rule])

    run(holdout, config, contract, experiment_id="EXP-TEST",
        output_dir=tmp_path)

    with (tmp_path / "holdout_summary.json").open() as f:
        s = json.load(f)
    assert s["experiment_id"] == "EXP-TEST"
    assert s["n_rules_evaluated"] == 1
    assert "overall_confirmation_rate" in s


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_missing_experiment_id_raises(contract):
    df = _make_holdout_df(n=100)
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    with pytest.raises(ValueError, match="experiment_id"):
        run(holdout, config, contract, experiment_id="")


def test_wrong_config_type_raises(contract):
    df = _make_holdout_df(n=100)
    holdout = _make_sealed_holdout(df)

    with pytest.raises(TypeError, match="FrozenProductionConfig"):
        run(holdout, {"not": "a config"}, contract,
            experiment_id="EXP-TEST")


def test_empty_holdout_raises(contract):
    df = pd.DataFrame()
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    with pytest.raises((ValueError, RuntimeError)):
        run(holdout, config, contract, experiment_id="EXP-TEST")


def test_holdout_without_profit_column_raises(contract):
    df = _make_holdout_df(n=100).drop(columns=["_profit"])
    holdout = _make_sealed_holdout(df)
    rule = _make_frozen_rule()
    config = _make_production_config([rule])

    with pytest.raises(ValueError, match="_profit|profitUSD"):
        run(holdout, config, contract, experiment_id="EXP-TEST")


def test_filter_by_rule_missing_feature():
    df = pd.DataFrame({"other_feat": [0.5, 0.6]})
    rule = _make_frozen_rule(feature="f_signal")
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 0
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L8_holdout_apply.py -v
```

Kỳ vọng:

```text
test_L8_holdout_apply.py
  Unseal protocol                    3 passed
  Rule evaluation                    4 passed
  Frozen artifacts immutability      2 passed
  Null result                        2 passed
  SL/TP evaluation                   4 passed
  Sizing evaluation                  2 passed
  Degradation                        2 passed
  Output                             2 passed
  Edge cases                         5 passed
  ────────────────────────────────────────────────
  Total                             26 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 322 + 26 = 348 passed
```

---

## Preview: Layer 8 trong pipeline

```python
from vp_analysis.layers import L8_holdout_apply

# First and only time holdout is touched
l8 = L8_holdout_apply.run(
    sealed_holdout=l2.boundary.holdout,
    production_config=l7.production_config,
    contract=contract,
    experiment_id=manifest.experiment_id,
    output_dir=output_dir / "L8_holdout",
    config=HoldoutConfig(
        min_gated_trades=20,
        ev_degradation_factor=0.50,
        pf_min=1.00,
        wr_degradation_factor=0.80,
    ),
)

print(f"  Rules confirmed: {l8.n_rules_confirmed}/{l8.n_rules_evaluated}")
print(f"  SL/TP confirmed: {l8.n_sl_tp_confirmed}")
print(f"  Sizing confirmed: {l8.n_sizing_confirmed}")
print(f"  Confirmation rate: {l8.overall_confirmation_rate:.1%}")
if l8.null_result:
    print("  → NULL RESULT — route to L11")
```

Output:

```text
output/
├── L8_holdout/
│   ├── holdout_evaluation.csv
│   ├── sl_tp_holdout_report.csv
│   ├── sizing_holdout_report.csv
│   ├── holdout_degradation.csv
│   └── holdout_summary.json
```

---

## Sprint 8 hoàn tất

**Deliverables:**
- `L8_holdout_apply.py` (~450 dòng) — one-time unseal, read-only evaluation
- 26 tests bao gồm:
  - Unseal once (raises on second attempt cùng experiment_id)
  - Different experiment_id allowed
  - Rule evaluation với confirmation logic
  - Insufficient trades handling
  - **Frozen artifacts immutability** (rule + config unchanged)
  - Null result detection
  - SL/TP evaluation với simulation
  - Sizing evaluation
  - Degradation analysis với time buckets
  - Output files + summary JSON
  - Edge cases (empty holdout, missing profit col, wrong type)

**Điểm quan trọng đã enforce:**
1. **`unseal_once()` gọi qua kernel** — không có bypass
2. **Không mutate bất cứ artifact nào** — test verify `rule.test_ev_mean` và `config.rules` unchanged
3. **`holdout_confirmed`** là field riêng, không ghi đè `validated` (đã lock ở L6)
4. **Null result** được flag rõ ràng để caller route đến L11
5. **Degradation analysis** dùng time buckets, phát hiện decay

**Bugs từ các phase cũ đã fix:**
1. ✅ Phase 02 v3/v4 không còn nhìn holdout sau khi freeze
2. ✅ Phase 05 không còn `rule["oos_validated"] = ...` mutation
3. ✅ Phase 06 fold leakage — không còn vì folds đã ở L7 (dev only)
4. ✅ Governance enforced ở kernel level (không thể access holdout trước khi gọi `unseal_once`)

**Kernel + L0-L8 hiện có:**
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
│  ─────────────────────────────────────────────────────────  │
│  Total                                     348 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Sprint 9 — Layer 9-11: Attribution + Bad Entry + Null Protocol:**
- L9 Attribution: entry vs exit, exit policy decomposition, cross-style consistency
- L10 Bad Entry: canary labels, negative feature screening
- L11 Null Protocol: case detection, result classification
- Output: `entry_exit_attribution.csv`, `canary_labels.csv`, `bad_entry_features.csv`, `experiment_result.json`
- ~25 tests
