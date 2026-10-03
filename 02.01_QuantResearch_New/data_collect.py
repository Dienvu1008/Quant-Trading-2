"""
data_collect.py — Sync raw MT5 CSVs into the partitioned Data/ store.

WRITE side of the data pipeline. Run once after each backtest:

    python data_collect.py

Reads VP_Funnel_*.csv / VP_Trades_*.csv from the MT5 Common/Files directory,
splits each by (symbol, entry-month), and appends only NEW rows into:

    Data/VP_Funnel_{SYMBOL}_{MM.YYYY}.csv
    Data/VP_Trades_{SYMBOL}_{MM.YYYY}.csv

Rows already present (matched by dedup key) are skipped, so repeated
backtests accumulate rather than overwrite, and re-running is idempotent.

The READ side (analysis) lives in data_loader.py — never run this there.

Usage
-----
    python data_collect.py                     # sync all symbols
    python data_collect.py --symbol XAUUSD     # sync one symbol only
    python data_collect.py --dry-run           # show what would be written
"""
import argparse
import glob
import sys
from pathlib import Path

import pandas as pd

from data_paths import DATA_DIR, MT5_FILES_DIR


# ─── Dedup key helpers ───────────────────────────────────────────

def _dedup_key_funnel(df: pd.DataFrame) -> pd.Series:
    """Stable dedup key for funnel rows.
    ticket can be 0 (exec failed) and is not unique, so combine multiple cols.
    signalId+trailStyle is the preferred key for new EA data (3-style collection).
    """
    if "signalId" in df.columns and "trailStyle" in df.columns:
        sig = df["signalId"].astype(str).fillna("")
        sty = df["trailStyle"].astype(str).fillna("")
        # Fall back to combined key only if signalId is missing/empty
        has_sig = (sig != "") & (sig != "nan") & (sig != "None")
        tk = df["ticket"].astype(str) if "ticket" in df.columns else pd.Series("0", index=df.index)
        tm = df["timestamp"].astype(str) if "timestamp" in df.columns else pd.Series("", index=df.index)
        sy = df["symbol"].astype(str) if "symbol" in df.columns else pd.Series("", index=df.index)
        st = df["setupType"].astype(str) if "setupType" in df.columns else pd.Series("", index=df.index)
        fallback = tk + "|" + tm + "|" + sy + "|" + st
        return pd.Series(
            [f"{s}|{t}" if h else f for s, t, h, f in zip(sig, sty, has_sig, fallback)],
            index=df.index,
        )
    tk = df["ticket"].astype(str) if "ticket" in df.columns else pd.Series("0", index=df.index)
    tm = df["timestamp"].astype(str) if "timestamp" in df.columns else pd.Series("", index=df.index)
    sy = df["symbol"].astype(str) if "symbol" in df.columns else pd.Series("", index=df.index)
    st = df["setupType"].astype(str) if "setupType" in df.columns else pd.Series("", index=df.index)
    return tk + "|" + tm + "|" + sy + "|" + st


def _dedup_key_trades(df: pd.DataFrame) -> pd.Series:
    """Stable dedup key for trade rows.
    signalId+trailStyle is preferred (new 3-style data). Falls back to ticket.
    """
    if "signalId" in df.columns and "trailStyle" in df.columns:
        sig = df["signalId"].astype(str).fillna("")
        sty = df["trailStyle"].astype(str).fillna("")
        has_sig = (sig != "") & (sig != "nan") & (sig != "None")
        tk = df["ticket"].astype(str) if "ticket" in df.columns else pd.Series("", index=df.index)
        tm = df["entryTime"].astype(str) if "entryTime" in df.columns else pd.Series("", index=df.index)
        fallback = tk + "|" + tm
        return pd.Series(
            [f"{s}|{t}" if h else f for s, t, h, f in zip(sig, sty, has_sig, fallback)],
            index=df.index,
        )
    tk = df["ticket"].astype(str) if "ticket" in df.columns else pd.Series("", index=df.index)
    tm = df["entryTime"].astype(str) if "entryTime" in df.columns else pd.Series("", index=df.index)
    return tk + "|" + tm


def _month_key(ts) -> str:
    """Return 'MM.YYYY' partition key from a timestamp (NaT-safe → 'unknown')."""
    if pd.isna(ts):
        return "unknown"
    return f"{ts.month:02d}.{ts.year}"


# ─── Core sync logic ─────────────────────────────────────────────

def _sync_kind(
    kind: str,
    time_col: str,
    dedup_fn,
    filter_symbol: str | None = None,
    dry_run: bool = False,
) -> int:
    """Sync one CSV family (VP_Funnel_* or VP_Trades_*) from MT5_FILES_DIR.

    Returns number of NEW rows written (or that would be written in dry_run).
    """
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    pattern = str(MT5_FILES_DIR / f"{kind}_*.csv")
    src_files = sorted(glob.glob(pattern))
    if not src_files:
        print(f"  [SKIP] No {kind}_*.csv found in {MT5_FILES_DIR}")
        return 0

    new_rows = 0
    for fpath in src_files:
        # Extract symbol from filename: VP_Funnel_XAUUSDm.csv → XAUUSDm
        sym = Path(fpath).stem.replace(f"{kind}_", "")
        if filter_symbol and sym != filter_symbol:
            continue

        # Load raw MT5 CSV (UTF-16 as written by the EA)
        try:
            raw = pd.read_csv(
                fpath, encoding="utf-16", low_memory=False,
                dtype={"signalId": str},
            )
        except Exception as e:
            print(f"  [ERR] {Path(fpath).name}: {e}")
            continue

        if raw.empty:
            continue

        raw = raw.copy()
        raw["symbol"] = sym

        # Parse time for month-key partitioning
        if time_col in raw.columns:
            tparsed = pd.to_datetime(
                raw[time_col], format="%Y.%m.%d %H:%M:%S", errors="coerce",
            )
        else:
            tparsed = pd.Series([pd.NaT] * len(raw), index=raw.index)

        raw["_month"] = tparsed.map(_month_key)

        # Write per-(symbol, month) partition
        for (msym, month), part in raw.groupby(["symbol", "_month"]):
            part = part.drop(columns=["_month"])
            out_path = DATA_DIR / f"{kind}_{msym}_{month}.csv"

            # Load existing partition
            if out_path.exists():
                try:
                    existing = pd.read_csv(
                        out_path, encoding="utf-8", low_memory=False,
                        dtype={"signalId": str},
                    )
                except Exception:
                    existing = pd.DataFrame()
            else:
                existing = pd.DataFrame()

            # Merge + dedup
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
                new_rows += added
                if dry_run:
                    print(f"  [DRY]  {out_path.name}: would add {added} rows "
                          f"(total {len(combined)})")
                else:
                    combined.to_csv(out_path, index=False, encoding="utf-8")
                    print(f"  [SYNC] {out_path.name}: +{added} rows "
                          f"(total {len(combined)})")

    return new_rows


# ─── Public API ──────────────────────────────────────────────────

def sync_data(
    symbol: str | None = None,
    dry_run: bool = False,
) -> dict:
    """Sync fresh MT5 CSVs from MT5_FILES_DIR into the partitioned Data/ store.

    Only new rows (by dedup key) are added; existing rows are skipped.
    Safe to run multiple times (idempotent).

    Parameters
    ----------
    symbol : str | None
        If given, sync only that symbol (e.g. "XAUUSDm"). Default: all.
    dry_run : bool
        If True, print what would be written without writing anything.

    Returns
    -------
    dict with keys 'funnel_rows' and 'trades_rows' (counts of new rows).
    """
    tag = f" ({symbol})" if symbol else ""
    mode = " [DRY RUN]" if dry_run else ""
    print("=" * 60)
    print(f"SYNC DATA{mode}{tag}")
    print(f"  Source : {MT5_FILES_DIR}")
    print(f"  Store  : {DATA_DIR}")
    print("=" * 60)

    nf = _sync_kind("VP_Funnel", "timestamp", _dedup_key_funnel, symbol, dry_run)
    nt = _sync_kind("VP_Trades", "entryTime", _dedup_key_trades, symbol, dry_run)

    print(f"\n  {'Would add' if dry_run else 'Added'}: "
          f"+{nf} funnel rows, +{nt} trade rows")
    if nf == 0 and nt == 0:
        print("  (nothing new — Data store already up to date)")
    return {"funnel_rows": nf, "trades_rows": nt}


def list_store() -> None:
    """Print a summary of what is currently in the Data/ store."""
    if not DATA_DIR.exists():
        print(f"Data store not found: {DATA_DIR}")
        print("Run data_collect.py to create it.")
        return

    funnel_files = sorted(DATA_DIR.glob("VP_Funnel_*.csv"))
    trades_files = sorted(DATA_DIR.glob("VP_Trades_*.csv"))

    if not funnel_files and not trades_files:
        print(f"Data store is empty: {DATA_DIR}")
        return

    print(f"\nData store: {DATA_DIR}")
    print(f"  {len(funnel_files)} funnel partitions, {len(trades_files)} trade partitions")

    # Collect months per symbol
    from collections import defaultdict
    sym_months: dict[str, set] = defaultdict(set)
    for f in funnel_files:
        rest = f.stem.replace("VP_Funnel_", "")
        if "_" in rest:
            sym, month = rest.rsplit("_", 1)
            sym_months[sym].add(month)

    print("\n  Symbol          Months")
    print("  " + "-" * 40)
    for sym in sorted(sym_months):
        months = sorted(sym_months[sym])
        print(f"  {sym:<16} {', '.join(months)}")


# ─── CLI ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Sync MT5 backtest CSVs into the partitioned Data/ store.",
    )
    parser.add_argument(
        "--symbol", default=None,
        help="Sync only this symbol (e.g. XAUUSDm). Default: all.",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be written without writing anything.",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="List current Data/ store contents and exit.",
    )
    args = parser.parse_args()

    if args.list:
        list_store()
        sys.exit(0)

    sync_data(symbol=args.symbol, dry_run=args.dry_run)
