
"""
run_pipeline.py — Interactive entry point for the VP Analysis New pipeline.

Run with no arguments — the script will ask everything interactively:

    python run_pipeline.py

Or skip the prompts by passing arguments:

    python run_pipeline.py --contract contracts/contract_v1.yaml \\
        --symbols XAUUSDm --start 01.2025 --end 09.2026

Workflow
--------
  1. Optionally sync fresh MT5 CSVs into the Data/ store
  2. Show available months / symbols
  3. Ask for analysis date range (MM.YYYY .. MM.YYYY)
  4. Ask for production trailing style (-1 / 0 / 1)
  5. Load & merge funnel + trades
  6. Run L0 → L12 pipeline
  7. Print summary + path to generated VPEdgeGuardConfig.mqh
"""
import argparse
import re
import sys
from pathlib import Path

# ─── Setup sys.path so `vp_analysis` package is importable ───────
_ROOT = Path(__file__).parent.resolve()
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

_MONTH_RE = re.compile(r"^\d{2}\.\d{4}$")
_DEFAULT_CONTRACT = _ROOT / "contracts" / "contract_v1.yaml"
_DEFAULT_OUTPUT   = _ROOT / "output"


# ─── Interactive prompts ──────────────────────────────────────────

def _ask_sync() -> bool:
    """Ask whether to sync fresh MT5 data."""
    ans = input("\nSync fresh backtest data from MT5? [y/N]: ").strip().lower()
    return ans in ("y", "yes")


def _ask_range(available_months: list[str]) -> tuple[str | None, str | None]:
    """Ask for start/end months. Returns (None, None) = use all."""
    if available_months:
        print(f"\nAvailable months: {', '.join(available_months)}")
    else:
        print("\n[WARN] No data found in Data/ store.")
        print("       Run 'python migrate_data.py' or 'python data_collect.py' first.")
        return None, None

    print("Enter analysis range (blank = use ALL available months).")
    start = input("  Start month [MM.YYYY]: ").strip()
    if not start:
        return None, None

    end = input(f"  End month   [MM.YYYY, blank={start}]: ").strip()
    if not end:
        end = start

    if not _MONTH_RE.match(start) or not _MONTH_RE.match(end):
        print("[WARN] Invalid format — expected MM.YYYY. Using ALL available data.")
        return None, None

    return start, end


def _ask_symbols(available_symbols: list[str]) -> list[str] | None:
    """Ask which symbols to analyse. None = all."""
    if not available_symbols:
        return None
    print(f"\nAvailable symbols: {', '.join(available_symbols)}")
    raw = input("  Symbols to analyse [comma-sep, blank = ALL]: ").strip()
    if not raw:
        return None
    selected = [s.strip() for s in raw.split(",") if s.strip()]
    unknown = [s for s in selected if s not in available_symbols]
    if unknown:
        print(f"[WARN] Not found in Data store: {', '.join(unknown)}")
    return selected or None


def _ask_production_style() -> int:
    """Ask which trailing style the EA runs Live."""
    print("\nProduction trailing style (used for guard-bound metrics):")
    print("  -1 = no trailing  |  0 = conservative  |  1 = expansion")
    raw = input("  Production style [-1/0/1, blank=1]: ").strip()
    if not raw:
        return 1
    try:
        val = int(raw)
        if val in (-1, 0, 1):
            return val
    except ValueError:
        pass
    print("[WARN] Invalid — using default 1 (expansion).")
    return 1


def _ask_target_mode() -> str:
    """Ask which target to use for gate discovery."""
    print("\nGate discovery target:")
    print("  1 = production_profit  (profitUSD of production trailing style)")
    print("  2 = all_styles_win     (1 if ALL 3 styles profitable — pure entry quality)")
    raw = input("  Target mode [1/2, blank=1]: ").strip()
    if raw == "2":
        return "all_styles_win"
    return "production_profit"


def _ask_sl_threshold() -> int:
    """Ask which SL count threshold to use for bad-entry canary labeling."""
    print("\nBad-entry canary threshold (L10):")
    print("  1 = any SL hit is bad   (strict  — ~85% signals flagged, more blocking)")
    print("  2 = majority SL is bad  (balanced — ~79% signals flagged, current default)")
    raw = input("  SL threshold [1/2, blank=2]: ").strip()
    if raw == "1":
        return 1
    return 2


def _confirm(message: str) -> bool:
    ans = input(f"\n{message} [Y/n]: ").strip().lower()
    return ans in ("", "y", "yes")


# ─── Main ─────────────────────────────────────────────────────────

def interactive_main() -> int:
    """Full interactive flow — no CLI args required."""
    print("=" * 70)
    print("  VP ANALYSIS NEW — RESEARCH PIPELINE")
    print("=" * 70)

    # ── 1. Optionally sync MT5 data ──────────────────────────────
    if _ask_sync():
        from data_collect import sync_data
        sync_data()
    else:
        print("  (skipping sync — using existing Data/ store)")

    # ── 2. Show what's available ─────────────────────────────────
    from data_loader import (
        list_available_months, list_available_symbols,
        check_data_range, load_merged, split_by_style,
    )

    available_syms   = list_available_symbols("VP_Trades")
    available_months = list_available_months("VP_Trades")

    if not available_syms:
        print("\n[BLOCKED] Data/ store is empty.")
        print("  Run 'python migrate_data.py' to copy from the old project.")
        print("  Or run a backtest in DataCollect mode and then 'python data_collect.py'.")
        return 1

    # ── 3. Ask for analysis window ───────────────────────────────
    symbols = _ask_symbols(available_syms)
    start, end = _ask_range(available_months)

    # Missing-months warning
    if start and end:
        ok_t, miss_t = check_data_range(start, end, "VP_Trades")
        ok_f, miss_f = check_data_range(start, end, "VP_Funnel")
        if miss_f:
            print(f"[WARN] Missing FUNNEL months: {', '.join(miss_f)}")
        if miss_t:
            print(f"[WARN] Missing TRADES months: {', '.join(miss_t)}")
        from data_loader import _months_in_range
        if not _months_in_range(start, end):
            print(f"[BLOCKED] Invalid range {start}..{end}.")
            return 1
        print(f"\n  Analyzing: {', '.join(symbols) if symbols else 'ALL symbols'}"
              f"  {start} .. {end}")
    else:
        print(f"\n  Analyzing: {', '.join(symbols) if symbols else 'ALL symbols'}"
              f"  ALL available months")

    # ── 4. Production style ──────────────────────────────────────
    production_style = _ask_production_style()
    print(f"  Production style: {production_style} "
          f"({['no-trailing', 'conservative', 'expansion'][production_style + 1]})")

    # ── 5. Contract ──────────────────────────────────────────────
    if not _DEFAULT_CONTRACT.exists():
        print(f"\n[ERROR] Contract not found: {_DEFAULT_CONTRACT}")
        print("  Run 'python generate_contract.py' to create it.")
        return 1

    if not _confirm(f"Ready to run pipeline with contract '{_DEFAULT_CONTRACT.name}'?"):
        print("Aborted.")
        return 0

    # ── 6. Load data ─────────────────────────────────────────────
    print("\n" + "─" * 60)
    print("LOADING DATA")
    print("─" * 60)
    merged_df = load_merged(symbols=symbols, start=start, end=end)
    if merged_df is None or merged_df.empty:
        print("[BLOCKED] No data loaded. Check Data/ store.")
        return 1

    # ── 7. Setup pipeline ────────────────────────────────────────
    from vp_analysis.core.research_contract import ResearchContract
    from vp_analysis.core.experiment_manifest import (
        ExperimentLineage, ExperimentManifest,
    )
    from vp_analysis.core.governance import Governance
    from vp_analysis.core.provenance import hash_dataframe
    from vp_analysis.pipeline import run_pipeline
    from vp_analysis.pipeline_config import PipelineConfig

    contract = ResearchContract.from_yaml(_DEFAULT_CONTRACT)
    contract.freeze()

    output_root = _DEFAULT_OUTPUT
    output_root.mkdir(parents=True, exist_ok=True)
    lineage = ExperimentLineage(storage_path=output_root / "lineage.json")

    dataset_hash = hash_dataframe(
        merged_df, exclude_cols=["time", "profitUSD", "_profit"],
    )
    gov = Governance(contract, lineage)
    try:
        gov.check_budget_before_start(dataset_hash)
    except Exception as e:
        print(f"[ERROR] Governance budget check failed: {e}")
        return 3

    eid = gov.next_experiment_id(dataset_hash)
    manifest = ExperimentManifest(
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        dataset_hash=dataset_hash,
        code_hash=contract.code_hash,
    )

    cfg = PipelineConfig()
    # ── L0 hygiene tuning for 3-style EA data ────────────────────
    # The EA opens 3 positions per signal at slightly different ticks,
    # so entryPrice and entryTime LEGITIMATELY differ between styles.
    # These are not data errors — they are by design.
    #
    # entry_price: BTC can differ by ~50-300 USD across styles (different ticks).
    # entry_time:  Styles open 1-2s apart (sequential order execution).
    # MAE/MFE:     EA may not log maeATR/mfeATR yet — skip this check.
    from vp_analysis.layers.L0_hygiene import HygieneConfig
    cfg.hygiene = HygieneConfig(
        halt_on_entry_inconsistency=False,  # 3-style design: price/time diffs are normal
        halt_on_mae_mfe_violation=False,    # EA doesn't log MAE/MFE → skip
        dead_trade_warn_fraction=1.1,       # suppress dead-trade warning (all zeros)
    )

    target_mode = _ask_target_mode()
    cfg.target_mode = target_mode
    print(f"  Target mode : {target_mode}")

    sl_threshold = _ask_sl_threshold()
    from vp_analysis.layers.L10_bad_entry import BadEntryConfig as _BEC
    cfg.bad_entry = _BEC(bad_sl_threshold=sl_threshold)
    print(f"  SL threshold: {sl_threshold} "  # noqa
          f"({'any SL = bad' if sl_threshold == 1 else 'majority SL = bad'})")

    # ── 8. Run pipeline ──────────────────────────────────────────
    print("\n" + "─" * 60)
    print(f"RUNNING PIPELINE  [{eid}]")
    print("─" * 60)
    print(f"  Data rows     : {len(merged_df):,}")
    print(f"  Output dir    : {output_root / 'experiments' / eid}")

    result = run_pipeline(
        merged_df=merged_df,
        contract=contract,
        manifest=manifest,
        lineage=lineage,
        config=cfg,
        output_dir=output_root,
    )

    # ── 9. Summary ───────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("PIPELINE COMPLETE")
    print("=" * 70)
    print(f"  Experiment    : {eid}")
    print(f"  Elapsed       : {result.elapsed_sec:.1f}s")
    print(f"  Completed     : {result.completed}")

    if result.halted_at:
        print(f"  [HALT]  at {result.halted_at}: {result.halt_reason}")

    if result.outcome:
        print(f"  Outcome       : {result.outcome}")

    # L6 stats
    if result.l6:
        print(f"\n  FDR results:")
        print(f"    Hard gate inputs    : {result.l6.n_hard_gate_inputs}")
        print(f"    Hard gate validated : {result.l6.n_hard_gate_validated}")
        print(f"    Soft gate validated : {result.l6.n_soft_gate_validated}")
        print(f"    Frozen rules        : {result.l6.n_frozen_rules}")

    # L7 stats
    if result.l7:
        print(f"\n  Optimization:")
        print(f"    SL/TP optimized     : {result.l7.n_sl_tp_optimized}")
        print(f"    Sizing validated    : {result.l7.n_sizing_validated}")

    # L8 stats
    if result.l8:
        rate = result.l8.overall_confirmation_rate
        print(f"\n  Holdout evaluation:")
        print(f"    Rules confirmed     : "
              f"{result.l8.n_rules_confirmed}/{result.l8.n_rules_evaluated}"
              f"  ({rate:.0%})")
        if result.l8.null_result:
            print("    ⚠  NULL RESULT — no rules confirmed on holdout")

    # L12 — EA Guard file
    exp_dir = output_root / "experiments" / eid
    mqh_path = exp_dir / "L12_reporting" / "VPEdgeGuardConfig.mqh"
    if mqh_path.exists():
        print(f"\n  EA Guard file : {mqh_path}")
    else:
        print(f"\n  (EA guard file not generated — no frozen rules passed holdout)")

    print()
    return 0 if result.completed else 1


def cli_main() -> int:
    """Non-interactive CLI mode — all params passed as arguments."""
    parser = argparse.ArgumentParser(
        prog="run_pipeline",
        description="Run the VP Analysis pipeline (non-interactive).",
    )
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=_DEFAULT_OUTPUT)
    parser.add_argument("--symbols", nargs="+", default=None)
    parser.add_argument("--start", default=None)
    parser.add_argument("--end", default=None)
    parser.add_argument("--production-style", type=int, default=1,
                        choices=[-1, 0, 1])
    parser.add_argument("--pipeline-config", type=Path, default=None)
    parser.add_argument("--experiment-id", default=None)
    args = parser.parse_args()

    from data_loader import load_merged, check_data_range
    from vp_analysis.core.research_contract import ResearchContract
    from vp_analysis.core.experiment_manifest import (
        ExperimentLineage, ExperimentManifest,
    )
    from vp_analysis.core.governance import Governance
    from vp_analysis.core.provenance import hash_dataframe
    from vp_analysis.pipeline import run_pipeline
    from vp_analysis.pipeline_config import PipelineConfig

    print(f"\n[INFO] Loading data...")
    merged_df = load_merged(symbols=args.symbols, start=args.start, end=args.end)
    if merged_df is None or merged_df.empty:
        print("[ERROR] No data loaded.")
        return 1

    contract = ResearchContract.from_yaml(args.contract)
    contract.freeze()

    output_root = Path(args.output)
    output_root.mkdir(parents=True, exist_ok=True)
    lineage = ExperimentLineage(storage_path=output_root / "lineage.json")

    dataset_hash = hash_dataframe(
        merged_df, exclude_cols=["time", "profitUSD", "_profit"],
    )
    gov = Governance(contract, lineage)
    try:
        gov.check_budget_before_start(dataset_hash)
    except Exception as e:
        print(f"[ERROR] Governance: {e}")
        return 3

    eid = args.experiment_id or gov.next_experiment_id(dataset_hash)
    manifest = ExperimentManifest(
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        dataset_hash=dataset_hash,
        code_hash=contract.code_hash,
    )

    cfg = PipelineConfig()
    # ── L0 hygiene tuning for 3-style EA data ────────────────────
    # The EA opens 3 positions per signal at slightly different ticks,
    # so entryPrice and entryTime LEGITIMATELY differ between styles.
    # These are not data errors — they are by design.
    #
    # entry_price: BTC can differ by ~50-300 USD across styles (different ticks).
    # entry_time:  Styles open 1-2s apart (sequential order execution).
    # MAE/MFE:     EA may not log maeATR/mfeATR yet — skip this check.
    from vp_analysis.layers.L0_hygiene import HygieneConfig
    cfg.hygiene = HygieneConfig(
        halt_on_entry_inconsistency=False,  # 3-style design: price/time diffs are normal
        halt_on_mae_mfe_violation=False,    # EA doesn't log MAE/MFE → skip
        dead_trade_warn_fraction=1.1,       # suppress dead-trade warning (all zeros)
    )
    if args.pipeline_config:
        from vp_analysis.pipeline_config import load_config
        cfg = load_config(args.pipeline_config)

    print(f"[INFO] Experiment: {eid}  |  {len(merged_df):,} rows")

    result = run_pipeline(
        merged_df=merged_df, contract=contract,
        manifest=manifest, lineage=lineage,
        config=cfg, output_dir=output_root,
    )

    print(f"\n[INFO] Completed: {result.completed}  |  {result.elapsed_sec:.1f}s")
    if result.halted_at:
        print(f"[WARN] Halted at {result.halted_at}: {result.halt_reason}")
    if result.outcome:
        print(f"[INFO] Outcome: {result.outcome}")
    return 0 if result.completed else 1


# ─── Entry point ──────────────────────────────────────────────────

if __name__ == "__main__":
    # If any recognised CLI flags are passed → non-interactive mode.
    # Otherwise → full interactive prompt.
    has_cli_args = any(
        arg.startswith("--") for arg in sys.argv[1:]
    )
    if has_cli_args:
        sys.exit(cli_main())
    else:
        sys.exit(interactive_main())
