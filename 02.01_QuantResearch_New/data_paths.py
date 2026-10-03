"""
data_paths.py — Shared path constants for the VP Analysis New research pipeline.

Split out so both data_collect.py (writer) and data_loader.py (reader) can
import the same locations without a circular dependency.

Data store layout:
    Data/VP_Funnel_{SYMBOL}_{MM.YYYY}.csv   — per-signal funnel state
    Data/VP_Trades_{SYMBOL}_{MM.YYYY}.csv   — closed trade outcomes
"""
import os
from pathlib import Path

_HERE_DIR     = Path(__file__).parent
_LOCAL_FILES  = Path(r"C:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files")
_COMMON_FILES = Path(r"C:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal\Common\Files")

# ─── Partitioned data store (the source for analysis) ────────────
# Per-(symbol, month) CSV files: Data/VP_Funnel_XAUUSD_01.2026.csv etc.
DATA_DIR: Path = _HERE_DIR / "Data"

# ─── Output directory (pipeline results per experiment) ──────────
OUTPUT_DIR: Path = _HERE_DIR / "output"


def _pick_mt5_dir() -> Path:
    """Pick whichever MT5 output directory holds the larger VP_Funnel dataset."""
    def _size(p: Path) -> int:
        return sum(f.stat().st_size for f in p.glob("VP_Funnel_*.csv")) \
               if p.exists() else 0
    return _COMMON_FILES if _size(_COMMON_FILES) >= _size(_LOCAL_FILES) else _LOCAL_FILES


# Raw MT5 output directory (where the EA writes fresh CSVs each backtest).
# Override with environment variable MT5_FILES_DIR if needed.
MT5_FILES_DIR: Path = (
    Path(os.environ["MT5_FILES_DIR"])
    if os.environ.get("MT5_FILES_DIR")
    else _pick_mt5_dir()
)
