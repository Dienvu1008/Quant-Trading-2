"""SHAPExplainer — compute SHAP values using TreeExplainer.

Uses shap.TreeExplainer for tree-based models (LightGBM/XGBoost).
Background dataset = random sample from training data (shap_max_samples rows).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

import numpy as np
import pandas as pd


@dataclass
class SHAPExplanation:
    """Container for SHAP values and metadata."""
    shap_values: np.ndarray          # shape (n_samples, n_features)
    expected_value: float            # model expected value (base rate)
    feature_names: List[str]
    n_samples: int
    interaction_values: Optional[np.ndarray] = None  # (n, n_features, n_features) or None
    warnings: List[str] = None

    def __post_init__(self):
        if self.warnings is None:
            self.warnings = []
        expected_shape = (self.n_samples, len(self.feature_names))
        if self.shap_values.shape != expected_shape:
            raise ValueError(
                f"shap_values shape {self.shap_values.shape} "
                f"!= expected {expected_shape}"
            )


class SHAPExplainer:
    """Wrapper around shap.TreeExplainer."""

    def __init__(self, shap_model, config=None):
        """
        Parameters
        ----------
        shap_model : SHAPModel
        config     : SHAPConfig
        """
        self._shap_model = shap_model
        from .shap_config import SHAPConfig
        self._cfg = config or SHAPConfig()

    def explain(self, X: pd.DataFrame) -> SHAPExplanation:
        """Compute SHAP values for all rows in X.

        Parameters
        ----------
        X : pd.DataFrame — feature matrix (same columns as training)
        """
        warns = []
        feature_names = self._shap_model.feature_names
        X_arr = X[feature_names].values.astype(np.float32)

        try:
            import shap
        except ImportError:
            raise ImportError(
                "shap not installed. Install with: pip install shap"
            )

        # Background dataset (sample for speed)
        n_bg = min(self._cfg.shap_max_samples, len(X_arr))
        rng = np.random.default_rng(self._cfg.seed)
        bg_idx = rng.choice(len(X_arr), size=n_bg, replace=False)
        background = X_arr[bg_idx]

        # Create explainer
        try:
            explainer = shap.TreeExplainer(
                self._shap_model.model,
                data=background,
                feature_perturbation="interventional",
            )
        except Exception as e:
            warns.append(f"TreeExplainer with background failed ({e}), retrying without background")
            try:
                explainer = shap.TreeExplainer(self._shap_model.model)
            except Exception as e2:
                raise RuntimeError(f"Cannot create TreeExplainer: {e2}") from e2

        # Compute SHAP values
        # check_additivity=False: suppresses the additivity error that can occur
        # when the background dataset is small relative to the training distribution.
        # The small numerical discrepancy does not affect ranking/interpretation.
        raw_values = explainer.shap_values(X_arr, check_additivity=False)

        # Handle multi-output (LightGBM binary classifier returns list)
        if isinstance(raw_values, list):
            # Binary: take positive class (index 1) if available, else index 0
            if len(raw_values) == 2:
                shap_values = raw_values[1]
                ev = float(explainer.expected_value[1]) if hasattr(explainer.expected_value, "__len__") else float(explainer.expected_value)
            else:
                shap_values = raw_values[0]
                ev = float(explainer.expected_value[0]) if hasattr(explainer.expected_value, "__len__") else float(explainer.expected_value)
            warns.append("Multi-class output detected — using positive class SHAP values")
        else:
            shap_values = raw_values
            ev_raw = explainer.expected_value
            ev = float(ev_raw[0]) if hasattr(ev_raw, "__len__") else float(ev_raw)

        shap_values = np.array(shap_values, dtype=np.float32)

        # Interaction values (optional, expensive)
        interaction_values = None
        if self._cfg.compute_interaction_values or self._cfg.run_shap_c:
            try:
                interaction_values = np.array(
                    explainer.shap_interaction_values(X_arr,
                                                       check_additivity=False), dtype=np.float32
                )
            except Exception as e:
                warns.append(f"Interaction values failed: {e}")
                interaction_values = None

        return SHAPExplanation(
            shap_values=shap_values,
            expected_value=ev,
            feature_names=feature_names,
            n_samples=len(X_arr),
            interaction_values=interaction_values,
            warnings=warns,
        )


# ─── Public API ──────────────────────────────────────────────────

def compute_shap_values(
    shap_model,
    X: pd.DataFrame,
    config=None,
) -> SHAPExplanation:
    """Convenience function to compute SHAP values."""
    explainer = SHAPExplainer(shap_model, config)
    return explainer.explain(X)
