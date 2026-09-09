"""
data_loader.py — Data loading for VP EA Quant Research Pipeline.

Loads:
  - VP_Funnel_{symbol}.csv  → all fired triggers with full VP/Auction state
  - VP_Trades_{symbol}.csv  → closed trades with entry+exit state + PnL
"""

import glob
import pandas as pd
import numpy as np
from pathlib import Path

# Shared path constants (also used by data_collect.py, the write side).
from data_paths import DATA_DIR, MT5_FILES_DIR

# ─── VP/Auction Feature Lists ─────────────────────────────────────
VP_CORE_FEATURES = [
    "vpPOC", "vpVAH", "vpVAL", "vpInsideVA", "vpDistToHVN", "vpDistToLVN",
    "vpPriceVsPOC", "vpDailyPOC",
]
VP_COMPOSITE_FEATURES = [
    "vpCompPOC", "vpCompVAH", "vpCompVAL", "vpCompInsideVA", "vpDistCompPOC",
]
VP_ENHANCED_FEATURES = [
    "vpThinnessRatio", "vpProfileShape", "vpBestHVN", "vpBestHVNScore",
    "vpVAOverlapRatio", "vpVAOverlapBias", "vpRangePOC", "vpBreakoutPOC", "vpPullbackPOC",
    "vpNearestNakedPOC", "vpDistNakedPOC_ATR",
    "vpUpthrust", "vpSpring", "vpCompPosition", "vpMigrationConf",
    "vpDevPOCDir", "vpDevPOCSlope", "vpMigrationScore",
]
AUCTION_FEATURES = [
    "auctAcceptance", "auctState", "auctBalance", "auctProfileShape", "auctShapeConf",
    "auctMajorHVN", "auctMajorLVN", "auctDistHVN", "auctDistLVN",
    "auctVAExpRate", "auctVAState", "auctFailure",
    "auctRegime", "auctRegimeConf", "auctExpReward", "auctExpMoveATR", "auctTargetProb",
    "auctTradeQuality", "auctTradeGrade", "auctTargetPrice", "auctTargetType", "auctTargetConf",
    "auctProfitZone", "auctExhaustion", "auctContinuation", "auctReversalRisk",
    "auctHVNStrength", "auctLVNStrength",
]
VP_LONGTERM_FEATURES = [
    "vpLTPOC60d", "vpLTPOC30d", "vpLTPOC10d",
    "vpLTPOCVelocity", "vpLTPOCAcceleration", "vpLTPOCMigration",
    "vpLTMajorHVNPrice", "vpLTMajorHVNStrength",
    "vpLTMajorLVNPrice", "vpLTMajorLVNStrength",
    "vpLTNearestZonePrice", "vpLTNearestZoneStrength", "vpLTNearestZoneDir",
    "vpLTAcceptanceAtPrice", "vpLTValid",
    "vpLTTransitionScore", "vpLTBalanceStability", "vpLTTrendDuration", "vpLTTrendExhaustion",
]
PROFILER_FEATURES = [
    "profilerArchetype", "profilerSamples", "profilerMigMean", "profilerBalMean", "profilerTQMean",
]
MARKET_FEATURES = ["spreadPoints", "avgSpread", "spreadToATR", "atrProxy", "dataQuality"]
SETUP_FEATURES = ["entryPrice", "SL", "TP", "RR", "thesis"]
STRUCTURE_FEATURES = ["bosConfirmed", "bosBullish", "bosScore", "bosLevel",
                      "chochConfirmed", "chochBullish", "chochScore", "chochLevel", "trendDirection",
                      "structDistATR"]

# ─── Bonus Engine Feature Lists (research data collection) ─────────
# Column names match the VPFunnelLogger CSV header (ms/of/liq/sm prefixes).
BONUS_STRUCTURE_FEATURES = ["structureBias"]
MICROSTRUCTURE_FEATURES = [
    "msSpreadScore", "msTickVelocity", "msTickImbalance", "msLiqVacuum", "msCompression",
]
ORDERFLOW_FEATURES = [
    "ofDeltaProxy", "ofCvdProxy", "ofAbsorption", "ofExhaustion", "ofParticipation",
    "ofDivergence", "ofBullDiv", "ofBearDiv", "ofFlowIntensity",
]
LIQUIDITY_FEATURES = [
    "liqDensity", "liqSweep", "liqStopCluster", "liqEqualHL", "liqSessionLiq", "liqPremDisc",
]
SMARTMONEY_FEATURES = [
    "smOrderBlock", "smFVG", "smMitigation", "smBreakerBlock", "smRejectionBlock", "smZoneQuality",
]

# All numeric features for SHAP/ML
FUNNEL_FEATURES = (
    VP_CORE_FEATURES + VP_COMPOSITE_FEATURES + VP_ENHANCED_FEATURES +
    AUCTION_FEATURES + VP_LONGTERM_FEATURES + PROFILER_FEATURES +
    MARKET_FEATURES + SETUP_FEATURES + STRUCTURE_FEATURES +
    BONUS_STRUCTURE_FEATURES + MICROSTRUCTURE_FEATURES + ORDERFLOW_FEATURES +
    LIQUIDITY_FEATURES + SMARTMONEY_FEATURES
)
_seen = set()
FUNNEL_FEATURES = [x for x in FUNNEL_FEATURES if not (x in _seen or _seen.add(x))]

# Layer grouping for analysis
LAYER_MAP = {
    "L_vp_core": VP_CORE_FEATURES,
    "L_vp_composite": VP_COMPOSITE_FEATURES,
    "L_vp_enhanced": VP_ENHANCED_FEATURES,
    "L_auction": AUCTION_FEATURES,
    "L_vp_longterm": VP_LONGTERM_FEATURES,
    "L_profiler": PROFILER_FEATURES,
    "L_market": MARKET_FEATURES,
    "L_structure": STRUCTURE_FEATURES,
    "L_microstructure": MICROSTRUCTURE_FEATURES,
    "L_orderflow": ORDERFLOW_FEATURES,
    "L_liquidity": LIQUIDITY_FEATURES,
    "L_smartmoney": SMARTMONEY_FEATURES,
}

REGIME_NAMES = {
    0: "BALANCED_ROTATION", 1: "COMPRESSION", 2: "TREND_INITIATION",
    3: "TREND_CONTINUATION", 4: "RE_ACCUMULATION", 5: "EXHAUSTION",
    6: "FAILED_AUCTION", 7: "EXCESS", 8: "CHAOTIC"
}


def get_archetype_map(all_results):
    """Extract symbol → archetype mapping from Phase 01 output.
    Used by downstream phases to group symbols by archetype.
    
    Returns: dict {symbol: archetype} or None if Phase 01 not run yet.
    """
    if all_results is None:
        return None
    phase1 = all_results.get("phase1", {})
    profiles = phase1.get("profiles", [])
    if not profiles:
        return None
    return {p["symbol"]: p.get("archetype", "NEUTRAL") for p in profiles if "symbol" in p}


def group_by_archetype(df, archetype_map):
    """Add 'archetype' column to dataframe based on symbol → archetype mapping.
    
    Returns: dataframe with 'archetype' column added.
    """
    if archetype_map is None or "symbol" not in df.columns:
        df = df.copy()
        df["archetype"] = "UNKNOWN"
        return df
    df = df.copy()
    df["archetype"] = df["symbol"].map(archetype_map).fillna("UNKNOWN")
    return df


def build_structure_composites(df: pd.DataFrame) -> pd.DataFrame:
    """Collapse redundant BOS/CHOCH raw columns into single directional quality scores.

    Rationale: bosConfirmed / bosBullish / bosScore / bosLevel are facets of ONE
    structural event and should be analyzed together, not as independent features.
    Same for the CHOCH group. This produces composites that carry the joint
    information (strength × confirmation × directional agreement × proximity to entry),
    reducing redundancy and multicollinearity in downstream phases.

    Adds columns:
      bosQuality   — signed [-1, 1]: BOS strength gated by confirmation & proximity,
                     signed by bull/bear direction
      chochQuality — signed [-1, 1]: same for CHOCH
      structAlign  — [0, 1]: agreement between structure direction and trendDirection

    Original raw columns are kept (backward compatible); composites are additive.
    """
    df = df.copy()

    def _proximity(level_col: str) -> pd.Series:
        # Proximity of structural level to entry in ATR units → [0, 1], 1 = at price.
        # Uses structDistATR when the level is missing; falls back to neutral 0.5.
        if "entryPrice" in df.columns and level_col in df.columns and "atrProxy" in df.columns:
            entry = pd.to_numeric(df["entryPrice"], errors="coerce")
            level = pd.to_numeric(df[level_col], errors="coerce")
            atr   = pd.to_numeric(df["atrProxy"], errors="coerce")
            # atrProxy is in points; convert level distance to ATR units via structDistATR scale.
            # We approximate: dist_atr = |entry - level| / (atr * pointSize). pointSize unknown here,
            # so prefer the EA-computed structDistATR when available.
            if "structDistATR" in df.columns:
                d = pd.to_numeric(df["structDistATR"], errors="coerce").fillna(3.0)
            else:
                # crude fallback: normalize raw price distance, clipped
                d = (entry - level).abs().fillna(3.0)
            prox = (1.0 - (d / 3.0)).clip(lower=0.0, upper=1.0)  # 0 ATR→1, ≥3 ATR→0
            return prox.fillna(0.5)
        return pd.Series(0.5, index=df.index)

    def _group_quality(prefix: str, level_col: str) -> pd.Series:
        conf_col  = f"{prefix}Confirmed"
        bull_col  = f"{prefix}Bullish"
        score_col = f"{prefix}Score"

        score = pd.to_numeric(df[score_col], errors="coerce").fillna(0.0) if score_col in df.columns else pd.Series(0.0, index=df.index)
        conf  = pd.to_numeric(df[conf_col], errors="coerce").fillna(0.0)  if conf_col in df.columns  else pd.Series(1.0, index=df.index)
        bull  = pd.to_numeric(df[bull_col], errors="coerce").fillna(0.0)  if bull_col in df.columns  else pd.Series(0.0, index=df.index)
        prox  = _proximity(level_col)

        # magnitude = strength gated by confirmation and proximity to entry
        magnitude = score.clip(0, 1) * conf.clip(0, 1) * prox
        # sign: +1 bullish, -1 bearish (bull column is 0/1)
        sign = np.where(bull >= 0.5, 1.0, -1.0)
        # if not confirmed, there is no structural event → magnitude already ~0 via conf
        return (magnitude * sign).astype(np.float32)

    if any(c.startswith("bos") for c in df.columns):
        df["bosQuality"] = _group_quality("bos", "bosLevel")
    if any(c.startswith("choch") for c in df.columns):
        df["chochQuality"] = _group_quality("choch", "chochLevel")

    # Structure/trend alignment: does confirmed structure agree with trendDirection?
    if "trendDirection" in df.columns:
        trend = pd.to_numeric(df["trendDirection"], errors="coerce").fillna(0.0)
        # Combined structural direction from whichever composite exists
        struct_sign = pd.Series(0.0, index=df.index)
        if "bosQuality" in df.columns:
            struct_sign = struct_sign + np.sign(df["bosQuality"])
        if "chochQuality" in df.columns:
            struct_sign = struct_sign + np.sign(df["chochQuality"])
        struct_sign = np.sign(struct_sign)
        # alignment 1.0 when signs match, 0.0 when opposed, 0.5 when trend flat
        align = np.where(trend == 0, 0.5,
                 np.where(np.sign(trend) == struct_sign, 1.0,
                 np.where(struct_sign == 0, 0.5, 0.0)))
        df["structAlign"] = align.astype(np.float32)

    return df


def build_engine_composites(df: pd.DataFrame) -> pd.DataFrame:
    """Collapse each bonus-engine group's SECONDARY outputs into one composite.

    Each engine group emits a cluster of related scores. We keep the single most
    informative "primary" feature per group as-is (it goes into PRE_REGISTERED for
    edge testing), and average the remaining "secondary" scores into one composite
    so their joint signal is captured without adding many correlated features that
    inflate the multiple-testing burden.

    Primary features (kept raw, NOT collapsed):
      microstructure → msCompression
      order flow     → ofFlowIntensity
      liquidity      → liqSweep
      smart money    → smZoneQuality

    Composites added (mean of available secondary scores, all already in [0,1]):
      msContext   = mean(msSpreadScore, msTickVelocity, msTickImbalance, msLiqVacuum)
      ofContext   = mean(ofDeltaProxy, ofCvdProxy, ofAbsorption, ofExhaustion,
                         ofParticipation, ofDivergence)
      liqContext  = mean(liqDensity, liqStopCluster, liqEqualHL, liqSessionLiq, liqPremDisc)
      smContext   = mean(smOrderBlock, smFVG, smMitigation, smBreakerBlock, smRejectionBlock)

    Note: ofBullDiv/ofBearDiv are directional booleans, not magnitudes, so they are
    left out of ofContext (they stay available as raw columns for descriptive use).
    Original raw columns are kept; composites are additive.
    """
    df = df.copy()

    def _mean_of(cols):
        present = [c for c in cols if c in df.columns]
        if not present:
            return None
        vals = df[present].apply(pd.to_numeric, errors="coerce")
        return vals.mean(axis=1).astype(np.float32)

    groups = {
        "msContext":  ["msSpreadScore", "msTickVelocity", "msTickImbalance", "msLiqVacuum"],
        "ofContext":  ["ofDeltaProxy", "ofCvdProxy", "ofAbsorption", "ofExhaustion",
                       "ofParticipation", "ofDivergence"],
        "liqContext": ["liqDensity", "liqStopCluster", "liqEqualHL", "liqSessionLiq", "liqPremDisc"],
        "smContext":  ["smOrderBlock", "smFVG", "smMitigation", "smBreakerBlock", "smRejectionBlock"],
    }
    for name, cols in groups.items():
        comp = _mean_of(cols)
        if comp is not None:
            df[name] = comp
    return df


def _parse_funnel_df(df: pd.DataFrame) -> pd.DataFrame:
    """Normalize/parse a raw funnel dataframe (column rename, time, numeric, composites)."""
    df = df.copy()
    # Normalize column names: EA uses short 'lt*' prefix, Python expects 'vpLT*'
    _lt_rename = {
        "ltTransitionScore":  "vpLTTransitionScore",
        "ltBalanceStability": "vpLTBalanceStability",
        "ltTrendDuration":    "vpLTTrendDuration",
        "ltTrendExhaustion":  "vpLTTrendExhaustion",
    }
    df.rename(columns={k: v for k, v in _lt_rename.items() if k in df.columns}, inplace=True)

    # Parse time
    if "timestamp" in df.columns:
        df["time"] = pd.to_datetime(df["timestamp"], format="%Y.%m.%d %H:%M:%S", errors="coerce")
    # Numeric coercion
    for col in FUNNEL_FEATURES:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Build BOS/CHOCH composites (collapse redundant raw columns)
    df = build_structure_composites(df)
    # Build bonus-engine group composites (collapse secondary engine scores)
    df = build_engine_composites(df)
    return df


def _parse_trades_df(df: pd.DataFrame) -> pd.DataFrame:
    """Normalize/parse a raw trades dataframe (time, win, numeric coercion)."""
    df = df.copy()
    for col in ["entryTime", "exitTime"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], format="%Y.%m.%d %H:%M:%S", errors="coerce")
    if "entryTime" in df.columns:
        df["time"] = df["entryTime"]

    if "profitUSD" in df.columns:
        df["profitUSD"] = pd.to_numeric(df["profitUSD"], errors="coerce")
        df["win"] = (df["profitUSD"] > 0).astype(int)
    if "profitPips" in df.columns:
        df["profitPips"] = pd.to_numeric(df["profitPips"], errors="coerce")

    numeric_cols = [c for c in df.columns if (c.startswith("entry") or c.startswith("exit"))
                    and c not in ["entryTime", "exitTime", "exitReason"]]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


# ═══════════════════════════════════════════════════════════════
# PARTITIONED DATA STORE — READ SIDE (Data/ folder)
# Raw MT5 CSVs are synced into per-(symbol, month) partition files by
# data_collect.py. This module only READS those partitions for analysis:
#   Data/VP_Funnel_{SYMBOL}_{MM.YYYY}.csv
#   Data/VP_Trades_{SYMBOL}_{MM.YYYY}.csv
# ═══════════════════════════════════════════════════════════════

def _parse_month_key(s: str):
    """Parse 'MM.YYYY' → (year, month) tuple for comparison, or None."""
    try:
        mm, yyyy = s.split(".")
        return (int(yyyy), int(mm))
    except Exception:
        return None


def _months_in_range(start: str, end: str):
    """Yield 'MM.YYYY' keys inclusive from start to end (both 'MM.YYYY')."""
    ps, pe = _parse_month_key(start), _parse_month_key(end)
    if ps is None or pe is None:
        return []
    (ys, ms), (ye, me) = ps, pe
    out = []
    y, m = ys, ms
    while (y, m) <= (ye, me):
        out.append(f"{m:02d}.{y}")
        m += 1
        if m > 12:
            m = 1; y += 1
    return out


def _load_partitioned(kind: str, parse_fn, start=None, end=None,
                      symbols=None, min_rows=1, warn_missing=True) -> pd.DataFrame:
    """Load partitioned CSVs from Data/, optionally filtered to [start, end] months."""
    if not DATA_DIR.exists():
        print(f"[WARN] Data store not found: {DATA_DIR}. Run sync_data() first.")
        return pd.DataFrame()

    files = glob.glob(str(DATA_DIR / f"{kind}_*.csv"))
    if not files:
        print(f"[WARN] No {kind}_*.csv in {DATA_DIR}. Run sync_data() first.")
        return pd.DataFrame()

    wanted_months = _months_in_range(start, end) if (start and end) else None

    # Track which requested months actually have files (for missing-data warning)
    found_months = set()
    dfs = []
    for f in sorted(files):
        stem = Path(f).stem  # e.g. VP_Funnel_XAUUSDm_01.2026
        rest = stem.replace(f"{kind}_", "")
        # rest = "{SYMBOL}_{MM.YYYY}" — split on last underscore
        if "_" not in rest:
            continue
        sym, month = rest.rsplit("_", 1)
        if symbols and sym not in symbols:
            continue
        if wanted_months is not None and month not in wanted_months:
            continue
        try:
            df = pd.read_csv(f, encoding="utf-8")
        except Exception as e:
            print(f"  [ERR] {Path(f).name}: {e}")
            continue
        if len(df) < min_rows:
            continue
        if "symbol" not in df.columns:
            df["symbol"] = sym
        found_months.add(month)
        dfs.append(df)

    # Missing-month warning
    if warn_missing and wanted_months is not None:
        missing = [m for m in wanted_months if m not in found_months]
        if missing:
            print(f"  [WARN] {kind}: no data for months: {', '.join(missing)}")

    if not dfs:
        return pd.DataFrame()
    df = pd.concat(dfs, ignore_index=True).copy()
    return parse_fn(df)


def load_funnel(symbols=None, min_rows=5, start=None, end=None) -> pd.DataFrame:
    """Load funnel data from the partitioned Data/ store, filtered to [start, end].

    start/end are 'MM.YYYY' strings (inclusive). If omitted, loads everything.
    """
    df = _load_partitioned("VP_Funnel", _parse_funnel_df, start, end,
                           symbols=symbols, min_rows=min_rows)
    if df.empty:
        print(f"[WARN] No funnel data loaded from {DATA_DIR}"
              f"{'' if not (start and end) else f' for {start}..{end}'}")
        return df
    print(f"\n[FUNNEL] Total: {len(df)} fired triggers across {df['symbol'].nunique()} symbols"
          f"{'' if not (start and end) else f' ({start}..{end})'}")
    return df


def load_trades(symbols=None, min_rows=1, start=None, end=None) -> pd.DataFrame:
    """Load trades data from the partitioned Data/ store, filtered to [start, end].

    start/end are 'MM.YYYY' strings (inclusive). If omitted, loads everything.
    """
    df = _load_partitioned("VP_Trades", _parse_trades_df, start, end,
                          symbols=symbols, min_rows=min_rows)
    if df.empty:
        print(f"[WARN] No trades data loaded from {DATA_DIR}"
              f"{'' if not (start and end) else f' for {start}..{end}'}")
        return df
    n = len(df)
    wr = df["win"].mean() if "win" in df.columns else 0
    print(f"\n[TRADES] Total: {n} trades, WR={wr:.1%}, "
          f"mean=${df.get('profitUSD', pd.Series([0])).mean():.2f}"
          f"{'' if not (start and end) else f' ({start}..{end})'}")
    return df


def merge_funnel_trades(funnel_df, trade_df, tolerance_sec=14400, min_records=5):
    """Merge funnel features onto trades by ticket (exact join).
    
    Fallback to time-based merge if ticket column not available.
    """
    if funnel_df is None or funnel_df.empty or trade_df is None or trade_df.empty:
        return None

    # ── Strategy 1: Exact join on ticket ────────────────────────
    if "ticket" in funnel_df.columns and "ticket" in trade_df.columns:
        funnel_valid = funnel_df[funnel_df["ticket"].notna() & (funnel_df["ticket"] > 0)].copy()
        trade_valid = trade_df[trade_df["ticket"].notna() & (trade_df["ticket"] > 0)].copy()

        if not funnel_valid.empty and not trade_valid.empty:
            funnel_valid["ticket"] = funnel_valid["ticket"].astype(int)
            trade_valid["ticket"] = trade_valid["ticket"].astype(int)

            merged = pd.merge(
                trade_valid, funnel_valid,
                on="ticket", how="inner", suffixes=("", "_funnel")
            )
            # Resolve duplicates
            for col in [c for c in merged.columns if c.endswith("_funnel")]:
                merged.drop(columns=[col], inplace=True, errors="ignore")

            if len(merged) >= min_records:
                if "time" in merged.columns:
                    merged = merged.sort_values("time").reset_index(drop=True)
                print(f"  [MERGE] ticket exact join: {len(merged)} records")
                return merged

    # ── Strategy 2: Time-based fallback ─────────────────────────
    if "time" not in funnel_df.columns or "time" not in trade_df.columns:
        print("  [MERGE] No time column available for fallback merge")
        return None

    funnel_df = funnel_df.copy()
    trade_df = trade_df.copy()
    funnel_df["time"] = pd.to_datetime(funnel_df["time"], errors="coerce")
    trade_df["time"] = pd.to_datetime(trade_df["time"], errors="coerce")
    funnel_df = funnel_df.dropna(subset=["time"])
    trade_df = trade_df.dropna(subset=["time"])

    if funnel_df.empty or trade_df.empty:
        return None

    by_cols = []
    if "symbol" in funnel_df.columns and "symbol" in trade_df.columns:
        by_cols.append("symbol")
    if "setupType" in funnel_df.columns and "setupType" in trade_df.columns:
        by_cols.append("setupType")

    merged = pd.merge_asof(
        trade_df.sort_values("time"),
        funnel_df.sort_values("time"),
        on="time", by=by_cols if by_cols else None,
        direction="backward",
        tolerance=pd.Timedelta(seconds=tolerance_sec),
        suffixes=("", "_funnel")
    )

    check_col = "vpPOC" if "vpPOC" in merged.columns else None
    if check_col:
        merged = merged.dropna(subset=[check_col])

    dedup_cols = ["time"] + by_cols
    merged = merged.drop_duplicates(subset=dedup_cols, keep="first")
    merged = merged.sort_values("time").reset_index(drop=True)

    n = len(merged)
    if n > 0:
        print(f"  [MERGE] time-based fallback: {n} records (tolerance={tolerance_sec}s)")
    return merged if n >= min_records else None


def list_available_months(kind: str = "VP_Trades"):
    """Return sorted list of 'MM.YYYY' partition keys present in the Data store."""
    if not DATA_DIR.exists():
        return []
    months = set()
    for f in glob.glob(str(DATA_DIR / f"{kind}_*.csv")):
        rest = Path(f).stem.replace(f"{kind}_", "")
        if "_" in rest:
            months.add(rest.rsplit("_", 1)[1])
    return sorted(months, key=lambda m: (_parse_month_key(m) or (9999, 99)))


def check_data_range(start: str, end: str, kind: str = "VP_Trades"):
    """Return (ok, missing_months) for the requested [start, end] range."""
    wanted = _months_in_range(start, end)
    have = set(list_available_months(kind))
    missing = [m for m in wanted if m not in have]
    return (len(missing) == 0, missing)


if __name__ == "__main__":
    print(f"Data store: {DATA_DIR}")
    print("Available months (trades):", list_available_months("VP_Trades"))
    print("Available months (funnel):", list_available_months("VP_Funnel"))
    print("\n(To sync fresh MT5 output into the Data store, run: python data_collect.py)")
