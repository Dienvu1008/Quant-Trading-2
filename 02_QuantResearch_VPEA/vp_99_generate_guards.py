"""
vp_99_generate_guards.py — Generate EdgeGuard Config for VP EA

Reads research outputs and generates:
1. VPEdgeGuardConfig.mqh — MQL5 hardcoded lookup tables
2. vp_edge_guards.json — Full config for runtime loading

Rules are tiered by confidence:
- STRICT: validated=true (statistically significant, temporally stable)
- SOFT: EV > 0 with n_folds >= 2 (positive but not fully validated)
- ALL: any rule with EV > 0

EA uses InpUseEdgeGuards input to select mode.
"""

import sys, json, time
import numpy as np
import pandas as pd
from pathlib import Path

_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))

OUTPUT_DIR = _HERE / "output" / "99_guards"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Target location for generated MQL5 file
EA_CONFIG_DIR = Path(r"c:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\My own robots\Quant Trading 2\01_EA_VP\Config")


def run(production_style=1):
    t0 = time.time()
    print("\n" + "=" * 60)
    print("VP PHASE 99 — GENERATE EDGEGUARD CONFIG")
    print("=" * 60)
    print(f"  Production trailing style: {production_style} "
          f"(guards derived from this style's trades)")

    config = {
        "version": "2.1",
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        # The style the EA runs Live. All guard-bound numbers below were computed
        # on this style's trades; the *_robust flags mark rules that also held
        # across all 3 trailing styles. Regenerate if the Live style changes.
        "production_style": production_style,
        "feature_gates": {"strict": [], "soft": []},
        "block_rules": [],
        "symbol_configs": [],
        "entry_gates": [],
        "sl_thresholds": [],
        "lot_multipliers": [],
    }

    # ─── Load Phase 01: Symbol configs ───
    p01 = _HERE / "output" / "01_behavior_profiling" / "recommended_configs.json"
    if p01.exists():
        with open(p01) as f:
            config["symbol_configs"] = json.load(f)
        print(f"  Symbol configs: {len(config['symbol_configs'])}")

    # ─── Load Phase 02: Feature gates (tiered) ───
    p02 = _HERE / "output" / "02_edge_discovery" / "threshold_rules.json"
    if p02.exists():
        with open(p02) as f:
            rules = json.load(f)
        strict = [r for r in rules if r.get("validated") == True]
        soft = [r for r in rules if not r.get("validated") and
                r.get("test_ev_mean", 0) > 0 and r.get("n_folds", 0) >= 2]
        config["feature_gates"]["strict"] = strict
        config["feature_gates"]["soft"] = soft
        n_robust = sum(1 for r in (strict + soft) if r.get("robust_across_styles"))
        rob_note = f", {n_robust} robust(3-style)" if any("robust_across_styles" in r for r in rules) else ""
        print(f"  Feature gates: {len(strict)} strict, {len(soft)} soft{rob_note}")

    # ─── Load Phase 03: Entry gates ───
    p03 = _HERE / "output" / "03_entry_quality" / "entry_gates.json"
    if p03.exists():
        with open(p03) as f:
            gates = json.load(f)
        config["entry_gates"] = gates
        validated = [g for g in gates if g.get("validated")]
        print(f"  Entry gates: {len(gates)} total, {len(validated)} validated")

    # ─── Load Phase 04: SL thresholds ───
    p04 = _HERE / "output" / "04_exit_profiling" / "sl_thresholds.json"
    if p04.exists():
        with open(p04) as f:
            config["sl_thresholds"] = json.load(f)
        print(f"  SL thresholds: {len(config['sl_thresholds'])}")

    # ─── Load Phase 05: Block rules ───
    p05 = _HERE / "output" / "05_regime_analysis" / "block_rules.json"
    if p05.exists():
        with open(p05) as f:
            config["block_rules"] = json.load(f)
        br = config["block_rules"]
        n_robust = sum(1 for r in br if r.get("robust_across_styles"))
        rob_note = f", {n_robust} robust(3-style)" if any("robust_across_styles" in r for r in br) else ""
        print(f"  Block rules: {len(br)}{rob_note}")

    # ─── Load Phase 06: Lot multipliers ───
    p06 = _HERE / "output" / "06_sizing_calibration" / "lot_multipliers.json"
    if p06.exists():
        with open(p06) as f:
            mults = json.load(f)
        config["lot_multipliers"] = [m for m in mults if m.get("validated")]
        print(f"  Lot multipliers: {len(config['lot_multipliers'])} validated")

    # ─── Save combined JSON ───
    json_path = OUTPUT_DIR / "vp_edge_guards.json"
    with open(json_path, "w") as f:
        json.dump(config, f, indent=2, default=str)
    print(f"\n  JSON: {json_path}")

    # ─── Generate MQL5 file ───
    mqh_path = OUTPUT_DIR / "VPEdgeGuardConfig.mqh"
    _generate_mqh(config, mqh_path)
    print(f"  MQH:  {mqh_path}")

    # Also copy to EA Config dir
    ea_mqh = EA_CONFIG_DIR / "VPEdgeGuardConfig.mqh"
    if EA_CONFIG_DIR.exists():
        _generate_mqh(config, ea_mqh)
        print(f"  EA:   {ea_mqh}")

    # Summary
    _print_summary(config)

    print(f"\n  Time: {time.time()-t0:.1f}s")
    return config


def _generate_mqh(config, path):
    """Generate MQL5 EdgeGuard config — hardcoded lookup tables."""
    lines = []
    lines.append("#ifndef __VP_EA_EDGEGUARD_CONFIG_MQH__")
    lines.append("#define __VP_EA_EDGEGUARD_CONFIG_MQH__")
    lines.append("")
    prod_style = config.get("production_style", 1)
    style_label = {-1: "no-trailing", 0: "conservative", 1: "expansion"}.get(prod_style, "?")
    lines.append("// =============================================================")
    lines.append(f"// VP EdgeGuard Config -- Generated {time.strftime('%Y-%m-%d %H:%M')}")
    lines.append(f"// Production trailing style: {prod_style} ({style_label})")
    lines.append("//   Guard numbers derived from this style's trades. [ROBUST] in a")
    lines.append("//   comment = the rule also held across all 3 trailing styles.")
    lines.append("//   Regenerate with a new production_style if the Live style changes.")
    lines.append("// DO NOT EDIT MANUALLY -- regenerate with vp_99_generate_guards.py")
    lines.append("// =============================================================")
    lines.append("")

    # ─── Block Rules (regime × setup) ───
    block_rules = config.get("block_rules", [])
    lines.append(f"// {len(block_rules)} block rules")
    lines.append("bool VPIsBlocked(const string symbol, const string setup, int regime)")
    lines.append("{")
    for rule in block_rules:
        sym = rule.get("symbol", "")
        setup = rule.get("setup", "")
        condition = rule.get("condition", "")
        rule_type = rule.get("type", "")

        if rule_type == "auction_regime":
            regime_val = _regime_name_to_int(condition)
            if regime_val >= 0:
                rtag = " [ROBUST]" if rule.get("robust_across_styles") else ""
                lines.append(f'   if(symbol=="{sym}" && setup=="{setup}" && regime=={regime_val}) return true; '
                             f'// EV={rule.get("ev", 0):.2f} n={rule.get("n", 0)}{rtag}')
    lines.append("   return false;")
    lines.append("}")
    lines.append("")

    # ─── Feature Gate: GetEdgeMultiplier ───
    feature_gates = config.get("feature_gates", {})
    soft_gates = feature_gates.get("soft", [])
    strict_gates = feature_gates.get("strict", [])
    all_gates = strict_gates + soft_gates  # strict first (priority)

    lines.append(f"// {len(all_gates)} feature gates ({len(strict_gates)} strict + {len(soft_gates)} soft)")
    lines.append("// Feature gates applied per (symbol, setup) — block if feature below threshold")
    lines.append("double VPGetEdgeMultiplier(const string symbol, const string setup, const string feature, double value)")
    lines.append("{")

    # Group by (symbol, setup, feature) — emit top 50 most impactful
    emitted = 0
    for rule in sorted(all_gates, key=lambda r: r.get("test_ev_mean", 0), reverse=True)[:50]:
        sym = rule.get("symbol", "")
        setup = rule.get("setup", "")
        feat = rule.get("feature", "")
        gate_type = rule.get("gate_type", "")
        direction = rule.get("direction", 1)
        low = rule.get("lower_bound")
        high = rule.get("upper_bound")
        ev = rule.get("test_ev_mean", 0)
        validated = rule.get("validated", False)
        tag = "STRICT" if validated else "soft"
        rtag = " [ROBUST]" if rule.get("robust_across_styles") else ""

        if gate_type == "threshold" and direction == 1 and low is not None:
            lines.append(f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}" && value<{low:.4f}) '
                         f'return 0.0; // [{tag}] EV={ev:.3f}{rtag}')
            emitted += 1
        elif gate_type == "threshold" and direction == -1 and high is not None:
            lines.append(f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}" && value>{high:.4f}) '
                         f'return 0.0; // [{tag}] EV={ev:.3f}{rtag}')
            emitted += 1
        elif gate_type == "band" and low is not None and high is not None:
            lines.append(f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}" && '
                         f'(value<{low:.4f} || value>{high:.4f})) '
                         f'return 0.0; // [{tag}] band EV={ev:.3f}{rtag}')
            emitted += 1

    lines.append("   return 1.0; // no gate matched")
    lines.append("}")
    lines.append("")

    # ─── Symbol Enable/Disable ───
    symbol_configs = config.get("symbol_configs", [])
    avoid_symbols = [sc["symbol"] for sc in symbol_configs if sc.get("quality_tier") == "AVOID"]

    lines.append(f"// {len(avoid_symbols)} AVOID symbols")
    lines.append("bool VPIsSymbolBlocked(const string symbol)")
    lines.append("{")
    for sym in avoid_symbols:
        lines.append(f'   if(symbol=="{sym}") return true;')
    lines.append("   return false;")
    lines.append("}")
    lines.append("")

    # ─── Trigger Enable per Symbol ───
    lines.append("bool VPIsTriggerEnabled(const string symbol, int setupType)")
    lines.append("{")
    for sc in symbol_configs:
        sym = sc.get("symbol", "")
        disabled = []
        trigger_map = {"breakout": 0, "breakout_retest": 1, "pullback": 2,
                       "trend_cont": 3, "sweep_reversal": 4, "mean_reversion": 5}
        for trig_name, trig_int in trigger_map.items():
            if sc.get(trig_name) == False:
                disabled.append(trig_int)
        if disabled:
            for d in disabled:
                lines.append(f'   if(symbol=="{sym}" && setupType=={d}) return false;')
    lines.append("   return true;")
    lines.append("}")
    lines.append("")

    # ─── SL Risk Thresholds ───
    sl_thresholds = config.get("sl_thresholds", [])
    lines.append(f"// {len(sl_thresholds)} SL risk thresholds")
    lines.append("// When feature crosses threshold, SL hit probability increases significantly")
    lines.append("// Use to tighten SL or reduce lot size")
    lines.append("double VPGetSLRiskMultiplier(const string symbol, const string setup, const string feature, double value)")
    lines.append("{")
    for t in sorted(sl_thresholds, key=lambda x: x.get("avg_lift", 0), reverse=True)[:30]:
        sym = t.get("symbol", "")
        setup = t.get("setup", "")
        feat = t.get("feature", "")
        direction = t.get("direction", "above")
        threshold = t.get("threshold", 0)
        lift = t.get("avg_lift", 0)
        sl_rate = t.get("avg_sl_rate", 0)

        if direction == "above":
            lines.append(f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}" && value>{threshold:.4f}) '
                         f'return 0.5; // SL_rate={sl_rate:.0%} lift=+{lift:.0%}')
        else:
            lines.append(f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}" && value<{threshold:.4f}) '
                         f'return 0.5; // SL_rate={sl_rate:.0%} lift=+{lift:.0%}')
    lines.append("   return 1.0;")
    lines.append("}")
    lines.append("")

    # ─── Lot Multiplier (Phase 06 — Fractional Kelly) ───
    lot_mults = config.get("lot_multipliers", [])
    # Separate symbol-specific from global fallback
    sym_mults    = [m for m in lot_mults if m.get("symbol") != "_GLOBAL"]
    global_mults = [m for m in lot_mults if m.get("symbol") == "_GLOBAL"]

    lines.append(f"// {len(lot_mults)} lot multipliers ({len(sym_mults)} symbol-specific + {len(global_mults)} global)")
    lines.append("// Returns multiplier in [0.50, 1.50] applied to maxLot")
    lines.append("// 1.0 = neutral (no calibration data), <1.0 = scale down, >1.0 = scale up")
    lines.append("double VPGetLotMultiplier(const string symbol, const string setup)")
    lines.append("{")

    # Emit symbol-specific rules first (more specific wins)
    for m in sorted(sym_mults, key=lambda x: x.get("lot_mult", 1.0), reverse=True):
        sym   = m.get("symbol", "")
        setup = m.get("setup", "")
        mult  = m.get("lot_mult", 1.0)
        ev    = m.get("ev_oos", 0.0)
        wr    = m.get("wr_oos", 0.0)
        n     = m.get("n_oos", 0)
        rtag  = " [ROBUST]" if m.get("robust_across_styles") else ""
        lines.append(f'   if(symbol=="{sym}" && setup=="{setup}") return {mult:.4f}; '
                     f'// EV=${ev:+.2f} WR={wr:.0%} n={n}{rtag}')

    # Global fallback (per setup, any symbol)
    for m in sorted(global_mults, key=lambda x: x.get("lot_mult", 1.0), reverse=True):
        setup = m.get("setup", "")
        mult  = m.get("lot_mult", 1.0)
        ev    = m.get("ev_oos", 0.0)
        wr    = m.get("wr_oos", 0.0)
        n     = m.get("n_oos", 0)
        rtag  = " [ROBUST]" if m.get("robust_across_styles") else ""
        lines.append(f'   if(setup=="{setup}") return {mult:.4f}; '
                     f'// [global] EV=${ev:+.2f} WR={wr:.0%} n={n}{rtag}')

    lines.append("   return 1.0; // no calibration data")
    lines.append("}")
    lines.append("")

    lines.append("#endif")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def _regime_name_to_int(name):
    mapping = {
        "BALANCED_ROTATION": 0, "COMPRESSION": 1, "TREND_INITIATION": 2,
        "TREND_CONTINUATION": 3, "RE_ACCUMULATION": 4, "EXHAUSTION": 5,
        "FAILED_AUCTION": 6, "EXCESS": 7, "CHAOTIC": 8
    }
    return mapping.get(name, -1)


def _print_summary(config):
    print("\n  ─── SUMMARY ───")
    ps = config.get("production_style", 1)
    ps_label = {-1: "no-trailing", 0: "conservative", 1: "expansion"}.get(ps, "?")
    print(f"  Production style: {ps} ({ps_label})")
    strict = config["feature_gates"]["strict"]
    soft = config["feature_gates"]["soft"]
    blocks = config["block_rules"]
    sl = config["sl_thresholds"]
    sym_cfgs = config["symbol_configs"]
    lot_mults = config.get("lot_multipliers", [])

    avoid = [s["symbol"] for s in sym_cfgs if s.get("quality_tier") == "AVOID"]
    high = [s["symbol"] for s in sym_cfgs if s.get("quality_tier") == "HIGH"]

    print(f"  Feature gates: {len(strict)} STRICT + {len(soft)} SOFT")
    print(f"  Block rules: {len(blocks)}")
    print(f"  SL thresholds: {len(sl)}")
    print(f"  Lot multipliers: {len(lot_mults)} validated")
    print(f"  Symbol AVOID: {len(avoid)} ({', '.join(avoid[:5])}{'...' if len(avoid)>5 else ''})")
    print(f"  Symbol HIGH: {len(high)} ({', '.join(high[:5])}{'...' if len(high)>5 else ''})")

    if blocks:
        print(f"\n  Top block rules:")
        for r in sorted(blocks, key=lambda x: x.get("ev", 0))[:5]:
            print(f"    {r['symbol']:<10} {r['setup']:<18} {r['condition']:<20} EV=${r['ev']:+.2f}")

    if soft:
        print(f"\n  Top soft feature gates:")
        for r in sorted(soft, key=lambda x: x.get("test_ev_mean", 0), reverse=True)[:5]:
            print(f"    {r['symbol']:<10} {r['setup']:<18} {r['feature']:<20} EV=${r['test_ev_mean']:+.3f}")

    if lot_mults:
        scale_up = [m for m in lot_mults if m.get("lot_mult", 1.0) > 1.0]
        scale_dn = [m for m in lot_mults if m.get("lot_mult", 1.0) < 1.0]
        print(f"\n  Lot multipliers — scale up: {len(scale_up)}, scale down: {len(scale_dn)}")
        for m in sorted(lot_mults, key=lambda x: abs(x.get("lot_mult", 1.0) - 1.0), reverse=True)[:5]:
            print(f"    {m['symbol']:<12} {m['setup']:<20} mult={m['lot_mult']:.2f}  "
                  f"EV=${m['ev_oos']:+.2f}  WR={m['wr_oos']:.0%}")


if __name__ == "__main__":
    run()
