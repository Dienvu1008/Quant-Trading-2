"""
vp_06_sizing_calibration.py — Lot Multiplier Calibration (Fractional Kelly)

Computes per-(symbol, setup) lot multipliers using:
  - Conditional EV: only scale up when EV is statistically above baseline
  - Fractional Kelly (25%): Kelly criterion capped at 25% to avoid over-leverage
  - Temporal stability: multiplier only valid if consistent across time folds
  - Minimum sample guard: needs MIN_OOS_TRADES OOS trades before any opinion
  - Output clipped to [MIN_MULT, MAX_MULT] to prevent extreme positions

Output:
  output/06_sizing_calibration/lot_multipliers.json
  output/06_sizing_calibration/lot_multipliers.csv
"""

import sys, json, warnings, time
import numpy as np
import pandas as pd
from pathlib import Path
from scipy import stats

warnings.filterwarnings("ignore")
_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))
from data_loader import (load_funnel, load_trades, merge_funnel_trades,
                         split_by_style, has_trail_styles, TRAIL_STYLES)

OUTPUT_DIR = _HERE / "output" / "06_sizing_calibration"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ─── Tuning constants ──────────────────────────────────────────
KELLY_FRACTION     = 0.25   # 25% Kelly — conservative
MIN_MULT           = 0.50   # never go below 50% of max lot
MAX_MULT           = 1.50   # never exceed 150% of max lot
NEUTRAL_MULT       = 1.00   # default when no opinion
MIN_OOS_TRADES     = 30     # minimum trades in OOS split before calibrating
OOS_RATIO          = 0.30   # last 30% of data = OOS
N_FOLDS            = 4      # walk-forward folds for stability check
MIN_FOLD_AGREE     = 0.70   # ≥70% folds must agree direction for multiplier to apply
PROFIT_COL         = "profitUSD"
# Minimum EV improvement over baseline to justify scaling up (absolute USD)
MIN_EV_TO_SCALE_UP = 0.0    # any positive EV qualifies (Kelly handles the rest)
# Significance threshold: t-test p-value on OOS fold profits
MAX_PVAL           = 0.10


def run(funnel_df=None, trade_df=None, all_results=None, production_style=1):
    t0 = time.time()
    print("\n" + "=" * 60)
    print("VP PHASE 06 — SIZING CALIBRATION (Fractional Kelly)")
    print("=" * 60)

    if funnel_df is None: funnel_df = load_funnel()
    if trade_df is None:  trade_df  = load_trades()

    merged_all = merge_funnel_trades(funnel_df, trade_df, tolerance_sec=14400, min_records=10)
    if merged_all is None or len(merged_all) < MIN_OOS_TRADES * 2:
        print("  [SKIP] Insufficient data"); return {"lot_multipliers": []}

    # Lot multipliers feed VPGetLotMultiplier (applied Live), so calibrate on the
    # PRODUCTION style. This also restores the i.i.d. assumption behind the Kelly
    # t-test/fold-agreement (one trade per signal instead of 3 correlated ones).
    # The full 3-style frame is kept to require the sizing edge (Kelly sign) to
    # hold across ALL exit styles before trusting a scale-up.
    multi_style = has_trail_styles(merged_all)
    prod_df, all_styles = split_by_style(merged_all, production_style)
    if multi_style:
        print(f"  [STYLE] production={production_style} baseline: "
              f"{len(prod_df)} trades (of {len(merged_all)} across all styles)")
    merged = prod_df
    if merged is None or len(merged) < MIN_OOS_TRADES * 2:
        print(f"  [SKIP] Insufficient production-style data "
              f"({0 if merged is None else len(merged)} < {MIN_OOS_TRADES*2})")
        return {"lot_multipliers": []}

    if "time" in merged.columns:
        merged = merged.sort_values("time").reset_index(drop=True)

    profits = merged[PROFIT_COL].values.astype(np.float64)
    symbol_arr = merged["symbol"].values if "symbol" in merged.columns else np.full(len(merged), "_GLOBAL")
    setup_arr  = merged["setupType"].values if "setupType" in merged.columns else np.full(len(merged), "ALL")

    n_total = len(merged)
    print(f"  Records: {n_total:,} | WR={np.mean(profits>0):.1%} | EV=${np.mean(profits):.2f}")

    results = []
    groups = {}

    # Build (symbol, setup) groups + _GLOBAL pseudo-group
    for sym in np.unique(symbol_arr):
        for setup in np.unique(setup_arr[symbol_arr == sym]):
            key = (sym, setup)
            idx = np.where((symbol_arr == sym) & (setup_arr == setup))[0]
            if len(idx) >= MIN_OOS_TRADES * 2:
                groups[key] = idx

    # Add global group per setup
    for setup in np.unique(setup_arr):
        key = ("_GLOBAL", setup)
        idx = np.where(setup_arr == setup)[0]
        if len(idx) >= MIN_OOS_TRADES * 2:
            groups[key] = idx

    print(f"  Groups to calibrate: {len(groups)}")

    for (sym, setup), idx in groups.items():
        p = profits[idx]
        mult, meta = _calibrate(p, sym, setup)
        rec = {
            "symbol":      sym,
            "setup":       setup,
            "lot_mult":    round(float(mult), 4),
            "n_total":     int(len(p)),
            "n_oos":       int(meta["n_oos"]),
            "wr_oos":      round(float(meta["wr_oos"]), 4),
            "ev_oos":      round(float(meta["ev_oos"]), 4),
            "kelly_raw":   round(float(meta["kelly_raw"]), 4),
            "kelly_frac":  round(float(meta["kelly_frac"]), 4),
            "fold_agree":  round(float(meta["fold_agree"]), 4),
            "pval_oos":    round(float(meta["pval_oos"]), 4),
            "validated":   bool(meta["validated"]),
            "reason":      meta["reason"],
        }
        results.append(rec)
        tag = "[OK]" if meta["validated"] else "[--]"
        print(f"  {tag} {sym:<12} {setup:<20} mult={mult:.2f}  "
              f"EV=${meta['ev_oos']:+.2f}  WR={meta['wr_oos']:.1%}  "
              f"K={meta['kelly_frac']:.2f}  folds={meta['fold_agree']:.0%}  "
              f"p={meta['pval_oos']:.3f}")

    # ── Robustness across trailing styles ────────────────────────
    # A sizing edge should not depend on the exit policy: require the Kelly sign
    # (edge direction) to match across all 3 trailing styles before trusting a
    # scale-up/scale-down. Adds robust_across_styles + kelly_by_style per group.
    if results and multi_style:
        _robustness_check(results, all_styles)
        n_robust = sum(1 for r in results if r.get("robust_across_styles"))
        print(f"  Robust across all 3 styles: {n_robust}/{len(results)}")

    # Sort: validated first, then by lot_mult descending
    results.sort(key=lambda r: (-int(r["validated"]), -r["lot_mult"]))

    # Save outputs
    json_path = OUTPUT_DIR / "lot_multipliers.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    csv_path = OUTPUT_DIR / "lot_multipliers.csv"
    pd.DataFrame(results).to_csv(csv_path, index=False, encoding="utf-8")

    validated = [r for r in results if r["validated"]]
    scale_up  = [r for r in validated if r["lot_mult"] > NEUTRAL_MULT]
    scale_dn  = [r for r in validated if r["lot_mult"] < NEUTRAL_MULT]

    print(f"\n  Validated: {len(validated)} / {len(results)}")
    print(f"  Scale UP  (mult>{NEUTRAL_MULT}): {len(scale_up)}")
    print(f"  Scale DOWN(mult<{NEUTRAL_MULT}): {len(scale_dn)}")
    print(f"  JSON: {json_path}")
    print(f"  CSV:  {csv_path}")
    print(f"  Time: {time.time()-t0:.1f}s")

    return {"lot_multipliers": results}


# ──────────────────────────────────────────────────────────────
def _calibrate(profits: np.ndarray, sym: str, setup: str):
    """Return (final_multiplier, metadata_dict) for one (symbol, setup) group."""
    n = len(profits)
    split = int(n * (1 - OOS_RATIO))
    oos   = profits[split:]

    if len(oos) < MIN_OOS_TRADES:
        return NEUTRAL_MULT, _no_opinion("oos_too_small")

    wr_oos = np.mean(oos > 0)
    ev_oos = np.mean(oos)

    # ─── Kelly calculation (standard formula) ──────────────────
    # K = WR - (1-WR)/b  where b = avg_win / avg_loss (win/loss ratio)
    # Range: K in (-inf, 1]. K>0 means edge exists, K<0 means no edge.
    wins  = oos[oos > 0]
    loses = oos[oos < 0]

    if len(wins) == 0 or len(loses) == 0:
        return NEUTRAL_MULT, _no_opinion("no_wins_or_losses")

    avg_win  = np.mean(wins)
    avg_loss = np.abs(np.mean(loses))
    b = avg_win / avg_loss  # win/loss ratio (dimensionless)

    # Standard Kelly: K = WR - (1-WR)/b
    kelly_raw  = wr_oos - (1 - wr_oos) / b
    # Fractional Kelly (25%) — the portion we actually act on
    kelly_frac = kelly_raw * KELLY_FRACTION

    # ─── Walk-forward fold consistency (expanding train window) ───
    step = max(1, n // (N_FOLDS + 1))
    gap  = max(1, int(n * 0.05))
    fold_kellys = []
    for i in range(N_FOLDS):
        te = step * (i + 1)
        vs = te + gap
        ve = min(vs + step, n)
        if ve - vs < 5: continue
        fp = profits[vs:ve]
        if len(fp) < 5: continue
        fw = fp[fp > 0]
        fl = fp[fp < 0]
        if len(fw) == 0 or len(fl) == 0: continue
        fwr = np.mean(fp > 0)
        fb  = np.mean(fw) / np.abs(np.mean(fl))
        fk  = fwr - (1 - fwr) / fb
        fold_kellys.append(fk)

    if len(fold_kellys) < 2:
        return NEUTRAL_MULT, _no_opinion("insufficient_folds")

    agree_sign = np.sign(kelly_raw)
    fold_agree = np.mean([np.sign(k) == agree_sign for k in fold_kellys])

    # ─── Statistical significance (t-test on OOS profits) ──────
    if len(oos) >= 2:
        _, pval_oos = stats.ttest_1samp(oos, 0)
    else:
        pval_oos = 1.0

    # ─── Validation gates ──────────────────────────────────────
    reason = "ok"
    validated = True

    if fold_agree < MIN_FOLD_AGREE:
        validated = False
        reason = f"fold_unstable({fold_agree:.0%})"
    elif pval_oos > MAX_PVAL:
        validated = False
        reason = f"not_significant(p={pval_oos:.3f})"
    elif len(oos) < MIN_OOS_TRADES:
        validated = False
        reason = "oos_too_small"

    # ─── Compute final multiplier ───────────────────────────────
    # kelly_frac is now properly in a useful range (e.g. -0.30 to +0.25).
    # Map linearly: kelly_frac=0 → 1.0, kelly_frac=+KELLY_FRACTION → MAX_MULT,
    #               kelly_frac=-KELLY_FRACTION → MIN_MULT
    if not validated:
        final_mult = NEUTRAL_MULT
    else:
        if kelly_frac >= 0:
            norm = min(1.0, kelly_frac / KELLY_FRACTION) if KELLY_FRACTION > 0 else 0
            final_mult = NEUTRAL_MULT + norm * (MAX_MULT - NEUTRAL_MULT)
        else:
            norm = min(1.0, abs(kelly_frac) / KELLY_FRACTION) if KELLY_FRACTION > 0 else 0
            final_mult = NEUTRAL_MULT - norm * (NEUTRAL_MULT - MIN_MULT)

        final_mult = float(np.clip(final_mult, MIN_MULT, MAX_MULT))

    meta = {
        "n_oos":       len(oos),
        "wr_oos":      wr_oos,
        "ev_oos":      ev_oos,
        "kelly_raw":   kelly_raw,
        "kelly_frac":  kelly_frac,
        "fold_agree":  fold_agree,
        "pval_oos":    pval_oos,
        "validated":   validated,
        "reason":      reason,
    }
    return final_mult, meta


def _no_opinion(reason: str) -> dict:
    return {
        "n_oos": 0, "wr_oos": 0.0, "ev_oos": 0.0,
        "kelly_raw": 0.0, "kelly_frac": 0.0,
        "fold_agree": 0.0, "pval_oos": 1.0,
        "validated": False, "reason": reason,
    }


def _kelly_raw(profits):
    """Standard Kelly K = WR - (1-WR)/b on a profit array, or None if degenerate."""
    p = np.asarray(profits, dtype=np.float64)
    wins = p[p > 0]; loses = p[p < 0]
    if len(wins) == 0 or len(loses) == 0:
        return None
    b = np.mean(wins) / np.abs(np.mean(loses))
    if b <= 0:
        return None
    wr = np.mean(p > 0)
    return wr - (1 - wr) / b


def _robustness_check(results, all_styles, min_per_style=MIN_OOS_TRADES):
    """For each (symbol, setup) group, compute Kelly per trailing style. The
    sizing edge is robust iff all 3 styles have >= min_per_style trades AND their
    Kelly values share the same sign (edge direction independent of exit policy).
    Writes robust_across_styles + kelly_by_style into each result dict.
    """
    if "trailStyle" not in all_styles.columns or PROFIT_COL not in all_styles.columns:
        for r in results:
            r["robust_across_styles"] = False
        return results

    m = all_styles.copy()
    m["trailStyle"] = pd.to_numeric(m["trailStyle"], errors="coerce")
    m = m[m["trailStyle"].isin(TRAIL_STYLES)]
    has_sym = "symbol" in m.columns
    has_setup = "setupType" in m.columns

    for r in results:
        sub = m
        if has_sym and r["symbol"] != "_GLOBAL":
            sub = sub[sub["symbol"] == r["symbol"]]
        if has_setup and r["setup"] != "ALL":
            sub = sub[sub["setupType"] == r["setup"]]

        kelly_by_style = {}
        for style in TRAIL_STYLES:
            s = sub[sub["trailStyle"] == style]
            prof = pd.to_numeric(s[PROFIT_COL], errors="coerce").dropna().values
            if len(prof) < min_per_style:
                kelly_by_style[style] = None
            else:
                k = _kelly_raw(prof)
                kelly_by_style[style] = None if k is None else float(k)

        r["kelly_by_style"] = {str(s): (None if kelly_by_style.get(s) is None
                                        else round(kelly_by_style[s], 4)) for s in TRAIL_STYLES}
        present = [kelly_by_style.get(s) for s in TRAIL_STYLES]
        if all(v is not None for v in present):
            signs = {np.sign(v) for v in present if v != 0}
            r["robust_across_styles"] = (len(signs) == 1)
        else:
            r["robust_across_styles"] = False
    return results


if __name__ == "__main__":
    run()
