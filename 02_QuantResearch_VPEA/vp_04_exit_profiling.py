"""
vp_05_exit_profiling.py — TP/SL Exit Profiling (ROBUST v2)

Key improvements:
- Pre-registered features (no data snooping)
- class_weight='balanced' for imbalanced exit types
- FDR correction (inlined BH)
- Brier score + AUC calibration
- Feature stability voting
- Permutation test for SL thresholds
- Fisher's combined p-value
- Final OOS validation
- Temporal gap enforcement
- Cohen's d effect size in descriptive
- `final_validated` output field
"""

import sys, json, warnings, time
import numpy as np
import pandas as pd
from pathlib import Path
from scipy import stats
from collections import defaultdict

try:
    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import StandardScaler
    from sklearn.metrics import roc_auc_score, brier_score_loss
    HAS_ML = True
except ImportError:
    HAS_ML = False

warnings.filterwarnings("ignore")
_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))
from data_loader import (load_funnel, load_trades, merge_funnel_trades, FUNNEL_FEATURES,
                         split_by_style, has_trail_styles, TRAIL_STYLES)

OUTPUT_DIR = _HERE / "output" / "04_exit_profiling"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MIN_SAMPLES = 30
MIN_EXIT_TYPE = 8
OUTER_SPLITS = 5
GAP_RATIO = 0.10
MIN_INNER = 12
MAX_FEATURES = 12
MIN_FEATURES = 3
MIN_AUC = 0.58
MAX_BRIER = 0.25
SL_LIFT_MIN = 0.08
SL_MIN_GROUP = 12
PERCENTILES = [25, 40, 50, 60, 75]
WF_MIN_FOLDS = 2
BOOTSTRAP_N = 500
CV_CONSISTENCY = 0.60
MAX_RECORDS = 500_000
LR_MAX_ITER = 500
FDR_LEVEL = 0.05
OOS_RATIO = 0.30

PRE_REGISTERED = {
    # Raw structure features and composites split into separate categories so the
    # 2-per-category cap evaluates each family independently.
    "trend_raw":       ["bosScore", "chochScore", "trendDirection"],
    "trend_composite": ["bosQuality", "chochQuality", "structAlign"],
    "trend":    ["auctContinuation"],
    "quality":  ["auctTradeQuality", "auctBalance", "auctExpReward"],
    "risk":     ["auctReversalRisk", "auctFailure", "auctExhaustion"],
    "volume":   ["vpMigrationConf", "vpBestHVNScore", "vpVAOverlapBias"],
    "volatility":["spreadToATR", "vpThinnessRatio", "auctRegimeConf"],
    "timing":   ["structDistATR"],
    "longterm": ["vpLTPOCMigration", "vpLTNearestZoneStrength", "vpLTTransitionScore", "vpLTBalanceStability"],
    # Bonus engines: primaries and composites in separate categories.
    "engine_primary": ["msCompression", "ofFlowIntensity", "liqSweep", "smZoneQuality"],
    "engine_context": ["msContext", "ofContext", "liqContext", "smContext"],
    "interactions": ["ix_tq_mig", "ix_bos_trend", "ix_spread_atr", "ix_cont_mig", "ix_fail_reversal",
                    "ix_struct_bos", "ix_devpoc_ltpoc", "ix_exhaust_lt", "ix_acceptance", "ix_target_rr"],
}

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


def run(funnel_df=None, trade_df=None, all_results=None, production_style=1):
    t0 = time.time()
    print("\n" + "=" * 60)
    print("VP PHASE 04 — EXIT PROFILING (ROBUST v2)")
    print("=" * 60)

    if not HAS_ML:
        print("  [SKIP] sklearn required"); return {"sl_thresholds": [], "tp_profiles": [], "sl_profiles": []}
    if trade_df is None: trade_df = load_trades()
    if funnel_df is None: funnel_df = load_funnel()

    merged_all = merge_funnel_trades(funnel_df, trade_df, tolerance_sec=14400, min_records=15)
    if merged_all is None or len(merged_all) < MIN_SAMPLES or "exitReason" not in merged_all.columns:
        print("  [SKIP] Insufficient data"); return {"sl_thresholds": [], "tp_profiles": [], "sl_profiles": []}

    # exitReason (TP_HIT / SL_HIT / TRAIL_STOP) is a DIRECT function of the
    # trailing style: style -1 (no trailing) can hit TP/SL but never TRAIL_STOP,
    # while styles 0/1 convert many would-be TP hits into TRAIL_STOP exits.
    # → Cross-style comparison (below) is computed on ALL styles; the guard-bound
    #   TP/SL models + sl_thresholds are computed on the PRODUCTION style so they
    #   match what the EA actually experiences Live.
    multi_style = has_trail_styles(merged_all)
    style_comparison = _style_comparison(merged_all) if multi_style else []

    prod_df, _all = split_by_style(merged_all, production_style)
    if multi_style:
        print(f"  [STYLE] production={production_style} baseline: "
              f"{len(prod_df)} trades (of {len(merged_all)} across all styles)")
    merged = prod_df
    if merged is None or len(merged) < MIN_SAMPLES:
        print(f"  [SKIP] Insufficient production-style data "
              f"({0 if merged is None else len(merged)} < {MIN_SAMPLES})")
        return {"sl_thresholds": [], "tp_profiles": [], "sl_profiles": [],
                "style_comparison": style_comparison}

    if len(merged) > MAX_RECORDS:
        merged = merged.sample(n=MAX_RECORDS, random_state=42)
    if "time" in merged.columns:
        merged = merged.sort_values("time").reset_index(drop=True)

    merged["_is_tp"] = (merged["exitReason"] == "TP_HIT").astype(np.int8).values
    merged["_is_sl"] = (merged["exitReason"] == "SL_HIT").astype(np.int8).values
    merged = _compute_interactions(merged)
    n_tp, n_sl = merged["_is_tp"].sum(), merged["_is_sl"].sum()
    print(f"  Records: {len(merged):,} | TP={n_tp} SL={n_sl}")

    if n_tp < MIN_EXIT_TYPE and n_sl < MIN_EXIT_TYPE:
        print("  [SKIP] Insufficient exit types"); return {"sl_thresholds": [], "tp_profiles": [], "sl_profiles": []}

    _descriptive(merged)
    _exit_state(merged)

    all_p_values = []
    groups = _get_groups(merged)
    all_tp, all_sl, all_thresh = [], [], []

    for sym, setup, sub in groups:
        feats = _get_features(sub)
        if len(feats) < MIN_FEATURES: continue

        if sub["_is_tp"].sum() >= MIN_EXIT_TYPE:
            p = _build_profile(sub, sym, setup, "TP_HIT", sub["_is_tp"].values, feats, all_p_values)
            if p: all_tp.append(p)

        if sub["_is_sl"].sum() >= MIN_EXIT_TYPE:
            p = _build_profile(sub, sym, setup, "SL_HIT", sub["_is_sl"].values, feats, all_p_values)
            if p: all_sl.append(p)

        if sub["_is_sl"].sum() >= MIN_EXIT_TYPE:
            t = _sl_thresholds(sub, sym, setup, feats, all_p_values)
            if t: all_thresh.extend(t)

    # FDR + OOS
    fdr_mask = _bh(all_p_values, FDR_LEVEL) if all_p_values else []
    all_profiles = all_tp + all_sl
    if all_profiles and "time" in merged.columns:
        all_profiles = _oos(all_profiles, merged, fdr_mask)
        all_tp = [p for p in all_profiles if p["exit_type"] == "TP_HIT"]
        all_sl = [p for p in all_profiles if p["exit_type"] == "SL_HIT"]

    # Save
    if all_tp:
        pd.DataFrame([{k:v for k,v in p.items() if k!="feature_importances"} for p in all_tp]).to_csv(OUTPUT_DIR/"tp_profiles.csv", index=False)
    if all_sl:
        pd.DataFrame([{k:v for k,v in p.items() if k!="feature_importances"} for p in all_sl]).to_csv(OUTPUT_DIR/"sl_profiles.csv", index=False)
    if all_thresh:
        pd.DataFrame(all_thresh).to_csv(OUTPUT_DIR/"sl_thresholds.csv", index=False)
        with open(OUTPUT_DIR/"sl_thresholds.json", "w") as f:
            json.dump(all_thresh, f, indent=2, default=str)

    # Cross-style exit comparison (which trailing style exits best per group)
    if style_comparison:
        pd.DataFrame(style_comparison).to_csv(OUTPUT_DIR/"style_comparison.csv", index=False)
        with open(OUTPUT_DIR/"style_comparison.json", "w") as f:
            json.dump(style_comparison, f, indent=2, default=str)

    final_tp = [p for p in all_tp if p.get("final_validated")]
    final_sl = [p for p in all_sl if p.get("final_validated")]
    print(f"\n  TP: {len(all_tp)} (final: {len(final_tp)}) | SL: {len(all_sl)} (final: {len(final_sl)}) | Thresh: {len(all_thresh)}")
    if style_comparison:
        _print_style_summary(style_comparison, production_style)
    print(f"  Time: {time.time()-t0:.1f}s")
    return {"tp_profiles": all_tp, "sl_profiles": all_sl, "sl_thresholds": all_thresh,
            "style_comparison": style_comparison}


def _style_comparison(merged_all):
    """Compare exit behaviour across trailing styles on IDENTICAL entries.

    Because DataCollect fires one position per style on the same signal, this is
    a like-for-like comparison: for each (symbol, setup, trailStyle) it reports
    trade count, TP/SL/TRAIL exit mix, win rate, mean profit (EV), and mean
    MFE/MAE (in ATR) when available. It answers 'which trailing style exits best
    for this setup?' — evidence for choosing the production style, and it is
    exit-policy aware by construction (each row is a single style).
    """
    if "trailStyle" not in merged_all.columns:
        return []
    m = merged_all.copy()
    m["trailStyle"] = pd.to_numeric(m["trailStyle"], errors="coerce")
    m = m[m["trailStyle"].isin(TRAIL_STYLES)]
    if m.empty or "profitUSD" not in m.columns:
        return []

    has_sym = "symbol" in m.columns
    has_setup = "setupType" in m.columns
    has_reason = "exitReason" in m.columns
    has_mfe = "mfeATR" in m.columns
    has_mae = "maeATR" in m.columns

    group_cols = []
    if has_sym: group_cols.append("symbol")
    if has_setup: group_cols.append("setupType")

    rows = []
    if group_cols:
        grouped = m.groupby(group_cols)
    else:
        grouped = [((), m)]

    for gvals, g in (grouped if group_cols else grouped):
        if group_cols:
            if not isinstance(gvals, tuple):
                gvals = (gvals,)
            base = dict(zip(group_cols, gvals))
        else:
            base = {}
        for style in TRAIL_STYLES:
            sub = g[g["trailStyle"] == style]
            if len(sub) == 0:
                continue
            prof = pd.to_numeric(sub["profitUSD"], errors="coerce").dropna()
            rec = dict(base)
            rec["trailStyle"] = style
            rec["n"] = int(len(sub))
            rec["ev"] = round(float(prof.mean()), 4) if len(prof) else 0.0
            rec["win_rate"] = round(float((prof > 0).mean()), 4) if len(prof) else 0.0
            tot = pos = neg = 0.0
            pos = prof[prof > 0].sum(); neg = abs(prof[prof < 0].sum())
            rec["profit_factor"] = round(float(pos / neg), 3) if neg > 0 else 999.0
            if has_reason:
                n = len(sub)
                rec["tp_rate"] = round(float((sub["exitReason"] == "TP_HIT").mean()), 4)
                rec["sl_rate"] = round(float((sub["exitReason"] == "SL_HIT").mean()), 4)
                rec["trail_rate"] = round(float((sub["exitReason"] == "TRAIL_STOP").mean()), 4)
            if has_mfe:
                rec["mfe_atr_mean"] = round(float(pd.to_numeric(sub["mfeATR"], errors="coerce").mean()), 3)
            if has_mae:
                rec["mae_atr_mean"] = round(float(pd.to_numeric(sub["maeATR"], errors="coerce").mean()), 3)
            rows.append(rec)

    # Mark the best style (by EV) within each group
    if rows:
        cmp_df = pd.DataFrame(rows)
        key = group_cols if group_cols else None
        if key:
            best_idx = cmp_df.groupby(key)["ev"].idxmax()
            cmp_df["best_ev_style"] = False
            cmp_df.loc[best_idx, "best_ev_style"] = True
        else:
            cmp_df["best_ev_style"] = cmp_df["ev"] == cmp_df["ev"].max()
        rows = cmp_df.to_dict("records")
    return rows


def _print_style_summary(style_comparison, production_style):
    """Console summary: per style, aggregate EV/WR and how often it is the best
    style in a group; flag whether the production style is the empirical winner."""
    if not style_comparison:
        return
    df = pd.DataFrame(style_comparison)
    label = {-1: "no-trail", 0: "conservative", 1: "expansion"}
    print("  Exit style comparison (all styles, identical entries):")
    for style in TRAIL_STYLES:
        s = df[df["trailStyle"] == style]
        if s.empty:
            continue
        wins = int(s["best_ev_style"].sum()) if "best_ev_style" in s.columns else 0
        # Trade-weighted mean EV across groups
        w = s["n"].sum()
        wev = float((s["ev"] * s["n"]).sum() / w) if w else 0.0
        wwr = float((s["win_rate"] * s["n"]).sum() / w) if w else 0.0
        tag = "  <- production" if style == production_style else ""
        print(f"    style {style:>2} ({label.get(style,'?'):<12}): "
              f"EV={wev:+.3f} WR={wwr:.1%} best-in-group x{wins}{tag}")


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


def _get_features(df):
    """Select features ensuring diversity across categories.
    Takes up to 2 best features per category (by variance), max MAX_FEATURES total."""
    available = []
    for cat, feats in PRE_REGISTERED.items():
        cat_available = []
        for f in feats:
            if f in df.columns and df[f].std() > 1e-9 and df[f].isna().mean() < 0.3:
                cat_available.append(f)
        if cat_available:
            variances = [(f, df[f].std()) for f in cat_available]
            variances.sort(key=lambda x: -x[1])
            for f, _ in variances[:2]:
                available.append(f)
                if len(available) >= MAX_FEATURES:
                    return available
    return available


def _build_profile(df, sym, setup, exit_type, target, feats, all_p_values):
    n = len(df)
    gap = max(1, int(n * GAP_RATIO))
    fold_size = n // (OUTER_SPLITS + 1)
    if fold_size < MIN_INNER: return None

    aucs, briers = [], []
    feat_votes = defaultdict(int)
    last_info = None

    for i in range(OUTER_SPLITS):
        te = fold_size*(i+1); vs = te+gap; ve = min(vs+fold_size, n)
        if ve-vs < MIN_INNER: continue
        y_tr, y_val = target[:te], target[vs:ve]
        if y_tr.sum() < 3 or y_val.sum() < 2: continue

        avail = [f for f in feats if f in df.columns and df[f].iloc[:te].std() > 1e-9]
        if len(avail) < MIN_FEATURES: continue
        for f in avail: feat_votes[f] += 1

        X_tr = df[avail].iloc[:te].fillna(0).values
        X_val = df[avail].iloc[vs:ve].fillna(0).values
        scaler = StandardScaler(); X_tr_s = scaler.fit_transform(X_tr); X_val_s = scaler.transform(X_val)
        if len(np.unique(y_tr)) < 2: continue  # need both classes
        model = LogisticRegression(C=0.1, penalty="l2", solver="lbfgs", max_iter=LR_MAX_ITER, class_weight="balanced")
        model.fit(X_tr_s, y_tr)

        try:
            proba = model.predict_proba(X_val_s)[:, 1]
            auc = roc_auc_score(y_val, proba)
            brier = brier_score_loss(y_val, proba)
        except: continue
        if brier > MAX_BRIER: continue

        aucs.append(auc); briers.append(brier)
        last_info = {"features": avail, "coefs": model.coef_[0]}

    if len(aucs) < WF_MIN_FOLDS or last_info is None: return None
    mean_auc = np.mean(aucs)
    if mean_auc < MIN_AUC: return None

    pos_folds = sum(1 for a in aucs if a > 0.55)
    consistency = pos_folds / len(aucs)
    if consistency < CV_CONSISTENCY: return None

    p_val = _t_test_auc(aucs)
    all_p_values.append(p_val)

    stable = [f for f, c in feat_votes.items() if c >= max(2, OUTER_SPLITS//2)]
    if len(stable) < MIN_FEATURES: stable = last_info["features"]

    feat_imp = sorted(zip(stable, last_info["coefs"][:len(stable)]), key=lambda x: abs(x[1]), reverse=True)

    return {
        "symbol": sym, "setup": setup, "exit_type": exit_type,
        "auc_mean": round(mean_auc, 4), "auc_std": round(float(np.std(aucs)), 4),
        "brier_mean": round(float(np.mean(briers)), 4),
        "target_rate": round(float(target.mean()), 4),
        "n_total": n, "n_target": int(target.sum()),
        "top_features": [f for f, _ in feat_imp[:5]],
        "feature_importances": [{"feature": f, "coef": round(float(c), 4)} for f, c in feat_imp],
        "fold_consistency": round(consistency, 3),
        "validated": mean_auc >= MIN_AUC and p_val < 0.05 and consistency >= CV_CONSISTENCY,
        "final_validated": False,
    }


def _sl_thresholds(df, sym, setup, feats, all_p_values):
    n = len(df); gap = max(1, int(n*GAP_RATIO)); fold_size = n//(OUTER_SPLITS+1)
    if fold_size < SL_MIN_GROUP: return []
    sl_vals = df["_is_sl"].values
    rule_folds = defaultdict(list)

    for fi in range(OUTER_SPLITS):
        te = fold_size*(fi+1); vs = te+gap; ve = min(vs+fold_size, n)
        if ve-vs < SL_MIN_GROUP: continue
        baseline = sl_vals[:te].mean(); val_baseline = sl_vals[vs:ve].mean()

        for feat in feats:
            if feat not in df.columns: continue
            tr_v = df[feat].iloc[:te].fillna(0).values; val_v = df[feat].iloc[vs:ve].fillna(0).values
            for pct in PERCENTILES:
                t = np.percentile(tr_v, pct)
                for d in ["above", "below"]:
                    tm = tr_v > t if d == "above" else tr_v < t
                    if tm.sum() < SL_MIN_GROUP: continue
                    if sl_vals[:te][tm].mean() - baseline < SL_LIFT_MIN: continue
                    vm = val_v > t if d == "above" else val_v < t
                    if vm.sum() < SL_MIN_GROUP//2: continue
                    vl = sl_vals[vs:ve][vm].mean() - val_baseline
                    if vl > 0:
                        rule_folds[(feat, d, pct)].append({"threshold": t, "val_sl": sl_vals[vs:ve][vm].mean(), "val_lift": vl, "n": int(vm.sum())})

    results = []; seen = set()
    for (feat, d, pct), folds in rule_folds.items():
        if len(folds) < WF_MIN_FOLDS: continue
        key = (feat, d)
        if key in seen: continue
        lifts = [f["val_lift"] for f in folds]
        ci_low, _ = _bci(lifts)
        if ci_low <= 0: continue
        if len(lifts) >= 3:
            s, _, _, p, _ = stats.linregress(np.arange(len(lifts)), np.array(lifts))
            if s < 0 and p < 0.10: continue
        pos = sum(1 for l in lifts if l > 0)
        if pos/len(lifts) < CV_CONSISTENCY: continue

        # Fisher's p
        perm_ps = [_perm_lift(sl_vals, f["n"], f["val_lift"]) for f in folds[:3]]
        combined_p = _fisher_p(perm_ps)
        all_p_values.append(combined_p)

        seen.add(key)
        results.append({
            "symbol": sym, "setup": setup, "feature": feat,
            "direction": d, "percentile": pct,
            "threshold": round(float(np.mean([f["threshold"] for f in folds])), 6),
            "avg_sl_rate": round(float(np.mean([f["val_sl"] for f in folds])), 4),
            "avg_lift": round(float(np.mean(lifts)), 4),
            "lift_ci_90": [round(ci_low, 4), round(float(np.percentile([np.mean(np.random.default_rng(42).choice(lifts, len(lifts), replace=True)) for _ in range(200)], 95)), 4)],
            "n_folds": len(folds), "validated": True,
        })
    results.sort(key=lambda x: x["avg_lift"], reverse=True)
    return results[:10]


def _oos(profiles, merged, fdr_mask):
    split = int(len(merged) * (1-OOS_RATIO)); oos = merged.iloc[split:]
    for i, p in enumerate(profiles):
        fdr_pass = fdr_mask[i] if i < len(fdr_mask) else False
        if not p.get("validated") or not fdr_pass:
            p["final_validated"] = False; continue
        grp = oos[(oos["symbol"]==p["symbol"]) & (oos["setupType"]==p["setup"])] if "symbol" in oos.columns else oos
        target = (grp["exitReason"]==p["exit_type"]).astype(int).values if len(grp)>=MIN_INNER else np.array([])
        if len(target) < MIN_INNER or target.sum() < 3:
            p["final_validated"] = False; continue
        feats = p.get("top_features", [])[:MAX_FEATURES]
        avail = [f for f in feats if f in grp.columns]
        if len(avail) < MIN_FEATURES:
            p["final_validated"] = False; continue
        coefs = np.array([imp["coef"] for imp in p.get("feature_importances",[]) if imp["feature"] in avail])[:len(avail)]
        if len(coefs) != len(avail):
            p["final_validated"] = False; continue
        X = grp[avail].fillna(0).values
        scores = X.dot(coefs)
        try: oos_auc = roc_auc_score(target, scores)
        except: oos_auc = 0.5
        p["oos_auc"] = round(oos_auc, 4)
        p["final_validated"] = oos_auc >= MIN_AUC * 0.9
    return profiles


def _descriptive(merged):
    exits = {"TP_HIT": merged[merged["_is_tp"]==1], "SL_HIT": merged[merged["_is_sl"]==1]}
    rows = []
    for feat in FUNNEL_FEATURES:
        if feat not in merged.columns: continue
        row = {"feature": feat}
        for et, sub in exits.items():
            if len(sub) >= MIN_EXIT_TYPE:
                row[f"{et}_mean"] = round(float(sub[feat].mean()), 4)
                row[f"{et}_std"] = round(float(sub[feat].std()), 4)
        if "TP_HIT_mean" in row and "SL_HIT_mean" in row:
            row["tp_vs_sl"] = round(row["TP_HIT_mean"]-row["SL_HIT_mean"], 4)
            ps = np.sqrt((row["TP_HIT_std"]**2+row["SL_HIT_std"]**2)/2)
            row["cohens_d"] = round((row["TP_HIT_mean"]-row["SL_HIT_mean"])/ps, 3) if ps > 0 else 0
        rows.append(row)
    if rows:
        pd.DataFrame(rows).sort_values("cohens_d", ascending=False, na_position="last").to_csv(OUTPUT_DIR/"feature_by_exit.csv", index=False)


def _exit_state(merged):
    exit_cols = [c for c in merged.columns if c.startswith("exit") and c not in ("exitReason","exitTime")]
    if not exit_cols: return
    exits = {"TP_HIT": merged[merged["_is_tp"]==1], "SL_HIT": merged[merged["_is_sl"]==1]}
    rows = []
    for col in exit_cols:
        row = {"feature": col}
        for et, sub in exits.items():
            if col in sub.columns and len(sub) >= MIN_EXIT_TYPE:
                row[f"{et}_mean"] = round(float(sub[col].mean()), 4)
        if "SL_HIT_mean" in row and "TP_HIT_mean" in row:
            row["sl_vs_tp"] = round(row["SL_HIT_mean"]-row["TP_HIT_mean"], 4)
        rows.append(row)
    if rows:
        pd.DataFrame(rows).sort_values("sl_vs_tp", ascending=False, na_position="last").to_csv(OUTPUT_DIR/"exit_state_comparison.csv", index=False)


def _get_groups(df):
    groups = []
    if "symbol" not in df.columns: return [("ALL","ALL",df)]
    for sym in df["symbol"].unique():
        sd = df[df["symbol"]==sym]
        if "setupType" in sd.columns:
            for st in sd["setupType"].unique():
                if pd.isna(st) or st in ("NONE",""): continue
                sub = sd[sd["setupType"]==st]
                if len(sub) >= MIN_SAMPLES: groups.append((sym,st,sub))
        else:
            if len(sd) >= MIN_SAMPLES: groups.append((sym,"ALL",sd))
    return groups


def _t_test_auc(aucs, baseline=0.5):
    if len(aucs) < 2: return 1.0
    a = np.array(aucs); se = a.std(ddof=1)/np.sqrt(len(a))
    return 0.0 if se <= 0 else float(stats.t.sf((a.mean()-baseline)/se, df=len(a)-1))

def _perm_lift(sl_vals, n_mask, observed, n_perm=200):
    rng = np.random.default_rng(42); count = 0
    for _ in range(n_perm):
        s = rng.permutation(sl_vals)
        if s[:n_mask].mean()-s.mean() >= observed: count += 1
    return (count+1)/(n_perm+1)

def _fisher_p(pv):
    pv = [max(p,1e-10) for p in pv]
    return 1-stats.chi2.cdf(-2*np.sum(np.log(pv)), 2*len(pv))

def _bh(p_values, alpha):
    n = len(p_values); si = np.argsort(p_values); sp = np.array(p_values)[si]
    mask = np.zeros(n, dtype=bool)
    for rank, idx in enumerate(si, 1):
        if sp[rank-1] <= alpha*rank/n: mask[idx] = True
        else: break
    return mask

def _bci(v, alpha=0.10):
    a = np.array(v, dtype=float)
    if len(a) < 3: return (float(a.min()), float(a.max()))
    rng = np.random.default_rng(42)
    b = [rng.choice(a, size=len(a), replace=True).mean() for _ in range(BOOTSTRAP_N)]
    return (float(np.percentile(b, 100*alpha/2)), float(np.percentile(b, 100*(1-alpha/2))))


if __name__ == "__main__":
    run()
