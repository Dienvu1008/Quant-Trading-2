
//+------------------------------------------------------------------+
//| AuctionTrailingStopEngine v4.7 — Event-Driven                    |
//| Tích hợp toàn bộ sự kiện từ EventDefinitions                     |
//| Đã sửa lỗi ghi đè reversalRisk/continuationBias                 |
//+------------------------------------------------------------------+
#ifndef __EA_ROOT_AUCTIONTRAILINGSTOP_MQH__
#define __EA_ROOT_AUCTIONTRAILINGSTOP_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "AuctionEnums.mqh"


enum ETrailingStyle
  {
   TRAIL_STYLE_DISABLED     = -1,  // no trailing — hold to TP/SL only
   TRAIL_STYLE_CONSERVATIVE = 0,
   TRAIL_STYLE_EXPANSION    = 1
  };

#define STRUCT_HISTORY_SIZE 10

struct SStructureHistory
  {
   double poc[STRUCT_HISTORY_SIZE];
   double hvn[STRUCT_HISTORY_SIZE];
   double lvn[STRUCT_HISTORY_SIZE];
   int    writeIdx;
   int    count;
  };

struct STrailingDecision
  {
   bool   shouldMoveStop;
   bool   shouldExitImmediately;
   double newStopPrice;
   double trailingStrength;
   double continuationBias;
   double reversalRisk;
   EAuctionRegime trailingRegime;
   string reason;
  };

struct SSmoothedSignals
  {
   double continuation;
   double exhaustion;
   double reversalRisk;
   double failureScore;
   int    regimePersist;
  };

struct STrailingContext
  {
   double bid;
   double ask;
   bool   isBuy;
   double entryPrice;
   double currentSL;
   double floatingProfit;
   double atr;            // atrProxy * pointSize (giữ nguyên chuẩn hóa)
   double pointSize;
   bool   isRunnerPosition;
  };

#define TRAIL_EMA_ALPHA          0.15
#define TRAIL_EMA_ALPHA_EXP      0.08
#define TRAIL_MIN_MOVEMENT       0.05
#define TRAIL_MIN_MOVEMENT_EXP   0.25
#define TRAIL_REGIME_PERSIST     3
#define TRAIL_REGIME_PERSIST_EXP 6
#define TRAIL_ATR_BUFFER         0.10
#define TRAIL_ATR_BUFFER_EXP     0.25

class CAuctionTrailingStopEngine
  {
private:
   ETrailingStyle    m_trailingStyle;
   SSmoothedSignals  m_smooth;
   EAuctionRegime    m_currentRegime;
   EAuctionRegime    m_pendingRegime;
   int               m_pendingCount;
   double            m_lastIssuedStop;
   int               m_trendPersistence;
   int               m_exhaustionPersistence;
   bool              m_profitExpansionMode;
   SStructureHistory m_structHistory;
   int               m_updateCounter;

   bool   IsExpansion(void)      const { return m_trailingStyle == TRAIL_STYLE_EXPANSION; }
   double GetEmaAlpha(void)      const { return IsExpansion() ? TRAIL_EMA_ALPHA_EXP : TRAIL_EMA_ALPHA; }
   double GetMinMovement(void)   const { return IsExpansion() ? TRAIL_MIN_MOVEMENT_EXP : TRAIL_MIN_MOVEMENT; }
   double GetAtrBuffer(void)     const { return IsExpansion() ? TRAIL_ATR_BUFFER_EXP : TRAIL_ATR_BUFFER; }
   int    GetRegimePersist(void) const { return IsExpansion() ? TRAIL_REGIME_PERSIST_EXP : TRAIL_REGIME_PERSIST; }

   void UpdateSmoothedSignals(const SVPPipelineState &state)
     {
      double a = GetEmaAlpha();
      m_smooth.continuation = m_smooth.continuation*(1.0-a) + state.auctContinuationScore*a;
      m_smooth.exhaustion   = m_smooth.exhaustion*(1.0-a) + state.auctExhaustionScore*a;
      m_smooth.reversalRisk = m_smooth.reversalRisk*(1.0-a) + state.auctReversalRiskScore*a;
      m_smooth.failureScore = m_smooth.failureScore*(1.0-a) + state.auctFailureScore*a;
     }

   void UpdateStructureHistory(const SVPPipelineState &state)
     {
      m_updateCounter++;
      if(m_updateCounter % 5 != 0) return;
      int idx = m_structHistory.writeIdx;
      m_structHistory.poc[idx] = state.vpPOC;
      m_structHistory.hvn[idx] = state.auctMajorHVN;
      m_structHistory.lvn[idx] = state.auctMajorLVN;
      m_structHistory.writeIdx = (idx+1) % STRUCT_HISTORY_SIZE;
      if(m_structHistory.count < STRUCT_HISTORY_SIZE) m_structHistory.count++;
     }

   double GetLaggedPOC(int lag) const
     { if(m_structHistory.count<=lag) return 0;
       return m_structHistory.poc[(m_structHistory.writeIdx-1-lag+STRUCT_HISTORY_SIZE)%STRUCT_HISTORY_SIZE]; }
   double GetLaggedLVN(int lag) const
     { if(m_structHistory.count<=lag) return 0;
       return m_structHistory.lvn[(m_structHistory.writeIdx-1-lag+STRUCT_HISTORY_SIZE)%STRUCT_HISTORY_SIZE]; }

   EAuctionRegime DetectTrailingRegime(const SVPPipelineState &state)
     {
      EAuctionRegime auctReg = (EAuctionRegime)state.auctRegime;
      double conf = state.auctRegimeConfidence;

      if(conf > 0.65)
        {
         if(auctReg==REGIME_CHAOTIC || auctReg==REGIME_EXCESS || auctReg==REGIME_FAILED_AUCTION)
            return auctReg;
         if(auctReg==REGIME_TREND_CONTINUATION && m_smooth.continuation>0.5)
            return REGIME_TREND_CONTINUATION;
         if(auctReg==REGIME_TREND_INITIATION)
            return REGIME_TREND_INITIATION;
        }

      EAuctionRegime detected = REGIME_BALANCED_ROTATION;

      if(auctReg==REGIME_CHAOTIC || auctReg==REGIME_EXCESS)
         detected = auctReg;
      else if(m_smooth.failureScore > 0.75 || auctReg==REGIME_FAILED_AUCTION)
         detected = REGIME_FAILED_AUCTION;
      else if(m_smooth.exhaustion > 0.60 && m_smooth.reversalRisk > 0.55)
         detected = REGIME_TREND_EXHAUSTION;
      else if(auctReg==REGIME_TREND_INITIATION)
         detected = REGIME_TREND_INITIATION;
      else if(state.vpBreakoutPOC > 0 && state.auctValueAreaState==(int)VA_EXPANDING)
         detected = REGIME_TREND_INITIATION;
      else if(auctReg==REGIME_TREND_CONTINUATION
              && state.auctValueAreaState==(int)VA_EXPANDING
              && m_smooth.continuation > 0.55
              && m_smooth.failureScore < 0.30)
         detected = REGIME_TREND_CONTINUATION;
      else if(auctReg==REGIME_RE_ACCUMULATION)
         detected = REGIME_RE_ACCUMULATION;
      else if(auctReg==REGIME_COMPRESSION)
         detected = REGIME_COMPRESSION;
      else if(state.auctBalanceScore > 0.75 && state.vpVAOverlapBias==0)
        { detected = (state.auctVAExpansionRate < -0.05) ? REGIME_COMPRESSION : REGIME_BALANCED_ROTATION; }

      if(IsExpansion() && m_currentRegime==REGIME_TREND_CONTINUATION)
        {
         if(detected!=REGIME_TREND_CONTINUATION && detected!=REGIME_FAILED_AUCTION
            && detected!=REGIME_CHAOTIC && m_smooth.failureScore<0.40 && m_smooth.exhaustion<0.70)
           { m_trendPersistence++;
             if(m_trendPersistence < 10) detected = REGIME_TREND_CONTINUATION;
             if(m_smooth.continuation > 0.45) m_trendPersistence = 0; }
         else m_trendPersistence = 0;
        }

      if(IsExpansion() && detected==REGIME_TREND_EXHAUSTION)
        { m_exhaustionPersistence++;
          if(m_exhaustionPersistence < 4) detected = REGIME_TREND_CONTINUATION; }
      else if(detected!=REGIME_TREND_EXHAUSTION)
         m_exhaustionPersistence = 0;

      int reqPersist = GetRegimePersist();
      if(detected != m_currentRegime)
        {
         if(detected==m_pendingRegime) m_pendingCount++;
         else { m_pendingRegime=detected; m_pendingCount=1; }
         if(detected==REGIME_FAILED_AUCTION || detected==REGIME_CHAOTIC
            || detected==REGIME_EXCESS || m_pendingCount>=reqPersist)
           { m_currentRegime=detected; m_smooth.regimePersist=0;
             if(detected==REGIME_TREND_CONTINUATION) m_trendPersistence=0; }
        }
      else
        { m_smooth.regimePersist++;
          m_pendingCount = 0;  // reset pending when stable in current regime
          if(m_currentRegime==REGIME_TREND_CONTINUATION) m_trendPersistence=0; }

      return m_currentRegime;
     }

   double GetBestStructuralSupport(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      if(ctx.isBuy)
        {
         double best = 0;
         if(state.vpBestHVN>0 && state.vpBestHVN<ctx.bid && state.vpBestHVN>best) best=state.vpBestHVN;
         if(state.vpRangeVAH>0 && state.vpRangeVAH<ctx.bid && state.vpRangeVAH>best) best=state.vpRangeVAH;
         if(state.vpBreakoutPOC>0 && state.vpBreakoutPOC<ctx.bid && state.vpBreakoutPOC>best) best=state.vpBreakoutPOC;
         if(state.vpPullbackPOC>0 && state.vpPullbackPOC<ctx.bid && state.vpPullbackPOC>best) best=state.vpPullbackPOC;
         return best;
        }
      else
        {
         double best = 1e18;
         if(state.vpBestHVN>0 && state.vpBestHVN>ctx.bid && state.vpBestHVN<best) best=state.vpBestHVN;
         if(state.vpRangeVAL>0 && state.vpRangeVAL>ctx.bid && state.vpRangeVAL<best) best=state.vpRangeVAL;
         if(state.vpBreakoutPOC>0 && state.vpBreakoutPOC>ctx.bid && state.vpBreakoutPOC<best) best=state.vpBreakoutPOC;
         if(state.vpPullbackPOC>0 && state.vpPullbackPOC>ctx.bid && state.vpPullbackPOC<best) best=state.vpPullbackPOC;
         return (best<1e18) ? best : 0;
        }
     }

   double ComputeBalancedTrail(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      double atr=ctx.atr;
      double stop = ctx.isBuy ? ctx.bid - atr*1.2 : ctx.bid + atr*1.2;
      if(ctx.isBuy)
        { if(state.vpInsideVA && state.vpVAL>0 && state.vpVAL>stop) stop=state.vpVAL-atr*TRAIL_ATR_BUFFER;
          if(state.vpPOC>0 && ctx.bid>state.vpPOC && (ctx.bid-state.vpPOC)<atr*0.5) stop=state.vpPOC-atr*0.2;
          if(state.vpUpthrustDetected||state.vpSpringDetected) stop=MathMax(stop,ctx.bid-atr*0.5); }
      else
        { if(state.vpInsideVA && state.vpVAH>0 && state.vpVAH<stop) stop=state.vpVAH+atr*TRAIL_ATR_BUFFER;
          if(state.vpPOC>0 && ctx.bid<state.vpPOC && (state.vpPOC-ctx.bid)<atr*0.5) stop=state.vpPOC+atr*0.2;
          if(state.vpUpthrustDetected||state.vpSpringDetected) stop=MathMin(stop,ctx.bid+atr*0.5); }
      return stop;
     }

   double ComputeCompressionTrail(const STrailingContext &ctx, const SVPPipelineState &state)
     { return ctx.isBuy ? ctx.bid - ctx.atr*0.6 : ctx.bid + ctx.atr*0.6; }

   double ComputeInitiationTrail(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      double atr=ctx.atr, base=atr*2.5;
      double structStop=0, pocStop=0;
      if(ctx.isBuy && state.auctMajorLVN>0 && state.auctMajorLVN<ctx.bid) structStop=state.auctMajorLVN-atr*0.2;
      else if(!ctx.isBuy && state.auctMajorLVN>0 && state.auctMajorLVN>ctx.bid) structStop=state.auctMajorLVN+atr*0.2;
      double sup=GetBestStructuralSupport(ctx,state);
      if(sup>0){ double a=ctx.isBuy?sup-atr*0.2:sup+atr*0.2;
                 if(ctx.isBuy) { if(structStop==0 || a>structStop) structStop=a; }
                 else          { if(structStop==0 || a<structStop) structStop=a; } }
      if(ctx.isBuy && state.vpPOC>0 && state.vpPOC<ctx.bid) pocStop=state.vpPOC-atr*0.5;
      else if(!ctx.isBuy && state.vpPOC>0 && state.vpPOC>ctx.bid) pocStop=state.vpPOC+atr*0.5;
      double stop=ctx.isBuy?ctx.bid-base:ctx.bid+base;
      if(ctx.isBuy){ if(structStop>0 && structStop>stop)stop=structStop; if(pocStop>0 && pocStop>stop)stop=pocStop; }
      else{ if(structStop>0 && structStop<stop)stop=structStop; if(pocStop>0 && pocStop<stop)stop=pocStop; }
      return stop;
     }

   double ComputeTrendContinuationTrail(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      double atr=ctx.atr;

      // ── Expansion mode: LT zone-anchored trail ─────────────────────
      // Uses 60-day institutional zones as structural stops instead of
      // arbitrary ATR multipliers. Allows trades to breathe within
      // confirmed LT structure.
      if(IsExpansion() && state.vpLTValid)
        {
         double baseDist = atr * (2.5 + m_smooth.continuation * 1.5);
         double structStop = 0;

         // Primary anchor: LT major LVN (deepest liquidity void = strong support/resistance)
         if(ctx.isBuy && state.vpLTMajorLVNPrice > 0 && state.vpLTMajorLVNPrice < ctx.bid)
           {
            double dist = ctx.bid - state.vpLTMajorLVNPrice;
            if(dist < atr * 6.0)  // only if within reasonable distance
               structStop = state.vpLTMajorLVNPrice - atr * 0.3;
           }
         else if(!ctx.isBuy && state.vpLTMajorLVNPrice > 0 && state.vpLTMajorLVNPrice > ctx.bid)
           {
            double dist = state.vpLTMajorLVNPrice - ctx.bid;
            if(dist < atr * 6.0)
               structStop = state.vpLTMajorLVNPrice + atr * 0.3;
           }

         // Secondary: LT major HVN (institutional accumulation = support)
         if(ctx.isBuy && state.vpLTMajorHVNPrice > 0 && state.vpLTMajorHVNPrice < ctx.bid)
           {
            double hvnStop = state.vpLTMajorHVNPrice - atr * 0.2;
            if(hvnStop > structStop) structStop = hvnStop;
           }
         else if(!ctx.isBuy && state.vpLTMajorHVNPrice > 0 && state.vpLTMajorHVNPrice > ctx.bid)
           {
            double hvnStop = state.vpLTMajorHVNPrice + atr * 0.2;
            if(structStop <= 0 || hvnStop < structStop) structStop = hvnStop;
           }

         // Tertiary: nearest significant LT zone (any direction)
         if(state.vpLTNearestZonePrice > 0 && state.vpLTNearestZoneStrength > 0.4)
           {
            if(ctx.isBuy && state.vpLTNearestZonePrice < ctx.bid)
              {
               double zStop = state.vpLTNearestZonePrice - atr * 0.2;
               if(zStop > structStop) structStop = zStop;
              }
            else if(!ctx.isBuy && state.vpLTNearestZonePrice > ctx.bid)
              {
               double zStop = state.vpLTNearestZonePrice + atr * 0.2;
               if(structStop <= 0 || zStop < structStop) structStop = zStop;
              }
           }

         // Also use short-term VP support if closer
         double stSupport = GetBestStructuralSupport(ctx, state);
         if(stSupport > 0)
           {
            double stStop = ctx.isBuy ? stSupport - atr * 0.2 : stSupport + atr * 0.2;
            if(ctx.isBuy && stStop > structStop) structStop = stStop;
            if(!ctx.isBuy && (structStop <= 0 || stStop < structStop)) structStop = stStop;
           }

         // Compute final stop
         double stop = ctx.isBuy ? ctx.bid - baseDist : ctx.bid + baseDist;

         // LT structure overrides base distance (but must be behind price)
         if(ctx.isBuy && structStop > 0 && structStop > stop && structStop < ctx.bid)
            stop = structStop;
         if(!ctx.isBuy && structStop > 0 && structStop < stop && structStop > ctx.bid)
            stop = structStop;

         // POC migration boost: if LT POC is moving with us, extra room
         if(state.vpLTPOCMigration != 0)
           {
            bool migWithTrade = (ctx.isBuy && state.vpLTPOCMigration >= 1)
                             || (!ctx.isBuy && state.vpLTPOCMigration <= -1);
            if(migWithTrade)
              { double ex = atr * 0.4; stop = ctx.isBuy ? stop - ex : stop + ex; }
           }

         // Continuation boost
         if(m_smooth.continuation > 0.75)
           { double ex = atr * 0.3; stop = ctx.isBuy ? stop - ex : stop + ex; }

         // Tighten if continuation fading
         if(m_smooth.continuation < 0.35)
           { double ex = atr * 0.5; stop = ctx.isBuy ? stop + ex : stop - ex; }

         // Runner position bonus
         if(ctx.isRunnerPosition)
           { double ex = atr * 0.6; stop = ctx.isBuy ? stop - ex : stop + ex; }

         return stop;
        }

      // ── Conservative mode: original logic ──────────────────────────
      double baseDist = atr * 1.8;
      double structStop=0;
      if(ctx.isBuy && state.auctMajorLVN>0 && state.auctMajorLVN<ctx.bid) structStop=state.auctMajorLVN-atr*TRAIL_ATR_BUFFER;
      else if(!ctx.isBuy && state.auctMajorLVN>0 && state.auctMajorLVN>ctx.bid) structStop=state.auctMajorLVN+atr*TRAIL_ATR_BUFFER;
      double sup=GetBestStructuralSupport(ctx,state);
      if(sup>0){ double a=ctx.isBuy?sup-atr*0.2:sup+atr*0.2;
                 if(ctx.isBuy&&a>structStop)structStop=a; if(!ctx.isBuy&&a<structStop)structStop=a; }
      double stop=ctx.isBuy?ctx.bid-baseDist:ctx.bid+baseDist;
      if(ctx.isBuy){ if(structStop>0 && structStop>stop)stop=structStop; }
      else{ if(structStop>0 && structStop<stop)stop=structStop; }
      if(state.vpThinnessRatio>0 && state.vpThinnessRatio<0.3)
        { double ex=atr*0.3; stop=ctx.isBuy?stop-ex:stop+ex; }
      if(m_smooth.continuation>0.75)
        { double ex=atr*0.3; stop=ctx.isBuy?stop-ex:stop+ex; }
      return stop;
     }

   double ComputeReAccumulationTrail(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      double atr=ctx.atr;
      double sup=GetBestStructuralSupport(ctx,state);
      if(sup>0) return ctx.isBuy ? sup-atr*0.2 : sup+atr*0.2;
      if(ctx.isBuy) return state.vpPOC>0 ? state.vpPOC-atr*0.5 : ctx.bid-atr*1.5;
      else          return state.vpPOC>0 ? state.vpPOC+atr*0.5 : ctx.bid+atr*1.5;
     }

   double ComputeExhaustionTrail(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      double atr=ctx.atr;
      double baseDist = IsExpansion() ? atr*1.0 : atr*0.7;
      double combined = (m_smooth.exhaustion+m_smooth.failureScore)/2.0;
      baseDist *= (1.0 - Clamp01(combined)*0.35);
      double stop;
      if(ctx.isBuy)
        { stop=ctx.bid-baseDist;
          if(state.auctMajorHVN>0 && state.auctMajorHVN<ctx.bid && (ctx.bid-state.auctMajorHVN)<atr*0.8)
             stop=MathMax(stop,state.auctMajorHVN-atr*0.1);
          if(state.vpUpthrustDetected) stop=MathMax(stop,ctx.bid-atr*(IsExpansion()?0.5:0.3)); }
      else
        { stop=ctx.bid+baseDist;
          if(state.auctMajorHVN>0 && state.auctMajorHVN>ctx.bid && (state.auctMajorHVN-ctx.bid)<atr*0.8)
             stop=MathMin(stop,state.auctMajorHVN+atr*0.1);
          if(state.vpSpringDetected) stop=MathMin(stop,ctx.bid+atr*(IsExpansion()?0.5:0.3)); }
      return stop;
     }

   double ComputeEmergencyTrail(const STrailingContext &ctx)
     { return ctx.isBuy ? ctx.bid-ctx.atr*0.4 : ctx.bid+ctx.atr*0.4; }

   double ComputeStructuralStop(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      switch(m_currentRegime)
        {
         case REGIME_BALANCED_ROTATION:  return ComputeBalancedTrail(ctx,state);
         case REGIME_COMPRESSION:        return ComputeCompressionTrail(ctx,state);
         case REGIME_TREND_INITIATION:   return ComputeInitiationTrail(ctx,state);
         case REGIME_TREND_CONTINUATION: return ComputeTrendContinuationTrail(ctx,state);
         case REGIME_RE_ACCUMULATION:    return ComputeReAccumulationTrail(ctx,state);
         case REGIME_TREND_EXHAUSTION:         return ComputeExhaustionTrail(ctx,state);
         case REGIME_FAILED_AUCTION:
         case REGIME_EXCESS:
         case REGIME_CHAOTIC:            return ComputeEmergencyTrail(ctx);
         default:                        return ComputeBalancedTrail(ctx,state);
        }
     }

   double ApplyNoiseFiltering(double rawStop, const STrailingContext &ctx)
     {
      double atr=ctx.atr, minMove=GetMinMovement();
      bool allowWiden = (IsExpansion() && m_profitExpansionMode);
      if(!allowWiden)
        { if(ctx.isBuy && m_lastIssuedStop>0 && rawStop<m_lastIssuedStop) rawStop=m_lastIssuedStop;
          if(!ctx.isBuy && m_lastIssuedStop>0 && rawStop>m_lastIssuedStop) rawStop=m_lastIssuedStop; }
      double moveDist = MathAbs(rawStop - ctx.currentSL);
      if(moveDist < atr*minMove && m_smooth.failureScore<0.75) return ctx.currentSL;
      double buf=GetAtrBuffer();
      if(ctx.isBuy && rawStop > ctx.bid-atr*buf) rawStop=ctx.bid-atr*buf;
      if(!ctx.isBuy && rawStop < ctx.bid+atr*buf) rawStop=ctx.bid+atr*buf;
      double beThresh = IsExpansion() ? 1.0 : 0.5;
      if(ctx.floatingProfit > atr*beThresh)
        { if(ctx.isBuy && rawStop<ctx.entryPrice) rawStop=ctx.entryPrice;
          if(!ctx.isBuy && rawStop>ctx.entryPrice) rawStop=ctx.entryPrice; }
      return rawStop;
     }

   bool ValidateStopPlacement(double stop, const STrailingContext &ctx)
     {
      double maxDist = IsExpansion() ? ctx.atr*7.0 : ctx.atr*5.0;
      if(ctx.isBuy)  { if(stop<=ctx.currentSL || stop>=ctx.bid) return false; }
      else           { if((stop>=ctx.currentSL && ctx.currentSL>0) || stop<=ctx.bid) return false; }
      if(MathAbs(ctx.bid-stop) > maxDist) return false;
      return true;
     }

   bool DetectFailedAuction(const SVPPipelineState &state)
     {
      EAuctionRegime aReg = (EAuctionRegime)state.auctRegime;
      if(state.vpUpthrustDetected || state.vpSpringDetected)
        { if(!IsExpansion()) return true;
          if(m_smooth.failureScore > 0.6) return true; }
      if(!IsExpansion())
        { if(m_smooth.failureScore>0.75) return true;
          if(aReg==REGIME_FAILED_AUCTION && state.auctRegimeConfidence>0.50) return true;
          if(state.vpInsideVA && m_smooth.failureScore>0.50 && m_smooth.continuation<0.25) return true;
          return false; }
      int confirms=0;
      if(m_smooth.failureScore>0.80) confirms++;
      if(m_smooth.continuation<0.15) confirms++;
      if(m_exhaustionPersistence>=4) confirms++;
      if(confirms>=2) return true;
      if(aReg==REGIME_FAILED_AUCTION && state.auctRegimeConfidence>0.65 && m_smooth.failureScore>0.80)
         return true;
      return false;
     }

   void UpdateProfitExpansionMode(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      if(!IsExpansion()) { m_profitExpansionMode=false; return; }

      // Enter profit expansion when: profitable + continuation strong + LT aligned
      bool ltAligned = false;
      if(state.vpLTValid && state.vpLTPOCMigration != 0)
        {
         ltAligned = (ctx.isBuy && state.vpLTPOCMigration >= 1)
                  || (!ctx.isBuy && state.vpLTPOCMigration <= -1);
        }

      // LT alignment lowers the profit threshold for expansion mode
      double profitThresh = ltAligned ? ctx.atr * 2.0 : ctx.atr * 3.0;
      double contThresh   = ltAligned ? 0.50 : 0.60;

      if(ctx.floatingProfit > profitThresh && m_smooth.continuation > contThresh && m_smooth.failureScore < 0.25)
         m_profitExpansionMode = true;
      else if(m_profitExpansionMode)
        {
         // Exit expansion mode if thesis breaks down
         if(m_smooth.failureScore > 0.50 || m_smooth.continuation < 0.30 || ctx.floatingProfit < ctx.atr * 1.0)
            m_profitExpansionMode = false;
        }
     }

   //+------------------------------------------------------------------+
   //| Event‑Driven Rules (v4.7)                                       |
   //+------------------------------------------------------------------+
   void ApplyEventDrivenRules(const STrailingContext &ctx,
                              STrailingDecision &d,
                              const SVPPipelineState &state)
     {
      for(int i = 0; i < state.pendingEventCount; i++)
        {
         int eventType = state.pendingEventTypes[i];
         double score  = state.pendingEventScores[i];
         double dir    = state.pendingEventDirs[i];

         bool sameDir  = (dir > 0.2 && ctx.isBuy) || (dir < -0.2 && !ctx.isBuy);
         bool oppDir   = (dir > 0.2 && !ctx.isBuy) || (dir < -0.2 && ctx.isBuy);

         switch(eventType)
           {
            case EVENT_BOS:
               if(score > 0.4 && sameDir)
                 {
                  m_profitExpansionMode = true;
                  m_trendPersistence = MathMax(m_trendPersistence, 8);
                  d.continuationBias = MathMax(d.continuationBias, 0.8);
                  if(d.reason == "") d.reason = "BOS_SAME";
                 }
               else if(score > 0.4 && oppDir)
                 {
                  d.reversalRisk = MathMax(d.reversalRisk, 0.9);
                  if(d.reason == "") d.reason = "BOS_OPPOSITE";
                  double emergStop = ComputeEmergencyTrail(ctx);
                  if(ValidateStopPlacement(emergStop, ctx))
                    { d.shouldMoveStop = true; d.newStopPrice = emergStop; }
                 }
               break;

            case EVENT_CHOCH:
               if(score > 0.4 && oppDir)
                 {
                  d.shouldExitImmediately = true;
                  d.reason = "CHOCH_REVERSAL_EXIT";
                  return;
                 }
               else if(score > 0.4 && sameDir)
                 {
                  m_profitExpansionMode = true;
                  m_trendPersistence = MathMax(m_trendPersistence, 10);
                  d.continuationBias = MathMax(d.continuationBias, 0.9);
                  if(d.reason == "") d.reason = "CHOCH_SAME";
                 }
               break;

            case EVENT_SWEEP:
               if(score > 0.3 && oppDir)
                 {
                  d.reversalRisk = MathMax(d.reversalRisk, 0.85);
                  if(d.reason == "") d.reason = "SWEEP_OPPOSITE";
                  double emergStop = ComputeEmergencyTrail(ctx);
                  if(ValidateStopPlacement(emergStop, ctx))
                    { d.shouldMoveStop = true; d.newStopPrice = emergStop; }
                 }
               else if(score > 0.3 && sameDir)
                 {
                  m_profitExpansionMode = true;
                  m_trendPersistence = MathMax(m_trendPersistence, 6);
                  d.continuationBias = MathMax(d.continuationBias, 0.7);
                  if(d.reason == "") d.reason = "SWEEP_SAME";
                 }
               break;

            case EVENT_STOP_CLUSTER:
               if(score > 0.4 && oppDir)
                 {
                  m_profitExpansionMode = true;
                  if(d.reason == "") d.reason = "STOP_CLUSTER_WIDE";
                 }
               else if(score > 0.4 && sameDir)
                 {
                  d.continuationBias = MathMax(d.continuationBias, 0.6);
                  if(d.reason == "") d.reason = "STOP_CLUSTER_SAME";
                 }
               break;

            case EVENT_COMPRESSION:
               if(score > 0.45)
                 {
                  double tightStop = ctx.isBuy ? ctx.bid - ctx.atr * GetAtrBuffer() * 0.6
                                               : ctx.bid + ctx.atr * GetAtrBuffer() * 0.6;
                  if(ValidateStopPlacement(tightStop, ctx))
                    { d.shouldMoveStop = true; d.newStopPrice = tightStop; }
                  if(d.reason == "") d.reason = "COMPRESSION";
                 }
               break;

            case EVENT_EXHAUSTION:
               if(score > 0.4)
                 {
                  d.reversalRisk = MathMax(d.reversalRisk, 0.8);
                  if(score > 0.65)
                    {
                     double stop = ComputeExhaustionTrail(ctx, state);
                     if(ValidateStopPlacement(stop, ctx))
                       { d.shouldMoveStop = true; d.newStopPrice = stop; }
                    }
                  if(d.reason == "") d.reason = "EXHAUSTION";
                 }
               break;

            case EVENT_ABSORPTION:
               if(score > 0.45 && sameDir)
                 {
                  if(IsExpansion())
                    {
                     double widerStop = ctx.isBuy ? ctx.bid - ctx.atr * (GetAtrBuffer() * 3.0)
                                                  : ctx.bid + ctx.atr * (GetAtrBuffer() * 3.0);
                     if(ValidateStopPlacement(widerStop, ctx))
                       { d.shouldMoveStop = true; d.newStopPrice = widerStop; }
                    }
                  if(d.reason == "") d.reason = "ABSORPTION_WIDE";
                 }
               break;

            case EVENT_DIVERGENCE:
               if(score > 0.3 && oppDir)
                 {
                  d.reversalRisk = MathMax(d.reversalRisk, 0.9);
                  if(d.reason == "") d.reason = "DIVERGENCE_OPPOSITE";
                  double emergStop = ComputeEmergencyTrail(ctx);
                  if(ValidateStopPlacement(emergStop, ctx))
                    { d.shouldMoveStop = true; d.newStopPrice = emergStop; }
                 }
               break;

            default:
               break;
           }
        }
     }

public:
   void SetTrailingStyle(ETrailingStyle style) { m_trailingStyle = style; }
   ETrailingStyle GetTrailingStyle(void) const { return m_trailingStyle; }

   void Reset(void)
     {
      m_trailingStyle = TRAIL_STYLE_CONSERVATIVE;
      m_smooth.continuation=0.5; m_smooth.exhaustion=0; m_smooth.reversalRisk=0;
      m_smooth.failureScore=0; m_smooth.regimePersist=0;
      m_currentRegime=REGIME_BALANCED_ROTATION; m_pendingRegime=REGIME_BALANCED_ROTATION;
      m_pendingCount=0; m_lastIssuedStop=0;
      m_trendPersistence=0; m_exhaustionPersistence=0;
      m_profitExpansionMode=false; m_updateCounter=0;
      m_structHistory.writeIdx=0; m_structHistory.count=0;
      ArrayInitialize(m_structHistory.poc,0);
      ArrayInitialize(m_structHistory.hvn,0);
      ArrayInitialize(m_structHistory.lvn,0);
     }

   CAuctionTrailingStopEngine(void) { Reset(); }

   STrailingDecision Evaluate(const STrailingContext &ctx, const SVPPipelineState &state)
     {
      STrailingDecision d;
      d.shouldMoveStop=false; d.shouldExitImmediately=false;
      d.newStopPrice=ctx.currentSL; d.trailingStrength=0;
      d.continuationBias=0; d.reversalRisk=0;
      d.trailingRegime=m_currentRegime; d.reason="";

      if(!state.vpValid) return d;

      EAuctionRegime rawReg = (EAuctionRegime)state.auctRegime;
      if(rawReg==REGIME_CHAOTIC || rawReg==REGIME_EXCESS)
        {
         double emergStop = ComputeEmergencyTrail(ctx);
         if(ValidateStopPlacement(emergStop, ctx))
           { d.shouldMoveStop=true; d.newStopPrice=emergStop; m_lastIssuedStop=emergStop;
             d.trailingRegime=rawReg; d.reversalRisk=1.0;
             d.reason = (rawReg==REGIME_CHAOTIC) ? "CHAOTIC_TIGHTEN" : "EXCESS_TIGHTEN"; }
         d.trailingStrength = 0.95;
         d.continuationBias = 0;
         d.reversalRisk = 1.0;

         ApplyEventDrivenRules(ctx, d, state);
         return d;
        }

      double minProfit = IsExpansion() ? ctx.atr*0.5 : ctx.atr*0.3;
      if(ctx.floatingProfit < minProfit)
        {
         ApplyEventDrivenRules(ctx, d, state);
         return d;
        }

      UpdateSmoothedSignals(state);
      if(IsExpansion()) UpdateStructureHistory(state);
      UpdateProfitExpansionMode(ctx, state);

      EAuctionRegime regime = DetectTrailingRegime(state);
      d.trailingRegime = regime;

      if(DetectFailedAuction(state))
        {
         double emergStop = ComputeEmergencyTrail(ctx);
         if(ValidateStopPlacement(emergStop, ctx))
           { d.shouldMoveStop=true; d.newStopPrice=emergStop; m_lastIssuedStop=emergStop;
             d.reason = IsExpansion() ? "EXP_FAILED_TIGHTEN" : "FAILED_TIGHTEN"; }
         d.trailingStrength = 0.90;
         d.reversalRisk = 1.0;

         ApplyEventDrivenRules(ctx, d, state);
         return d;
        }

      double rawStop = ComputeStructuralStop(ctx,state);
      double filtered = ApplyNoiseFiltering(rawStop,ctx);

      if(ValidateStopPlacement(filtered,ctx))
        {
         d.shouldMoveStop=true; d.newStopPrice=filtered; m_lastIssuedStop=filtered;
         string pre = IsExpansion() ? "EXP_" : "";
         switch(regime)
           { case REGIME_TREND_CONTINUATION: d.reason=pre+"TREND_CONT"; break;
             case REGIME_TREND_INITIATION:   d.reason=pre+"INITIATION"; break;
             case REGIME_RE_ACCUMULATION:    d.reason=pre+"RE_ACCUM"; break;
             case REGIME_COMPRESSION:        d.reason=pre+"COMPRESSION"; break;
             case REGIME_BALANCED_ROTATION:  d.reason=pre+"BALANCED"; break;
             case REGIME_TREND_EXHAUSTION:         d.reason=pre+"EXHAUST_TIGHTEN"; break;
             default:                        d.reason=pre+"TRAIL_UPDATE"; break; }
         if(m_profitExpansionMode) d.reason += "_EXPANDED";
        }

      d.trailingStrength = (regime==REGIME_TREND_EXHAUSTION) ? 0.85
         : (regime==REGIME_BALANCED_ROTATION || regime==REGIME_COMPRESSION) ? 0.55
         : (m_profitExpansionMode ? 0.20 : 0.35);

      // ── SỬA LỖI: giữ giá trị reversalRisk và continuationBias từ sự kiện ──
      d.continuationBias = MathMax(m_smooth.continuation, d.continuationBias);
      d.reversalRisk     = MathMax(m_smooth.reversalRisk, d.reversalRisk);

      ApplyEventDrivenRules(ctx, d, state);
      return d;
     }

   EAuctionRegime GetCurrentRegime(void)       const { return m_currentRegime; }
   bool           InProfitExpansion(void)       const { return m_profitExpansionMode; }
   int            GetTrendPersistence(void)     const { return m_trendPersistence; }
   double         GetSmoothedContinuation(void) const { return m_smooth.continuation; }
   double         GetSmoothedExhaustion(void)   const { return m_smooth.exhaustion; }
   double         GetSmoothedFailure(void)      const { return m_smooth.failureScore; }
  };

#endif