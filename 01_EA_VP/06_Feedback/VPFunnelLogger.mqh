#ifndef __VP_EA_FUNNEL_LOGGER_MQH__
#define __VP_EA_FUNNEL_LOGGER_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| VP Funnel Logger v2 — Full VP/Auction feature set for SHAP       |
//| Uses FileWriteString to bypass FileWrite 63-param limit          |
//+------------------------------------------------------------------+

class CVPFunnelLogger
{
private:
   string m_symbol;
   int    m_fileHandle;
   bool   m_enabled;
   int    m_logCount;

   // Helper: join fields with comma
   string J(const string a, const string b) { return a + "," + b; }

   // Compute distance from entry to nearest structural level (BOS or CHOCH) in ATR units
   double _ComputeStructDist(const SVPPipelineState &state)
   {
      double entry = state.primarySetup.entryPrice;
      double atr = state.marketData.atrProxy;
      double pointSize = state.marketData.pointSize;
      if(atr <= 0 || pointSize <= 0 || entry <= 0) return 0;
      double atrPrice = atr * pointSize;

      double bosD = (state.bosConfirmed && state.bosLevel > 0) ? MathAbs(entry - state.bosLevel) / atrPrice : 999;
      double chochD = (state.chochConfirmed && state.chochLevel > 0) ? MathAbs(entry - state.chochLevel) / atrPrice : 999;
      double best = MathMin(bosD, chochD);
      return (best < 999) ? best : 0;
   }

   // ── Composite helpers matching data_loader._build_structure_composites() ──

   // bosQuality = bosScore * bosConfirmed * proximity, signed by bosBullish
   // proximity = clamp(1 - structDistATR/3, 0, 1)
   string _ComputeBosQuality(const SVPPipelineState &state)
   {
      if(!state.bosConfirmed) return "0.000";
      double structDist = _ComputeStructDist(state);
      double prox = MathMax(0.0, MathMin(1.0, 1.0 - structDist / 3.0));
      double magnitude = MathMax(0.0, MathMin(1.0, state.bosScore)) * prox;
      double sign = state.bosBullish ? 1.0 : -1.0;
      return DoubleToString(magnitude * sign, 4);
   }

   // chochQuality = chochScore * chochConfirmed * proximity, signed by chochBullish
   string _ComputeChochQuality(const SVPPipelineState &state)
   {
      if(!state.chochConfirmed) return "0.000";
      double entry = state.primarySetup.entryPrice;
      double atr = state.marketData.atrProxy * state.marketData.pointSize;
      double prox = 0.5;
      if(state.chochLevel > 0 && atr > 0)
         prox = MathMax(0.0, MathMin(1.0, 1.0 - MathAbs(entry - state.chochLevel) / (atr * 3.0)));
      double magnitude = MathMax(0.0, MathMin(1.0, state.chochScore)) * prox;
      double sign = state.chochBullish ? 1.0 : -1.0;
      return DoubleToString(magnitude * sign, 4);
   }

   // structAlign = 1.0 if structure direction agrees with trend, 0.0 if opposed, 0.5 if neutral
   string _ComputeStructAlign(const SVPPipelineState &state)
   {
      double bosSign   = state.bosConfirmed   ? (state.bosBullish   ? 1.0 : -1.0) : 0.0;
      double chochSign = state.chochConfirmed ? (state.chochBullish ? 1.0 : -1.0) : 0.0;
      double structSign = 0.0;
      if(bosSign   != 0) structSign += bosSign;
      if(chochSign != 0) structSign += chochSign;
      if(structSign > 0) structSign = 1.0;
      else if(structSign < 0) structSign = -1.0;

      int trend = state.trendDirection;
      double align;
      if(trend == 0)        align = 0.5;
      else if((trend > 0 && structSign > 0) || (trend < 0 && structSign < 0)) align = 1.0;
      else if(structSign == 0) align = 0.5;
      else                  align = 0.0;
      return DoubleToString(align, 4);
   }

public:
   CVPFunnelLogger(void) { m_fileHandle = INVALID_HANDLE; m_enabled = false; m_logCount = 0; }

   void Bootstrap(const string symbol, bool enabled = true)
   {
      m_symbol = symbol;
      m_enabled = enabled;
      if (!m_enabled) return;

      string filename = "VP_Funnel_" + symbol + ".csv";
      m_fileHandle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_COMMON);
      if (m_fileHandle != INVALID_HANDLE)
      {
         string hdr = "ticket,signalId,timestamp,symbol,setupType,direction,trailStyle,session,"
            "entryPrice,SL,TP,RR,thesis,"
            "vpPOC,vpVAH,vpVAL,vpInsideVA,vpDistToHVN,vpDistToLVN,vpPriceVsPOC,vpDailyPOC,"
            "vpCompPOC,vpCompVAH,vpCompVAL,vpCompInsideVA,vpDistCompPOC,"
            "vpThinnessRatio,vpProfileShape,vpBestHVN,vpBestHVNScore,"
            "vpVAOverlapRatio,vpVAOverlapBias,vpRangePOC,vpBreakoutPOC,vpPullbackPOC,"
            "vpNearestNakedPOC,vpDistNakedPOC_ATR,"
            "vpUpthrust,vpSpring,vpCompPosition,vpMigrationConf,"
            "vpDevPOCDir,vpDevPOCSlope,vpMigrationScore,"
            "auctAcceptance,auctState,auctBalance,auctProfileShape,auctShapeConf,"
            "auctMajorHVN,auctMajorLVN,auctDistHVN,auctDistLVN,"
            "auctVAExpRate,auctVAState,auctFailure,"
            "auctRegime,auctRegimeConf,auctExpReward,auctExpMoveATR,auctTargetProb,"
            "auctTradeQuality,auctTradeGrade,auctTargetPrice,auctTargetType,auctTargetConf,"
            "auctProfitZone,auctExhaustion,auctContinuation,auctReversalRisk,"
            "auctHVNStrength,auctLVNStrength,"
            "vpLTPOC60d,vpLTPOC30d,vpLTPOC10d,"
            "vpLTPOCVelocity,vpLTPOCAcceleration,vpLTPOCMigration,"
            "vpLTMajorHVNPrice,vpLTMajorHVNStrength,vpLTMajorLVNPrice,vpLTMajorLVNStrength,"
            "vpLTNearestZonePrice,vpLTNearestZoneStrength,vpLTNearestZoneDir,"
            "vpLTAcceptanceAtPrice,vpLTValid,"
            "profilerArchetype,profilerSamples,profilerMigMean,profilerBalMean,profilerTQMean,"
            "spreadPoints,avgSpread,spreadToATR,atrProxy,dataQuality,"
            "bosConfirmed,bosBullish,bosScore,bosLevel,"
            "chochConfirmed,chochBullish,chochScore,chochLevel,trendDirection,"
            "structDistATR,"
            "ltTransitionScore,ltBalanceStability,ltTrendDuration,ltTrendExhaustion,"
            // ─── Bonus Engines (research) ───
            "structureBias,"
            "msSpreadScore,msTickVelocity,msTickImbalance,msLiqVacuum,msCompression,"
            "ofDeltaProxy,ofCvdProxy,ofAbsorption,ofExhaustion,ofParticipation,ofDivergence,ofBullDiv,ofBearDiv,ofFlowIntensity,"
            "liqDensity,liqSweep,liqStopCluster,liqEqualHL,liqSessionLiq,liqPremDisc,"
            "smOrderBlock,smFVG,smMitigation,smBreakerBlock,smRejectionBlock,smZoneQuality,"
            // ─── Python-compatible composites (computed inline) ───
            // These match data_loader._build_structure_composites() and
            // _build_engine_composites() so pipeline gates using them work in EA.
            "bosQuality,chochQuality,structAlign,"
            "msContext,ofContext,liqContext,smContext\n";
         FileWriteString(m_fileHandle, hdr);
      }
   }

   // trailStyle: ETrailingStyle assigned to the fired position (-1/0/1), or 99
   // when unknown (e.g. trigger logged with no execution).
   // signalId: shared id linking this funnel row to its (up to 3) trade rows.
   void LogSetup(const SVPPipelineState &state, ulong ticket = 0, int trailStyle = 99,
                 const string signalId = "")
   {
      if (!m_enabled || m_fileHandle == INVALID_HANDLE) return;
      if (!state.primarySetup.isValid) return;

      bool isBuy = (state.primarySetup.stopLoss < state.primarySetup.entryPrice);
      string d = ","; // delimiter

      string line =
         IntegerToString((long)ticket) + d +
         signalId + d +
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + d +
         m_symbol + d +
         SetupTypeToString(state.primarySetup.setupType) + d +
         (isBuy ? "BUY" : "SELL") + d +
         IntegerToString(trailStyle) + d +
         IntegerToString((int)state.session) + d +
         // Entry
         DoubleToString(state.primarySetup.entryPrice, 5) + d +
         DoubleToString(state.primarySetup.stopLoss, 5) + d +
         DoubleToString(state.primarySetup.takeProfit, 5) + d +
         DoubleToString(state.primarySetup.riskReward, 2) + d +
         DoubleToString(state.winProbability, 3) + d +
         // VP Core
         DoubleToString(state.vpPOC, 5) + d +
         DoubleToString(state.vpVAH, 5) + d +
         DoubleToString(state.vpVAL, 5) + d +
         (state.vpInsideVA ? "1" : "0") + d +
         DoubleToString(state.vpDistToHVN_ATR, 3) + d +
         DoubleToString(state.vpDistToLVN_ATR, 3) + d +
         DoubleToString(state.vpPriceVsPOC, 4) + d +
         DoubleToString(state.vpDailyPOC, 5) + d +
         // Composite
         DoubleToString(state.vpCompositePOC, 5) + d +
         DoubleToString(state.vpCompositeVAH, 5) + d +
         DoubleToString(state.vpCompositeVAL, 5) + d +
         (state.vpCompositeInsideVA ? "1" : "0") + d +
         DoubleToString(state.vpDistToCompositePOC_ATR, 3) + d +
         // VP Enhancements
         DoubleToString(state.vpThinnessRatio, 3) + d +
         IntegerToString(state.vpProfileShape) + d +
         DoubleToString(state.vpBestHVN, 5) + d +
         DoubleToString(state.vpBestHVNScore, 3) + d +
         DoubleToString(state.vpVAOverlapRatio, 3) + d +
         IntegerToString(state.vpVAOverlapBias) + d +
         DoubleToString(state.vpRangePOC, 5) + d +
         DoubleToString(state.vpBreakoutPOC, 5) + d +
         DoubleToString(state.vpPullbackPOC, 5) + d +
         DoubleToString(state.vpNearestNakedPOC, 5) + d +
         DoubleToString(state.vpDistToNakedPOC_ATR, 3) + d +
         (state.vpUpthrustDetected ? "1" : "0") + d +
         (state.vpSpringDetected ? "1" : "0") + d +
         IntegerToString(state.vpCompositePosition) + d +
         DoubleToString(state.vpMigrationConfidence, 3) + d +
         // DevPOC
         DoubleToString(state.vpDevPOCDirection, 4) + d +
         DoubleToString(state.vpDevPOCSlope, 4) + d +
         DoubleToString(state.vpMigrationScore, 3) + d +
         // Auction
         DoubleToString(state.auctAcceptanceScore, 3) + d +
         IntegerToString(state.auctState) + d +
         DoubleToString(state.auctBalanceScore, 3) + d +
         IntegerToString(state.auctProfileShape) + d +
         DoubleToString(state.auctProfileShapeConf, 3) + d +
         DoubleToString(state.auctMajorHVN, 5) + d +
         DoubleToString(state.auctMajorLVN, 5) + d +
         DoubleToString(state.auctDistToMajorHVN_ATR, 3) + d +
         DoubleToString(state.auctDistToMajorLVN_ATR, 3) + d +
         DoubleToString(state.auctVAExpansionRate, 4) + d +
         IntegerToString(state.auctValueAreaState) + d +
         DoubleToString(state.auctFailureScore, 3) + d +
         IntegerToString(state.auctRegime) + d +
         DoubleToString(state.auctRegimeConfidence, 3) + d +
         DoubleToString(state.auctExpectedReward, 3) + d +
         DoubleToString(state.auctExpectedMoveATR, 3) + d +
         DoubleToString(state.auctTargetProbability, 3) + d +
         DoubleToString(state.auctTradeQuality, 3) + d +
         IntegerToString(state.auctTradeGrade) + d +
         DoubleToString(state.auctTargetPrice, 5) + d +
         IntegerToString(state.auctTargetType) + d +
         DoubleToString(state.auctTargetConfidence, 3) + d +
         DoubleToString(state.auctProfitZoneScore, 3) + d +
         DoubleToString(state.auctExhaustionScore, 3) + d +
         DoubleToString(state.auctContinuationScore, 3) + d +
         DoubleToString(state.auctReversalRiskScore, 3) + d +
         DoubleToString(state.auctHVNClusterStrength, 3) + d +
         DoubleToString(state.auctLVNClusterStrength, 3) + d +
         // Long-Term
         DoubleToString(state.vpLTPOC60d, 5) + d +
         DoubleToString(state.vpLTPOC30d, 5) + d +
         DoubleToString(state.vpLTPOC10d, 5) + d +
         DoubleToString(state.vpLTPOCVelocity, 4) + d +
         DoubleToString(state.vpLTPOCAcceleration, 4) + d +
         IntegerToString(state.vpLTPOCMigration) + d +
         DoubleToString(state.vpLTMajorHVNPrice, 5) + d +
         DoubleToString(state.vpLTMajorHVNStrength, 3) + d +
         DoubleToString(state.vpLTMajorLVNPrice, 5) + d +
         DoubleToString(state.vpLTMajorLVNStrength, 3) + d +
         DoubleToString(state.vpLTNearestZonePrice, 5) + d +
         DoubleToString(state.vpLTNearestZoneStrength, 3) + d +
         IntegerToString(state.vpLTNearestZoneDir) + d +
         DoubleToString(state.vpLTAcceptanceAtPrice, 3) + d +
         (state.vpLTValid ? "1" : "0") + d +
         // Profiler
         IntegerToString((int)state.profiler.archetype) + d +
         IntegerToString(state.profiler.samplesCollected) + d +
         DoubleToString(state.profiler.migrationMean, 3) + d +
         DoubleToString(state.profiler.balanceMean, 3) + d +
         DoubleToString(state.profiler.tradeQualityMean, 3) + d +
         // Market
         DoubleToString(state.marketData.spreadPoints, 1) + d +
         DoubleToString(state.marketData.avgSpreadPoints, 1) + d +
         DoubleToString(state.marketData.atrProxy > 0 ? state.marketData.spreadPoints / state.marketData.atrProxy : 0, 4) + d +
         DoubleToString(state.marketData.atrProxy, 1) + d +
         DoubleToString(state.marketData.dataQualityScore, 3) + d +
         // Structure
         (state.bosConfirmed ? "1" : "0") + d +
         (state.bosBullish ? "1" : "0") + d +
         DoubleToString(state.bosScore, 3) + d +
         DoubleToString(state.bosLevel, 5) + d +
         (state.chochConfirmed ? "1" : "0") + d +
         (state.chochBullish ? "1" : "0") + d +
         DoubleToString(state.chochScore, 3) + d +
         DoubleToString(state.chochLevel, 5) + d +
         IntegerToString(state.trendDirection) + d +
         // Structure distance (entry timing vs structure confirmation)
         DoubleToString(_ComputeStructDist(state), 3) + d +
         // LT Transition
         DoubleToString(state.vpLTTransitionScore, 3) + d +
         DoubleToString(state.vpLTBalanceStability, 3) + d +
         DoubleToString(state.vpLTTrendDuration, 1) + d +
         DoubleToString(state.vpLTTrendExhaustion, 3) + d +
         // ─── Bonus Engines (research) ───
         DoubleToString(state.structure.structureBias, 3) + d +
         // Microstructure
         DoubleToString(state.microstructure.spreadScore, 3) + d +
         DoubleToString(state.microstructure.tickVelocity, 3) + d +
         DoubleToString(state.microstructure.tickImbalance, 3) + d +
         DoubleToString(state.microstructure.liquidityVacuumScore, 3) + d +
         DoubleToString(state.microstructure.compressionScore, 3) + d +
         // Order flow
         DoubleToString(state.flow.deltaProxy, 3) + d +
         DoubleToString(state.flow.cvdProxy, 3) + d +
         DoubleToString(state.flow.absorptionScore, 3) + d +
         DoubleToString(state.flow.exhaustionScore, 3) + d +
         DoubleToString(state.flow.participationScore, 3) + d +
         DoubleToString(state.flow.divergenceScore, 3) + d +
         (state.flow.bullishDivergence ? "1" : "0") + d +
         (state.flow.bearishDivergence ? "1" : "0") + d +
         DoubleToString(state.flow.flowIntensityScore, 3) + d +
         // Liquidity
         DoubleToString(state.liquidity.liquidityDensity, 3) + d +
         DoubleToString(state.liquidity.sweepScore, 3) + d +
         DoubleToString(state.liquidity.stopClusterScore, 3) + d +
         DoubleToString(state.liquidity.equalHighLowScore, 3) + d +
         DoubleToString(state.liquidity.sessionLiquidityScore, 3) + d +
         DoubleToString(state.liquidity.premiumDiscountScore, 3) + d +
         // Smart money
         DoubleToString(state.smartMoney.orderBlockScore, 3) + d +
         DoubleToString(state.smartMoney.fvgScore, 3) + d +
         DoubleToString(state.smartMoney.mitigationScore, 3) + d +
         DoubleToString(state.smartMoney.breakerBlockScore, 3) + d +
         DoubleToString(state.smartMoney.rejectionBlockScore, 3) + d +
         DoubleToString(state.smartMoney.zoneQualityScore, 3) + d +
         // ─── Composite features (mirror of data_loader Python composites) ───
         // bosQuality = bosScore * bosConfirmed * proximity, signed by bosBullish
         // Uses structDistATR as proximity proxy: prox = clamp(1 - dist/3, 0, 1)
         _ComputeBosQuality(state) + d +
         _ComputeChochQuality(state) + d +
         _ComputeStructAlign(state) + d +
         // msContext = mean(msSpreadScore, msTickVelocity, msTickImbalance, msLiqVacuum)
         DoubleToString((state.microstructure.spreadScore + state.microstructure.tickVelocity +
                         state.microstructure.tickImbalance + state.microstructure.liquidityVacuumScore) / 4.0, 4) + d +
         // ofContext = mean(ofDeltaProxy, ofCvdProxy, ofAbsorption, ofExhaustion, ofParticipation, ofDivergence)
         DoubleToString((state.flow.deltaProxy + state.flow.cvdProxy + state.flow.absorptionScore +
                         state.flow.exhaustionScore + state.flow.participationScore + state.flow.divergenceScore) / 6.0, 4) + d +
         // liqContext = mean(liqDensity, liqStopCluster, liqEqualHL, liqSessionLiq, liqPremDisc)
         DoubleToString((state.liquidity.liquidityDensity + state.liquidity.stopClusterScore +
                         state.liquidity.equalHighLowScore + state.liquidity.sessionLiquidityScore +
                         state.liquidity.premiumDiscountScore) / 5.0, 4) + d +
         // smContext = mean(smOrderBlock, smFVG, smMitigation, smBreakerBlock, smRejectionBlock)
         DoubleToString((state.smartMoney.orderBlockScore + state.smartMoney.fvgScore +
                         state.smartMoney.mitigationScore + state.smartMoney.breakerBlockScore +
                         state.smartMoney.rejectionBlockScore) / 5.0, 4) + "\n";

      FileWriteString(m_fileHandle, line);
      m_logCount++;
   }

   void Flush(void)
   {
      if (m_fileHandle != INVALID_HANDLE)
      {
         FileFlush(m_fileHandle);
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
         PrintFormat("[VP_FUNNEL] %s flushed %d rows", m_symbol, m_logCount);
      }
   }
};

#endif
