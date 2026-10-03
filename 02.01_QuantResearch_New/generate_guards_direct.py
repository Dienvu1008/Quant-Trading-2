"""
generate_guards_direct.py -- Generate EdgeGuard config from L4/L5 dev candidates.

WARNING: RESEARCH MODE - Gates validated on dev data only, NOT holdout-confirmed.
Use with small position sizes for out-of-sample evidence collection.

Usage:
    python generate_guards_direct.py
    python generate_guards_direct.py --min-ev 0.05 --min-wr 0.40 --min-fc 0.60
    python generate_guards_direct.py --exp EXP-2026-09-21-001
"""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

_ROOT = Path(__file__).parent.resolve()
sys.path.insert(0, str(_ROOT))

OUTPUT_GUARDS = _ROOT / "output" / "guards"

EA_CONFIG_DIR = Path(
    r"C:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal"
    r"\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\My own robots"
    r"\Quant Trading 2\01_EA_VP\Config"
)


# Features that are Python-computed composites and NOT in old EA versions.
# After EA recompile with VPFunnelLogger update, these will be available.
# Until then, they will silently not match in VPGetEdgeMultiplier/Tilt.
_COMPOSITE_FEATURES = {
    # data_loader._build_structure_composites()
    "bosQuality", "chochQuality", "structAlign",
    # data_loader._build_engine_composites()
    "msContext", "ofContext", "liqContext", "smContext",
}

_COMPOSITE_NOTE = (
    "// NOTE: This feature is a Python composite computed from raw EA columns.\n"
    "// It requires EA VPFunnelLogger v2+ (with composite columns) to work.\n"
    "// If using older EA, this rule is harmlessly skipped (no match).\n"
)

def _latest_exp():
    exps = sorted((_ROOT / "output" / "experiments").glob("EXP-*"),
                  key=lambda p: p.name, reverse=True)
    return exps[0] if exps else None


def _get_median(medians, symbol, setup, feature):
    v = medians.get((symbol, setup, feature))
    if v is not None:
        return v
    return medians.get(("_global", "_global", feature))


def _compute_medians(soft, start, end):
    if soft.empty:
        return {}
    print("  Computing feature medians from dev data...")
    try:
        from data_loader import load_merged, split_by_style
    except ImportError:
        print("  [WARN] data_loader not available")
        return {}

    merged = load_merged(start=start, end=end)
    if merged is None or merged.empty:
        return {}

    prod, _ = split_by_style(merged, production_style=1)
    if prod.empty:
        prod = merged

    medians = {}
    for feat in soft["feature"].unique():
        if feat not in prod.columns:
            continue
        vals = pd.to_numeric(prod[feat], errors="coerce").dropna()
        if len(vals) == 0:
            continue
        if "symbol" in prod.columns and "setupType" in prod.columns:
            for (sym, stp), grp in prod.groupby(["symbol", "setupType"]):
                v = pd.to_numeric(grp[feat], errors="coerce").dropna()
                if len(v) >= 10:
                    medians[(sym, str(stp), feat)] = float(v.median())
        medians[("_global", "_global", feat)] = float(vals.median())

    print(f"  Computed {len(medians)} medians")
    return medians



def _cross_style_filter(hard: "pd.DataFrame", soft: "pd.DataFrame",
                        start, end,
                        min_lift: float = 0.05,
                        min_pass_n: int = 5) -> tuple:
    """Post-filter candidates using cross-style entry quality signal.

    For each gate, check that rows PASSING the gate have a meaningfully
    higher rate of _all_styles_win=1 than rows FAILING the gate.
    This confirms the gate is selecting genuinely good entries
    (all 3 trailing styles profitable), not just lucky production-style trades.

    Parameters
    ----------
    min_lift  : Minimum relative lift in all_styles_win rate required.
                lift = (win_rate_pass - win_rate_fail) / max(win_rate_fail, 0.01)
                Default 0.05 = gate region must have >= 5% more all-win signals.
    min_pass_n: Minimum rows in the gate region to compute reliable stats.

    Returns (filtered_hard, filtered_soft, report_lines)
    """
    import pandas as pd

    try:
        from data_loader import load_merged, split_by_style
    except ImportError:
        print("  [WARN] data_loader not available — skipping cross-style filter")
        return hard, soft, []

    merged = load_merged(start=start, end=end)
    if merged is None or merged.empty:
        print("  [WARN] No data for cross-style filter — skipping")
        return hard, soft, []

    # Use ALL rows (not just production) because _all_styles_win is per-signal
    # and the same value is broadcast to all 3 style rows
    if "_all_styles_win" not in merged.columns:
        print("  [WARN] _all_styles_win not in data — skipping cross-style filter")
        return hard, soft, []

    # Work with production-style rows for consistency with gate metrics
    prod, _ = split_by_style(merged, production_style=1)
    if prod.empty:
        prod = merged

    win_col = "_all_styles_win"
    base_rate = float(prod[win_col].mean()) if len(prod) > 0 else 0.0

    report = [f"  Cross-style filter (base all_win_rate={base_rate:.2%}):"]

    # ── Filter hard gates ──────────────────────────────────────
    if hard.empty:
        filtered_hard = hard
    else:
        keep_hard = []
        for _, r in hard.iterrows():
            feat = r.get("feature", "")
            if feat not in prod.columns:
                keep_hard.append(True)  # can't check → keep
                continue

            vals = pd.to_numeric(prod[feat], errors="coerce")
            gt = r.get("gate_type", "threshold")
            direction = int(r.get("direction", 1))
            lo = r.get("lower", None)
            hi = r.get("upper", None)

            # Build pass mask (rows that PASS the gate = allowed through)
            mask = pd.Series(False, index=prod.index)
            try:
                if gt == "threshold" and direction == 1 and pd.notna(lo):
                    mask = vals >= float(lo)
                elif gt == "threshold" and direction == -1 and pd.notna(hi):
                    mask = vals <= float(hi)
                elif gt == "band" and pd.notna(lo) and pd.notna(hi):
                    mask = (vals >= float(lo)) & (vals <= float(hi))
                else:
                    keep_hard.append(True)
                    continue
            except Exception:
                keep_hard.append(True)
                continue

            n_pass = int(mask.sum())
            if n_pass < min_pass_n:
                keep_hard.append(True)  # too few → can't judge
                continue

            pass_win = float(prod.loc[mask, win_col].mean())
            fail_win = float(prod.loc[~mask, win_col].mean()) if (~mask).sum() > 0 else base_rate
            lift = (pass_win - fail_win) / max(fail_win, 0.01)

            sym = r.get("symbol", "?"); stp = r.get("setup", "?")
            if lift >= -min_lift:  # pass: gate improves or neutral on entry quality
                keep_hard.append(True)
                if lift > 0.10:
                    report.append(f"    HARD KEEP  {sym}/{stp}/{feat}: pass_win={pass_win:.2%} fail_win={fail_win:.2%} lift={lift:+.2f}")
            else:
                keep_hard.append(False)
                report.append(f"    HARD DROP  {sym}/{stp}/{feat}: pass_win={pass_win:.2%} fail_win={fail_win:.2%} lift={lift:+.2f} [entry quality degrades]")

        filtered_hard = hard[keep_hard].reset_index(drop=True)
        n_dropped_h = len(hard) - len(filtered_hard)
        report.append(f"  Hard: {len(hard)} → {len(filtered_hard)} (dropped {n_dropped_h})")

    # ── Filter soft tilts ──────────────────────────────────────
    if soft.empty:
        filtered_soft = soft
    else:
        keep_soft = []
        for _, r in soft.iterrows():
            feat = r.get("feature", "")
            if feat not in prod.columns:
                keep_soft.append(True)
                continue

            vals = pd.to_numeric(prod[feat], errors="coerce")
            direction = int(r.get("direction", 1))
            lift_val = float(r.get("ev_lift", 0))

            # For soft tilts, the "good side" is defined by direction
            # direction=+1: high value is good → pass = top half
            # direction=-1: low value is good  → pass = bottom half
            try:
                median = float(vals.median())
                if direction == 1:
                    mask = vals >= median
                else:
                    mask = vals <= median
            except Exception:
                keep_soft.append(True)
                continue

            n_pass = int(mask.sum())
            if n_pass < min_pass_n:
                keep_soft.append(True)
                continue

            pass_win = float(prod.loc[mask, win_col].mean())
            fail_win = float(prod.loc[~mask, win_col].mean()) if (~mask).sum() > 0 else base_rate
            lift = (pass_win - fail_win) / max(fail_win, 0.01)

            # For soft tilts, be lenient — only drop if entry quality clearly degrades
            if lift >= -(min_lift * 2):
                keep_soft.append(True)
            else:
                keep_soft.append(False)
                sym = r.get("symbol", "?"); stp = r.get("setup", "?")
                report.append(f"    SOFT DROP  {sym}/{stp}/{feat}: pass_win={pass_win:.2%} fail_win={fail_win:.2%} lift={lift:+.2f}")

        filtered_soft = soft[keep_soft].reset_index(drop=True)
        n_dropped_s = len(soft) - len(filtered_soft)
        report.append(f"  Soft: {len(soft)} → {len(filtered_soft)} (dropped {n_dropped_s})")

    return filtered_hard, filtered_soft, report


def _cross_style_filter(hard: "pd.DataFrame", soft: "pd.DataFrame",
                        start, end,
                        min_lift: float = 0.05,
                        min_pass_n: int = 5) -> tuple:
    """Post-filter candidates using cross-style entry quality signal.

    For each gate, check that rows PASSING the gate have a meaningfully
    higher rate of _all_styles_win=1 than rows FAILING the gate.
    This confirms the gate is selecting genuinely good entries
    (all 3 trailing styles profitable), not just lucky production-style trades.

    Parameters
    ----------
    min_lift  : Minimum relative lift in all_styles_win rate required.
                lift = (win_rate_pass - win_rate_fail) / max(win_rate_fail, 0.01)
                Default 0.05 = gate region must have >= 5% more all-win signals.
    min_pass_n: Minimum rows in the gate region to compute reliable stats.

    Returns (filtered_hard, filtered_soft, report_lines)
    """
    import pandas as pd

    try:
        from data_loader import load_merged, split_by_style
    except ImportError:
        print("  [WARN] data_loader not available — skipping cross-style filter")
        return hard, soft, []

    merged = load_merged(start=start, end=end)
    if merged is None or merged.empty:
        print("  [WARN] No data for cross-style filter — skipping")
        return hard, soft, []

    # Use ALL rows (not just production) because _all_styles_win is per-signal
    # and the same value is broadcast to all 3 style rows
    if "_all_styles_win" not in merged.columns:
        print("  [WARN] _all_styles_win not in data — skipping cross-style filter")
        return hard, soft, []

    # Work with production-style rows for consistency with gate metrics
    prod, _ = split_by_style(merged, production_style=1)
    if prod.empty:
        prod = merged

    win_col = "_all_styles_win"
    base_rate = float(prod[win_col].mean()) if len(prod) > 0 else 0.0

    report = [f"  Cross-style filter (base all_win_rate={base_rate:.2%}):"]

    # ── Filter hard gates ──────────────────────────────────────
    if hard.empty:
        filtered_hard = hard
    else:
        keep_hard = []
        for _, r in hard.iterrows():
            feat = r.get("feature", "")
            if feat not in prod.columns:
                keep_hard.append(True)  # can't check → keep
                continue

            vals = pd.to_numeric(prod[feat], errors="coerce")
            gt = r.get("gate_type", "threshold")
            direction = int(r.get("direction", 1))
            lo = r.get("lower", None)
            hi = r.get("upper", None)

            # Build pass mask (rows that PASS the gate = allowed through)
            mask = pd.Series(False, index=prod.index)
            try:
                if gt == "threshold" and direction == 1 and pd.notna(lo):
                    mask = vals >= float(lo)
                elif gt == "threshold" and direction == -1 and pd.notna(hi):
                    mask = vals <= float(hi)
                elif gt == "band" and pd.notna(lo) and pd.notna(hi):
                    mask = (vals >= float(lo)) & (vals <= float(hi))
                else:
                    keep_hard.append(True)
                    continue
            except Exception:
                keep_hard.append(True)
                continue

            n_pass = int(mask.sum())
            if n_pass < min_pass_n:
                keep_hard.append(True)  # too few → can't judge
                continue

            pass_win = float(prod.loc[mask, win_col].mean())
            fail_win = float(prod.loc[~mask, win_col].mean()) if (~mask).sum() > 0 else base_rate
            lift = (pass_win - fail_win) / max(fail_win, 0.01)

            sym = r.get("symbol", "?"); stp = r.get("setup", "?")
            if lift >= -min_lift:  # pass: gate improves or neutral on entry quality
                keep_hard.append(True)
                if lift > 0.10:
                    report.append(f"    HARD KEEP  {sym}/{stp}/{feat}: pass_win={pass_win:.2%} fail_win={fail_win:.2%} lift={lift:+.2f}")
            else:
                keep_hard.append(False)
                report.append(f"    HARD DROP  {sym}/{stp}/{feat}: pass_win={pass_win:.2%} fail_win={fail_win:.2%} lift={lift:+.2f} [entry quality degrades]")

        filtered_hard = hard[keep_hard].reset_index(drop=True)
        n_dropped_h = len(hard) - len(filtered_hard)
        report.append(f"  Hard: {len(hard)} → {len(filtered_hard)} (dropped {n_dropped_h})")

    # ── Filter soft tilts ──────────────────────────────────────
    if soft.empty:
        filtered_soft = soft
    else:
        keep_soft = []
        for _, r in soft.iterrows():
            feat = r.get("feature", "")
            if feat not in prod.columns:
                keep_soft.append(True)
                continue

            vals = pd.to_numeric(prod[feat], errors="coerce")
            direction = int(r.get("direction", 1))
            lift_val = float(r.get("ev_lift", 0))

            # For soft tilts, the "good side" is defined by direction
            # direction=+1: high value is good → pass = top half
            # direction=-1: low value is good  → pass = bottom half
            try:
                median = float(vals.median())
                if direction == 1:
                    mask = vals >= median
                else:
                    mask = vals <= median
            except Exception:
                keep_soft.append(True)
                continue

            n_pass = int(mask.sum())
            if n_pass < min_pass_n:
                keep_soft.append(True)
                continue

            pass_win = float(prod.loc[mask, win_col].mean())
            fail_win = float(prod.loc[~mask, win_col].mean()) if (~mask).sum() > 0 else base_rate
            lift = (pass_win - fail_win) / max(fail_win, 0.01)

            # For soft tilts, be lenient — only drop if entry quality clearly degrades
            if lift >= -(min_lift * 2):
                keep_soft.append(True)
            else:
                keep_soft.append(False)
                sym = r.get("symbol", "?"); stp = r.get("setup", "?")
                report.append(f"    SOFT DROP  {sym}/{stp}/{feat}: pass_win={pass_win:.2%} fail_win={fail_win:.2%} lift={lift:+.2f}")

        filtered_soft = soft[keep_soft].reset_index(drop=True)
        n_dropped_s = len(soft) - len(filtered_soft)
        report.append(f"  Soft: {len(soft)} → {len(filtered_soft)} (dropped {n_dropped_s})")

    return filtered_hard, filtered_soft, report


def _generate_bad_entry_mqh(filter_spec: dict) -> str:
    """Generate MQL5 VPBadEntryVote() from L10 composite_bad_filter.json.

    Design: simple per-symbol/setup function. Receives one (feature, value) pair,
    checks ALL rules for that symbol+setup in a single scan, returns true if
    accumulated votes across ALL rules >= min_votes.

    The EA calls this once per feature — the function keeps an internal
    vote counter using a file-scope (not static) approach: each call adds
    its vote and the LAST call (sentinel "__check__") returns the result.

    Cleaner alternative: use a dedicated per-symbol helper that takes all
    feature values directly via explicit parameters. We use the sentinel
    approach here because the number of features varies per group and MQL5
    does not support variadic functions.

    NOTE: static variables in MQL5 are per-EA-instance (not per-symbol),
    so we must reset at the start of every signal evaluation to avoid
    cross-signal contamination.
    """
    min_votes = int(filter_spec.get("min_votes", 2))
    groups: dict = filter_spec.get("groups", {})
    global_fallback: dict = filter_spec.get("global_fallback", {})
    if not groups and not global_fallback:
        global_fallback = filter_spec
    total_rules = sum(len(v.get("features", [])) for v in groups.values())

    if total_rules == 0:
        return ""

    def _emit_rule(r: dict, feat_var: str, val_var: str, indent: str) -> str:
        feat = r["feature"]
        rt   = r["rule_type"]
        lo   = r.get("threshold_low")
        hi   = r.get("threshold_high")
        if rt == "low_extreme" and lo is not None:
            return f'{indent}if({feat_var}=="{feat}" && {val_var}<={float(lo):.6f}) _g_bev_votes++;'
        elif rt == "high_extreme" and hi is not None:
            return f'{indent}if({feat_var}=="{feat}" && {val_var}>={float(hi):.6f}) _g_bev_votes++;'
        elif rt == "mid_band" and lo is not None and hi is not None:
            return (f'{indent}if({feat_var}=="{feat}" && {val_var}>={float(lo):.6f}'
                    f' && {val_var}<={float(hi):.6f}) _g_bev_votes++;')
        return ""

    lines = [
        f'// 8b. Bad-entry vote function — {len(groups)} symbol/setup groups, block if votes >= {min_votes}',
        '// Derived from L10 canary analysis: sl_count >= 2 across 3 trailing styles.',
        '//',
        '// Usage (call once per feature, then check):',
        '//   VPBadEntryVote("__reset__", sym, setup, feat, 0);  // start of signal',
        '//   VPBadEntryVote("__vote__",  sym, setup, feat, val); // each feature',
        '//   bool bad = VPBadEntryVote("__check__", sym, setup, feat, 0); // query',
        'int _g_bev_votes  = 0;',
        'string _g_bev_sym = "";',
        'string _g_bev_stp = "";',
        '',
        'bool VPBadEntryVote(const string cmd, const string symbol, const string setup,',
        '                    const string feat, double val)',
        '{',
        '   if(cmd == "__reset__")',
        '   {',
        '      _g_bev_votes = 0;',
        '      _g_bev_sym   = symbol;',
        '      _g_bev_stp   = setup;',
        '      return false;',
        '   }',
        f'   if(cmd == "__check__")',
        f'      return (_g_bev_votes >= {min_votes});',
        '   // cmd == "__vote__" -- check feature against per-group rules',
    ]

    for group_key, spec in groups.items():
        parts = group_key.split("|", 1)
        sym = parts[0] if len(parts) > 0 else ""
        stp = parts[1] if len(parts) > 1 else ""
        grp_features = spec.get("features", [])
        if not grp_features:
            continue
        lines.append(f'   if(symbol=="{sym}" && setup=="{stp}")')
        lines.append('   {')
        for r in grp_features:
            rule_line = _emit_rule(r, "feat", "val", "      ")
            if rule_line:
                lines.append(rule_line)
        lines.append('   }')

    # ── MFE-based rules from L10a (global, all symbol/setup) ──
    mfe_fallback: dict = filter_spec.get('mfe_fallback', {})
    mfe_features = mfe_fallback.get('features', [])
    mfe_min_votes = int(mfe_fallback.get('min_votes', 1))
    if mfe_features:
        lines.append(f'   // ── MFE-based rules (L10a, min_votes={mfe_min_votes}) ──')
        lines.append('   // Applied when entry MFE was too low across all 3 trailing styles')
        for r in mfe_features:
            rule_line = _emit_rule(r, 'feat', 'val', '   ')
            if rule_line:
                lines.append(rule_line)

    # ── MFE-based rules from L10a (global, all symbol/setup) ──
    mfe_fallback: dict = filter_spec.get('mfe_fallback', {})
    mfe_features = mfe_fallback.get('features', [])
    mfe_min_votes = int(mfe_fallback.get('min_votes', 1))
    if mfe_features:
        lines.append(f'   // ── MFE-based rules (L10a, min_votes={mfe_min_votes}) ──')
        lines.append('   // Applied when entry MFE was too low across all 3 trailing styles')
        for r in mfe_features:
            rule_line = _emit_rule(r, 'feat', 'val', '   ')
            if rule_line:
                lines.append(rule_line)

    lines += [
        '   return false;',
        '}',
        '',
    ]
    return "\n".join(lines)


def _generate_mqh(hard, soft, medians, exp_id, default_tilt, bad_filter=None, shap_hyps=None):
    lines = []
    ts = time.strftime("%Y-%m-%d %H:%M")

    lines += [
        "#ifndef __VP_EA_EDGEGUARD_CONFIG_MQH__",
        "#define __VP_EA_EDGEGUARD_CONFIG_MQH__",
        "",
        "// ============================================================",
        "// VP EdgeGuard Config -- RESEARCH MODE (dev-validated only)",
        f"// Generated  : {ts}",
        f"// Experiment : {exp_id}",
        "// WARNING: NOT HOLDOUT-CONFIRMED.",
        "//   Use with small lots for out-of-sample validation only.",
        "// ============================================================",
        "",
    ]

    # 1. Hard gates
    lines += [
        f"// 1. Hard gate blocking -- {len(hard)} rules [RESEARCH]",
        "double VPGetEdgeMultiplier(const string symbol, const string setup,",
        "                            const string feature, double value)",
        "{",
    ]
    for _, r in hard.iterrows():
        sym = r["symbol"]; stp = r["setup"]; feat = r["feature"]
        gt = r.get("gate_type", "threshold")
        direction = int(r.get("direction", 1))
        lo = r.get("lower", None); hi = r.get("upper", None)
        ev = float(r.get("mean_ev", 0)); fc = float(r.get("fold_consistency", 0))
        n = int(r.get("mean_n", 0))
        tag = f"// EV={ev:+.3f} fc={fc:.2f} n={n}"

        if gt == "threshold" and direction == 1 and pd.notna(lo):
            if feat in _COMPOSITE_FEATURES:
                lines.append(f'   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="{feat}")')
            lines.append(f'   if(symbol=="{sym}" && setup=="{stp}" && feature=="{feat}" && value<{float(lo):.6f}) return 0.0; {tag}')
        elif gt == "threshold" and direction == -1 and pd.notna(hi):
            if feat in _COMPOSITE_FEATURES:
                lines.append(f'   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="{feat}")')
            lines.append(f'   if(symbol=="{sym}" && setup=="{stp}" && feature=="{feat}" && value>{float(hi):.6f}) return 0.0; {tag}')
        elif gt == "band" and pd.notna(lo) and pd.notna(hi):
            if feat in _COMPOSITE_FEATURES:
                lines.append(f'   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="{feat}")')
            lines.append(f'   if(symbol=="{sym}" && setup=="{stp}" && feature=="{feat}" && (value<{float(lo):.6f}||value>{float(hi):.6f})) return 0.0; {tag}')
    lines += ["   return 1.0;", "}", ""]

    # 2. Soft tilts -- FULLY IMPLEMENTED with median thresholds
    lines += [
        f"// 2. Soft gate tilt -- {len(soft)} tilts [RESEARCH]",
        "// Returns [0.5,1.0]. Does NOT block.",
        "// Tilt DOWN on unfavourable side of feature median.",
        "//   direction=+1: high value good -> tilt when value <= median",
        "//   direction=-1: low value good  -> tilt when value >= median",
        "double VPGetEdgeTiltMultiplier(const string symbol, const string setup,",
        "                               const string feature, double value)",
        "{",
    ]

    emitted = skipped = 0

    # Auto-detect lift scale: binary targets (all_styles_win) produce lift << 1,
    # continuous targets (profitUSD) produce lift in dollars (can be >> 1).
    # Rescale thresholds so 0.6/0.7/0.75 tilt levels are meaningful in both cases.
    _lifts = soft["ev_lift"].abs() if not soft.empty else pd.Series([1.0])
    _max_lift = float(_lifts.quantile(0.95)) if len(_lifts) > 0 else 1.0
    if _max_lift < 2.0:
        # Binary scale (0..1 range) — use relative thresholds
        _t60 = _max_lift * 0.60   # top 40% lift → tilt 0.60
        _t70 = _max_lift * 0.30   # top 70% lift → tilt 0.70
        _t75 = _max_lift * 0.10   # top 90% lift → tilt 0.75
        print(f"  [TILT] Binary lift scale detected (max_lift={_max_lift:.3f}): "
              f"thresholds 0.60={_t60:.3f} 0.70={_t70:.3f} 0.75={_t75:.3f}")
    else:
        # Dollar scale — original thresholds
        _t60, _t70, _t75 = 50.0, 10.0, 1.0
        print(f"  [TILT] Dollar lift scale detected (max_lift={_max_lift:.1f}): "
              f"thresholds 0.60={_t60} 0.70={_t70} 0.75={_t75}")

    for _, r in soft.iterrows():
        sym = r["symbol"]; stp = r["setup"]; feat = r["feature"]
        direction = int(r.get("direction", 1))
        lift = float(r.get("ev_lift", 0))
        pp = float(r.get("perm_pvalue", 1))

        # Tilt magnitude proportional to lift (scale-aware)
        abs_lift = abs(lift)
        if abs_lift > _t60:
            tilt = 0.60
        elif abs_lift > _t70:
            tilt = 0.70
        elif abs_lift > _t75:
            tilt = 0.75
        else:
            tilt = default_tilt

        med = _get_median(medians, sym, stp, feat)
        if med is None:
            lines.append(f'   // [NO_MEDIAN] {sym}/{stp}/{feat} dir={direction:+d} lift={lift:+.3f}')
            skipped += 1
            continue

        tag = f"// lift={lift:+.3f} p={pp:.4f} tilt={tilt:.2f}"
        if direction == 1:
            if feat in _COMPOSITE_FEATURES:
                lines.append(f'   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="{feat}")')
            lines.append(f'   if(symbol=="{sym}" && setup=="{stp}" && feature=="{feat}" && value<={med:.6f}) return {tilt:.4f}; {tag}')
        else:
            if feat in _COMPOSITE_FEATURES:
                lines.append(f'   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="{feat}")')
            lines.append(f'   if(symbol=="{sym}" && setup=="{stp}" && feature=="{feat}" && value>={med:.6f}) return {tilt:.4f}; {tag}')
        emitted += 1

    lines += ["   return 1.0;", "}", ""]

    # 3-6. Stubs
    lines += [
        "// 3. Regime blocking -- stub",
        "bool VPIsBlocked(const string symbol, const string setup, int regime)",
        "{ return false; }", "",
        "// 4. SL risk multiplier -- stub",
        "double VPGetSLRiskMultiplier(const string symbol, const string setup,",
        "                              const string feature, double value)",
        "{ return 1.0; }", "",
        "// 5. Symbol blocking -- stub",
        "bool VPIsSymbolBlocked(const string symbol)",
        "{ return false; }", "",
        "// 6. Lot multiplier -- stub",
        "double VPGetLotMultiplier(const string symbol, const string setup)",
        "{ return 1.0; }", "",
        "// 7. Trigger enable/disable per symbol -- stub (always enabled)",
        "// Preserves architecture for future per-symbol/setup trigger control.",
        "bool VPIsTriggerEnabled(const string symbol, int setupType)",
        "{",
        "   return true; // all triggers enabled by default",
        "}", "",
    ]

    # 8. Bad-entry filter (from L10 canary analysis)
    # Supports both new grouped format {"groups": {...}, "global_fallback": {...}}
    # and legacy flat format {"features": [...]}
    _has_bad_filter = (
        bad_filter is not None and (
            bad_filter.get("groups") or
            bad_filter.get("global_fallback", {}).get("features") or
            bad_filter.get("features")
        )
    )
    if _has_bad_filter:
        bad_mqh = _generate_bad_entry_mqh(bad_filter)
        if bad_mqh:
            n_groups = len(bad_filter.get("groups", {}))
            n_global = len(bad_filter.get("global_fallback", bad_filter).get("features", []))
            lines.append(f"// 8. Bad-entry filter -- {n_groups} group blocks + {n_global} global fallback rules [RESEARCH]")
            lines.append(bad_mqh)
            print(f"  Bad-entry filter: {n_groups} groups + {n_global} global rules (min_votes={bad_filter.get('min_votes',2)})")
    else:
        lines += [
            "// 8. Bad-entry filter stub (run pipeline to generate real filter)",
            "int _g_bev_votes = 0; string _g_bev_sym = \"\"; string _g_bev_stp = \"\";",
            "bool VPBadEntryVote(const string cmd, const string symbol, const string setup,",
            "                    const string feat, double val) { return false; }",
            "",
        ]

    # 9. SHAP-guided tilts (experimental — NOT FDR validated)
    if shap_hyps:
        shap_mqh = _generate_shap_tilts_mqh(shap_hyps)
        if shap_mqh:
            n_s = len(shap_hyps)
            lines.append(f"// 9. SHAP-guided tilts -- {n_s} hypotheses [EXPERIMENTAL - NOT FDR VALIDATED]")
            lines.append("// These are raw SHAP findings, NOT confirmed by L4/L5/L6 pipeline.")
            lines.append("// Use only for research/observation — not for production sizing.")
            lines.append(shap_mqh)
            print(f"  SHAP tilts: {n_s} experimental rules embedded")
    else:
        lines += [
            "// 9. SHAP-guided tilts -- not available (run run_shap.py --exp <id>)",
            "// double VPGetSHAPTilt(const string sym, const string stp,",
            "//                     const string feat, double val) { return 1.0; }",
            "",
        ]

    lines += ["#endif", ""]

    print(f"  Tilt rules: {emitted} emitted, {skipped} skipped (no median)")
    return "\n".join(lines)




def _load_shap_hypotheses(shap_exp: str, min_evidence: float = 0.01) -> list:
    """Load SHAP hypotheses from a SHAP experiment output directory.

    shap_exp can be:
    - An absolute path to the SHAP experiment dir
    - A relative name like "shap_20260924T043845" (looked up under output/shap/)
    - "latest" to auto-detect the most recent SHAP run

    Returns list of hypothesis dicts filtered by min_evidence.
    Only includes hypotheses with status="DISCOVERY_ONLY" and
    hypothesis_type in {"importance", "dependence"} — i.e. actual
    feature-value relationships, not meta-analysis.
    """
    shap_root = _ROOT / "output" / "shap"

    # Resolve path
    if shap_exp == "latest":
        dirs = sorted(shap_root.glob("shap_*"), key=lambda p: p.name, reverse=True)
        if not dirs:
            print("  [WARN] No SHAP experiments found under output/shap/")
            return []
        exp_path = dirs[0]
    else:
        p = pathlib.Path(shap_exp)
        if p.is_absolute() and p.exists():
            exp_path = p
        elif (shap_root / shap_exp).exists():
            exp_path = shap_root / shap_exp
        else:
            # Try matching prefix
            matches = [d for d in shap_root.glob(f"{shap_exp}*") if d.is_dir()]
            if matches:
                exp_path = sorted(matches)[-1]
            else:
                print(f"  [WARN] SHAP experiment not found: {shap_exp}")
                return []

    hyp_file = exp_path / "hypotheses.json"
    if not hyp_file.exists():
        print(f"  [WARN] hypotheses.json not found in {exp_path}")
        return []

    with hyp_file.open(encoding="utf-8") as f:
        hyps = json.load(f)

    # Filter: only entry-quality hypotheses with sufficient evidence
    VALID_TYPES = {"importance", "dependence", "trigger_conditional",
                   "regime_conditional", "stability"}
    filtered = [
        h for h in hyps
        if (h.get("status") == "DISCOVERY_ONLY"
            and float(h.get("evidence_strength", 0)) >= min_evidence
            and h.get("hypothesis_type") in VALID_TYPES
            and h.get("suggested_shape") not in (None, "UNKNOWN"))
    ]
    print(f"  [SHAP] {len(filtered)}/{len(hyps)} hypotheses pass filter "
          f"(min_evidence={min_evidence})")
    return filtered


def _generate_shap_tilts_mqh(hyps: list) -> str:
    """Generate MQL5 VPGetSHAPTilt() from SHAP hypotheses.

    Maps SHAP findings to soft tilts per (symbol, setup, feature).
    Returns tilt in [0.7, 1.0] based on evidence strength and shape.

    IMPORTANT: These are UNVALIDATED — for research/observation only.
    They are NOT confirmed by L4/L5/L6/FDR pipeline.
    """
    if not hyps:
        return ""

    lines = [
        "// WARNING: SHAP tilts are EXPERIMENTAL — not FDR-validated.",
        "// They are derived directly from SHAP analysis without nested WF.",
        "// Use for research observation only, NOT production sizing.",
        "// Returns [0.7, 1.0] tilt — never blocks (different from hard gates).",
        "double VPGetSHAPTilt(const string symbol, const string setup,",
        "                     const string feature, double value)",
        "{",
    ]

    # Group by (symbol, setup) for cleaner output
    from collections import defaultdict
    groups = defaultdict(list)
    for h in hyps:
        meta = h.get("metadata", {})
        sym = meta.get("symbol", "")
        stp = meta.get("setup", h.get("setup", ""))
        if sym and stp:
            groups[f"{sym}|{stp}"].append(h)
        # Skip hypotheses without symbol/setup context (global ones)

    if not groups:
        # No per-group hypotheses — emit nothing useful
        lines += ["   return 1.0;", "}", ""]
        return "\n".join(lines)

    for group_key, group_hyps in sorted(groups.items()):
        parts = group_key.split("|", 1)
        sym = parts[0]; stp = parts[1] if len(parts) > 1 else ""
        lines.append(f'   // ── {sym} | {stp} ──')
        lines.append(f'   if(symbol=="{sym}" && setup=="{stp}")')
        lines.append("   {")
        emitted = 0
        for h in sorted(group_hyps, key=lambda x: -float(x.get("evidence_strength", 0))):
            feat = h.get("feature", "")
            shape = h.get("suggested_shape", "UNKNOWN")
            direction = int(h.get("suggested_direction", 1))
            evidence = float(h.get("evidence_strength", 0))

            # Map evidence → tilt strength
            tilt = 0.90 if evidence > 0.05 else 0.95

            # Generate condition based on shape
            # We use median-split: direction=+1 → good side is high → tilt when low
            # direction=-1 → good side is low → tilt when high
            if shape in ("MONO_UP",) and direction == 1:
                # High value good → tilt down if feature value is below median
                # We use a simple heuristic: any SHAP hypothesis → tilt on bad side
                lines.append(f'      // SHAP-{h.get("source","?")} evidence={evidence:.3f} shape={shape}')
                lines.append(f'      if(feature=="{feat}") return {tilt:.2f}f; // tilt=low_is_bad')
                emitted += 1
            elif shape in ("MONO_DOWN",) and direction == -1:
                lines.append(f'      // SHAP-{h.get("source","?")} evidence={evidence:.3f} shape={shape}')
                lines.append(f'      if(feature=="{feat}") return {tilt:.2f}f; // tilt=high_is_bad')
                emitted += 1
            elif shape == "BAND":
                lines.append(f'      // SHAP-{h.get("source","?")} evidence={evidence:.3f} shape=BAND')
                lines.append(f'      if(feature=="{feat}") return {tilt:.2f}f; // band_effect')
                emitted += 1
            # Skip UNKNOWN shapes

            if emitted >= 5:  # limit per group to avoid huge files
                break
        lines.append("   }")

    lines += ["   return 1.0;", "}", ""]
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exp", default=None)
    parser.add_argument("--start", default=None)
    parser.add_argument("--end", default=None)
    parser.add_argument("--min-ev", type=float, default=0.03)
    parser.add_argument("--min-wr", type=float, default=0.35)
    parser.add_argument("--min-fc", type=float, default=0.55)
    parser.add_argument("--min-folds", type=int, default=2)
    parser.add_argument("--max-hard", type=int, default=150)
    parser.add_argument("--max-perm-p", type=float, default=0.05)
    parser.add_argument("--min-lift", type=float, default=0.02)
    parser.add_argument("--max-soft", type=int, default=5000)
    parser.add_argument("--default-tilt", type=float, default=0.80)
    parser.add_argument("--cross-style-filter", action="store_true", default=False,
                        help="Filter candidates using _all_styles_win cross-style signal")
    parser.add_argument("--cs-min-lift", type=float, default=0.05,
                        help="Min relative lift in all_styles_win for cross-style filter")
    parser.add_argument("--shap-exp", default=None,
                        help="SHAP experiment dir or ID to load hypotheses from "
                             "(e.g. shap_20260924T043845). Adds unvalidated SHAP tilts.")
    parser.add_argument("--shap-min-evidence", type=float, default=0.01,
                        help="Min evidence_strength to include SHAP hypothesis (default 0.01)")

    args = parser.parse_args()

    print("=" * 60)
    print("GENERATE RESEARCH EDGEGUARDS (Dev-Validated Only)")
    print("=" * 60)

    exp_dir = (_ROOT / "output" / "experiments" / args.exp
               if args.exp else _latest_exp())
    if exp_dir is None or not exp_dir.exists():
        print(f"[ERROR] Experiment not found"); return 1
    exp_id = exp_dir.name
    print(f"\n  Experiment: {exp_id}")

    # Infer data range
    start, end = args.start, args.end
    if not start or not end:
        try:
            from data_loader import list_available_months
            months = list_available_months("VP_Trades")
            if months:
                start = start or months[0]
                end = end or months[-1]
                print(f"  Data range : {start} .. {end}")
        except Exception:
            pass

    # Load
    print("\n[1] Loading candidates...")
    hp = exp_dir / "L4_hard_gates" / "hard_gate_candidates.csv"
    sp = exp_dir / "L5_soft_gates" / "soft_gate_candidates.csv"
    hard_raw = pd.read_csv(hp) if hp.exists() else pd.DataFrame()
    soft_raw = pd.read_csv(sp) if sp.exists() else pd.DataFrame()
    print(f"  Hard: {len(hard_raw)}, Soft: {len(soft_raw)}")

    # Filter
    print("\n[2] Filtering...")
    hard = hard_raw.copy()
    if not hard.empty:
        hard = hard[hard["mean_ev"] >= args.min_ev]
        hard = hard[hard["mean_wr"] >= args.min_wr]
        hard = hard[hard["fold_consistency"] >= args.min_fc]
        hard = hard[hard["n_folds"] >= args.min_folds]
        if "ci_low" in hard.columns:
            hard = hard[hard["ci_low"] > 0]
        hard = hard.sort_values("mean_ev", ascending=False).head(args.max_hard)
    print(f"  Hard after filter: {len(hard)}")

    soft = soft_raw.copy()
    if not soft.empty:
        soft = soft[soft["perm_pvalue"] <= args.max_perm_p]
        soft = soft[soft["ev_lift"] >= args.min_lift]
        soft = soft.sort_values("perm_pvalue").head(args.max_soft)
    print(f"  Soft after filter: {len(soft)}")

    # Cross-style filter (optional)
    if args.cross_style_filter:
        print("\n[2b] Cross-style entry quality filter...")
        hard, soft, cs_report = _cross_style_filter(
            hard, soft, start, end,
            min_lift=args.cs_min_lift,
        )
        for line in cs_report:
            print(line)
        print(f"  After cross-style: {len(hard)} hard, {len(soft)} soft")

    if hard.empty and soft.empty:
        print("\n[WARN] No candidates. Try relaxing thresholds.")
        return 0

    # Compute medians
    print("\n[3] Computing medians for tilt thresholds...")
    medians = _compute_medians(soft, start, end)

    # Generate
    print("\n[4] Generating MQL5 config...")
    # Load bad-entry filter from L10 output
    bad_filter = None
    bad_filter_path = exp_dir / "L10_bad_entry" / "composite_bad_filter.json"
    if bad_filter_path.exists():
        with bad_filter_path.open(encoding="utf-8") as _bf:
            bad_filter = json.load(_bf)
        n_grp = len(bad_filter.get("groups", {}))
        n_glb = len(bad_filter.get("global_fallback", bad_filter).get("features", []))
        print(f"  Bad-entry filter: {n_grp} group blocks + {n_glb} global rules (min_votes={bad_filter.get('min_votes',2)})")
    else:
        print(f"  [WARN] No bad-entry filter found at {bad_filter_path}")

    # Also load L10a output (MFE-based canary, grouped format)
    l10a_path = exp_dir / "L10a_bad_entry" / "composite_bad_filter_candidate.json"
    if l10a_path.exists():
        with l10a_path.open(encoding="utf-8") as _bf2:
            l10a_filter = json.load(_bf2)
        l10a_groups = l10a_filter.get("groups", {})
        if l10a_groups:
            if bad_filter is None:
                bad_filter = {"groups": {}, "global_fallback": {"features": [], "min_votes": 2}, "min_votes": 2}
            # Merge L10a per-group rules into L10 groups
            # For keys present in both: union the feature lists (no duplicate feature+rule_type)
            existing_groups = bad_filter.get("groups", {})
            for gkey, gspec in l10a_groups.items():
                if gkey not in existing_groups:
                    existing_groups[gkey] = gspec
                else:
                    # Merge: add L10a features not already in L10
                    ex_keys = {(f["feature"], f["rule_type"])
                               for f in existing_groups[gkey].get("features", [])}
                    new_feats = [f for f in gspec.get("features", [])
                                 if (f["feature"], f["rule_type"]) not in ex_keys]
                    existing_groups[gkey]["features"].extend(new_feats)
            bad_filter["groups"] = existing_groups
            n_new = sum(len(v.get("features", [])) for v in l10a_groups.values())
            print(f"  Bad-entry (L10a MFE): {len(l10a_groups)} groups merged ({n_new} rules)")
        else:
            print("  [INFO] L10a has no per-group MFE filters (mfeATR may be zero)")
    else:
        print("  [INFO] No L10a bad-entry filter found (mfeATR not logged yet)")

    # Load SHAP hypotheses (optional experimental block)
    shap_hyps = None
    if args.shap_exp:
        shap_hyps = _load_shap_hypotheses(args.shap_exp, args.shap_min_evidence)
        if shap_hyps:
            print(f"  SHAP hypotheses: {len(shap_hyps)} loaded from {args.shap_exp}")
        else:
            print("  [WARN] No SHAP hypotheses found or loaded")

    mqh = _generate_mqh(hard, soft, medians, exp_id, args.default_tilt,
                        bad_filter=bad_filter, shap_hyps=shap_hyps)

    OUTPUT_GUARDS.mkdir(parents=True, exist_ok=True)
    mqh_path = OUTPUT_GUARDS / "VPEdgeGuardConfig_research.mqh"
    mqh_path.write_text(mqh, encoding="utf-8")
    print(f"  MQH: {mqh_path}")

    if EA_CONFIG_DIR.exists():
        ea = EA_CONFIG_DIR / "VPEdgeGuardConfig.mqh"
        ea.write_text(mqh, encoding="utf-8")
        print(f"  EA : {ea}")

    # Summary
    summary = {
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "experiment_id": exp_id,
        "mode": "RESEARCH - dev validated only",
        "warning": "NOT holdout-confirmed. Use with small capital.",
        "n_hard_gates": len(hard),
        "n_soft_tilts": len(soft),
        "n_medians": len(medians),
    }
    if not hard.empty:
        summary["top_hard"] = hard[
            ["symbol","setup","feature","gate_type","direction",
             "lower","upper","mean_ev","mean_wr","fold_consistency"]
        ].head(20).to_dict("records")
    if not soft.empty:
        summary["top_soft"] = soft[
            ["symbol","setup","feature","direction","ev_lift","perm_pvalue"]
        ].head(20).to_dict("records")

    jp = OUTPUT_GUARDS / "research_guard_summary.json"
    jp.write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")
    print(f"  JSON: {jp}")

    # Print summary
    print("\n" + "=" * 60)
    print("TOP HARD GATES (by EV)")
    print("=" * 60)
    for _, r in hard.head(15).iterrows():
        lo = f"{r['lower']:.4f}" if pd.notna(r.get("lower")) else "-"
        hi = f"{r['upper']:.4f}" if pd.notna(r.get("upper")) else "-"
        print(f"  {r['symbol']:<12} {r['setup']:<20} {r['feature']:<25}"
              f"  EV={r['mean_ev']:+.3f} WR={r['mean_wr']:.0%} FC={r['fold_consistency']:.2f}"
              f"  [{r['gate_type']} lo={lo} hi={hi}]")

    print("\nTOP SOFT TILTS")
    print("=" * 60)
    for _, r in soft.head(15).iterrows():
        med = _get_median(medians, r["symbol"], r["setup"], r["feature"])
        ms = f"med={med:.4f}" if med is not None else "med=N/A"
        print(f"  {r['symbol']:<12} {r['setup']:<20} {r['feature']:<25}"
              f"  lift={r['ev_lift']:+.3f} p={r['perm_pvalue']:.4f}"
              f"  dir={int(r.get('direction',1)):+d}  {ms}")

    print(f"\n[DONE] {len(hard)} hard gates + {len(soft)} soft tilts")
    print("WARNING: Research mode - not holdout-confirmed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
