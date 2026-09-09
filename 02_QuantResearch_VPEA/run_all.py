"""
run_all.py — Run all VP EA research phases in optimal dependency order.

Workflow:
  1. Sync fresh MT5 CSVs (Common/Files) into the partitioned Data/ store.
  2. Ask the user for the analysis date range (MM.YYYY .. MM.YYYY).
  3. Warn if any month in the range is missing from the Data store.
  4. Load only that range and run all phases on it.
"""
import sys
import re
from pathlib import Path

_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))

from data_collect import sync_data
from data_loader import (
    load_funnel, load_trades,
    list_available_months, check_data_range, _months_in_range,
)

_MONTH_RE = re.compile(r"^\d{2}\.\d{4}$")


def _prompt_range():
    """Ask the user for start/end months (MM.YYYY). Returns (start, end) or (None, None)
    to mean 'use everything available'."""
    months_t = list_available_months("VP_Trades")
    months_f = list_available_months("VP_Funnel")
    all_months = sorted(set(months_t) | set(months_f),
                        key=lambda m: tuple(reversed(m.split("."))))
    if all_months:
        print(f"\nAvailable months in Data store: {', '.join(all_months)}")
    else:
        print("\n[WARN] Data store is empty. Nothing to analyze after sync.")
        return None, None

    print("Enter analysis range as MM.YYYY (blank = use ALL available).")
    start = input("  Start month (MM.YYYY): ").strip()
    if start == "":
        return None, None
    end = input("  End month   (MM.YYYY): ").strip()
    if end == "":
        end = start

    if not _MONTH_RE.match(start) or not _MONTH_RE.match(end):
        print(f"  [WARN] Invalid format. Expected MM.YYYY. Using ALL available data.")
        return None, None
    return start, end


def main():
    print("=" * 70)
    print("VP EA QUANT RESEARCH PIPELINE")
    print("=" * 70)

    # 1. Optionally sync fresh MT5 output into the partitioned Data store.
    #    Skip this when re-analyzing already-collected data to save time.
    do_sync = input("Sync fresh backtest data first? [Y/n]: ").strip().lower()
    if do_sync in ("", "y", "yes"):
        sync_data()
    else:
        print("  (skipping sync — using existing Data store)")

    # 2. Ask for the analysis window
    start, end = _prompt_range()

    # 3. Warn on missing months
    if start and end:
        wanted = _months_in_range(start, end)
        if not wanted:
            print(f"[BLOCKED] Invalid range {start}..{end} (start after end?).")
            return
        ok_t, missing_t = check_data_range(start, end, "VP_Trades")
        ok_f, missing_f = check_data_range(start, end, "VP_Funnel")
        if missing_f:
            print(f"[WARN] Missing FUNNEL months in {start}..{end}: {', '.join(missing_f)}")
        if missing_t:
            print(f"[WARN] Missing TRADES months in {start}..{end}: {', '.join(missing_t)}")
        if len(missing_f) == len(wanted):
            print(f"[BLOCKED] No funnel data at all for {start}..{end}.")
            return
        print(f"\nAnalyzing range: {start} .. {end}")
    else:
        print("\nAnalyzing ALL available data.")

    # 4. Load the selected range
    funnel_df = load_funnel(start=start, end=end)
    trade_df = load_trades(start=start, end=end)

    if funnel_df.empty:
        print("\n[BLOCKED] No VP_Funnel data for the selected range.")
        return

    all_results = {}

    # ═══ Phase 01: Behavior Profiling (FIRST — establishes context) ═══
    try:
        from vp_01_behavior_profiling import run as run_phase01
        all_results["phase1"] = run_phase01(funnel_df, trade_df)
    except Exception as e:
        print(f"[ERR] Phase 01: {e}")
        all_results["phase1"] = {}

    # ═══ Phase 02: Edge Discovery (uses Phase 01 to filter symbols) ═══
    try:
        from vp_02_edge_discovery import run as run_phase02
        all_results["phase2"] = run_phase02(funnel_df, trade_df)
    except Exception as e:
        print(f"[ERR] Phase 02: {e}")
        all_results["phase2"] = {}

    # ═══ Phase 03: Entry Quality (uses Phase 02 features) ═══
    try:
        from vp_03_entry_quality import run as run_phase03
        all_results["phase3"] = run_phase03(funnel_df, trade_df, all_results)
    except Exception as e:
        print(f"[ERR] Phase 03: {e}")
        all_results["phase3"] = {}

    # ═══ Phase 04: Exit Profiling (uses Phase 02 features) ═══
    try:
        from vp_04_exit_profiling import run as run_phase04
        all_results["phase4"] = run_phase04(funnel_df, trade_df, all_results)
    except Exception as e:
        print(f"[ERR] Phase 04: {e}")
        all_results["phase4"] = {}

    # ═══ Phase 05: Regime Analysis (last — filters by prior phase results) ═══
    try:
        from vp_05_regime_analysis import run as run_phase05
        all_results["phase5"] = run_phase05(funnel_df, trade_df, all_results)
    except Exception as e:
        print(f"[ERR] Phase 05: {e}")
        all_results["phase5"] = {}

    # ═══ Phase 06: Sizing Calibration (uses all prior trade results) ═══
    try:
        from vp_06_sizing_calibration import run as run_phase06
        all_results["phase6"] = run_phase06(funnel_df, trade_df, all_results)
    except Exception as e:
        print(f"[ERR] Phase 06: {e}")
        all_results["phase6"] = {}

    # ═══ Phase 99: Generate EdgeGuard Config ═══
    try:
        from vp_99_generate_guards import run as run_phase99
        all_results["phase99"] = run_phase99()
    except Exception as e:
        print(f"[ERR] Phase 99: {e}")

    print("\n" + "=" * 70)
    print("PIPELINE COMPLETE")
    print("=" * 70)

    # Print key findings
    p1 = all_results.get("phase1", {})
    profiles = p1.get("profiles", [])
    if profiles:
        avoid = [p["symbol"] for p in profiles if p.get("quality_tier") == "AVOID"]
        high = [p["symbol"] for p in profiles if p.get("quality_tier") == "HIGH"]
        if avoid: print(f"  AVOID symbols: {', '.join(avoid[:10])}")
        if high: print(f"  HIGH quality: {', '.join(high[:10])}")

    p2 = all_results.get("phase2", {})
    if isinstance(p2, dict):
        validated = sum(1 for g in p2.values() if isinstance(g, dict)
                        for t in g.get("thresholds", {}).values()
                        if isinstance(t, dict) and t.get("validated"))
        print(f"  Validated thresholds (Phase 02): {validated}")

    p3 = all_results.get("phase3", {})
    gates = p3.get("entry_quality_gates", [])
    validated_gates = [g for g in gates if g.get("validated")]
    print(f"  Entry gates (Phase 03): {len(validated_gates)} validated")

    p4 = all_results.get("phase4", {})
    sl_thresh = p4.get("sl_thresholds", [])
    print(f"  SL thresholds (Phase 04): {len(sl_thresh)}")

    p5 = all_results.get("phase5", {})
    block_rules = p5.get("auction_block_rules", [])
    print(f"  Block rules (Phase 05): {len(block_rules)}")

    p6 = all_results.get("phase6", {})
    lot_mults = p6.get("lot_multipliers", [])
    validated_mults = [m for m in lot_mults if m.get("validated")]
    scale_up = [m for m in validated_mults if m.get("lot_mult", 1.0) > 1.0]
    scale_dn = [m for m in validated_mults if m.get("lot_mult", 1.0) < 1.0]
    print(f"  Lot multipliers (Phase 06): {len(validated_mults)} validated "
          f"(↑{len(scale_up)} up, ↓{len(scale_dn)} down)")


if __name__ == "__main__":
    main()
