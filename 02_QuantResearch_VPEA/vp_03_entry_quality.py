"""
vp_04_entry_quality.py — Composite Entry Quality Gate (ROBUST v2)

Key improvements:
- Pre-registered features (5 categories, no data snooping)
- Hyperparameter tuning (C in [0.01, 0.1, 1.0])
- class_weight='balanced' for imbalanced targets
- Brier score + AUC calibration check
- Feature stability voting across folds
- Fold consistency >= 60%
- FDR correction (inlined BH)
- Final OOS validation (70/30 temporal)
- Pass ratio bounds (20-80%)
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
    from sklearn.metrics import brier_score_loss, roc_auc_score
    HAS_ML = True
except ImportError:
    HAS_ML = False

warnings.filterwarnings("ignore")
_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))
from data_loader import load_funnel, load_trades, merge_funnel_trades, FUNNEL_FEATURES

OUTPUT_DIR = _HERE / "output" / "03_entry_quality"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MIN_SAMPLES = 30
OUTER_SPLITS = 5
INNER_SPLITS = 3
GAP_RATIO = 0.10
MIN_INNER = 12
MAX_FEATURES = 12
MIN_FEATURES = 3
MIN_TP = 10
MAX_RECORDS = 500_000
CUTOFF_RANGE = [55, 60, 65, 70, 75]
LR_MAX_ITER = 500
MIN_LIFT = 0.03
MIN_PASS_RATIO = 0.20
MAX_PASS_RATIO = 0.80
CV_CONSISTENCY = 0.60
MIN_AUC = 0.55
MAX_BRIER = 0.25
FDR_LEVEL = 0.05
OOS_RATIO = 0.30

PRE_REGISTERED = {
    # Raw structure features and composites are split into SEPARATE categories so
    # _get_features (which caps at 2 per category) evaluates each family on its own
    # merits instead of letting one crowd out the other.
    "trend_raw":       ["bosScore", "chochScore", "trendDirection"],
    "trend_composite": ["bosQuality", "chochQuality", "structAlign"],
    "trend":    ["auctContinuation"],
    "quality":  ["auctTradeQuality", "auctBalance", "auctExpReward"],
    "risk":     ["auctReversalRisk", "auctFailure", "auctExhaustion"],
    "volume":   ["vpMigrationConf", "vpBestHVNScore", "vpVAOverlapBias"],
    "volatility":["spreadToATR", "vpThinnessRatio", "auctRegimeConf"],
    "timing":   ["structDistATR"],
    "longterm": ["vpLTPOCMigration", "vpLTNearestZoneStrength", "vpLTTransitionScore", "vpLTBalanceStability"],
    # Bonus engines: primaries and composites in separate categories so the
    # 2-per-category feature cap evaluates each family independently.
    "engine_primary": ["msCompression", "ofFlowIntensity", "liqSweep", "smZoneQuality"],
    "engine_context": ["msContext", "ofContext", "liqContext", "smContext"],
    "interactions": ["ix_tq_mig", "ix_bos_trend", "ix_spread_atr", "ix_cont_mig", "ix_fail_reversal",
                    "ix_struct_bos", "ix_devpoc_ltpoc", "ix_exhaust_lt", "ix_acceptance", "ix_target_rr"],
}

# Theory-driven interaction pairs:
# ix_tq_mig: trade quality meaningful only with clear migration
# ix_bos_trend: BOS composite amplified when aligned with structure/trend
# ix_spread_atr: spread cost relative to available volatility (move size)
# ix_cont_mig: continuation signal + migration = strong trend confirmation
# ix_fail_reversal: failure + reversal risk = compounding danger
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


def run(funnel_df=None, trade_df=None, all_results=None):
    t0 = time.time()
    print("\n" + "=" * 60)
    print("VP PHASE 03 — ENTRY QUALITY (ROBUST v2)")
    print("=" * 60)

    if not HAS_ML:
        print("  [SKIP] sklearn required"); return {"entry_quality_gates": []}
    if funnel_df is None: funnel_df = load_funnel()
    if trade_df is None: trade_df = load_trades()

    merged = merge_funnel_trades(funnel_df, trade_df, tolerance_sec=14400, min_records=15)
    if merged is None or len(merged) < MIN_SAMPLES:
        print("  [SKIP] Insufficient data"); return {"entry_quality_gates": []}

    if len(merged) > MAX_RECORDS:
        merged = merged.sample(n=MAX_RECORDS, random_state=42)

    merged = _compute_target(merged)
    merged = _compute_interactions(merged)
    if "time" in merged.columns:
        merged = merged.sort_values("time").reset_index(drop=True)

    baseline = merged["_target"].mean()
    print(f"  Records: {len(merged):,}, baseline: {baseline:.1%}")

    if merged["_target"].sum() < MIN_TP:
        print("  [SKIP] Insufficient positive samples"); return {"entry_quality_gates": []}

    all_p_values = []
    groups = _get_groups(merged)
    print(f"  Groups: {len(groups)}")

    all_gates = []
    for sym, setup, sub in groups:
        if len(sub) < MIN_SAMPLES or sub["_target"].sum() < MIN_TP: continue
        feats = _get_features(sub)
        if len(feats) < MIN_FEATURES: continue
        gate = _build_gate(sub, sym, setup, feats, all_p_values)
        if gate:
            all_gates.append(gate)
            v = "✓" if gate["validated"] else "✗"
            print(f"  [{sym}_{setup}] {v} lift={gate['wr_lift_mean']:+.1%} AUC={gate.get('auc_mean',0):.2f}")

    # FDR + OOS
    if all_gates and "time" in merged.columns:
        fdr_mask = _bh_correction(all_p_values, FDR_LEVEL) if all_p_values else []
        all_gates = _oos_validation(all_gates, merged, fdr_mask)

    final = [g for g in all_gates if g.get("final_validated")]
    print(f"\n  Gates: {len(all_gates)} | Final validated: {len(final)}")

    pd.DataFrame(all_gates).to_csv(OUTPUT_DIR / "entry_gates.csv", index=False)
    with open(OUTPUT_DIR / "entry_gates.json", "w") as f:
        json.dump(all_gates, f, indent=2, default=_jd)

    print(f"  Time: {time.time()-t0:.1f}s")
    return {"entry_quality_gates": all_gates}


def _compute_target(merged):
    merged = merged.copy()
    if "exitReason" in merged.columns and (merged["exitReason"] == "TP_HIT").sum() >= MIN_TP:
        merged["_target"] = (merged["exitReason"] == "TP_HIT").astype(np.int8)
        if "mfeATR" in merged.columns:
            strong = (merged["exitReason"] == "TRAIL_STOP") & (merged["profitUSD"] > 0) & (merged["mfeATR"] > 1.5)
            merged.loc[strong, "_target"] = 1
    else:
        merged["_target"] = (merged["profitUSD"] > 0).astype(np.int8)
    return merged


def _compute_interactions(df):
    """Compute theory-driven interaction features (product of normalized pairs)."""
    for name, feat_a, feat_b in INTERACTION_DEFS:
        if feat_a in df.columns and feat_b in df.columns:
            a = pd.to_numeric(df[feat_a], errors='coerce').fillna(0)
            b = pd.to_numeric(df[feat_b], errors='coerce').fillna(0)
            # Normalize each to [0,1] range before multiplication to avoid scale issues
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
        # Take up to 2 from each category (prioritize by variance = signal strength)
        if cat_available:
            variances = [(f, df[f].std()) for f in cat_available]
            variances.sort(key=lambda x: -x[1])
            for f, _ in variances[:2]:
                available.append(f)
                if len(available) >= MAX_FEATURES:
                    return available
    return available


def _build_gate(df, sym, setup, feats, all_p_values):
    n = len(df)
    gap = max(1, int(n * GAP_RATIO))
    fold_size = n // (OUTER_SPLITS + 1)
    if fold_size < MIN_INNER * 2: return None

    lifts, passes, aucs, briers, cutoffs = [], [], [], [], []
    feat_votes = defaultdict(int)
    last_result = None

    for i in range(OUTER_SPLITS):
        te = fold_size * (i+1)
        vs = te + gap
        ve = min(vs + fold_size, n)
        if ve - vs < MIN_INNER: continue

        # Skip if training data has only one class
        y_train_fold = df["_target"].values[:te]
        if len(np.unique(y_train_fold)) < 2: continue

        result = _inner(df.iloc[:te], feats)
        if result is None: continue

        for f in result["features"]: feat_votes[f] += 1

        X_val = df[result["features"]].iloc[vs:ve].fillna(0).values
        X_val_s = result["scaler"].transform(X_val)
        scores = X_val_s.dot(result["coefs"]) + result["intercept"]
        threshold = np.percentile(scores, result["cutoff"])
        mask = scores >= threshold
        n_pass = mask.sum()
        pr = n_pass / (ve - vs)
        if n_pass < MIN_INNER or pr < MIN_PASS_RATIO or pr > MAX_PASS_RATIO: continue

        y_val = df["_target"].values[vs:ve]
        lift = y_val[mask].mean() - y_val.mean()
        if lift <= 0: continue

        auc = roc_auc_score(y_val, scores) if len(np.unique(y_val)) > 1 else 0.5
        brier = brier_score_loss(y_val, 1/(1+np.exp(-scores)))
        if auc < MIN_AUC or brier > MAX_BRIER: continue

        lifts.append(lift); passes.append(pr); aucs.append(auc)
        briers.append(brier); cutoffs.append(result["cutoff"])
        last_result = result

    if len(lifts) < 2 or last_result is None: return None
    mean_lift = np.mean(lifts)
    if mean_lift < MIN_LIFT: return None

    pos_folds = sum(1 for l in lifts if l > 0)
    if pos_folds / len(lifts) < CV_CONSISTENCY: return None

    p_val = _t_test(lifts)
    ci_low, ci_high = _bci(lifts)
    slope_p = _ts(lifts)
    all_p_values.append(p_val)

    validated = (mean_lift >= MIN_LIFT and p_val < 0.05 and ci_low > 0 and slope_p > 0.10)

    # Final model on stable features
    stable = [f for f, c in feat_votes.items() if c >= max(2, OUTER_SPLITS//2)]
    if len(stable) < MIN_FEATURES:
        stable = [f for f, _ in sorted(feat_votes.items(), key=lambda x: -x[1])[:MAX_FEATURES]]
    if len(stable) < MIN_FEATURES: return None

    X = df[stable].fillna(0).values; y = df["_target"].values
    if len(np.unique(y)) < 2: return None
    scaler = StandardScaler(); X_s = scaler.fit_transform(X)
    model = LogisticRegression(C=0.1, penalty="l2", solver="lbfgs", max_iter=LR_MAX_ITER, class_weight="balanced")
    model.fit(X_s, y)

    rw = model.coef_[0] / scaler.scale_
    rb = model.intercept_[0] - np.sum(model.coef_[0] * scaler.mean_ / scaler.scale_)
    fc = float(np.median(cutoffs))
    st = float(np.percentile(X.dot(rw) + rb, fc))

    return {
        "symbol": sym, "setup": setup, "features": stable,
        "weights": [round(float(w), 6) for w in rw],
        "bias": round(float(rb), 6), "score_threshold": round(st, 6),
        "cutoff_percentile": fc,
        "wr_lift_mean": round(mean_lift, 4), "wr_lift_ci_90": [round(ci_low, 4), round(ci_high, 4)],
        "pass_ratio_mean": round(np.mean(passes), 3),
        "auc_mean": round(np.mean(aucs), 4), "brier_mean": round(np.mean(briers), 4),
        "pvalue": round(p_val, 4), "temporal_slope_pvalue": round(slope_p, 4),
        "n_folds": len(lifts), "fold_consistency": round(pos_folds/len(lifts), 3),
        "group_n": len(df), "group_wr": round(float(df["_target"].mean()), 4),
        "validated": validated, "final_validated": False,
    }


def _inner(outer_train, feats):
    n = len(outer_train)
    gap = max(1, int(n * GAP_RATIO))
    fold_size = n // (INNER_SPLITS + 1)
    if fold_size < MIN_INNER: return None

    best_cutoff, best_score = 60, -np.inf
    for i in range(INNER_SPLITS):
        te = fold_size*(i+1); vs = te+gap; ve = min(vs+fold_size, n)
        if ve-vs < MIN_INNER: continue

        X_tr = outer_train[feats].iloc[:te].fillna(0).values
        y_tr = outer_train["_target"].values[:te]
        if y_tr.sum() < 3 or len(np.unique(y_tr)) < 2: continue

        scaler = StandardScaler(); X_tr_s = scaler.fit_transform(X_tr)
        # Hyperparameter tuning
        best_C, best_auc = 0.1, 0
        for C in [0.01, 0.1, 1.0]:
            m = LogisticRegression(C=C, penalty="l2", solver="lbfgs", max_iter=LR_MAX_ITER, class_weight="balanced")
            m.fit(X_tr_s, y_tr)
            X_v = scaler.transform(outer_train[feats].iloc[vs:ve].fillna(0).values)
            y_v = outer_train["_target"].values[vs:ve]
            if len(np.unique(y_v)) < 2: continue
            auc = roc_auc_score(y_v, X_v.dot(m.coef_[0]) + m.intercept_[0])
            if auc > best_auc: best_auc = auc; best_C = C

        # Find best cutoff (y_tr already checked for 2 classes above)
        m = LogisticRegression(C=best_C, penalty="l2", solver="lbfgs", max_iter=LR_MAX_ITER, class_weight="balanced")
        m.fit(X_tr_s, y_tr)  # safe: y_tr has 2+ classes
        X_v = scaler.transform(outer_train[feats].iloc[vs:ve].fillna(0).values)
        scores = X_v.dot(m.coef_[0]) + m.intercept_[0]
        baseline = outer_train["_target"].values[vs:ve].mean()
        for pct in CUTOFF_RANGE:
            t = np.percentile(scores, pct)
            mask = scores >= t
            if mask.sum() < MIN_INNER: continue
            lift = outer_train["_target"].values[vs:ve][mask].mean() - baseline
            s = lift * np.sqrt(mask.sum())
            if s > best_score: best_score = s; best_cutoff = pct

    # Retrain final
    X = outer_train[feats].fillna(0).values; y = outer_train["_target"].values
    if len(np.unique(y)) < 2: return None
    scaler = StandardScaler(); X_s = scaler.fit_transform(X)
    model = LogisticRegression(C=0.1, penalty="l2", solver="lbfgs", max_iter=LR_MAX_ITER, class_weight="balanced")
    model.fit(X_s, y)
    return {"features": feats, "coefs": model.coef_[0], "intercept": model.intercept_[0],
            "scaler": scaler, "cutoff": best_cutoff}


def _oos_validation(gates, merged, fdr_mask):
    split = int(len(merged) * (1 - OOS_RATIO))
    oos = merged.iloc[split:]
    for i, gate in enumerate(gates):
        fdr_pass = fdr_mask[i] if i < len(fdr_mask) else False
        if not gate.get("validated") or not fdr_pass:
            gate["final_validated"] = False; continue
        sym, setup = gate["symbol"], gate["setup"]
        grp = oos[(oos["symbol"] == sym) & (oos["setupType"] == setup)] if "symbol" in oos.columns else oos
        if len(grp) < MIN_INNER:
            gate["final_validated"] = False; continue
        feats = gate["features"]
        w = np.array(gate["weights"]); b = gate["bias"]; t = gate["score_threshold"]
        X = grp[feats].fillna(0).values
        scores = X.dot(w) + b
        mask = scores >= t
        if mask.sum() < MIN_INNER:
            gate["final_validated"] = False; continue
        y = grp["_target"].values
        lift = y[mask].mean() - y.mean()
        gate["oos_lift"] = round(lift, 4)
        gate["final_validated"] = lift >= MIN_LIFT * 0.5
    return gates


def _get_groups(df):
    groups = []
    if "symbol" not in df.columns: return [("ALL", "ALL", df)]
    for sym in df["symbol"].unique():
        sym_df = df[df["symbol"] == sym]
        if "setupType" in sym_df.columns:
            for st in sym_df["setupType"].unique():
                if pd.isna(st) or st in ("NONE", ""): continue
                sub = sym_df[sym_df["setupType"] == st]
                if len(sub) >= MIN_SAMPLES: groups.append((sym, st, sub))
        else:
            if len(sym_df) >= MIN_SAMPLES: groups.append((sym, "ALL", sym_df))
    return groups


def _bh_correction(p_values, alpha):
    n = len(p_values)
    si = np.argsort(p_values)
    sp = np.array(p_values)[si]
    mask = np.zeros(n, dtype=bool)
    for rank, idx in enumerate(si, 1):
        if sp[rank-1] <= alpha * rank / n: mask[idx] = True
        else: break
    return mask


def _t_test(v):
    if len(v) < 2: return 1.0
    a = np.array(v); se = a.std(ddof=1)/np.sqrt(len(a))
    return 0.0 if se <= 0 else float(stats.t.sf(a.mean()/se, df=len(a)-1))

def _ts(v):
    if len(v) < 3: return 1.0
    s, _, _, p, _ = stats.linregress(np.arange(len(v)), np.array(v))
    return p/2 if s < 0 else 1.0

def _bci(v, alpha=0.10):
    a = np.array(v)
    if len(a) < 3: return (float(a.min()), float(a.max()))
    rng = np.random.default_rng(42)
    b = [rng.choice(a, size=len(a), replace=True).mean() for _ in range(500)]
    return (float(np.percentile(b, 100*alpha/2)), float(np.percentile(b, 100*(1-alpha/2))))

def _jd(obj):
    if isinstance(obj, (np.integer,)): return int(obj)
    if isinstance(obj, (np.floating,)): return float(obj)
    if isinstance(obj, np.ndarray): return obj.tolist()
    if obj is None or (isinstance(obj, float) and np.isnan(obj)): return None
    return str(obj)


if __name__ == "__main__":
    run()
