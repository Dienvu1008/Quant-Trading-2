"""SHAPConfig — configuration dataclass for the SHAP analysis layer.

All parameters are immutable after construction to ensure reproducibility.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass(frozen=True)
class SHAPConfig:
    """Configuration for the SHAP analysis layer.

    target_mode options:
        "production_profit"  - profitUSD of production-style (trailStyle=1) trades
        "all_styles_win"     - binary: 1 if all 3 styles profitable, dedup by signalId
        "consensus_profit"   - mean(profitUSD) across 3 styles, dedup by signalId

    model_type options:
        "lightgbm"   - LightGBM GBM (default, fast)
        "xgboost"    - XGBoost (alternative)
    """

    # --- Target ---
    target_mode: str = "production_profit"
    production_style: int = 1                 # trailStyle value for production

    # --- Model ---
    model_type: str = "lightgbm"
    n_estimators: int = 200
    max_depth: int = 4
    learning_rate: float = 0.05
    min_child_samples: int = 20               # LGB: min_child_samples (XGB: min_child_weight)
    subsample: float = 0.8
    colsample_bytree: float = 0.8
    reg_alpha: float = 0.1                    # L1 regularization
    reg_lambda: float = 1.0                   # L2 regularization
    seed: int = 42

    # --- SHAP computation ---
    shap_max_samples: int = 2000              # background dataset size for TreeExplainer
    max_signals: int = 50000                  # max signals to sample before SHAP (0=all)
    compute_interaction_values: bool = False  # expensive — off by default

    # --- Which analyses to run ---
    run_shap_a: bool = True    # global importance
    run_shap_b: bool = True    # dependence plots
    run_shap_c: bool = False   # interaction values (expensive)
    run_shap_d: bool = True    # trigger-conditional
    run_shap_e: bool = True    # regime-conditional
    run_shap_f: bool = True    # local explanations
    run_shap_g: bool = True    # entry edge vs exit policy
    run_shap_h: bool = True    # stability analysis

    # --- Analysis parameters ---
    n_local_top: int = 20                     # top-N winning/losing signals for SHAP-F
    n_dependence_top: int = 15               # top-N features for dependence plots (SHAP-B)
    stability_n_folds: int = 4               # temporal folds for SHAP-H
    min_trigger_samples: int = 30            # min rows per trigger for SHAP-D
    min_regime_samples: int = 30             # min rows per regime for SHAP-E
    min_rows_total: int = 50                 # minimum rows needed to run SHAP at all
    min_group_signals: int = 100             # min signals per (symbol, setup) group
    run_grouped: bool = True                 # per-(symbol,setup) instead of global pool
    min_group_signals: int = 100             # min signals per (symbol, setup) group for grouped analysis
    run_grouped: bool = True                 # run per-(symbol,setup) SHAP instead of global

    # --- Output ---
    output_plots: bool = True               # generate matplotlib figures
    plot_format: str = "png"                # "png" | "svg"
    plot_dpi: int = 120

    def __post_init__(self) -> None:
        valid_targets = {"production_profit", "all_styles_win", "consensus_profit"}
        if self.target_mode not in valid_targets:
            raise ValueError(
                f"target_mode must be one of {valid_targets}, got {self.target_mode!r}"
            )
        valid_models = {"lightgbm", "xgboost"}
        if self.model_type not in valid_models:
            raise ValueError(
                f"model_type must be one of {valid_models}, got {self.model_type!r}"
            )
        if self.min_rows_total < 10:
            raise ValueError("min_rows_total must be >= 10")
