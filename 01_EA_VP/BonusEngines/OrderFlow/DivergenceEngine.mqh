#ifndef __EA_ROOT_DIVERGENCEENGINE_MQH__
#define __EA_ROOT_DIVERGENCEENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Divergence Engine v4.0 — Auction‑Enhanced CVD/Price Divergence    |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+
class CDivergenceEngine : public CPipelineModuleBase
  {
private:
   double            m_divergenceScore;
   bool              m_bullishDivergence;
   bool              m_bearishDivergence;
   double            m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double &auctionMult,
                                            double &direction,
                                            double atrPrice)
     {
      double bid = state.marketData.bid;

      // Anchored profiles: divergence near anchored level = strong reversal potential
      if(state.vpRangePOC > 0 && MathAbs(bid - state.vpRangePOC) < atrPrice * 0.4)
        {
         auctionMult *= 1.2;
         if(m_bullishDivergence) direction = MathMax(direction, 0.8);
         else                    direction = MathMin(direction, -0.8);
        }
      if(state.vpBreakoutPOC > 0 && MathAbs(bid - state.vpBreakoutPOC) < atrPrice * 0.4)
        {
         auctionMult *= 1.15;
         if(m_bullishDivergence) direction = MathMax(direction, 0.7);
         else                    direction = MathMin(direction, -0.7);
        }
      if(state.vpPullbackPOC > 0 && MathAbs(bid - state.vpPullbackPOC) < atrPrice * 0.4)
        {
         auctionMult *= 1.1;
         if(m_bullishDivergence) direction = MathMax(direction, 0.6);
         else                    direction = MathMin(direction, -0.6);
        }

      // Best HVN: divergence at best HVN = high quality
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.3)
        {
         auctionMult *= 1.2;
         if(m_bullishDivergence) direction = MathMax(direction, 0.7);
         else                    direction = MathMin(direction, -0.7);
        }

      // Fake breakout traps: upthrust + bullish divergence = strong buy, etc.
      if(state.vpUpthrustDetected && m_bullishDivergence)  auctionMult *= 1.3;
      if(state.vpSpringDetected && m_bearishDivergence)    auctionMult *= 1.3;

      // Thin profile: divergence in thin market may be false, but still can be powerful
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         auctionMult *= 1.05;  // keep existing direction

      // VA Overlap bias: strong directional confirmation
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.7);
      if(vaBias == -1) direction = MathMin(direction, -0.7);

      // Migration confidence reinforces direction
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm (Sweep Reversal, phù hợp divergence) ──
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
            auctionMult *= 1.08;
         else if(direction < 0 && bid < state.vpCompositeVAL)
            auctionMult *= 1.08;
         else if(direction > 0 && bid < state.vpCompositeVAL)
            auctionMult *= 0.90;
         else if(direction < 0 && bid > state.vpCompositeVAH)
            auctionMult *= 0.90;
        }
     }

public:
   void              Bootstrap(const string symbol)
     {
      Configure(symbol, "DivergenceEngine");
      m_divergenceScore   = 0;
      m_bullishDivergence = false;
      m_bearishDivergence = false;
      m_directionBias     = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      m_bullishDivergence = false;
      m_bearishDivergence = false;
      m_divergenceScore   = 0;
      m_directionBias     = 0.0;

      int cvdCount = state.flow.cvdHistCount;
      int m5Count  = state.marketData.m5Copied;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         state.flow.divergenceScore = 0.0;
         state.flow.bullishDivergence = false;
         state.flow.bearishDivergence = false;
         return true;
        }

      // ATR in price (giữ nguyên)
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      // ─── 1. Primary: CVD vs Price slope (giữ nguyên) ────────────
      if(cvdCount >= 10 && m5Count >= 10)
        {
         double cvdNow    = state.flow.cvdHistory[cvdCount - 1];
         double cvdPrev   = state.flow.cvdHistory[cvdCount - 10];
         double cvdSlope  = cvdNow - cvdPrev;

         double priceNow  = state.marketData.m5Rates[m5Count - 1].close;
         double pricePrev = state.marketData.m5Rates[m5Count - 10].close;
         double priceSlope = priceNow - pricePrev;

         bool priceUp   = (priceSlope >  atrPrice * 0.2);
         bool priceDown = (priceSlope < -atrPrice * 0.2);
         bool cvdUp     = (cvdSlope > 0);
         bool cvdDown   = (cvdSlope < 0);

         m_bullishDivergence = (priceDown && cvdUp);
         m_bearishDivergence = (priceUp   && cvdDown);

         if(m_bullishDivergence || m_bearishDivergence)
           {
            double cvdIntensity = (MathAbs(cvdPrev) > 0) ? MathAbs(cvdSlope) / MathAbs(cvdPrev) : 0;
            double priceIntensity = (atrPrice > 0) ? MathAbs(priceSlope) / atrPrice : 0;
            m_divergenceScore = Clamp01(cvdIntensity * 0.6 + priceIntensity * 0.4);
           }
        }
      else
        {
         // Fallback using structure bias and delta proxy
         double priceBias = state.structure.structureBias;
         double flowBias  = state.flow.deltaProxy;
         bool bullDiv = (priceBias < 0.4 && flowBias > 0.6);
         bool bearDiv = (priceBias > 0.6 && flowBias < 0.4);
         if(bullDiv || bearDiv)
           {
            m_bullishDivergence = bullDiv;
            m_bearishDivergence = bearDiv;
            m_divergenceScore = 0.4;
           }
        }

      // ─── 2. Original VP & cross-engine context + NEW auction & V3 ────
      if(m_divergenceScore > 0.1)
        {
         double boost = 1.0;

         // --- original VP context ---
         if(state.vpValid)
           {
            if(!state.vpInsideVA) boost += 0.12;
            else if(MathAbs(state.vpPriceVsVA) > 0.8) boost += 0.08;
            else if(MathAbs(state.vpPriceVsPOC) < 0.2) boost -= 0.10;

            if(state.vpDistToHVN_ATR < 0.4) boost += 0.05;
            if(state.vpDistToLVN_ATR < 0.4) boost -= 0.05;

            if(state.auctValueAreaState == (int)VA_EXPANDING) boost -= 0.08;
            else if(state.auctValueAreaState == (int)VA_CONTRACTING) boost += 0.08;

            if(state.auctAcceptanceScore < 0.25) boost += 0.08;
            if(state.auctFailureScore > 0.4) boost += 0.06;

            double vpDir = state.vpMigrationDirRaw;
            if(state.vpMigrationScore > 0.3)
              {
               if((m_bullishDivergence && vpDir < 0) || (m_bearishDivergence && vpDir > 0)) boost -= 0.10;
               else if((m_bullishDivergence && vpDir > 0) || (m_bearishDivergence && vpDir < 0)) boost += 0.08;
              }
           }

         // --- NEW Auction regime & advanced context ---
         double auctionMult = 1.0;
         double direction   = m_bullishDivergence ? 1.0 : -1.0;

         if(regime == (int)REGIME_BALANCED_ROTATION)
           {
            auctionMult = 1.25;
           }
         else if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
           {
            auctionMult = 0.80;
            double trendDir = (state.vpDevPOCSlope > 0.02) ? 1.0 : ((state.vpDevPOCSlope < -0.02) ? -1.0 : 0);
            if((m_bullishDivergence && trendDir < 0) || (m_bearishDivergence && trendDir > 0))
               auctionMult = 1.20;
           }
         else if(regime == (int)REGIME_TREND_EXHAUSTION)
           {
            auctionMult = 1.20;
           }
         else if(regime == (int)REGIME_FAILED_AUCTION)
           {
            auctionMult = 1.30;
           }

         if(state.auctExhaustionScore > 0.65) auctionMult *= 1.1;
         if(state.auctContinuationScore > 0.7) auctionMult *= 0.9;

         if(MathAbs(state.vpDevPOCSlope) > 0.03)
           {
            if((m_bullishDivergence && state.vpDevPOCSlope > 0) || (m_bearishDivergence && state.vpDevPOCSlope < 0))
               auctionMult *= 1.15;
            else
               auctionMult *= 0.85;
           }

         // Composite profile (giữ nguyên)
         if(state.vpValid)
           {
            double bid = state.marketData.bid;
            if(MathAbs(bid - state.vpCompositeVAH) < atrPrice * 0.3 ||
               MathAbs(bid - state.vpCompositeVAL) < atrPrice * 0.3)
               auctionMult *= 1.15;
            if(bid > state.vpCompositePOC && m_bullishDivergence) direction = MathMax(direction, 0.6);
            if(bid < state.vpCompositePOC && m_bearishDivergence) direction = MathMin(direction, -0.6);
           }

         // Naked POC magnet
         if(state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.6)
           {
            if((m_bullishDivergence && state.marketData.bid < state.vpNearestNakedPOC) ||
               (m_bearishDivergence && state.marketData.bid > state.vpNearestNakedPOC))
               auctionMult *= 1.1;
            direction = m_bullishDivergence ? MathMax(direction, 0.7) : MathMin(direction, -0.7);
           }

         // ── v4.0: Structural context (bao gồm thesis health & composite) ──
         ApplyStructuralContext(state, auctionMult, direction, atrPrice);

         // Final multiplier & score
         double totalMult = MathMax(0.75, MathMin(1.35, boost)) * auctionMult;
         totalMult = MathMax(0.65, MathMin(1.50, totalMult));

         m_divergenceScore = Clamp01(m_divergenceScore * totalMult);
         m_directionBias   = direction;
        }

      // ─── 3. Final threshold ──────────────────────────────────
      if(m_divergenceScore < 0.18)
        {
         m_bullishDivergence = false;
         m_bearishDivergence = false;
         m_divergenceScore   = 0;
         m_directionBias     = 0.0;
        }

      state.flow.divergenceScore   = m_divergenceScore;
      state.flow.bearishDivergence = m_bearishDivergence;
      state.flow.bullishDivergence = m_bullishDivergence;

      if(m_divergenceScore > 0.25 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_DIVERGENCE;
         state.pendingEventScores[idx] = m_divergenceScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   bool              IsBullishDiv(void) const { return m_bullishDivergence; }
   bool              IsBearishDiv(void) const { return m_bearishDivergence; }
   double            DivergenceScore(void) const { return m_divergenceScore; }
   double            DirectionBias(void) const { return m_directionBias; }
  };

#endif