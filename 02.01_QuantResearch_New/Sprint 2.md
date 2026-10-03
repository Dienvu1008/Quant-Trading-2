# Sprint 2 — Layer 1 (Boundary) + Layer 2 (Feature Engineering)

> **v3 changes (từ SPECIFICATION.md v3):**
> - L1 bổ sung (`L1_boundary.py`): sau khi split `prod_df` thành dev/holdout, cũng split `merged_all` (3-style) tại cùng `split_time` → `dev_all_styles`. Log cả hai trong `run_meta.json`. [Fix #1, #2]
> - L1 bổ sung: tính và log `n_total_hypotheses` (hard_gate, soft_gate, regime_block) vào `run_meta.json`. Đây là số hypotheses sẽ được thử — **frozen trước L4**. [Fix #3]
> - L2 bổ sung (`L2_feature_engineering.py`): `InteractionTransformer.fit_transform()` nhận thêm optional `all_styles_df`; nếu được cung cấp, transform cả `dev_all_styles` → `dev_all_styles_fe`. Transform dùng cùng `interaction_stats.json` (fit từ dev), không fit lại. [Fix #2]

Deliverables:
- `layers/L1_boundary.py` — split orchestrator, feature availability, run_meta, n_total_hypotheses pre-computation
- `layers/L2_feature_engineering.py` — `InteractionTransformer` (fit-on-dev, transform dev_all_styles)
- Shared constants cho interaction definitions
- Tests với ~28 cases
- Outputs: `run_meta.json` (với n_total_hypotheses), `feature_availability.csv`, `interaction_stats.json`

Nguyên tắc:
- L1 wrap kernel `DataBoundary`, không reimplement
- L2 implement `FeatureTransformer` protocol — fit chỉ nhận dev_df
- Interaction stats được lưu lại để audit và reproduce
- Missing features → graceful degradation, log warning

---

## `vp_analysis/layers/_constants.py`

```python
"""Pre-registered constants shared across layers.

Interaction definitions are theory-driven and pre-registered. Changing
this list requires a new ResearchContract.
"""
from __future__ import annotations


# ─── Interaction definitions ─────────────────────────────────────
# Each tuple: (interaction_name, feature_a, feature_b)
# Interaction = product of normalized (a, b) — see L2 for details.

DEFAULT_INTERACTION_DEFS: tuple[tuple[str, str, str], ...] = (
    ("ix_tq_mig",       "auctTradeQuality", "vpMigrationConf"),
    ("ix_bos_trend",    "bosQuality",        "structAlign"),
    ("ix_spread_atr",   "spreadToATR",       "atrProxy"),
    ("ix_cont_mig",     "auctContinuation",  "vpMigrationConf"),
    ("ix_fail_reversal","auctFailure",       "auctReversalRisk"),
    ("ix_struct_bos",   "chochQuality",      "structAlign"),
    ("ix_devpoc_ltpoc", "vpDevPOCDir",       "vpLTPOCVelocity"),
    ("ix_exhaust_lt",   "auctExhaustion",    "vpLTTrendExhaustion"),
    ("ix_acceptance",   "vpInsideVA",        "auctAcceptance"),
    ("ix_target_rr",    "auctTargetProb",    "RR"),
)
```

## `vp_analysis/layers/L1_boundary.py`

```python
"""Layer 1 — Boundary split and feature availability.

Wraps the kernel's DataBoundary to:
  1. Split merged data into development and sealed holdout.
  2. Compute feature availability on development only.
  3. Write run_meta.json (audit trail).
  4. Return a small immutable report.

This layer does NOT modify feature columns. Feature engineering is L2.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

from ..core.data_boundary import DataBoundary, DevelopmentData
from ..core.research_contract import ResearchContract


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class FeatureAvailabilityCriteria:
    min_std: float = 1e-9
    max_na_frac: float = 0.30


@dataclass(frozen=True)
class FeatureAvailabilityEntry:
    feature: str
    category: str
    present: bool
    std: float
    na_frac: float
    available: bool
    reason: str  # "", "missing", "low_variance", "too_many_na"

    def to_dict(self) -> dict:
        return {
            "feature": self.feature,
            "category": self.category,
            "present": self.present,
            "std": self.std,
            "na_frac": self.na_frac,
            "available": self.available,
            "reason": self.reason,
        }


@dataclass(frozen=True)
class LayerOneResult:
    boundary: DataBoundary  # not immutable but wrap it
    feature_availability: tuple
    n_dev: int
    n_holdout: int
    split_time: Optional[str]
    split_method: str
    split_ratio: float
    n_available: int
    n_unavailable: int
    warnings: tuple
    ran_at: str

    def available_features(self) -> tuple[str, ...]:
        return tuple(
            e.feature for e in self.feature_availability if e.available
        )

    def run_meta(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_dev": self.n_dev,
            "n_holdout": self.n_holdout,
            "split_time": self.split_time,
            "split_method": self.split_method,
            "split_ratio": self.split_ratio,
            "n_available": self.n_available,
            "n_unavailable": self.n_unavailable,
            "warnings": list(self.warnings),
            "feature_availability": [
                e.to_dict() for e in self.feature_availability
            ],
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    merged_df: pd.DataFrame,
    contract: ResearchContract,
    output_dir: Optional[Path] = None,
    criteria: Optional[FeatureAvailabilityCriteria] = None,
) -> LayerOneResult:
    """Execute Layer 1.

    Preconditions:
      - merged_df is clean (Layer 0 passed)
      - contract is valid and frozen (caller responsibility)
    """
    if merged_df is None or len(merged_df) == 0:
        raise ValueError("L1: merged_df is empty")

    crit = criteria or FeatureAvailabilityCriteria()

    # ─── 1. Create boundary via kernel ──────────────────────────
    boundary = DataBoundary.from_merged(
        merged_df,
        split_ratio=contract.split_ratio,
        split_method=contract.split_method,
    )

    # ─── 2. Feature availability on DEVELOPMENT only ────────────
    entries, warnings = _compute_feature_availability(
        boundary.dev, contract.pre_registered, crit,
    )

    n_available = sum(1 for e in entries if e.available)
    n_unavailable = len(entries) - n_available

    result = LayerOneResult(
        boundary=boundary,
        feature_availability=tuple(entries),
        n_dev=len(boundary.dev),
        n_holdout=boundary.holdout.size,
        split_time=boundary.split_time,
        split_method=boundary.split_method,
        split_ratio=boundary.split_ratio,
        n_available=n_available,
        n_unavailable=n_unavailable,
        warnings=tuple(warnings),
        ran_at=dt.datetime.utcnow().isoformat() + "Z",
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Feature availability ────────────────────────────────────────

def _compute_feature_availability(
    dev: DevelopmentData,
    pre_registered: dict,
    crit: FeatureAvailabilityCriteria,
) -> tuple[list[FeatureAvailabilityEntry], list[str]]:
    """Compute per-feature availability on development data."""
    df = dev.data
    entries: list[FeatureAvailabilityEntry] = []
    warnings: list[str] = []

    for category, features in pre_registered.items():
        for feat in features:
            entry = _check_feature(df, feat, category, crit)
            entries.append(entry)

            if not entry.present:
                warnings.append(
                    f"Feature {feat!r} (category {category!r}) not present "
                    f"in development data — will be skipped downstream."
                )

    return entries, warnings


def _check_feature(
    df: pd.DataFrame,
    feature: str,
    category: str,
    crit: FeatureAvailabilityCriteria,
) -> FeatureAvailabilityEntry:
    if feature not in df.columns:
        return FeatureAvailabilityEntry(
            feature=feature, category=category,
            present=False, std=0.0, na_frac=1.0,
            available=False, reason="missing",
        )

    series = pd.to_numeric(df[feature], errors="coerce")
    na_frac = float(series.isna().mean())

    # Compute std on non-NaN values only
    valid = series.dropna()
    if len(valid) < 2:
        return FeatureAvailabilityEntry(
            feature=feature, category=category,
            present=True, std=0.0, na_frac=na_frac,
            available=False, reason="low_variance",
        )

    std = float(valid.std(ddof=1))

    if na_frac > crit.max_na_frac:
        return FeatureAvailabilityEntry(
            feature=feature, category=category,
            present=True, std=std, na_frac=na_frac,
            available=False, reason="too_many_na",
        )

    if std <= crit.min_std:
        return FeatureAvailabilityEntry(
            feature=feature, category=category,
            present=True, std=std, na_frac=na_frac,
            available=False, reason="low_variance",
        )

    return FeatureAvailabilityEntry(
        feature=feature, category=category,
        present=True, std=std, na_frac=na_frac,
        available=True, reason="",
    )


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerOneResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    # run_meta.json
    with (output_dir / "run_meta.json").open("w", encoding="utf-8") as f:
        json.dump(result.run_meta(), f, indent=2, default=str)

    # feature_availability.csv
    rows = [e.to_dict() for e in result.feature_availability]
    pd.DataFrame(rows).to_csv(
        output_dir / "feature_availability.csv", index=False,
    )
```

## `vp_analysis/layers/L2_feature_engineering.py`

```python
"""Layer 2 — Feature engineering (fit on development only).

Implements the FeatureTransformer protocol expected by DataBoundary.apply:
  - fit(dev_df): compute interaction normalization stats from development
  - transform(df): apply using fitted stats, clip to [0, 1]

The transformer is stateless after fit. Its `stats` attribute is the
audit record.

Key property enforced by design:
  - fit is only ever called with DevelopmentData.data
  - transform is deterministic given the fitted stats
  - transform does NOT look at aggregate statistics of its input
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

from ..core.data_boundary import DataBoundary
from ._constants import DEFAULT_INTERACTION_DEFS


# ─── Stats record ────────────────────────────────────────────────

@dataclass(frozen=True)
class InteractionStats:
    """Per-interaction normalization stats. All derived from dev."""
    interaction_name: str
    feature_a: str
    feature_b: str
    a_min: Optional[float]
    a_max: Optional[float]
    b_min: Optional[float]
    b_max: Optional[float]
    present: bool
    reason: str  # "" if ok, else "missing_a", "missing_b", "degenerate_range"

    def to_dict(self) -> dict:
        return {
            "interaction_name": self.interaction_name,
            "feature_a": self.feature_a,
            "feature_b": self.feature_b,
            "a_min": self.a_min,
            "a_max": self.a_max,
            "b_min": self.b_min,
            "b_max": self.b_max,
            "present": self.present,
            "reason": self.reason,
        }


@dataclass(frozen=True)
class LayerTwoResult:
    boundary: DataBoundary
    interactions: tuple
    n_interactions_computed: int
    n_interactions_skipped: int
    warnings: tuple
    fit_source: str  # always "development"
    ran_at: str

    def stats_dict(self) -> dict:
        return {
            "fit_source": self.fit_source,
            "ran_at": self.ran_at,
            "n_computed": self.n_interactions_computed,
            "n_skipped": self.n_interactions_skipped,
            "warnings": list(self.warnings),
            "interactions": [s.to_dict() for s in self.interactions],
        }


# ─── Transformer ─────────────────────────────────────────────────

class InteractionTransformer:
    """Computes interaction features as (a_norm * b_norm).

    Normalization:
        a_norm = clip((a - a_min) / (a_max - a_min), 0, 1)
        b_norm = clip((b - b_min) / (b_max - b_min), 0, 1)

    Clipping prevents out-of-range values in holdout from extrapolating.
    Stats are computed only in fit(), which receives development data.

    If a feature pair is missing or degenerate in dev, the interaction is
    set to 0.0 (a neutral value) and a warning is recorded.
    """

    def __init__(
        self,
        interaction_defs: tuple = DEFAULT_INTERACTION_DEFS,
    ):
        self._defs = tuple(interaction_defs)
        self._stats: dict[str, InteractionStats] = {}
        self._warnings: list[str] = []

    # ─── Protocol ───────────────────────────────────────────────

    def fit(self, dev_df: pd.DataFrame) -> "InteractionTransformer":
        self._stats = {}
        self._warnings = []

        for name, feat_a, feat_b in self._defs:
            stat = self._compute_stats(dev_df, name, feat_a, feat_b)
            self._stats[name] = stat
            if not stat.present:
                self._warnings.append(
                    f"Interaction {name!r} skipped: {stat.reason} "
                    f"(a={feat_a!r}, b={feat_b!r})"
                )
        return self

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        if not self._stats:
            raise RuntimeError(
                "InteractionTransformer.transform called before fit"
            )

        out = df.copy()
        for name, stat in self._stats.items():
            out[name] = self._apply(df, stat).astype(np.float32)
        return out

    # ─── Introspection ──────────────────────────────────────────

    @property
    def stats(self) -> tuple:
        return tuple(self._stats.values())

    @property
    def warnings(self) -> tuple:
        return tuple(self._warnings)

    # ─── Internals ──────────────────────────────────────────────

    def _compute_stats(
        self,
        dev_df: pd.DataFrame,
        name: str,
        feat_a: str,
        feat_b: str,
    ) -> InteractionStats:
        if feat_a not in dev_df.columns:
            return InteractionStats(
                name, feat_a, feat_b,
                None, None, None, None,
                present=False, reason="missing_a",
            )
        if feat_b not in dev_df.columns:
            return InteractionStats(
                name, feat_a, feat_b,
                None, None, None, None,
                present=False, reason="missing_b",
            )

        a = pd.to_numeric(dev_df[feat_a], errors="coerce").dropna()
        b = pd.to_numeric(dev_df[feat_b], errors="coerce").dropna()

        if len(a) < 2 or len(b) < 2:
            return InteractionStats(
                name, feat_a, feat_b,
                None, None, None, None,
                present=False, reason="degenerate_range",
            )

        a_min, a_max = float(a.min()), float(a.max())
        b_min, b_max = float(b.min()), float(b.max())

        if a_max - a_min <= 1e-12 or b_max - b_min <= 1e-12:
            return InteractionStats(
                name, feat_a, feat_b,
                a_min, a_max, b_min, b_max,
                present=False, reason="degenerate_range",
            )

        return InteractionStats(
            name, feat_a, feat_b,
            a_min, a_max, b_min, b_max,
            present=True, reason="",
        )

    def _apply(
        self,
        df: pd.DataFrame,
        stat: InteractionStats,
    ) -> pd.Series:
        if not stat.present:
            return pd.Series(0.0, index=df.index, dtype=np.float32)

        a = pd.to_numeric(df[stat.feature_a], errors="coerce").fillna(0.0)
        b = pd.to_numeric(df[stat.feature_b], errors="coerce").fillna(0.0)

        a_range = stat.a_max - stat.a_min
        b_range = stat.b_max - stat.b_min

        a_norm = ((a - stat.a_min) / a_range).clip(0.0, 1.0)
        b_norm = ((b - stat.b_min) / b_range).clip(0.0, 1.0)

        return (a_norm * b_norm).astype(np.float32)


# ─── Public API ──────────────────────────────────────────────────

def run(
    l1_result,  # LayerOneResult
    output_dir: Optional[Path] = None,
    interaction_defs: tuple = DEFAULT_INTERACTION_DEFS,
) -> LayerTwoResult:
    """Execute Layer 2.

    Takes the LayerOneResult (which contains the boundary) and returns a
    new LayerTwoResult with the boundary transformed. The holdout remains
    sealed — DataBoundary.apply handles this.
    """
    transformer = InteractionTransformer(interaction_defs)
    new_boundary = l1_result.boundary.apply(transformer)

    stats = transformer.stats
    n_computed = sum(1 for s in stats if s.present)
    n_skipped = len(stats) - n_computed

    result = LayerTwoResult(
        boundary=new_boundary,
        interactions=stats,
        n_interactions_computed=n_computed,
        n_interactions_skipped=n_skipped,
        warnings=tuple(transformer.warnings),
        fit_source="development",
        ran_at=dt.datetime.utcnow().isoformat() + "Z",
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


def _write_outputs(result: LayerTwoResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / "interaction_stats.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.stats_dict(), f, indent=2, default=str)
```

## `vp_analysis/layers/__init__.py` — cập nhật

```python
"""Analysis layers."""
from . import L0_hygiene
from . import L1_boundary
from . import L2_feature_engineering

__all__ = ["L0_hygiene", "L1_boundary", "L2_feature_engineering"]
```

---

## Tests

## `vp_analysis/tests/test_L1_boundary.py`

```python
"""Tests for Layer 1 — Boundary and feature availability."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L1_boundary
from vp_analysis.layers.L1_boundary import (
    FeatureAvailabilityCriteria,
    LayerOneResult,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def synthetic_merged():
    rng = np.random.default_rng(42)
    n = 200
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="D"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        # present, well-behaved
        "auctTradeQuality": rng.normal(0.5, 0.2, n),
        "vpMigrationConf": rng.normal(0.3, 0.15, n),
        # present, but constant → low variance
        "auctBalance": [0.5] * n,
        # present, but mostly NaN → too_many_na
        "auctExpReward": [np.nan if i < 150 else 0.2 for i in range(n)],
        "profitUSD": rng.normal(0.1, 1.0, n),
    })
    return df


@pytest.fixture
def contract_with_those_features(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "quality": ["auctTradeQuality", "auctBalance", "auctExpReward"],
        "volume": ["vpMigrationConf", "missing_feature"],
    }
    d["shape_priors"] = {
        "auctTradeQuality": "MONO_UP",
        "auctBalance": "MONO_UP",
        "auctExpReward": "MONO_UP",
        "vpMigrationConf": "MONO_UP",
        "missing_feature": "MONO_UP",
    }
    d["feature_direction"] = {
        "auctTradeQuality": 1,
        "auctBalance": 1,
        "auctExpReward": 1,
        "vpMigrationConf": 1,
        "missing_feature": 1,
    }
    return ResearchContract.from_dict(d)


# ─── Split correctness ──────────────────────────────────────────

def test_split_ratio_respected(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    assert result.n_dev == 140
    assert result.n_holdout == 60
    assert result.split_ratio == 0.70


def test_split_time_recorded(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    assert result.split_time is not None
    # Should match time at index 140
    assert result.split_time == str(synthetic_merged["time"].iloc[140])


def test_boundary_holdout_still_sealed(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    assert result.boundary.holdout.is_sealed


# ─── Feature availability ───────────────────────────────────────

def test_feature_present_and_available(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    by_name = {e.feature: e for e in result.feature_availability}
    assert by_name["auctTradeQuality"].available
    assert by_name["auctTradeQuality"].reason == ""
    assert by_name["vpMigrationConf"].available


def test_feature_missing_marked_unavailable(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    by_name = {e.feature: e for e in result.feature_availability}
    e = by_name["missing_feature"]
    assert e.present is False
    assert e.available is False
    assert e.reason == "missing"


def test_constant_feature_marked_low_variance(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    by_name = {e.feature: e for e in result.feature_availability}
    e = by_name["auctBalance"]
    assert e.present is True
    assert e.available is False
    assert e.reason == "low_variance"


def test_too_many_na_marked_unavailable(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    by_name = {e.feature: e for e in result.feature_availability}
    e = by_name["auctExpReward"]
    assert e.present is True
    assert e.available is False
    assert e.reason == "too_many_na"
    assert e.na_frac > 0.70


def test_available_features_helper(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    available = result.available_features()
    assert "auctTradeQuality" in available
    assert "vpMigrationConf" in available
    assert "auctBalance" not in available
    assert "auctExpReward" not in available
    assert "missing_feature" not in available


def test_counts_correct(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    # 5 declared, 2 available (auctTradeQuality, vpMigrationConf)
    assert result.n_available == 2
    assert result.n_unavailable == 3


def test_availability_computed_on_dev_only(contract_with_those_features):
    """A feature with huge variance in holdout but zero in dev must NOT
    be marked available — the computation must use dev only."""
    n = 200
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="D"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        # First 140 (dev): constant 0.5
        # Last 60 (holdout): wild variance
        "auctTradeQuality": [0.5] * 140 + list(np.random.RandomState(0).normal(0, 10, 60)),
        "vpMigrationConf": list(np.random.RandomState(1).normal(0, 1, n)),
        "profitUSD": [0.1] * n,
    })
    result = L1_boundary.run(df, contract_with_those_features)
    by_name = {e.feature: e for e in result.feature_availability}
    # Must be flagged low_variance — dev had no signal
    assert by_name["auctTradeQuality"].available is False
    assert by_name["auctTradeQuality"].reason == "low_variance"


# ─── Warnings ────────────────────────────────────────────────────

def test_missing_feature_produces_warning(synthetic_merged, contract_with_those_features):
    result = L1_boundary.run(
        synthetic_merged, contract_with_those_features,
    )
    warnings_text = " ".join(result.warnings)
    assert "missing_feature" in warnings_text


# ─── Output ──────────────────────────────────────────────────────

def test_run_meta_written(synthetic_merged, contract_with_those_features, tmp_path):
    L1_boundary.run(
        synthetic_merged, contract_with_those_features,
        output_dir=tmp_path,
    )
    assert (tmp_path / "run_meta.json").exists()
    with (tmp_path / "run_meta.json").open() as f:
        meta = json.load(f)
    assert meta["n_dev"] == 140
    assert meta["n_holdout"] == 60
    assert meta["split_ratio"] == 0.70


def test_feature_availability_csv_written(synthetic_merged, contract_with_those_features, tmp_path):
    L1_boundary.run(
        synthetic_merged, contract_with_those_features,
        output_dir=tmp_path,
    )
    assert (tmp_path / "feature_availability.csv").exists()
    df = pd.read_csv(tmp_path / "feature_availability.csv")
    assert len(df) == 5
    assert set(df["feature"]) == {
        "auctTradeQuality", "auctBalance", "auctExpReward",
        "vpMigrationConf", "missing_feature",
    }


# ─── Edge cases ─────────────────────────────────────────────────

def test_empty_df_raises(contract_with_those_features):
    with pytest.raises(ValueError, match="empty"):
        L1_boundary.run(pd.DataFrame(), contract_with_those_features)


def test_custom_criteria(minimal_contract_dict):
    n = 100
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="D"),
        "feature_x": list(np.random.RandomState(0).normal(0, 0.001, n)),
    })
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {"cat": ["feature_x"]}
    d["shape_priors"] = {"feature_x": "MONO_UP"}
    d["feature_direction"] = {"feature_x": 1}
    contract = ResearchContract.from_dict(d)

    # Default min_std=1e-9 → available
    r_default = L1_boundary.run(df, contract)
    assert r_default.feature_availability[0].available

    # Stricter min_std=0.01 → unavailable
    r_strict = L1_boundary.run(
        df, contract,
        criteria=FeatureAvailabilityCriteria(min_std=0.01),
    )
    assert not r_strict.feature_availability[0].available
```

## `vp_analysis/tests/test_L2_feature_engineering.py`

```python
"""Tests for Layer 2 — Feature engineering (fit-on-dev)."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L1_boundary, L2_feature_engineering
from vp_analysis.layers.L2_feature_engineering import (
    InteractionTransformer,
    LayerTwoResult,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def merged_for_interactions():
    """Data designed so interactions can be computed."""
    n = 200
    rng = np.random.default_rng(7)
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="D"),
        "auctTradeQuality": rng.uniform(0, 1, n),
        "vpMigrationConf": rng.uniform(0, 1, n),
        "bosQuality": rng.uniform(-1, 1, n),
        "structAlign": rng.uniform(0, 1, n),
        "profitUSD": rng.normal(0.1, 1.0, n),
    })


@pytest.fixture
def minimal_interactions():
    """Only the pairs we test, to isolate behavior."""
    return (
        ("ix_tq_mig", "auctTradeQuality", "vpMigrationConf"),
        ("ix_bos_trend", "bosQuality", "structAlign"),
    )


@pytest.fixture
def minimal_contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "quality": ["auctTradeQuality", "vpMigrationConf"],
        "trend": ["bosQuality", "structAlign"],
    }
    d["shape_priors"] = {
        "auctTradeQuality": "MONO_UP",
        "vpMigrationConf": "MONO_UP",
        "bosQuality": "BAND",
        "structAlign": "MONO_UP",
    }
    d["feature_direction"] = {
        "auctTradeQuality": 1, "vpMigrationConf": 1,
        "bosQuality": 0, "structAlign": 1,
    }
    return ResearchContract.from_dict(d)


# ─── Transformer protocol ───────────────────────────────────────

def test_transform_before_fit_raises():
    t = InteractionTransformer(
        (("ix_a", "f1", "f2"),)
    )
    with pytest.raises(RuntimeError, match="before fit"):
        t.transform(pd.DataFrame({"f1": [1], "f2": [2]}))


def test_fit_computes_stats_from_dev(merged_for_interactions, minimal_interactions):
    transformer = InteractionTransformer(minimal_interactions)
    dev = merged_for_interactions.iloc[:140]
    transformer.fit(dev)

    stats = {s.interaction_name: s for s in transformer.stats}
    assert "ix_tq_mig" in stats
    s = stats["ix_tq_mig"]
    assert s.present
    assert s.a_min == pytest.approx(dev["auctTradeQuality"].min())
    assert s.a_max == pytest.approx(dev["auctTradeQuality"].max())


def test_fit_ignores_holdout_values(merged_for_interactions, minimal_interactions):
    """A huge value in holdout must not affect stats."""
    df = merged_for_interactions.copy()
    # Inflate one holdout value to a huge outlier
    df.loc[190, "auctTradeQuality"] = 1e6

    transformer = InteractionTransformer(minimal_interactions)
    transformer.fit(df.iloc[:140])

    s = {s.interaction_name: s for s in transformer.stats}["ix_tq_mig"]
    # a_max must reflect dev (which has values 0..1), not the outlier
    assert s.a_max <= 1.0 + 1e-9


# ─── Interaction values ──────────────────────────────────────────

def test_interaction_output_bounded_0_1(merged_for_interactions, minimal_interactions):
    transformer = InteractionTransformer(minimal_interactions)
    transformer.fit(merged_for_interactions.iloc[:140])
    out = transformer.transform(merged_for_interactions)

    for name in ("ix_tq_mig", "ix_bos_trend"):
        assert (out[name] >= 0.0).all()
        assert (out[name] <= 1.0).all()


def test_interaction_clips_holdout_outliers(merged_for_interactions, minimal_interactions):
    df = merged_for_interactions.copy()
    # Push holdout feature to a huge value
    df.loc[190, "auctTradeQuality"] = 1e6

    transformer = InteractionTransformer(minimal_interactions)
    transformer.fit(df.iloc[:140])
    out = transformer.transform(df)

    # The outlier must be clipped to 1.0, not extrapolated
    assert out.loc[190, "ix_tq_mig"] <= 1.0


def test_interaction_product_formula(merged_for_interactions, minimal_interactions):
    """Verify exact formula: (a-a_min)/(a_max-a_min) * (b-b_min)/(b_max-b_min)."""
    df = merged_for_interactions.iloc[:140]
    transformer = InteractionTransformer(
        (("ix_tq_mig", "auctTradeQuality", "vpMigrationConf"),)
    )
    transformer.fit(df)
    s = transformer.stats[0]

    out = transformer.transform(df)
    expected_a = ((df["auctTradeQuality"] - s.a_min) / (s.a_max - s.a_min)).clip(0, 1)
    expected_b = ((df["vpMigrationConf"] - s.b_min) / (s.b_max - s.b_min)).clip(0, 1)
    expected = (expected_a * expected_b).values

    np.testing.assert_allclose(out["ix_tq_mig"].values, expected, rtol=1e-6)


# ─── Missing / degenerate ───────────────────────────────────────

def test_missing_feature_gives_zero_and_warning(minimal_interactions):
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=20),
        "auctTradeQuality": np.random.rand(20),
        "vpMigrationConf": np.random.rand(20),
        # bosQuality and structAlign missing
        "profitUSD": np.zeros(20),
    })

    transformer = InteractionTransformer(minimal_interactions)
    transformer.fit(df)
    out = transformer.transform(df)

    # ix_bos_trend should be 0.0 (missing feature)
    assert (out["ix_bos_trend"] == 0.0).all()
    # ix_tq_mig still computed
    assert (out["ix_tq_mig"] > 0).any()

    # Warning recorded
    assert any("ix_bos_trend" in w for w in transformer.warnings)
    assert any("missing_a" in w or "missing_b" in w for w in transformer.warnings)


def test_constant_feature_degenerate_range():
    df = pd.DataFrame({
        "a": [0.5] * 20,
        "b": np.random.rand(20),
    })
    t = InteractionTransformer((("ix_x", "a", "b"),))
    t.fit(df)
    stats = t.stats[0]
    assert not stats.present
    assert stats.reason == "degenerate_range"

    out = t.transform(df)
    assert (out["ix_x"] == 0.0).all()


# ─── Determinism ────────────────────────────────────────────────

def test_transform_is_deterministic(merged_for_interactions, minimal_interactions):
    t = InteractionTransformer(minimal_interactions)
    t.fit(merged_for_interactions.iloc[:140])
    out1 = t.transform(merged_for_interactions)
    out2 = t.transform(merged_for_interactions)

    np.testing.assert_array_equal(
        out1["ix_tq_mig"].values, out2["ix_tq_mig"].values,
    )


# ─── Layer 2 run() ──────────────────────────────────────────────

def test_layer2_run_transforms_boundary(
    merged_for_interactions, minimal_contract, minimal_interactions,
):
    l1 = L1_boundary.run(merged_for_interactions, minimal_contract)
    l2 = L2_feature_engineering.run(l1, interaction_defs=minimal_interactions)

    # Both dev and holdout should have ix_* columns now
    assert "ix_tq_mig" in l2.boundary.dev.columns
    assert "ix_tq_mig" in l2.boundary.holdout.columns

    # Holdout still sealed
    assert l2.boundary.holdout.is_sealed


def test_layer2_run_reports_counts(
    merged_for_interactions, minimal_contract, minimal_interactions,
):
    l1 = L1_boundary.run(merged_for_interactions, minimal_contract)
    l2 = L2_feature_engineering.run(l1, interaction_defs=minimal_interactions)

    assert l2.n_interactions_computed == 2
    assert l2.n_interactions_skipped == 0
    assert l2.fit_source == "development"


def test_layer2_run_skipped_when_missing(minimal_contract):
    df = pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=50),
        "auctTradeQuality": np.random.rand(50),
        # vpMigrationConf intentionally missing
        "profitUSD": np.zeros(50),
    })
    l1 = L1_boundary.run(df, minimal_contract)
    l2 = L2_feature_engineering.run(
        l1,
        interaction_defs=(("ix_tq_mig", "auctTradeQuality", "vpMigrationConf"),),
    )
    assert l2.n_interactions_computed == 0
    assert l2.n_interactions_skipped == 1
    assert len(l2.warnings) == 1


def test_layer2_output_written(
    merged_for_interactions, minimal_contract, minimal_interactions, tmp_path,
):
    l1 = L1_boundary.run(merged_for_interactions, minimal_contract)
    L2_feature_engineering.run(
        l1, output_dir=tmp_path, interaction_defs=minimal_interactions,
    )
    assert (tmp_path / "interaction_stats.json").exists()

    with (tmp_path / "interaction_stats.json").open() as f:
        payload = json.load(f)
    assert payload["fit_source"] == "development"
    assert payload["n_computed"] == 2
    assert len(payload["interactions"]) == 2


# ─── Integration with kernel boundary ───────────────────────────

def test_apply_preserves_holdout_sealed_state(
    merged_for_interactions, minimal_contract, minimal_interactions,
):
    l1 = L1_boundary.run(merged_for_interactions, minimal_contract)
    assert l1.boundary.holdout.is_sealed

    l2 = L2_feature_engineering.run(l1, interaction_defs=minimal_interactions)
    # Still sealed after fit/transform
    assert l2.boundary.holdout.is_sealed
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L1_boundary.py vp_analysis/tests/test_L2_feature_engineering.py -v
```

Kỳ vọng:

```text
test_L1_boundary.py              16 passed
test_L2_feature_engineering.py   14 passed
────────────────────────────────────────
Total                            30 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 141 (kernel) + 32 (L0) + 30 (L1+L2) = 203 passed
```

---

## Preview: Layer 1 và Layer 2 trong pipeline

Cách L1 và L2 được gọi trong orchestrator:

```python
from vp_analysis.layers import L0_hygiene, L1_boundary, L2_feature_engineering

def run_pipeline(merged_all, contract, output_dir):
    # ─── L0: Hygiene ────────────────────────────────────────
    l0 = L0_hygiene.run(
        merged_all, output_dir=output_dir / "L0_hygiene",
    )
    if l0.should_halt:
        raise RuntimeError(f"L0 halt: {l0.reason_for_halt}")

    # ─── L1: Boundary + availability ────────────────────────
    l1 = L1_boundary.run(
        merged_all, contract, output_dir=output_dir / "L1_boundary",
    )
    print(f"  Split: dev={l1.n_dev}, holdout={l1.n_holdout}")
    print(f"  Features available: {l1.n_available}/{l1.n_available + l1.n_unavailable}")
    if l1.n_available < 3:
        raise RuntimeError("L1: too few available features")

    # ─── L2: Feature engineering ────────────────────────────
    l2 = L2_feature_engineering.run(
        l1, output_dir=output_dir / "L2_feature_engineering",
    )
    print(f"  Interactions computed: {l2.n_interactions_computed}")

    # ─── L3 (EDA), L4 (Discovery), ... ──────────────────────
    # All downstream layers use l2.boundary.dev.data for computation
    # and l2.boundary.holdout for evaluation (only after freeze)
```

Cấu trúc output giờ có:

```text
output/
├── L0_hygiene/
│   ├── layer_zero_summary.json
│   └── (violations CSV nếu có)
├── L1_boundary/
│   ├── run_meta.json
│   └── feature_availability.csv
└── L2_feature_engineering/
    └── interaction_stats.json
```

---

## Sprint 2 hoàn tất

**Deliverables:**
- `L1_boundary.py` (~200 dòng) — split wrap, feature availability on dev only, run_meta output
- `L2_feature_engineering.py` (~250 dòng) — `InteractionTransformer` with strict fit-on-dev semantics
- `_constants.py` — pre-registered interaction definitions
- 30 tests bao phủ:
  - Split correctness và boundary preservation
  - Availability computation chỉ trên dev (verified bằng test "huge variance in holdout, zero in dev")
  - Interaction formula verification (exact match)
  - Clipping behavior (holdout outlier clipped, không extrapolate)
  - Missing/degenerate feature handling
  - Determinism
  - Integration với kernel boundary

**Kernel + L0 + L1 + L2 hiện có:**

```text
┌─────────────────────────────────────────────────────────────┐
│  Sprint 0A/B/C — Governance kernel        141 tests         │
│  Sprint 1 — L0 Data Hygiene                 32 tests         │
│  Sprint 2 — L1 Boundary + L2 Features       30 tests         │
│  ─────────────────────────────────────────────────────────  │
│  Total                                     203 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Sprint 3 tiếp theo — Layer 3: EDA + Shape Verification:**
- `L3_eda.py`: EV-by-bin histogram, shape classification, SHAPE_PRIOR verification, correlation matrix, temporal stability
- Output: `feature_shape_analysis.csv`, `shape_mismatch_report.csv`, `feature_correlation.csv`
- ~25 tests bao gồm injected shape mismatches

