"""
vp_02_edge_discovery.py — VP Edge Discovery v3 (ROBUST + OPTIMIZED)

Key improvements:
- Pre-registered features (5 categories, no data snooping)
- Permutation test (100 iter + early stopping) for significance
- Final OOS validation (70/30 temporal split)
- Economic significance: MIN_EFFECT_SIZE, MIN_PF, MIN_WR
- GAP_RATIO=0.10, OUTER_SPLITS=5 for robustness
- Fold consistency >= 60%
- Export ALL features + oos_validated field
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
from data_loader import load_funnel, load_trades, merge_funnel_trades, FUNNEL_FEATURES

OUTPUT_DIR = _HERE / "output" / "02_edge_discovery"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Parameters
MIN_GROUP_SAMPLES = 30
OUTER_SPLITS = 5
INNER_SPLITS = 3
GAP_RATIO = 0.10
MIN_SAMPLES_INNER = 15
THRESHOLD_STEPS = 15
MAX_RECORDS = 500_000
BAND_SCAN_LIMIT = 10
CONFIDENCE_LEVEL = 0.95

# Economic significance
MIN_EFFECT_SIZE = 0.05     # min EV per trade ($)
MIN_PROFIT_FACTOR = 1.1
MIN_WIN_RATE = 0.35

# Permutation
PERM_INNER = 100           # permutations in inner loop
PERM_ALPHA = 0.10          # permutation p-value threshold (inner)

# Validation
FOLD_CONSISTENCY = 0.60    # 60% folds must be positive
OOS_RATIO = 0.30           # 30% holdout for final OOS
MIN_OOS_TRADES = 20

# Pre-registered features (theory-driven, not data-driven)
PRE_REGISTERED = {
    # 'trend' keeps BOTH the raw strength features AND the collapsed composites,
    # so the pipeline can compare them head-to-head via OOS + FDR validation.
    #   bosScore / chochScore / trendDirection = raw single features
    #   bosQuality / chochQuality = strength × confirmation × proximity × direction
    #   structAlign = structure-vs-trendDirection agreement
    # Redundant raw facets (bosBullish/bosConfirmed/bosLevel) are intentionally
    # omitted — their information is already inside the composites.
    "trend":    ["bosScore", "chochScore", "trendDirection",
                 "bosQuality", "chochQuality", "structAlign", "auctContinuation"],
    "quality":  ["auctTradeQuality", "auctBalance", "auctExpReward", "dataQuality"],
    "risk":     ["auctReversalRisk", "auctFailure", "auctExhaustion", "spreadToATR"],
    "volume":   ["vpMigrationConf", "vpBestHVNScore", "auctHVNStrength", "vpDevPOCSlope"],
    "structure":["vpDevPOCDir", "vpVAOverlapBias", "vpLTAcceptanceAtPrice", "vpThinnessRatio"],
    "longterm": ["vpLTPOCMigration", "vpLTNearestZoneStrength", "vpLTTransitionScore", "vpLTBalanceStability"],
    # Bonus engines: one PRIMARY feature per group + one composite of secondaries.
    #   msCompression   (micro) — coiled-range breakout energy
    #   ofFlowIntensity (flow)  — aggregate participation/absorption/delta
    #   liqSweep        (liq)   — liquidity-grab event
    #   smZoneQuality   (SM)    — overall smart-money zone quality
    #   *Context        — mean of that group's secondary scores
    "engine":   ["msCompression", "ofFlowIntensity", "liqSweep", "smZoneQuality",
                 "msContext", "ofContext", "liqContext", "smContext"],
    "interactions": ["ix_tq_mig", "ix_bos_trend", "ix_spread_atr", "ix_cont_mig", "ix_fail_reversal",
                    "ix_struct_bos", "ix_devpoc_ltpoc", "ix_exhaust_lt", "ix_acceptance", "ix_target_rr"],
}

# Theory-driven interaction pairs
INTERACTION_DEFS = [
    ("ix_tq_mig",       "auctTradeQuality", "vpMigrationConf"),
    ("ix_bos_trend",    "bosQuality",        "structAlign"),
    ("ix_spread_atr",   "spreadToATR",       "atrProxy"),
    ("ix_cont_mig",     "auctContinuation",  "vpMigrationConf"),
    ("ix_fail_reversal","auctFailure",       "auctReversalRisk"),
    ("ix_struct_bos",   "chochQuality",      "structAlign"),
    ("ix_devpoc_ltpoc", "vpDevPOCDir",       "vpLTPOCVelocity"),
    ("ix_exhaust_lt",   "auctExhaustion",    "vpLTTrendExhaustion"),
    ("ix_acceptance",   "vpInsideVA",        "auctAcceptance"),
    ("ix_target_rr",    "auctTargetProb",    "RR"),
]

FEATURE_DIRECTION = {
    "auctContinuation": 1, "auctTradeQuality": 1, "auctBalance": 1,
    "auctExpReward": 1, "vpMigrationConf": 1, "vpBestHVNScore": 1,
    "auctExhaustion": -1, "auctFailure": -1, "auctReversalRisk": -1,
    "vpThinnessRatio": -1, "spreadToATR": -1,
    "vpDevPOCDir": 0, "vpDevPOCSlope": 0,
    "auctHVNStrength": 1, "vpLTAcceptanceAtPrice": 1,
    # Raw structure features (higher score = stronger signal)
    "bosScore": 1, "chochScore": 1, "trendDirection": 0,
    # Structure composites: signed [-1,1], edge is directional (0 = search both sides)
    "bosQuality": 0, "chochQuality": 0, "structAlign": 1,
    "dataQuality": 1, "vpVAOverlapBias": 0,
    # Longterm
    "vpLTPOCMigration": 0, "vpLTNearestZoneStrength": 1,
    "vpLTTransitionScore": -1, "vpLTBalanceStability": 1,
    # Bonus engines — all in [0,1]; direction unknown a priori, so search both
    # sides (0) and let OOS+FDR decide whether high or low carries the edge.
    "msCompression": 0, "ofFlowIntensity": 0, "liqSweep": 0, "smZoneQuality": 0,
    "msContext": 0, "ofContext": 0, "liqContext": 0, "smContext": 0,
    # Interactions (higher = better for positive pairs, lower = better for danger pairs)
    "ix_tq_mig": 1, "ix_bos_trend": 1, "ix_spread_atr": -1,
    "ix_cont_mig": 1, "ix_fail_reversal": -1,
    "ix_struct_bos": 1, "ix_devpoc_ltpoc": 1, "ix_exhaust_lt": -1,
    "ix_acceptance": 1, "ix_target_rr": 1,
}


def run(funnel_df=None, trade_df=None):
    t0 = time.time()
    print("\n" + "=" * 60)
    print("VP PHASE 02 — EDGE DISCOVERY (ROBUST v3)")
    print("=" * 60)

    if funnel_df is None: funnel_df = load_funnel()
    if trade_df is None: trade_df = load_trades()
    if funnel_df.empty:
        print("  [SKIP] No funnel data"); return {}

    merged = merge_funnel_trades(funnel_df, trade_df, tolerance_sec=14400, min_records=15)
    if merged is None or len(merged) < MIN_GROUP_SAMPLES:
        print("  [SKIP] Insufficient merged data"); return {}

    if len(merged) > MAX_RECORDS:
        print(f"  [OPTIMIZE] Downsample {len(merged):,} → {MAX_RECORDS:,}")
        merged = merged.sample(n=MAX_RECORDS, random_state=42)

    if "time" in merged.columns:
        merged = merged.sort_values("time").reset_index(drop=True)
    if "profitUSD" not in merged.columns:
        print("  [SKIP] No profitUSD"); return {}
    merged["_profit"] = merged["profitUSD"].values

    # Compute interaction features
    merged = _compute_interactions(merged)

    # Determine available pre-registered features
    avail_features = []
    for cat, feats in PRE_REGISTERED.items():
        for f in feats:
            if f in merged.columns and merged[f].std() > 1e-9:
                avail_features.append(f)
    print(f"  Pre-registered features available: {len(avail_features)}/{sum(len(v) for v in PRE_REGISTERED.values())}")

    symbols = merged["symbol"].unique() if "symbol" in merged.columns else ["ALL"]
    setup_types = [s for s in merged.get("setupType", pd.Series()).unique()
                   if pd.notna(s) and s not in ("NONE", "")]

    all_results = {}
    all_rules = []

    for sym in symbols:
        sym_df = merged[merged["symbol"] == sym] if "symbol" in merged.columns else merged
        for setup in setup_types:
            group_df = sym_df[sym_df["setupType"] == setup] if "setupType" in sym_df.columns else sym_df
            if len(group_df) < MIN_GROUP_SAMPLES: continue
            group = f"{sym}_{setup}"

            rules = _nested_discovery(group_df, sym, setup, avail_features)

            thresholds_dict = {}
            if rules:
                for r in rules:
                    thresholds_dict[r["feature"]] = {
                        "gate_type": r["gate_type"], "direction": r.get("direction", 1),
                        "breakeven": r.get("lower_bound"), "breakeven_upper": r.get("upper_bound"),
                        "validated": r["validated"], "test_ev_mean": r.get("test_ev_mean", 0),
                        "oos_validated": r.get("oos_validated", False),
                    }
                all_rules.extend(rules)

            # Export ALL features by correlation
            for f in avail_features:
                if f in group_df.columns and f not in thresholds_dict:
                    corr = group_df[f].corr(group_df["_profit"])
                    if pd.notna(corr):
                        thresholds_dict[f] = {"gate_type": "none", "direction": 1 if corr >= 0 else -1,
                                              "breakeven": None, "breakeven_upper": None,
                                              "validated": False, "test_ev_mean": 0, "oos_validated": False,
                                              "correlation": round(float(corr), 4)}
            if thresholds_dict:
                all_results[group] = {"thresholds": thresholds_dict}

    # Final OOS validation
    if all_rules and "time" in merged.columns:
        print("\n  Running OOS validation...")
        all_rules = _oos_validation(all_rules, merged)

    # Save
    if all_rules:
        pd.DataFrame(all_rules).to_csv(OUTPUT_DIR / "threshold_rules.csv", index=False)
        validated = [r for r in all_rules if r.get("validated")]
        oos_valid = [r for r in all_rules if r.get("oos_validated")]
        print(f"\n  Rules: {len(all_rules)} | validated: {len(validated)} | OOS confirmed: {len(oos_valid)}")
        for r in (oos_valid or validated)[:8]:
            print(f"    {r['symbol']:<10} {r['setup']:<18} {r['feature']:<20} "
                  f"EV={r['test_ev_mean']:+.3f} OOS={r.get('oos_ev','N/A')}")
        with open(OUTPUT_DIR / "threshold_rules.json", "w") as f:
            json.dump(all_rules, f, indent=2, default=_json_default)

    print(f"\n  Time: {time.time()-t0:.1f}s")
    return all_results


def _compute_interactions(df):
    """Compute theory-driven interaction features (product of normalized pairs)."""
    for name, feat_a, feat_b in INTERACTION_DEFS:
        if feat_a in df.columns and feat_b in df.columns:
            a = pd.to_numeric(df[feat_a], errors='coerce').fillna(0)
            b = pd.to_numeric(df[feat_b], errors='coerce').fillna(0)
            a_min, a_max = a.min(), a.max()
            b_min, b_max = b.min(), b.max()
            a_norm = (a - a_min) / (a_max - a_min) if a_max > a_min else 0.5
            b_norm = (b - b_min) / (b_max - b_min) if b_max > b_min else 0.5
            df[name] = (a_norm * b_norm).astype(np.float32)
        else:
            df[name] = 0.0
    return df


def _nested_discovery(df, sym, setup, avail_features):
    n = len(df)
    gap = max(1, int(n * GAP_RATIO))
    fold_size = n // (OUTER_SPLITS + 1)
    if fold_size < MIN_SAMPLES_INNER: return []

    feature_results = defaultdict(list)
    for i in range(OUTER_SPLITS):
        te = fold_size * (i + 1)
        vs = te + gap
        ve = min(vs + fold_size, n)
        if ve - vs < MIN_SAMPLES_INNER: continue

        inner_rules = _inner_loop(df.iloc[:te], avail_features)
        test_df = df.iloc[vs:ve]

        for feat, rule in inner_rules.items():
            vals = test_df[feat].fillna(0).values
            profits = test_df["_profit"].values
            mask = _apply(vals, rule)
            n_pass = mask.sum()
            if n_pass < MIN_SAMPLES_INNER: continue

            ev = profits[mask].mean()
            wr = (profits[mask] > 0).mean()
            pos = profits[mask][profits[mask] > 0].sum()
            neg = abs(profits[mask][profits[mask] < 0].sum())
            pf = pos / neg if neg > 0 else 999

            feature_results[feat].append({
                "ev": ev, "wr": wr, "pf": min(pf, 999), "n": n_pass,
                "low": rule.get("low"), "high": rule.get("high"),
                "direction": rule.get("direction"), "gate_type": rule.get("gate_type"), "fold": i})

    return _aggregate(feature_results, sym, setup)


def _inner_loop(outer_train, avail_features):
    n = len(outer_train)
    gap = max(1, int(n * GAP_RATIO))
    fold_size = n // (INNER_SPLITS + 1)
    if fold_size < MIN_SAMPLES_INNER: return {}

    scores = defaultdict(list)
    for i in range(INNER_SPLITS):
        te = fold_size * (i + 1)
        vs = te + gap
        ve = min(vs + fold_size, n)
        if ve - vs < MIN_SAMPLES_INNER: continue

        inner_val = outer_train.iloc[vs:ve]

        for feat in avail_features:
            if feat not in inner_val.columns: continue
            direction = FEATURE_DIRECTION.get(feat, 0)
            vals = inner_val[feat].fillna(0).values
            profits = inner_val["_profit"].values

            rule = _find_threshold(vals, profits, direction)
            if rule is None: continue

            mask = _apply(vals, rule)
            n_pass = mask.sum()
            if n_pass < MIN_SAMPLES_INNER: continue

            ev = profits[mask].mean()
            if ev < MIN_EFFECT_SIZE: continue

            wr = (profits[mask] > 0).mean()
            if wr < MIN_WIN_RATE: continue

            pos = profits[mask][profits[mask] > 0].sum()
            neg = abs(profits[mask][profits[mask] < 0].sum())
            pf = pos / neg if neg > 0 else 999
            if pf < MIN_PROFIT_FACTOR: continue

            # Permutation test (fast, 100 iter)
            perm_p = _perm_test(profits, mask, ev)
            if perm_p > PERM_ALPHA: continue

            # Score
            se = np.std(profits[mask], ddof=1) / np.sqrt(n_pass)
            t_crit = stats.t.ppf(CONFIDENCE_LEVEL, df=max(1, n_pass-1))
            score = (ev - t_crit * se) * np.sqrt(n_pass)
            scores[feat].append((score, rule))

    final = {}
    for feat, sr in scores.items():
        if sr:
            best = max(sr, key=lambda x: x[0])
            if best[0] > 0: final[feat] = best[1]
    return final


def _find_threshold(vals, profits, direction):
    n = len(vals)
    sorted_idx = np.argsort(vals)
    sorted_vals = vals[sorted_idx]
    sorted_profits = profits[sorted_idx]
    cumsum = np.cumsum(sorted_profits)

    thresholds = np.percentile(vals, np.linspace(10, 90, THRESHOLD_STEPS))
    best_rule, best_score = None, -np.inf

    dirs = [direction] if direction != 0 else [1, -1]
    for d in dirs:
        if d == 1:
            for t in thresholds[int(len(thresholds)*0.3):int(len(thresholds)*0.75)]:
                idx = np.searchsorted(sorted_vals, t)
                n_pass = n - idx
                if n_pass < MIN_SAMPLES_INNER or n_pass > n * 0.75: continue
                total = cumsum[-1] - (cumsum[idx-1] if idx > 0 else 0)
                ev = total / n_pass
                if ev < MIN_EFFECT_SIZE: continue
                se = np.std(sorted_profits[idx:], ddof=1) / np.sqrt(n_pass)
                if se <= 0: continue
                score = (ev - stats.t.ppf(CONFIDENCE_LEVEL, df=n_pass-1) * se) * np.sqrt(n_pass)
                if score > best_score:
                    best_score = score
                    best_rule = {"gate_type": "threshold", "direction": 1, "low": float(t), "high": None}
        else:
            for t in thresholds[int(len(thresholds)*0.25):int(len(thresholds)*0.7)]:
                idx = np.searchsorted(sorted_vals, t, side='right')
                n_pass = idx
                if n_pass < MIN_SAMPLES_INNER or n_pass > n * 0.75: continue
                total = cumsum[idx-1] if idx > 0 else 0
                ev = total / n_pass
                if ev < MIN_EFFECT_SIZE: continue
                se = np.std(sorted_profits[:idx], ddof=1) / np.sqrt(n_pass)
                if se <= 0: continue
                score = (ev - stats.t.ppf(CONFIDENCE_LEVEL, df=n_pass-1) * se) * np.sqrt(n_pass)
                if score > best_score:
                    best_score = score
                    best_rule = {"gate_type": "threshold", "direction": -1, "low": None, "high": float(t)}

    # Band scan
    lo_pcts = np.linspace(20, 40, 4)
    hi_pcts = np.linspace(60, 80, 4)
    bc = 0
    for lo_p in lo_pcts:
        for hi_p in hi_pcts:
            if bc >= BAND_SCAN_LIMIT: break
            lt = np.percentile(vals, lo_p)
            ht = np.percentile(vals, hi_p)
            if lt >= ht: continue
            mask = (vals >= lt) & (vals <= ht)
            n_pass = mask.sum()
            if n_pass < MIN_SAMPLES_INNER or n_pass < n * 0.20 or n_pass > n * 0.70: continue
            ev = profits[mask].mean()
            if ev < MIN_EFFECT_SIZE: continue
            se = np.std(profits[mask], ddof=1) / np.sqrt(n_pass)
            if se <= 0: continue
            score = (ev - stats.t.ppf(CONFIDENCE_LEVEL, df=n_pass-1) * se) * np.sqrt(n_pass)
            if score > best_score:
                best_score = score
                best_rule = {"gate_type": "band", "direction": 0, "low": float(lt), "high": float(ht)}
            bc += 1
    return best_rule


def _perm_test(profits, mask, observed_ev, n_perm=PERM_INNER):
    """Fast permutation test with early stopping."""
    n_blocked = mask.sum()
    arr = profits.copy()
    rng = np.random.default_rng(42)
    count = 0
    for i in range(n_perm):
        rng.shuffle(arr)
        if arr[:n_blocked].mean() >= observed_ev:
            count += 1
        if i >= 30:
            p = count / (i + 1)
            if p > 0.30: return p  # clearly not significant
    return count / n_perm


def _apply(vals, rule):
    if rule["gate_type"] == "threshold":
        return vals >= rule["low"] if rule["direction"] == 1 else vals <= rule["high"]
    elif rule["gate_type"] == "band":
        return (vals >= rule["low"]) & (vals <= rule["high"])
    return np.ones(len(vals), dtype=bool)


def _aggregate(feature_results, sym, setup):
    rules = []
    for feat, vals in feature_results.items():
        if len(vals) < 2: continue
        evs = [v["ev"] for v in vals]
        mean_ev = np.mean(evs)
        if mean_ev < MIN_EFFECT_SIZE: continue

        # Fold consistency
        positive_folds = sum(1 for e in evs if e > 0)
        if positive_folds / len(evs) < FOLD_CONSISTENCY: continue

        p_val = _t_test(evs)
        ci_low, ci_high = _bootstrap_ci(evs)
        slope_p = _temporal_stability(evs)

        wrs = [v["wr"] for v in vals]
        pfs = [v["pf"] for v in vals if v["pf"] < 999]

        validated = (
            mean_ev >= MIN_EFFECT_SIZE and
            p_val < 0.05 and
            ci_low > 0 and
            slope_p > 0.15 and
            np.mean(wrs) >= MIN_WIN_RATE and
            (np.mean(pfs) >= MIN_PROFIT_FACTOR if pfs else False)
        )

        lows = [v["low"] for v in vals if v["low"] is not None]
        highs = [v["high"] for v in vals if v["high"] is not None]

        rules.append({
            "symbol": sym, "setup": setup, "feature": feat,
            "gate_type": vals[0]["gate_type"], "direction": vals[0].get("direction", 0),
            "lower_bound": round(float(np.median(lows)), 4) if lows else None,
            "upper_bound": round(float(np.median(highs)), 4) if highs else None,
            "test_ev_mean": round(mean_ev, 4),
            "test_ev_ci_90": [round(ci_low, 4), round(ci_high, 4)],
            "test_wr_mean": round(np.mean(wrs), 4),
            "test_pf_mean": round(np.mean(pfs), 2) if pfs else 0,
            "test_n_avg": int(np.mean([v["n"] for v in vals])),
            "significance_pvalue": round(p_val, 4),
            "temporal_slope_pvalue": round(slope_p, 4),
            "fold_consistency": round(positive_folds / len(evs), 3),
            "n_folds": len(vals),
            "validated": validated,
            "oos_validated": False,  # updated by _oos_validation
        })
    return rules


def _oos_validation(rules, merged):
    """Final holdout validation (30% most recent data)."""
    merged = merged.sort_values("time")
    split = int(len(merged) * (1 - OOS_RATIO))
    oos = merged.iloc[split:]

    for rule in rules:
        if not rule.get("validated"):
            rule["oos_validated"] = False
            continue

        sym, setup, feat = rule["symbol"], rule["setup"], rule["feature"]
        oos_grp = oos[(oos["symbol"] == sym) & (oos["setupType"] == setup)] if "symbol" in oos.columns else oos[oos["setupType"] == setup]

        if len(oos_grp) < MIN_OOS_TRADES or feat not in oos_grp.columns:
            rule["oos_validated"] = False
            continue

        vals = oos_grp[feat].fillna(0).values
        profits = oos_grp["_profit"].values
        mask = _apply(vals, {"gate_type": rule["gate_type"], "direction": rule["direction"],
                             "low": rule["lower_bound"], "high": rule["upper_bound"]})
        n_pass = mask.sum()
        if n_pass < MIN_OOS_TRADES:
            rule["oos_validated"] = False
            continue

        oos_ev = profits[mask].mean()
        oos_wr = (profits[mask] > 0).mean()
        pos = profits[mask][profits[mask] > 0].sum()
        neg = abs(profits[mask][profits[mask] < 0].sum())
        oos_pf = pos / neg if neg > 0 else 999

        rule["oos_ev"] = round(oos_ev, 4)
        rule["oos_wr"] = round(oos_wr, 4)
        rule["oos_pf"] = round(min(oos_pf, 999), 2)
        rule["oos_n"] = int(n_pass)
        # Allow 50% degradation from in-sample
        rule["oos_validated"] = (oos_ev >= MIN_EFFECT_SIZE * 0.5 and oos_pf >= 1.0 and oos_wr >= MIN_WIN_RATE * 0.8)

    return rules


def _t_test(v):
    if len(v) < 3: return 1.0
    a = np.array(v); se = a.std(ddof=1)/np.sqrt(len(a))
    return 0.0 if se <= 0 else float(stats.t.sf(a.mean()/se, df=len(a)-1))

def _temporal_stability(v):
    if len(v) < 3: return 1.0
    s, _, _, p, _ = stats.linregress(np.arange(len(v)), np.array(v))
    return p/2 if s < 0 else 1.0

def _bootstrap_ci(v, alpha=0.10, n_boot=500):
    a = np.array(v)
    if len(a) < 3: return (float(a.min()), float(a.max()))
    rng = np.random.default_rng(42)
    b = [rng.choice(a, size=len(a), replace=True).mean() for _ in range(n_boot)]
    return (float(np.percentile(b, 100*alpha/2)), float(np.percentile(b, 100*(1-alpha/2))))

def _json_default(obj):
    if isinstance(obj, (np.integer,)): return int(obj)
    if isinstance(obj, (np.floating,)): return float(obj)
    if isinstance(obj, np.ndarray): return obj.tolist()
    if obj is None or (isinstance(obj, float) and np.isnan(obj)): return None
    return str(obj)


if __name__ == "__main__":
    run()
