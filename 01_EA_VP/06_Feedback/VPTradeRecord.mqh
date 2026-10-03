#ifndef __VP_EA_TRADE_RECORD_MQH__
#define __VP_EA_TRADE_RECORD_MQH__

#include "..\Config\GlobalParameters.mqh"

struct SVPTradeRecord
{
   // ─── Trade Identity ───
   ulong    ticket;
   string   signalId;        // links this trade to its funnel signal row (1 signal -> up to 3 trades)
   string   symbol;
   ESetupType setupType;
   int      trailingStyle;   // ETrailingStyle applied to this position (-1/0/1)
   bool     isBuy;
   double   entryPrice;
   double   exitPrice;
   datetime entryTime;
   datetime exitTime;
   int      holdingMinutes;

   // ─── PnL ───
   double   profitUSD;
   double   profitPips;
   double   maeATR;
   double   mfeATR;
   string   exitReason;

   // ─── Entry State: VP Core ───
   double   entryVpPOC;
   double   entryVpVAH;
   double   entryVpVAL;
   bool     entryVpInsideVA;
   double   entryVpDistHVN;
   double   entryVpDistLVN;
   double   entryVpBestHVN;
   double   entryVpThinnessRatio;
   int      entryVpOverlapBias;
   double   entryVpMigrationConf;
   double   entryVpDevPOCDir;
   int      entryVpProfileShape;
   bool     entryVpUpthrust;
   bool     entryVpSpring;
   int      entryVpCompPosition;
   double   entryVpBreakoutPOC;

   // ─── Entry State: Auction ───
   int      entryRegime;
   double   entryRegimeConf;
   double   entryTradeQuality;
   int      entryTradeGrade;
   double   entryBalanceScore;
   double   entryContinuation;
   double   entryReversalRisk;
   double   entryExhaustion;
   double   entryFailure;
   double   entryVAExpRate;
   double   entryTargetPrice;
   double   entryTargetConf;
   double   entryExpReward;

   // ─── Entry State: Long-Term ───
   bool     entryLTValid;
   int      entryLTPOCMigration;
   double   entryLTNearestZoneStrength;

   // ─── Entry State: Profiler ───
   EVPSymbolArchetype archetype;
   int      profilerSamples;

   // ─── Entry Thesis ───
   double   thesis;
   double   riskReward;
};

#endif
