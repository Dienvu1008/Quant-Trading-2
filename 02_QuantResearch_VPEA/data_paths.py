"""
data_paths.py — Shared path constants for the VP EA research pipeline.

Split out so both data_collect.py (writer) and data_loader.py (reader) can
import the same locations without a circular dependency.
"""
import os
from pathlib import Path

_HERE_DIR     = Path(__file__).parent
_LOCAL_FILES  = Path(r"C:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files")
_COMMON_FILES = Path(r"C:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal\Common\Files")

# Local partitioned data store (per symbol + month) — the source for analysis.
DATA_DIR = _HERE_DIR / "Data"


def _pick_dir() -> Path:
    """Pick whichever MT5 output dir holds the larger VP_Funnel dataset."""
    def _size(p):
        return sum(f.stat().st_size for f in p.glob("VP_Funnel_*.csv")) if p.exists() else 0
    return _COMMON_FILES if _size(_COMMON_FILES) >= _size(_LOCAL_FILES) else _LOCAL_FILES


# Raw MT5 output directory (where the EA writes fresh CSVs each backtest).
MT5_FILES_DIR = Path(os.environ["MT5_FILES_DIR"]) if os.environ.get("MT5_FILES_DIR") else _pick_dir()
