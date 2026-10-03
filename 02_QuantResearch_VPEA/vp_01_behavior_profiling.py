"""
vp_01_behavior_profiling.py — Per-Symbol VP Behavior Analysis (ROBUST v2)

Key improvements:
- MIN_SAMPLES=50, MIN_TRADES=30 (reduce noise)
- Bootstrap CI for EV (avoid false positives)
- Temporal stability check (split-half comparison)
- UNSTABLE tier for regime-switching symbols
- Archetype confidence scoring
- Stratified downsampling
- Sharpe ratio + PF > 1.5 for HIGH tier
- Default triggers per archetype
"""

import sys, json, warnings, time
import numpy as np
import pandas as pd
from pathlib import Path
from collections import defaultdict
from scipy import stats

warnings.filterwarnings("ignore")
_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))
from data_loader import load_funnel, load_trades, merge_funnel_trades, FUNNEL_FEATURES, REGIME_NAMES

OUTPUT_DIR = _HERE / "output" / "01_behavior_profiling"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

KEY_FEATURES = [
    "vpMigrationConf", "auctBalance", "auctTradeQuality",
    "auctContinuation", "vpDevPOCDir", "vpThinnessRatio",
    "auctRegime", "auctReversalRisk", "auctFailure",
    "vpVAOverlapBias", "vpBestHVNScore", "auctExpReward",
    "auctRegimeConf", "auctExhaustion", "vpDevPOCSlope",
    "spreadToATR", "bosScore", "chochScore", "trendDirection",
]

MIN_SAMPLES = 50
MIN_TRADES_FOR_PERF = 30
MAX_RECORDS = 500_000
STABILITY_CV_THRESHOLD = 0.4  # CV > 40% = unstable


def run(funnel_df=None, trade_df=None, production_style=1):
    t0 = time.time()
    print("\n" + "=" * 60)
    print("VP PHASE 01 — BEHAVIOR PROFILING (ROBUST v2)")
    print("=" * 60)

    if funnel_df is None: funnel_df = load_funnel()
    if trade_df is None: trade_df = load_trades()
    if funnel_df.empty:
        print("  [SKIP] No funnel data"); return {}

    if len(funnel_df) > MAX_RECORDS:
        print(f"  [OPTIMIZE] Stratified downsample {len(funnel_df):,} → {MAX_RECORDS:,}")
        funnel_df = _stratified_sample(funnel_df, MAX_RECORDS)

    if "time" in funnel_df.columns:
        funnel_df = funnel_df.sort_values("time").reset_index(drop=True)

    merged = merge_funnel_trades(funnel_df, trade_df, tolerance_sec=14400, min_records=10)
    symbols = funnel_df["symbol"].unique() if "symbol" in funnel_df.columns else ["ALL"]
    print(f"  Symbols: {len(symbols)}, Funnel: {len(funnel_df):,}")

    # 1. Raw stats
    profiles = _compute_profiles(funnel_df)
    if not profiles:
        print("  [SKIP] No valid profiles"); return {}

    # 2. Stability check (split-half temporal)
    if "time" in funnel_df.columns:
        profiles = _check_stability(profiles, funnel_df)

    # 3. Classify archetypes
    profiles = _classify(profiles)

    # 4. Performance refinement
    if merged is not None and len(merged) >= MIN_TRADES_FOR_PERF:
        profiles = _refine_with_performance(profiles, merged)

    # 5. Regime distribution
    regime_dist = _regime_distribution(funnel_df)
    if regime_dist is not None:
        regime_dist.to_csv(OUTPUT_DIR / "regime_distribution.csv")

    # 6. Trigger performance
    trigger_perf = []
    if merged is not None and len(merged) >= MIN_TRADES_FOR_PERF:
        trigger_perf = _trigger_performance(merged)
        if trigger_perf:
            pd.DataFrame(trigger_perf).sort_values("meanEV", ascending=False).to_csv(
                OUTPUT_DIR / "trigger_performance.csv", index=False)

    # 7. Recommendations
    configs = _recommendations(profiles, trigger_perf)

    # Save
    pd.DataFrame(profiles).to_csv(OUTPUT_DIR / "symbol_profiles.csv", index=False)
    pd.DataFrame(configs).to_csv(OUTPUT_DIR / "recommended_configs.csv", index=False)
    with open(OUTPUT_DIR / "recommended_configs.json", "w") as f:
        json.dump(configs, f, indent=2, default=_jd)

    _print_summary(profiles)
    print(f"\n  Time: {time.time()-t0:.1f}s")
    return {"profiles": profiles, "configs": configs}


def _stratified_sample(df, n):
    """Stratified sampling preserving regime distribution."""
    if "auctRegime" in df.columns:
        return df.groupby("auctRegime", group_keys=False).apply(
            lambda x: x.sample(min(len(x), max(1, int(n * len(x) / len(df)))), random_state=42)
        ).reset_index(drop=True)
    return df.sample(n=n, random_state=42)


def _compute_profiles(df):
    if "symbol" not in df.columns: return []
    counts = df["symbol"].value_counts()
    valid = counts[counts >= MIN_SAMPLES].index
    sub = df[df["symbol"].isin(valid)]
    available = [f for f in KEY_FEATURES if f in sub.columns]
    if not available: return []

    g = sub.groupby("symbol")[available]
    means = g.mean()
    stds = g.std()
    p25 = g.quantile(0.25)
    p75 = g.quantile(0.75)
    ns = sub.groupby("symbol").size()

    pct_balanced = pd.Series(0.0, index=valid)
    pct_trend = pd.Series(0.0, index=valid)
    pct_compression = pd.Series(0.0, index=valid)
    regime_entropy = pd.Series(0.0, index=valid)

    if "auctRegime" in sub.columns:
        ct = pd.crosstab(sub["symbol"], sub["auctRegime"], normalize="index")
        for sym in valid:
            if sym in ct.index:
                row = ct.loc[sym]
                pct_balanced[sym] = row.get(0, 0)
                pct_trend[sym] = row.get(2, 0) + row.get(3, 0)
                pct_compression[sym] = row.get(1, 0)
                probs = row[row > 0].values
                regime_entropy[sym] = -np.sum(probs * np.log2(probs)) if len(probs) > 0 else 0

    profiles = []
    for sym in valid:
        p = {"symbol": sym, "n_samples": int(ns[sym])}
        for f in available:
            p[f"{f}_mean"] = round(float(means.loc[sym, f]), 4)
            p[f"{f}_std"] = round(float(stds.loc[sym, f]), 4)
            p[f"{f}_p25"] = round(float(p25.loc[sym, f]), 4)
            p[f"{f}_p75"] = round(float(p75.loc[sym, f]), 4)
        p["pct_balanced"] = round(float(pct_balanced.get(sym, 0)), 4)
        p["pct_trend"] = round(float(pct_trend.get(sym, 0)), 4)
        p["pct_compression"] = round(float(pct_compression.get(sym, 0)), 4)
        p["regime_entropy"] = round(float(regime_entropy.get(sym, 0)), 4)
        profiles.append(p)
    return profiles


def _check_stability(profiles, df):
    """Split-half temporal stability: compare first half vs second half means."""
    if "symbol" not in df.columns: return profiles

    mid_time = df["time"].quantile(0.5)
    first_half = df[df["time"] <= mid_time]
    second_half = df[df["time"] > mid_time]

    key_feats = ["auctBalance", "vpMigrationConf", "auctTradeQuality", "auctContinuation"]

    for p in profiles:
        sym = p["symbol"]
        h1 = first_half[first_half["symbol"] == sym]
        h2 = second_half[second_half["symbol"] == sym]

        if len(h1) < MIN_SAMPLES // 2 or len(h2) < MIN_SAMPLES // 2:
            p["is_stable"] = False
            p["stability_score"] = 0.0
            continue

        cvs = []
        for f in key_feats:
            if f in h1.columns and h1[f].std() > 1e-9:
                m1 = h1[f].mean()
                m2 = h2[f].mean()
                combined_mean = (m1 + m2) / 2
                if abs(combined_mean) > 1e-9:
                    cv = abs(m1 - m2) / abs(combined_mean)
                    cvs.append(cv)

        if cvs:
            median_cv = np.median(cvs)
            p["stability_score"] = round(max(0, 1 - median_cv / STABILITY_CV_THRESHOLD), 3)
            p["is_stable"] = median_cv < STABILITY_CV_THRESHOLD
        else:
            p["is_stable"] = True
            p["stability_score"] = 0.5

    return profiles


def _classify(profiles):
    """Percentile-based classification with confidence scoring."""
    df = pd.DataFrame(profiles)
    for col in ["auctBalance_mean", "vpMigrationConf_mean", "auctTradeQuality_mean",
                "auctContinuation_mean", "pct_trend", "pct_balanced", "regime_entropy"]:
        if col in df.columns:
            df[f"{col}_pct"] = df[col].rank(pct=True)

    mig = df.get("vpMigrationConf_mean_pct", pd.Series(0.5, index=df.index))
    bal = df.get("auctBalance_mean_pct", pd.Series(0.5, index=df.index))
    tq = df.get("auctTradeQuality_mean_pct", pd.Series(0.5, index=df.index))
    trend = df.get("pct_trend_pct", pd.Series(0.5, index=df.index))
    ent = df.get("regime_entropy_pct", pd.Series(0.5, index=df.index))
    cont = df.get("auctContinuation_mean_pct", pd.Series(0.5, index=df.index))

    archetypes = np.select(
        [tq < 0.15,
         (trend > 0.75) & (mig > 0.60),
         (trend > 0.60) & (cont > 0.60),
         ent > 0.75,
         (bal > 0.75) & (trend < 0.30),
         bal > 0.50],
        ["SPREAD_UNSTABLE", "TREND_FRIENDLY", "TREND_MODERATE",
         "VOLATILE_SWITCHING", "STRONG_RANGE", "MODERATE_RANGE"],
        default="NEUTRAL")

    for i, p in enumerate(profiles):
        p["archetype"] = archetypes[i]
        if not p.get("is_stable", True):
            p["quality_tier"] = "UNSTABLE"
        else:
            p["quality_tier"] = "UNKNOWN"
    return profiles


def _refine_with_performance(profiles, merged):
    if "symbol" not in merged.columns or "profitUSD" not in merged.columns:
        return profiles

    for p in profiles:
        sym = p["symbol"]
        sym_df = merged[merged["symbol"] == sym]
        nv = len(sym_df)

        if nv < MIN_TRADES_FOR_PERF:
            if p["quality_tier"] == "UNKNOWN":
                p["quality_tier"] = "INSUFFICIENT_DATA"
            continue

        profits = sym_df["profitUSD"].values
        e = profits.mean()
        w = (profits > 0).mean()
        pos = profits[profits > 0].sum()
        neg = abs(profits[profits < 0].sum())
        pv = pos / neg if neg > 0 else 999
        sh = np.sqrt(252) * e / profits.std() if profits.std() > 0 else 0

        # Bootstrap CI for EV
        ev_ci = _bootstrap_ci(profits)

        p["avg_ev"] = round(e, 2)
        p["avg_ev_ci_lower"] = round(ev_ci[0], 2)
        p["avg_wr"] = round(w, 3)
        p["avg_pf"] = round(min(pv, 999), 2)
        p["sharpe"] = round(sh, 2)
        p["trade_count"] = nv

        # Quality tiers (strict)
        if p["quality_tier"] == "UNSTABLE":
            continue  # keep UNSTABLE from stability check

        if e < 0 and w < 0.30 and nv >= 30:
            p["quality_tier"] = "AVOID"
            p["avoid_reason"] = f"EV=${e:.0f} WR={w:.0%} PF={pv:.1f}"
        elif e < 0 and pv < 0.6:
            p["quality_tier"] = "AVOID"
            p["avoid_reason"] = f"PF={pv:.1f} EV=${e:.0f}"
        elif ev_ci[0] < 0:
            p["quality_tier"] = "LOW"
        elif e > 0 and pv > 1.5 and sh > 0.3 and nv >= 30 and ev_ci[0] > 0:
            p["quality_tier"] = "HIGH"
        elif e > 0 and pv > 1.0:
            p["quality_tier"] = "MEDIUM"
        else:
            p["quality_tier"] = "LOW"

    return profiles


def _bootstrap_ci(values, alpha=0.10, n_boot=500):
    vals = np.array(values)
    if len(vals) < 10: return (float(vals.min()), float(vals.max()))
    rng = np.random.default_rng(42)
    boot = [rng.choice(vals, size=len(vals), replace=True).mean() for _ in range(n_boot)]
    return (float(np.percentile(boot, 100*alpha/2)), float(np.percentile(boot, 100*(1-alpha/2))))


def _trigger_performance(merged):
    if "setupType" not in merged.columns: return []
    valid = merged[(merged["setupType"].notna()) & (merged["setupType"] != "NONE")]
    if valid.empty: return []

    results = []
    for (sym, st), grp in valid.groupby(["symbol", "setupType"]):
        if len(grp) < MIN_TRADES_FOR_PERF: continue
        profits = grp["profitUSD"].values
        ev = profits.mean()
        ev_ci = _bootstrap_ci(profits)
        wr = (profits > 0).mean()
        pos = profits[profits > 0].sum()
        neg = abs(profits[profits < 0].sum())
        pf = pos / neg if neg > 0 else 999

        results.append({
            "symbol": sym, "setupType": st, "count": len(grp),
            "meanEV": round(ev, 4), "ev_ci_lower": round(ev_ci[0], 4),
            "profitFactor": round(min(pf, 999), 2),
            "winRate": round(wr, 3), "maxDD": round(profits.min(), 2),
            "reliable": bool(ev_ci[0] > 0 and len(grp) >= MIN_TRADES_FOR_PERF),
        })
    return results


def _recommendations(profiles, trigger_perf):
    perf_lookup = {(tp["symbol"], tp["setupType"]): tp for tp in trigger_perf}
    trigger_names = ["BREAKOUT", "BREAKOUT_RETEST", "PULLBACK",
                     "TREND_CONTINUATION", "SWEEP_REVERSAL", "MEAN_REVERSION"]
    config_keys = ["breakout", "breakout_retest", "pullback",
                   "trend_cont", "sweep_reversal", "mean_reversion"]

    configs = []
    for p in profiles:
        sym, tier, arch = p["symbol"], p.get("quality_tier", "UNKNOWN"), p.get("archetype", "NEUTRAL")
        cfg = {"symbol": sym, "archetype": arch, "quality_tier": tier,
               "stability_score": p.get("stability_score", 0)}

        if tier == "AVOID":
            for k in config_keys: cfg[k] = False
            cfg["naked_poc"] = False; cfg["anchored_pullback"] = False

        elif tier == "UNSTABLE":
            for k in config_keys: cfg[k] = False
            cfg["mean_reversion"] = True  # only conservative
            cfg["naked_poc"] = False; cfg["anchored_pullback"] = False

        else:
            for tn, ck in zip(trigger_names, config_keys):
                perf = perf_lookup.get((sym, tn))
                if perf:
                    cfg[ck] = bool(perf.get("reliable", False) or perf["meanEV"] > 0)
                else:
                    cfg[ck] = bool(_default_for_archetype(arch, tn))
            cfg["naked_poc"] = bool(tier in ["HIGH", "MEDIUM"])
            cfg["anchored_pullback"] = bool(tier == "HIGH")

        configs.append(cfg)
    return configs


def _default_for_archetype(arch, trigger):
    if arch in ("TREND_FRIENDLY", "TREND_MODERATE"):
        return trigger in ("BREAKOUT", "PULLBACK", "TREND_CONTINUATION", "BREAKOUT_RETEST")
    elif arch in ("STRONG_RANGE", "MODERATE_RANGE"):
        return trigger in ("MEAN_REVERSION", "SWEEP_REVERSAL")
    elif arch in ("VOLATILE_SWITCHING", "SPREAD_UNSTABLE"):
        return False
    return trigger in ("BREAKOUT_RETEST", "MEAN_REVERSION")


def _regime_distribution(df):
    if "symbol" not in df.columns or "auctRegime" not in df.columns: return None
    ct = pd.crosstab(df["symbol"], df["auctRegime"], normalize="index")
    ct.columns = [REGIME_NAMES.get(c, f"R{c}") for c in ct.columns]
    return ct.round(4)


def _jd(obj):
    if isinstance(obj, (np.integer,)): return int(obj)
    if isinstance(obj, (np.floating,)): return float(obj)
    if isinstance(obj, (np.bool_,)): return bool(obj)
    if isinstance(obj, np.ndarray): return obj.tolist()
    return str(obj)


def _print_summary(profiles):
    arch_counts = defaultdict(int)
    tier_counts = defaultdict(int)
    for p in profiles:
        arch_counts[p["archetype"]] += 1
        tier_counts[p.get("quality_tier", "UNKNOWN")] += 1

    print(f"\n  Profiles: {len(profiles)}")
    print("  Archetypes:")
    for a, c in sorted(arch_counts.items(), key=lambda x: -x[1]):
        print(f"    {a:<25} {c}")
    print("  Quality:")
    for t, c in sorted(tier_counts.items(), key=lambda x: -x[1]):
        print(f"    {t:<25} {c}")

    avoid = [p["symbol"] for p in profiles if p.get("quality_tier") == "AVOID"]
    high = [p["symbol"] for p in profiles if p.get("quality_tier") == "HIGH"]
    unstable = [p["symbol"] for p in profiles if p.get("quality_tier") == "UNSTABLE"]
    if avoid: print(f"  AVOID: {', '.join(avoid[:8])}")
    if unstable: print(f"  UNSTABLE: {', '.join(unstable[:8])}")
    if high: print(f"  HIGH: {', '.join(high[:8])}")


if __name__ == "__main__":
    run()
