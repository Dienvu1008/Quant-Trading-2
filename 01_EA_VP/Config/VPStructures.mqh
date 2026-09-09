#ifndef __VP_EA_STRUCTURES_MQH__
#define __VP_EA_STRUCTURES_MQH__

#include "VPEnums.mqh"

// ─── Market Data (shared with DataAcquisition) ───
struct SVPMarketData
{
   string   symbol;
   double   bid;
   double   ask;
   double   pointSize;
   double   tickSize;
   double   tickValue;
   double   spreadPoints;
   double   avgSpreadPoints;
   double   atrProxy;        // ATR in POINTS (atrProxy * pointSize = ATR in PRICE)
   datetime timestamp;
   // Shared rate arrays
   MqlRates h1Rates[];
   MqlRates m5Rates[];
   MqlRates m1Rates[];
   MqlRates h4Rates[];
   MqlRates d1Rates[];
   int      h1Copied;
   int      m5Copied;
   int      m1Copied;
   int      h4Copied;
   int      d1Copied;
   double   dataQualityScore;
   // Shared tick cache — populated by CVPTickCache, read by microstructure engines
   MqlTick  ticks[];
   int      tickCopied;
};

// ─── Setup Object ───
struct SSetupObject
{
   bool        isValid;
   ESetupType  setupType;
   double      entryPrice;
   double      stopLoss;
   double      takeProfit;
   double      riskReward;
   datetime    detectedAt;
};

// ─── News State ───
struct SNewsState
{
   bool     isNearNews;
   int      minutesToNews;
   ENewsImpact nextImpact;
   string   nextEventName;
};

// ─── VP Behavior Profiler Output ───
struct SVPProfilerOutput
{
   EVPSymbolArchetype archetype;
   double  migrationP25;
   double  migrationP75;
   double  migrationMean;
   double  balanceP25;
   double  balanceP75;
   double  balanceMean;
   double  tradeQualityMean;
   double  thinnessRatioMean;
   int     samplesCollected;
   bool    isReady;
};

// NOTE: STrailingContext, STrailingDecision, SThesisOutput are defined in
// 02_VolumeProfile/AuctionTrailingStop.mqh and AuctionThesisManager.mqh
// They are NOT duplicated here to avoid redefinition errors.

// ═══════════════════════════════════════════════════════════════
// BONUS ENGINE OUTPUT STRUCTS (research data collection)
// These sub-structs hold outputs of the BonusEngines. They are written
// by the engines each tick and read by VPFunnelLogger for CSV logging.
// Currently NOT used for execution decisions — but any field can later be
// wired into a gate in VPTradingPipeline.Update() (like EdgeGuard features).
// ═══════════════════════════════════════════════════════════════

// Swing points (populated from CSimpleSwingDetector, read by liquidity/orderflow engines)
struct SVPStructSwing
{
   double   price;
   datetime time;
   int      barIndex;
   bool     isHigh;
};

struct SVPStructureFeatures
{
   double structureBias;              // [0,1] 0=bearish structure, 1=bullish
   SVPStructSwing swingHighs[30];
   SVPStructSwing swingLows[30];
   int      swingHighCount;
   int      swingLowCount;
};

struct SVPMicrostructureFeatures
{
   double spreadScore;                // [0,1] 1=tight/healthy spread
   double tickVelocity;               // [0,1] tick pace vs baseline
   double tickImbalance;              // [0,1] up-tick ratio (0.5=balanced)
   double liquidityVacuumScore;       // [0,1] imminent-move vacuum
   double compressionScore;           // [0,1] coiled-range energy
};

struct SVPFlowFeatures
{
   double deltaProxy;                 // [0,1] buy/sell pressure
   double cvdProxy;                   // [0,1] cumulative volume delta (normalized)
   double absorptionScore;            // [0,1] effort-vs-result absorption
   double exhaustionScore;            // [0,1] climax exhaustion
   double participationScore;         // [0,1] volume participation
   double divergenceScore;            // [0,1] CVD/price divergence strength
   bool   bearishDivergence;
   bool   bullishDivergence;
   double flowIntensityScore;         // [0,1] aggregate flow intensity
   double cvdHistory[30];             // rolling CVD snapshots (CVDProxy → Divergence)
   int    cvdHistCount;
};

struct SVPLiquidityFeatures
{
   double liquidityDensity;           // [0,1] liquidity concentration
   double sweepScore;                 // [0,1] liquidity sweep strength
   double stopClusterScore;           // [0,1] stop cluster proximity
   double equalHighLowScore;          // [0,1] equal highs/lows pool
   double sessionLiquidityScore;      // [0,1] session range liquidity
   double premiumDiscountScore;       // [-1,1] premium(+)/discount(-)
};

struct SVPSmartMoneyFeatures
{
   double orderBlockScore;            // [0,1]
   double fvgScore;                   // [0,1] fair value gap
   double mitigationScore;            // [0,1]
   double breakerBlockScore;          // [0,1]
   double rejectionBlockScore;        // [0,1]
   double zoneQualityScore;           // [0,1] overall zone quality
};

// ═══════════════════════════════════════════════════════════════
// PIPELINE STATE — VP EA
// Contains ALL fields that VP/Auction modules read/write
// ═══════════════════════════════════════════════════════════════
struct SVPPipelineState
{
   // ─── Market Data ───
   SVPMarketData marketData;

   // ─── Session ───
   ESessionType session;

   // ─── News ───
   SNewsState news;

   // ─── Volume Profile fields (written by VolumeProfileEngine) ───
   bool    vpValid;
   double  vpPOC;
   double  vpVAH;
   double  vpVAL;
   bool    vpInsideVA;
   double  vpNearestHVN;
   double  vpNearestLVN;
   double  vpDistToHVN_ATR;
   double  vpDistToLVN_ATR;
   double  vpBestHVN;
   double  vpBestHVNScore;
   double  vpNearestNakedPOC;
   double  vpDistToNakedPOC_ATR;
   double  vpDevPOCDirection;
   double  vpDevPOCSlope;
   double  vpMigrationConfidence;
   int     vpVAOverlapBias;       // +1=bull, -1=bear, 0=neutral
   double  vpThinnessRatio;
   int     vpProfileShape;        // EProfileShape
   double  vpBreakoutPOC;
   double  vpRangePOC;
   double  vpRangeVAH;
   double  vpRangeVAL;
   double  vpPullbackPOC;
   double  vpCompositePOC;
   double  vpCompositeVAH;
   double  vpCompositeVAL;
   bool    vpCompositeInsideVA;
   int     vpCompositePosition;   // +1=above, -1=below, 0=inside
   double  vpDailyPOC;
   bool    vpUpthrustDetected;
   bool    vpSpringDetected;
   double  vpMigrationScore;
   // Additional VP fields referenced by VolumeProfileEngine WriteState
   double  vpPriceVsPOC;
   double  vpPriceVsVA;
   double  vpSessionPOC;
   int     vpMigrationDirRaw;
   double  vpDistToCompositePOC_ATR;
   double  vpNearestHighIntensityHVN;
   double  vpDistToHighIntensityHVN_ATR;
   double  vpVAOverlapRatio;
   double  vpBreakoutVAH;
   double  vpBreakoutVAL;

   // ─── Long-Term VP (H4 60-day) ───
   bool    vpLTValid;
   double  vpLTPOCVelocity;
   double  vpLTPOCAcceleration;
   int     vpLTPOCMigration;
   double  vpLTPOC60d;
   double  vpLTPOC30d;
   double  vpLTPOC10d;
   double  vpLTMajorHVNPrice;
   double  vpLTMajorHVNStrength;
   double  vpLTMajorLVNPrice;
   double  vpLTMajorLVNStrength;
   double  vpLTNearestZonePrice;
   double  vpLTNearestZoneStrength;
   int     vpLTNearestZoneDir;
   double  vpLTAcceptanceAtPrice;
   double  vpLTTransitionScore;     // 0=stable market, 1=full transition (post-trend chaos)
   double  vpLTBalanceStability;    // 1=stable, 0=unstable (inverse of transition)
   double  vpLTTrendDuration;       // estimated trend duration in H4 bars
   double  vpLTTrendExhaustion;     // 0=strong trend, 1=exhausted

   // ─── Auction Intelligence fields ───
   int     auctRegime;            // EAuctionRegime
   double  auctRegimeConfidence;
   int     auctState;             // EAuctionState
   double  auctBalanceScore;
   int     auctProfileShape;
   double  auctProfileShapeConf;
   double  auctMajorHVN;
   double  auctMajorLVN;
   double  auctDistToMajorHVN_ATR;
   double  auctDistToMajorLVN_ATR;
   double  auctVAExpansionRate;
   int     auctValueAreaState;
   double  auctFailureScore;
   double  auctTradeQuality;
   int     auctTradeGrade;
   double  auctTargetPrice;
   int     auctTargetType;
   double  auctTargetConfidence;
   double  auctTargetProbability;
   double  auctAcceptanceScore;
   double  auctContinuationScore;
   double  auctReversalRiskScore;
   double  auctExhaustionScore;
   double  auctProfitZoneScore;
   double  auctExpectedReward;
   double  auctExpectedMoveATR;
   double  auctHVNClusterStrength;
   double  auctLVNClusterStrength;

   // ─── Profiler Output ───
   SVPProfilerOutput profiler;

   // ─── Setup (trigger output) ───
   SSetupObject primarySetup;
   double  winProbability;
   double  edgeGuardMultiplier;

   // ─── Execution ───
   double  approvedLots;
   bool    executionAllowed;
   string  statusMessage;

   // ─── Module tracking ───
   int     executedModules;
   string  lastModule;
   datetime lastUpdateTime;

   // ─── Pending Events (used by AuctionTrailingStop) ───
   int     pendingEventCount;
   int     pendingEventTypes[8];
   double  pendingEventScores[8];
   int     pendingEventDirs[8];

   // ─── Market Structure (SimpleBOS + SimpleCHOCH) ───
   bool    bosConfirmed;
   bool    bosBullish;
   double  bosScore;
   double  bosLevel;
   bool    chochConfirmed;
   bool    chochBullish;
   double  chochScore;
   double  chochLevel;
   int     trendDirection;    // +1=up, -1=down, 0=neutral

   // ─── Bonus Engine outputs (research data collection) ───
   SVPStructureFeatures      structure;
   SVPMicrostructureFeatures microstructure;
   SVPFlowFeatures           flow;
   SVPLiquidityFeatures      liquidity;
   SVPSmartMoneyFeatures     smartMoney;
};

// ─── Reset function ───
void ResetVPPipelineState(SVPPipelineState &state, const string symbol)
{
   ZeroMemory(state);
   state.marketData.symbol = symbol;
   state.vpValid = false;
   state.primarySetup.isValid = false;
   state.primarySetup.setupType = SETUP_NONE;
   state.executionAllowed = true;
   state.edgeGuardMultiplier = 1.0;
   state.statusMessage = "";
   state.profiler.isReady = false;
   state.news.isNearNews = false;
}

// ─── Config ───
struct SVPEAConfig
{
   double  riskPercent;
   double  fixedLot;
   int     maxPositionsPerSymbol;
   int     trailingStyle;
   int     profilerWarmupBars;
   int     newsBlockMinsBefore;
   int     newsBlockMinsAfter;
   int     magicNumber;
   bool    enableBreakout;
   bool    enableBreakoutRetest;
   bool    enablePullback;
   bool    enableTrendCont;
   bool    enableSweepReversal;
   bool    enableMeanReversion;
   bool    enableNakedPOC;
   bool    enableAnchoredPullback;
   bool    logFunnel;
   bool    useEdgeGuards;      // Enable/disable EdgeGuard filtering
   bool    useSizingCalibration; // Use Phase 06 lot multipliers (maxLot mode)
   double  maxLot;               // Max lot when useSizingCalibration=true (0=symbol max)
   // Telegram notifications
   bool    telegramEnabled;
   string  telegramBotToken;
   string  telegramChatId;
   string  telegramPrefix;       // optional label shown in each message
   // Visuals
   bool    showDashboard;        // on-chart info panel
   bool    showOverlay;          // VP levels overlay on price chart
   EVPDataSource vpDataSource;
};

void SetDefaultVPConfig(SVPEAConfig &config)
{
   config.riskPercent = 0.5;
   config.fixedLot = 0.0;
   config.maxPositionsPerSymbol = 2;
   config.trailingStyle = 1;
   config.profilerWarmupBars = 100;
   config.newsBlockMinsBefore = 30;
   config.newsBlockMinsAfter = 15;
   config.magicNumber = VP_EA_MAGIC_NUMBER;
   config.enableBreakout = true;
   config.enableBreakoutRetest = true;
   config.enablePullback = true;
   config.enableTrendCont = true;
   config.enableSweepReversal = true;
   config.enableMeanReversion = true;
   config.enableNakedPOC = true;
   config.enableAnchoredPullback = true;
   config.logFunnel = true;
   config.useEdgeGuards = false;
   config.useSizingCalibration = false;
   config.maxLot = 0.0;
   config.telegramEnabled = false;
   config.telegramBotToken = "";
   config.telegramChatId = "";
   config.telegramPrefix = "";
   config.showDashboard = false;
   config.showOverlay = false;
   config.vpDataSource = VP_SOURCE_M1_BARS;
}

#endif
