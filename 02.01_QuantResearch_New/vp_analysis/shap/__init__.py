"""SHAP Analysis Layer for VP Analysis pipeline.

Hypothesis generator: SHAP values → prioritized feature hypotheses
that are validated through the existing L4/L5/L6 FDR pipeline.

Usage:
    from vp_analysis.shap import run_shap_analysis
    result = run_shap_analysis(
        dev_df=dev_df,
        contract=contract,
        available_features=available_features,
        experiment_id="shap_001",
        output_dir=Path("output/shap/shap_001"),
    )
"""
from .shap_config import SHAPConfig
from .shap_dataset import SHAPDataset, SHAPDatasetBuilder, build_shap_dataset
from .shap_model import SHAPModel, fit_shap_model
from .shap_explainer import SHAPExplanation, SHAPExplainer, compute_shap_values
from .shap_provenance import SHAPRunMeta

__all__ = [
    "SHAPConfig",
    "SHAPDataset",
    "SHAPDatasetBuilder",
    "build_shap_dataset",
    "SHAPModel",
    "fit_shap_model",
    "SHAPExplanation",
    "SHAPExplainer",
    "compute_shap_values",
    "SHAPRunMeta",
]
