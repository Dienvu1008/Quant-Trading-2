"""Layer 4b — Regime Block Discovery.

Finds (setup, regime) combinations where the blocked EV is significantly
negative — i.e., trading in that regime/condition is unprofitable even
after passing the hard-gate feature conditions.

This layer is the governance-integrated replacement for the old Phase 05
(vp_05_regime_analysis.py). Key differences from the old pipeline:

  1. Runs on production-style dev only (70% temporal split, same as L4).
  2. Does NOT pre-filter by L4 results (regime block is independent).
  3. FDR pool is isolated: 'regime_block' — separate from hard/soft gate pools.
  4. n_total_hypotheses is frozen at L1, NOT recomputed here.
  5. Output is candidates (not yet FDR'd) — L6 applies FDR.
  6. Holdout evaluation is in L8.3 (after L8 unseal).

Walk-forward structure (per symbol):
    Outer fold: train = dev[:te], test = dev[vs:ve], gap = 10%
    Discover candidate block rules on train.
    Validate on test: blocked_ev < 0, lift >= MIN_EV_IMPROVEMENT,
    WR_blocked < 0.40, permutation test.
    Aggregate across folds: Fisher's combined p, fold consistency.

Output: RegimeBlockCandidate objects with combined_p (not yet FDR'd).
"""
from __future__ import annotations

import datetime as dt
import json
import math
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from scipy import stats


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class RegimeBlockConfig:
    outer_folds: int = 5
    gap_ratio: float = 0.10
    min_train_samples: int = 15
    min_val_samples: int = 10
    min_block_samples: int = 10   # min trades in blocked group per fold
    min_pass_samples: int = 10    # min trades in non-blocked group per fold
    perm_iterations: int = 300
    fold_consistency_threshold: float = 0.70  # stricter than L4 (0.60)
    min_ev_improvement: float = 0.10          # min lift: pass_ev - blocked_ev
    min_wr_improvement: float = 0.03
    max_candidates_per_symbol: int = 20
    seed: int = 42


REGIME_NAMES = {
    0: "BALANCED_ROTATION",  1: "COMPRESSION",      2: "TREND_INITIATION",
    3: "TREND_CONTINUATION", 4: "RE_ACCUMULATION",  5: "EXHAUSTION",
    6: "FAILED_AUCTION",     7: "EXCESS",            8: "CHAOTIC",
}
LT_TRANS_BINS = ["LT_HIGH", "LT_MED", "LT_LOW", "LT_UNKNOWN"]


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class RegimeBlockCandidate:
    """One candidate block rule after outer-fold aggregation. Not yet FDR'd."""
    symbol: str
    setup: str
    rule_type: str       # "auction_regime" | "auction_failure" | etc.
    condition: str       # regime name, "auctFailure>0.5", "regime+session", etc.

    mean_blocked_ev: float    # EV of blocked trades (should be negative)
    mean_pass_ev: float       # EV of non-blocked trades (should be higher)
    mean_lift: float          # pass_ev - blocked_ev (should be positive)
    mean_wr_blocked: float
    mean_n_blocked: int
    n_folds: int
    fold_consistency: float   # fraction of folds with lift > 0
    combined_p: float         # Fisher's combined p from per-fold perm tests
    temporal_slope_p: float

    fold_details: tuple       # list of per-fold dicts for audit

    def to_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "setup": self.setup,
            "rule_type": self.rule_type,
            "condition": self.condition,
            "mean_blocked_ev": round(self.mean_blocked_ev, 6),
            "mean_pass_ev": round(self.mean_pass_ev, 6),
            "mean_lift": round(self.mean_lift, 6),
            "mean_wr_blocked": round(self.mean_wr_blocked, 6),
            "mean_n_blocked": int(self.mean_n_blocked),
            "n_folds": self.n_folds,
            "fold_consistency": round(self.fold_consistency, 4),
            "combined_p": round(self.combined_p, 6),
            "temporal_slope_p": round(self.temporal_slope_p, 6),
        }


@dataclass
class LayerFourBResult:
    candidates: tuple           # of RegimeBlockCandidate
    n_hypotheses_attempted: int
    n_symbols: int
    n_setups: int
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_hypotheses_attempted": self.n_hypotheses_attempted,
            "n_candidates": len(self.candidates),
            "n_symbols": self.n_symbols,
            "n_setups": self.n_setups,
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_df: pd.DataFrame,
    run_meta: dict,          # from L1 — contains n_total_hypotheses
    output_dir: Optional[Path] = None,
    config: Optional[RegimeBlockConfig] = None,
) -> LayerFourBResult:
    """Execute Layer 4b.

    dev_df must be the production-style development DataFrame with:
      - '_profit' column
      - 'symbol', 'setupType' columns
      - 'auctRegime' (or 'regimeName') column
      - optionally: 'auctFailure', 'session', 'vpLTTransitionScore'

    n_total_hypotheses["regime_block"] is read from run_meta (frozen at L1).
    This layer does NOT recompute n_total — it must match what L1 logged.
    """
    cfg = config or RegimeBlockConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if dev_df is None or len(dev_df) == 0:
        raise ValueError("L4b: dev_df is empty")
    if "_profit" not in dev_df.columns:
        raise ValueError("L4b: dev_df must have '_profit' column")

    # Prepare derived columns
    df = dev_df.copy()
    if "auctRegime" in df.columns and "regimeName" not in df.columns:
        df["regimeName"] = df["auctRegime"].map(REGIME_NAMES).fillna("UNKNOWN")
    if "regimeName" not in df.columns:
        df["regimeName"] = "UNKNOWN"

    if "session" not in df.columns:
        df["_session"] = "0"
    else:
        df["_session"] = df["session"].astype(str)

    if "_session" not in df.columns:
        df["_session"] = "0"

    if "vpLTTransitionScore" in df.columns:
        ts = df["vpLTTransitionScore"].fillna(0)
        df["_ltBin"] = np.where(ts > 0.5, "LT_HIGH",
                       np.where(ts > 0.25, "LT_MED", "LT_LOW"))
    elif "_ltBin" not in df.columns:
        df["_ltBin"] = "LT_UNKNOWN"

    # n_total from run_meta (frozen — do not recompute)
    n_total = run_meta.get("n_total_hypotheses", {}).get("regime_block", 0)

    groups = _split_groups(df)
    all_candidates: list[RegimeBlockCandidate] = []
    warnings: list[str] = []
    n_attempted = 0

    for symbol, setup, group_df in groups:
        if len(group_df) < cfg.min_train_samples * 3:
            warnings.append(f"Group {symbol}/{setup}: too small, skipped")
            continue
        candidates, attempted = _discover_in_group(group_df, symbol, setup, cfg)
        all_candidates.extend(candidates)
        n_attempted += attempted

    # Sanity check: log warning if attempted count doesn't match n_total
    if n_total > 0 and abs(n_attempted - n_total) > n_total * 0.10:
        warnings.append(
            f"n_attempted ({n_attempted}) differs from run_meta n_total "
            f"({n_total}) by > 10%. Check L1 pre-computation logic."
        )

    result = LayerFourBResult(
        candidates=tuple(all_candidates),
        n_hypotheses_attempted=n_attempted,
        n_symbols=len({g[0] for g in groups}),
        n_setups=len({g[1] for g in groups}),
        warnings=tuple(warnings),
        ran_at=ran_at,
    )
    if output_dir is not None:
        _write_outputs(result, Path(output_dir))
    return result


# ─── Grouping ────────────────────────────────────────────────────

def _split_groups(df: pd.DataFrame) -> list[tuple[str, str, pd.DataFrame]]:
    if "symbol" not in df.columns:
        if "setupType" in df.columns:
            return [
                ("ALL", str(st), df[df["setupType"] == st].reset_index(drop=True))
                for st in df["setupType"].dropna().unique()
                if st not in ("NONE", "")
            ]
        return [("ALL", "ALL", df)]
    out = []
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
    cfg: RegimeBlockConfig,
) -> tuple[list[RegimeBlockCandidate], int]:
    n = len(df)
    gap = max(1, int(n * cfg.gap_ratio))
    fold_size = n // (cfg.outer_folds + 1)
    if fold_size < cfg.min_train_samples:
        return [], 0

    profits_all = df["_profit"].values.astype(float)
    regime_arr = df["regimeName"].values
    session_arr = df["_session"].values
    failure_arr = (
        df["auctFailure"].fillna(0).values.astype(float)
        if "auctFailure" in df.columns
        else np.zeros(n)
    )
    lt_arr = df["_ltBin"].values
    setup_arr = np.full(n, setup)

    hypotheses = _enumerate_hypotheses(df, setup, cfg)
    n_attempted = len(hypotheses)

    # fold results per hypothesis key
    fold_results: dict[str, list[dict]] = defaultdict(list)

    for i in range(cfg.outer_folds):
        te = fold_size * (i + 1)
        vs = te + gap
        ve = min(vs + fold_size, n)
        if ve - vs < cfg.min_val_samples:
            continue

        val_profits = profits_all[vs:ve]
        val_regime = regime_arr[vs:ve]
        val_session = session_arr[vs:ve]
        val_failure = failure_arr[vs:ve]
        val_lt = lt_arr[vs:ve]
        val_setup = setup_arr[vs:ve]

        # Discover candidate block rules from train
        train_candidates = _discover_train_blocks(
            profits_all[:te], regime_arr[:te], session_arr[:te],
            failure_arr[:te], lt_arr[:te], setup_arr[:te],
            setup, cfg,
        )

        # Validate on val
        for rule in train_candidates:
            mask = _apply_block_mask(
                val_setup, val_regime, val_session, val_failure, val_lt, rule,
            )
            nb = int(mask.sum())
            np_ = int((~mask).sum())
            if nb < cfg.min_block_samples or np_ < cfg.min_pass_samples:
                continue

            blocked_ev = float(val_profits[mask].mean())
            pass_ev = float(val_profits[~mask].mean())
            lift = pass_ev - blocked_ev
            if blocked_ev >= 0 or lift < cfg.min_ev_improvement:
                continue
            wr_blocked = float((val_profits[mask] > 0).mean())
            wr_pass = float((val_profits[~mask] > 0).mean())
            if (wr_blocked - wr_pass) > -cfg.min_wr_improvement:
                continue

            perm_p = _perm_test_block(val_profits, nb, blocked_ev, cfg)
            if perm_p >= 0.05:
                continue

            fold_results[rule["key"]].append({
                "fold": i,
                "blocked_ev": blocked_ev,
                "pass_ev": pass_ev,
                "lift": lift,
                "wr_blocked": wr_blocked,
                "n_blocked": nb,
                "perm_p": perm_p,
                "rule_type": rule["type"],
                "condition": rule["condition"],
            })

    # Aggregate across folds
    candidates: list[RegimeBlockCandidate] = []
    for key, folds in fold_results.items():
        if len(folds) < 2:
            continue
        lifts = [f["lift"] for f in folds]
        blocked_evs = [f["blocked_ev"] for f in folds]

        positive_folds = sum(1 for lt in lifts if lt > 0)
        fold_consistency = positive_folds / len(folds)
        if fold_consistency < cfg.fold_consistency_threshold:
            continue

        mean_lift = float(np.mean(lifts))
        if mean_lift < cfg.min_ev_improvement:
            continue

        # Temporal slope of lift
        if len(lifts) >= 4:
            slope, _, _, p2, _ = stats.linregress(
                np.arange(len(lifts)), np.array(lifts),
            )
            slope_p = float(p2 / 2) if slope < 0 else 1.0
        else:
            slope_p = 1.0

        # Fisher's combined p across fold permutation p-values
        ps = [max(f["perm_p"], 1e-10) for f in folds]
        combined_p = float(
            1 - stats.chi2.cdf(-2 * np.sum(np.log(ps)), 2 * len(ps))
        )

        first = folds[0]
        candidates.append(RegimeBlockCandidate(
            symbol=symbol,
            setup=setup,
            rule_type=first["rule_type"],
            condition=first["condition"],
            mean_blocked_ev=float(np.mean(blocked_evs)),
            mean_pass_ev=float(np.mean([f["pass_ev"] for f in folds])),
            mean_lift=mean_lift,
            mean_wr_blocked=float(np.mean([f["wr_blocked"] for f in folds])),
            mean_n_blocked=int(np.mean([f["n_blocked"] for f in folds])),
            n_folds=len(folds),
            fold_consistency=fold_consistency,
            combined_p=combined_p,
            temporal_slope_p=slope_p,
            fold_details=tuple(folds),
        ))

    candidates.sort(key=lambda c: c.mean_blocked_ev)  # most negative first
    return candidates[: cfg.max_candidates_per_symbol], n_attempted


# ─── Hypothesis enumeration ──────────────────────────────────────

def _enumerate_hypotheses(
    df: pd.DataFrame, setup: str, cfg: RegimeBlockConfig,
) -> list[dict]:
    hyp: list[dict] = []
    regimes = sorted(df["regimeName"].dropna().unique()) if "regimeName" in df.columns else []
    sessions = sorted(df["_session"].dropna().unique()) if "_session" in df.columns else []
    lt_bins = sorted(df["_ltBin"].dropna().unique()) if "_ltBin" in df.columns else []

    for r in regimes:
        hyp.append({
            "type": "auction_regime", "condition": r,
            "key": f"{setup}|regime|{r}",
        })
    if "auctFailure" in df.columns:
        hyp.append({
            "type": "auction_failure", "condition": "auctFailure>0.5",
            "key": f"{setup}|failure",
        })
    for r in regimes:
        for s in sessions:
            hyp.append({
                "type": "regime_session", "condition": f"{r}+{s}",
                "key": f"{setup}|regime_sess|{r}+{s}",
            })
    for r in regimes:
        for lt in lt_bins:
            hyp.append({
                "type": "regime_lt_transition", "condition": f"{r}+{lt}",
                "key": f"{setup}|regime_lt|{r}+{lt}",
            })
    return hyp


def _discover_train_blocks(
    profits: np.ndarray,
    regime_arr: np.ndarray,
    session_arr: np.ndarray,
    failure_arr: np.ndarray,
    lt_arr: np.ndarray,
    setup_arr: np.ndarray,
    setup: str,
    cfg: RegimeBlockConfig,
) -> list[dict]:
    """Find candidate block rules from training data (negative EV)."""
    hyp_list: list[dict] = []
    setup_mask = setup_arr == setup
    regimes = np.unique(regime_arr[(regime_arr != "UNKNOWN") & setup_mask])
    sessions = np.unique(session_arr[setup_mask])
    lt_bins = np.unique(lt_arr[setup_mask])

    # auction_regime
    for r in regimes:
        mask = setup_mask & (regime_arr == r)
        if mask.sum() < cfg.min_train_samples:
            continue
        if (profits[mask].mean() < -cfg.min_ev_improvement
                and (profits[mask] > 0).mean() < 0.35):
            hyp_list.append({
                "type": "auction_regime", "condition": r,
                "key": f"{setup}|regime|{r}",
            })

    # auction_failure
    fail_m = setup_mask & (failure_arr > 0.5)
    if fail_m.sum() >= cfg.min_train_samples:
        if profits[fail_m].mean() < -cfg.min_ev_improvement:
            hyp_list.append({
                "type": "auction_failure", "condition": "auctFailure>0.5",
                "key": f"{setup}|failure",
            })

    # regime × session
    for r in regimes:
        for s in sessions:
            mask = setup_mask & (regime_arr == r) & (session_arr == s)
            if mask.sum() < cfg.min_train_samples:
                continue
            if (profits[mask].mean() < -cfg.min_ev_improvement
                    and (profits[mask] > 0).mean() < 0.30):
                hyp_list.append({
                    "type": "regime_session", "condition": f"{r}+{s}",
                    "key": f"{setup}|regime_sess|{r}+{s}",
                })

    # regime × lt_transition
    for r in regimes:
        for lt in lt_bins:
            mask = setup_mask & (regime_arr == r) & (lt_arr == lt)
            if mask.sum() < cfg.min_train_samples:
                continue
            if (profits[mask].mean() < -cfg.min_ev_improvement
                    and (profits[mask] > 0).mean() < 0.30):
                hyp_list.append({
                    "type": "regime_lt_transition", "condition": f"{r}+{lt}",
                    "key": f"{setup}|regime_lt|{r}+{lt}",
                })

    return hyp_list


def _apply_block_mask(
    setup_arr: np.ndarray,
    regime_arr: np.ndarray,
    session_arr: np.ndarray,
    failure_arr: np.ndarray,
    lt_arr: np.ndarray,
    rule: dict,
) -> np.ndarray:
    t = rule["type"]
    c = rule["condition"]
    if t == "auction_regime":
        return regime_arr == c
    if t == "auction_failure":
        return failure_arr > 0.5
    if t == "regime_session":
        r, s = c.split("+", 1)
        return (regime_arr == r) & (session_arr == s)
    if t == "regime_lt_transition":
        r, lt = c.split("+", 1)
        return (regime_arr == r) & (lt_arr == lt)
    return np.zeros(len(setup_arr), dtype=bool)


# ─── Permutation test ────────────────────────────────────────────

def _perm_test_block(
    profits: np.ndarray,
    n_blocked: int,
    observed_mean: float,
    cfg: RegimeBlockConfig,
) -> float:
    """One-sided permutation test: is blocked EV truly negative?

    H0: blocked group is random sample. Count how often null blocked_ev
    is <= observed (i.e. as negative or more negative). Small p means
    the observed negative EV is unlikely under the null.
    """
    arr = profits.copy()
    rng = np.random.default_rng(cfg.seed)
    count = 0
    for _ in range(cfg.perm_iterations):
        rng.shuffle(arr)
        null_mean = float(arr[:n_blocked].mean())
        if null_mean <= observed_mean:  # null is as negative as observed
            count += 1
    return (count + 1) / (cfg.perm_iterations + 1)


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerFourBResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    if result.candidates:
        pd.DataFrame([c.to_dict() for c in result.candidates]).to_csv(
            output_dir / "regime_block_candidates.csv", index=False,
        )
    with (output_dir / "regime_block_discovery_summary.json").open(
        "w", encoding="utf-8",
    ) as fh:
        json.dump(result.summary_dict(), fh, indent=2, default=str)
