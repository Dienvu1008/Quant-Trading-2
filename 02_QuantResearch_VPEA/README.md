# 02_QuantResearch_VPEA — VP/Auction Research Pipeline

Phân tích dữ liệu thu thập từ `01_EA_VP` để tìm edge per-symbol.

## Data Sources

- `VP_Funnel_{symbol}.csv` — Every fired trigger with full VP/Auction state (80+ features)
- `VP_Trades_{symbol}.csv` — Every closed trade with entry state + exit state + PnL

## Phases

| Phase | File | Purpose | Inherited from |
|---|---|---|---|
| 01 | `01_vp_edge_discovery.py` | Walk-forward threshold discovery per VP/Auction feature | Phase 01 |
| 02 | `02_vp_regime_analysis.py` | Regime × Setup interaction, block rules | Phase 13 |
| 03 | `03_vp_entry_quality.py` | Composite entry quality gate (logistic discriminator) | Phase 14 |
| 04 | `04_vp_exit_profiling.py` | TP/SL exit profiling + SL risk thresholds | Phase 19 |
| 05 | `05_vp_behavior_profiling.py` | Per-symbol VP behavior classification + archetype validation |
| 99 | `99_generate_config.py` | Generate optimized configs back into EA |

## Usage

```bash
cd 02_QuantResearch_VPEA
python run_all.py              # Run all phases sequentially
python 01_vp_edge_discovery.py # Run single phase
```

## Key Differences from 02_QuantResearch

1. **VP-only features**: No latentRaw, structure.*, smartMoney.*, flow.* — only vp* and auct*
2. **Per-symbol profiling**: Focus on how VP/Auction behaves differently per symbol
3. **Output targets EA VP**: Generate thresholds for `01_EA_VP` triggers (not V2 EdgeGuard)
4. **Simpler merge**: Uses VP_Funnel (fired only) + VP_Trades (outcome) — no executed/rejected split
