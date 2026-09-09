# 01_EA_VP — Volume Profile Auction EA
## Architecture Design Document

---

## 1. Purpose

Standalone EA sử dụng **Volume Profile + Auction Market Theory** thuần túy.
- Research & validate VP/Auction edge per-symbol
- Thu thập labeled dataset cho SHAP/ML optimization
- Tách biệt hoàn toàn khỏi 01_EA_V2 (no shared mutable state)
- Có VP Behavior Profiler để adaptive per-symbol

---

## 2. Folder Structure

```
01_EA_VP/
├── Main_VP_EA.mq5                    # Entry point
├── DESIGN.md                         # This document
│
├── Config/                           # EA-specific configuration
│   ├── GlobalParameters.mqh          # Trimmed: only VP-relevant structs/enums
│   ├── VPConfig.mqh                  # VP-specific config (lot mode, risk%, symbols)
│   └── Logger.mqh                    # Copy from V2 (lightweight)
│
├── 01_DataAcquisition/               # COPY from V2 (read-only, no VP dependency)
│   ├── RatesCache.mqh                # M1/M5/H1/H4/D1 bar cache
│   ├── SessionData.mqh              # Session time detection
│   ├── SpreadMonitor.mqh            # Spread tracking
│   ├── EconomicCalendar.mqh         # News event detection (avoid trading near news)
│   └── SymbolMetaData.mqh           # Symbol properties
│
├── 02_VolumeProfile/                 # MOVE from V2/VolumeProfile (becomes owned)
│   ├── AuctionEnums.mqh
│   ├── VolumeProfileEngine.mqh
│   ├── AuctionIntelligence.mqh
│   ├── AuctionTrailingStop.mqh
│   └── AuctionThesisManager.mqh
│
├── 03_VPBehaviorProfiler/            # NEW — per-symbol VP behavior adaptation
│   └── VPBehaviorProfiler.mqh       # Rolling stats, percentile, archetype
│
├── 04_SetupTriggers/                 # MOVE from V2/10.2_VPBasedSetupTrigger
│   ├── SimpleBreakoutTrigger.mqh
│   ├── SimpleBreakoutRetestTrigger.mqh
│   ├── SimplePullbackTrigger.mqh
│   ├── SimpleTrendContinuationTrigger.mqh
│   ├── SimpleSweepReversalTrigger.mqh
│   ├── SimpleMeanReversionTrigger.mqh
│   ├── SimpleNakedPOCTrigger.mqh
│   └── SimpleAnchoredPullbackTrigger.mqh
│
├── 05_Risk/                          # Simplified risk management
│   ├── PositionSizing.mqh           # Fixed lot or risk-based
│   └── TradeManager.mqh             # Order execution + trailing (Auction-based)
│
├── 06_Feedback/                      # Data collection & attribution
│   ├── VPFunnelLogger.mqh           # Setup funnel CSV (VP-specific features)
│   ├── VPFailureAttribution.mqh     # Trade close analysis
│   └── VPTradeRecord.mqh            # Trade record struct
│
├── SymbolManager/                    # Multi-symbol orchestration
│   ├── VPSymbolManager.mqh          # Manages N symbols, routes OnTick/OnTrade
│   └── VPTradingPipeline.mqh        # Per-symbol pipeline (lightweight)
│
└── Utils/                            # Shared utilities
    └── MathUtils.mqh                 # Clamp01, etc.
```

---

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│ Main_VP_EA.mq5                                                │
│   OnInit() → VPSymbolManager.Initialize(symbols[])            │
│   OnTick() → VPSymbolManager.OnTick()                         │
│   OnTrade() → VPSymbolManager.OnTradeTransaction()            │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ VPSymbolManager                                               │
│   For each symbol → VPTradingPipeline[i].Update()             │
│   Routes trade events to correct pipeline                     │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼ (per symbol)
┌──────────────────────────────────────────────────────────────┐
│ VPTradingPipeline (lightweight — ~300 lines)                  │
│                                                               │
│ Layer 1: Data Acquisition                                     │
│   RatesCache → SessionData → SpreadMonitor → SymbolMetaData  │
│   EconomicCalendar (news filter: block before/after events)   │
│                                                               │
│ Layer 2: Volume Profile + Auction                             │
│   VolumeProfileEngine → AuctionIntelligence                  │
│                                                               │
│ Layer 3: VP Behavior Profiler (NEW)                           │
│   Track rolling stats → classify symbol archetype             │
│   Expose: IsAboveNormal(), GetPercentile(), GetArchetype()    │
│                                                               │
│ Layer 4: Setup Triggers (8 triggers, first-match)             │
│   Breakout → BreakoutRetest → Pullback → TrendCont →         │
│   SweepReversal → MeanReversion → NakedPOC → AnchoredPB     │
│                                                               │
│ Layer 5: Risk & Execution                                     │
│   PositionSizing → TradeManager (open/trail/close)            │
│                                                               │
│ Layer 6: Feedback                                             │
│   VPFunnelLogger (every trigger evaluation)                   │
│   VPFailureAttribution (on trade close)                       │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Key Design Decisions

### 4.1 Isolation from 01_EA_V2
- **COPY** DataAcquisition files (RatesCache, SessionData, SpreadMonitor, SymbolMetaData)
- **MOVE** VolumeProfile/ folder and 10.2_VPBasedSetupTrigger/ to 01_EA_VP
- **COPY & TRIM** Config (only keep VP-relevant structs: SPipelineState trimmed, enums)
- 01_EA_V2 will reference VP via a shared include or have its own copy (decide at implementation)

### 4.2 VP Behavior Profiler
```
Fields tracked (rolling window = 200 H1 bars):
- vpMigrationConfidence: mean, p25, p75
- auctBalanceScore: mean, p25, p75
- auctTradeQuality: mean, p25, p75
- auctContinuationScore: mean, p25, p75
- vpDevPOCDirection: mean absolute
- vpVAOverlapBias: frequency distribution (+1, -1, 0)
- auctRegime: time-in-regime distribution (9 regimes)
- vpThinnessRatio: mean

Derived:
- Symbol archetype: TREND_FRIENDLY, RANGE_BOUND, VOLATILE_SWITCHING, SPREAD_UNSTABLE
- Per-trigger suitability scores (which triggers work best for this symbol)
```

### 4.3 Pipeline State (trimmed)
Only fields needed by VP/Auction + Triggers:
- marketData (bid, ask, atr, spread, rates arrays)
- vp* fields (all — from VolumeProfileEngine)
- auct* fields (all — from AuctionIntelligence)
- primarySetup (SSetupObject)
- winProbability, riskReward
- profiler outputs (archetype, percentiles)

NOT included: structure.*, latentRaw.*, latent.*, smartMoney.*, flow.*, liquidity.*

### 4.4 Trade Management
- Reuse AuctionTrailingStop + AuctionThesisManager from VP_Test_EA pattern
- Simple position tracking (max N positions per symbol)
- On close: log full VP feature vector + outcome → CSV

### 4.5 Funnel Logger (VP-specific)
CSV columns:
```
timestamp, symbol, setupType, direction, regime, regimeConf,
tradeQuality, migrationConf, balanceScore, continuationScore,
reversalRisk, failureScore, vpPOC, vpVAH, vpVAL, vpInsideVA,
vpDevPOCDir, vpOverlapBias, thinnessRatio, thesis,
SL, TP, RR, isFired(bool), blockReason,
profilerArchetype, profilerPercentileMig, profilerPercentileBalance
```

### 4.6 Failure Attribution (VP-specific)
On trade close:
```
ticket, symbol, setupType, profit, profitPips, holdingMinutes,
entryRegime, exitRegime, entryTradeQuality, entryMigConf,
maeATR, mfeATR, thesisAtEntry, exitReason(TP/SL/THESIS/TRAIL),
profilerArchetype
```

---

## 5. Data Flow

```
Market Data → RatesCache → VolumeProfileEngine → AuctionIntelligence
                                                         │
                                                         ▼
                                               VPBehaviorProfiler
                                               (update rolling stats)
                                                         │
                                                         ▼
                                               8 Setup Triggers
                                               (evaluate, first-match)
                                                         │
                                                  ┌──────┴──────┐
                                                  │ No trigger  │ Trigger fired
                                                  │ → log skip  │ → PositionSizing
                                                  └─────────────┘ → TradeManager
                                                                  → VPFunnelLogger
```

---

## 6. Implementation Phases

### Phase 1: Scaffold & Config
- Create folder structure
- Copy/adapt Config (trimmed GlobalParameters, VPConfig)
- Copy DataAcquisition modules (RatesCache, SessionData, SpreadMonitor, SymbolMetaData)
- Copy VolumeProfile modules (VPEngine, AuctionIntelligence, TrailingStop, ThesisManager)
- Move 10.2 triggers to 04_SetupTriggers/

### Phase 2: Core Pipeline
- VPTradingPipeline.mqh (lightweight, ~300 lines)
- VPSymbolManager.mqh (multi-symbol routing)
- Main_VP_EA.mq5 (entry point with inputs)

### Phase 3: VP Behavior Profiler
- VPBehaviorProfiler.mqh (rolling stats, archetype classification)
- Integrate into pipeline (Layer 3)

### Phase 4: Risk & Execution
- PositionSizing.mqh (fixed lot or risk-based)
- TradeManager.mqh (order send, trailing via AuctionTrailingStop)

### Phase 5: Feedback & Logging
- VPFunnelLogger.mqh (CSV logging per trigger evaluation)
- VPFailureAttribution.mqh (per trade close)
- VPTradeRecord.mqh (struct)

### Phase 6: Cleanup V2
- Remove 10.2_VPBasedSetupTrigger from 01_EA_V2 (or mark deprecated)
- Ensure 01_EA_V2 compiles without moved files
- Update 01_EA_V2 VP references if needed

---

## 7. Inputs (Main_VP_EA.mq5)

```mql5
input string InpSymbols = "XAUUSD,EURUSD,GBPUSD,USDJPY,BTCUSD";
input double InpRiskPercent = 0.5;
input double InpFixedLot = 0.0;        // 0 = risk-based
input int    InpMaxPositionsPerSymbol = 2;
input int    InpTrailingStyle = 1;      // 0=Conservative, 1=Expansion
input int    InpProfilerWarmup = 100;   // H1 bars before trading
input bool   InpEnableBreakout = true;
input bool   InpEnableBreakoutRetest = true;
input bool   InpEnablePullback = true;
input bool   InpEnableTrendCont = true;
input bool   InpEnableSweepReversal = true;
input bool   InpEnableMeanReversion = true;
input bool   InpEnableNakedPOC = true;
input bool   InpEnableAnchoredPullback = true;
input bool   InpLogFunnel = true;       // CSV logging
input int    InpMagicNumber = 202607;
input int    InpNewsBlockMinsBefore = 30;  // Block entries X mins before high-impact news
input int    InpNewsBlockMinsAfter = 15;   // Block entries X mins after high-impact news
```

---

## 8. What's NOT in this EA

- No StateCompression (latentRaw, latent)
- No PolicyEngine (alpha, permission, decision)
- No PercentileTracker (replaced by VPBehaviorProfiler)
- No EdgeGuardConfig (no per-symbol thresholds — profiler handles this)
- No AdaptiveController / WalkForwardManager
- No SmartMoney / OrderFlow / LiquidityIntelligence engines
- No BOSEngine / CHOCHEngine / SwingEngine / TrendEngine
- No EventStore
- No PythonBridge

---

## 9. Relationship to 01_EA_V2

After validation:
- VPBehaviorProfiler results can be exported as symbol configs
- Feed optimal per-symbol VP thresholds back into 01_EA_V2's EdgeGuardConfig
- 01_EA_V2 retains VP as optional overlay with validated thresholds
- Both EAs can run simultaneously on different account/chart
