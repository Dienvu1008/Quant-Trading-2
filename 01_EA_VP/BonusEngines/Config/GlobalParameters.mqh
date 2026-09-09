#ifndef __VP_EA_BONUS_GLOBALPARAMETERS_MQH__
#define __VP_EA_BONUS_GLOBALPARAMETERS_MQH__

//+------------------------------------------------------------------+
//| BonusEngines adapter shim                                        |
//|                                                                  |
//| The BonusEngines were written for the old 01_EA_V2 pipeline      |
//| (CPipelineModuleBase + SPipelineState + free helpers). This shim |
//| maps that interface onto the VP EA pipeline so the engines can   |
//| run unmodified (aside from being wired into VPTradingPipeline).  |
//|                                                                  |
//|   SPipelineState      -> SVPPipelineState  (via #define)         |
//|   CPipelineModuleBase  -> CVPModuleBase     (via #define)        |
//|                                                                  |
//| Plus the free helpers/enums the engines expect: Clamp01,         |
//| EVENT_* market-event ids, EFlowState, EEntryArchetype, the       |
//| session-time helpers, and a lightweight CAuctionThesisManager    |
//| stub (the engines already neutered thesisHealth, so the stub     |
//| just returns a neutral health of 1.0).                           |
//+------------------------------------------------------------------+

// Pull in the VP EA's real config: SVPPipelineState, CVPModuleBase,
// ESessionType, EAuctionRegime, EProfileShape, EValueAreaState, etc.
#include "..\..\Config\GlobalParameters.mqh"

// ─── Interface aliasing ────────────────────────────────────────────
// The engines declare `class CX : public CPipelineModuleBase` and
// `virtual bool Execute(SPipelineState &state)`. Map both names to the
// VP EA equivalents so the engines compile against the VP pipeline.
#define CPipelineModuleBase CVPModuleBase
#define SPipelineState      SVPPipelineState

// NOTE: Clamp01 is provided by the VP EA's Utils/MathUtils.mqh (pulled in via
// ..\..\Config\GlobalParameters.mqh above), so it is NOT redefined here.

// ─── Market Event IDs used by BonusEngines but NOT already defined in VPEnums.mqh ──
// VPEnums.mqh already #defines: EVENT_BOS(1), EVENT_CHOCH(2), EVENT_SWEEP(3),
// EVENT_STOP_CLUSTER(4), EVENT_COMPRESSION(5), EVENT_EXHAUSTION(6),
// EVENT_ABSORPTION(7), EVENT_DIVERGENCE(8). We only add the missing ones the
// bonus engines reference, using non-colliding ids (20+). These are only used
// as tags in the pendingEvent queue (research), so exact values don't matter.
#ifndef EVENT_LIQUIDITY_VACUUM
   #define EVENT_LIQUIDITY_VACUUM   20
#endif
#ifndef EVENT_EQUAL_HIGH_LOW
   #define EVENT_EQUAL_HIGH_LOW     21
#endif
#ifndef EVENT_LIQUIDITY_DENSITY
   #define EVENT_LIQUIDITY_DENSITY  22
#endif
#ifndef EVENT_PREMIUM
   #define EVENT_PREMIUM            23
#endif
#ifndef EVENT_DISCOUNT
   #define EVENT_DISCOUNT           24
#endif
#ifndef EVENT_SESSION_LIQUIDITY
   #define EVENT_SESSION_LIQUIDITY  25
#endif
#ifndef EVENT_PARTICIPATION
   #define EVENT_PARTICIPATION      26
#endif
#ifndef EVENT_FVG
   #define EVENT_FVG                27
#endif
#ifndef EVENT_ORDERBLOCK
   #define EVENT_ORDERBLOCK         28
#endif
#ifndef EVENT_ZONE_QUALITY
   #define EVENT_ZONE_QUALITY       29
#endif

// ─── Flow state (used by OrderFlow engines) ────────────────────────
enum EFlowState
{
   FLOW_STATE_BALANCED = 0,
   FLOW_STATE_ACCUMULATION,
   FLOW_STATE_DISTRIBUTION
};

// NOTE: EEntryArchetype is NOT defined here — the VP EA's real
// AuctionThesisManager (02_VolumeProfile/AuctionThesisManager.mqh) already
// defines it, and the BonusEngines/VolumeProfile shim re-exports that file.

// ─── Session-time helpers (only SessionLiquidityDetector needs these) ──
#define SESSION_ASIAN_START_GMT    23
#define SESSION_ASIAN_END_GMT      7
#define SESSION_LONDON_START_GMT   7
#define SESSION_LONDON_END_GMT     15
#define SESSION_NY_START_GMT       12
#define SESSION_NY_END_GMT         21
#define SESSION_OVERLAP_START_GMT  12
#define SESSION_OVERLAP_END_GMT    15

int _BonusLastSundayOfMonth(int year, int month)
{
   int daysInMonth = 31;
   if(month == 4 || month == 6 || month == 9 || month == 11) daysInMonth = 30;
   else if(month == 2)
   {
      daysInMonth = 28;
      if((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) daysInMonth = 29;
   }
   MqlDateTime dt;
   dt.year = year; dt.mon = month; dt.day = daysInMonth;
   dt.hour = 12; dt.min = 0; dt.sec = 0;
   datetime t = StructToTime(dt);
   TimeToStruct(t, dt);
   return daysInMonth - dt.day_of_week;
}

bool _BonusIsEuropeanDST(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int lastSunMar = _BonusLastSundayOfMonth(dt.year, 3);
   int lastSunOct = _BonusLastSundayOfMonth(dt.year, 10);
   int md = dt.mon * 100 + dt.day;
   int dstStart = 3 * 100 + lastSunMar;
   int dstEnd   = 10 * 100 + lastSunOct;
   if(md > dstStart && md < dstEnd) return true;
   if(md < dstStart || md > dstEnd) return false;
   if(md == dstStart) return (dt.hour >= 3);
   if(md == dstEnd)   return (dt.hour < 4);
   return false;
}

int GetBrokerGMTOffsetForTime(datetime t)
{
   return _BonusIsEuropeanDST(t) ? 3 : 2;
}

int GetCurrentGMTHour(void)
{
   datetime srv = TimeCurrent();
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      int offset = GetBrokerGMTOffsetForTime(srv);
      MqlDateTime dt; TimeToStruct(srv, dt);
      return (dt.hour - offset + 24) % 24;
   }
   datetime gmt = TimeGMT();
   MqlDateTime gmtDt; TimeToStruct(gmt, gmtDt);
   return gmtDt.hour;
}

int DetectBrokerGMTOffset(void)
{
   return GetBrokerGMTOffsetForTime(TimeCurrent());
}

ESessionType ClassifySessionGMT(int gmtHour)
{
   if(gmtHour >= SESSION_OVERLAP_START_GMT && gmtHour < SESSION_OVERLAP_END_GMT)
      return SESSION_OVERLAP;
   if(gmtHour >= SESSION_LONDON_START_GMT && gmtHour < SESSION_OVERLAP_START_GMT)
      return SESSION_LONDON;
   if(gmtHour >= SESSION_OVERLAP_END_GMT && gmtHour < SESSION_NY_END_GMT)
      return SESSION_NEWYORK;
   if(gmtHour >= SESSION_ASIAN_START_GMT || gmtHour < SESSION_ASIAN_END_GMT)
      return SESSION_ASIAN;
   return SESSION_ASIAN;
}

#endif
