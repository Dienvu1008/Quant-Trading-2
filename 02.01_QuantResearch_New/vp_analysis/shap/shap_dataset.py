"""SHAPDatasetBuilder — leakage-safe dataset construction for SHAP analysis.

Rules enforced here:
1. Only features from contract.pre_registered (filtered by available_features) are used.
2. All SHAP_FORBIDDEN_FEATURES are stripped before returning X.
3. Signal-level view deduplicates by signalId (entry features are identical across styles).
4. Style view (for SHAP-G) keeps all 3 style rows.
5. Target is computed from the correct source column based on target_mode.
6. Only dev data is accepted — holdout is never touched here.
"""
from __future__ import annotations

import warnings
from dataclasses import dataclass, field
from typing import Dict, List, Optional

import numpy as np
import pandas as pd


# ─── Forbidden features ─────────────────────────────────────────
# These columns MUST NEVER be SHAP model inputs.
# They are either post-entry outcomes or structural keys that would
# cause direct leakage or 3-style inflation.

SHAP_FORBIDDEN_FEATURES: frozenset = frozenset({
    # Direct profit outcomes — target variables, never features
    "profitUSD", "_profit", "win", "profitPips",
    # MAE/MFE — measured AFTER entry (post-entry outcomes)
    "mfeATR", "maeATR",
    # Exit-time state — all columns recorded at exit, not known at entry
    "exitReason", "exitTime", "exitPrice",
    "exitAuctRegime", "exitAuctFailure", "exitAuctContinuation",
    "exitAuctReversalRisk", "exitAuctExhaustion", "exitAuctBalance",
    "exitVpMigrationConf", "exitVpInsideVA", "exitVpDevPOCDir",
    "exitSpreadPoints", "exitAtrProxy",
    # Auction profit zone — derived from future price movement
    "auctProfitZone",
    # Entry time (structural key, not a predictive feature)
    "entryTime",
    # Cross-style consensus targets
    "_all_styles_win", "_all_styles_loss",
    "_consensus_profit", "_style_agree_count",
    # Grouping / identity keys
    "signalId", "trailStyle",
    # Temporal index
    "time",
    # Post-entry timing — computed AFTER trade closes
    "holdingMinutes", "holdingMins", "holdingHours",
    "durationMinutes", "tradeDuration",
    # Points/pips derived from exit price — post-entry
    "maePoints", "mfePoints",
    # atrAtEntry could be valid but often correlated with exit timing
    # Metadata
    "ticket",
})

# Additional soft exclusions (warn but don't hard-exclude)
SHAP_WARN_FEATURES: frozenset = frozenset({
    "symbol", "setupType",        # categorical metadata, may be added intentionally
    "SL", "TP", "entryPrice",     # setup parameters with partial overlap with post-entry
})


# ─── Dataset types ───────────────────────────────────────────────

@dataclass
class SHAPDataset:
    """Leakage-safe SHAP dataset."""
    X: pd.DataFrame                     # feature matrix (signal-level)
    y: pd.Series                        # target vector
    feature_names: List[str]
    target_name: str
    target_mode: str
    n_signals: int                      # unique signals (after dedup)
    n_rows_before_dedup: int            # rows before signalId dedup
    n_features: int
    style_df: Optional[pd.DataFrame]    # for SHAP-G: all 3 style rows, target per style
    meta: Dict                          # provenance metadata
    warnings: List[str] = field(default_factory=list)

    def __post_init__(self) -> None:
        assert len(self.X) == len(self.y), (
            f"X ({len(self.X)}) and y ({len(self.y)}) must have same length"
        )
        assert len(self.feature_names) == self.X.shape[1], (
            f"feature_names length {len(self.feature_names)} != X columns {self.X.shape[1]}"
        )


# ─── Builder ─────────────────────────────────────────────────────

class SHAPDatasetBuilder:
    """Build SHAPDataset from dev DataFrame and contract."""

    def __init__(
        self,
        dev_df: pd.DataFrame,
        contract,                        # ResearchContract
        available_features: List[str],
        config=None,                     # SHAPConfig
    ):
        self._dev_df = dev_df.copy()
        self._contract = contract
        self._available_features = list(available_features)
        self._config = config

    def build(self) -> SHAPDataset:
        """Build the dataset applying all governance rules."""
        from .shap_config import SHAPConfig
        cfg = self._config or SHAPConfig()
        warns: List[str] = []

        # 1. Resolve feature set
        features, feat_warns = self._resolve_features()
        warns.extend(feat_warns)

        if not features:
            raise ValueError(
                "No valid SHAP features after applying governance filters. "
                "Check contract.pre_registered and available_features."
            )

        # 2. Build full style view (for SHAP-G) before dedup
        style_df = self._build_style_view(features, cfg, warns)

        # 3. Build signal-level view (for SHAP-A through SHAP-H excluding SHAP-G)
        signal_df, n_before = self._build_signal_view(features, warns)

        # 4. Compute target
        y, target_name = self._compute_target(signal_df, cfg, warns)

        # 5. Extract feature matrix (no forbidden columns)
        X = signal_df[features].copy()

        # Coerce all to float32
        for col in X.columns:
            X[col] = pd.to_numeric(X[col], errors="coerce").astype(np.float32)

        # Fill NaN with column median (SHAP models need no missing values)
        for col in X.columns:
            med = float(X[col].median())
            if np.isnan(med):
                med = 0.0
            X[col] = X[col].fillna(med)

        # Reset index
        X = X.reset_index(drop=True)
        y = y.reset_index(drop=True)

        if len(X) < cfg.min_rows_total:
            raise ValueError(
                f"Only {len(X)} rows after filtering — minimum is {cfg.min_rows_total}. "
                "Expand date range or reduce min_rows_total."
            )

        # Determine symbols list
        symbols = sorted(signal_df["symbol"].dropna().unique().tolist()) if "symbol" in signal_df.columns else []

        meta = {
            "target_mode": cfg.target_mode,
            "target_name": target_name,
            "n_rows_before_dedup": n_before,
            "n_signals": len(X),
            "n_features": len(features),
            "symbols": symbols,
            "forbidden_stripped": list(SHAP_FORBIDDEN_FEATURES),
            "feature_categories": self._feature_categories(features),
        }

        return SHAPDataset(
            X=X,
            y=y,
            feature_names=features,
            target_name=target_name,
            target_mode=cfg.target_mode,
            n_signals=len(X),
            n_rows_before_dedup=n_before,
            n_features=len(features),
            style_df=style_df,
            meta=meta,
            warnings=warns,
        )

    # ─── Internal helpers ───────────────────────────────────────

    def _resolve_features(self):
        """Return (feature_list, warnings) after applying all filters."""
        warns = []

        # Start from contract.pre_registered (if contract is available)
        all_registered: List[str] = []
        if self._contract is not None and hasattr(self._contract, "pre_registered"):
            for category, feat_list in self._contract.pre_registered.items():
                all_registered.extend(feat_list)
        else:
            # No contract — fall back to available_features directly,
            # but still strip exit/post-entry columns via SHAP_FORBIDDEN_FEATURES
            all_registered = [
                f for f in self._available_features
                if not (f.startswith("exit") or f.startswith("Exit"))
                and f not in SHAP_FORBIDDEN_FEATURES
            ]
            warns.append(
                f"No contract available — auto-detected {len(all_registered)} entry features "
                "(exit/post-entry columns stripped automatically)"
            )

        # Also include interaction columns if present
        available_set = set(self._available_features)
        df_cols = set(self._dev_df.columns)

        # Composite features built by data_loader are also valid
        composite_cols = {
            "bosQuality", "chochQuality", "structAlign",
            "msContext", "ofContext", "liqContext", "smContext",
        }

        candidate_set = set(all_registered) | composite_cols
        candidate_set &= (available_set | composite_cols)  # must be available or composite
        candidate_set &= df_cols                            # must exist in df

        # Strip forbidden features
        forbidden_found = candidate_set & SHAP_FORBIDDEN_FEATURES
        if forbidden_found:
            warns.append(
                f"Stripped {len(forbidden_found)} forbidden features: {sorted(forbidden_found)}"
            )
        candidate_set -= SHAP_FORBIDDEN_FEATURES

        # Warn on soft-exclusion features
        soft_found = candidate_set & SHAP_WARN_FEATURES
        if soft_found:
            warns.append(
                f"Warning: {sorted(soft_found)} are setup/metadata columns — "
                "included but interpret SHAP with caution."
            )

        # Keep stable ordering — preserve registration order if contract available
        ordered: List[str] = []
        seen: set = set()
        if self._contract is not None and hasattr(self._contract, "pre_registered"):
            for category, feat_list in self._contract.pre_registered.items():
                for f in feat_list:
                    if f in candidate_set and f not in seen:
                        ordered.append(f)
                        seen.add(f)
        # Add composites and interactions not in pre_registered
        for f in sorted(candidate_set - seen):
            ordered.append(f)

        return ordered, warns

    def _build_signal_view(self, features: List[str], warns: List[str]):
        """Return (signal_df, n_before_dedup).

        For production_profit target: filters to production trailing style FIRST
        (default trailStyle=1 / expansion) so profitUSD reflects the correct exit.
        For all_styles_win / consensus_profit: deduplicates by signalId only
        (profitUSD column is not used as target, so style doesn't matter).
        Features are identical across 3 trailStyle rows — no info lost.
        """
        from .shap_config import SHAPConfig
        cfg = self._config or SHAPConfig()

        df = self._dev_df.copy()
        n_before = len(df)

        # For production_profit: filter to production style so profitUSD is correct
        if (cfg.target_mode == "production_profit"
                and "trailStyle" in df.columns):
            prod_style = getattr(cfg, "production_style", 1)
            df_prod = df[df["trailStyle"] == prod_style]
            if len(df_prod) > 0:
                df = df_prod.reset_index(drop=True)
                warns.append(
                    f"Filtered to production trailing style={prod_style}: "
                    f"{n_before} → {len(df)} rows"
                )
            else:
                warns.append(
                    f"No rows with trailStyle={prod_style} — using all styles "
                    "(profitUSD may be from wrong trailing style)"
                )

        if "signalId" in df.columns:
            n_signals_before = df["signalId"].nunique()
            df = df.drop_duplicates(subset=["signalId"], keep="first").reset_index(drop=True)
            n_after = len(df)
            if n_before != n_after:
                warns.append(
                    f"Signal dedup: {n_before} rows → {n_after} rows "
                    f"({n_signals_before} unique signals)"
                )
        else:
            warns.append("signalId column not found — no dedup applied (possible 3x inflation)")

        # Sample down to max_signals if configured
        from .shap_config import SHAPConfig
        cfg = self._config or SHAPConfig()
        max_sig = getattr(cfg, "max_signals", 0)
        if max_sig and max_sig > 0 and len(df) > max_sig:
            rng = __import__("numpy").random.default_rng(getattr(cfg, "seed", 42))
            idx = rng.choice(len(df), size=max_sig, replace=False)
            idx = sorted(idx)
            df = df.iloc[idx].reset_index(drop=True)
            warns.append(
                f"Sampled {max_sig} signals from {n_before} rows for SHAP ")
            print(f"  [SHAP] Sampled {max_sig:,} signals for analysis")

        return df, n_before

    def _build_style_view(self, features: List[str], cfg, warns: List[str]):
        """Build signal×style view for SHAP-G.

        Keeps all 3 trailStyle rows, target = profitUSD for that style.
        """
        if not cfg.run_shap_g:
            return None

        df = self._dev_df.copy()

        if "trailStyle" not in df.columns or "profitUSD" not in df.columns:
            warns.append("SHAP-G: trailStyle or profitUSD not found — style view unavailable")
            return None

        # Keep only feature columns + style keys
        keep_cols = list(set(features) & set(df.columns))
        meta_cols = [c for c in ["signalId", "trailStyle", "profitUSD", "symbol", "setupType", "time"]
                     if c in df.columns]
        style_df = df[keep_cols + [c for c in meta_cols if c not in keep_cols]].copy()

        for col in keep_cols:
            style_df[col] = pd.to_numeric(style_df[col], errors="coerce").astype(np.float32)

        return style_df.reset_index(drop=True)

    def _compute_target(self, signal_df: pd.DataFrame, cfg, warns: List[str]):
        """Return (y_series, target_name) based on target_mode."""
        mode = cfg.target_mode

        if mode == "production_profit":
            if "profitUSD" in signal_df.columns:
                y = pd.to_numeric(signal_df["profitUSD"], errors="coerce").fillna(0.0)
                return y.astype(np.float32), "profitUSD"
            elif "_profit" in signal_df.columns:
                y = pd.to_numeric(signal_df["_profit"], errors="coerce").fillna(0.0)
                warns.append("Used _profit as target (profitUSD not found)")
                return y.astype(np.float32), "_profit"
            else:
                raise ValueError("target_mode='production_profit' but no profitUSD/_profit column")

        elif mode == "all_styles_win":
            if "_all_styles_win" in signal_df.columns:
                y = pd.to_numeric(signal_df["_all_styles_win"], errors="coerce").fillna(0.0)
                return y.astype(np.float32), "_all_styles_win"
            else:
                warns.append("_all_styles_win not found, falling back to profitUSD>0 (win)")
                if "profitUSD" in signal_df.columns:
                    y = (pd.to_numeric(signal_df["profitUSD"], errors="coerce") > 0).astype(np.float32)
                    return y, "win_fallback"
                raise ValueError("target_mode='all_styles_win' but _all_styles_win not found")

        elif mode == "consensus_profit":
            if "_consensus_profit" in signal_df.columns:
                y = pd.to_numeric(signal_df["_consensus_profit"], errors="coerce").fillna(0.0)
                return y.astype(np.float32), "_consensus_profit"
            else:
                warns.append("_consensus_profit not found, falling back to profitUSD")
                if "profitUSD" in signal_df.columns:
                    y = pd.to_numeric(signal_df["profitUSD"], errors="coerce").fillna(0.0)
                    return y.astype(np.float32), "profitUSD_fallback"
                raise ValueError("target_mode='consensus_profit' but _consensus_profit not found")

        else:
            raise ValueError(f"Unknown target_mode: {mode!r}")

    def _feature_categories(self, features: List[str]) -> Dict[str, str]:
        """Map feature → category from contract.pre_registered."""
        cat_map: Dict[str, str] = {}
        if self._contract is not None and hasattr(self._contract, "pre_registered"):
            for category, feat_list in self._contract.pre_registered.items():
                for f in feat_list:
                    cat_map[f] = category
        # Composites
        for f in ["bosQuality", "chochQuality", "structAlign"]:
            if f in features and f not in cat_map:
                cat_map[f] = "structure_composite"
        for f in ["msContext", "ofContext", "liqContext", "smContext"]:
            if f in features and f not in cat_map:
                cat_map[f] = "engine_composite"
        return {f: cat_map.get(f, "unknown") for f in features}


# ─── Public API ──────────────────────────────────────────────────

def build_shap_dataset(
    dev_df: pd.DataFrame,
    contract,
    available_features: list,
    config=None,
) -> SHAPDataset:
    """Convenience wrapper around SHAPDatasetBuilder.build()."""
    builder = SHAPDatasetBuilder(dev_df, contract, available_features, config)
    return builder.build()
