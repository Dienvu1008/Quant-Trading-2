#ifndef __VP_EA_TRADING_PIPELINE_MQH__
#define __VP_EA_TRADING_PIPELINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\01_DataAcquisition\RatesCache.mqh"
#include "..\01_DataAcquisition\SessionData.mqh"
#include "..\01_DataAcquisition\SpreadMonitor.mqh"
#include "..\01_DataAcquisition\EconomicCalendar.mqh"
#include "..\01_DataAcquisition\SymbolMetaData.mqh"
#include "..\02_VolumeProfile\VolumeProfileEngine.mqh"
#include "..\02_VolumeProfile\AuctionIntelligence.mqh"
#include "..\02_VolumeProfile\AuctionTrailingStop.mqh"
#include "..\02_VolumeProfile\AuctionThesisManager.mqh"
#include "..\03_VPBehaviorProfiler\VPBehaviorProfiler.mqh"
#include "..\04_MarketStructure\SimpleSwingDetector.mqh"
#include "..\04_MarketStructure\SimpleBOS.mqh"
#include "..\04_MarketStructure\SimpleCHOCH.mqh"
#include "..\04_SetupTriggers\SimpleBreakoutTrigger.mqh"
#include "..\04_SetupTriggers\SimpleBreakoutRetestTrigger.mqh"
#include "..\04_SetupTriggers\SimplePullbackTrigger.mqh"
#include "..\04_SetupTriggers\SimpleTrendContinuationTrigger.mqh"
#include "..\04_SetupTriggers\SimpleSweepReversalTrigger.mqh"
#include "..\04_SetupTriggers\SimpleMeanReversionTrigger.mqh"
#include "..\04_SetupTriggers\SimpleNakedPOCTrigger.mqh"
#include "..\04_SetupTriggers\SimpleAnchoredPullbackTrigger.mqh"
#include "..\Config\VPEdgeGuardConfig.mqh"
#include "..\05_Risk\PositionSizing.mqh"
#include "..\06_Feedback\VPFunnelLogger.mqh"
#include "..\06_Feedback\VPFailureAttribution.mqh"
#include "..\06_Feedback\VPTradeRecord.mqh"
#include "..\07_Notify\TelegramNotifier.mqh"
#include "..\08_Visual\VPChartOverlay.mqh"
#include "..\08_Visual\VPDashboard.mqh"
// ─── Bonus Engines (research data collection) ───
#include "..\01_DataAcquisition\TickCache.mqh"
#include "..\BonusEngines\MicroStructure\SpreadEngine.mqh"
#include "..\BonusEngines\MicroStructure\TickImbalanceEngine.mqh"
#include "..\BonusEngines\MicroStructure\TickVelocityEngine.mqh"
#include "..\BonusEngines\MicroStructure\CompressionEngine.mqh"
#include "..\BonusEngines\MicroStructure\LiquidityVacuumEngine.mqh"
#include "..\BonusEngines\OrderFlow\CVDProxyEngine.mqh"
#include "..\BonusEngines\OrderFlow\DeltaProxyEngine.mqh"
#include "..\BonusEngines\OrderFlow\ParticipationEngine.mqh"
#include "..\BonusEngines\OrderFlow\AbsorptionEngine.mqh"
#include "..\BonusEngines\OrderFlow\DivergenceEngine.mqh"
#include "..\BonusEngines\OrderFlow\ExhaustionEngine.mqh"
#include "..\BonusEngines\OrderFlow\FlowIntensityScore.mqh"
#include "..\BonusEngines\LiquidityIntelligence\LiquidityEngine.mqh"
#include "..\BonusEngines\LiquidityIntelligence\EqualHighLowDetector.mqh"
#include "..\BonusEngines\LiquidityIntelligence\PremiumDiscountEngine.mqh"
#include "..\BonusEngines\LiquidityIntelligence\StopClusterDetector.mqh"
#include "..\BonusEngines\LiquidityIntelligence\SessionLiquidityDetector.mqh"
#include "..\BonusEngines\LiquidityIntelligence\SweepEngine.mqh"
#include "..\BonusEngines\SmartMoney\ZoneLifecycleManager.mqh"
#include "..\BonusEngines\SmartMoney\FVG_Engine.mqh"
#include "..\BonusEngines\SmartMoney\OrderBlockEngine.mqh"
#include "..\BonusEngines\SmartMoney\RejectionBlockEngine.mqh"

// ─── Position tracking (captures full VP/Auction state at entry) ───
struct SVPPosition
{
   ulong    ticket;
   string   signalId;        // shared by all fan-out positions from the SAME signal
   bool     isBuy;
   double   entryPrice;
   ESetupType setupType;
   datetime entryTime;
   double   thesis;
   double   riskReward;
   int      trailingStyle;   // ETrailingStyle applied to THIS position (-1/0/1)
   // VP Core at entry
   double   vpPOC, vpVAH, vpVAL;
   bool     vpInsideVA;
   double   vpDistHVN, vpDistLVN;
   double   vpBestHVN, vpThinnessRatio;
   int      vpOverlapBias;
   double   vpMigrationConf, vpDevPOCDir;
   int      vpProfileShape;
   bool     vpUpthrust, vpSpring;
   int      vpCompPosition;
   double   vpBreakoutPOC;
   // Auction at entry
   int      auctRegime;
   double   auctRegimeConf;
   double   auctTradeQuality;
   int      auctTradeGrade;
   double   auctBalance, auctContinuation, auctReversalRisk;
   double   auctExhaustion, auctFailure, auctVAExpRate;
   double   auctTargetPrice, auctTargetConf, auctExpReward;
   // Long-Term at entry
   bool     ltValid;
   int      ltPOCMigration;
   double   ltNearestZoneStrength;
   // Profiler at entry
   EVPSymbolArchetype archetype;
   int      profilerSamples;
   // MAE/MFE tracking — updated every tick while position is open
   double   worstPrice;   // lowest bid seen (buy) / highest ask seen (sell) → MAE
   double   bestPrice;    // highest bid seen (buy) / lowest ask seen (sell)  → MFE
   double   atrAtEntry;   // atrProxy snapshot at entry — used to normalise MAE/MFE
   // Staleness counter: incremented each tick that PositionSelectByTicket fails.
   // Entry is only evicted from m_positions[] once this reaches the eviction
   // threshold, giving OnTradeClosed() time to run first and capture signalId.
   int      staleTicks;
};

// Raised from 64: DataCollect fires 3 positions per signal with no position cap.
// 2000 covers the realistic peak of simultaneous open positions across all symbols
// in a DataCollect backtest (~667 signals open at once × 3 styles). The array is
// static so trades beyond this still close correctly via the fallback path in
// OnTradeClosed, but they will lack signalId. Increase further if diagnostics show
// a large fraction of trades falling through to the untracked branch.
#define VP_MAX_POSITIONS 2000
// How many consecutive ticks a position can fail PositionSelectByTicket before
// ManagePositions evicts it as orphaned. This must be large enough that
// OnTradeClosed() (triggered by OnTradeTransaction) has time to run first and
// copy signalId into the trade record. In both live and backtests, OnTradeTransaction
// fires in the same tick or the very next tick, so 5 is a safe margin.
#define VP_STALE_EVICT_TICKS 5

class CVPTradingPipeline
{
private:
   string         m_symbol;
   SVPEAConfig    m_config;
   SVPPipelineState m_state;

   // Modules
   CVPRatesCache          m_ratesCache;
   CVPSessionData         m_sessionData;
   CVPSpreadMonitor       m_spreadMonitor;
   CVPEconomicCalendar    m_economicCalendar;
   CVPSymbolMetaData      m_symbolMetaData;
   CVolumeProfileEngine   m_vpEngine;
   CAuctionIntelligence   m_auctionIntel;
   CVPBehaviorProfiler    m_profiler;
   CSimpleSwingDetector   m_swingDetector;
   CSimpleBOS             m_bos;
   CSimpleCHOCH           m_choch;
   // One trailing engine per style so the DataCollect fan-out keeps independent
   // trailing state (smoothing, last-issued stop, throttle) per style instead of
   // clobbering a single shared engine. Index: 0=Conservative, 1=Expansion.
   CAuctionTrailingStopEngine m_trailing[2];
   CAuctionThesisManager  m_thesis;

   // Map ETrailingStyle (0 conservative, 1 expansion) to the engine index. Style
   // -1 (disabled) never reaches an engine.
   CAuctionTrailingStopEngine* TrailEngine(int style)
   {
      int idx = (style == (int)TRAIL_STYLE_EXPANSION) ? 1 : 0;
      return GetPointer(m_trailing[idx]);
   }

   // Triggers
   CSimpleBreakoutTrigger          m_trigBreakout;
   CSimpleBreakoutRetestTrigger    m_trigRetest;
   CSimplePullbackTrigger          m_trigPullback;
   CSimpleTrendContinuationTrigger m_trigTrendCont;
   CSimpleSweepReversalTrigger     m_trigSweep;
   CSimpleMeanReversionTrigger     m_trigMeanRev;
   CSimpleNakedPOCTrigger          m_trigNakedPOC;
   CSimpleAnchoredPullbackTrigger  m_trigAnchoredPB;

   // Feedback
   CVPFunnelLogger        m_funnelLogger;
   CVPFailureAttribution  m_failureAttrib;
   CVPTelegramNotifier    m_telegram;
   CVPChartOverlay        m_overlay;
   CVPDashboard           m_dashboard;

   // ─── Bonus Engines (research data collection) ───
   CVPTickCache               m_tickCache;
   CSpreadEngine              m_engSpread;
   CTickImbalanceEngine       m_engTickImb;
   CTickVelocityEngine        m_engTickVel;
   CCompressionEngine         m_engCompression;
   CLiquidityVacuumEngine     m_engLiqVacuum;
   CCVDProxyEngine            m_engCVD;
   CDeltaProxyEngine          m_engDelta;
   CParticipationEngine       m_engParticipation;
   CAbsorptionEngine          m_engAbsorption;
   CDivergenceEngine          m_engDivergence;
   CExhaustionEngine          m_engExhaustion;
   CFlowIntensityScore        m_engFlowIntensity;
   CLiquidityEngine           m_engLiquidity;
   CEqualHighLowDetector      m_engEqualHL;
   CPremiumDiscountEngine     m_engPremDisc;
   CStopClusterDetector       m_engStopCluster;
   CSessionLiquidityDetector  m_engSessionLiq;
   CSweepEngine               m_engSweep;
   CZoneLifecycleManager      m_engZoneLifecycle;
   CFVG_Engine                m_engFVG;
   COrderBlockEngine          m_engOrderBlock;
   CRejectionBlockEngine      m_engRejectionBlock;

   // Position tracking
   SVPPosition m_positions[VP_MAX_POSITIONS];
   int         m_posCount;

   void SampleMarketData(void)
   {
      m_state.marketData.symbol = m_symbol;
      m_state.marketData.bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      m_state.marketData.ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      m_state.marketData.pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_state.marketData.tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      m_state.marketData.tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      m_state.marketData.spreadPoints = (m_state.marketData.ask - m_state.marketData.bid) / MathMax(m_state.marketData.pointSize, 1e-7);
      m_state.marketData.timestamp = TimeCurrent();

      MqlRates atrRates[];
      int n = CopyRates(m_symbol, PERIOD_H1, 1, 14, atrRates);
      if (n >= 3)
      {
         double sum = 0;
         for (int i = 0; i < n; i++) sum += (atrRates[i].high - atrRates[i].low);
         m_state.marketData.atrProxy = (sum / n) / MathMax(m_state.marketData.pointSize, 1e-7);
      }
      else
         m_state.marketData.atrProxy = m_state.marketData.bid * 0.005 / MathMax(m_state.marketData.pointSize, 1e-7);
   }

   int CountMyPositions(void)
   {
      int count = 0;
      for (int i = PositionsTotal() - 1; i >= 0; i--)
         if (PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_config.magicNumber)
            count++;
      return count;
   }

   // ─── Populate state.structure from swing detector + run bonus engines ───
   // These engines only WRITE research features into m_state (read by the
   // funnel logger). They do NOT influence trigger/execution decisions.
   void RunBonusEngines(void)
   {
      // Mirror swing points into state.structure for engines that read them
      int hc = m_swingDetector.HighCount();
      int lc = m_swingDetector.LowCount();
      if (hc > 30) hc = 30;
      if (lc > 30) lc = 30;
      m_state.structure.swingHighCount = hc;
      m_state.structure.swingLowCount = lc;
      for (int i = 0; i < hc; i++)
      {
         SVPSwingPoint sp = m_swingDetector.GetSwingHigh(i);
         m_state.structure.swingHighs[i].price = sp.price;
         m_state.structure.swingHighs[i].time = sp.time;
         m_state.structure.swingHighs[i].barIndex = sp.barIndex;
         m_state.structure.swingHighs[i].isHigh = true;
      }
      for (int i = 0; i < lc; i++)
      {
         SVPSwingPoint sp = m_swingDetector.GetSwingLow(i);
         m_state.structure.swingLows[i].price = sp.price;
         m_state.structure.swingLows[i].time = sp.time;
         m_state.structure.swingLows[i].barIndex = sp.barIndex;
         m_state.structure.swingLows[i].isHigh = false;
      }
      // structureBias: 1=bullish, 0=bearish, 0.5=neutral (from trend direction)
      m_state.structure.structureBias =
         (m_state.trendDirection > 0) ? 1.0 :
         (m_state.trendDirection < 0) ? 0.0 : 0.5;

      // Tick cache (feeds tick-based microstructure engines)
      m_tickCache.Execute(m_state);

      // Microstructure
      m_engSpread.Execute(m_state);
      m_engTickImb.Execute(m_state);
      m_engTickVel.Execute(m_state);
      m_engCompression.Execute(m_state);
      m_engLiqVacuum.Execute(m_state);

      // Order flow (CVD before Divergence; Participation+Absorption+Delta before FlowIntensity)
      m_engCVD.Execute(m_state);
      m_engDelta.Execute(m_state);
      m_engParticipation.Execute(m_state);
      m_engAbsorption.Execute(m_state);
      m_engDivergence.Execute(m_state);
      m_engExhaustion.Execute(m_state);
      m_engFlowIntensity.Execute(m_state);

      // Liquidity (EqualHL + PremiumDiscount + Compression/Vacuum feed Sweep, so Sweep last)
      m_engLiquidity.Execute(m_state);
      m_engEqualHL.Execute(m_state);
      m_engPremDisc.Execute(m_state);
      m_engStopCluster.Execute(m_state);
      m_engSessionLiq.Execute(m_state);
      m_engSweep.Execute(m_state);

      // Smart money (ZoneLifecycle before RejectionBlock)
      m_engZoneLifecycle.Execute(m_state);
      m_engFVG.Execute(m_state);
      m_engOrderBlock.Execute(m_state);
      m_engRejectionBlock.Execute(m_state);
   }

   // Build a signal id shared by all positions of one signal:
   //   <symbol>_<YYYYMMDDHHMMSS>_<setupTypeInt>
   // The 3 DataCollect fan-out positions fire on the same tick, so they share the
   // same TimeCurrent() and thus the same id; the funnel row logs the same id.
   string MakeSignalId(ESetupType setupType)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      string ts = StringFormat("%04d%02d%02d%02d%02d%02d",
                               dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
      return m_symbol + "_" + ts + "_" + IntegerToString((int)setupType);
   }

   // trailStyle: ETrailingStyle for this position. In DataCollect fan-out this
   // is one of -1/0/1; in Live it is m_config.trailingStyle.
   // signalId: shared identifier for all positions fired from the same signal,
   // so the research pipeline can join one funnel row to its (up to 3) trades.
   ulong ExecuteSetup(int trailStyle, const string signalId)
   {
      if (!m_state.primarySetup.isValid) return 0;
      // DataCollect fires up to 3 positions per signal (one per trailing style),
      // so the per-symbol cap is bypassed in that mode; Live still respects it.
      if (m_config.presetMode != RUN_MODE_DATACOLLECT
          && CountMyPositions() >= m_config.maxPositionsPerSymbol)
         return 0;

      // Check if symbol allows new positions
      ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
      if (tradeMode != SYMBOL_TRADE_MODE_FULL)
         return 0;

      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      bool isBuy = (m_state.primarySetup.stopLoss < m_state.primarySetup.entryPrice);

      double slDist = MathAbs(m_state.primarySetup.entryPrice - m_state.primarySetup.stopLoss);
      double tpDist = MathAbs(m_state.primarySetup.takeProfit - m_state.primarySetup.entryPrice);
      m_state.primarySetup.entryPrice = isBuy ? ask : bid;
      m_state.primarySetup.stopLoss = isBuy ? m_state.primarySetup.entryPrice - slDist : m_state.primarySetup.entryPrice + slDist;
      m_state.primarySetup.takeProfit = isBuy ? m_state.primarySetup.entryPrice + tpDist : m_state.primarySetup.entryPrice - tpDist;

      double slDistPrice = MathAbs(m_state.primarySetup.entryPrice - m_state.primarySetup.stopLoss);

      double lots;
      if (m_config.useSizingCalibration)
      {
         // MaxLot mode: look up Phase 06 calibration multiplier here (VPEdgeGuardConfig is in scope)
         string setupName = SetupTypeToString(m_state.primarySetup.setupType);
         double calMult = VPGetLotMultiplier(m_symbol, setupName);
         lots = CVPPositionSizing::ComputeLotsMaxMode(m_symbol,
                                                      m_config.maxLot,
                                                      calMult,
                                                      m_state.edgeGuardMultiplier);
      }
      else
      {
         // Standard mode: risk-percent or fixed lot
         lots = CVPPositionSizing::ComputeLots(m_symbol, slDistPrice,
                                               m_config.riskPercent, m_config.fixedLot);
         // Apply EdgeGuard SL risk multiplier (reduces lot when SL risk is high)
         if (m_state.edgeGuardMultiplier < 1.0)
            lots *= m_state.edgeGuardMultiplier;
      }
      if (lots <= 0) return 0;

      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_state.primarySetup.stopLoss = NormalizeDouble(m_state.primarySetup.stopLoss, digits);
      m_state.primarySetup.takeProfit = NormalizeDouble(m_state.primarySetup.takeProfit, digits);

      MqlTradeRequest req; MqlTradeResult res;
      ZeroMemory(req); ZeroMemory(res);
      req.action = TRADE_ACTION_DEAL;
      req.symbol = m_symbol;
      req.volume = lots;
      req.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      req.price = isBuy ? ask : bid;
      req.sl = m_state.primarySetup.stopLoss;
      req.tp = m_state.primarySetup.takeProfit;
      req.deviation = 30;
      req.magic = m_config.magicNumber;
      // Encode trailing style into the comment (VP_<setup>_T<style>) so the close
      // handler can recover it even if the position is no longer tracked in RAM.
      req.comment = "VP_" + SetupTypeToString(m_state.primarySetup.setupType)
                    + "_T" + IntegerToString(trailStyle);
      req.type_filling = ORDER_FILLING_IOC;

      if (!OrderSend(req, res) || res.retcode != 10009)
      {
         PrintFormat("[VP_EA][%s] ORDER FAILED: %d %s", m_symbol, res.retcode, SetupTypeToString(m_state.primarySetup.setupType));
         return 0;
      }

      PrintFormat("[VP_EA][%s] OPENED: %s %s %.2f @ %.5f SL=%.5f TP=%.5f RR=%.1f",
         m_symbol, SetupTypeToString(m_state.primarySetup.setupType), isBuy?"BUY":"SELL",
         lots, req.price, m_state.primarySetup.stopLoss, m_state.primarySetup.takeProfit, m_state.primarySetup.riskReward);

      // Telegram: order opened
      m_telegram.NotifyOpen(m_symbol, res.order, isBuy, lots,
                            SetupTypeToString(m_state.primarySetup.setupType),
                            req.price, m_state.primarySetup.stopLoss,
                            m_state.primarySetup.takeProfit, m_state.primarySetup.riskReward);

      // Track position — use POSITION ticket (not order ticket)
      ulong posTicket = 0;
      if (m_posCount < VP_MAX_POSITIONS)
      {
         // Find the newly opened position for this symbol
         for (int p = PositionsTotal() - 1; p >= 0; p--)
         {
            if (PositionGetSymbol(p) != m_symbol) continue;
            if (PositionGetInteger(POSITION_MAGIC) != m_config.magicNumber) continue;
            ulong t = (ulong)PositionGetInteger(POSITION_TICKET);
            bool known = false;
            for (int k = 0; k < m_posCount; k++)
               if (m_positions[k].ticket == t) { known = true; break; }
            if (!known) { posTicket = t; break; }
         }
         if (posTicket == 0) posTicket = res.order;

         int idx = m_posCount++;
         m_positions[idx].ticket = posTicket;
         m_positions[idx].isBuy = isBuy;
         m_positions[idx].entryPrice = req.price;
         m_positions[idx].setupType = m_state.primarySetup.setupType;
         m_positions[idx].entryTime = TimeCurrent();
         m_positions[idx].signalId = signalId;
         m_positions[idx].thesis = m_state.winProbability;
         m_positions[idx].riskReward = m_state.primarySetup.riskReward;
         m_positions[idx].trailingStyle = trailStyle;
         m_positions[idx].staleTicks = 0;
         // VP Core
         m_positions[idx].vpPOC = m_state.vpPOC;
         m_positions[idx].vpVAH = m_state.vpVAH;
         m_positions[idx].vpVAL = m_state.vpVAL;
         m_positions[idx].vpInsideVA = m_state.vpInsideVA;
         m_positions[idx].vpDistHVN = m_state.vpDistToHVN_ATR;
         m_positions[idx].vpDistLVN = m_state.vpDistToLVN_ATR;
         m_positions[idx].vpBestHVN = m_state.vpBestHVN;
         m_positions[idx].vpThinnessRatio = m_state.vpThinnessRatio;
         m_positions[idx].vpOverlapBias = m_state.vpVAOverlapBias;
         m_positions[idx].vpMigrationConf = m_state.vpMigrationConfidence;
         m_positions[idx].vpDevPOCDir = m_state.vpDevPOCDirection;
         m_positions[idx].vpProfileShape = m_state.vpProfileShape;
         m_positions[idx].vpUpthrust = m_state.vpUpthrustDetected;
         m_positions[idx].vpSpring = m_state.vpSpringDetected;
         m_positions[idx].vpCompPosition = m_state.vpCompositePosition;
         m_positions[idx].vpBreakoutPOC = m_state.vpBreakoutPOC;
         // Auction
         m_positions[idx].auctRegime = m_state.auctRegime;
         m_positions[idx].auctRegimeConf = m_state.auctRegimeConfidence;
         m_positions[idx].auctTradeQuality = m_state.auctTradeQuality;
         m_positions[idx].auctTradeGrade = m_state.auctTradeGrade;
         m_positions[idx].auctBalance = m_state.auctBalanceScore;
         m_positions[idx].auctContinuation = m_state.auctContinuationScore;
         m_positions[idx].auctReversalRisk = m_state.auctReversalRiskScore;
         m_positions[idx].auctExhaustion = m_state.auctExhaustionScore;
         m_positions[idx].auctFailure = m_state.auctFailureScore;
         m_positions[idx].auctVAExpRate = m_state.auctVAExpansionRate;
         m_positions[idx].auctTargetPrice = m_state.auctTargetPrice;
         m_positions[idx].auctTargetConf = m_state.auctTargetConfidence;
         m_positions[idx].auctExpReward = m_state.auctExpectedReward;
         // Long-Term
         m_positions[idx].ltValid = m_state.vpLTValid;
         m_positions[idx].ltPOCMigration = m_state.vpLTPOCMigration;
         m_positions[idx].ltNearestZoneStrength = m_state.vpLTNearestZoneStrength;
         // Profiler
         m_positions[idx].archetype = m_state.profiler.archetype;
         m_positions[idx].profilerSamples = m_state.profiler.samplesCollected;

         // MAE/MFE: initialise extreme-price trackers at entry price
         m_positions[idx].worstPrice  = req.price;
         m_positions[idx].bestPrice   = req.price;
         m_positions[idx].atrAtEntry  = m_state.marketData.atrProxy;
         m_positions[idx].staleTicks  = 0;
      }
      return posTicket;
   }

   void ManagePositions(void)
   {
      double atrPrice = m_state.marketData.atrProxy * m_state.marketData.pointSize;
      if (atrPrice <= 0) return;
      double realBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double realAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      if (realBid <= 0 || realAsk <= 0) return;

      for (int i = m_posCount - 1; i >= 0; i--)
      {
         if (!PositionSelectByTicket(m_positions[i].ticket))
         {
            // The position is no longer selectable — it has been closed. Do NOT
            // remove the entry immediately: OnTradeClosed() (fired by
            // OnTradeTransaction) has not run yet and needs this entry to copy
            // signalId/trailingStyle into the trade record.  Instead, increment
            // a staleness counter and only evict once it reaches the threshold.
            // This gives OnTradeTransaction at least VP_STALE_EVICT_TICKS ticks
            // to fire before we treat the entry as truly orphaned.
            m_positions[i].staleTicks++;
            if (m_positions[i].staleTicks >= VP_STALE_EVICT_TICKS)
            {
               m_positions[i] = m_positions[m_posCount - 1];
               m_posCount--;
            }
            continue;
         }
         // Position is still live — reset any staleness from a previous miss.
         m_positions[i].staleTicks = 0;

         double curPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         bool isBuy = m_positions[i].isBuy;
         double profit = isBuy ? (curPrice - openPrice) : (openPrice - curPrice);

         // ── MAE/MFE tracking: update extreme prices while position is live ──
         // For a BUY: MAE = lowest bid (adverse), MFE = highest bid (favourable).
         // For a SELL: MAE = highest ask (adverse), MFE = lowest ask (favourable).
         // We use the current execution price as a proxy (curPrice from MT5).
         if (isBuy) {
            if (curPrice < m_positions[i].worstPrice) m_positions[i].worstPrice = curPrice;
            if (curPrice > m_positions[i].bestPrice)  m_positions[i].bestPrice  = curPrice;
         } else {
            if (curPrice > m_positions[i].worstPrice) m_positions[i].worstPrice = curPrice;
            if (curPrice < m_positions[i].bestPrice)  m_positions[i].bestPrice  = curPrice;
         }

         // Thesis check
         SThesisOutput thesisOut = m_thesis.Evaluate(m_state, profit, atrPrice);
         if (thesisOut.exitSeverity == EXIT_FULL)
         {
            MqlTradeRequest req; MqlTradeResult res;
            ZeroMemory(req); ZeroMemory(res);
            req.action = TRADE_ACTION_DEAL; req.symbol = m_symbol;
            req.volume = PositionGetDouble(POSITION_VOLUME);
            req.type = isBuy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            req.price = isBuy ? realBid : realAsk;
            req.deviation = 30; req.position = m_positions[i].ticket;
            req.type_filling = ORDER_FILLING_IOC;
            if (OrderSend(req, res) && res.retcode == 10009)
            {
               PrintFormat("[VP_EA][%s] THESIS_EXIT: ticket=%llu", m_symbol, m_positions[i].ticket);
               m_positions[i] = m_positions[m_posCount - 1];
               m_posCount--;
            }
            continue;
         }

         // Trailing stop — driven by THIS position's own style (set at entry),
         // not the global config, so the DataCollect fan-out trails each of its
         // 3 positions differently (-1=off, 0=conservative, 1=expansion).
         double currentSL = PositionGetDouble(POSITION_SL);
         int posTrailStyle = m_positions[i].trailingStyle;
         if (posTrailStyle != (int)TRAIL_STYLE_DISABLED)
         {
         CAuctionTrailingStopEngine *eng = TrailEngine(posTrailStyle);
         eng.SetTrailingStyle((ETrailingStyle)posTrailStyle);
         eng.SetMinUpdateSeconds(m_config.trailMinUpdateSecs);

         STrailingContext ctx;
         ctx.bid = realBid; ctx.ask = realAsk; ctx.isBuy = isBuy;
         ctx.entryPrice = openPrice; ctx.currentSL = currentSL;
         ctx.floatingProfit = profit;
         ctx.atr = atrPrice * MathMax(0.6, thesisOut.adjustedATRMultiplier);
         ctx.pointSize = m_state.marketData.pointSize;
         ctx.isRunnerPosition = false;

         STrailingDecision decision = eng.Evaluate(ctx, m_state);
         if (decision.shouldExitImmediately)
         {
            MqlTradeRequest req; MqlTradeResult res;
            ZeroMemory(req); ZeroMemory(res);
            req.action = TRADE_ACTION_DEAL; req.symbol = m_symbol;
            req.volume = PositionGetDouble(POSITION_VOLUME);
            req.type = isBuy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            req.price = isBuy ? realBid : realAsk;
            req.deviation = 30; req.position = m_positions[i].ticket;
            req.type_filling = ORDER_FILLING_IOC;
            if (OrderSend(req, res) && res.retcode == 10009)
            {
               m_positions[i] = m_positions[m_posCount - 1];
               m_posCount--;
            }
            continue;
         }
         if (decision.shouldMoveStop)
         {
            int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
            double newSL = NormalizeDouble(decision.newStopPrice, digits);
            if (MathAbs(newSL - currentSL) > ctx.pointSize)
            {
               double curTP = PositionGetDouble(POSITION_TP);
               MqlTradeRequest req; MqlTradeResult res;
               ZeroMemory(req); ZeroMemory(res);
               req.action = TRADE_ACTION_SLTP; req.symbol = m_symbol;
               req.sl = newSL; req.tp = curTP;
               req.position = m_positions[i].ticket;
               bool sent = OrderSend(req, res);
               if (sent && res.retcode == 10009)
                  m_telegram.NotifyModify(m_symbol, m_positions[i].ticket, currentSL, newSL, curTP);
            }
         }
         } // end trailing block
      }
   }

public:
   CVPTradingPipeline(void) { m_posCount = 0; }

   bool Initialize(const string symbol, const SVPEAConfig &config)
   {
      m_symbol = symbol;
      m_config = config;
      m_posCount = 0;

      m_ratesCache.Bootstrap(symbol);
      m_sessionData.Bootstrap(symbol);
      m_spreadMonitor.Bootstrap(symbol);
      m_economicCalendar.Bootstrap(symbol, config.newsBlockMinsBefore, config.newsBlockMinsAfter);
      m_symbolMetaData.Bootstrap(symbol);
      m_vpEngine.Bootstrap(symbol);
      m_auctionIntel.Bootstrap(symbol);
      m_auctionIntel.SetVPEngine(GetPointer(m_vpEngine));
      m_profiler.Bootstrap(symbol, config.profilerWarmupBars);
      m_swingDetector.Bootstrap(symbol, 3);
      m_bos.Bootstrap(symbol);
      m_choch.Bootstrap(symbol);
      // Both trailing engines (conservative + expansion). Per-position style is
      // applied in ManagePositions; here we just reset state and set the throttle.
      m_trailing[0].Reset();
      m_trailing[0].SetTrailingStyle(TRAIL_STYLE_CONSERVATIVE);
      m_trailing[0].SetMinUpdateSeconds(config.trailMinUpdateSecs);
      m_trailing[1].Reset();
      m_trailing[1].SetTrailingStyle(TRAIL_STYLE_EXPANSION);
      m_trailing[1].SetMinUpdateSeconds(config.trailMinUpdateSecs);
      m_thesis.Reset();

      m_trigBreakout.Bootstrap(symbol);
      m_trigRetest.Bootstrap(symbol);
      m_trigPullback.Bootstrap(symbol);
      m_trigTrendCont.Bootstrap(symbol);
      m_trigSweep.Bootstrap(symbol);
      m_trigMeanRev.Bootstrap(symbol);
      m_trigNakedPOC.Bootstrap(symbol);
      m_trigAnchoredPB.Bootstrap(symbol);

      m_funnelLogger.Bootstrap(symbol, config.logFunnel);
      m_failureAttrib.Bootstrap(symbol);
      m_telegram.Bootstrap(config.telegramEnabled, config.telegramBotToken,
                           config.telegramChatId, config.telegramPrefix);

      // ─── Bonus Engines ───
      m_tickCache.Bootstrap(symbol);
      m_engSpread.Bootstrap(symbol);
      m_engTickImb.Bootstrap(symbol);
      m_engTickVel.Bootstrap(symbol);
      m_engCompression.Bootstrap(symbol);
      m_engLiqVacuum.Bootstrap(symbol);
      m_engCVD.Bootstrap(symbol);
      m_engDelta.Bootstrap(symbol);
      m_engParticipation.Bootstrap(symbol);
      m_engAbsorption.Bootstrap(symbol);
      m_engDivergence.Bootstrap(symbol);
      m_engExhaustion.Bootstrap(symbol);
      m_engFlowIntensity.Bootstrap(symbol);
      m_engLiquidity.Bootstrap(symbol);
      m_engEqualHL.Bootstrap(symbol);
      m_engPremDisc.Bootstrap(symbol);
      m_engStopCluster.Bootstrap(symbol);
      m_engSessionLiq.Bootstrap(symbol);
      m_engSweep.Bootstrap(symbol);
      m_engZoneLifecycle.Bootstrap(symbol);
      m_engFVG.Bootstrap(symbol);
      m_engOrderBlock.Bootstrap(symbol);
      m_engRejectionBlock.Bootstrap(symbol);

      // ─── Visuals ───
      m_overlay.Init(symbol, config.showOverlay, config.showOverlay, config.showOverlay,
                     config.showOverlay, config.showOverlay, config.showOverlay,
                     config.showOverlay, config.showOverlay);
      m_overlay.SetEnabled(config.showOverlay);
      m_dashboard.Init(symbol, config.showDashboard);

      CLogger::Info(StringFormat("VP Pipeline initialized for %s", symbol));
      return true;
   }

   void Update(void)
   {
      ResetVPPipelineState(m_state, m_symbol);
      SampleMarketData();

      // Layer 1: Data Acquisition
      m_ratesCache.Execute(m_state);
      m_sessionData.Execute(m_state);
      m_spreadMonitor.Execute(m_state);
      m_economicCalendar.Execute(m_state);
      m_symbolMetaData.Execute(m_state);

      // Layer 2: Volume Profile + Auction
      m_vpEngine.Execute(m_state);
      if (!m_state.vpValid) return;
      m_auctionIntel.Execute(m_state);

      // Layer 3: VP Behavior Profiler
      m_profiler.Execute(m_state);

      // Layer 3.5: Market Structure (timing layer)
      m_swingDetector.Execute(m_state);
      m_bos.Update(m_state, m_swingDetector);
      m_choch.Update(m_state, m_swingDetector);
      // Write structure state
      m_state.bosConfirmed = m_bos.IsConfirmed();
      m_state.bosBullish = m_bos.IsBullish();
      m_state.bosScore = m_bos.Score();
      m_state.bosLevel = m_bos.Level();
      m_state.chochConfirmed = m_choch.IsConfirmed();
      m_state.chochBullish = m_choch.IsBullishReversal();
      m_state.chochScore = m_choch.Score();
      m_state.chochLevel = m_choch.Level();
      m_state.trendDirection = m_choch.TrendDirection();

      // Layer 3.6: Bonus Engines (research data collection only — no trade impact)
      RunBonusEngines();

      // Visuals: state now has VP/auction/structure/engine data. Draw here so the
      // panel/overlay refresh every tick regardless of the trade-gate early returns below.
      m_overlay.Update(GetPointer(m_vpEngine));
      m_dashboard.Update(m_state);

      // Manage existing positions (trailing + thesis exit)
      ManagePositions();

      // ─── News filter: block new entries near high-impact news ───
      if (m_state.news.isNearNews)
      {
         m_state.executionAllowed = false;
         m_state.statusMessage = StringFormat("news_block_%s_%dmin",
            m_state.news.nextEventName, m_state.news.minutesToNews);
         return;
      }

      // ─── Structural confirmation gate ───────────────────────────
      // Triggers only fire when BOS or CHOCH confirms a directional move.
      // This drastically reduces noise and ensures we only enter on
      // structurally significant moves, not random VP level touches.
      bool hasStructuralSignal = m_state.bosConfirmed || m_state.chochConfirmed;
      if (!hasStructuralSignal)
         return;  // skip trigger evaluation entirely — no structure = no trade

      // Layer 4: Setup Triggers (first-match)
      // Direction from structural signal determines which triggers can fire:
      // BOS bull → only bullish triggers, CHOCH bull → reversal to bull
      // This prevents firing a bearish trigger when BOS just confirmed bullish
      if (!m_state.primarySetup.isValid && m_config.enableBreakout)
         m_trigBreakout.Execute(m_state);
      if (!m_state.primarySetup.isValid && m_config.enableBreakoutRetest)
         m_trigRetest.Execute(m_state);
      if (!m_state.primarySetup.isValid && m_config.enablePullback)
         m_trigPullback.Execute(m_state);
      if (!m_state.primarySetup.isValid && m_config.enableTrendCont)
         m_trigTrendCont.Execute(m_state);
      if (!m_state.primarySetup.isValid && m_config.enableSweepReversal)
         m_trigSweep.Execute(m_state);
      if (!m_state.primarySetup.isValid && m_config.enableMeanReversion)
         m_trigMeanRev.Execute(m_state);
      if (!m_state.primarySetup.isValid && m_config.enableNakedPOC)
         m_trigNakedPOC.Execute(m_state);
      if (!m_state.primarySetup.isValid && m_config.enableAnchoredPullback)
         m_trigAnchoredPB.Execute(m_state);

      // ─── Post-trigger: Validate direction alignment with structure ───
      // If trigger fired, check direction matches BOS/CHOCH
      if (m_state.primarySetup.isValid)
      {
         bool isBuySetup = (m_state.primarySetup.stopLoss < m_state.primarySetup.entryPrice);
         bool structBull = (m_state.bosConfirmed && m_state.bosBullish) ||
                           (m_state.chochConfirmed && m_state.chochBullish);
         bool structBear = (m_state.bosConfirmed && !m_state.bosBullish) ||
                           (m_state.chochConfirmed && !m_state.chochBullish);

         // Block if direction conflicts (buy setup but bearish structure, etc.)
         if (isBuySetup && structBear && !structBull)
         {
            m_state.primarySetup.isValid = false;
            m_state.statusMessage = "direction_conflict_bear_struct";
         }
         else if (!isBuySetup && structBull && !structBear)
         {
            m_state.primarySetup.isValid = false;
            m_state.statusMessage = "direction_conflict_bull_struct";
         }
      }

      // ─── EdgeGuard Filtering (when enabled) ────────────────────
      if (m_state.primarySetup.isValid && m_config.useEdgeGuards)
      {
         string setupName = SetupTypeToString(m_state.primarySetup.setupType);
         int setupInt = (int)m_state.primarySetup.setupType;

         // 1. Symbol blocked entirely (Phase 01 AVOID)
         if (VPIsSymbolBlocked(m_symbol))
         {
            m_state.primarySetup.isValid = false;
            m_state.statusMessage = "edgeguard_symbol_blocked";
         }

         // 2. Trigger disabled for this symbol (Phase 01 recommendation)
         if (m_state.primarySetup.isValid && !VPIsTriggerEnabled(m_symbol, setupInt))
         {
            m_state.primarySetup.isValid = false;
            m_state.statusMessage = "edgeguard_trigger_disabled";
         }

         // 3. Regime block (Phase 03)
         if (m_state.primarySetup.isValid && VPIsBlocked(m_symbol, setupName, m_state.auctRegime))
         {
            m_state.primarySetup.isValid = false;
            m_state.statusMessage = "edgeguard_regime_blocked";
         }

         // 4. Feature gates (Phase 02) — ALL features from VPEdgeGuardConfig
         if (m_state.primarySetup.isValid)
         {
            double spreadToATR4 = (m_state.marketData.atrProxy > 0)
                                   ? m_state.marketData.spreadPoints / m_state.marketData.atrProxy : 0.0;
            double mult = 1.0;
            // ── VP core ──
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpPOC",              m_state.vpPOC));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpVAH",              m_state.vpVAH));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpVAL",              m_state.vpVAL));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpInsideVA",         m_state.vpInsideVA ? 1.0 : 0.0));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpDistToHVN",        m_state.vpDistToHVN_ATR));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpDistToLVN",        m_state.vpDistToLVN_ATR));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpBestHVNScore",     m_state.vpBestHVNScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpThinnessRatio",    m_state.vpThinnessRatio));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpMigrationScore",   m_state.vpMigrationScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpMigrationConf",    m_state.vpMigrationConfidence));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpPriceVsPOC",       m_state.vpPriceVsPOC));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpDevPOCDir",        m_state.vpDevPOCDirection));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpDevPOCSlope",      m_state.vpDevPOCSlope));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpDailyPOC",         m_state.vpDailyPOC));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpDistCompPOC",      m_state.vpDistToCompositePOC_ATR));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpCompPOC",          m_state.vpCompositePOC));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpCompVAH",          m_state.vpCompositeVAH));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpCompVAL",          m_state.vpCompositeVAL));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpCompInsideVA",     m_state.vpCompositeInsideVA ? 1.0 : 0.0));
            // ── Long-term VP ──
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpLTPOCVelocity",       m_state.vpLTPOCVelocity));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpLTPOCMigration",      (double)m_state.vpLTPOCMigration));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpLTTransitionScore",   m_state.vpLTTransitionScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpLTBalanceStability",  m_state.vpLTBalanceStability));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpLTTrendDuration",     m_state.vpLTTrendDuration));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpLTTrendExhaustion",   m_state.vpLTTrendExhaustion));
            // ── Auction intelligence ──
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctRegimeConf",     m_state.auctRegimeConfidence));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctBalance",        m_state.auctBalanceScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctFailure",        m_state.auctFailureScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctTradeQuality",   m_state.auctTradeQuality));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctTradeGrade",     (double)m_state.auctTradeGrade));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctTargetProb",     m_state.auctTargetProbability));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctAcceptance",     m_state.auctAcceptanceScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctContinuation",   m_state.auctContinuationScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctReversalRisk",   m_state.auctReversalRiskScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctExhaustion",     m_state.auctExhaustionScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctExpReward",      m_state.auctExpectedReward));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctExpMoveATR",     m_state.auctExpectedMoveATR));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctHVNStrength",    m_state.auctHVNClusterStrength));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctVAExpRate",      m_state.auctVAExpansionRate));
            // ── Structure ──
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "bosScore",           m_state.bosScore));
            // ── Bonus engines ──
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "msCompression",      m_state.microstructure.compressionScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "ofFlowIntensity",    m_state.flow.flowIntensityScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "liqSweep",           m_state.liquidity.sweepScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "smZoneQuality",      m_state.smartMoney.zoneQualityScore));
            // ── Composite features (VPFunnelLogger v2+) ──
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "bosQuality",         m_state.bosScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "chochQuality",       m_state.chochScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "structAlign",        (m_state.trendDirection == (m_state.bosBullish ? 1 : -1)) ? 1.0 : 0.0));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "msContext",          m_state.microstructure.compressionScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "ofContext",          m_state.flow.flowIntensityScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "liqContext",         m_state.liquidity.sweepScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "smContext",          m_state.smartMoney.zoneQualityScore));
            // ── Market conditions ──
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "atrProxy",           m_state.marketData.atrProxy));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "spreadToATR",        spreadToATR4));

            if (mult <= 0.0)
            {
               m_state.primarySetup.isValid = false;
               m_state.statusMessage = "edgeguard_feature_gate";
            }
         }

         // 5. Soft tilt (Phase 04) — adjust winProbability, does NOT block
         if (m_state.primarySetup.isValid)
         {
            double spreadToATR5 = (m_state.marketData.atrProxy > 0)
                                   ? m_state.marketData.spreadPoints / m_state.marketData.atrProxy : 0.0;
            double tilt = 1.0;
            // ── VP core ──
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpPOC",              m_state.vpPOC));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpVAH",              m_state.vpVAH));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpVAL",              m_state.vpVAL));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpInsideVA",         m_state.vpInsideVA ? 1.0 : 0.0));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpDistToHVN",        m_state.vpDistToHVN_ATR));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpDistToLVN",        m_state.vpDistToLVN_ATR));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpBestHVNScore",     m_state.vpBestHVNScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpThinnessRatio",    m_state.vpThinnessRatio));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpMigrationScore",   m_state.vpMigrationScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpMigrationConf",    m_state.vpMigrationConfidence));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpPriceVsPOC",       m_state.vpPriceVsPOC));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpDevPOCDir",        m_state.vpDevPOCDirection));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpDevPOCSlope",      m_state.vpDevPOCSlope));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpDailyPOC",         m_state.vpDailyPOC));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpDistCompPOC",      m_state.vpDistToCompositePOC_ATR));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpCompPOC",          m_state.vpCompositePOC));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpCompVAH",          m_state.vpCompositeVAH));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpCompVAL",          m_state.vpCompositeVAL));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpLTPOCVelocity",    m_state.vpLTPOCVelocity));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpLTPOCMigration",   (double)m_state.vpLTPOCMigration));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpLTTransitionScore",m_state.vpLTTransitionScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpLTBalanceStability",m_state.vpLTBalanceStability));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpLTTrendDuration",  m_state.vpLTTrendDuration));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "vpLTTrendExhaustion",m_state.vpLTTrendExhaustion));
            // ── Auction ──
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctRegimeConf",     m_state.auctRegimeConfidence));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctBalance",        m_state.auctBalanceScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctFailure",        m_state.auctFailureScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctTradeQuality",   m_state.auctTradeQuality));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctTradeGrade",     (double)m_state.auctTradeGrade));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctTargetProb",     m_state.auctTargetProbability));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctAcceptance",     m_state.auctAcceptanceScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctContinuation",   m_state.auctContinuationScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctReversalRisk",   m_state.auctReversalRiskScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctExhaustion",     m_state.auctExhaustionScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctExpReward",      m_state.auctExpectedReward));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctExpMoveATR",     m_state.auctExpectedMoveATR));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctHVNStrength",    m_state.auctHVNClusterStrength));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "auctVAExpRate",      m_state.auctVAExpansionRate));
            // ── Structure / bonus engines ──
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "bosScore",           m_state.bosScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "msCompression",      m_state.microstructure.compressionScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "ofFlowIntensity",    m_state.flow.flowIntensityScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "liqSweep",           m_state.liquidity.sweepScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "smZoneQuality",      m_state.smartMoney.zoneQualityScore));
            // ── Composite features ──
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "bosQuality",         m_state.bosScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "chochQuality",       m_state.chochScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "structAlign",        (m_state.trendDirection == (m_state.bosBullish ? 1 : -1)) ? 1.0 : 0.0));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "msContext",          m_state.microstructure.compressionScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "ofContext",          m_state.flow.flowIntensityScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "liqContext",         m_state.liquidity.sweepScore));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "smContext",          m_state.smartMoney.zoneQualityScore));
            // ── Market conditions ──
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "atrProxy",           m_state.marketData.atrProxy));
            tilt = MathMin(tilt, VPGetEdgeTiltMultiplier(m_symbol, setupName, "spreadToATR",        spreadToATR5));
            // Apply tilt: scales winProbability (informational, used by lot sizing if enabled)
            m_state.winProbability *= tilt;
            // Block trade if cumulative tilt is below minimum threshold
            if (m_config.minTiltThreshold > 0.0 && tilt < m_config.minTiltThreshold)
            {
               m_state.primarySetup.isValid = false;
               m_state.statusMessage = "edgeguard_tilt_below_threshold";
            }
         }

         // 5b. SHAP-guided tilts (experimental — NOT FDR validated)
         // Applies VPGetSHAPTilt() per feature, scales winProbability further.
         // These are raw SHAP findings — used for research observation only.
         if (m_state.primarySetup.isValid)
         {
            double spreadToATR5b = (m_state.marketData.atrProxy > 0)
                                   ? m_state.marketData.spreadPoints / m_state.marketData.atrProxy : 0.0;
            double shapTilt = 1.0;
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpPOC",             m_state.vpPOC));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpVAH",             m_state.vpVAH));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpVAL",             m_state.vpVAL));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpDistToHVN",       m_state.vpDistToHVN_ATR));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpDistToLVN",       m_state.vpDistToLVN_ATR));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpMigrationScore",  m_state.vpMigrationScore));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpThinnessRatio",   m_state.vpThinnessRatio));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "vpDevPOCDir",       m_state.vpDevPOCDirection));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "auctTradeQuality",  m_state.auctTradeQuality));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "auctBalance",       m_state.auctBalanceScore));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "auctRegimeConf",    m_state.auctRegimeConfidence));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "auctContinuation",  m_state.auctContinuationScore));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "auctHVNStrength",   m_state.auctHVNClusterStrength));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "auctExpReward",     m_state.auctExpectedReward));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "msCompression",     m_state.microstructure.compressionScore));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "ofFlowIntensity",   m_state.flow.flowIntensityScore));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "liqContext",        m_state.liquidity.sweepScore));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "smZoneQuality",     m_state.smartMoney.zoneQualityScore));
            shapTilt = MathMin(shapTilt, VPGetSHAPTilt(m_symbol, setupName, "spreadToATR",       spreadToATR5b));
            // Apply SHAP tilt to winProbability (informational + research tracking)
            m_state.winProbability *= shapTilt;
         }

         // 6. SL risk multiplier (Phase 05) — reduce lot, don't block
         if (m_state.primarySetup.isValid)
         {
            double spreadToATR6 = (m_state.marketData.atrProxy > 0)
                                   ? m_state.marketData.spreadPoints / m_state.marketData.atrProxy : 0.0;
            double slMult = 1.0;
            slMult = MathMin(slMult, VPGetSLRiskMultiplier(m_symbol, setupName, "auctFailure", m_state.auctFailureScore));
            slMult = MathMin(slMult, VPGetSLRiskMultiplier(m_symbol, setupName, "auctReversalRisk", m_state.auctReversalRiskScore));
            slMult = MathMin(slMult, VPGetSLRiskMultiplier(m_symbol, setupName, "spreadToATR", spreadToATR6));
            m_state.edgeGuardMultiplier = slMult; // applied to lot size in ExecuteSetup
         }

         // 9. Bad-entry filter (L10 canary: sl_count >= 2 across 3 trailing styles)
         // Uses file-scope vote counter: reset → vote each feature → check result.
         if (m_state.primarySetup.isValid)
         {
            double spreadToATR9 = (m_state.marketData.atrProxy > 0)
                                   ? m_state.marketData.spreadPoints / m_state.marketData.atrProxy : 0.0;
            // Step 1: reset vote counter
            VPBadEntryVote("__reset__", m_symbol, setupName, "", 0);
            // Step 2: feed each feature
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpPOC",              m_state.vpPOC);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpVAH",              m_state.vpVAH);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpVAL",              m_state.vpVAL);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpInsideVA",         m_state.vpInsideVA ? 1.0 : 0.0);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpDistToHVN",        m_state.vpDistToHVN_ATR);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpDistToLVN",        m_state.vpDistToLVN_ATR);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpPriceVsPOC",       m_state.vpPriceVsPOC);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpThinnessRatio",    m_state.vpThinnessRatio);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpMigrationScore",   m_state.vpMigrationScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpMigrationConf",    m_state.vpMigrationConfidence);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpDevPOCDir",        m_state.vpDevPOCDirection);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpDevPOCSlope",      m_state.vpDevPOCSlope);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpDailyPOC",         m_state.vpDailyPOC);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpDistCompPOC",      m_state.vpDistToCompositePOC_ATR);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpCompPOC",          m_state.vpCompositePOC);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpCompVAH",          m_state.vpCompositeVAH);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpCompVAL",          m_state.vpCompositeVAL);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpCompInsideVA",     m_state.vpCompositeInsideVA ? 1.0 : 0.0);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpLTTransitionScore",m_state.vpLTTransitionScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpLTBalanceStability",m_state.vpLTBalanceStability);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpLTTrendExhaustion",m_state.vpLTTrendExhaustion);
            VPBadEntryVote("__vote__", m_symbol, setupName, "vpLTPOCVelocity",    m_state.vpLTPOCVelocity);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctAcceptance",     m_state.auctAcceptanceScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctBalance",        m_state.auctBalanceScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctRegimeConf",     m_state.auctRegimeConfidence);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctTradeQuality",   m_state.auctTradeQuality);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctTradeGrade",     (double)m_state.auctTradeGrade);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctExpReward",      m_state.auctExpectedReward);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctExpMoveATR",     m_state.auctExpectedMoveATR);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctTargetProb",     m_state.auctTargetProbability);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctExhaustion",     m_state.auctExhaustionScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctContinuation",   m_state.auctContinuationScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctReversalRisk",   m_state.auctReversalRiskScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "auctHVNStrength",    m_state.auctHVNClusterStrength);
            VPBadEntryVote("__vote__", m_symbol, setupName, "msCompression",      m_state.microstructure.compressionScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "ofFlowIntensity",    m_state.flow.flowIntensityScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "liqContext",         m_state.liquidity.sweepScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "smZoneQuality",      m_state.smartMoney.zoneQualityScore);
            VPBadEntryVote("__vote__", m_symbol, setupName, "atrProxy",           m_state.marketData.atrProxy);
            VPBadEntryVote("__vote__", m_symbol, setupName, "spreadToATR",        spreadToATR9);
            // Step 3: check accumulated result
            if (VPBadEntryVote("__check__", m_symbol, setupName, "", 0))
            {
               m_state.primarySetup.isValid = false;
               m_state.statusMessage = "edgeguard_bad_entry";
            }
         }
      }

      // Layer 5: Execute if triggered, then log funnel with ticket
      if (m_state.primarySetup.isValid)
      {
         // One signal id shared by every position fired from this signal. It links
         // the single funnel row to its (up to 3) trade rows in the research join.
         string signalId = MakeSignalId(m_state.primarySetup.setupType);

         if (m_config.presetMode == RUN_MODE_DATACOLLECT)
         {
            // Fan out one position per trailing style (-1/0/1) on the SAME signal
            // so the research pipeline can attribute exit behaviour to trailing.
            int styles[3] = { (int)TRAIL_STYLE_DISABLED,
                              (int)TRAIL_STYLE_CONSERVATIVE,
                              (int)TRAIL_STYLE_EXPANSION };
            for (int s = 0; s < 3; s++)
            {
               ulong t = ExecuteSetup(styles[s], signalId);
               // One funnel row per fired position, tagged with its trailing style
               // (0 ticket = execution failed but still log the attempt).
               m_funnelLogger.LogSetup(m_state, t, styles[s], signalId);
            }
         }
         else
         {
            ulong openedTicket = ExecuteSetup(m_config.trailingStyle, signalId);
            // Log funnel WITH ticket (0 = execution failed but still log the trigger)
            m_funnelLogger.LogSetup(m_state, openedTicket, m_config.trailingStyle, signalId);
         }
      }

      // Cache the setup/decision for the dashboard (shown until the next setup)
      m_dashboard.CaptureDecision(m_state);
   }

   void OnTradeClosed(ulong ticket, double profit)
   {
      SVPTradeRecord rec;
      ZeroMemory(rec);
      rec.ticket = ticket;
      rec.symbol = m_symbol;
      rec.profitUSD = profit;
      rec.exitTime = TimeCurrent();

      // Find in tracked positions
      bool found = false;
      for (int i = 0; i < m_posCount; i++)
      {
         if (m_positions[i].ticket == ticket)
         {
            rec.setupType = m_positions[i].setupType;
            rec.signalId = m_positions[i].signalId;
            rec.trailingStyle = m_positions[i].trailingStyle;
            rec.isBuy = m_positions[i].isBuy;
            rec.entryPrice = m_positions[i].entryPrice;
            rec.entryTime = m_positions[i].entryTime;
            rec.thesis = m_positions[i].thesis;
            rec.riskReward = m_positions[i].riskReward;
            // VP Core
            rec.entryVpPOC = m_positions[i].vpPOC;
            rec.entryVpVAH = m_positions[i].vpVAH;
            rec.entryVpVAL = m_positions[i].vpVAL;
            rec.entryVpInsideVA = m_positions[i].vpInsideVA;
            rec.entryVpDistHVN = m_positions[i].vpDistHVN;
            rec.entryVpDistLVN = m_positions[i].vpDistLVN;
            rec.entryVpBestHVN = m_positions[i].vpBestHVN;
            rec.entryVpThinnessRatio = m_positions[i].vpThinnessRatio;
            rec.entryVpOverlapBias = m_positions[i].vpOverlapBias;
            rec.entryVpMigrationConf = m_positions[i].vpMigrationConf;
            rec.entryVpDevPOCDir = m_positions[i].vpDevPOCDir;
            rec.entryVpProfileShape = m_positions[i].vpProfileShape;
            rec.entryVpUpthrust = m_positions[i].vpUpthrust;
            rec.entryVpSpring = m_positions[i].vpSpring;
            rec.entryVpCompPosition = m_positions[i].vpCompPosition;
            rec.entryVpBreakoutPOC = m_positions[i].vpBreakoutPOC;
            // Auction
            rec.entryRegime = m_positions[i].auctRegime;
            rec.entryRegimeConf = m_positions[i].auctRegimeConf;
            rec.entryTradeQuality = m_positions[i].auctTradeQuality;
            rec.entryTradeGrade = m_positions[i].auctTradeGrade;
            rec.entryBalanceScore = m_positions[i].auctBalance;
            rec.entryContinuation = m_positions[i].auctContinuation;
            rec.entryReversalRisk = m_positions[i].auctReversalRisk;
            rec.entryExhaustion = m_positions[i].auctExhaustion;
            rec.entryFailure = m_positions[i].auctFailure;
            rec.entryVAExpRate = m_positions[i].auctVAExpRate;
            rec.entryTargetPrice = m_positions[i].auctTargetPrice;
            rec.entryTargetConf = m_positions[i].auctTargetConf;
            rec.entryExpReward = m_positions[i].auctExpReward;
            // Long-Term
            rec.entryLTValid = m_positions[i].ltValid;
            rec.entryLTPOCMigration = m_positions[i].ltPOCMigration;
            rec.entryLTNearestZoneStrength = m_positions[i].ltNearestZoneStrength;
            // Profiler
            rec.archetype = m_positions[i].archetype;
            rec.profilerSamples = m_positions[i].profilerSamples;

            // MAE/MFE: convert tracked extreme prices to ATR-normalised values
            // atrAtEntry = atrProxy in POINTS → atrInPrice = atrProxy * pointSize
            double atrE = m_positions[i].atrAtEntry;
            double pt   = m_state.marketData.pointSize;
            if (pt <= 0) pt = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            double atrInPrice = atrE * pt;   // ATR in price units
            if (atrInPrice > 0 && rec.entryPrice > 0) {
               double mae_raw = MathAbs(m_positions[i].worstPrice - rec.entryPrice);
               double mfe_raw = MathAbs(m_positions[i].bestPrice  - rec.entryPrice);
               rec.maeATR = mae_raw / atrInPrice;
               rec.mfeATR = mfe_raw / atrInPrice;
            }

            // Remove from tracking
            m_positions[i] = m_positions[m_posCount - 1];
            m_posCount--;
            found = true;
            break;
         }
      }

      // If not found in tracked positions, recover setupType from deal comment
      if (!found)
      {
         rec.setupType = SETUP_NONE;
         rec.signalId = "";      // unknown — position was not tracked in RAM
         rec.trailingStyle = 99; // 99 = unknown (position not tracked in RAM)
         if (HistorySelectByPosition(ticket))
         {
            for (int d = 0; d < HistoryDealsTotal(); d++)
            {
               ulong deal = HistoryDealGetTicket(d);
               if (HistoryDealGetInteger(deal, DEAL_POSITION_ID) != (long)ticket) continue;
               if ((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  string cmt = HistoryDealGetString(deal, DEAL_COMMENT);
                  // Recover trailing style encoded as _T<style> (see ExecuteSetup)
                  int tp = StringFind(cmt, "_T");
                  if (tp >= 0)
                     rec.trailingStyle = (int)StringToInteger(StringSubstr(cmt, tp + 2));
                  if (StringFind(cmt, "BREAKOUT_RETEST") >= 0) rec.setupType = SETUP_BREAKOUT_RETEST;
                  else if (StringFind(cmt, "NAKED_POC") >= 0) rec.setupType = SETUP_NAKED_POC;
                  else if (StringFind(cmt, "ANCHORED_PULLBACK") >= 0) rec.setupType = SETUP_ANCHORED_PULLBACK;
                  else if (StringFind(cmt, "BREAKOUT") >= 0) rec.setupType = SETUP_BREAKOUT;
                  else if (StringFind(cmt, "PULLBACK") >= 0) rec.setupType = SETUP_PULLBACK;
                  else if (StringFind(cmt, "TREND_CONTINUATION") >= 0) rec.setupType = SETUP_TREND_CONTINUATION;
                  else if (StringFind(cmt, "SWEEP_REVERSAL") >= 0) rec.setupType = SETUP_SWEEP_REVERSAL;
                  else if (StringFind(cmt, "MEAN_REVERSION") >= 0) rec.setupType = SETUP_MEAN_REVERSION;
                  rec.entryPrice = HistoryDealGetDouble(deal, DEAL_PRICE);
                  rec.entryTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
                  rec.isBuy = ((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_BUY);
                  break;
               }
            }
         }
      }

      // Enrich from deal history
      if (HistorySelectByPosition(ticket))
      {
         for (int d = 0; d < HistoryDealsTotal(); d++)
         {
            ulong deal = HistoryDealGetTicket(d);
            if (HistoryDealGetInteger(deal, DEAL_POSITION_ID) != (long)ticket) continue;
            ENUM_DEAL_ENTRY de = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
            if (de == DEAL_ENTRY_OUT || de == DEAL_ENTRY_OUT_BY)
            {
               rec.exitPrice = HistoryDealGetDouble(deal, DEAL_PRICE);
               ENUM_DEAL_REASON dr = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);
               if (dr == DEAL_REASON_TP) rec.exitReason = "TP_HIT";
               else if (dr == DEAL_REASON_SL) rec.exitReason = (profit >= 0) ? "TRAIL_STOP" : "SL_HIT";
               else if (dr == DEAL_REASON_EXPERT) rec.exitReason = "THESIS_EXIT";
               else rec.exitReason = "OTHER";
            }
         }
      }

      double pt = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if (pt > 0 && rec.entryPrice > 0 && rec.exitPrice > 0)
         rec.profitPips = MathAbs(rec.exitPrice - rec.entryPrice) / pt * (profit >= 0 ? 1.0 : -1.0);
      if (rec.entryTime > 0 && rec.exitTime > rec.entryTime)
         rec.holdingMinutes = (int)((rec.exitTime - rec.entryTime) / 60);

      m_failureAttrib.OnTradeClosed(rec, m_state);
      PrintFormat("[VP_EA][%s] CLOSED: ticket=%llu profit=%.2f setup=%s",
         m_symbol, ticket, profit, SetupTypeToString(rec.setupType));

      // Telegram: trade closed (covers SL/TP, thesis exit, trailing exit — every close)
      m_telegram.NotifyClose(m_symbol, ticket,
                             (rec.exitReason == "" ? "CLOSED" : rec.exitReason),
                             rec.exitPrice, rec.profitUSD, rec.profitPips);
   }

   void Shutdown(void)
   {
      m_funnelLogger.Flush();
      m_failureAttrib.Flush();
      m_overlay.Deinit();
      m_dashboard.Deinit();
      CLogger::Info(StringFormat("VP Pipeline shutdown for %s", m_symbol));
   }

   string Symbol(void) const { return m_symbol; }
};

#endif
