"""
data_collect.py — Sync raw MT5 CSVs into the partitioned Data/ store.

This is the WRITE side of the data pipeline. Run it once after each backtest:

    python data_collect.py

It reads the fresh VP_Funnel_*.csv / VP_Trades_*.csv from the MT5 Common\\Files
directory, splits each by (symbol, entry-month), and appends only NEW rows into:

    Data/VP_Funnel_{SYMBOL}_{MM.YYYY}.csv
    Data/VP_Trades_{SYMBOL}_{MM.YYYY}.csv

Rows already present (matched by ticket/timestamp) are skipped, so repeated
backtests accumulate rather than overwrite, and re-running is idempotent.

The READ side (analysis) lives in data_loader.py and never needs to run this.
"""
import glob
import pandas as pd
from pathlib import Path

from data_paths import DATA_DIR, MT5_FILES_DIR


def _month_key(ts) -> str:
    """Return 'MM.YYYY' partition key from a timestamp (NaT-safe → 'unknown')."""
    if pd.isna(ts):
        return "unknown"
    return f"{ts.month:02d}.{ts.year}"


def _dedup_key_funnel(df: pd.DataFrame) -> pd.Series:
    """Stable dedup key for funnel rows. ticket can be 0 (exec failed) and not
    unique, so combine ticket + timestamp + symbol + setupType."""
    tk = df["ticket"].astype(str) if "ticket" in df.columns else "0"
    tm = df["timestamp"].astype(str) if "timestamp" in df.columns else ""
    sy = df["symbol"].astype(str) if "symbol" in df.columns else ""
    st = df["setupType"].astype(str) if "setupType" in df.columns else ""
    return tk + "|" + tm + "|" + sy + "|" + st


def _dedup_key_trades(df: pd.DataFrame) -> pd.Series:
    """Stable dedup key for trade rows — ticket is the MT5 position id (unique)."""
    tk = df["ticket"].astype(str) if "ticket" in df.columns else ""
    tm = df["entryTime"].astype(str) if "entryTime" in df.columns else ""
    return tk + "|" + tm


def _sync_kind(kind: str, time_col: str, dedup_fn) -> int:
    """Sync one CSV family (VP_Funnel_* or VP_Trades_*) from MT5_FILES_DIR into
    the partitioned Data/ store. Returns number of NEW rows written."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    src_files = glob.glob(str(MT5_FILES_DIR / f"{kind}_*.csv"))
    if not src_files:
        return 0

    new_rows = 0
    for f in sorted(src_files):
        sym = Path(f).stem.replace(f"{kind}_", "")
        try:
            raw = pd.read_csv(f, encoding="utf-16")
        except Exception as e:
            print(f"  [ERR] sync {Path(f).name}: {e}")
            continue
        if raw.empty:
            continue
        raw = raw.copy()  # defragment before adding columns
        raw["symbol"] = sym

        # Determine partition month from the time column
        tparsed = pd.to_datetime(raw[time_col], format="%Y.%m.%d %H:%M:%S", errors="coerce") \
                  if time_col in raw.columns else pd.Series([pd.NaT] * len(raw))
        raw["_month"] = tparsed.map(_month_key)

        for (msym, month), part in raw.groupby(["symbol", "_month"]):
            part = part.drop(columns=["_month"])
            out = DATA_DIR / f"{kind}_{msym}_{month}.csv"
            if out.exists():
                try:
                    existing = pd.read_csv(out, encoding="utf-8")
                except Exception:
                    existing = pd.DataFrame()
            else:
                existing = pd.DataFrame()

            if not existing.empty:
                combined = pd.concat([existing, part], ignore_index=True)
                keys = dedup_fn(combined)
                combined = combined[~keys.duplicated(keep="first")].reset_index(drop=True)
                added = len(combined) - len(existing)
            else:
                combined = part.reset_index(drop=True)
                keys = dedup_fn(combined)
                combined = combined[~keys.duplicated(keep="first")].reset_index(drop=True)
                added = len(combined)

            if added > 0:
                combined.to_csv(out, index=False, encoding="utf-8")
                new_rows += added
                print(f"  [SYNC] {out.name}: +{added} rows (total {len(combined)})")
    return new_rows


def sync_data() -> None:
    """Sync fresh MT5 CSVs from Common/Files into the partitioned Data/ store.
    Appends only new rows (dedup by ticket/timestamp); existing rows are skipped."""
    print("=" * 60)
    print(f"SYNC DATA  {MT5_FILES_DIR}  ->  {DATA_DIR}")
    print("=" * 60)
    nf = _sync_kind("VP_Funnel", "timestamp", _dedup_key_funnel)
    nt = _sync_kind("VP_Trades", "entryTime", _dedup_key_trades)
    print(f"  Synced: +{nf} funnel rows, +{nt} trade rows")
    if nf == 0 and nt == 0:
        print("  (nothing new — Data store already up to date)")


if __name__ == "__main__":
    sync_data()
