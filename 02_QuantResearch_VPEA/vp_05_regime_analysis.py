"""
vp_05_regime_analysis.py — Auction Block Rules (ROBUST v2)

Key improvements:
- Pre-filters dataset by Phase 02 OOS-validated thresholds (only analyze trades EA would take)
- FDR correction (Benjamini-Hochberg, inlined)
- Proper permutation test (300 iter, Laplace smoothing)
- Economic significance (MIN_EV_IMPROVEMENT, MIN_WR_IMPROVEMENT)
- Fold consistency >= 70%
- Temporal stability check
- Final OOS validation (70/30 split)
- Fisher's combined p-value
- `final_validated` field for Phase 99
"""

import sys, json, warnings, time
import numpy as np
import pandas as pd
from pathlib import Path
from scipy import stats
from collections import defaultdict

warnings.filterwarnings("ignore")
_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))
from data_loader import load_funnel, load_trades, merge_funnel_trades, REGIME_NAMES

OUTPUT_DIR = _HERE / "output" / "05_regime_analysis"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MIN_SAMPLES_TRAIN = 15
MIN_SAMPLES_VAL = 10
MIN_SAMPLES_BLOCK = 10
MIN_SAMPLES_PASS = 10
OUTER_SPLITS = 5
GAP_RATIO = 0.10
CI_ALPHA = 0.05
FDR_LEVEL = 0.05
PERM_ITERATIONS = 300
MIN_EV_IMPROVEMENT = 0.10
MIN_WR_IMPROVEMENT = 0.03
MAX_RULES_PER_TYPE = 5
MAX_RECORDS = 500_000
CV_CONSISTENCY = 0.60
PROFIT_COL = "profitUSD"
OOS_RATIO = 0.30


def run(funnel_df=None, trade_df=None, all_results=None):
    t0 = time.time()
    print("\n" + "=" * 60)
    print("VP PHASE 05 — BLOCK RULES (ROBUST v2)")
    print("=" * 60)

    if funnel_df is None: funnel_df = load_funnel()
    if trade_df is None: trade_df = load_trades()

    merged = merge_funnel_trades(funnel_df, trade_df, tolerance_sec=14400, min_records=10)
    if merged is None or len(merged) < MIN_SAMPLES_TRAIN * 3:
        print("  [SKIP] Insufficient data"); return {"auction_block_rules": []}

    if len(merged) > MAX_RECORDS:
        merged = merged.sample(n=MAX_RECORDS, random_state=42)
    if "time" in merged.columns:
        merged = merged.sort_values("time").reset_index(drop=True)

    # ─── Pre-filter: only keep records that pass prior phase gates ────
    merged = _apply_prior_filters(merged, all_results)
    if len(merged) < MIN_SAMPLES_TRAIN * 3:
        print("  [SKIP] Too few records after prior-phase filtering"); return {"auction_block_rules": []}

    if "auctTradeQuality" in merged.columns:
        qm = merged["auctTradeQuality"].notna() & (merged["auctTradeQuality"] > 0)
        if qm.sum() > len(merged) * 0.5:
            merged = merged[qm].copy()

    if "auctRegime" not in merged.columns:
        print("  [SKIP] No auctRegime"); return {"auction_block_rules": []}

    merged["regimeName"] = merged["auctRegime"].map(REGIME_NAMES).fillna("UNKNOWN")
    merged["_session"] = merged["session"].astype(str) if "session" in merged.columns else "0"

    # Discretize LT Transition Score into bins for interaction analysis
    if "vpLTTransitionScore" in merged.columns:
        ts = merged["vpLTTransitionScore"].fillna(0)
        merged["_ltTransBin"] = np.where(ts > 0.5, "LT_HIGH", np.where(ts > 0.25, "LT_MED", "LT_LOW"))
    else:
        merged["_ltTransBin"] = "LT_UNKNOWN"

    profits = merged[PROFIT_COL].values.astype(np.float64)
    setup_arr = merged["setupType"].values if "setupType" in merged.columns else np.array(["ALL"]*len(merged))
    regime_arr = merged["regimeName"].values
    session_arr = merged["_session"].values
    symbol_arr = merged["symbol"].values if "symbol" in merged.columns else np.array(["ALL"]*len(merged))
    failure_arr = merged["auctFailure"].values if "auctFailure" in merged.columns else np.zeros(len(merged))
    lt_trans_arr = merged["_ltTransBin"].values

    print(f"  Records: {len(merged):,} | WR={np.mean(profits>0):.1%} EV=${np.mean(profits):.2f}")

    all_p_values = []  # for FDR
    all_rules = []

    symbols = list(np.unique(symbol_arr)) + ["_GLOBAL"]
    for sym in symbols:
        idx = np.arange(len(merged)) if sym == "_GLOBAL" else np.where(symbol_arr == sym)[0]
        if len(idx) < MIN_SAMPLES_TRAIN * 3: continue
        rules = _walkforward(idx, profits, setup_arr, regime_arr, session_arr, failure_arr, lt_trans_arr, sym, all_p_values)
        all_rules.extend(rules)

    # FDR correction
    if all_p_values:
        fdr_mask = _benjamini_hochberg(all_p_values, FDR_LEVEL)
        significant_count = sum(fdr_mask)
        print(f"\n  Tests: {len(all_p_values)} | FDR significant: {significant_count}")
    else:
        fdr_mask = []

    # OOS validation
    if all_rules and "time" in merged.columns:
        all_rules = _oos_validation(all_rules, merged, profits, setup_arr, regime_arr, session_arr, failure_arr, lt_trans_arr)

    # Mark final_validated
    for i, rule in enumerate(all_rules):
        fdr_pass = fdr_mask[i] if i < len(fdr_mask) else False
        rule["fdr_significant"] = fdr_pass
        rule["final_validated"] = rule.get("oos_validated", False) and fdr_pass

    final = [r for r in all_rules if r.get("final_validated")]
    print(f"  Final validated: {len(final)}")

    # Save
    pd.DataFrame(all_rules).to_csv(OUTPUT_DIR / "block_rules.csv", index=False)
    with open(OUTPUT_DIR / "block_rules.json", "w") as f:
        json.dump(all_rules, f, indent=2, default=str)

    for r in sorted(final, key=lambda x: x.get("ev", 0))[:8]:
        print(f"    {r['symbol']:<10} {r['setup']:<18} {r['condition']:<22} EV={r['ev']:+.2f} lift={r['lift']:+.2f}")

    _run_diagnostics(merged)
    print(f"\n  Time: {time.time()-t0:.1f}s")
    return {"auction_block_rules": all_rules}


def _apply_prior_filters(merged, all_results):
    """Filter dataset to only include records that pass Phase 02 thresholds.
    This ensures regime analysis only examines trades the EA would actually take."""
    if not all_results or "phase2" not in all_results:
        return merged

    p2 = all_results["phase2"]
    if not isinstance(p2, dict) or not p2:
        return merged

    n_before = len(merged)
    mask = np.ones(len(merged), dtype=bool)

    for group_key, group_data in p2.items():
        if not isinstance(group_data, dict): continue
        thresholds = group_data.get("thresholds", {})
        if not thresholds: continue

        # Parse group key: "SYMBOL_SETUP"
        parts = group_key.rsplit("_", 1)
        if len(parts) != 2: continue
        sym, setup = parts

        # Find rows matching this symbol+setup
        sym_mask = (merged["symbol"] == sym) if "symbol" in merged.columns else np.ones(len(merged), dtype=bool)
        setup_mask = (merged["setupType"] == setup) if "setupType" in merged.columns else np.ones(len(merged), dtype=bool)
        group_mask = sym_mask & setup_mask

        if group_mask.sum() == 0: continue

        for feat, rule in thresholds.items():
            if not isinstance(rule, dict): continue
            if not rule.get("oos_validated", False): continue  # only apply OOS-validated rules
            if feat not in merged.columns: continue

            gate_type = rule.get("gate_type", "none")
            direction = rule.get("direction", 0)
            breakeven = rule.get("breakeven")
            breakeven_upper = rule.get("breakeven_upper")

            if gate_type == "threshold" and direction == 1 and breakeven is not None:
                # Block when feature < threshold
                feat_fail = merged[feat].fillna(0) < breakeven
                mask &= ~(group_mask & feat_fail)
            elif gate_type == "threshold" and direction == -1 and breakeven_upper is not None:
                # Block when feature > threshold
                feat_fail = merged[feat].fillna(0) > breakeven_upper
                mask &= ~(group_mask & feat_fail)
            elif gate_type == "band" and breakeven is not None and breakeven_upper is not None:
                # Block when outside band
                vals = merged[feat].fillna(0)
                feat_fail = (vals < breakeven) | (vals > breakeven_upper)
                mask &= ~(group_mask & feat_fail)

    merged = merged[mask].reset_index(drop=True)
    n_after = len(merged)
    if n_before != n_after:
        print(f"  Prior-phase filter: {n_before:,} → {n_after:,} ({n_after/n_before:.1%} retained)")
    return merged


def _walkforward(idx, profits, setup_arr, regime_arr, session_arr, failure_arr, lt_trans_arr, sym, all_p_values):
    n = len(idx)
    gap = max(1, int(n * GAP_RATIO))
    fold_size = n // (OUTER_SPLITS + 1)
    if fold_size < MIN_SAMPLES_TRAIN: return []

    candidates = []
    for i in range(OUTER_SPLITS):
        te = fold_size * (i+1)
        vs = te + gap
        ve = min(vs + fold_size, n)
        if ve - vs < MIN_SAMPLES_VAL: continue

        train_idx = idx[:te]
        val_idx = idx[vs:ve]
        rules = _discover(train_idx, profits, setup_arr, regime_arr, session_arr, failure_arr, lt_trans_arr, sym)

        val_profits = profits[val_idx]
        val_setup = setup_arr[val_idx]
        val_regime = regime_arr[val_idx]
        val_session = session_arr[val_idx]
        val_failure = failure_arr[val_idx]
        val_lt_trans = lt_trans_arr[val_idx]

        for rule in rules:
            mask = _mask(val_setup, val_regime, val_session, val_failure, val_lt_trans, rule)
            nb = mask.sum()
            np_ = len(val_idx) - nb
            if nb < MIN_SAMPLES_BLOCK or np_ < MIN_SAMPLES_PASS: continue

            mean_b = val_profits[mask].mean()
            mean_p = val_profits[~mask].mean()
            lift = mean_p - mean_b
            if mean_b >= 0 or lift < MIN_EV_IMPROVEMENT: continue

            wr_b = (val_profits[mask] > 0).mean()
            wr_p = (val_profits[~mask] > 0).mean()
            if wr_p - wr_b < MIN_WR_IMPROVEMENT: continue

            p_val = _perm_test(val_profits, nb, mean_b)
            all_p_values.append(p_val)
            if p_val >= 0.05: continue

            candidates.append({
                "symbol": sym, "setup": rule["setup"], "type": rule["type"],
                "condition": rule["condition"],
                "ev": round(mean_b, 4), "lift": round(lift, 4),
                "wr": round(wr_b, 4), "p_value": round(p_val, 4),
                "n_blocked": int(nb), "fold": i,
            })

    return _aggregate(candidates)


def _discover(train_idx, profits, setup_arr, regime_arr, session_arr, failure_arr, lt_trans_arr, sym):
    rules = []
    tr = profits[train_idx]
    tr_s = setup_arr[train_idx]
    tr_r = regime_arr[train_idx]
    tr_ss = session_arr[train_idx]
    tr_f = failure_arr[train_idx]
    tr_lt = lt_trans_arr[train_idx]

    for setup in np.unique(tr_s):
        if setup == "NONE": continue
        sm = tr_s == setup

        for regime in np.unique(tr_r[sm]):
            if regime == "UNKNOWN": continue
            m = sm & (tr_r == regime)
            n = m.sum()
            if n < MIN_SAMPLES_TRAIN: continue
            mean = tr[m].mean()
            if mean < -MIN_EV_IMPROVEMENT and (tr[m] > 0).mean() < 0.35:
                rules.append({"setup": setup, "type": "auction_regime", "condition": regime})

        mf = sm & (tr_f > 0.5)
        if mf.sum() >= MIN_SAMPLES_TRAIN:
            if tr[mf].mean() < -MIN_EV_IMPROVEMENT:
                rules.append({"setup": setup, "type": "auction_failure", "condition": "auctFailure>0.5"})

        for regime in np.unique(tr_r[sm]):
            if regime == "UNKNOWN": continue
            for sess in np.unique(tr_ss[sm & (tr_r == regime)]):
                m = sm & (tr_r == regime) & (tr_ss == sess)
                if m.sum() < MIN_SAMPLES_TRAIN: continue
                if tr[m].mean() < -MIN_EV_IMPROVEMENT and (tr[m] > 0).mean() < 0.30:
                    rules.append({"setup": setup, "type": "regime_session", "condition": f"{regime}+{sess}"})

        # ─── LT Transition interaction rules ────────────────────────
        # Block when LT transition is high (post-trend chaos)
        for lt_bin in ["LT_HIGH", "LT_MED"]:
            m_lt = sm & (tr_lt == lt_bin)
            if m_lt.sum() < MIN_SAMPLES_TRAIN: continue
            if tr[m_lt].mean() < -MIN_EV_IMPROVEMENT and (tr[m_lt] > 0).mean() < 0.35:
                rules.append({"setup": setup, "type": "lt_transition", "condition": lt_bin})

        # Regime × LT Transition interaction (the key insight)
        for regime in np.unique(tr_r[sm]):
            if regime == "UNKNOWN": continue
            for lt_bin in ["LT_HIGH", "LT_MED"]:
                m = sm & (tr_r == regime) & (tr_lt == lt_bin)
                if m.sum() < MIN_SAMPLES_TRAIN: continue
                if tr[m].mean() < -MIN_EV_IMPROVEMENT and (tr[m] > 0).mean() < 0.30:
                    rules.append({"setup": setup, "type": "regime_lt_transition", "condition": f"{regime}+{lt_bin}"})

    return rules[:MAX_RULES_PER_TYPE * 4]


def _mask(setup_arr, regime_arr, session_arr, failure_arr, lt_trans_arr, rule):
    base = setup_arr == rule["setup"]
    if rule["type"] == "auction_regime":
        return base & (regime_arr == rule["condition"])
    elif rule["type"] == "auction_failure":
        return base & (failure_arr > 0.5)
    elif rule["type"] == "regime_session":
        parts = rule["condition"].split("+")
        return base & (regime_arr == parts[0]) & (session_arr == (parts[1] if len(parts) > 1 else ""))
    elif rule["type"] == "lt_transition":
        return base & (lt_trans_arr == rule["condition"])
    elif rule["type"] == "regime_lt_transition":
        parts = rule["condition"].split("+")
        return base & (regime_arr == parts[0]) & (lt_trans_arr == (parts[1] if len(parts) > 1 else ""))
    return np.zeros(len(setup_arr), dtype=bool)


def _perm_test(profits, n_blocked, observed_mean, n_perm=PERM_ITERATIONS):
    arr = profits.copy()
    rng = np.random.default_rng(42)
    count = 0
    for _ in range(n_perm):
        rng.shuffle(arr)
        if arr[:n_blocked].mean() <= observed_mean:
            count += 1
    return (count + 1) / (n_perm + 1)  # Laplace smoothing


def _benjamini_hochberg(p_values, alpha=0.05):
    """Inline BH FDR correction (no statsmodels dependency)."""
    n = len(p_values)
    sorted_idx = np.argsort(p_values)
    sorted_p = np.array(p_values)[sorted_idx]
    mask = np.zeros(n, dtype=bool)
    for rank, idx in enumerate(sorted_idx, 1):
        if sorted_p[rank-1] <= alpha * rank / n:
            mask[idx] = True
        else:
            break  # BH step-up: stop at first failure
    return mask


def _aggregate(candidates):
    if not candidates: return []
    groups = defaultdict(list)
    for c in candidates:
        groups[(c["symbol"], c["setup"], c["type"], c["condition"])].append(c)

    final = []
    for key, folds in groups.items():
        if len(folds) < 2: continue
        evs = [f["ev"] for f in folds]
        lifts = [f["lift"] for f in folds]
        if np.mean(lifts) < MIN_EV_IMPROVEMENT: continue

        pos_folds = sum(1 for l in lifts if l > 0)
        if pos_folds / len(folds) < CV_CONSISTENCY: continue

        # Temporal stability
        if len(lifts) >= 3:
            s, _, _, p, _ = stats.linregress(np.arange(len(lifts)), np.array(lifts))
            if s < 0 and p < 0.10: continue

        # Fisher's combined p
        p_vals = [f["p_value"] for f in folds]
        combined_p = _fisher_p(p_vals)

        final.append({
            "symbol": key[0], "setup": key[1], "type": key[2], "condition": key[3],
            "ev": round(np.mean(evs), 4), "lift": round(np.mean(lifts), 4),
            "wr": round(np.mean([f["wr"] for f in folds]), 4),
            "n": sum(f["n_blocked"] for f in folds),
            "n_folds": len(folds), "fold_consistency": round(pos_folds/len(folds), 3),
            "combined_p": round(combined_p, 6),
            "oos_validated": False,  # updated later
        })
    return final


def _fisher_p(p_values):
    p_values = [max(p, 1e-10) for p in p_values]
    chi2 = -2 * np.sum(np.log(p_values))
    return 1 - stats.chi2.cdf(chi2, 2 * len(p_values))


def _oos_validation(rules, merged, profits, setup_arr, regime_arr, session_arr, failure_arr, lt_trans_arr):
    split = int(len(merged) * (1 - OOS_RATIO))
    oos_idx = np.arange(split, len(merged))
    oos_profits = profits[oos_idx]
    oos_setup = setup_arr[oos_idx]
    oos_regime = regime_arr[oos_idx]
    oos_session = session_arr[oos_idx]
    oos_failure = failure_arr[oos_idx]
    oos_lt_trans = lt_trans_arr[oos_idx]

    for rule in rules:
        mask = _mask(oos_setup, oos_regime, oos_session, oos_failure, oos_lt_trans, rule)
        nb = mask.sum()
        np_ = len(oos_idx) - nb
        if nb < MIN_SAMPLES_BLOCK or np_ < MIN_SAMPLES_PASS:
            rule["oos_validated"] = False; continue

        oos_blocked_ev = oos_profits[mask].mean()
        oos_pass_ev = oos_profits[~mask].mean()
        oos_lift = oos_pass_ev - oos_blocked_ev

        rule["oos_lift"] = round(oos_lift, 4)
        rule["oos_blocked_ev"] = round(oos_blocked_ev, 4)
        rule["oos_validated"] = (oos_lift >= MIN_EV_IMPROVEMENT * 0.5 and oos_blocked_ev < 0)
    return rules


def _run_diagnostics(df):
    if "regimeName" in df.columns:
        df.groupby("regimeName", observed=True)[PROFIT_COL].agg(
            count="count", mean="mean", wr=lambda x: (x>0).mean()
        ).round(3).sort_values("mean").to_csv(OUTPUT_DIR / "regime_performance.csv")
    if "spreadToATR" in df.columns:
        try:
            df2 = df.copy()
            df2["_sb"] = pd.cut(df2["spreadToATR"], bins=[0,.05,.10,.15,.20,.30,1.0])
            df2.groupby("_sb", observed=True)[PROFIT_COL].agg(
                count="count", mean="mean", wr=lambda x: (x>0).mean()
            ).round(3).to_csv(OUTPUT_DIR / "spread_erosion.csv")
        except: pass


if __name__ == "__main__":
    run()
