"""SHAPModel — deterministic LightGBM/XGBoost model for SHAP analysis.

Purpose: feature attribution, not prediction optimization.
All hyperparameters are fixed from SHAPConfig — no hyperparameter search.
n_jobs=1 and fixed seeds ensure bit-for-bit reproducibility.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import pandas as pd


# ─── Model wrapper ───────────────────────────────────────────────

@dataclass
class SHAPModel:
    """Fitted model wrapper with provenance metadata."""
    model: Any                   # fitted LightGBM or XGBoost model
    model_type: str
    feature_names: List[str]
    params: Dict
    is_classifier: bool          # True for binary targets
    n_samples_train: int
    feature_importances_gain: Dict[str, float] = field(default_factory=dict)

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        """Predict target values (raw, not probability)."""
        X_arr = X[self.feature_names].values.astype(np.float32)
        if self.model_type == "lightgbm":
            return self.model.predict(X_arr)
        else:  # xgboost
            import xgboost as xgb
            dmatrix = xgb.DMatrix(X_arr, feature_names=self.feature_names)
            return self.model.predict(dmatrix)

    def save(self, model_dir: Path) -> None:
        """Save model + params to model_dir."""
        model_dir = Path(model_dir)
        model_dir.mkdir(parents=True, exist_ok=True)

        # Save model
        try:
            import joblib
            joblib.dump(self.model, model_dir / "model.joblib")
        except Exception as e:
            print(f"  [WARN] Could not save model with joblib: {e}")

        # Save params
        meta = {
            "model_type": self.model_type,
            "feature_names": self.feature_names,
            "params": self.params,
            "is_classifier": self.is_classifier,
            "n_samples_train": self.n_samples_train,
            "feature_importances_gain": self.feature_importances_gain,
        }
        with (model_dir / "model_params.json").open("w", encoding="utf-8") as fh:
            json.dump(meta, fh, indent=2, default=str)

    @classmethod
    def load(cls, model_dir: Path) -> "SHAPModel":
        """Load from model_dir."""
        model_dir = Path(model_dir)
        import joblib
        model = joblib.load(model_dir / "model.joblib")
        with (model_dir / "model_params.json").open(encoding="utf-8") as fh:
            meta = json.load(fh)
        return cls(
            model=model,
            model_type=meta["model_type"],
            feature_names=meta["feature_names"],
            params=meta["params"],
            is_classifier=meta["is_classifier"],
            n_samples_train=meta["n_samples_train"],
            feature_importances_gain=meta.get("feature_importances_gain", {}),
        )


# ─── Fitting ─────────────────────────────────────────────────────

def fit_shap_model(
    dataset,           # SHAPDataset
    config=None,       # SHAPConfig
) -> SHAPModel:
    """Fit a SHAP model on the dataset.

    Raises:
        ImportError if the requested model library is not installed.
        ValueError if dataset is too small.
    """
    from .shap_config import SHAPConfig
    cfg = config or SHAPConfig()

    X: pd.DataFrame = dataset.X
    y: np.ndarray = dataset.y.values.astype(np.float32)
    feature_names = dataset.feature_names

    if len(X) < cfg.min_rows_total:
        raise ValueError(f"Too few training samples: {len(X)} < {cfg.min_rows_total}")

    # Determine if binary classification or regression
    unique_y = np.unique(y)
    is_binary = len(unique_y) == 2 and set(unique_y).issubset({0.0, 1.0})
    is_classifier = is_binary

    if cfg.model_type == "lightgbm":
        model, params = _fit_lightgbm(X, y, feature_names, cfg, is_classifier)
    elif cfg.model_type == "xgboost":
        model, params = _fit_xgboost(X, y, feature_names, cfg, is_classifier)
    else:
        raise ValueError(f"Unknown model_type: {cfg.model_type!r}")

    # Feature importances (gain-based)
    fi = _get_importances(model, cfg.model_type, feature_names)

    return SHAPModel(
        model=model,
        model_type=cfg.model_type,
        feature_names=feature_names,
        params=params,
        is_classifier=is_classifier,
        n_samples_train=len(X),
        feature_importances_gain=fi,
    )


# ─── LightGBM ────────────────────────────────────────────────────

def _fit_lightgbm(X, y, feature_names, cfg, is_classifier: bool):
    try:
        import lightgbm as lgb
    except ImportError:
        raise ImportError(
            "LightGBM not installed. Install with: pip install lightgbm"
        )

    X_arr = X[feature_names].values.astype(np.float32)

    base_params = {
        "n_estimators": cfg.n_estimators,
        "max_depth": cfg.max_depth,
        "learning_rate": cfg.learning_rate,
        "min_child_samples": cfg.min_child_samples,
        "subsample": cfg.subsample,
        "colsample_bytree": cfg.colsample_bytree,
        "reg_alpha": cfg.reg_alpha,
        "reg_lambda": cfg.reg_lambda,
        "random_state": cfg.seed,
        "n_jobs": 1,             # determinism
        "verbose": -1,
    }

    if is_classifier:
        params = {**base_params, "objective": "binary", "metric": "binary_logloss"}
        clf = lgb.LGBMClassifier(**params)
        clf.fit(X_arr, y.astype(int))
        model = clf
    else:
        params = {**base_params, "objective": "regression", "metric": "rmse"}
        reg = lgb.LGBMRegressor(**params)
        reg.fit(X_arr, y)
        model = reg

    return model, params


# ─── XGBoost ─────────────────────────────────────────────────────

def _fit_xgboost(X, y, feature_names, cfg, is_classifier: bool):
    try:
        import xgboost as xgb
    except ImportError:
        raise ImportError(
            "XGBoost not installed. Install with: pip install xgboost"
        )

    X_arr = X[feature_names].values.astype(np.float32)

    base_params = {
        "n_estimators": cfg.n_estimators,
        "max_depth": cfg.max_depth,
        "learning_rate": cfg.learning_rate,
        "min_child_weight": cfg.min_child_samples,
        "subsample": cfg.subsample,
        "colsample_bytree": cfg.colsample_bytree,
        "reg_alpha": cfg.reg_alpha,
        "reg_lambda": cfg.reg_lambda,
        "seed": cfg.seed,
        "nthread": 1,            # determinism
        "verbosity": 0,
    }

    if is_classifier:
        params = {**base_params, "objective": "binary:logistic", "eval_metric": "logloss"}
        clf = xgb.XGBClassifier(**params)
        clf.fit(X_arr, y.astype(int))
        model = clf
    else:
        params = {**base_params, "objective": "reg:squarederror", "eval_metric": "rmse"}
        reg = xgb.XGBRegressor(**params)
        reg.fit(X_arr, y)
        model = reg

    return model, params


# ─── Feature importances ─────────────────────────────────────────

def _get_importances(model, model_type: str, feature_names: list) -> dict:
    """Extract gain-based feature importances as {feature: importance}."""
    try:
        if model_type == "lightgbm":
            imp = model.booster_.feature_importance(importance_type="gain")
            total = imp.sum()
            if total > 0:
                imp = imp / total
            return {f: float(v) for f, v in zip(feature_names, imp)}
        else:  # xgboost
            scores = model.get_booster().get_fscore()
            total = sum(scores.values()) or 1.0
            return {f: float(scores.get(f, 0.0) / total) for f in feature_names}
    except Exception:
        return {f: 0.0 for f in feature_names}
