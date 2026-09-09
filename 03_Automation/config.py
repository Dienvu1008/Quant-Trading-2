"""
config.py — Central configuration for the VP EA automation pipeline.

All paths, parameters, and settings in one place.
"""
from pathlib import Path

# ─── MT5 Terminal Paths ───────────────────────────────────────────────────────
MT5_PROGRAM_DIR = Path(r"C:\Program Files\MetaTrader 5")
MT5_TERMINAL_EXE = MT5_PROGRAM_DIR / "terminal64.exe"
MT5_METAEDITOR_EXE = MT5_PROGRAM_DIR / "MetaEditor64.exe"

# ─── Terminal Data Paths ──────────────────────────────────────────────────────
MT5_DATA_DIR = Path(r"C:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075")
MT5_MQL5_DIR = MT5_DATA_DIR / "MQL5"

# ─── Project Paths ────────────────────────────────────────────────────────────
PROJECT_ROOT = MT5_MQL5_DIR / "Experts" / "My own robots" / "Quant Trading 2"
EA_DIR       = PROJECT_ROOT / "01_EA_VP"
RESEARCH_DIR = PROJECT_ROOT / "02_QuantResearch_VPEA"

# ─── Key Files ────────────────────────────────────────────────────────────────
MAIN_EA_SOURCE   = EA_DIR / "Main_VP_EA.mq5"
EDGE_GUARD_CONFIG = EA_DIR / "Config" / "VPEdgeGuardConfig.mqh"
RUN_ALL_SCRIPT   = RESEARCH_DIR / "run_all.py"

# ─── MT5 Common Files (where EA writes CSVs) ─────────────────────────────────
MT5_COMMON_FILES = Path(r"C:\Users\Dienv\AppData\Roaming\MetaQuotes\Terminal\Common\Files")
MT5_LOCAL_FILES  = MT5_DATA_DIR / "MQL5" / "Files"

# ─── Backtest Configuration ──────────────────────────────────────────────────
BACKTEST_CONFIG = {
    "symbol":    "EURUSDm",      # Chart symbol for the tester
    "period":    "H1",           # Timeframe
    "from_date": "2026.05.01",   # Start date
    "to_date":   "2026.08.01",   # End date
    "model":     1,              # 0=EveryTick, 1=1MinOHLC, 2=OpenPrice
    "deposit":   10000,
    "leverage":  100,
    "optimization": 0,           # 0=Single run
    "ea_input_file": "Main_VP_EA_DataCollect.set",  # .set file for data collection mode
}

# ─── Report Output ────────────────────────────────────────────────────────────
DATA_DIR_PROJECT      = PROJECT_ROOT / "03_Automation" / "data"
BACKTEST_REPORT_DIR   = DATA_DIR_PROJECT / "backtest_reports"
MAX_ITERATIONS        = 1      # Max backtest→analyze→compile loops
MIN_TRADES_FOR_ANALYSIS = 50   # Skip analysis if fewer trades
COMPILE_TIMEOUT_SEC   = 120    # Max time to wait for compilation
BACKTEST_TIMEOUT_SEC  = 3600   # Max time for backtest (1 hour)
ANALYSIS_TIMEOUT_SEC  = 1800   # Max time for run_all.py (30 min)
