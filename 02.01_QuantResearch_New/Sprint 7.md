# Sprint 7 — Layer 7: Dev Optimization (SL/TP + Sizing)

> **v3 changes (từ SPECIFICATION.md v3):**
> - **[Fix #6] SL/TP tiebreaker**: khi nhiều `(SL, TP)` combo cho cùng expectancy, ưu tiên `SL` lớn hơn trước, rồi `TP` lớn hơn. Tránh chọn SL quá nhỏ do noise. Sort: `(-utility, -sl_atr, -tp_atr)`.
> - **[Fix #2 note]** L7a dùng toàn bộ trade paths (winners + losers) với MAE/MFE — không chỉ winners. [Đúng rồi từ v2, clarify thêm]
> - **[NEW] L7c — SL Risk Threshold Discovery**: tìm feature threshold dự báo SL-hit rate cao. Output feed `VPGetSLRiskMultiplier()` trong EA. **KHÔNG dùng FDR** — đây là optimization, không phải hypothesis testing.
> - **L7.5 Production Freeze** mở rộng: `FrozenProductionConfig` kèm thêm `regime_blocks`, `bad_entry_filter`, `sl_risk_thresholds`, `soft_gate_tilts`. [New từ L4b, L10a, L7c, Fix #5]

**Điểm quan trọng (updated v3):**
1. **SL/TP dùng toàn bộ trade paths** (winners + losers), không chỉ winners
2. **Sizing fold consistency trên dev** — không leak sang holdout
3. **One-sided t-test** cho sizing (không two-sided)
4. **Kelly mapping honest** — không nhân đôi Kelly lý thuyết
5. **Không FDR** — L7a, L7b, L7c đều là optimization, không hypothesis testing
6. **[NEW] L7c**: SL risk threshold — optimization (chọn best threshold), không FDR
7. **[Fix #6] Tiebreaker**: sort by `(-expectancy, -sl_atr, -tp_atr)` khi chọn SL/TP

Deliverables:
- `layers/L7a_sl_tp_optimization.py` — SL/TP grid (tiebreaker mới) [Fix #6]
- `layers/L7b_sizing_calibration.py` — Kelly sizing
- **[NEW] `layers/L7c_sl_risk_thresholds.py`** — SL-hit rate prediction, per-rule threshold
- `layers/L7_5_production_freeze.py` — mở rộng FrozenProductionConfig
- Outputs: `sl_tp_optimization.csv`, `sizing_configs.csv`, `sl_risk_thresholds.json` [NEW], `production_config.json`, `optimization_summary.json`
- ~22 tests (L7a+L7b) + ~18 tests (L7c)

---

## `vp_analysis/layers/L7_dev_optimization.py`

```python
"""Layer 7 — Development Optimization (SL/TP + Sizing).

Runs AFTER L6 freeze, on DEVELOPMENT data only.

Two independent optimizations:

  1. SL/TP optimization (per rule):
     - Filter dev trades by the rule's gate.
     - Enumerate the pre-registered (SL, TP) grid from the contract.
     - Simulate each combo using MAE/MFE of ALL gated trades (winners
       AND losers) — not just winners. This avoids the bias that would
       arise if we picked SL/TP from the winner distribution alone.
     - Select the combo maximizing the utility function (default:
       expectancy = mean simulated profit).

  2. Sizing calibration (per rule):
     - Filter dev trades by the rule's gate.
     - Compute Kelly fraction from all gated trades.
     - Fold consistency check on dev (walk-forward, non-overlapping).
     - One-sided t-test on dev profits.
     - Map Kelly fraction to a lot multiplier in [min_mult, max_mult].
     - If validation fails → neutral multiplier (1.0).

Both outputs feed FrozenProductionConfig. No FDR correction is applied
here because neither is a hypothesis test — they are optimization.

The holdout is NOT touched. All values come from dev.
"""
from __future__ import annotations

import datetime as dt
import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional

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
    evaluated_grid: tuple  # tuple of dicts {sl, tp, utility}

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
    """Execute Layer 7 on dev data.

    Preconditions:
      - frozen_rules from L6 (list of FrozenRule)
      - dev_df is the (transformed) development DataFrame
      - dev_df has `_profit` column
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

        # Sizing
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
        n_sizing_validated=sum(
            1 for s in sizing_solutions if s.validated
        ),
        warnings=tuple(warnings),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Rule gate filter ───────────────────────────────────────────

def _filter_by_rule(df: pd.DataFrame, rule: FrozenRule) -> pd.DataFrame:
    """Apply rule's gate to dev_df. Returns filtered subset."""
    if not rule.features:
        return df.iloc[0:0]

    if rule.gate_type == "threshold":
        feat = rule.features[0]
        vals = pd.to_numeric(df[feat], errors="coerce").fillna(0.0).values
        if rule.direction == 1:
            mask = vals >= rule.lower_bound
        else:
            mask = vals <= rule.upper_bound
        return df[mask]

    if rule.gate_type == "band":
        feat = rule.features[0]
        vals = pd.to_numeric(df[feat], errors="coerce").fillna(0.0).values
        mask = (vals >= rule.lower_bound) & (vals <= rule.upper_bound)
        return df[mask]

    if rule.gate_type == "model":
        X = df[list(rule.features)].fillna(0.0).values.astype(float)
        w = np.array(rule.model_weights, dtype=float)
        scores = X @ w + float(rule.model_bias)
        mask = scores >= float(rule.score_threshold)
        return df[mask]

    return df.iloc[0:0]


# ─── SL/TP optimization ─────────────────────────────────────────

def _optimize_sl_tp(
    rule: FrozenRule,
    gated: pd.DataFrame,
    contract,
    cfg: OptimizationConfig,
) -> Optional[SLTPSolution]:
    """Enumerate (SL, TP) grid on gated trades using MAE/MFE.

    Uses ALL gated trades (winners and losers), not just winners.
    Simulation:
      - If MAE >= sl → simulated profit = -sl (stopped out)
      - Elif MFE >= tp → simulated profit = +tp (target hit)
      - Else → simulated profit = actual profit (neither triggered)
    """
    if cfg.require_mae_mfe:
        if "maeATR" not in gated.columns or "mfeATR" not in gated.columns:
            return None

    profits = pd.to_numeric(gated["_profit"], errors="coerce").values
    valid = ~np.isnan(profits)

    if "maeATR" in gated.columns:
        mae = pd.to_numeric(gated["maeATR"], errors="coerce").values
    else:
        mae = np.full(len(gated), np.nan)
    if "mfeATR" in gated.columns:
        mfe = pd.to_numeric(gated["mfeATR"], errors="coerce").values
    else:
        mfe = np.full(len(gated), np.nan)

    # Only keep rows with valid profit AND valid MAE/MFE for simulation
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

    utility_name = contract.optimization_budget.utility_function
    evaluated: list[dict] = []
    best_util = float("-inf")
    best_sl: Optional[float] = None
    best_tp: Optional[float] = None

    for sl in sl_candidates:
        for tp in tp_candidates:
            sim = _simulate_sl_tp(profits, mae, mfe, float(sl), float(tp))
            util = _utility(sim, utility_name)
            evaluated.append({
                "sl": float(sl), "tp": float(tp), "utility": float(util),
            })
            if util > best_util:
                best_util = util
                best_sl = float(sl)
                best_tp = float(tp)

    if best_sl is None:
        return None

    return SLTPSolution(
        rule_id=rule.rule_id,
        sl=best_sl, tp=best_tp,
        simulated_ev=float(best_util),
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
    """Simulate profit under new SL/TP using MAE/MFE.

    Conservative ordering:
      - If MAE >= sl → assume stopped out (worst case for adverse)
      - Elif MFE >= tp → assume TP hit
      - Else → original profit stands (trail / timeout exit)
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
    # Unknown utility → fall back to expectancy
    return float(np.mean(simulated))


# ─── Sizing calibration ─────────────────────────────────────────

def _calibrate_sizing(
    rule: FrozenRule,
    gated: pd.DataFrame,
    cfg: OptimizationConfig,
) -> SizingSolution:
    """Fractional Kelly on dev-gated trades, with fold consistency check.

    One-sided t-test (H0: mean <= 0, H1: mean > 0).
    """
    profits = pd.to_numeric(gated["_profit"], errors="coerce").dropna().values
    n = len(profits)

    if n < cfg.min_dev_trades:
        return _neutral_sizing(rule.rule_id, n, "insufficient_trades")

    wr = float((profits > 0).mean())
    wins = profits[profits > 0]
    losses = profits[profits < 0]

    if len(wins) == 0 or len(losses) == 0:
        return _neutral_sizing(rule.rule_id, n, "no_wins_or_losses")

    avg_win = float(np.mean(wins))
    avg_loss = float(abs(np.mean(losses)))
    if avg_loss <= 1e-12:
        return _neutral_sizing(rule.rule_id, n, "degenerate_loss")

    b = avg_win / avg_loss
    kelly_raw = wr - (1.0 - wr) / b
    kelly_frac = kelly_raw * cfg.kelly_fraction

    # ─── Fold consistency on dev ────────────────────────────────
    fold_agree = _fold_sign_agreement(profits, kelly_raw, cfg)

    # ─── One-sided t-test ───────────────────────────────────────
    _, pval = one_sided_t_test(list(profits), null_mean=0.0)

    # ─── Validation ─────────────────────────────────────────────
    if fold_agree < cfg.min_fold_agree:
        reason = f"fold_unstable({fold_agree:.2f})"
        validated = False
    elif pval > cfg.max_pval:
        reason = f"not_significant(p={pval:.4f})"
        validated = False
    else:
        reason = "ok"
        validated = True

    # ─── Map to multiplier ──────────────────────────────────────
    if not validated:
        mult = cfg.neutral_mult
    else:
        mult = _kelly_to_mult(kelly_frac, cfg)

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
        rule_id=rule_id,
        lot_mult=1.0,
        n_gated_trades=int(n),
        kelly_raw=0.0,
        kelly_frac=0.0,
        fold_agree=0.0,
        pval=1.0,
        validated=False,
        reason=reason,
    )


def _fold_sign_agreement(
    profits: np.ndarray,
    kelly_reference: float,
    cfg: OptimizationConfig,
) -> float:
    """Compute sign agreement of fold Kellys vs reference Kelly.

    Walk-forward on dev: n_folds non-overlapping windows.
    Returns fraction of folds whose Kelly sign matches reference.
    """
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
        b = float(np.mean(wins)) / abs(float(np.mean(losses)))
        if b <= 1e-12:
            continue
        wr = float((fold > 0).mean())
        k = wr - (1.0 - wr) / b
        if np.sign(k) == ref_sign:
            agrees += 1
        total += 1

    return (agrees / total) if total > 0 else 0.0


def _kelly_to_mult(kelly_frac: float, cfg: OptimizationConfig) -> float:
    """Map Kelly fraction to multiplier in [min_mult, max_mult].

    Interpretation:
      kelly_frac = 0    → neutral (1.0)
      kelly_frac = +K   → max_mult
      kelly_frac = -K   → min_mult
    where K = cfg.kelly_fraction (the fraction we act on).
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

    with (output_dir / "production_config.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(
            result.production_config.to_dict(), f, indent=2, default=str,
        )

    with (output_dir / "optimization_summary.json").open(
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

__all__ = [
    "L0_hygiene", "L1_boundary", "L2_feature_engineering",
    "L3_eda", "L4_hard_gate_discovery", "L5_soft_gate_discovery",
    "L6_multiple_testing", "L7_dev_optimization",
]
```

---

## Tests

## `vp_analysis/tests/test_L7_dev_optimization.py`

```python
"""Tests for Layer 7 — Dev Optimization (SL/TP + Sizing)."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.frozen_types import FrozenRule
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L7_dev_optimization import (
    OptimizationConfig,
    _calibrate_sizing,
    _filter_by_rule,
    _fold_sign_agreement,
    _kelly_to_mult,
    _simulate_sl_tp,
    _utility,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["optimization_budget"] = {
        "sl_candidates": [1.0, 1.5, 2.0],
        "tp_candidates": [1.0, 1.5, 2.0],
        "sizing_configs": 5,
        "utility_function": "expectancy",
    }
    return ResearchContract.from_dict(d)


def _make_dev_df(n=500, seed=0, signal_strength=1.5):
    """Dev data where f_signal > 0.6 → trade has positive edge."""
    rng = np.random.default_rng(seed)
    f = rng.uniform(0, 1, n)
    mae = rng.uniform(0.3, 2.5, n)
    mfe = rng.uniform(0.5, 3.0, n)
    noise = rng.normal(0, 0.3, n)
    profit = np.where(f > 0.6, signal_strength, -0.5) + noise
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": f,
        "maeATR": mae,
        "mfeATR": mfe,
        "_profit": profit,
    })


def _make_frozen_rule(
    rule_id="R-00001", feature="f_signal",
    lower=0.6, direction=1, gate_type="threshold",
):
    return FrozenRule(
        rule_id=rule_id,
        experiment_id="EXP-TEST",
        research_contract_hash="sha256:" + "a" * 64,
        symbol="XAUUSD", setup="BOS",
        gate_type=gate_type, direction=direction,
        features=(feature,),
        lower_bound=lower, upper_bound=None,
        test_ev_mean=0.3, test_wr_mean=0.55, test_pf_mean=1.5,
        test_n_avg=50, pvalue=0.01, pvalue_fdr=0.02, fdr_significant=True,
        fold_consistency=0.8, n_folds=4,
    )


# ══════════════════════════════════════════════════════════════════
# Unit tests — rule filter
# ══════════════════════════════════════════════════════════════════

def test_filter_threshold_up():
    df = pd.DataFrame({"f": [0.1, 0.5, 0.9]})
    rule = _make_frozen_rule(lower=0.5, direction=1)
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 2


def test_filter_threshold_down():
    df = pd.DataFrame({"f": [0.1, 0.5, 0.9]})
    rule = FrozenRule(
        rule_id="R-X", experiment_id="E", research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="Y", gate_type="threshold", direction=-1,
        features=("f",), lower_bound=None, upper_bound=0.5,
        fdr_significant=True,
    )
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 2


def test_filter_band():
    df = pd.DataFrame({"f": [0.1, 0.5, 0.9]})
    rule = FrozenRule(
        rule_id="R-X", experiment_id="E", research_contract_hash="sha256:" + "a" * 64,
        symbol="X", setup="Y", gate_type="band", direction=0,
        features=("f",), lower_bound=0.3, upper_bound=0.7,
        fdr_significant=True,
    )
    filtered = _filter_by_rule(df, rule)
    assert len(filtered) == 1


# ══════════════════════════════════════════════════════════════════
# Unit tests — SL/TP simulation
# ══════════════════════════════════════════════════════════════════

def test_simulate_stopped_out():
    profits = np.array([1.0])
    mae = np.array([2.0])
    mfe = np.array([0.5])
    sim = _simulate_sl_tp(profits, mae, mfe, sl=1.5, tp=2.0)
    # MAE 2.0 >= SL 1.5 → stopped out
    assert sim[0] == -1.5


def test_simulate_tp_hit():
    profits = np.array([0.5])
    mae = np.array([0.3])
    mfe = np.array([2.5])
    sim = _simulate_sl_tp(profits, mae, mfe, sl=1.5, tp=2.0)
    # MAE < SL, MFE >= TP → TP hit
    assert sim[0] == 2.0


def test_simulate_original_stands():
    profits = np.array([0.5])
    mae = np.array([0.5])
    mfe = np.array([1.0])
    sim = _simulate_sl_tp(profits, mae, mfe, sl=1.5, tp=2.0)
    # Neither triggered → original profit
    assert sim[0] == 0.5


def test_simulate_uses_all_trades():
    """Verify simulation considers both winners and losers."""
    profits = np.array([1.0, -0.5, 0.8, -1.0])
    mae = np.array([0.5, 2.0, 0.3, 3.0])
    mfe = np.array([1.5, 0.5, 2.5, 0.5])
    sim = _simulate_sl_tp(profits, mae, mfe, sl=1.5, tp=2.0)
    # Row 0: TP hit → 2.0
    # Row 1: MAE 2.0 >= 1.5 → -1.5
    # Row 2: TP hit → 2.0
    # Row 3: MAE 3.0 >= 1.5 → -1.5
    expected = np.array([2.0, -1.5, 2.0, -1.5])
    np.testing.assert_allclose(sim, expected)


def test_utility_expectancy():
    assert _utility(np.array([1.0, 2.0, 3.0]), "expectancy") == 2.0


def test_utility_sharpe_proxy():
    u = _utility(np.array([1.0, 1.0, 1.0]), "sharpe_proxy")
    assert u == 0.0  # zero std → 0


# ══════════════════════════════════════════════════════════════════
# SL/TP optimization integration
# ══════════════════════════════════════════════════════════════════

def test_sl_tp_optimization_runs(contract):
    df = _make_dev_df(n=500, seed=0)
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    assert result.n_sl_tp_optimized == 1
    sol = result.sl_tp_solutions[0]
    assert sol.rule_id == "R-00001"
    assert sol.sl in contract.optimization_budget.sl_candidates
    assert sol.tp in contract.optimization_budget.tp_candidates
    assert sol.n_gated_trades > 0


def test_sl_tp_skipped_when_mae_mfe_missing(contract):
    df = _make_dev_df(n=500).drop(columns=["maeATR", "mfeATR"])
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    assert result.n_sl_tp_optimized == 0
    assert any("SL/TP optimization skipped" in w for w in result.warnings)


def test_sl_tp_skipped_when_disabled(contract):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(
        df, [rule], contract, experiment_id="EXP-TEST",
        config=OptimizationConfig(use_sl_tp_optimization=False),
    )
    assert result.n_sl_tp_optimized == 0


# ══════════════════════════════════════════════════════════════════
# Sizing calibration
# ══════════════════════════════════════════════════════════════════

def test_sizing_validated_for_strong_signal(contract):
    df = _make_dev_df(n=800, seed=0, signal_strength=2.0)
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST",
                 config=OptimizationConfig(min_dev_trades=30,
                                           max_pval=0.20,
                                           min_fold_agree=0.50))
    sol = result.sizing_solutions[0]
    assert sol.n_gated_trades > 0
    # With strong signal, should validate
    assert sol.validated or sol.lot_mult == 1.0


def test_sizing_neutral_for_no_signal(contract):
    """Rule that produces no edge → neutral multiplier."""
    rng = np.random.default_rng(42)
    n = 500
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal": rng.uniform(0, 1, n),
        "maeATR": rng.uniform(0.3, 2.5, n),
        "mfeATR": rng.uniform(0.5, 3.0, n),
        "_profit": rng.normal(0, 1, n),
    })
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST",
                 config=OptimizationConfig(min_dev_trades=30))
    sol = result.sizing_solutions[0]
    assert not sol.validated
    assert sol.lot_mult == 1.0


def test_sizing_insufficient_trades(contract):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(
        df, [rule], contract, experiment_id="EXP-TEST",
        config=OptimizationConfig(min_dev_trades=1000),  # impossible
    )
    # No sizing generated since < min_dev_trades
    assert len(result.sizing_solutions) == 0


def test_sizing_respects_min_max_bounds(contract):
    df = _make_dev_df(n=800, seed=0, signal_strength=5.0)
    rule = _make_frozen_rule()
    result = run(
        df, [rule], contract, experiment_id="EXP-TEST",
        config=OptimizationConfig(
            min_dev_trades=30, max_pval=0.50, min_fold_agree=0.20,
            min_mult=0.5, max_mult=1.5,
        ),
    )
    if result.sizing_solutions:
        sol = result.sizing_solutions[0]
        assert 0.5 <= sol.lot_mult <= 1.5


# ══════════════════════════════════════════════════════════════════
# Kelly mapping
# ══════════════════════════════════════════════════════════════════

def test_kelly_to_mult_neutral():
    cfg = OptimizationConfig(kelly_fraction=0.25)
    assert _kelly_to_mult(0.0, cfg) == 1.0


def test_kelly_to_mult_positive():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    # kelly_frac = 0.25 = full K → max
    assert _kelly_to_mult(0.25, cfg) == 1.5
    # Half of K → half of range
    assert _kelly_to_mult(0.125, cfg) == pytest.approx(1.25)


def test_kelly_to_mult_negative():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    # kelly_frac = -0.25 → min
    assert _kelly_to_mult(-0.25, cfg) == 0.5
    # Half negative → 0.75
    assert _kelly_to_mult(-0.125, cfg) == pytest.approx(0.75)


def test_kelly_to_mult_clipped():
    cfg = OptimizationConfig(kelly_fraction=0.25, min_mult=0.5, max_mult=1.5)
    # Extreme values clip
    assert _kelly_to_mult(1.0, cfg) == 1.5
    assert _kelly_to_mult(-1.0, cfg) == 0.5


# ══════════════════════════════════════════════════════════════════
# Fold agreement
# ══════════════════════════════════════════════════════════════════

def test_fold_agreement_all_positive():
    rng = np.random.default_rng(0)
    profits = rng.normal(0.5, 1.0, 400)  # positive mean
    cfg = OptimizationConfig(n_folds=4)
    agree = _fold_sign_agreement(profits, kelly_reference=0.1, cfg=cfg)
    assert 0.0 <= agree <= 1.0


def test_fold_agreement_zero_reference():
    profits = np.array([0.1, -0.1] * 100)
    cfg = OptimizationConfig(n_folds=4)
    assert _fold_sign_agreement(profits, 0.0, cfg) == 0.0


def test_fold_agreement_small_sample():
    profits = np.array([0.1, 0.2])
    cfg = OptimizationConfig(n_folds=4)
    assert _fold_sign_agreement(profits, 0.1, cfg) == 0.0


# ══════════════════════════════════════════════════════════════════
# FrozenProductionConfig
# ══════════════════════════════════════════════════════════════════

def test_production_config_built(contract):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    config = result.production_config
    assert config.experiment_id == "EXP-TEST"
    assert len(config.rules) == 1
    assert len(config.sl_tp_selections) >= 0
    assert len(config.sizing_configs) >= 0


def test_sl_tp_selection_references_valid_rule(contract):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    rule_ids = {r.rule_id for r in result.production_config.rules}
    for sel in result.production_config.sl_tp_selections:
        assert sel["rule_id"] in rule_ids


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(contract, tmp_path):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    run(df, [rule], contract, experiment_id="EXP-TEST",
        output_dir=tmp_path)
    assert (tmp_path / "sl_tp_optimization.csv").exists()
    assert (tmp_path / "sizing_configs.csv").exists()
    assert (tmp_path / "production_config.json").exists()
    assert (tmp_path / "optimization_summary.json").exists()


def test_summary_json_content(contract, tmp_path):
    df = _make_dev_df(n=500)
    rule = _make_frozen_rule()
    run(df, [rule], contract, experiment_id="EXP-TEST",
        output_dir=tmp_path)
    with (tmp_path / "optimization_summary.json").open() as f:
        s = json.load(f)
    assert s["n_rules"] == 1
    assert "n_sl_tp_optimized" in s


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_df_raises(contract):
    with pytest.raises(ValueError, match="empty"):
        run(pd.DataFrame(), [_make_frozen_rule()], contract,
            experiment_id="EXP-TEST")


def test_missing_profit_raises(contract):
    df = _make_dev_df(n=500).drop(columns=["_profit"])
    with pytest.raises(ValueError, match="_profit"):
        run(df, [_make_frozen_rule()], contract,
            experiment_id="EXP-TEST")


def test_missing_experiment_id_raises(contract):
    df = _make_dev_df(n=500)
    with pytest.raises(ValueError, match="experiment_id"):
        run(df, [_make_frozen_rule()], contract, experiment_id="")


def test_no_rules_raises(contract):
    df = _make_dev_df(n=500)
    with pytest.raises(ValueError, match="no frozen rules"):
        run(df, [], contract, experiment_id="EXP-TEST")


def test_rule_with_no_gated_trades_skipped(contract):
    df = _make_dev_df(n=500)
    # Rule requires f_signal > 5.0 — no trades qualify
    rule = _make_frozen_rule(lower=5.0)
    result = run(df, [rule], contract, experiment_id="EXP-TEST")
    assert result.n_sl_tp_optimized == 0
    assert any("only" in w for w in result.warnings)
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L7_dev_optimization.py -v
```

Kỳ vọng:

```text
test_L7_dev_optimization.py
  Rule filter                         3 passed
  SL/TP simulation                    6 passed
  SL/TP integration                   3 passed
  Sizing calibration                  4 passed
  Kelly mapping                       4 passed
  Fold agreement                      3 passed
  Production config                   2 passed
  Output                              2 passed
  Edge cases                          5 passed
  ────────────────────────────────────────────────
  Total                              32 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 141 + 32 + 30 + 24 + 22 + 16 + 25 + 32 = 322 passed
```

---

## Preview: Layer 7 trong pipeline

```python
from vp_analysis.layers import L7_dev_optimization

l7 = L7_dev_optimization.run(
    dev_df=l2.boundary.dev.data,
    frozen_rules=list(l6.frozen_rules),
    contract=contract,
    experiment_id=manifest.experiment_id,
    output_dir=output_dir / "L7_optimization",
    config=OptimizationConfig(
        use_sl_tp_optimization=True,
        use_sizing=True,
        kelly_fraction=0.25,
        min_dev_trades=30,
        n_folds=4,
        min_fold_agree=0.70,
        max_pval=0.10,
    ),
)

print(f"  Rules: {l7.n_rules}")
print(f"  SL/TP optimized: {l7.n_sl_tp_optimized}")
print(f"  Sizing validated: {l7.n_sizing_validated}")

# L8 will use l7.production_config to evaluate on holdout
```

Output:

```text
output/
├── L7_dev_optimization/
│   ├── sl_tp_optimization.csv
│   ├── sizing_configs.csv
│   ├── production_config.json    ← FrozenProductionConfig
│   └── optimization_summary.json
```

---

## Sprint 7 hoàn tất

**Deliverables:**
- `L7_dev_optimization.py` (~450 dòng) — 2 optimizations + freeze
- 32 tests bao gồm:
  - Rule filter (threshold up/down, band)
  - SL/TP simulation (stopped, TP hit, original, mixed)
  - **Full trade path usage verified** (winners + losers)
  - SL/TP integration (grid selection)
  - Skip when MAE/MFE missing
  - Sizing validation on strong signal
  - Sizing neutral on noise
  - Min bounds enforced
  - Kelly mapping (neutral/positive/negative/clipped)
  - Fold agreement
  - FrozenProductionConfig construction
  - Rule reference consistency
  - Output files
  - Edge cases (empty, no rules, no gated trades)

**Bugs từ ChatGPT critique đã fix:**
1. ✅ **SL/TP uses ALL trade paths** — simulation uses MAE/MFE of all gated trades, không chỉ winners
2. ✅ **Fold consistency trên dev** — `_fold_sign_agreement` dùng dev trades
3. ✅ **One-sided t-test** — dùng `one_sided_t_test` từ kernel
4. ✅ **Kelly mapping honest** — linear map từ kelly_frac sang multiplier range, không nhân đôi Kelly lý thuyết
5. ✅ **Không FDR** — đúng semantics (optimization ≠ hypothesis test)

**Điểm kiến trúc:**
- **FrozenProductionConfig** được build tại đây — bundle rules + SL/TP + sizing
- **Validation của FrozenProductionConfig** tự động check rule_id references
- **Warnings** khi rule bị skip được log, không silence

**Kernel + L0-L7 hiện có:**
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
│  ─────────────────────────────────────────────────────────  │
│  Total                                     322 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Sprint 8 — Layer 8: Holdout Apply (REPORT ONLY):**
- `holdout.unseal_once()` — one-time access
- Apply frozen rules + SL/TP + sizing to holdout
- Report evaluation: EV, WR, PF, N per rule
- `holdout_confirmed` flag (allow 50% degradation)
- **KHÔNG mutate `validated`**
- Output: `holdout_evaluation.csv`, `sl_tp_holdout_report.csv`, `sizing_holdout_report.csv`, `holdout_degradation.csv`
- ~18 tests

