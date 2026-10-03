#ifndef __VP_EA_FAILURE_ATTRIBUTION_MQH__
#define __VP_EA_FAILURE_ATTRIBUTION_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "VPTradeRecord.mqh"

//+------------------------------------------------------------------+
//| VP Failure Attribution v2 — Full entry + exit state logging      |
//| Uses FileWriteString to bypass FileWrite 63-param limit          |
//+------------------------------------------------------------------+

class CVPFailureAttribution
{
private:
   string m_symbol;
   int    m_fileHandle;
   int    m_tradeCount;

public:
   CVPFailureAttribution(void) { m_fileHandle = INVALID_HANDLE; m_tradeCount = 0; }

   void Bootstrap(const string symbol)
   {
      m_symbol = symbol;
      string filename = "VP_Trades_" + symbol + ".csv";
      m_fileHandle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_COMMON);
      if (m_fileHandle != INVALID_HANDLE)
      {
         string hdr =
            "ticket,signalId,symbol,setupType,direction,trailStyle,entryTime,exitTime,holdingMinutes,"
            "entryPrice,exitPrice,profitPips,profitUSD,maeATR,mfeATR,exitReason,"
            "entryVpPOC,entryVpVAH,entryVpVAL,entryVpInsideVA,"
            "entryVpDistHVN,entryVpDistLVN,entryVpBestHVN,entryVpThinnessRatio,"
            "entryVpOverlapBias,entryVpMigrationConf,entryVpDevPOCDir,entryVpProfileShape,"
            "entryVpUpthrust,entryVpSpring,entryVpCompPosition,entryVpBreakoutPOC,"
            "entryAuctRegime,entryAuctRegimeConf,entryAuctTradeQuality,entryAuctTradeGrade,"
            "entryAuctBalance,entryAuctContinuation,entryAuctReversalRisk,"
            "entryAuctExhaustion,entryAuctFailure,entryAuctVAExpRate,"
            "entryAuctTargetPrice,entryAuctTargetConf,entryAuctExpReward,"
            "entryLTValid,entryLTPOCMigration,entryLTNearestZoneStrength,"
            "entryArchetype,entryProfilerSamples,thesis,riskReward,"
            "exitAuctRegime,exitAuctFailure,exitAuctContinuation,"
            "exitAuctReversalRisk,exitAuctExhaustion,exitAuctBalance,"
            "exitVpMigrationConf,exitVpInsideVA,exitVpDevPOCDir,"
            "exitSpreadPoints,exitAtrProxy\n";
         FileWriteString(m_fileHandle, hdr);
      }
   }

   void OnTradeClosed(const SVPTradeRecord &rec, const SVPPipelineState &exitState)
   {
      if (m_fileHandle == INVALID_HANDLE) return;

      string d = ",";
      string dir = rec.isBuy ? "BUY" : "SELL";

      string line =
         IntegerToString((long)rec.ticket) + d +
         rec.signalId + d +
         rec.symbol + d +
         SetupTypeToString(rec.setupType) + d +
         dir + d +
         IntegerToString(rec.trailingStyle) + d +
         TimeToString(rec.entryTime, TIME_DATE|TIME_SECONDS) + d +
         TimeToString(rec.exitTime, TIME_DATE|TIME_SECONDS) + d +
         IntegerToString(rec.holdingMinutes) + d +
         // PnL
         DoubleToString(rec.entryPrice, 5) + d +
         DoubleToString(rec.exitPrice, 5) + d +
         DoubleToString(rec.profitPips, 1) + d +
         DoubleToString(rec.profitUSD, 2) + d +
         DoubleToString(rec.maeATR, 3) + d +
         DoubleToString(rec.mfeATR, 3) + d +
         rec.exitReason + d +
         // Entry VP Core
         DoubleToString(rec.entryVpPOC, 5) + d +
         DoubleToString(rec.entryVpVAH, 5) + d +
         DoubleToString(rec.entryVpVAL, 5) + d +
         (rec.entryVpInsideVA ? "1" : "0") + d +
         DoubleToString(rec.entryVpDistHVN, 3) + d +
         DoubleToString(rec.entryVpDistLVN, 3) + d +
         DoubleToString(rec.entryVpBestHVN, 5) + d +
         DoubleToString(rec.entryVpThinnessRatio, 3) + d +
         IntegerToString(rec.entryVpOverlapBias) + d +
         DoubleToString(rec.entryVpMigrationConf, 3) + d +
         DoubleToString(rec.entryVpDevPOCDir, 4) + d +
         IntegerToString(rec.entryVpProfileShape) + d +
         (rec.entryVpUpthrust ? "1" : "0") + d +
         (rec.entryVpSpring ? "1" : "0") + d +
         IntegerToString(rec.entryVpCompPosition) + d +
         DoubleToString(rec.entryVpBreakoutPOC, 5) + d +
         // Entry Auction
         IntegerToString(rec.entryRegime) + d +
         DoubleToString(rec.entryRegimeConf, 3) + d +
         DoubleToString(rec.entryTradeQuality, 3) + d +
         IntegerToString(rec.entryTradeGrade) + d +
         DoubleToString(rec.entryBalanceScore, 3) + d +
         DoubleToString(rec.entryContinuation, 3) + d +
         DoubleToString(rec.entryReversalRisk, 3) + d +
         DoubleToString(rec.entryExhaustion, 3) + d +
         DoubleToString(rec.entryFailure, 3) + d +
         DoubleToString(rec.entryVAExpRate, 4) + d +
         DoubleToString(rec.entryTargetPrice, 5) + d +
         DoubleToString(rec.entryTargetConf, 3) + d +
         DoubleToString(rec.entryExpReward, 3) + d +
         // Entry LT
         (rec.entryLTValid ? "1" : "0") + d +
         IntegerToString(rec.entryLTPOCMigration) + d +
         DoubleToString(rec.entryLTNearestZoneStrength, 3) + d +
         // Profiler
         IntegerToString((int)rec.archetype) + d +
         IntegerToString(rec.profilerSamples) + d +
         DoubleToString(rec.thesis, 3) + d +
         DoubleToString(rec.riskReward, 2) + d +
         // Exit State
         IntegerToString(exitState.auctRegime) + d +
         DoubleToString(exitState.auctFailureScore, 3) + d +
         DoubleToString(exitState.auctContinuationScore, 3) + d +
         DoubleToString(exitState.auctReversalRiskScore, 3) + d +
         DoubleToString(exitState.auctExhaustionScore, 3) + d +
         DoubleToString(exitState.auctBalanceScore, 3) + d +
         DoubleToString(exitState.vpMigrationConfidence, 3) + d +
         (exitState.vpInsideVA ? "1" : "0") + d +
         DoubleToString(exitState.vpDevPOCDirection, 4) + d +
         // Market at exit
         DoubleToString(exitState.marketData.spreadPoints, 1) + d +
         DoubleToString(exitState.marketData.atrProxy, 1) + "\n";

      FileWriteString(m_fileHandle, line);
      m_tradeCount++;
   }

   void Flush(void)
   {
      if (m_fileHandle != INVALID_HANDLE)
      {
         FileFlush(m_fileHandle);
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
         PrintFormat("[VP_ATTR] %s flushed %d trades", m_symbol, m_tradeCount);
      }
   }
};

#endif
