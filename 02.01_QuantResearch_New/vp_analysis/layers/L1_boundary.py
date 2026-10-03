"""Layer 1 -- Boundary split and feature availability (v3)."""
from __future__ import annotations
import datetime as dt, json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
import numpy as np, pandas as pd
from ..core.data_boundary import DataBoundary, DevelopmentData
from ..core.research_contract import ResearchContract
from ._constants import REGIME_NAMES

# Columns that carry outcome / consensus information — must never be treated
# as input features by L3/L4/L5 even if they appear in pre_registered by mistake.
_OUTCOME_COLS: frozenset[str] = frozenset({
    # Direct profit outcomes
    "_profit", "profitUSD", "win", "profitPips",
    # MAE/MFE — measured AFTER entry (post-entry outcomes)
    "maeATR", "mfeATR",
    # Exit-time state — recorded at exit, not known at entry
    "exitTime", "exitPrice", "exitReason",
    "exitAuctRegime", "exitAuctFailure", "exitAuctContinuation",
    "exitAuctReversalRisk", "exitAuctExhaustion", "exitAuctBalance",
    "exitVpMigrationConf", "exitVpInsideVA", "exitVpDevPOCDir",
    "exitSpreadPoints", "exitAtrProxy",
    # Post-entry timing — computed AFTER trade closes
    "holdingMinutes", "holdingMins", "holdingHours",
    "durationMinutes", "tradeDuration",
    # Points/pips from exit price
    "maePoints", "mfePoints",
    # Auction profit zone — forward-looking, derived from future price
    "auctProfitZone",
    # Grouping keys
    "signalId", "trailStyle",
    # Cross-style consensus targets
    "_consensus_profit", "_all_styles_win", "_all_styles_loss", "_style_agree_count",
})

@dataclass(frozen=True)
class FeatureAvailabilityCriteria:
    min_std: float = 1e-9
    max_na_frac: float = 0.30

@dataclass(frozen=True)
class FeatureAvailabilityEntry:
    feature: str; category: str; present: bool; std: float
    na_frac: float; available: bool; reason: str
    def to_dict(self):
        return {"feature":self.feature,"category":self.category,"present":self.present,
                "std":round(self.std,8),"na_frac":round(self.na_frac,6),
                "available":self.available,"reason":self.reason}

@dataclass(frozen=True)
class LayerOneResult:
    boundary: DataBoundary
    dev_all_styles: Optional[pd.DataFrame]
    feature_availability: tuple
    n_total_hypotheses: dict
    n_dev: int; n_holdout: int; split_time: Optional[str]; split_method: str
    split_ratio: float; n_available: int; n_unavailable: int; warnings: tuple; ran_at: str
    def available_features(self):
        return tuple(e.feature for e in self.feature_availability if e.available)
    def run_meta(self):
        return {"ran_at":self.ran_at,"n_dev":self.n_dev,"n_holdout":self.n_holdout,
                "split_time":self.split_time,"split_method":self.split_method,
                "split_ratio":self.split_ratio,"n_available":self.n_available,
                "n_unavailable":self.n_unavailable,
                "n_total_hypotheses":self.n_total_hypotheses,
                "warnings":list(self.warnings),
                "feature_availability":[e.to_dict() for e in self.feature_availability]}

def run(merged_df, contract, all_styles_df=None, output_dir=None, criteria=None):
    if merged_df is None or len(merged_df)==0: raise ValueError("L1: merged_df is empty")
    crit = criteria or FeatureAvailabilityCriteria()
    boundary = DataBoundary.from_merged(merged_df, split_ratio=contract.split_ratio, split_method=contract.split_method)
    split_time = boundary.split_time
    dev_all_styles = None
    if all_styles_df is not None and not all_styles_df.empty:
        dev_all_styles = _split_all_styles_at_time(all_styles_df, split_time, contract.split_method)
    entries, warnings = _compute_feature_availability(boundary.dev, contract.pre_registered, crit)
    n_available = sum(1 for e in entries if e.available)
    n_unavailable = len(entries) - n_available
    available = [e.feature for e in entries if e.available]
    n_total = _compute_n_total_hypotheses(boundary.dev.data, available, contract)
    for pool_name, n in n_total.items():
        if n==0: warnings.append(f"n_total_hypotheses[{pool_name!r}] = 0")
    result = LayerOneResult(
        boundary=boundary, dev_all_styles=dev_all_styles,
        feature_availability=tuple(entries), n_total_hypotheses=n_total,
        n_dev=len(boundary.dev), n_holdout=boundary.holdout.size,
        split_time=split_time, split_method=boundary.split_method,
        split_ratio=boundary.split_ratio, n_available=n_available,
        n_unavailable=n_unavailable, warnings=tuple(warnings),
        ran_at=dt.datetime.now(dt.timezone.utc).isoformat())
    if output_dir is not None: _write_outputs(result, Path(output_dir))
    return result

def _split_all_styles_at_time(df, split_time, split_method):
    if split_time is not None and split_method=="temporal" and "time" in df.columns:
        times = pd.to_datetime(df["time"], errors="coerce")
        st = pd.to_datetime(split_time, errors="coerce")
        if pd.notna(st): return df[times<st].sort_values("time").reset_index(drop=True)
    return df.iloc[:int(len(df)*0.70)].reset_index(drop=True)

def _compute_n_total_hypotheses(dev_df, available_features, contract):
    n_features = len(available_features)
    if "symbol" in dev_df.columns and "setupType" in dev_df.columns:
        n_groups = dev_df.groupby(["symbol","setupType"],sort=False).ngroups
    elif "symbol" in dev_df.columns: n_groups = dev_df["symbol"].nunique()
    elif "setupType" in dev_df.columns: n_groups = dev_df["setupType"].nunique()
    else: n_groups = 1
    n_groups = max(n_groups, 1)
    regime_col = "auctRegime" if "auctRegime" in dev_df.columns else "regimeName"
    n_regimes = int(dev_df[regime_col].nunique()) if regime_col in dev_df.columns else len(REGIME_NAMES)
    n_regimes = max(n_regimes, 1)
    return {"hard_gate":n_features*n_groups,"soft_gate":n_features*n_groups,"regime_block":n_regimes*n_groups}

def _compute_feature_availability(dev, pre_registered, crit):
    df = dev.data; entries=[]; warnings=[]
    for category, features in pre_registered.items():
        for feat in features:
            if feat in _OUTCOME_COLS:
                warnings.append(f"Feature {feat!r} ({category!r}) is an outcome column — skipped.")
                continue
            entry = _check_feature(df, feat, category, crit)
            entries.append(entry)
            if not entry.present:
                warnings.append(f"Feature {feat!r} ({category!r}) not in dev.")
    return entries, warnings

def _check_feature(df, feature, category, crit):
    if feature not in df.columns:
        return FeatureAvailabilityEntry(feature,category,False,0.0,1.0,False,"missing")
    series = pd.to_numeric(df[feature],errors="coerce"); na_frac=float(series.isna().mean())
    valid = series.dropna()
    if len(valid)<2: return FeatureAvailabilityEntry(feature,category,True,0.0,na_frac,False,"low_variance")
    std = float(valid.std(ddof=1))
    if na_frac>crit.max_na_frac: return FeatureAvailabilityEntry(feature,category,True,std,na_frac,False,"too_many_na")
    if std<=crit.min_std: return FeatureAvailabilityEntry(feature,category,True,std,na_frac,False,"low_variance")
    return FeatureAvailabilityEntry(feature,category,True,std,na_frac,True,"")

def _write_outputs(result, output_dir):
    output_dir.mkdir(parents=True,exist_ok=True)
    with (output_dir/"run_meta.json").open("w",encoding="utf-8") as f:
        json.dump(result.run_meta(),f,indent=2,default=str)
    pd.DataFrame([e.to_dict() for e in result.feature_availability]).to_csv(
        output_dir/"feature_availability.csv",index=False)
