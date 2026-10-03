from __future__ import annotations
import datetime as dt, json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
import numpy as np, pandas as pd
from ..core.data_boundary import DataBoundary
from ._constants import DEFAULT_INTERACTION_DEFS

@dataclass(frozen=True)
class InteractionStats:
    interaction_name: str
    feature_a: str
    feature_b: str
    a_min: Optional[float]
    a_max: Optional[float]
    b_min: Optional[float]
    b_max: Optional[float]
    present: bool
    reason: str
    def to_dict(self):
        return dict(interaction_name=self.interaction_name, feature_a=self.feature_a,
                    feature_b=self.feature_b, a_min=self.a_min, a_max=self.a_max,
                    b_min=self.b_min, b_max=self.b_max, present=self.present, reason=self.reason)

@dataclass(frozen=True)
class LayerTwoResult:
    boundary: DataBoundary
    dev_all_styles_fe: Optional[pd.DataFrame]
    interactions: tuple
    n_interactions_computed: int
    n_interactions_skipped: int
    warnings: tuple
    fit_source: str
    ran_at: str
    def stats_dict(self):
        return dict(fit_source=self.fit_source, ran_at=self.ran_at,
                    n_computed=self.n_interactions_computed,
                    n_skipped=self.n_interactions_skipped,
                    warnings=list(self.warnings),
                    interactions=[s.to_dict() for s in self.interactions])

class InteractionTransformer:
    def __init__(self, interaction_defs=DEFAULT_INTERACTION_DEFS):
        self._defs = tuple(interaction_defs)
        self._stats: dict = {}
        self._warnings: list = []

    def fit(self, dev_df):
        self._stats = {}; self._warnings = []
        for name, feat_a, feat_b in self._defs:
            stat = self._compute_stats(dev_df, name, feat_a, feat_b)
            self._stats[name] = stat
            if not stat.present:
                self._warnings.append(f"Interaction {name!r} skipped: {stat.reason}")
        return self

    def transform(self, df):
        if not self._stats:
            raise RuntimeError("InteractionTransformer.transform called before fit")
        out = df.copy()
        for name, stat in self._stats.items():
            out[name] = self._apply(df, stat).astype(np.float32)
        return out

    @property
    def stats(self): return tuple(self._stats.values())
    @property
    def warnings(self): return tuple(self._warnings)

    def _compute_stats(self, dev_df, name, feat_a, feat_b):
        if feat_a not in dev_df.columns:
            return InteractionStats(name, feat_a, feat_b, None, None, None, None, False, "missing_a")
        if feat_b not in dev_df.columns:
            return InteractionStats(name, feat_a, feat_b, None, None, None, None, False, "missing_b")
        a = pd.to_numeric(dev_df[feat_a], errors="coerce").dropna()
        b = pd.to_numeric(dev_df[feat_b], errors="coerce").dropna()
        if len(a) < 2 or len(b) < 2:
            return InteractionStats(name, feat_a, feat_b, None, None, None, None, False, "degenerate_range")
        a_min, a_max = float(a.min()), float(a.max())
        b_min, b_max = float(b.min()), float(b.max())
        if a_max - a_min <= 1e-12 or b_max - b_min <= 1e-12:
            return InteractionStats(name, feat_a, feat_b, a_min, a_max, b_min, b_max, False, "degenerate_range")
        return InteractionStats(name, feat_a, feat_b, a_min, a_max, b_min, b_max, True, "")

    def _apply(self, df, stat):
        if not stat.present:
            return pd.Series(0.0, index=df.index, dtype=np.float32)
        a = pd.to_numeric(df[stat.feature_a], errors="coerce").fillna(0.0)
        b = pd.to_numeric(df[stat.feature_b], errors="coerce").fillna(0.0)
        a_norm = ((a - stat.a_min) / (stat.a_max - stat.a_min)).clip(0.0, 1.0)
        b_norm = ((b - stat.b_min) / (stat.b_max - stat.b_min)).clip(0.0, 1.0)
        return (a_norm * b_norm).astype(np.float32)


def run(l1_result, output_dir=None, interaction_defs=DEFAULT_INTERACTION_DEFS):
    transformer = InteractionTransformer(interaction_defs)
    new_boundary = l1_result.boundary.apply(transformer)
    dev_all_styles_fe = None
    if l1_result.dev_all_styles is not None:
        dev_all_styles_fe = transformer.transform(l1_result.dev_all_styles)
    stats = transformer.stats
    n_computed = sum(1 for s in stats if s.present)
    result = LayerTwoResult(
        boundary=new_boundary, dev_all_styles_fe=dev_all_styles_fe,
        interactions=stats, n_interactions_computed=n_computed,
        n_interactions_skipped=len(stats) - n_computed,
        warnings=tuple(transformer.warnings), fit_source="development",
        ran_at=dt.datetime.now(dt.timezone.utc).isoformat())
    if output_dir is not None:
        p = Path(output_dir); p.mkdir(parents=True, exist_ok=True)
        with (p / "interaction_stats.json").open("w", encoding="utf-8") as f:
            json.dump(result.stats_dict(), f, indent=2, default=str)
    return result
