"""
data_loader.py — Data loading for VP Analysis New research pipeline.

READ side only. Never syncs or writes raw CSVs — that is data_collect.py.

Loads partitioned Data/ store (written by data_collect.py) and merges
VP_Funnel + VP_Trades into a single analysis-ready DataFrame that the
pipeline's L0 → L12 layers consume.

Quick start
-----------
    from data_loader import load_merged

    df = load_merged(symbols=["XAUUSDm"], start="01.2026", end="03.2026")
    # df is the merged funnel+trades DataFrame for the pipeline

Key concepts
------------
  - Data is partitioned: Data/VP_Funnel_{SYM}_{MM.YYYY}.csv
  - 3-style collection: each signal fires 3 trades (trailStyle -1/0/1).
    signalId+trailStyle is the preferred join key.
  - split_by_style() separates production-style (L0-L8 analysis) from
    all-styles (L10a canary labeling, L4b robustness checks).
"""
import glob
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

from data_paths import DATA_DIR

# ─── Trailing style constants ─────────────────────────────────────
TRAIL_STYLES = [-1, 0, 1]
PRODUCTION_STYLE_DEFAULT = 1   # expansion trailing (EA default)

# ─── Feature column lists (ported from old data_loader) ──────────

VP_CORE_FEATURES = [
    "vpPOC", "vpVAH", "vpVAL", "vpInsideVA", "vpDistToHVN", "vpDistToLVN",
    "vpPriceVsPOC", "vpDailyPOC",
]
VP_COMPOSITE_FEATURES = [
    "vpCompPOC", "vpCompVAH", "vpCompVAL", "vpCompInsideVA", "vpDistCompPOC",
]
VP_ENHANCED_FEATURES = [
    "vpThinnessRatio", "vpProfileShape", "vpBestHVN", "vpBestHVNScore",
    "vpVAOverlapRatio", "vpVAOverlapBias", "vpRangePOC", "vpBreakoutPOC",
    "vpPullbackPOC", "vpNearestNakedPOC", "vpDistNakedPOC_ATR",
    "vpUpthrust", "vpSpring", "vpCompPosition", "vpMigrationConf",
    "vpDevPOCDir", "vpDevPOCSlope", "vpMigrationScore",
]
AUCTION_FEATURES = [
    "auctAcceptance", "auctState", "auctBalance", "auctProfileShape",
    "auctShapeConf", "auctMajorHVN", "auctMajorLVN", "auctDistHVN",
    "auctDistLVN", "auctVAExpRate", "auctVAState", "auctFailure",
    "auctRegime", "auctRegimeConf", "auctExpReward", "auctExpMoveATR",
    "auctTargetProb", "auctTradeQuality", "auctTradeGrade",
    "auctTargetPrice", "auctTargetType", "auctTargetConf",
    "auctProfitZone", "auctExhaustion", "auctContinuation",
    "auctReversalRisk", "auctHVNStrength", "auctLVNStrength",
]
VP_LONGTERM_FEATURES = [
    "vpLTPOC60d", "vpLTPOC30d", "vpLTPOC10d",
    "vpLTPOCVelocity", "vpLTPOCAcceleration", "vpLTPOCMigration",
    "vpLTMajorHVNPrice", "vpLTMajorHVNStrength",
    "vpLTMajorLVNPrice", "vpLTMajorLVNStrength",
    "vpLTNearestZonePrice", "vpLTNearestZoneStrength", "vpLTNearestZoneDir",
    "vpLTAcceptanceAtPrice", "vpLTValid",
    "vpLTTransitionScore", "vpLTBalanceStability",
    "vpLTTrendDuration", "vpLTTrendExhaustion",
]
MICROSTRUCTURE_FEATURES = [
    "msSpreadScore", "msTickVelocity", "msTickImbalance",
    "msLiqVacuum", "msCompression",
]
ORDERFLOW_FEATURES = [
    "ofDeltaProxy", "ofCvdProxy", "ofAbsorption", "ofExhaustion",
    "ofParticipation", "ofDivergence", "ofBullDiv", "ofBearDiv",
    "ofFlowIntensity",
]
LIQUIDITY_FEATURES = [
    "liqDensity", "liqSweep", "liqStopCluster", "liqEqualHL",
    "liqSessionLiq", "liqPremDisc",
]
SMARTMONEY_FEATURES = [
    "smOrderBlock", "smFVG", "smMitigation", "smBreakerBlock",
    "smRejectionBlock", "smZoneQuality",
]
STRUCTURE_FEATURES = [
    "bosConfirmed", "bosBullish", "bosScore", "bosLevel",
    "chochConfirmed", "chochBullish", "chochScore", "chochLevel",
    "trendDirection", "structDistATR",
]
MARKET_FEATURES = [
    "spreadPoints", "avgSpread", "spreadToATR", "atrProxy", "dataQuality",
]
SETUP_FEATURES = ["entryPrice", "SL", "TP", "RR"]

# All analysis-ready numeric features
_ALL = (
    VP_CORE_FEATURES + VP_COMPOSITE_FEATURES + VP_ENHANCED_FEATURES
    + AUCTION_FEATURES + VP_LONGTERM_FEATURES
    + MICROSTRUCTURE_FEATURES + ORDERFLOW_FEATURES
    + LIQUIDITY_FEATURES + SMARTMONEY_FEATURES
    + STRUCTURE_FEATURES + MARKET_FEATURES + SETUP_FEATURES
)
_seen: set = set()
FUNNEL_FEATURES: list[str] = [x for x in _ALL if not (x in _seen or _seen.add(x))]  # type: ignore[func-returns-value]

# Regime int → name
REGIME_NAMES = {
    0: "BALANCED_ROTATION", 1: "COMPRESSION", 2: "TREND_INITIATION",
    3: "TREND_CONTINUATION", 4: "RE_ACCUMULATION", 5: "EXHAUSTION",
    6: "FAILED_AUCTION", 7: "EXCESS", 8: "CHAOTIC",
}


# ─── Month key helpers ────────────────────────────────────────────

def _parse_month_key(s: str) -> tuple[int, int] | None:
    """Parse 'MM.YYYY' → (year, month) for sorting/comparison."""
    try:
        mm, yyyy = s.split(".")
        return (int(yyyy), int(mm))
    except Exception:
        return None


def _months_in_range(start: str, end: str) -> list[str]:
    """Yield 'MM.YYYY' keys inclusive from start to end."""
    ps, pe = _parse_month_key(start), _parse_month_key(end)
    if ps is None or pe is None:
        return []
    (ys, ms_), (ye, me) = ps, pe
    out: list[str] = []
    y, m = ys, ms_
    while (y, m) <= (ye, me):
        out.append(f"{m:02d}.{y}")
        m += 1
        if m > 12:
            m = 1
            y += 1
    return out


# ─── Parsing helpers ──────────────────────────────────────────────

def _parse_funnel(df: pd.DataFrame) -> pd.DataFrame:
    """Normalise a raw funnel DataFrame: rename columns, parse time, coerce numerics,
    and build composite features (structure quality, engine group composites).
    """
    df = df.copy()

    # EA uses short 'lt*' prefix; analysis expects 'vpLT*'
    _rename = {
        "ltTransitionScore":  "vpLTTransitionScore",
        "ltBalanceStability": "vpLTBalanceStability",
        "ltTrendDuration":    "vpLTTrendDuration",
        "ltTrendExhaustion":  "vpLTTrendExhaustion",
    }
    df.rename(columns={k: v for k, v in _rename.items() if k in df.columns}, inplace=True)

    if "timestamp" in df.columns:
        df["time"] = pd.to_datetime(
            df["timestamp"], format="%Y.%m.%d %H:%M:%S", errors="coerce",
        )
    if "trailStyle" in df.columns:
        df["trailStyle"] = pd.to_numeric(df["trailStyle"], errors="coerce")
    if "signalId" in df.columns:
        df["signalId"] = df["signalId"].astype(str)

    for col in FUNNEL_FEATURES:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Build composite features
    df = _build_structure_composites(df)
    df = _build_engine_composites(df)
    return df


def _build_structure_composites(df: pd.DataFrame) -> pd.DataFrame:
    """Collapse BOS/CHOCH raw columns into signed quality composites.

    bosQuality  : signed [-1,1] — BOS strength × confirmation × proximity, signed by direction
    chochQuality: same for CHOCH
    structAlign : [0,1] — agreement between structure direction and trendDirection
    """
    df = df.copy()

    def _proximity(level_col: str) -> pd.Series:
        if ("entryPrice" in df.columns and level_col in df.columns
                and "structDistATR" in df.columns):
            d = pd.to_numeric(df["structDistATR"], errors="coerce").fillna(3.0)
            prox = (1.0 - (d / 3.0)).clip(lower=0.0, upper=1.0)
            return prox.fillna(0.5)
        return pd.Series(0.5, index=df.index)

    def _group_quality(prefix: str, level_col: str) -> pd.Series:
        conf_col  = f"{prefix}Confirmed"
        bull_col  = f"{prefix}Bullish"
        score_col = f"{prefix}Score"
        score = pd.to_numeric(df[score_col],  errors="coerce").fillna(0.0) if score_col  in df.columns else pd.Series(0.0, index=df.index)
        conf  = pd.to_numeric(df[conf_col],   errors="coerce").fillna(0.0) if conf_col   in df.columns else pd.Series(1.0, index=df.index)
        bull  = pd.to_numeric(df[bull_col],   errors="coerce").fillna(0.0) if bull_col   in df.columns else pd.Series(0.0, index=df.index)
        prox  = _proximity(level_col)
        magnitude = score.clip(0, 1) * conf.clip(0, 1) * prox
        sign = np.where(bull >= 0.5, 1.0, -1.0)
        return (magnitude * sign).astype(np.float32)

    if any(c.startswith("bos") for c in df.columns):
        df["bosQuality"] = _group_quality("bos", "bosLevel")
    if any(c.startswith("choch") for c in df.columns):
        df["chochQuality"] = _group_quality("choch", "chochLevel")

    if "trendDirection" in df.columns:
        trend = pd.to_numeric(df["trendDirection"], errors="coerce").fillna(0.0)
        struct_sign = pd.Series(0.0, index=df.index)
        if "bosQuality"   in df.columns: struct_sign = struct_sign + np.sign(df["bosQuality"])
        if "chochQuality" in df.columns: struct_sign = struct_sign + np.sign(df["chochQuality"])
        struct_sign = np.sign(struct_sign)
        align = np.where(trend == 0, 0.5,
                np.where(np.sign(trend) == struct_sign, 1.0,
                np.where(struct_sign == 0, 0.5, 0.0)))
        df["structAlign"] = align.astype(np.float32)

    return df


def _build_engine_composites(df: pd.DataFrame) -> pd.DataFrame:
    """Collapse bonus-engine SECONDARY outputs into group composites.

    Primary features (kept raw): msCompression, ofFlowIntensity, liqSweep, smZoneQuality
    Composites (mean of secondary scores):
        msContext   = mean(msSpreadScore, msTickVelocity, msTickImbalance, msLiqVacuum)
        ofContext   = mean(ofDeltaProxy, ofCvdProxy, ofAbsorption, ofExhaustion, ofParticipation, ofDivergence)
        liqContext  = mean(liqDensity, liqStopCluster, liqEqualHL, liqSessionLiq, liqPremDisc)
        smContext   = mean(smOrderBlock, smFVG, smMitigation, smBreakerBlock, smRejectionBlock)
    """
    df = df.copy()

    def _mean_of(cols: list[str]) -> Optional[pd.Series]:
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


def _parse_trades(df: pd.DataFrame) -> pd.DataFrame:
    """Normalise a raw trades DataFrame: parse times, add win, coerce numerics."""
    df = df.copy()

    for col in ("entryTime", "exitTime"):
        if col in df.columns:
            df[col] = pd.to_datetime(
                df[col], format="%Y.%m.%d %H:%M:%S", errors="coerce",
            )
    if "entryTime" in df.columns:
        df["time"] = df["entryTime"]

    if "profitUSD" in df.columns:
        df["profitUSD"] = pd.to_numeric(df["profitUSD"], errors="coerce")
        df["_profit"] = df["profitUSD"]        # canonical profit column for pipeline
        df["win"] = (df["profitUSD"] > 0).astype(int)

    if "trailStyle" in df.columns:
        df["trailStyle"] = pd.to_numeric(df["trailStyle"], errors="coerce")
    if "signalId" in df.columns:
        df["signalId"] = df["signalId"].astype(str)
    if "maeATR" in df.columns:
        df["maeATR"] = pd.to_numeric(df["maeATR"], errors="coerce")
    if "mfeATR" in df.columns:
        df["mfeATR"] = pd.to_numeric(df["mfeATR"], errors="coerce")

    return df


# ─── Partitioned store loaders ────────────────────────────────────

def _load_partitioned(
    kind: str,
    parse_fn,
    start: Optional[str] = None,
    end: Optional[str] = None,
    symbols: Optional[list[str]] = None,
    min_rows: int = 1,
    warn_missing: bool = True,
) -> pd.DataFrame:
    """Load partitioned CSVs from Data/, filtered to [start, end] months."""
    if not DATA_DIR.exists():
        print(f"[WARN] Data store not found: {DATA_DIR}. Run data_collect.py first.")
        return pd.DataFrame()

    files = sorted(glob.glob(str(DATA_DIR / f"{kind}_*.csv")))
    if not files:
        print(f"[WARN] No {kind}_*.csv in {DATA_DIR}. Run data_collect.py first.")
        return pd.DataFrame()

    wanted_months = _months_in_range(start, end) if (start and end) else None
    found_months: set[str] = set()
    dfs: list[pd.DataFrame] = []

    for fpath in files:
        stem = Path(fpath).stem                    # VP_Funnel_XAUUSDm_01.2026
        rest = stem.replace(f"{kind}_", "", 1)    # XAUUSDm_01.2026
        if "_" not in rest:
            continue
        sym, month = rest.rsplit("_", 1)
        if symbols and sym not in symbols:
            continue
        if wanted_months is not None and month not in wanted_months:
            continue
        try:
            df = pd.read_csv(fpath, encoding="utf-8", low_memory=False,
                             dtype={"signalId": str})
        except Exception as e:
            print(f"  [ERR] {Path(fpath).name}: {e}")
            continue
        if len(df) < min_rows:
            continue
        if "symbol" not in df.columns:
            df["symbol"] = sym
        found_months.add(month)
        dfs.append(df)

    if warn_missing and wanted_months is not None:
        missing = [m for m in wanted_months if m not in found_months]
        if missing:
            print(f"  [WARN] {kind}: no data for months: {', '.join(missing)}")

    if not dfs:
        return pd.DataFrame()

    combined = pd.concat(dfs, ignore_index=True)
    return parse_fn(combined)


def load_funnel(
    symbols: Optional[list[str]] = None,
    start: Optional[str] = None,
    end: Optional[str] = None,
    min_rows: int = 5,
) -> pd.DataFrame:
    """Load funnel data from the partitioned Data/ store.

    Parameters
    ----------
    symbols : list[str] | None   Filter to specific symbols (e.g. ['XAUUSDm']).
    start   : 'MM.YYYY' | None   Start month inclusive.
    end     : 'MM.YYYY' | None   End month inclusive.
    min_rows: int                Skip partitions with fewer rows.
    """
    df = _load_partitioned("VP_Funnel", _parse_funnel, start, end,
                           symbols=symbols, min_rows=min_rows)
    if df.empty:
        print(f"[WARN] No funnel data loaded from {DATA_DIR}")
        return df
    rng = f" ({start}..{end})" if (start and end) else ""
    print(f"[FUNNEL] {len(df):,} fired triggers "
          f"across {df['symbol'].nunique()} symbol(s){rng}")
    return df


def load_trades(
    symbols: Optional[list[str]] = None,
    start: Optional[str] = None,
    end: Optional[str] = None,
    min_rows: int = 1,
) -> pd.DataFrame:
    """Load trades data from the partitioned Data/ store."""
    df = _load_partitioned("VP_Trades", _parse_trades, start, end,
                           symbols=symbols, min_rows=min_rows)
    if df.empty:
        print(f"[WARN] No trades data loaded from {DATA_DIR}")
        return df
    rng = f" ({start}..{end})" if (start and end) else ""
    wr = df["win"].mean() if "win" in df.columns else float("nan")
    ev = df["profitUSD"].mean() if "profitUSD" in df.columns else float("nan")
    print(f"[TRADES] {len(df):,} trades  WR={wr:.1%}  EV=${ev:+.2f}{rng}")
    return df


# ─── Merge funnel + trades ────────────────────────────────────────

def merge_funnel_trades(
    funnel_df: pd.DataFrame,
    trade_df: pd.DataFrame,
    tolerance_sec: int = 14_400,
    min_records: int = 5,
) -> Optional[pd.DataFrame]:
    """Merge funnel (entry) features onto trades (outcomes).

    Join priority:
      1. signalId + trailStyle  — exact 1:1 for new 3-style EA data (preferred)
      2. ticket exact join      — legacy single-style data
      3. time-based merge_asof  — last-resort fallback

    Returns None if fewer than min_records rows result.
    """
    if funnel_df is None or funnel_df.empty or trade_df is None or trade_df.empty:
        return None

    def _clean(df: pd.DataFrame) -> pd.DataFrame:
        """Drop *_funnel suffix columns left by merge suffixes."""
        drop = [c for c in df.columns if c.endswith("_funnel")]
        return df.drop(columns=drop, errors="ignore")

    # ── Strategy 1: signalId + trailStyle ────────────────────────
    has_sig = (
        "signalId" in funnel_df.columns and "signalId" in trade_df.columns
    )
    if has_sig:
        f = funnel_df.copy()
        t = trade_df.copy()
        # Keep only rows with a real signalId
        _valid = lambda s: s.notna() & (s.astype(str) != "") & (s.astype(str) != "nan")
        f = f[_valid(f["signalId"])]
        t = t[_valid(t["signalId"])]

        if not f.empty and not t.empty:
            keys = ["signalId"]
            if "trailStyle" in f.columns and "trailStyle" in t.columns:
                keys.append("trailStyle")

            merged = pd.merge(t, f, on=keys, how="inner", suffixes=("", "_funnel"))
            merged = _clean(merged)

            if len(merged) >= min_records:
                # Coverage check: if < 10% of trades matched, EA signalId may be broken
                coverage = len(merged) / max(len(trade_df), 1)
                if coverage >= 0.10:
                    if "time" in merged.columns:
                        merged = merged.sort_values("time").reset_index(drop=True)
                    n_sig = merged["signalId"].nunique()
                    print(f"  [MERGE] signalId join: {len(merged):,} records "
                          f"across {n_sig:,} signals "
                          f"(avg {len(merged)/max(n_sig,1):.1f} exits/signal)")
                    return merged
                else:
                    print(f"  [MERGE] signalId low coverage ({coverage:.1%}) "
                          f"— falling back to ticket join")

    # ── Strategy 2: Exact ticket join ────────────────────────────
    if "ticket" in funnel_df.columns and "ticket" in trade_df.columns:
        fv = funnel_df[funnel_df["ticket"].notna() & (funnel_df["ticket"] > 0)].copy()
        tv = trade_df[trade_df["ticket"].notna() & (trade_df["ticket"] > 0)].copy()
        if not fv.empty and not tv.empty:
            fv["ticket"] = fv["ticket"].astype(int)
            tv["ticket"] = tv["ticket"].astype(int)
            merged = pd.merge(tv, fv, on="ticket", how="inner",
                              suffixes=("", "_funnel"))
            merged = _clean(merged)
            if len(merged) >= min_records:
                if "time" in merged.columns:
                    merged = merged.sort_values("time").reset_index(drop=True)
                print(f"  [MERGE] ticket exact join: {len(merged):,} records")
                return merged

    # ── Strategy 3: Time-based fallback ──────────────────────────
    if "time" not in funnel_df.columns or "time" not in trade_df.columns:
        print("  [MERGE] No time column — cannot merge")
        return None

    f3 = funnel_df.copy()
    t3 = trade_df.copy()
    f3["time"] = pd.to_datetime(f3["time"], errors="coerce")
    t3["time"] = pd.to_datetime(t3["time"], errors="coerce")
    f3 = f3.dropna(subset=["time"])
    t3 = t3.dropna(subset=["time"])
    if f3.empty or t3.empty:
        return None

    by_cols = [c for c in ("symbol", "setupType")
               if c in f3.columns and c in t3.columns]

    merged = pd.merge_asof(
        t3.sort_values("time"),
        f3.sort_values("time"),
        on="time",
        by=by_cols or None,
        direction="backward",
        tolerance=pd.Timedelta(seconds=tolerance_sec),
        suffixes=("", "_funnel"),
    )
    merged = _clean(merged)

    # Drop rows where funnel didn't match (anchor column is NaN)
    anchor = "vpPOC" if "vpPOC" in merged.columns else None
    if anchor:
        merged = merged.dropna(subset=[anchor])

    merged = merged.drop_duplicates(
        subset=["time"] + by_cols, keep="first",
    ).sort_values("time").reset_index(drop=True)

    n = len(merged)
    if n >= min_records:
        print(f"  [MERGE] time-based fallback: {n:,} records "
              f"(tolerance={tolerance_sec}s)")
        return merged
    return None


# ─── Convenience: load everything merged ─────────────────────────

def _build_consensus_targets(df: pd.DataFrame) -> pd.DataFrame:
    """Add cross-style consensus columns to the merged frame.

    For each signalId group (3 rows with trailStyle -1, 0, 1):

      _all_styles_win   : 1.0 if ALL 3 styles have profitUSD > 0, else 0.0
                          Best-entry indicator — independent of trailing behavior.

      _all_styles_loss  : 1.0 if ALL 3 styles have profitUSD < 0, else 0.0
                          Worst-entry indicator.

      _consensus_profit : mean(profitUSD) across all styles for the signal.
                          Entry quality measure independent of exit style.

      _style_agree_count: number of styles with profitUSD > 0 (0, 1, 2, or 3).

    If signalId or trailStyle columns are missing, returns df unchanged.
    Existing rows are preserved; only new columns are added.
    """
    if "signalId" not in df.columns or "profitUSD" not in df.columns:
        return df

    profit = pd.to_numeric(df["profitUSD"], errors="coerce")
    sig = df["signalId"]

    # Per-signal aggregates — compute on Series directly, avoid full df.copy()
    # Use merge on signalId instead of transform to avoid 2.5GB consolidation
    sig_stats = (
        profit.groupby(sig)
        .agg(
            _consensus_profit="mean",
            _all_styles_win=lambda x: float((x > 0).all()),
            _all_styles_loss=lambda x: float((x < 0).all()),
            _style_agree_count=lambda x: float((x > 0).sum()),
        )
        .reset_index()
    )
    sig_stats.columns = ["signalId",
                         "_consensus_profit", "_all_styles_win",
                         "_all_styles_loss", "_style_agree_count"]

    # Assign columns directly without copying the whole DataFrame
    # This avoids the 2.55 GiB consolidation triggered by df.copy()
    merged_stats = df["signalId"].map(sig_stats.set_index("signalId")["_consensus_profit"])
    df["_consensus_profit"]  = merged_stats.values
    df["_all_styles_win"]    = df["signalId"].map(sig_stats.set_index("signalId")["_all_styles_win"]).values
    df["_all_styles_loss"]   = df["signalId"].map(sig_stats.set_index("signalId")["_all_styles_loss"]).values
    df["_style_agree_count"] = df["signalId"].map(sig_stats.set_index("signalId")["_style_agree_count"]).values

    n_sig = int(sig_stats.shape[0])
    n_all_win  = int((sig_stats["_all_styles_win"] == 1.0).sum())
    n_all_loss = int((sig_stats["_all_styles_loss"] == 1.0).sum())
    print(f"  [CONSENSUS] {n_sig} signals: "
          f"{n_all_win} all-win ({n_all_win/max(n_sig,1):.0%}), "
          f"{n_all_loss} all-loss ({n_all_loss/max(n_sig,1):.0%})")
    return df


def _normalize_vp_features(df: pd.DataFrame) -> pd.DataFrame:
    """Normalize absolute VP price levels to ATR-relative signed distances.

    VP features like vpPOC, vpVAH, vpVAL are absolute prices (e.g. 5259 USD/oz).
    This makes them perfectly correlated (Spearman ≈ 1.0) because they all
    move with the market price level.

    Fix: replace each absolute price level with its signed distance from
    entryPrice, normalised by ATR-in-price-units:
        vpPOC_norm = (vpPOC - entryPrice) / atr_in_price

    where atr_in_price is inferred as:
        atr_in_price = atrProxy * (entryPrice / atrProxy / 100)
                     ≈ entryPrice * 0.01   (assuming ATR ≈ 1% of price)

    This approximation is good enough to remove the correlation: the exact
    ATR value only affects the scale of the normalised feature, not its
    rank order (Spearman rho is rank-based).

    Columns that look like absolute prices (median > 100 × min_plausible)
    are normalized. Non-price columns (already normalised by the EA, ratios,
    booleans) are left unchanged.
    """
    if "entryPrice" not in df.columns:
        return df

    # No df.copy() — modifying VP price columns in-place is safe and avoids OOM
    # on large merged DataFrames (2M+ rows × 143 columns)
    entry = pd.to_numeric(df["entryPrice"], errors="coerce")
    entry_median = float(entry.median())
    if entry_median <= 0:
        return df

    # atrProxy is in POINTS. Convert to price: atrInPrice = atrProxy * pointSize.
    # We infer pointSize from atrProxy vs entryPrice — ATR is typically 0.3-1.5%
    # of price for most instruments:
    #   pointSize ≈ (entryPrice * 0.01) / atrProxy_median
    if "atrProxy" in df.columns:
        atr_pts = pd.to_numeric(df["atrProxy"], errors="coerce")
        atr_median = float(atr_pts.median())
        if atr_median > 0:
            implied_pt = (entry_median * 0.01) / atr_median
            atr_price = atr_pts * implied_pt
        else:
            atr_price = entry * 0.01
    else:
        atr_price = entry * 0.01   # 1% of price as ATR proxy

    atr_safe = atr_price.where(atr_price > 1e-12, other=entry_median * 0.01)

    # Columns to normalize: those whose median is close to entry price
    # (i.e. absolute price levels, not already-normalised ratios)
    price_threshold = entry_median * 0.10   # within 10× entry price = absolute price

    VP_PRICE_COLS = [
        # Core VP levels
        "vpPOC", "vpVAH", "vpVAL", "vpDailyPOC",
        "vpCompPOC", "vpCompVAH", "vpCompVAL",
        "vpBestHVN", "vpNearestNakedPOC",
        "vpBreakoutPOC", "vpPullbackPOC", "vpRangePOC",
        # Auction price target
        "auctTargetPrice",
        # Long-term VP levels
        "vpLTPOC60d", "vpLTPOC30d", "vpLTPOC10d",
        "vpLTMajorHVNPrice", "vpLTMajorLVNPrice",
        "vpLTNearestZonePrice",
        # Trade-record prefixed versions (from VPTradeRecord.mqh)
        "entryVpPOC", "entryVpVAH", "entryVpVAL",
        "entryAuctTargetPrice",
    ]
    for col in VP_PRICE_COLS:
        if col not in df.columns:
            continue
        vals = pd.to_numeric(df[col], errors="coerce")
        col_median = float(vals.median())
        # Only normalize if it looks like an absolute price
        if abs(col_median) >= price_threshold:
            df[col] = (vals - entry) / atr_safe

    return df

def load_merged(
    symbols: Optional[list[str]] = None,
    start: Optional[str] = None,
    end: Optional[str] = None,
    min_records: int = 5,
) -> Optional[pd.DataFrame]:
    """Load funnel + trades and merge them.

    This is the main entry point for the analysis pipeline:

        df = load_merged(symbols=["XAUUSDm"], start="01.2026", end="03.2026")
        result = run_pipeline(merged_df=df, contract=contract, ...)

    Returns None if merge fails or too few records.
    """
    funnel = load_funnel(symbols=symbols, start=start, end=end)
    trades = load_trades(symbols=symbols, start=start, end=end)

    if funnel.empty or trades.empty:
        print("[WARN] Cannot merge: funnel or trades is empty")
        return None

    merged = merge_funnel_trades(funnel, trades, min_records=min_records)
    if merged is None or merged.empty:
        print("[WARN] Merge produced no records")
        return None

    # Ensure _profit column exists (pipeline canonical name)
    if "_profit" not in merged.columns and "profitUSD" in merged.columns:
        merged["_profit"] = pd.to_numeric(merged["profitUSD"], errors="coerce")

    merged = _build_consensus_targets(merged)

    # Normalize absolute VP price levels to ATR-relative distances.
    # This removes the spurious ~1.0 Spearman correlation between VP levels
    # that arises because they are all absolute prices moving with the market.
    merged = _normalize_vp_features(merged)

    print(f"\n[MERGED] {len(merged):,} rows ready for pipeline")
    return merged


# ─── Style helpers ────────────────────────────────────────────────

def has_trail_styles(df: Optional[pd.DataFrame]) -> bool:
    """True if the DataFrame has a meaningful trailStyle column."""
    if df is None or "trailStyle" not in df.columns:
        return False
    vals = pd.to_numeric(df["trailStyle"], errors="coerce").dropna().unique()
    return any(int(v) in TRAIL_STYLES for v in vals)


def split_by_style(
    merged: pd.DataFrame,
    production_style: int = PRODUCTION_STYLE_DEFAULT,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Split merged frame into (production_df, all_styles_df).

    production_df  : rows with trailStyle == production_style
                     → used for hard/soft gate metrics (EV, thresholds, sizing)
    all_styles_df  : all rows across styles
                     → used for L10a canary labeling and robustness checks

    If no trailStyle column exists, both returns are the input unchanged.
    """
    if merged is None or len(merged) == 0:
        return merged, merged
    if not has_trail_styles(merged):
        return merged, merged

    m = merged.copy()
    m["trailStyle"] = pd.to_numeric(m["trailStyle"], errors="coerce")
    prod = m[m["trailStyle"] == production_style].reset_index(drop=True)
    return prod, m


# ─── Store inspection ─────────────────────────────────────────────

def list_available_months(kind: str = "VP_Trades") -> list[str]:
    """Return sorted list of 'MM.YYYY' partition keys present in the Data store."""
    if not DATA_DIR.exists():
        return []
    months: set[str] = set()
    for f in DATA_DIR.glob(f"{kind}_*.csv"):
        rest = f.stem.replace(f"{kind}_", "", 1)
        if "_" in rest:
            months.add(rest.rsplit("_", 1)[1])
    return sorted(months, key=lambda m: (_parse_month_key(m) or (9999, 99)))


def list_available_symbols(kind: str = "VP_Trades") -> list[str]:
    """Return sorted list of symbols present in the Data store."""
    if not DATA_DIR.exists():
        return []
    symbols: set[str] = set()
    for f in DATA_DIR.glob(f"{kind}_*.csv"):
        rest = f.stem.replace(f"{kind}_", "", 1)
        if "_" in rest:
            symbols.add(rest.rsplit("_", 1)[0])
    return sorted(symbols)


def check_data_range(start: str, end: str, kind: str = "VP_Trades") -> tuple[bool, list[str]]:
    """Return (ok, missing_months) for the requested range."""
    wanted = _months_in_range(start, end)
    have = set(list_available_months(kind))
    missing = [m for m in wanted if m not in have]
    return len(missing) == 0, missing


# ─── CLI / quick check ────────────────────────────────────────────

if __name__ == "__main__":
    print(f"Data store : {DATA_DIR}")
    syms = list_available_symbols()
    months_t = list_available_months("VP_Trades")
    months_f = list_available_months("VP_Funnel")
    print(f"Symbols    : {syms or '(none)'}")
    print(f"Months (T) : {months_t or '(none)'}")
    print(f"Months (F) : {months_f or '(none)'}")
    print()
    if not syms:
        print("No data yet. Run: python data_collect.py")
    else:
        print("To load data:")
        print("  from data_loader import load_merged")
        print("  df = load_merged()")
