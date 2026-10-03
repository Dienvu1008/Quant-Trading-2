"""Configuration loading for the full pipeline.

Wraps individual layer configs into a single PipelineConfig so the
orchestrator only takes one config object.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

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
from .layers.L10a_bad_entry_discovery import BadEntryDiscoveryConfig
from .shap.shap_config import SHAPConfig


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
    bad_entry_discovery: BadEntryDiscoveryConfig = field(default_factory=BadEntryDiscoveryConfig)
    run_bad_entry_discovery: bool = True  # L10a MFE-based bad entry
    bad_entry_discovery: BadEntryDiscoveryConfig = field(default_factory=BadEntryDiscoveryConfig)
    run_bad_entry_discovery: bool = True  # L10a MFE-based bad entry
    bad_entry_discovery: BadEntryDiscoveryConfig = field(default_factory=BadEntryDiscoveryConfig)

    # ─── SHAP analysis layer (optional) ─────────────────────────
    # None = skip SHAP layer; set to SHAPConfig(...) to enable
    shap: Optional[SHAPConfig] = None
    run_shap: bool = False   # set True to enable SHAP after L3 EDA

    # Target mode for L4/L5 discovery
    # "production_profit"  : use profitUSD of production trailing style (default)
    # "all_styles_win"     : use _all_styles_win (binary: 1=all 3 styles profitable)
    #                        deduplicates by signalId to avoid 3x inflation
    target_mode: str = "production_profit"

    # Pipeline behavior flags
    run_soft_gates: bool = True
    run_attribution: bool = True
    run_bad_entry: bool = True
    run_bad_entry_discovery: bool = True  # L10a MFE-based
    run_dev_optimization: bool = True

    # Safety / halt conditions
    halt_on_L0_fail: bool = True
    halt_on_insufficient_features: bool = True
    min_available_features: int = 3


def load_config(path: Path) -> PipelineConfig:
    """Load a PipelineConfig from a YAML file.

    Missing sections fall back to defaults. Unknown keys are ignored.
    Requires PyYAML (pip install pyyaml).
    """
    try:
        import yaml
    except ImportError:
        raise ImportError(
            "PyYAML is required to load pipeline configs. "
            "Install with: pip install pyyaml"
        )

    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {path}")

    with path.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}

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
        min_available_features=int(data.get("min_available_features", 3)),
    )


def _build(cls, kwargs: dict):
    """Construct a frozen dataclass from a dict, ignoring unknown keys."""
    if not isinstance(kwargs, dict):
        return cls()
    field_names = {f for f in cls.__dataclass_fields__}
    filtered = {k: v for k, v in kwargs.items() if k in field_names}
    return cls(**filtered)
