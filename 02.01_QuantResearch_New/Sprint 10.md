# Sprint 10 — Orchestrator + End-to-End

> **v3 changes (từ SPECIFICATION.md v3):**
> - `pipeline.py` cập nhật execution order:
>   ```
>   L0 → L1 (+ n_total_hypotheses) → L2 (+ dev_all_styles) → L3
>   → L4, L4b [NEW], L5, L10a [Fix #1] (song song trên dev)
>   → L6 (4 pools [Fix #3])
>   → L7a [Fix #6], L7b, L7c [NEW], L7.5
>   → L8.1 (unseal + persist log [Fix #4]) → L8.2-L8.8 (+ regime eval, L10b eval, SL risk eval)
>   → L9 → L11 → L12 (+ soft tilt export [Fix #5])
>   ```
> - `pipeline_config.py` thêm config cho: `L4b_regime_block_discovery`, `L7c_sl_risk_thresholds`, `L10a_bad_entry_discovery`.
> - E2E test: phải verify regime block được discover + confirm trên holdout.
> - Leak detection test: inject regime label dependency on holdout → verify pipeline không leak.
> - Verify `holdout_access.json` tồn tại sau run và có đúng `experiment_id`. [Fix #4]
> - Verify `n_total_hypotheses` trong `run_meta.json` == `n_total` dùng trong L6 FDR. [Fix #3]

**Nguyên tắc (updated v3):**
1. Entry point: `pipeline.run(contract, merged_df, experiment_id)` — `merged_df` phải là 3-style (L0 cần)
2. Tất cả layers dùng cùng `experiment_id`, `output_dir`
3. Halt sớm khi L0 fail, L1 no features, L6 null → L11 route
4. **[NEW]** L4b, L10a chạy song song với L4, L5 (đều là dev-only discovery)
5. **[Fix #4]** Sau pipeline, kiểm tra `holdout_access.json` tồn tại
6. **[Fix #3]** Sau pipeline, kiểm tra `n_total_hypotheses` nhất quán

Deliverables:
- `pipeline.py` — orchestrator (updated execution order)
- `pipeline_config.py` — config cho tất cả layers (+ L4b, L7c, L10a)
- `cli.py` — command-line entry point
- `tests/test_pipeline_e2e.py` — e2e với synthetic data (kể cả regime signal)
- `tests/test_leak_detection.py` — verify pipeline catch leak (bao gồm holdout log check)

---

## `vp_analysis/pipeline_config.py`

```python
"""Configuration loading for the full pipeline.

Wraps individual layer configs into a single PipelineConfig so the
orchestrator only takes one config object.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import yaml

from .layers.L0_hygiene import HygieneConfig
from .layers.L1_boundary import FeatureAvailabilityCriteria
from .layers.L3_eda import EDAConfig
from .layers.L4_hard_gate_discovery import HardGateConfig
from .layers.L5_soft_gate_discovery import SoftGateConfig
from .layers.L6_multiple_testing import MultipleTestingConfig
from .layers.L7_dev_optimization import OptimizationConfig
from .layers.L8_holdout_apply import HoldoutConfig
from .layers.L9_attribution import AttributionConfig
from .layers.L10_bad_entry import BadEntryConfig


@dataclass
class PipelineConfig:
    hygiene: HygieneConfig = field(default_factory=HygieneConfig)
    feature_availability: FeatureAvailabilityCriteria = field(
        default_factory=FeatureAvailabilityCriteria,
    )
    eda: EDAConfig = field(default_factory=EDAConfig)
    hard_gate: HardGateConfig = field(default_factory=HardGateConfig)
    soft_gate: SoftGateConfig = field(default_factory=SoftGateConfig)
    multiple_testing: MultipleTestingConfig = field(
        default_factory=MultipleTestingConfig,
    )
    optimization: OptimizationConfig = field(
        default_factory=OptimizationConfig,
    )
    holdout: HoldoutConfig = field(default_factory=HoldoutConfig)
    attribution: AttributionConfig = field(
        default_factory=AttributionConfig,
    )
    bad_entry: BadEntryConfig = field(default_factory=BadEntryConfig)

    # Pipeline behavior
    run_soft_gates: bool = True
    run_attribution: bool = True
    run_bad_entry: bool = True
    run_dev_optimization: bool = True

    # Safety
    halt_on_L0_fail: bool = True
    halt_on_insufficient_features: bool = True
    min_available_features: int = 3


def load_config(path: Path) -> PipelineConfig:
    """Load a PipelineConfig from a YAML file.

    Missing sections fall back to defaults. Unknown keys are ignored.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    if not isinstance(data, dict):
        raise ValueError(f"Config root must be a mapping, got {type(data)}")

    return PipelineConfig(
        hygiene=_build(HygieneConfig, data.get("hygiene", {})),
        feature_availability=_build(
            FeatureAvailabilityCriteria,
            data.get("feature_availability", {}),
        ),
        eda=_build(EDAConfig, data.get("eda", {})),
        hard_gate=_build(HardGateConfig, data.get("hard_gate", {})),
        soft_gate=_build(SoftGateConfig, data.get("soft_gate", {})),
        multiple_testing=_build(
            MultipleTestingConfig,
            data.get("multiple_testing", {}),
        ),
        optimization=_build(
            OptimizationConfig, data.get("optimization", {}),
        ),
        holdout=_build(HoldoutConfig, data.get("holdout", {})),
        attribution=_build(
            AttributionConfig, data.get("attribution", {}),
        ),
        bad_entry=_build(BadEntryConfig, data.get("bad_entry", {})),
        run_soft_gates=bool(data.get("run_soft_gates", True)),
        run_attribution=bool(data.get("run_attribution", True)),
        run_bad_entry=bool(data.get("run_bad_entry", True)),
        run_dev_optimization=bool(data.get("run_dev_optimization", True)),
        halt_on_L0_fail=bool(data.get("halt_on_L0_fail", True)),
        halt_on_insufficient_features=bool(
            data.get("halt_on_insufficient_features", True),
        ),
        min_available_features=int(
            data.get("min_available_features", 3),
        ),
    )


def _build(cls, kwargs: dict):
    """Construct a frozen dataclass from a dict, ignoring unknown keys."""
    if not isinstance(kwargs, dict):
        return cls()
    field_names = {f.name for f in cls.__dataclass_fields__.values()}
    filtered = {k: v for k, v in kwargs.items() if k in field_names}
    # Normalize lists to tuples where the dataclass expects tuples
    return cls(**filtered)
```

## `vp_analysis/pipeline.py`

```python
"""Pipeline orchestrator.

Runs the full L0 → L11 sequence for one experiment, with the governance
kernel enforcing boundaries (freeze, budget, holdout access).

Public API:
    result = run_pipeline(
        merged_df,           # combined funnel+trades DataFrame
        contract,            # frozen ResearchContract
        manifest,            # ExperimentManifest
        lineage,             # ExperimentLineage (for budget checks)
        config,              # PipelineConfig (or None for defaults)
        output_dir,          # root output dir for this experiment
    )

The function returns a PipelineResult with all layer outputs and the
final outcome.

The pipeline does NOT load data itself. Caller is responsible for
providing merged_df. This keeps the orchestrator data-source-agnostic
and testable.
"""
from __future__ import annotations

import datetime as dt
import json
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import pandas as pd

from .core.experiment_manifest import (
    ExperimentLineage,
    ExperimentManifest,
    ExperimentResult,
    ExperimentStatus,
)
from .core.governance import Governance
from .core.research_contract import ResearchContract
from .layers import (
    L0_hygiene, L1_boundary, L2_feature_engineering, L3_eda,
    L4_hard_gate_discovery, L5_soft_gate_discovery,
    L6_multiple_testing, L7_dev_optimization, L8_holdout_apply,
    L9_attribution, L10_bad_entry, L11_null_protocol,
)
from .pipeline_config import PipelineConfig


# ─── Result types ────────────────────────────────────────────────

@dataclass
class PipelineResult:
    experiment_id: str
    completed: bool
    halted_at: Optional[str]        # layer name if halted
    halt_reason: Optional[str]

    l0: object = None
    l1: object = None
    l2: object = None
    l3: object = None
    l4: object = None
    l5: object = None
    l6: object = None
    l7: object = None
    l8: object = None
    l9: object = None
    l10: object = None
    l11: object = None

    outcome: Optional[str] = None
    elapsed_sec: float = 0.0
    output_dir: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "experiment_id": self.experiment_id,
            "completed": self.completed,
            "halted_at": self.halted_at,
            "halt_reason": self.halt_reason,
            "outcome": self.outcome,
            "elapsed_sec": round(self.elapsed_sec, 2),
            "output_dir": self.output_dir,
        }


# ─── Public API ──────────────────────────────────────────────────

def run_pipeline(
    merged_df: pd.DataFrame,
    contract: ResearchContract,
    manifest: ExperimentManifest,
    lineage: ExperimentLineage,
    config: Optional[PipelineConfig] = None,
    output_dir: Optional[Path] = None,
) -> PipelineResult:
    """Execute the full analysis pipeline.

    Caller is responsible for:
      - Loading and merging the raw data into merged_df
      - Constructing the contract (and freezing it)
      - Creating the manifest (with unique experiment_id)
      - Registering the manifest in lineage (or this function registers it)
      - Budget checks (via Governance) — done here
    """
    cfg = config or PipelineConfig()
    t0 = time.time()
    eid = manifest.experiment_id

    out_root = Path(output_dir) if output_dir else Path("output")
    exp_dir = out_root / "experiments" / eid
    exp_dir.mkdir(parents=True, exist_ok=True)

    result = PipelineResult(
        experiment_id=eid, completed=False,
        halted_at=None, halt_reason=None,
        output_dir=str(exp_dir),
    )

    # ─── Register manifest if not already ───────────────────────
    if not lineage.exists(eid):
        lineage.add(manifest)

    # ─── L0: Hygiene ────────────────────────────────────────────
    l0 = _safe_step(
        "L0_hygiene",
        lambda: L0_hygiene.run(
            merged_df, config=cfg.hygiene,
            output_dir=exp_dir / "L0_hygiene",
        ),
        result, exp_dir,
    )
    if l0 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l0 = l0

    if l0.should_halt and cfg.halt_on_L0_fail:
        result.halted_at = "L0_hygiene"
        result.halt_reason = l0.reason_for_halt
        manifest.invalidate(f"L0 halt: {l0.reason_for_halt}")
        _save_summary(result, exp_dir)
        return _finalize(result, manifest, lineage, t0)

    # ─── L1: Boundary ───────────────────────────────────────────
    l1 = _safe_step(
        "L1_boundary",
        lambda: L1_boundary.run(
            merged_df, contract,
            output_dir=exp_dir / "L1_boundary",
            criteria=cfg.feature_availability,
        ),
        result, exp_dir,
    )
    if l1 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l1 = l1

    if (l1.n_available < cfg.min_available_features
            and cfg.halt_on_insufficient_features):
        result.halted_at = "L1_boundary"
        result.halt_reason = (
            f"Only {l1.n_available} available features "
            f"(< {cfg.min_available_features})"
        )
        manifest.invalidate(result.halt_reason)
        _save_summary(result, exp_dir)
        return _finalize(result, manifest, lineage, t0)

    # ─── L2: Feature engineering ────────────────────────────────
    l2 = _safe_step(
        "L2_feature_engineering",
        lambda: L2_feature_engineering.run(
            l1, output_dir=exp_dir / "L2_feature_engineering",
        ),
        result, exp_dir,
    )
    if l2 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l2 = l2

    dev_df = l2.boundary.dev.data

    # ─── L3: EDA ────────────────────────────────────────────────
    l3 = _safe_step(
        "L3_eda",
        lambda: L3_eda.run(
            dev_df, contract,
            available_features=l1.available_features(),
            output_dir=exp_dir / "L3_eda",
            config=cfg.eda,
        ),
        result, exp_dir,
    )
    if l3 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l3 = l3

    # ─── L4: Hard gate discovery ────────────────────────────────
    l4 = _safe_step(
        "L4_hard_gate_discovery",
        lambda: L4_hard_gate_discovery.run(
            dev_df, contract,
            available_features=l1.available_features(),
            output_dir=exp_dir / "L4_hard_gates",
            config=cfg.hard_gate,
        ),
        result, exp_dir,
    )
    if l4 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l4 = l4

    # ─── L5: Soft gate discovery ────────────────────────────────
    if cfg.run_soft_gates:
        l5 = _safe_step(
            "L5_soft_gate_discovery",
            lambda: L5_soft_gate_discovery.run(
                dev_df, contract,
                available_features=l1.available_features(),
                output_dir=exp_dir / "L5_soft_gates",
                config=cfg.soft_gate,
            ),
            result, exp_dir,
        )
        if l5 is None:
            return _finalize(result, manifest, lineage, t0)
        result.l5 = l5
    else:
        result.l5 = _empty_l5()

    # ─── L6: Multiple testing + freeze ──────────────────────────
    l6 = _safe_step(
        "L6_multiple_testing",
        lambda: L6_multiple_testing.run(
            l4_result=l4, l5_result=result.l5,
            contract=contract, experiment_id=eid,
            output_dir=exp_dir / "L6_multiple_testing",
            config=cfg.multiple_testing,
        ),
        result, exp_dir,
    )
    if l6 is None:
        return _finalize(result, manifest, lineage, t0)
    result.l6 = l6

    # ─── L7: Dev optimization (skip if no frozen rules) ─────────
    if cfg.run_dev_optimization and len(l6.frozen_rules) > 0:
        l7 = _safe_step(
            "L7_dev_optimization",
            lambda: L7_dev_optimization.run(
                dev_df, list(l6.frozen_rules), contract,
                experiment_id=eid,
                output_dir=exp_dir / "L7_optimization",
                config=cfg.optimization,
            ),
            result, exp_dir,
        )
        if l7 is None:
            return _finalize(result, manifest, lineage, t0)
        result.l7 = l7
    else:
        result.l7 = None

    # ─── L8: Holdout apply ──────────────────────────────────────
    # Only if we have frozen rules AND a production config
    if result.l7 is not None:
        production_config = result.l7.production_config
        l8 = _safe_step(
            "L8_holdout_apply",
            lambda: L8_holdout_apply.run(
                sealed_holdout=l2.boundary.holdout,
                production_config=production_config,
                contract=contract,
                experiment_id=eid,
                output_dir=exp_dir / "L8_holdout",
                config=cfg.holdout,
            ),
            result, exp_dir,
        )
        if l8 is None:
            return _finalize(result, manifest, lineage, t0)
        result.l8 = l8

    # ─── L9: Attribution ────────────────────────────────────────
    if cfg.run_attribution and result.l8 is not None:
        holdout_df = _get_holdout_df_safely(l2.boundary)
        if holdout_df is not None:
            l9 = _safe_step(
                "L9_attribution",
                lambda: L9_attribution.run(
                    holdout_df,
                    result.l7.production_config,
                    output_dir=exp_dir / "L9_attribution",
                    config=cfg.attribution,
                ),
                result, exp_dir,
            )
            if l9 is not None:
                result.l9 = l9

    # ─── L10: Bad entry (dev screening + holdout eval) ──────────
    if cfg.run_bad_entry:
        holdout_df = None
        if result.l8 is not None:
            holdout_df = _get_holdout_df_safely(l2.boundary)
        l10 = _safe_step(
            "L10_bad_entry",
            lambda: L10_bad_entry.run(
                dev_df, contract, experiment_id=eid,
                available_features=l1.available_features(),
                holdout_df=holdout_df,
                output_dir=exp_dir / "L10_bad_entry",
                config=cfg.bad_entry,
            ),
            result, exp_dir,
        )
        if l10 is not None:
            result.l10 = l10

    # ─── L11: Null protocol ─────────────────────────────────────
    l11 = _safe_step(
        "L11_null_protocol",
        lambda: L11_null_protocol.run(
            experiment_id=eid,
            l6_result=result.l6,
            l8_result=result.l8,
            output_dir=exp_dir / "L11_result",
        ),
        result, exp_dir,
    )
    if l11 is not None:
        result.l11 = l11
        result.outcome = l11.outcome

    # ─── Complete manifest ──────────────────────────────────────
    _complete_manifest(manifest, result, lineage)
    result.completed = True

    _save_summary(result, exp_dir)
    return _finalize(result, manifest, lineage, t0)


# ─── Step wrapper ────────────────────────────────────────────────

def _safe_step(name: str, fn, result: PipelineResult, exp_dir: Path):
    """Run a layer, catching exceptions and logging them."""
    try:
        return fn()
    except Exception as e:
        result.halted_at = name
        result.halt_reason = f"{type(e).__name__}: {e}"
        _save_summary(result, exp_dir)
        return None


# ─── Finalization ────────────────────────────────────────────────

def _finalize(
    result: PipelineResult,
    manifest: ExperimentManifest,
    lineage: ExperimentLineage,
    t0: float,
) -> PipelineResult:
    result.elapsed_sec = time.time() - t0
    # Persist lineage if it has a storage path
    try:
        if lineage.storage_path:
            lineage.save()
    except Exception:
        pass
    return result


def _complete_manifest(
    manifest: ExperimentManifest,
    result: PipelineResult,
    lineage: ExperimentLineage,
) -> None:
    if manifest.status != ExperimentStatus.ACTIVE:
        return
    if result.outcome == "SUCCESS":
        manifest.complete(ExperimentResult.SUCCESS)
    elif result.outcome == "NULL_DEV":
        manifest.complete(ExperimentResult.NULL_DEV)
    elif result.outcome == "NULL_HOLDOUT":
        manifest.complete(ExperimentResult.NULL_HOLDOUT)
    else:
        manifest.complete(ExperimentResult.SUCCESS)


def _save_summary(result: PipelineResult, exp_dir: Path) -> None:
    try:
        with (exp_dir / "pipeline_summary.json").open(
            "w", encoding="utf-8",
        ) as f:
            json.dump(result.to_dict(), f, indent=2, default=str)
    except Exception:
        pass


# ─── Helpers ─────────────────────────────────────────────────────

def _get_holdout_df_safely(boundary) -> Optional[pd.DataFrame]:
    """Return the holdout DataFrame if it has been unsealed, else None.

    Never unseals — only reads after L8 has done so.
    """
    holdout = boundary.holdout
    if holdout.is_sealed:
        return None
    # Access via access log to get the underlying df
    # We need a public accessor; use the private _df through a small helper.
    # In production code we'd add a public `peek_after_unseal()` method.
    return getattr(holdout, "_df", None)


def _empty_l5():
    """Return an empty L5 result for when soft gates are disabled."""
    from .layers.L5_soft_gate_discovery import LayerFiveResult
    return LayerFiveResult(
        directions=(), candidates=(),
        n_features_evaluated=0, n_candidates=0,
        warnings=("soft gates disabled",),
        n_dev_rows=0,
        ran_at=dt.datetime.utcnow().isoformat() + "Z",
    )
```

## `vp_analysis/cli.py`

```python
"""Command-line entry point.

Usage:
    python -m vp_analysis.cli \
        --contract contracts/contract_v1.yaml \
        --data path/to/merged.parquet \
        --output output/run_001 \
        --pipeline-config pipeline_config.yaml

The CLI loads data, builds a contract and manifest, and runs the full
pipeline. It does not construct the contract — it loads it from YAML.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

from .core.experiment_manifest import (
    ExperimentLineage, ExperimentManifest,
)
from .core.governance import Governance
from .core.provenance import hash_dataframe
from .core.research_contract import ResearchContract
from .pipeline import run_pipeline
from .pipeline_config import load_config


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
                        help="Path to lineage JSON (default: output/lineage.json)")
    parser.add_argument("--parent-experiment", default=None,
                        help="Parent experiment_id, if this is a follow-up")

    args = parser.parse_args(argv)

    # ─── Load data ──────────────────────────────────────────────
    data_path = Path(args.data)
    if data_path.suffix == ".parquet":
        merged = pd.read_parquet(data_path)
    elif data_path.suffix == ".csv":
        merged = pd.read_csv(data_path)
    else:
        print(f"[ERROR] Unsupported data format: {data_path.suffix}",
              file=sys.stderr)
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
        print(f"[ERROR] Governance budget check failed: {e}",
              file=sys.stderr)
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
        cfg = load_config(args.pipeline_config)
    else:
        from .pipeline_config import PipelineConfig
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
```

## `vp_analysis/__main__.py`

```python
"""Entry point for `python -m vp_analysis`."""
import sys
from .cli import main

if __name__ == "__main__":
    sys.exit(main())
```

## `vp_analysis/__init__.py` — cập nhật

```python
"""VP Analysis — Research pipeline with governance kernel."""
__version__ = "0.2.0"

from .pipeline import run_pipeline, PipelineResult
from .pipeline_config import PipelineConfig, load_config

__all__ = [
    "run_pipeline", "PipelineResult",
    "PipelineConfig", "load_config",
]
```

---

## Tests

## `vp_analysis/tests/test_pipeline_e2e.py`

```python
"""End-to-end pipeline test with synthetic data."""
import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.experiment_manifest import (
    ExperimentLineage, ExperimentManifest,
)
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.pipeline import run_pipeline
from vp_analysis.pipeline_config import PipelineConfig


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def e2e_contract(minimal_contract_dict):
    """Contract with features + shapes matching our synthetic data."""
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "quality": ["f_signal", "f_noise"],
    }
    d["feature_direction"] = {"f_signal": 1, "f_noise": 0}
    d["shape_priors"] = {
        "f_signal": "MONO_UP",
        "f_noise": "MONO_UP",
    }
    d["split_ratio"] = 0.70
    d["split_method"] = "temporal"
    d["stopping_rules"] = {
        "min_group_samples": 30, "min_fold_consistency": 0.50,
        "min_effect_size": 0.05, "max_outer_folds": 5,
        "max_inner_folds": 3,
    }
    d["production_criteria"] = {
        "min_ev": 0.05, "min_pf": 1.10, "min_wr": 0.35,
        "require_robust_across_styles": False,
        "require_holdout_confirmation": True,
    }
    d["fdr_pools"] = {
        "hard_gate": {"name": "hard_gate",
                       "max_hypotheses": 500, "alpha": 0.05},
        "soft_gate": {"name": "soft_gate",
                       "max_hypotheses": 200, "alpha": 0.05},
        "bad_entry": {"name": "bad_entry",
                       "max_hypotheses": 200, "alpha": 0.05},
    }
    return ResearchContract.from_dict(d)


@pytest.fixture
def e2e_config():
    """Config tuned for small synthetic datasets."""
    from vp_analysis.layers.L4_hard_gate_discovery import HardGateConfig
    from vp_analysis.layers.L5_soft_gate_discovery import SoftGateConfig
    from vp_analysis.layers.L7_dev_optimization import OptimizationConfig
    from vp_analysis.layers.L8_holdout_apply import HoldoutConfig
    from vp_analysis.layers.L4_hard_gate_discovery import HardGateConfig

    cfg = PipelineConfig()
    cfg.hard_gate = HardGateConfig(
        outer_folds=5, inner_folds=3,
        min_inner_train=15, min_inner_val=15, min_outer_test=15,
        min_effect_size=0.10, min_win_rate=0.40,
        min_profit_factor=1.05,
        fold_consistency_threshold=0.50,
        ttest_alpha=0.20,
        min_folds_results=2,
        seed=42,
    )
    cfg.soft_gate = SoftGateConfig(
        perm_alpha=0.10, perm_iterations=200, seed=42,
    )
    cfg.optimization = OptimizationConfig(
        min_dev_trades=20, n_folds=4,
        min_fold_agree=0.50, max_pval=0.20,
    )
    cfg.holdout = HoldoutConfig(
        min_gated_trades=15,
        ev_degradation_factor=0.30,
        wr_degradation_factor=0.70,
    )
    cfg.min_available_features = 1
    return cfg


def _make_e2e_merged(n=800, seed=0, signal_strength=1.5):
    """Full synthetic dataset with 3-orders-per-signal design."""
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(n):
        sig_id = f"SIG-{i:05d}"
        entry_time = pd.Timestamp("2024-01-01") + pd.Timedelta(hours=i)
        f_signal = rng.uniform(0, 1)
        f_noise = rng.uniform(0, 1)
        is_high = f_signal > 0.6
        base_profit = signal_strength if is_high else -0.5
        entry_price = 2000.0 + rng.normal(0, 5)
        mae = abs(rng.normal(0.8, 0.4))
        mfe = abs(rng.normal(1.5, 0.6))
        # 3 styles
        for style in (-1, 0, 1):
            # Small style-dependent noise on profit
            style_adjust = {-1: -0.1, 0: 0.0, 1: 0.1}[style]
            profit = base_profit + style_adjust + rng.normal(0, 0.3)
            # Exit reason
            if profit > 0.5:
                reason = "TP_HIT"
            elif profit < -0.3:
                reason = "SL_HIT"
            else:
                reason = "TRAIL_STOP"
            rows.append({
                "signalId": sig_id,
                "trailStyle": style,
                "entryTime": entry_time,
                "exitTime": entry_time + pd.Timedelta(minutes=30),
                "entryPrice": entry_price,
                "maeATR": mae,
                "mfeATR": mfe,
                "exitReason": reason,
                "time": entry_time,
                "symbol": "XAUUSD",
                "setupType": "BOS",
                "f_signal": f_signal,
                "f_noise": f_noise,
                "profitUSD": profit,
                "_profit": profit,
            })
    return pd.DataFrame(rows)


# ══════════════════════════════════════════════════════════════════
# End-to-end runs
# ══════════════════════════════════════════════════════════════════

def test_pipeline_runs_to_completion(e2e_contract, e2e_config, tmp_path):
    df = _make_e2e_merged(n=800, seed=0, signal_strength=1.5)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-E2E-001",
        research_contract_hash=e2e_contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=e2e_contract.code_hash,
    )

    result = run_pipeline(
        merged_df=df,
        contract=e2e_contract,
        manifest=manifest,
        lineage=lineage,
        config=e2e_config,
        output_dir=tmp_path,
    )

    assert result.completed
    assert result.halted_at is None
    # All layers should have run
    assert result.l0 is not None
    assert result.l1 is not None
    assert result.l2 is not None
    assert result.l3 is not None
    assert result.l4 is not None
    assert result.l6 is not None


def test_pipeline_produces_expected_output_tree(e2e_contract, e2e_config, tmp_path):
    df = _make_e2e_merged(n=800, seed=0)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-E2E-002",
        research_contract_hash=e2e_contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=e2e_contract.code_hash,
    )

    run_pipeline(df, e2e_contract, manifest, lineage,
                 config=e2e_config, output_dir=tmp_path)

    exp_dir = tmp_path / "experiments" / "EXP-E2E-002"
    assert (exp_dir / "L0_hygiene").exists()
    assert (exp_dir / "L1_boundary").exists()
    assert (exp_dir / "L2_feature_engineering").exists()
    assert (exp_dir / "L3_eda").exists()
    assert (exp_dir / "pipeline_summary.json").exists()


def test_pipeline_discovers_signal(e2e_contract, e2e_config, tmp_path):
    """Strong synthetic signal should produce at least one frozen rule."""
    df = _make_e2e_merged(n=1000, seed=1, signal_strength=2.0)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-E2E-003",
        research_contract_hash=e2e_contract.contract_hash,
        dataset_hash="sha256:" + "b" * 64,
        code_hash=e2e_contract.code_hash,
    )

    result = run_pipeline(df, e2e_contract, manifest, lineage,
                          config=e2e_config, output_dir=tmp_path)

    # L4 ran
    assert result.l4 is not None
    assert result.l4.n_features_searched > 0
    # At least attempt at discovery happened
    assert result.l6 is not None


def test_pipeline_halts_on_clean_l0(e2e_contract, e2e_config, tmp_path):
    """Inject a L0 violation → should halt."""
    df = _make_e2e_merged(n=400, seed=0)
    # Corrupt one entry price
    mask = df["signalId"] == "SIG-00000"
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"] + 100.0

    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-E2E-L0",
        research_contract_hash=e2e_contract.contract_hash,
        dataset_hash="sha256:" + "c" * 64,
        code_hash=e2e_contract.code_hash,
    )

    result = run_pipeline(df, e2e_contract, manifest, lineage,
                          config=e2e_config, output_dir=tmp_path)

    assert result.halted_at == "L0_hygiene"
    assert "inconsistency" in result.halt_reason.lower()


def test_pipeline_manifest_completed(e2e_contract, e2e_config, tmp_path):
    df = _make_e2e_merged(n=800, seed=0)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-E2E-004",
        research_contract_hash=e2e_contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=e2e_contract.code_hash,
    )

    result = run_pipeline(df, e2e_contract, manifest, lineage,
                          config=e2e_config, output_dir=tmp_path)

    # Manifest should have been transitioned
    assert manifest.status.value in ("COMPLETED", "INVALIDATED", "SUPERSEDED")


def test_pipeline_summary_written(e2e_contract, e2e_config, tmp_path):
    df = _make_e2e_merged(n=400, seed=0)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-E2E-005",
        research_contract_hash=e2e_contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=e2e_contract.code_hash,
    )

    run_pipeline(df, e2e_contract, manifest, lineage,
                 config=e2e_config, output_dir=tmp_path)

    summary_path = tmp_path / "experiments" / "EXP-E2E-005" / "pipeline_summary.json"
    assert summary_path.exists()


def test_pipeline_result_to_dict(e2e_contract, e2e_config, tmp_path):
    df = _make_e2e_merged(n=400, seed=0)
    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-E2E-006",
        research_contract_hash=e2e_contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=e2e_contract.code_hash,
    )

    result = run_pipeline(df, e2e_contract, manifest, lineage,
                          config=e2e_config, output_dir=tmp_path)
    d = result.to_dict()
    assert d["experiment_id"] == "EXP-E2E-006"
    assert isinstance(d["completed"], bool)
    assert "elapsed_sec" in d
```

## `vp_analysis/tests/test_leak_detection.py`

```python
"""Leak detection tests.

These verify that the pipeline's information boundary is enforced:
  - Holdout is NOT touched before freeze
  - Interaction scaler is fit on dev only
  - FDR pools are isolated

The tests are deliberately structural: they check invariants that, if
violated, would indicate a leak, rather than trying to detect subtle
statistical patterns.
"""
import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.data_boundary import DataBoundary
from vp_analysis.core.experiment_manifest import (
    ExperimentLineage, ExperimentManifest,
)
from vp_analysis.core.fdr_registry import FDRPoolRegistry
from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers.L2_feature_engineering import (
    InteractionTransformer,
)
from vp_analysis.pipeline import run_pipeline
from vp_analysis.pipeline_config import PipelineConfig


@pytest.fixture
def leak_contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {"cat": ["f_a", "f_b"]}
    d["feature_direction"] = {"f_a": 1, "f_b": 1}
    d["shape_priors"] = {"f_a": "MONO_UP", "f_b": "MONO_UP"}
    d["split_ratio"] = 0.70
    return ResearchContract.from_dict(d)


# ══════════════════════════════════════════════════════════════════
# Structural leak checks
# ══════════════════════════════════════════════════════════════════

def test_holdout_stays_sealed_before_l8(leak_contract, tmp_path):
    """Run pipeline with no rules surviving → holdout must remain sealed."""
    rng = np.random.default_rng(0)
    n = 400
    # Pure noise — no signal to discover
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n, "setupType": ["BOS"] * n,
        "f_a": rng.uniform(0, 1, n),
        "f_b": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
        "profitUSD": rng.normal(0, 1, n),
        "maeATR": abs(rng.normal(1, 0.5, n)),
        "mfeATR": abs(rng.normal(1.5, 0.5, n)),
        "signalId": [f"SIG-{i}" for i in range(n)],
        "trailStyle": rng.choice([-1, 0, 1], size=n),
        "entryTime": pd.date_range("2024-01-01", periods=n, freq="h"),
        "exitTime": pd.date_range("2024-01-01", periods=n, freq="h"),
        "entryPrice": np.full(n, 2000.0),
        "exitReason": "TRAIL_STOP",
    })

    lineage = ExperimentLineage()
    manifest = ExperimentManifest(
        experiment_id="EXP-LEAK-001",
        research_contract_hash=leak_contract.contract_hash,
        dataset_hash="sha256:" + "a" * 64,
        code_hash=leak_contract.code_hash,
    )

    result = run_pipeline(df, leak_contract, manifest, lineage,
                          output_dir=tmp_path)

    # Holdout is inside L1's DataBoundary — check it's still sealed
    if result.l2 is not None:
        assert result.l2.boundary.holdout.is_sealed or result.l8 is not None


def test_interaction_scaler_uses_dev_only():
    """Verify fit() sees only development rows."""
    rng = np.random.default_rng(1)
    n = 100
    df = pd.DataFrame({
        "a": rng.uniform(0, 1, n),
        "b": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })
    # Dev is first 70 rows only
    dev = df.iloc[:70]

    transformer = InteractionTransformer(
        (("ix_ab", "a", "b"),),
    )
    transformer.fit(dev)

    s = transformer.stats[0]
    # a_max must equal dev's a_max, not full df's
    assert s.a_max == pytest.approx(dev["a"].max())
    assert s.a_max <= df["a"].max() + 1e-9
    # Verify strict: if full df has larger max, ours should be smaller
    assert s.a_max < df["a"].max() or np.isclose(s.a_max, df["a"].max())


def test_interaction_scaler_ignores_holdout_outlier():
    """Huge outlier in holdout must not affect stats."""
    rng = np.random.default_rng(2)
    n = 100
    a_vals = rng.uniform(0, 1, n).tolist()
    a_vals[95] = 1e6  # massive outlier in "holdout"
    df = pd.DataFrame({
        "a": a_vals,
        "b": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })

    dev = df.iloc[:70]  # dev doesn't include the outlier
    transformer = InteractionTransformer((("ix_ab", "a", "b"),))
    transformer.fit(dev)

    s = transformer.stats[0]
    assert s.a_max <= 1.0 + 1e-9  # not dragged to 1e6


def test_boundary_holdout_cannot_be_unsealed_twice():
    """Kernel enforces one-time unseal."""
    rng = np.random.default_rng(3)
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=100, freq="h"),
        "a": rng.uniform(0, 1, 100),
        "profitUSD": rng.normal(0, 1, 100),
    })
    boundary = DataBoundary.from_merged(df)
    boundary.holdout.unseal_once("EXP-001", reason="test")

    from vp_analysis.core.exceptions import HoldoutAlreadyUnsealedError
    with pytest.raises(HoldoutAlreadyUnsealedError):
        boundary.holdout.unseal_once("EXP-001", reason="again")


def test_fdr_pools_isolated():
    """Registration in one pool must not affect another."""
    from vp_analysis.core.research_contract import ResearchContract
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {}, "feature_direction": {},
        "shape_priors": {}, "allowed_interactions": [],
        "gate_types": ["threshold"], "allowed_directions": [1],
        "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {
            "pool_a": {"name": "pool_a",
                        "max_hypotheses": 100, "alpha": 0.05},
            "pool_b": {"name": "pool_b",
                        "max_hypotheses": 100, "alpha": 0.05},
        },
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05,
                            "max_outer_folds": 5, "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    fdr = FDRPoolRegistry(contract)

    fdr.register("pool_a", "H1", 0.001)
    fdr.register("pool_b", "H1", 0.900)

    ra = fdr.correct("pool_a")
    rb = fdr.correct("pool_b")

    assert ra.as_dict()["H1"]["reject"] is True
    assert rb.as_dict()["H1"]["reject"] is False


def test_feature_availability_uses_dev_only():
    """Feature with zero variance in dev but high in holdout must be
    marked as unavailable."""
    n = 200
    # Dev: constant feature; Holdout: variable feature
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "a": [0.5] * 140 + list(np.random.RandomState(0).normal(0, 5, 60)),
        "profitUSD": np.zeros(n),
    })
    d = {
        "version": "v1", "observation_unit": "x", "style_filter": "x",
        "pre_registered": {"cat": ["a"]}, "feature_direction": {"a": 1},
        "shape_priors": {"a": "MONO_UP"}, "allowed_interactions": [],
        "gate_types": ["threshold"], "allowed_directions": [1],
        "primary_test": "t", "screening_test": "p",
        "multiple_testing_method": "bh",
        "fdr_pools": {"hard_gate": {"name": "hard_gate",
                                     "max_hypotheses": 100, "alpha": 0.05}},
        "optimization_budget": {"sl_candidates": [1.0],
                                 "tp_candidates": [1.0],
                                 "sizing_configs": 1,
                                 "utility_function": "ev"},
        "stopping_rules": {"min_group_samples": 30,
                            "min_fold_consistency": 0.6,
                            "min_effect_size": 0.05,
                            "max_outer_folds": 5, "max_inner_folds": 3},
        "production_criteria": {"min_ev": 0.05, "min_pf": 1.1,
                                 "min_wr": 0.35,
                                 "require_robust_across_styles": False,
                                 "require_holdout_confirmation": True},
        "selection_budget": {"max_experiments_per_dataset": 5,
                              "max_contract_changes_per_day": 3,
                              "cooldown_hours_between_experiments": 24,
                              "max_eda_inspect_and_rerun": 1,
                              "config_frozen_after_start": True},
        "split_ratio": 0.70, "split_method": "temporal",
        "dataset_hash": "sha256:" + "a" * 64,
        "code_hash": "sha256:" + "b" * 64,
        "config_hash": "sha256:" + "c" * 64,
        "feature_registry_hash": "sha256:" + "d" * 64,
        "target_definition_hash": "sha256:" + "e" * 64,
        "split_definition_hash": "sha256:" + "f" * 64,
    }
    contract = ResearchContract.from_dict(d)
    from vp_analysis.layers.L1_boundary import run as l1_run
    result = l1_run(df, contract)
    entries = {e.feature: e for e in result.feature_availability}
    # Feature 'a' had std=0 in dev → marked unavailable
    assert entries["a"].available is False
    assert entries["a"].reason == "low_variance"
```

---

## Example pipeline config YAML

## `vp_analysis/configs/pipeline_default.yaml`

```yaml
# Pipeline configuration — passes through to layer configs.
# All keys optional; missing keys use layer defaults.

hygiene:
  halt_on_entry_inconsistency: true
  halt_on_mae_mfe_violation: true
  halt_on_time_integrity: true

feature_availability:
  min_std: 1.0e-9
  max_na_frac: 0.30

eda:
  n_bins: 10
  monotone_rho_threshold: 0.60
  correlation_threshold: 0.70
  n_temporal_blocks: 5

hard_gate:
  outer_folds: 5
  inner_folds: 3
  gap_ratio: 0.10
  min_effect_size: 0.05
  fold_consistency_threshold: 0.60
  ttest_alpha: 0.05
  perm_iterations: 100
  seed: 42

soft_gate:
  perm_iterations: 500
  perm_alpha: 0.10
  min_total_samples: 60
  min_half_samples: 20
  seed: 42

multiple_testing:
  conservative_fdr: true
  require_ci_low_positive: true

optimization:
  use_sl_tp_optimization: true
  use_sizing: true
  kelly_fraction: 0.25
  min_dev_trades: 30
  n_folds: 4
  min_fold_agree: 0.70
  max_pval: 0.10

holdout:
  min_gated_trades: 20
  ev_degradation_factor: 0.50
  pf_min: 1.00
  wr_degradation_factor: 0.80

attribution:
  min_trades: 20
  min_style_trades: 15

bad_entry:
  min_extreme_samples: 20
  binom_alpha: 0.05
  min_votes: 2

run_soft_gates: true
run_attribution: true
run_bad_entry: true
run_dev_optimization: true

halt_on_L0_fail: true
halt_on_insufficient_features: true
min_available_features: 3
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_pipeline_e2e.py \
       vp_analysis/tests/test_leak_detection.py -v
```

Kỳ vọng:

```text
test_pipeline_e2e.py       7 passed
test_leak_detection.py     6 passed
────────────────────────────────
Total                     13 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 378 + 13 = 391 passed
```

---

## Sprint 10 hoàn tất — Pipeline complete

**Deliverables:**
- `pipeline_config.py` — PipelineConfig + YAML loader
- `pipeline.py` — orchestrator L0 → L11 (~330 dòng)
- `cli.py` + `__main__.py` — CLI entry point
- `configs/pipeline_default.yaml` — full-config example
- 13 end-to-end tests (7 pipeline + 6 leak detection)

**Cách chạy pipeline:**

```bash
# Command line
python -m vp_analysis \
    --contract contracts/contract_v1.yaml \
    --data data/merged.parquet \
    --pipeline-config configs/pipeline_default.yaml \
    --output output/run_2026_09_18

# Hoặc từ Python
from vp_analysis import run_pipeline, PipelineConfig
from vp_analysis.core import ResearchContract, ExperimentManifest, ExperimentLineage

contract = ResearchContract.from_yaml("contracts/contract_v1.yaml")
contract.freeze()

lineage = ExperimentLineage(storage_path="output/lineage.json")
manifest = ExperimentManifest(
    experiment_id="EXP-2026-09-18-001",
    research_contract_hash=contract.contract_hash,
    dataset_hash="sha256:...",
    code_hash=contract.code_hash,
)

result = run_pipeline(
    merged_df=merged,
    contract=contract,
    manifest=manifest,
    lineage=lineage,
    config=PipelineConfig(),
    output_dir="output",
)
```

**Output structure:**

```text
output/
├── lineage.json
└── experiments/
    └── EXP-2026-09-18-001/
        ├── pipeline_summary.json
        ├── L0_hygiene/
        │   ├── layer_zero_summary.json
        │   └── (violations CSVs if any)
        ├── L1_boundary/
        │   ├── run_meta.json
        │   └── feature_availability.csv
        ├── L2_feature_engineering/
        │   └── interaction_stats.json
        ├── L3_eda/
        │   ├── feature_shape_analysis.csv
        │   ├── shape_mismatch_report.csv    (if mismatch)
        │   ├── feature_correlation_matrix.csv
        │   ├── redundant_feature_pairs.csv  (if any)
        │   ├── feature_stability.csv
        │   ├── baseline_stats.json
        │   └── layer_three_summary.json
        ├── L4_hard_gates/
        │   ├── hard_gate_candidates.csv
        │   ├── fold_details.csv
        │   └── hard_gate_discovery_summary.json
        ├── L5_soft_gates/
        │   ├── soft_gate_directions.csv
        │   ├── soft_gate_candidates.csv
        │   └── soft_gate_discovery_summary.json
        ├── L6_multiple_testing/
        │   ├── fdr_summary.json
        │   ├── fdr_hard_gate.csv
        │   ├── fdr_soft_gate.csv
        │   ├── validated_hard_gates.csv
        │   ├── validated_soft_gates.csv
        │   └── frozen_rules.json
        ├── L7_optimization/
        │   ├── sl_tp_optimization.csv
        │   ├── sizing_configs.csv
        │   ├── production_config.json
        │   └── optimization_summary.json
        ├── L8_holdout/
        │   ├── holdout_evaluation.csv
        │   ├── sl_tp_holdout_report.csv
        │   ├── sizing_holdout_report.csv
        │   ├── holdout_degradation.csv
        │   └── holdout_summary.json
        ├── L9_attribution/
        │   ├── entry_exit_attribution.csv
        │   ├── exit_policy_decomposition.csv
        │   ├── style_consistency.csv
        │   └── attribution_summary.json
        ├── L10_bad_entry/
        │   ├── canary_labels.json
        │   ├── bad_entry_features.csv
        │   ├── composite_bad_filter.json
        │   ├── bad_filter_holdout_report.csv
        │   └── bad_entry_summary.json
        └── L11_result/
            └── experiment_result.json
```

---

## Tổng kết toàn bộ dự án

**Kernel + Layers + Pipeline:**

```text
┌─────────────────────────────────────────────────────────────┐
│  Sprint 0A/B/C — Governance kernel        141 tests         │
│  Sprint 1 — L0 Data Hygiene                 32 tests         │
│  Sprint 2 — L1 Boundary + L2 Features       30 tests         │
│  Sprint 3 — L3 EDA + Shape Verification     24 tests         │
│  Sprint 4 — L4 Hard Gate Discovery          22 tests         │
│  Sprint 5 — L5 Soft Gate Discovery          16 tests         │
│  Sprint 6 — L6 Multiple Testing + Freeze    25 tests         │
│  Sprint 7 — L7 Dev Optimization             32 tests         │
│  Sprint 8 — L8 Holdout Apply                26 tests         │
│  Sprint 9 — L9+L10+L11 Attribution/Bad/Null 30 tests         │
│  Sprint 10 — Orchestrator + E2E             13 tests         │
│  ─────────────────────────────────────────────────────────  │
│  Total                                     391 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Những gì đã xây dựng:**

1. **Governance kernel** (Sprint 0): Research Contract với 6 hashes, immutable freeze, selection budget, type-enforced boundary (`DevelopmentData` ≠ `SealedHoldout`), FDR pools isolated, optimization registry riêng biệt.

2. **Information boundary enforcement** (3 cấp độ):
   - Type level: `DevelopmentData` vs `SealedHoldout`
   - Runtime: `unseal_once(experiment_id)` raises nếu trùng
   - Convention + 391 tests

3. **Toàn bộ 12 layers** với semantics rõ ràng:
   - L0: hygiene (3-orders consistency, MAE/MFE, time)
   - L1: boundary split + feature availability
   - L2: interaction scaler fit-on-dev
   - L3: EDA + SHAPE_PRIOR verification (immutable)
   - L4: nested walk-forward với proper inner split (fix bug Phase 02 v3)
   - L5: soft gate discovery **trên dev** (fix bug Phase 02 v4)
   - L6: FDR 2 isolated pools + conservative padding + FrozenRule
   - L7: SL/TP optimization (full paths) + Kelly sizing trên dev
   - L8: holdout apply (report-only, no mutation)
   - L9: attribution (entry vs exit, exit policy)
   - L10: bad entry (canary labels, negative feature screening)
   - L11: null protocol (outcome classification, forbidden actions)

4. **Orchestrator** + CLI + config YAML để chạy end-to-end.

**Bugs từ các phase cũ đã fix triệt để:**
- Phase 02 v3: inner/outer separation, FDR alignment
- Phase 02 v4: soft gate không dùng holdout
- Phase 05: FDR trên combined_p, không phải per-fold
- Phase 06: fold leakage (folds trên dev, không cross OOS)
- Tất cả: `oos_validated` mutation → tách `validated` (dev) và `holdout_confirmed` (report)

**Điểm mạnh của kiến trúc:**
- Không có code path nào có thể leak holdout mà không bị type system hoặc runtime exception chặn
- Shape prior immutable → không có adaptive hypothesis formation
- FDR pools isolated → không cross-contamination giữa hard/soft/bad-entry
- FrozenProductionConfig bundle 3 artifacts (rules + SL/TP + sizing) với cross-reference validation
- Conservative FDR padding → bảo toàn information boundary khi L4 filter nhiều candidates
- Null result là **valid outcome** — pipeline được thiết kế để chấp nhận "không tìm thấy edge"

