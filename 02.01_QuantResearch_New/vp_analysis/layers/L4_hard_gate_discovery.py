"""Layer 4 — Hard Gate Discovery via Nested Walk-Forward.

Structure per outer fold:
    outer_train = dev.iloc[:te]
    outer_test  = dev.iloc[vs:ve]     (gap between)

    Inner walk-forward (3 folds) on outer_train:
        inner_train = outer_train.iloc[:te_inner]
        inner_val   = outer_train.iloc[vs_inner:ve_inner]

        For each candidate feature:
          - search threshold / band on inner_train
          - evaluate candidate on inner_val (no mutation)
          - permutation screening on inner_val
          - score = (EV - t*SE) * sqrt(n)
        Best rule per feature = argmax(score) across inner folds.

    Apply best inner rule to outer_test (no mutation).
    Record: ev, wr, pf, n, rule.

Aggregation across outer folds:
    Keep features with >= MIN_FOLDS_RESULTS fold results.
    Keep those with:
      - mean EV >= MIN_EFFECT_SIZE
      - fold consistency >= MIN_FOLD_CONSISTENCY
      - one-sided t-test p < 0.05
      - bootstrap CI low > 0
      - temporal slope not significantly negative

Output: GateCandidate objects with combined_p (not yet FDR-corrected).
"""
from __future__ import annotations

import datetime as dt
import json
import math
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from scipy import stats

from ..core.stats_helpers import bootstrap_ci, one_sided_t_test


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class HardGateConfig:
    # Outer walk-forward
    outer_folds: int = 5
    inner_folds: int = 3
    gap_ratio: float = 0.10
    min_inner_train: int = 15
    min_inner_val: int = 15
    min_outer_test: int = 15

    # Candidate search
    n_threshold_quantiles: int = 15
    threshold_pct_low: float = 0.20
    threshold_pct_high: float = 0.80
    n_band_min_frac: float = 0.20
    n_band_max_frac: float = 0.70
    band_scan_limit: int = 10

    # Economic filters (per-fold evaluation)
    min_effect_size: float = 0.05
    min_win_rate: float = 0.35
    min_profit_factor: float = 1.10

    # Permutation screening (inner)
    perm_iterations: int = 100
    perm_alpha: float = 0.10
    perm_early_stop_after: int = 30
    perm_early_stop_p: float = 0.30

    # Aggregation
    min_folds_results: int = 2
    fold_consistency_threshold: float = 0.60
    ttest_alpha: float = 0.05
    ci_alpha: float = 0.10
    temporal_slope_min_p: float = 0.15

    # Confidence level for the search score
    confidence_level: float = 0.95
    min_pass_ratio: float = 0.05
    max_pass_ratio: float = 0.75

    # Randomness
    seed: int = 42

    # Cap
    max_candidates_per_feature: int = 50


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class ThresholdRuleSpec:
    """A frozen rule specification from inner search."""
    gate_type: str              # "threshold" | "band"
    direction: int              # -1, 0, +1
    lower: Optional[float]
    upper: Optional[float]


@dataclass(frozen=True)
class FoldResult:
    fold_idx: int
    ev: float
    wr: float
    pf: float
    n: int
    pass_ratio: float


@dataclass(frozen=True)
class GateCandidate:
    """One candidate gate after outer-fold aggregation. Not yet FDR'd."""
    symbol: str
    setup: str
    feature: str
    category: str
    shape_prior: str

    gate_type: str
    direction: int
    lower: Optional[float]
    upper: Optional[float]

    mean_ev: float
    mean_wr: float
    mean_pf: float
    mean_n: int
    mean_pass_ratio: float

    n_folds: int
    fold_consistency: float
    ttest_pvalue: float
    ci_low: float
    ci_high: float
    temporal_slope_p: float

    fold_results: tuple  # of FoldResult.to_dict()

    # Diagnostic
    inner_search_rule_count: int

    def to_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "setup": self.setup,
            "feature": self.feature,
            "category": self.category,
            "shape_prior": self.shape_prior,
            "gate_type": self.gate_type,
            "direction": self.direction,
            "lower": self.lower,
            "upper": self.upper,
            "mean_ev": round(self.mean_ev, 6),
            "mean_wr": round(self.mean_wr, 6),
            "mean_pf": round(self.mean_pf, 6),
            "mean_n": int(self.mean_n),
            "mean_pass_ratio": round(self.mean_pass_ratio, 6),
            "n_folds": self.n_folds,
            "fold_consistency": round(self.fold_consistency, 4),
            "ttest_pvalue": round(self.ttest_pvalue, 6),
            "ci_low": round(self.ci_low, 6),
            "ci_high": round(self.ci_high, 6),
            "temporal_slope_p": round(self.temporal_slope_p, 6),
            "inner_search_rule_count": self.inner_search_rule_count,
        }


@dataclass(frozen=True)
class LayerFourResult:
    candidates: tuple
    n_features_searched: int
    n_features_kept: int
    warnings: tuple
    n_dev_rows: int
    n_symbols: int
    n_setups: int
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_dev_rows": self.n_dev_rows,
            "n_symbols": self.n_symbols,
            "n_setups": self.n_setups,
            "n_features_searched": self.n_features_searched,
            "n_features_kept": self.n_features_kept,
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_df: pd.DataFrame,
    contract,
    available_features,  # iterable from L1
    output_dir: Optional[Path] = None,
    config: Optional[HardGateConfig] = None,
) -> LayerFourResult:
    """Execute Layer 4.

    dev_df must be the development DataFrame with `_profit` column set.
    Only features that have a SHAPE_PRIOR in contract.shape_priors are used.
    """
    cfg = config or HardGateConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if dev_df is None or len(dev_df) == 0:
        raise ValueError("L4: dev_df is empty")
    if "_profit" not in dev_df.columns:
        raise ValueError("L4: dev_df must have '_profit' column")

    # Filter to features that have a shape prior (contract-governed)
    usable = [f for f in available_features
              if f in dev_df.columns and f in contract.shape_priors]
    if not usable:
        return LayerFourResult(
            candidates=(), n_features_searched=0, n_features_kept=0,
            warnings=("No features with SHAPE_PRIOR present",),
            n_dev_rows=len(dev_df), n_symbols=0, n_setups=0,
            ran_at=ran_at,
        )

    # Group by (symbol, setupType) — discovery runs per group
    groups = _split_groups(dev_df)
    warnings: list[str] = []

    all_candidates: list[GateCandidate] = []
    n_searched = 0

    for symbol, setup, group_df in groups:
        if len(group_df) < cfg.min_inner_train * 3:
            warnings.append(
                f"Group {symbol}/{setup}: only {len(group_df)} rows, "
                f"skipped (need >= {cfg.min_inner_train * 3})"
            )
            continue

        group_df = group_df.reset_index(drop=True)
        candidates = _discover_in_group(
            group_df, symbol, setup, usable, contract, cfg,
        )
        all_candidates.extend(candidates)
        n_searched += len(usable)

    result = LayerFourResult(
        candidates=tuple(all_candidates),
        n_features_searched=n_searched,
        n_features_kept=len(all_candidates),
        warnings=tuple(warnings),
        n_dev_rows=len(dev_df),
        n_symbols=len({g[0] for g in groups}),
        n_setups=len({g[1] for g in groups}),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Grouping ────────────────────────────────────────────────────

def _split_groups(
    df: pd.DataFrame,
) -> list[tuple[str, str, pd.DataFrame]]:
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


# ─── Per-group discovery ─────────────────────────────────────────

def _discover_in_group(
    df: pd.DataFrame,
    symbol: str,
    setup: str,
    features: list[str],
    contract,
    cfg: HardGateConfig,
) -> list[GateCandidate]:
    """Run nested walk-forward on one (symbol, setup) group."""
    n = len(df)
    gap = max(1, int(n * cfg.gap_ratio))
    fold_size = n // (cfg.outer_folds + 1)
    if fold_size < cfg.min_inner_train:
        return []

    feature_category = _build_feature_category_map(contract.pre_registered)
    profits_all = df["_profit"].values.astype(float)

    # feature -> list of FoldResult
    outer_results: dict[str, list[FoldResult]] = defaultdict(list)
    # feature -> list of inner best rule specs (for diagnostics)
    inner_rule_counts: dict[str, int] = defaultdict(int)
    # feature -> most recent winning rule spec
    last_rule: dict[str, ThresholdRuleSpec] = {}

    for i in range(cfg.outer_folds):
        te = fold_size * (i + 1)
        vs = te + gap
        ve = min(vs + fold_size, n)
        if ve - vs < cfg.min_outer_test:
            continue

        outer_train = df.iloc[:te]
        outer_test = df.iloc[vs:ve]

        inner_rules = _inner_walk_forward(
            outer_train, features, contract, cfg,
        )

        test_profits = outer_test["_profit"].values.astype(float)
        for feat, (rule_spec, inner_count) in inner_rules.items():
            inner_rule_counts[feat] += inner_count
            vals = pd.to_numeric(
                outer_test[feat], errors="coerce",
            ).fillna(0.0).values
            mask = _apply_rule(vals, rule_spec)
            n_pass = int(mask.sum())
            if n_pass < cfg.min_outer_test:
                continue
            pass_ratio = n_pass / len(outer_test)
            if pass_ratio < cfg.min_pass_ratio or pass_ratio > cfg.max_pass_ratio:
                continue

            ev = float(test_profits[mask].mean())
            if ev < cfg.min_effect_size * 0.5:
                continue

            wr = float((test_profits[mask] > 0).mean())
            pos = test_profits[mask][test_profits[mask] > 0].sum()
            neg = abs(test_profits[mask][test_profits[mask] < 0].sum())
            pf = float(pos / neg) if neg > 0 else 999.0

            outer_results[feat].append(FoldResult(
                fold_idx=i, ev=ev, wr=wr, pf=min(pf, 999.0),
                n=n_pass, pass_ratio=pass_ratio,
            ))
            last_rule[feat] = rule_spec

    # ─── Aggregation ────────────────────────────────────────────
    candidates: list[GateCandidate] = []
    for feat, folds in outer_results.items():
        if len(folds) < cfg.min_folds_results:
            continue

        evs = [f.ev for f in folds]
        wrs = [f.wr for f in folds]
        pfs = [f.pf for f in folds]
        ns = [f.n for f in folds]
        prs = [f.pass_ratio for f in folds]

        mean_ev = float(np.mean(evs))
        if mean_ev < cfg.min_effect_size:
            continue

        positive_folds = sum(1 for e in evs if e > 0)
        fold_consistency = positive_folds / len(evs)
        if fold_consistency < cfg.fold_consistency_threshold:
            continue

        _, ttest_p = one_sided_t_test(evs, null_mean=0.0)
        if ttest_p >= cfg.ttest_alpha:
            continue

        ci_lo, ci_hi = bootstrap_ci(evs, alpha=cfg.ci_alpha, seed=cfg.seed)
        if ci_lo <= 0:
            continue

        temporal_p = _temporal_slope_p(evs)
        if temporal_p < cfg.temporal_slope_min_p and _slope_is_negative(evs):
            continue

        rule_spec = last_rule.get(feat)
        if rule_spec is None:
            continue

        candidates.append(GateCandidate(
            symbol=symbol, setup=setup, feature=feat,
            category=feature_category.get(feat, "unknown"),
            shape_prior=contract.shape_priors[feat],
            gate_type=rule_spec.gate_type,
            direction=rule_spec.direction,
            lower=rule_spec.lower,
            upper=rule_spec.upper,
            mean_ev=mean_ev,
            mean_wr=float(np.mean(wrs)),
            mean_pf=float(np.mean(pfs)),
            mean_n=int(np.mean(ns)),
            mean_pass_ratio=float(np.mean(prs)),
            n_folds=len(folds),
            fold_consistency=fold_consistency,
            ttest_pvalue=ttest_p,
            ci_low=ci_lo,
            ci_high=ci_hi,
            temporal_slope_p=temporal_p,
            fold_results=tuple(
                {"fold_idx": f.fold_idx, "ev": f.ev, "wr": f.wr,
                 "pf": f.pf, "n": f.n, "pass_ratio": f.pass_ratio}
                for f in folds
            ),
            inner_search_rule_count=inner_rule_counts.get(feat, 0),
        ))

    candidates.sort(key=lambda c: -c.mean_ev)
    return candidates[:cfg.max_candidates_per_feature]


# ─── Inner walk-forward ──────────────────────────────────────────

def _inner_walk_forward(
    outer_train: pd.DataFrame,
    features: list[str],
    contract,
    cfg: HardGateConfig,
) -> dict[str, tuple[ThresholdRuleSpec, int]]:
    """Run inner WF and return best rule per feature.

    Returns: {feature: (best_rule, n_rules_tried_across_inner_folds)}
    """
    n = len(outer_train)
    gap = max(1, int(n * cfg.gap_ratio))
    fold_size = n // (cfg.inner_folds + 1)
    if fold_size < cfg.min_inner_train:
        return {}

    # feature -> list of (score, rule_spec)
    feature_scores: dict[str, list[tuple[float, ThresholdRuleSpec]]] = defaultdict(list)
    feature_n_tried: dict[str, int] = defaultdict(int)

    for j in range(cfg.inner_folds):
        te = fold_size * (j + 1)
        vs = te + gap
        ve = min(vs + fold_size, n)
        if ve - vs < cfg.min_inner_val:
            continue
        if te < cfg.min_inner_train:
            continue

        inner_train = outer_train.iloc[:te]
        inner_val = outer_train.iloc[vs:ve]

        train_profits = inner_train["_profit"].values.astype(float)
        val_profits = inner_val["_profit"].values.astype(float)

        for feat in features:
            if feat not in inner_train.columns or feat not in inner_val.columns:
                continue
            prior = contract.shape_priors[feat]

            train_vals = pd.to_numeric(
                inner_train[feat], errors="coerce",
            ).fillna(0.0).values
            val_vals = pd.to_numeric(
                inner_val[feat], errors="coerce",
            ).fillna(0.0).values

            rule_spec = _search_candidate_rule(
                train_vals, train_profits, prior, cfg,
            )
            feature_n_tried[feat] += 1
            if rule_spec is None:
                continue

            # Evaluate on inner_val (no mutation, threshold was learned on train)
            mask = _apply_rule(val_vals, rule_spec)
            n_pass = int(mask.sum())
            if n_pass < cfg.min_inner_val:
                continue
            pass_ratio = n_pass / len(inner_val)
            if pass_ratio < cfg.min_pass_ratio or pass_ratio > cfg.max_pass_ratio:
                continue

            ev = float(val_profits[mask].mean())
            if ev < cfg.min_effect_size:
                continue

            wr = float((val_profits[mask] > 0).mean())
            if wr < cfg.min_win_rate:
                continue
            pos = val_profits[mask][val_profits[mask] > 0].sum()
            neg = abs(val_profits[mask][val_profits[mask] < 0].sum())
            pf = float(pos / neg) if neg > 0 else 999.0
            if pf < cfg.min_profit_factor:
                continue

            # Permutation screening on inner_val (valid: rule fixed)
            perm_p = _permutation_screen(
                val_profits, mask, ev, cfg,
            )
            if perm_p > cfg.perm_alpha:
                continue

            # Confidence-adjusted score
            std = float(np.std(val_profits[mask], ddof=1))
            se = std / math.sqrt(n_pass) if n_pass > 1 else 0.0
            if se <= 0:
                continue
            t_crit = float(stats.t.ppf(cfg.confidence_level, df=max(1, n_pass - 1)))
            score = (ev - t_crit * se) * math.sqrt(n_pass)

            feature_scores[feat].append((score, rule_spec))

    # Pick best per feature
    out: dict[str, tuple[ThresholdRuleSpec, int]] = {}
    for feat, scored in feature_scores.items():
        if not scored:
            continue
        best = max(scored, key=lambda x: x[0])
        if best[0] <= 0:
            continue
        out[feat] = (best[1], feature_n_tried[feat])
    return out


# ─── Candidate rule search (on training slice) ──────────────────

def _search_candidate_rule(
    vals: np.ndarray,
    profits: np.ndarray,
    shape_prior: str,
    cfg: HardGateConfig,
) -> Optional[ThresholdRuleSpec]:
    """Shape-aware search on a training slice."""
    n = len(vals)
    if n < cfg.min_inner_train:
        return None

    if shape_prior == "MONO_UP":
        return _search_threshold(vals, profits, direction=+1, cfg=cfg)
    if shape_prior == "MONO_DOWN":
        return _search_threshold(vals, profits, direction=-1, cfg=cfg)
    if shape_prior == "BAND":
        return _search_band(vals, profits, cfg=cfg)
    return None


def _search_threshold(
    vals: np.ndarray,
    profits: np.ndarray,
    direction: int,
    cfg: HardGateConfig,
) -> Optional[ThresholdRuleSpec]:
    n = len(vals)
    if n < cfg.min_inner_train:
        return None

    quantiles = np.linspace(10, 90, cfg.n_threshold_quantiles)
    candidates = np.percentile(vals, quantiles)

    # Restrict to middle range to avoid tiny groups
    keep_mask = (
        (quantiles >= cfg.threshold_pct_low * 100)
        & (quantiles <= cfg.threshold_pct_high * 100)
    )
    candidates = candidates[keep_mask]
    if len(candidates) == 0:
        return None

    best: Optional[ThresholdRuleSpec] = None
    best_score = -np.inf

    for t in candidates:
        if direction == +1:
            mask = vals >= t
            lower, upper = float(t), None
        else:
            mask = vals <= t
            lower, upper = None, float(t)

        n_pass = int(mask.sum())
        if n_pass < cfg.min_inner_train:
            continue
        pass_ratio = n_pass / n
        if pass_ratio < cfg.min_pass_ratio or pass_ratio > cfg.max_pass_ratio:
            continue

        ev = float(profits[mask].mean())
        if ev < cfg.min_effect_size:
            continue

        se = float(np.std(profits[mask], ddof=1)) / math.sqrt(n_pass)
        if se <= 0:
            continue
        t_crit = float(stats.t.ppf(cfg.confidence_level, df=max(1, n_pass - 1)))
        score = (ev - t_crit * se) * math.sqrt(n_pass)
        if score > best_score:
            best_score = score
            best = ThresholdRuleSpec(
                gate_type="threshold", direction=direction,
                lower=lower, upper=upper,
            )

    return best


def _search_band(
    vals: np.ndarray,
    profits: np.ndarray,
    cfg: HardGateConfig,
) -> Optional[ThresholdRuleSpec]:
    n = len(vals)
    if n < cfg.min_inner_train:
        return None

    lo_pcts = np.linspace(20, 40, 4)
    hi_pcts = np.linspace(60, 80, 4)

    best: Optional[ThresholdRuleSpec] = None
    best_score = -np.inf
    scans = 0

    for lo_p in lo_pcts:
        for hi_p in hi_pcts:
            if scans >= cfg.band_scan_limit:
                break
            scans += 1
            lt = float(np.percentile(vals, lo_p))
            ht = float(np.percentile(vals, hi_p))
            if lt >= ht:
                continue
            mask = (vals >= lt) & (vals <= ht)
            n_pass = int(mask.sum())
            if n_pass < cfg.min_inner_train:
                continue
            pass_ratio = n_pass / n
            if pass_ratio < cfg.min_pass_ratio or pass_ratio > cfg.max_pass_ratio:
                continue
            ev = float(profits[mask].mean())
            if ev < cfg.min_effect_size:
                continue
            se = float(np.std(profits[mask], ddof=1)) / math.sqrt(n_pass)
            if se <= 0:
                continue
            t_crit = float(stats.t.ppf(cfg.confidence_level, df=max(1, n_pass - 1)))
            score = (ev - t_crit * se) * math.sqrt(n_pass)
            if score > best_score:
                best_score = score
                best = ThresholdRuleSpec(
                    gate_type="band", direction=0,
                    lower=lt, upper=ht,
                )

    return best


# ─── Apply rule ─────────────────────────────────────────────────

def _apply_rule(vals: np.ndarray, rule: ThresholdRuleSpec) -> np.ndarray:
    if rule.gate_type == "threshold":
        if rule.direction == 1:
            return vals >= rule.lower
        if rule.direction == -1:
            return vals <= rule.upper
        return np.zeros(len(vals), dtype=bool)
    if rule.gate_type == "band":
        return (vals >= rule.lower) & (vals <= rule.upper)
    return np.zeros(len(vals), dtype=bool)


# ─── Permutation screening ──────────────────────────────────────

def _permutation_screen(
    profits: np.ndarray,
    mask: np.ndarray,
    observed_ev: float,
    cfg: HardGateConfig,
) -> float:
    """Fast permutation with early stop. Rule fixed → test is valid."""
    n_pass = int(mask.sum())
    if n_pass < 2 or n_pass >= len(profits):
        return 1.0

    arr = profits.copy()
    rng = np.random.default_rng(cfg.seed)
    count = 0
    for it in range(cfg.perm_iterations):
        rng.shuffle(arr)
        null_ev = float(arr[:n_pass].mean())
        if null_ev >= observed_ev:
            count += 1
        if it + 1 >= cfg.perm_early_stop_after:
            p = count / (it + 1)
            if p > cfg.perm_early_stop_p:
                return p
    return count / cfg.perm_iterations


# ─── Aggregation helpers ────────────────────────────────────────

def _temporal_slope_p(evs: list[float]) -> float:
    """One-sided p that slope is negative. Small p = decay evidence."""
    if len(evs) < 4:
        return 1.0
    slope, _, _, p_two, _ = stats.linregress(np.arange(len(evs)), np.array(evs))
    return float(p_two / 2) if slope < 0 else 1.0


def _slope_is_negative(evs: list[float]) -> bool:
    if len(evs) < 4:
        return False
    slope, _, _, _, _ = stats.linregress(np.arange(len(evs)), np.array(evs))
    return slope < 0


# ─── Helpers ─────────────────────────────────────────────────────

def _build_feature_category_map(pre_registered: dict) -> dict:
    out: dict[str, str] = {}
    for cat, features in pre_registered.items():
        for f in features:
            out[f] = cat
    return out


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerFourResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    if result.candidates:
        pd.DataFrame(
            [c.to_dict() for c in result.candidates]
        ).to_csv(output_dir / "hard_gate_candidates.csv", index=False)

        # Fold-level details
        fold_rows = []
        for c in result.candidates:
            for f in c.fold_results:
                fold_rows.append({
                    "symbol": c.symbol, "setup": c.setup,
                    "feature": c.feature,
                    **f,
                })
        if fold_rows:
            pd.DataFrame(fold_rows).to_csv(
                output_dir / "fold_details.csv", index=False,
            )

    with (output_dir / "hard_gate_discovery_summary.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.summary_dict(), f, indent=2, default=str)
