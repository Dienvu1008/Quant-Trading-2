"""Command-line entry point for vp_analysis.

Usage:
    python -m vp_analysis \\
        --contract contracts/contract_v1.yaml \\
        --data path/to/merged.parquet \\
        --output output/run_001 \\
        --pipeline-config pipeline_config.yaml
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

from .core.experiment_manifest import ExperimentLineage, ExperimentManifest
from .core.governance import Governance
from .core.provenance import hash_dataframe
from .core.research_contract import ResearchContract
from .pipeline import run_pipeline
from .pipeline_config import PipelineConfig


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="vp_analysis",
        description="Run the full VP analysis pipeline.",
    )
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--data", required=True, type=Path,
                        help="Path to merged DataFrame (.parquet or .csv)")
    parser.add_argument("--output", type=Path, default=Path("output"),
                        help="Root output directory")
    parser.add_argument("--pipeline-config", type=Path, default=None,
                        help="Optional pipeline config YAML")
    parser.add_argument("--lineage", type=Path, default=None,
                        help="Path to lineage JSON")
    parser.add_argument("--parent-experiment", default=None,
                        help="Parent experiment_id for follow-up")

    args = parser.parse_args(argv)

    # ─── Load data ──────────────────────────────────────────────
    data_path = Path(args.data)
    if data_path.suffix == ".parquet":
        merged = pd.read_parquet(data_path)
    elif data_path.suffix == ".csv":
        merged = pd.read_csv(data_path)
    else:
        print(f"[ERROR] Unsupported data format: {data_path.suffix}", file=sys.stderr)
        return 2

    if len(merged) == 0:
        print("[ERROR] Data is empty", file=sys.stderr)
        return 2

    # ─── Load contract ──────────────────────────────────────────
    contract = ResearchContract.from_yaml(args.contract)
    contract.freeze()

    # ─── Setup lineage + governance ─────────────────────────────
    output_root = Path(args.output)
    output_root.mkdir(parents=True, exist_ok=True)
    lineage_path = args.lineage or (output_root / "lineage.json")
    lineage = ExperimentLineage(storage_path=lineage_path)

    dataset_hash = hash_dataframe(
        merged, exclude_cols=["time", "profitUSD", "_profit"],
    )
    gov = Governance(contract, lineage)

    try:
        gov.check_budget_before_start(dataset_hash)
    except Exception as e:
        print(f"[ERROR] Governance budget check failed: {e}", file=sys.stderr)
        return 3

    eid = gov.next_experiment_id(dataset_hash)
    manifest = ExperimentManifest(
        experiment_id=eid,
        research_contract_hash=contract.contract_hash,
        dataset_hash=dataset_hash,
        code_hash=contract.code_hash,
        parent_experiment_id=args.parent_experiment,
    )

    # ─── Load pipeline config ───────────────────────────────────
    if args.pipeline_config:
        from .pipeline_config import load_config
        cfg = load_config(args.pipeline_config)
    else:
        cfg = PipelineConfig()

    # ─── Run ────────────────────────────────────────────────────
    print(f"[INFO] Experiment: {eid}")
    print(f"[INFO] Dataset hash: {dataset_hash[:24]}...")
    print(f"[INFO] Output: {output_root / 'experiments' / eid}")

    result = run_pipeline(
        merged_df=merged,
        contract=contract,
        manifest=manifest,
        lineage=lineage,
        config=cfg,
        output_dir=output_root,
    )

    print(f"[INFO] Completed: {result.completed}")
    print(f"[INFO] Elapsed: {result.elapsed_sec:.1f}s")
    if result.halted_at:
        print(f"[WARN] Halted at {result.halted_at}: {result.halt_reason}")
    if result.outcome:
        print(f"[INFO] Outcome: {result.outcome}")

    return 0 if result.completed else 1


if __name__ == "__main__":
    sys.exit(main())
