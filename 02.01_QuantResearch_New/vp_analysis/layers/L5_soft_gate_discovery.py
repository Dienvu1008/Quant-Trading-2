"""Layer 5 — Soft Gate Discovery.

A soft gate is a monotone signal: it doesn't gate trades in/out, it tilts
the size/direction. The direction is learned on development; the test
verifies whether conditioning on the signal shifts EV in the expected
direction.

Pipeline (all on dev):
  1. For each feature: direction = sign(Spearman(feature, profit)).
  2. Signal = direction * feature.
  3. Split dev trades by signal percentile (top X% vs bottom X%).
  4. Lift = EV(top) - EV(bottom).
  5. Permutation test on lift (shuffle profit, recompute).
  6. Candidates with perm_pvalue <= alpha go to L6 for FDR.

CRITICAL — no holdout is touched here. The permutation test runs on
development data only. The direction is derived from development only.
The lift is measured on development only. The p-value is a development
p-value, to be FDR-corrected alongside other candidates in L6.

This fixes the design flaw in Phase 02 v3/v4 where the soft-gate
permutation ran on holdout — which would have consumed the holdout
before the freeze.
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
class SoftGateConfig:
    # Direction extraction
    min_spearman_abs: float = 0.00   # allow weak signals; FDR handles strength

    # Minimum sample sizes
    min_total_samples: int = 60
    min_half_samples: int = 20

    # Permutation
    perm_iterations: int = 500
    perm_alpha: float = 0.10
    perm_early_stop_after: int = 100
    perm_early_stop_p: float = 0.30

    # Seed
    seed: int = 42


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class SoftGateDirection:
    feature: str
    category: str
    direction: int
    dev_spearman_rho: float
    dev_spearman_pvalue: float
    n_samples: int

    def to_dict(self) -> dict:
        return {
            "feature": self.feature,
            "category": self.category,
            "direction": self.direction,
            "dev_spearman_rho": round(self.dev_spearman_rho, 6),
            "dev_spearman_pvalue": round(self.dev_spearman_pvalue, 6),
            "n_samples": int(self.n_samples),
        }


@dataclass(frozen=True)
class SoftGateCandidate:
    """Candidate gate after dev permutation. Not yet FDR-corrected."""
    symbol: str
    setup: str
    feature: str
    category: str
    direction: int

    # Development measurements
    dev_spearman_rho: float
    dev_spearman_pvalue: float
    n_total: int
    n_top: int
    n_bottom: int
    ev_top: float
    ev_bottom: float
    ev_lift: float
    wr_top: float
    wr_bottom: float

    # Permutation test (dev)
    perm_pvalue: float

    def to_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "setup": self.setup,
            "feature": self.feature,
            "category": self.category,
            "direction": self.direction,
            "dev_spearman_rho": round(self.dev_spearman_rho, 6),
            "dev_spearman_pvalue": round(self.dev_spearman_pvalue, 6),
            "n_total": int(self.n_total),
            "n_top": int(self.n_top),
            "n_bottom": int(self.n_bottom),
            "ev_top": round(self.ev_top, 6),
            "ev_bottom": round(self.ev_bottom, 6),
            "ev_lift": round(self.ev_lift, 6),
            "wr_top": round(self.wr_top, 6),
            "wr_bottom": round(self.wr_bottom, 6),
            "perm_pvalue": round(self.perm_pvalue, 6),
        }


@dataclass(frozen=True)
class LayerFiveResult:
    directions: tuple
    candidates: tuple
    n_features_evaluated: int
    n_candidates: int
    warnings: tuple
    n_dev_rows: int
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_dev_rows": self.n_dev_rows,
            "n_features_evaluated": self.n_features_evaluated,
            "n_candidates": self.n_candidates,
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_df: pd.DataFrame,
    contract,
    available_features,
    output_dir: Optional[Path] = None,
    config: Optional[SoftGateConfig] = None,
) -> LayerFiveResult:
    """Execute Layer 5 — all computation on dev_df only."""
    cfg = config or SoftGateConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if dev_df is None or len(dev_df) == 0:
        raise ValueError("L5: dev_df is empty")
    if "_profit" not in dev_df.columns:
        raise ValueError("L5: dev_df must have '_profit' column")

    usable = [f for f in available_features if f in dev_df.columns]
    if not usable:
        return LayerFiveResult(
            directions=(), candidates=(),
            n_features_evaluated=0, n_candidates=0,
            warnings=("No usable features present in dev_df",),
            n_dev_rows=len(dev_df), ran_at=ran_at,
        )

    feature_category = _build_feature_category_map(contract.pre_registered)

    # ─── 1. Direction extraction on entire dev ─────────────────
    directions, dir_warnings = _extract_directions(
        dev_df, usable, feature_category, cfg,
    )

    # ─── 2. Per-group permutation screening ────────────────────
    groups = _split_groups(dev_df)
    warnings = list(dir_warnings)
    candidates: list[SoftGateCandidate] = []

    dir_lookup = {d.feature: d for d in directions}

    for symbol, setup, group_df in groups:
        if len(group_df) < cfg.min_total_samples:
            warnings.append(
                f"Group {symbol}/{setup}: {len(group_df)} rows < "
                f"{cfg.min_total_samples}, skipped"
            )
            continue

        group_df = group_df.reset_index(drop=True)
        for feat in usable:
            d = dir_lookup.get(feat)
            if d is None or d.direction == 0:
                continue
            cand = _test_soft_gate(
                group_df, symbol, setup, feat,
                feature_category.get(feat, "unknown"),
                d, cfg,
            )
            if cand is not None:
                candidates.append(cand)

    # Sort by p-value (most significant first)
    candidates.sort(key=lambda c: c.perm_pvalue)

    result = LayerFiveResult(
        directions=tuple(directions),
        candidates=tuple(candidates),
        n_features_evaluated=len(usable),
        n_candidates=len(candidates),
        warnings=tuple(warnings),
        n_dev_rows=len(dev_df),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Direction extraction ───────────────────────────────────────

def _extract_directions(
    dev_df: pd.DataFrame,
    features: list[str],
    feature_category: dict,
    cfg: SoftGateConfig,
) -> tuple[list[SoftGateDirection], list[str]]:
    """Compute Spearman(feature, profit) on full dev, one entry per feature."""
    out: list[SoftGateDirection] = []
    warnings: list[str] = []
    profits = pd.to_numeric(dev_df["_profit"], errors="coerce")

    for feat in features:
        series = pd.to_numeric(dev_df[feat], errors="coerce")
        valid = series.notna() & profits.notna()
        n = int(valid.sum())
        if n < cfg.min_total_samples:
            warnings.append(
                f"Direction for {feat!r}: only {n} valid rows, skipped"
            )
            continue

        x = series[valid].values
        y = profits[valid].values

        if float(np.std(x)) < 1e-12:
            warnings.append(
                f"Direction for {feat!r}: zero variance, skipped"
            )
            continue

        rho, pval = stats.spearmanr(x, y)
        rho = float(rho) if not np.isnan(rho) else 0.0
        pval = float(pval) if not np.isnan(pval) else 1.0

        direction = 1 if rho >= 0 else -1

        out.append(SoftGateDirection(
            feature=feat,
            category=feature_category.get(feat, "unknown"),
            direction=direction,
            dev_spearman_rho=rho,
            dev_spearman_pvalue=pval,
            n_samples=n,
        ))

    return out, warnings


# ─── Per-group soft gate test ─────────────────────────────────────

def _test_soft_gate(
    group_df: pd.DataFrame,
    symbol: str,
    setup: str,
    feature: str,
    category: str,
    direction_info: SoftGateDirection,
    cfg: SoftGateConfig,
) -> Optional[SoftGateCandidate]:
    """Test one soft gate on one (symbol, setup) group. Dev only."""
    profits = pd.to_numeric(group_df["_profit"], errors="coerce")
    vals = pd.to_numeric(group_df[feature], errors="coerce")
    valid = vals.notna() & profits.notna()
    n_total = int(valid.sum())
    if n_total < cfg.min_total_samples:
        return None

    vals_arr = vals[valid].values.astype(float)
    profits_arr = profits[valid].values.astype(float)

    # Signal uses direction frozen from dev
    signal = direction_info.direction * vals_arr

    # Median split
    med = float(np.median(signal))
    top_mask = signal > med
    bot_mask = signal < med
    n_top = int(top_mask.sum())
    n_bot = int(bot_mask.sum())
    if n_top < cfg.min_half_samples or n_bot < cfg.min_half_samples:
        return None

    ev_top = float(profits_arr[top_mask].mean())
    ev_bot = float(profits_arr[bot_mask].mean())
    lift = ev_top - ev_bot

    wr_top = float((profits_arr[top_mask] > 0).mean())
    wr_bot = float((profits_arr[bot_mask] > 0).mean())

    # Permutation test on dev: shuffle profits, recompute lift
    perm_p = _permutation_soft_gate(
        profits_arr, top_mask, bot_mask, lift, cfg,
    )

    if perm_p > cfg.perm_alpha:
        return None

    return SoftGateCandidate(
        symbol=symbol, setup=setup,
        feature=feature, category=category,
        direction=direction_info.direction,
        dev_spearman_rho=direction_info.dev_spearman_rho,
        dev_spearman_pvalue=direction_info.dev_spearman_pvalue,
        n_total=n_total, n_top=n_top, n_bottom=n_bot,
        ev_top=ev_top, ev_bottom=ev_bot, ev_lift=lift,
        wr_top=wr_top, wr_bottom=wr_bot,
        perm_pvalue=perm_p,
    )


def _permutation_soft_gate(
    profits: np.ndarray,
    top_mask: np.ndarray,
    bot_mask: np.ndarray,
    observed_lift: float,
    cfg: SoftGateConfig,
) -> float:
    """One-sided permutation: P(lift_perm >= observed_lift) under H0.

    Signal positions are held fixed; only profits are shuffled.
    Early stop if clearly not significant.
    """
    arr = profits.copy()
    rng = np.random.default_rng(cfg.seed)
    count = 0
    for it in range(cfg.perm_iterations):
        rng.shuffle(arr)
        null_lift = float(arr[top_mask].mean() - arr[bot_mask].mean())
        if null_lift >= observed_lift:
            count += 1
        if it + 1 >= cfg.perm_early_stop_after:
            p = count / (it + 1)
            if p > cfg.perm_early_stop_p:
                return p
    return count / cfg.perm_iterations


# ─── Grouping ────────────────────────────────────────────────────

def _split_groups(df: pd.DataFrame) -> list[tuple[str, str, pd.DataFrame]]:
    if "symbol" not in df.columns:
        if "setupType" in df.columns:
            out = []
            for st in df["setupType"].dropna().unique():
                if st in ("NONE", ""):
                    continue
                sub = df[df["setupType"] == st].reset_index(drop=True)
                out.append(("ALL", str(st), sub))
            return out
        return [("ALL", "ALL", df)]

    out: list[tuple[str, str, pd.DataFrame]] = []
    for sym in df["symbol"].unique():
        sym_df = df[df["symbol"] == sym]
        if "setupType" in sym_df.columns:
            for st in sym_df["setupType"].dropna().unique():
                if st in ("NONE", ""):
                    continue
                sub = sym_df[sym_df["setupType"] == st].reset_index(drop=True)
                if len(sub) > 0:
                    out.append((str(sym), str(st), sub))
        else:
            out.append((str(sym), "ALL", sym_df.reset_index(drop=True)))
    return out


# ─── Helpers ─────────────────────────────────────────────────────

def _build_feature_category_map(pre_registered: dict) -> dict:
    out: dict[str, str] = {}
    for cat, features in pre_registered.items():
        for f in features:
            out[f] = cat
    return out


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerFiveResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    if result.directions:
        pd.DataFrame(
            [d.to_dict() for d in result.directions]
        ).to_csv(output_dir / "soft_gate_directions.csv", index=False)

    if result.candidates:
        pd.DataFrame(
            [c.to_dict() for c in result.candidates]
        ).to_csv(output_dir / "soft_gate_candidates.csv", index=False)

    with (output_dir / "soft_gate_discovery_summary.json").open(
        "w", encoding="utf-8",
    ) as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)
