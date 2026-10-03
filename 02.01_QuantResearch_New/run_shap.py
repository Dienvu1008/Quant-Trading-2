"""run_shap.py — Standalone CLI for SHAP Analysis Layer.

Usage examples:
    python run_shap.py --target production_profit --seed 42 --symbols XAUUSDm --start 01.2025 --end 09.2026
    python run_shap.py --target all_styles_win
    python run_shap.py --experiment-id shap_test_001

Required:
    --target    target mode: production_profit | all_styles_win | consensus_profit (default: production_profit)

Optional:
    --symbols   comma-separated symbols, e.g. XAUUSDm
    --start     start month, e.g. 01.2025
    --end       end month, e.g. 09.2026
    --seed      random seed (default: 42)
    --model     model type: lightgbm | xgboost (default: lightgbm)
    --experiment-id  override experiment ID (auto-generated if omitted)
    --no-interactions  disable SHAP-C interaction values (expensive, default: disabled)
    --output-dir     output root directory (default: output/shap)
"""
from __future__ import annotations

import argparse
import datetime as dt
import sys
import traceback
from pathlib import Path


# ─── Make project importable ─────────────────────────────────────
_ROOT = Path(__file__).parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="run_shap",
        description="SHAP Analysis Layer — hypothesis generator for VP Analysis pipeline",
    )
    parser.add_argument(
        "--target",
        default="production_profit",
        choices=["production_profit", "all_styles_win", "consensus_profit"],
        help="Target mode for SHAP analysis (default: production_profit)",
    )
    parser.add_argument(
        "--symbols",
        default=None,
        help="Comma-separated list of symbols, e.g. XAUUSDm,EURUSDm",
    )
    parser.add_argument(
        "--start",
        default=None,
        help="Start month in MM.YYYY format, e.g. 01.2025",
    )
    parser.add_argument(
        "--end",
        default=None,
        help="End month in MM.YYYY format, e.g. 09.2026",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for model and SHAP (default: 42)",
    )
    parser.add_argument(
        "--model",
        default="lightgbm",
        choices=["lightgbm", "xgboost"],
        dest="model_type",
        help="Model type for SHAP (default: lightgbm)",
    )
    parser.add_argument(
        "--experiment-id",
        default=None,
        dest="experiment_id",
        help="Override experiment ID (auto-generated if omitted)",
    )
    parser.add_argument(
        "--no-grouped",
        action="store_true",
        default=False,
        help="Disable per-(symbol,setup) grouped analysis, use global pooled model instead",
    )
    parser.add_argument(
        "--no-interactions",
        action="store_true",
        default=False,
        help="Disable SHAP-C interaction values (expensive, disabled by default)",
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        dest="output_dir",
        help="Output root directory (default: output/shap/<experiment_id>)",
    )
    parser.add_argument(
        "--max-signals",
        type=int,
        default=50000,
        dest="max_signals",
        help="Max signals to use for SHAP (randomly sampled, default: 50000). Use smaller value for faster runs.",
    )
    parser.add_argument(
        "--min-rows",
        type=int,
        default=50,
        dest="min_rows",
        help="Minimum signal rows required to run SHAP (default: 50)",
    )
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)

    # ── Check shap package ───────────────────────────────────────
    try:
        import shap as _shap_pkg  # noqa: F401
    except ImportError:
        print(
            "[ERROR] shap package not installed.\n"
            "Install with: pip install shap\n"
            "Also install a model backend: pip install lightgbm  (or xgboost)"
        )
        return 1

    # ── Build config ─────────────────────────────────────────────
    try:
        from vp_analysis.shap.shap_config import SHAPConfig
        config = SHAPConfig(
            target_mode=args.target,
            model_type=args.model_type,
            seed=args.seed,
            compute_interaction_values=not args.no_interactions,
            run_shap_c=not args.no_interactions,
            min_rows_total=args.min_rows,
            max_signals=args.max_signals,
            run_grouped=not args.no_grouped,
        )
    except Exception as e:
        print(f"[ERROR] Invalid configuration: {e}")
        return 1

    # ── Generate experiment ID ───────────────────────────────────
    if args.experiment_id:
        experiment_id = args.experiment_id
    else:
        ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
        experiment_id = f"shap_{ts}"

    # ── Set output directory ─────────────────────────────────────
    if args.output_dir:
        output_dir = Path(args.output_dir) / experiment_id
    else:
        output_dir = _ROOT / "output" / "shap" / experiment_id

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"SHAP Analysis Layer")
    print(f"{'='*60}")
    print(f"  Experiment ID : {experiment_id}")
    print(f"  Target mode   : {args.target}")
    print(f"  Model         : {args.model_type}")
    print(f"  Seed          : {args.seed}")
    if args.symbols:
        print(f"  Symbols       : {args.symbols}")
    if args.start:
        print(f"  Start         : {args.start}")
    if args.end:
        print(f"  End           : {args.end}")
    print(f"  Output dir    : {output_dir}")
    print(f"{'='*60}\n")

    # ── Load data ────────────────────────────────────────────────
    symbols = [s.strip() for s in args.symbols.split(",")] if args.symbols else None

    try:
        from data_loader import load_merged
        merged_df = load_merged(
            symbols=symbols,
            start=args.start,
            end=args.end,
        )
    except ImportError as e:
        print(f"[ERROR] Cannot import data_loader: {e}")
        print("Make sure you run this script from the project root directory.")
        return 1
    except Exception as e:
        print(f"[ERROR] Data loading failed: {e}")
        traceback.print_exc()
        return 1

    if merged_df is None or merged_df.empty:
        print("[ERROR] No data loaded. Check symbols/date range and data files.")
        return 1

    print(f"[DATA] Loaded {len(merged_df):,} rows")

    # ── Load contract ────────────────────────────────────────────
    try:
        from vp_analysis.core.research_contract import ResearchContract
        from contracts import load_latest_contract
        contract = load_latest_contract()
    except Exception:
        # Try to auto-detect contract
        try:
            contract = _load_contract_fallback()
        except Exception as e:
            print(f"[WARN] Could not load contract: {e}")
            print("[WARN] Using auto-detected features from dataframe columns.")
            contract = None

    # ── Resolve available features ───────────────────────────────
    available_features = _resolve_features(merged_df, contract)
    print(f"[FEATURES] {len(available_features)} available features")

    # ── Run SHAP layer ───────────────────────────────────────────
    try:
        from vp_analysis.layers.L_shap import run_shap_layer
        result = run_shap_layer(
            dev_df=merged_df,
            dev_df_3style=merged_df,  # full 3-style data passed as both
            contract=contract,
            available_features=available_features,
            config=config,
            output_dir=output_dir,
            experiment_id=experiment_id,
        )
    except Exception as e:
        print(f"[ERROR] SHAP layer failed: {e}")
        traceback.print_exc()
        return 1

    # ── Report result ────────────────────────────────────────────
    print(f"\n{'='*60}")
    if result.null_result:
        print(f"[RESULT] NULL — {result.null_reason}")
    elif result.completed:
        print(f"[RESULT] SUCCESS")
        print(f"  Signals   : {result.n_signals}")
        print(f"  Features  : {result.n_features}")
        print(f"  Hypotheses: {result.n_hypotheses}")
        print(f"  Elapsed   : {result.elapsed_sec:.1f}s")
    else:
        print(f"[RESULT] INCOMPLETE — {result.null_reason}")
    print(f"  Output    : {result.output_dir}")
    print(f"{'='*60}\n")

    return 0 if (result.completed or result.null_result) else 1


# ─── Helpers ─────────────────────────────────────────────────────

def _load_contract_fallback():
    """Try to find and load the most recent contract JSON."""
    contracts_dir = _ROOT / "contracts"
    if not contracts_dir.exists():
        raise FileNotFoundError(f"contracts/ directory not found at {contracts_dir}")

    json_files = sorted(contracts_dir.glob("*.json"), reverse=True)
    if not json_files:
        raise FileNotFoundError("No contract JSON files found in contracts/")

    from vp_analysis.core.research_contract import ResearchContract
    import json
    with json_files[0].open(encoding="utf-8") as fh:
        data = json.load(fh)
    print(f"[CONTRACT] Loaded from {json_files[0].name}")
    return ResearchContract.from_dict(data)


def _resolve_features(df, contract) -> list:
    """Resolve available features from contract or dataframe columns."""
    from vp_analysis.shap.shap_dataset import SHAP_FORBIDDEN_FEATURES

    if contract is not None:
        # Collect all pre-registered features from contract
        features = []
        for feat_list in contract.pre_registered.values():
            features.extend(feat_list)
        # Filter to only columns that actually exist in df
        features = [f for f in features if f in df.columns]
        if features:
            return features

    # Fallback: use all numeric columns except forbidden
    numeric_cols = df.select_dtypes(include=["number"]).columns.tolist()
    features = [
        c for c in numeric_cols
        if c not in SHAP_FORBIDDEN_FEATURES
        and not c.startswith("_")
    ]
    return features


if __name__ == "__main__":
    sys.exit(main())
