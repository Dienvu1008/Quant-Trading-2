"""
run_pipeline.py — Manual trigger entry point for VP EA pipeline.

Run this script to kick off the full optimization pipeline:
  Compile → Backtest → Analyze → Generate VPEdgeGuard → Recompile (loop)

Usage:
    python run_pipeline.py                    # Full pipeline (1 loop)
    python run_pipeline.py --loop 3           # Up to 3 iterations
    python run_pipeline.py --skip-backtest    # Skip backtest, use existing data
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from graph import main

if __name__ == "__main__":
    main()
