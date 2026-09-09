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
   bool     isBuy;
   double   entryPrice;
   ESetupType setupType;
   datetime entryTime;
   double   thesis;
   double   riskReward;
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
};

#define VP_MAX_POSITIONS 10

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
   CAuctionTrailingStopEngine m_trailing;
   CAuctionThesisManager  m_thesis;

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

   ulong ExecuteSetup(void)
   {
      if (!m_state.primarySetup.isValid) return 0;
      if (CountMyPositions() >= m_config.maxPositionsPerSymbol) return 0;

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
      req.comment = "VP_" + SetupTypeToString(m_state.primarySetup.setupType);
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
         m_positions[idx].thesis = m_state.winProbability;
         m_positions[idx].riskReward = m_state.primarySetup.riskReward;
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
            m_positions[i] = m_positions[m_posCount - 1];
            m_posCount--;
            continue;
         }

         double curPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         bool isBuy = m_positions[i].isBuy;
         double profit = isBuy ? (curPrice - openPrice) : (openPrice - curPrice);

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

         // Trailing stop (only when not disabled)
         double currentSL = PositionGetDouble(POSITION_SL);
         if (m_config.trailingStyle != (int)TRAIL_STYLE_DISABLED)
         {
         STrailingContext ctx;
         ctx.bid = realBid; ctx.ask = realAsk; ctx.isBuy = isBuy;
         ctx.entryPrice = openPrice; ctx.currentSL = currentSL;
         ctx.floatingProfit = profit;
         ctx.atr = atrPrice * MathMax(0.6, thesisOut.adjustedATRMultiplier);
         ctx.pointSize = m_state.marketData.pointSize;
         ctx.isRunnerPosition = false;

         STrailingDecision decision = m_trailing.Evaluate(ctx, m_state);
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
      m_trailing.Reset();
      m_trailing.SetTrailingStyle((ETrailingStyle)config.trailingStyle);
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

         // 4. Feature gates (Phase 02) — check key VP/Auction features
         if (m_state.primarySetup.isValid)
         {
            double mult = 1.0;
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctTradeQuality", m_state.auctTradeQuality));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "vpMigrationConf", m_state.vpMigrationConfidence));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctBalance", m_state.auctBalanceScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctContinuation", m_state.auctContinuationScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctFailure", m_state.auctFailureScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "auctReversalRisk", m_state.auctReversalRiskScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "bosScore", m_state.bosScore));
            mult = MathMin(mult, VPGetEdgeMultiplier(m_symbol, setupName, "spreadToATR",
                     m_state.marketData.atrProxy > 0 ? m_state.marketData.spreadPoints / m_state.marketData.atrProxy : 0));

            if (mult <= 0.0)
            {
               m_state.primarySetup.isValid = false;
               m_state.statusMessage = "edgeguard_feature_gate";
            }
         }

         // 5. SL risk multiplier (Phase 05) — reduce lot, don't block
         if (m_state.primarySetup.isValid)
         {
            double slMult = 1.0;
            slMult = MathMin(slMult, VPGetSLRiskMultiplier(m_symbol, setupName, "auctFailure", m_state.auctFailureScore));
            slMult = MathMin(slMult, VPGetSLRiskMultiplier(m_symbol, setupName, "auctReversalRisk", m_state.auctReversalRiskScore));
            slMult = MathMin(slMult, VPGetSLRiskMultiplier(m_symbol, setupName, "spreadToATR",
                     m_state.marketData.atrProxy > 0 ? m_state.marketData.spreadPoints / m_state.marketData.atrProxy : 0));
            m_state.edgeGuardMultiplier = slMult; // applied to lot size in ExecuteSetup
         }
      }

      // Layer 5: Execute if triggered, then log funnel with ticket
      if (m_state.primarySetup.isValid)
      {
         ulong openedTicket = ExecuteSetup();
         // Log funnel WITH ticket (0 = execution failed but still log the trigger)
         m_funnelLogger.LogSetup(m_state, openedTicket);
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
         if (HistorySelectByPosition(ticket))
         {
            for (int d = 0; d < HistoryDealsTotal(); d++)
            {
               ulong deal = HistoryDealGetTicket(d);
               if (HistoryDealGetInteger(deal, DEAL_POSITION_ID) != (long)ticket) continue;
               if ((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  string cmt = HistoryDealGetString(deal, DEAL_COMMENT);
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
