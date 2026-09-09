#ifndef __EA_ROOT_EXHAUSTIONENGINE_MQH__
#define __EA_ROOT_EXHAUSTIONENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Exhaustion Engine v4.0 — Auction‑Enhanced Climax Detection        |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+
class CExhaustionEngine : public CPipelineModuleBase
  {
private:
   double            m_exhaustionScore;
   double            m_directionBias;   // +1 = bullish exhaustion (buy), -1 = bearish (sell)

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double &qualityMult,
                                            double &direction,
                                            double atrPrice)
     {
      double bid = state.marketData.bid;

      // Anchored profiles near exhaustion zone
      if(state.vpRangePOC > 0 && MathAbs(bid - state.vpRangePOC) < atrPrice * 0.5)
         qualityMult *= 1.2;
      if(state.vpBreakoutPOC > 0 && MathAbs(bid - state.vpBreakoutPOC) < atrPrice * 0.5)
         qualityMult *= 1.15;
      if(state.vpPullbackPOC > 0 && MathAbs(bid - state.vpPullbackPOC) < atrPrice * 0.5)
         qualityMult *= 1.1;

      // Best HVN: exhaustion at best HVN strong signal
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.3)
         qualityMult *= 1.2;

      // Fake breakout traps: exhaustion after upthrust → bearish, after spring → bullish
      if(state.vpUpthrustDetected) direction = MathMin(direction, -0.8);
      if(state.vpSpringDetected)   direction = MathMax(direction, 0.8);

      // Thin profile: exhaustion may be less reliable but still add boost
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         qualityMult *= 1.05;

      // VA Overlap bias: strong directional clue
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.7);
      if(vaBias == -1) direction = MathMin(direction, -0.7);

      // Migration confidence reinforces direction
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm (Exhaustion → Mean Reversion / Sweep Reversal) ──
      if(state.vpValid)
        {
         if(m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
            m_thesisManager.InitTrade(ENTRY_SWEEP_REVERSAL, atrPrice,
                                      state.auctRegimeConfidence, m_symbol);

         // thesisHealth removed: already accounted for in auction adjustment above
        }

      // ── v4.0: Xác nhận composite đa khung thời gian ──────────
      if(state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
        {
         if(direction > 0 && bid > state.vpCompositeVAH)
            qualityMult *= 1.08;
         else if(direction < 0 && bid < state.vpCompositeVAL)
            qualityMult *= 1.08;
         else if(direction > 0 && bid < state.vpCompositeVAL)
            qualityMult *= 0.90;
         else if(direction < 0 && bid > state.vpCompositeVAH)
            qualityMult *= 0.90;
        }
     }

public:
   void              Bootstrap(const string symbol)
     {
      Configure(symbol, "ExhaustionEngine");
      m_exhaustionScore = 0;
      m_directionBias   = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      int m5Count = state.marketData.m5Copied;
      if(m5Count < 5) return true;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         m_exhaustionScore = 0.0;
         state.flow.exhaustionScore = 0.0;
         return true;
        }

      int last = m5Count - 1;

      // ATR in price (giữ nguyên)
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      // ---- Average volume (last 20 bars) ----
      int volBars = MathMin(20, m5Count);
      double avgVol = 0;
      for(int i = m5Count - volBars; i < m5Count; i++)
         avgVol += (double)state.marketData.m5Rates[i].tick_volume;
      avgVol /= volBars;

      double lastVol = (double)state.marketData.m5Rates[last].tick_volume;
      double hi = state.marketData.m5Rates[last].high;
      double lo = state.marketData.m5Rates[last].low;
      double op = state.marketData.m5Rates[last].open;
      double cl = state.marketData.m5Rates[last].close;
      double range = hi - lo;

      // ---- 1. Volume surge (mandatory) ----
      if(avgVol <= 0 || lastVol <= avgVol * 2.0)
        {
         m_exhaustionScore = 0.0;
         state.flow.exhaustionScore = 0.0;
         return true;
        }

      // ---- 2. Reversal context (unchanged) ----
      int trendDir = 0;
      if(last >= 3)
        {
         int upBars = 0, downBars = 0;
         for(int i = last-1; i >= last-3; i--)
           {
            if(state.marketData.m5Rates[i].close > state.marketData.m5Rates[i].open) upBars++;
            else if(state.marketData.m5Rates[i].close < state.marketData.m5Rates[i].open) downBars++;
           }
         if(upBars >= 2) trendDir = 1;
         else if(downBars >= 2) trendDir = -1;
        }

      bool currBullish = (cl > op);
      bool prevTrendUp = (trendDir == 1);
      bool reversal = (currBullish && !prevTrendUp) || (!currBullish && prevTrendUp);

      // ---- 3. Rejection wick ----
      double upperWick = hi - MathMax(op, cl);
      double lowerWick = MathMin(op, cl) - lo;
      double maxWick = MathMax(upperWick, lowerWick);
      double wickRatio = (range > 0) ? maxWick / range : 0;

      // ---- Base exhaustion score ----
      double volIntensity = MathMin(1.0, (lastVol / avgVol - 1.0) / 4.0);
      double reversalScore = reversal ? 1.0 : 0.0;
      double wickScore = Clamp01(wickRatio / 0.4);
      double baseScore = volIntensity * 0.40 + reversalScore * 0.30 + wickScore * 0.30;
      baseScore = Clamp01(baseScore);

      // ═══════════════════════════════════════════════════════════
      // ══ AUCTION & VP CONTEXT + NEW V3 DATA ═══════════════════
      // ═══════════════════════════════════════════════════════════
      double qualityMult = 1.0;
      double direction   = 0.0;

      if(state.vpValid && baseScore > 0.15)
        {
         // ── Preserved VP conditions ──
         if(!state.vpInsideVA)
            qualityMult *= 1.10;
         else
           {
            if(MathAbs(state.vpPriceVsVA) > 0.8)
               qualityMult *= 1.05;
            else if(MathAbs(state.vpPriceVsPOC) < 0.15)
               qualityMult *= 0.95;
           }

         if(state.vpDistToHVN_ATR < 0.3) qualityMult *= 1.08;
         if(state.vpDistToLVN_ATR < 0.4) qualityMult *= 1.10;

         if(state.auctAcceptanceScore < 0.25) qualityMult *= 1.10;
         if(state.auctFailureScore > 0.4)     qualityMult *= 1.08;

         // ── Auction Regime (giữ nguyên) ──
         if(regime == (int)REGIME_BALANCED_ROTATION)
            qualityMult *= 1.25;
         else if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
           {
            qualityMult *= 0.80;
            bool trendUp = (state.vpDevPOCSlope > 0.02);
            if((currBullish && trendUp) || (!currBullish && !trendUp))
               qualityMult *= 1.20;
           }
         else if(regime == (int)REGIME_TREND_EXHAUSTION)
            qualityMult *= 1.20;
         else if(regime == (int)REGIME_FAILED_AUCTION)
            qualityMult *= 1.30;

         if(state.auctExhaustionScore > 0.65) qualityMult *= 1.1;
         if(state.auctContinuationScore > 0.7) qualityMult *= 0.9;

         double pocSlope = state.vpDevPOCSlope;
         if(MathAbs(pocSlope) > 0.03)
           {
            if((currBullish && pocSlope > 0) || (!currBullish && pocSlope < 0))
               qualityMult *= 0.85;
            else
               qualityMult *= 1.15;
           }

         // ── Composite profile context (giữ nguyên) ──
         if(state.vpValid)
           {
            double bid = state.marketData.bid;
            if(MathAbs(bid - state.vpCompositeVAH) < atrPrice * 0.3 ||
               MathAbs(bid - state.vpCompositeVAL) < atrPrice * 0.3)
               qualityMult *= 1.15;
            if(bid > state.vpCompositePOC && currBullish) direction = -0.8;
            if(bid < state.vpCompositePOC && !currBullish) direction = 0.8;
           }

         // ── Naked POC ──
         if(state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.6)
           {
            qualityMult *= 1.1;
            if(currBullish && state.marketData.bid < state.vpNearestNakedPOC) direction = -0.7;
            else if(!currBullish && state.marketData.bid > state.vpNearestNakedPOC) direction = 0.7;
           }

         // ── v4.0: Structural context (bao gồm thesis health & composite) ──
         ApplyStructuralContext(state, qualityMult, direction, atrPrice);

         // Final directional bias
         if(direction == 0.0)
            direction = currBullish ? -1.0 : 1.0;
         if(MathAbs(pocSlope) > 0.02)
           {
            if(pocSlope > 0) direction = MathMax(direction, 0.3);
            else             direction = MathMin(direction, -0.3);
           }
         m_directionBias = MathMax(-1.0, MathMin(1.0, direction));
        }

      double adjustedScore = baseScore * qualityMult;
      m_exhaustionScore = Clamp01(adjustedScore);

      state.flow.exhaustionScore = m_exhaustionScore;

      if(m_exhaustionScore > 0.35 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_EXHAUSTION;
         state.pendingEventScores[idx] = m_exhaustionScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   double            ExhaustionScore(void) const { return m_exhaustionScore; }
   double            DirectionBias(void)   const { return m_directionBias; }
  };

#endif