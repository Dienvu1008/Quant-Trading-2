"""Layer 7 — Development Optimization (SL/TP + Sizing).

Runs AFTER L6 freeze, on DEVELOPMENT data only.

Two independent optimizations:

  1. SL/TP optimization (per rule):
     - Filter dev trades by the rule's gate.
     - Enumerate the pre-registered (SL, TP) grid from the contract.
     - Simulate each combo using MAE/MFE of ALL gated trades (winners
       AND losers) — not just winners. Avoids bias from winner-only dist.
     - Select the combo maximizing the utility function.
     - [Fix #6] Tiebreaker: sort by (-utility, -sl_atr, -tp_atr).

  2. Sizing calibration (per rule):
     - Filter dev trades by the rule's gate.
     - Compute Kelly fraction from all gated trades.
     - Fold consistency check on dev (walk-forward).
     - One-sided t-test on dev profits.
     - Map Kelly fraction to a lot multiplier in [min_mult, max_mult].

Both outputs feed FrozenProductionConfig. No FDR correction applied —
neither is a hypothesis test, both are optimization.

The holdout is NOT touched. All values come from dev.
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
from ..core.stats_helpers import one_sided_t_test


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class OptimizationConfig:
    # SL/TP
    use_sl_tp_optimization: bool = True
    require_mae_mfe: bool = True        # if MAE/MFE missing → skip
    utility_function: str = "expectancy"  # "expectancy" | "sharpe_proxy"

    # Sizing
    use_sizing: bool = True
    kelly_fraction: float = 0.25
    min_mult: float = 0.50
    max_mult: float = 1.50
    neutral_mult: float = 1.00

    # Sizing validation
    min_dev_trades: int = 30
    n_folds: int = 4
    min_fold_agree: float = 0.70
    max_pval: float = 0.10

    # Randomness (none here; kept for future use)
    seed: int = 42


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class SLTPSolution:
    rule_id: str
    sl: float
    tp: float
    simulated_ev: float
    n_gated_trades: int
    utility_name: str
    evaluated_grid: tuple  # of dicts {sl, tp, utility}

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "sl": round(self.sl, 6),
            "tp": round(self.tp, 6),
            "simulated_ev": round(self.simulated_ev, 6),
            "n_gated_trades": self.n_gated_trades,
            "utility_name": self.utility_name,
        }


@dataclass(frozen=True)
class SizingSolution:
    rule_id: str
    lot_mult: float
    n_gated_trades: int
    kelly_raw: float
    kelly_frac: float
    fold_agree: float
    pval: float
    validated: bool
    reason: str

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "lot_mult": round(self.lot_mult, 6),
            "n_gated_trades": self.n_gated_trades,
            "kelly_raw": round(self.kelly_raw, 6),
            "kelly_frac": round(self.kelly_frac, 6),
            "fold_agree": round(self.fold_agree, 4),
            "pval": round(self.pval, 6),
            "validated": self.validated,
            "reason": self.reason,
        }


@dataclass(frozen=True)
class LayerSevenResult:
    sl_tp_solutions: tuple
    sizing_solutions: tuple
    production_config: FrozenProductionConfig
    n_rules: int
    n_sl_tp_optimized: int
    n_sizing_validated: int
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_rules": self.n_rules,
            "n_sl_tp_optimized": self.n_sl_tp_optimized,
            "n_sizing_validated": self.n_sizing_validated,
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_df: pd.DataFrame,
    frozen_rules: list,
    contract,
    experiment_id: str,
    output_dir: Optional[Path] = None,
    config: Optional[OptimizationConfig] = None,
) -> LayerSevenResult:
    """Execute Layer 7 on dev data only.

    Preconditions:
      - frozen_rules from L6 (list of FrozenRule)
      - dev_df has '_profit' column
      - holdout is NOT passed — all computation on dev
    """
    cfg = config or OptimizationConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if dev_df is None or len(dev_df) == 0:
        raise ValueError("L7: dev_df is empty")
    if "_profit" not in dev_df.columns:
        raise ValueError("L7: dev_df must have '_profit' column")
    if not experiment_id:
        raise ValueError("L7: experiment_id is required")
    if not frozen_rules:
        raise ValueError("L7: no frozen rules provided")

    warnings: list[str] = []
    sl_tp_solutions: list[SLTPSolution] = []
    sizing_solutions: list[SizingSolution] = []

    for rule in frozen_rules:
        gated = _filter_by_rule(dev_df, rule)

        if len(gated) < cfg.min_dev_trades:
            warnings.append(
                f"Rule {rule.rule_id}: only {len(gated)} gated trades "
                f"(< {cfg.min_dev_trades}), skipped SL/TP & sizing"
            )
            continue

        # SL/TP optimization
        if cfg.use_sl_tp_optimization:
            sl_tp = _optimize_sl_tp(rule, gated, contract, cfg)
            if sl_tp is not None:
                sl_tp_solutions.append(sl_tp)
            else:
                warnings.append(
                    f"Rule {rule.rule_id}: SL/TP optimization skipped "
                    f"(MAE/MFE missing or insufficient data)"
                )

        # Sizing calibration
        if cfg.use_sizing:
            sizing = _calibrate_sizing(rule, gated, cfg)
            sizing_solutions.append(sizing)

    # Build FrozenProductionConfig
    sl_tp_selections = tuple(
        {"rule_id": s.rule_id, "sl": s.sl, "tp": s.tp}
        for s in sl_tp_solutions
    )
    sizing_configs = tuple(
        {"rule_id": s.rule_id, "lot_mult": s.lot_mult}
        for s in sizing_solutions
    )

    production_config = FrozenProductionConfig(
        experiment_id=experiment_id,
        research_contract_hash=contract.contract_hash,
        rules=tuple(frozen_rules),
        sl_tp_selections=sl_tp_selections,
        sizing_configs=sizing_configs,
    )

    result = LayerSevenResult(
        sl_tp_solutions=tuple(sl_tp_solutions),
        sizing_solutions=tuple(sizing_solutions),
        production_config=production_config,
        n_rules=len(frozen_rules),
        n_sl_tp_optimized=len(sl_tp_solutions),
        n_sizing_validated=sum(1 for s in sizing_solutions if s.validated),
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Rule gate filter ─────────────────────────────────────────────

def _filter_by_rule(df: pd.DataFrame, rule: FrozenRule) -> pd.DataFrame:
    """Apply rule's gate condition to dev_df. Returns filtered subset."""
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
        feats = [f for f in rule.features if f in df.columns]
        if not feats:
            return df.iloc[0:0]
        X = df[feats].fillna(0.0).values.astype(float)
        w = np.array(rule.model_weights, dtype=float)
        scores = X @ w + float(rule.model_bias)
        mask = scores >= float(rule.score_threshold)
        return df[mask]

    return df.iloc[0:0]


# ─── SL/TP optimization ──────────────────────────────────────────

def _optimize_sl_tp(
    rule: FrozenRule,
    gated: pd.DataFrame,
    contract,
    cfg: OptimizationConfig,
) -> Optional[SLTPSolution]:
    """Enumerate (SL, TP) grid on ALL gated trades using MAE/MFE.

    [Fix #6] Tiebreaker: sort by (-utility, -sl_atr, -tp_atr) to prefer
    larger SL/TP when utility is equal (avoids tiny noisy thresholds).
    """
    if cfg.require_mae_mfe:
        if "maeATR" not in gated.columns or "mfeATR" not in gated.columns:
            return None

    profits = pd.to_numeric(gated["_profit"], errors="coerce").values
    valid = ~np.isnan(profits)

    mae = (
        pd.to_numeric(gated["maeATR"], errors="coerce").values
        if "maeATR" in gated.columns
        else np.full(len(gated), np.nan)
    )
    mfe = (
        pd.to_numeric(gated["mfeATR"], errors="coerce").values
        if "mfeATR" in gated.columns
        else np.full(len(gated), np.nan)
    )

    if cfg.require_mae_mfe:
        valid &= ~np.isnan(mae) & ~np.isnan(mfe)

    if valid.sum() < cfg.min_dev_trades:
        return None

    profits = profits[valid]
    mae = mae[valid]
    mfe = mfe[valid]

    sl_candidates = contract.optimization_budget.sl_candidates
    tp_candidates = contract.optimization_budget.tp_candidates
    if not sl_candidates or not tp_candidates:
        return None

    utility_name = (
        cfg.utility_function
        if cfg.utility_function in ("expectancy", "sharpe_proxy")
        else contract.optimization_budget.utility_function
    )

    evaluated: list[dict] = []
    for sl in sl_candidates:
        for tp in tp_candidates:
            sim = _simulate_sl_tp(profits, mae, mfe, float(sl), float(tp))
            util = _utility(sim, utility_name)
            evaluated.append({
                "sl": float(sl), "tp": float(tp), "utility": float(util),
            })

    if not evaluated:
        return None

    # [Fix #6] Tiebreaker: (-utility, -sl, -tp) → prefer larger SL/TP on ties
    best = max(evaluated, key=lambda e: (e["utility"], e["sl"], e["tp"]))

    return SLTPSolution(
        rule_id=rule.rule_id,
        sl=best["sl"],
        tp=best["tp"],
        simulated_ev=best["utility"],
        n_gated_trades=int(valid.sum()),
        utility_name=utility_name,
        evaluated_grid=tuple(evaluated),
    )


def _simulate_sl_tp(
    profits: np.ndarray,
    mae: np.ndarray,
    mfe: np.ndarray,
    sl: float,
    tp: float,
) -> np.ndarray:
    """Simulate profit under new SL/TP using MAE/MFE on ALL trades.

    Conservative ordering:
      1. If MAE >= sl → stopped out: profit = -sl
      2. Elif MFE >= tp → TP hit: profit = +tp
      3. Else → original profit (timeout / trail exit)
    """
    stopped = mae >= sl
    hit_tp = (~stopped) & (mfe >= tp)
    sim = profits.copy()
    sim[stopped] = -sl
    sim[hit_tp] = tp
    return sim


def _utility(simulated: np.ndarray, name: str) -> float:
    if name == "expectancy":
        return float(np.mean(simulated))
    if name == "sharpe_proxy":
        sd = float(np.std(simulated, ddof=1))
        return float(np.mean(simulated) / sd) if sd > 1e-12 else 0.0
    return float(np.mean(simulated))


# ─── Sizing calibration ──────────────────────────────────────────

def _calibrate_sizing(
    rule: FrozenRule,
    gated: pd.DataFrame,
    cfg: OptimizationConfig,
) -> SizingSolution:
    """Fractional Kelly on dev-gated trades, with fold consistency + t-test."""
    profits = pd.to_numeric(gated["_profit"], errors="coerce").dropna().values
    n = len(profits)

    if n < cfg.min_dev_trades:
        return _neutral_sizing(rule.rule_id, n, "insufficient_trades")

    wins = profits[profits > 0]
    losses = profits[profits < 0]

    if len(wins) == 0 or len(losses) == 0:
        return _neutral_sizing(rule.rule_id, n, "no_wins_or_losses")

    avg_win = float(np.mean(wins))
    avg_loss = float(abs(np.mean(losses)))
    if avg_loss <= 1e-12:
        return _neutral_sizing(rule.rule_id, n, "degenerate_loss")

    wr = float((profits > 0).mean())
    b = avg_win / avg_loss
    kelly_raw = wr - (1.0 - wr) / b
    kelly_frac = kelly_raw * cfg.kelly_fraction

    # Fold consistency on dev (walk-forward)
    fold_agree = _fold_sign_agreement(profits, kelly_raw, cfg)

    # One-sided t-test: H0: mean <= 0
    _, pval = one_sided_t_test(list(profits), null_mean=0.0)

    # Validation
    if fold_agree < cfg.min_fold_agree:
        reason = f"fold_unstable({fold_agree:.2f})"
        validated = False
    elif pval > cfg.max_pval:
        reason = f"not_significant(p={pval:.4f})"
        validated = False
    else:
        reason = "ok"
        validated = True

    mult = _kelly_to_mult(kelly_frac, cfg) if validated else cfg.neutral_mult

    return SizingSolution(
        rule_id=rule.rule_id,
        lot_mult=float(mult),
        n_gated_trades=int(n),
        kelly_raw=float(kelly_raw),
        kelly_frac=float(kelly_frac),
        fold_agree=float(fold_agree),
        pval=float(pval),
        validated=validated,
        reason=reason,
    )


def _neutral_sizing(rule_id: str, n: int, reason: str) -> SizingSolution:
    return SizingSolution(
        rule_id=rule_id, lot_mult=1.0,
        n_gated_trades=int(n), kelly_raw=0.0, kelly_frac=0.0,
        fold_agree=0.0, pval=1.0, validated=False, reason=reason,
    )


def _fold_sign_agreement(
    profits: np.ndarray,
    kelly_reference: float,
    cfg: OptimizationConfig,
) -> float:
    """Fraction of dev folds whose Kelly sign matches reference Kelly."""
    n = len(profits)
    if n < cfg.n_folds * 5:
        return 0.0

    fold_size = n // cfg.n_folds
    if fold_size < 5:
        return 0.0

    ref_sign = np.sign(kelly_reference)
    if ref_sign == 0:
        return 0.0

    agrees = 0
    total = 0
    for i in range(cfg.n_folds):
        start = i * fold_size
        end = (i + 1) * fold_size if i < cfg.n_folds - 1 else n
        fold = profits[start:end]
        wins = fold[fold > 0]
        losses = fold[fold < 0]
        if len(wins) == 0 or len(losses) == 0:
            continue
        avg_w = float(np.mean(wins))
        avg_l = abs(float(np.mean(losses)))
        if avg_l <= 1e-12:
            continue
        b = avg_w / avg_l
        wr_fold = float((fold > 0).mean())
        k = wr_fold - (1.0 - wr_fold) / b
        if np.sign(k) == ref_sign:
            agrees += 1
        total += 1

    return (agrees / total) if total > 0 else 0.0


def _kelly_to_mult(kelly_frac: float, cfg: OptimizationConfig) -> float:
    """Map Kelly fraction to lot multiplier in [min_mult, max_mult].

    kelly_frac = 0      → neutral_mult (1.0)
    kelly_frac = +K     → max_mult
    kelly_frac = -K     → min_mult
    where K = cfg.kelly_fraction.
    """
    K = cfg.kelly_fraction
    if K <= 0:
        return cfg.neutral_mult

    if kelly_frac >= 0:
        norm = min(1.0, kelly_frac / K)
        mult = cfg.neutral_mult + norm * (cfg.max_mult - cfg.neutral_mult)
    else:
        norm = min(1.0, abs(kelly_frac) / K)
        mult = cfg.neutral_mult - norm * (cfg.neutral_mult - cfg.min_mult)

    return float(np.clip(mult, cfg.min_mult, cfg.max_mult))


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerSevenResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    if result.sl_tp_solutions:
        pd.DataFrame(
            [s.to_dict() for s in result.sl_tp_solutions]
        ).to_csv(output_dir / "sl_tp_optimization.csv", index=False)

    if result.sizing_solutions:
        pd.DataFrame(
            [s.to_dict() for s in result.sizing_solutions]
        ).to_csv(output_dir / "sizing_configs.csv", index=False)

    with (output_dir / "production_config.json").open("w", encoding="utf-8") as fh:
        json.dump(result.production_config.to_dict(), fh, indent=2, default=str)

    with (output_dir / "optimization_summary.json").open("w", encoding="utf-8") as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)
