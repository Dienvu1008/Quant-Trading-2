#ifndef __EA_ROOT_ABSORPTIONENGINE_MQH__
#define __EA_ROOT_ABSORPTIONENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Absorption Engine v4.0 — Auction‑Enhanced Effort‑vs‑Result        |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+
class CAbsorptionEngine : public CPipelineModuleBase
  {
private:
   double            m_absorptionScore;
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

      // Anchored profiles: absorption near anchored level = strong
      if(state.vpRangePOC > 0 && MathAbs(bid - state.vpRangePOC) < atrPrice * 0.4)
        {
         auctionMult *= 1.2;
         if(bid > state.vpRangePOC) direction = MathMax(direction, 0.7);
         else                        direction = MathMin(direction, -0.7);
        }
      if(state.vpBreakoutPOC > 0 && MathAbs(bid - state.vpBreakoutPOC) < atrPrice * 0.4)
        {
         auctionMult *= 1.15;
         if(bid > state.vpBreakoutPOC) direction = MathMax(direction, 0.7);
         else                           direction = MathMin(direction, -0.7);
        }
      if(state.vpPullbackPOC > 0 && MathAbs(bid - state.vpPullbackPOC) < atrPrice * 0.4)
        {
         auctionMult *= 1.1;
         if(bid > state.vpPullbackPOC) direction = MathMax(direction, 0.6);
         else                           direction = MathMin(direction, -0.6);
        }

      // Best HVN: absorption at best HVN is significant
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.3)
        {
         auctionMult *= 1.2;
         if(bid > state.vpBestHVN) direction = MathMax(direction, 0.5);
         else                       direction = MathMin(direction, -0.5);
        }

      // Fake breakout traps: if upthrust, absorption likely distribution (bearish)
      if(state.vpUpthrustDetected) direction = MathMin(direction, -0.7);
      if(state.vpSpringDetected)   direction = MathMax(direction, 0.7);

      // Thin profile: absorption = brief pause before continuation
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         auctionMult *= 1.1;   // keep existing direction

      // VA Overlap bias: strong directional signal
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.7);
      if(vaBias == -1) direction = MathMin(direction, -0.7);

      // Migration confidence: reinforces direction
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm (Breakout Retest / Pullback) ──
      if(state.vpValid)
        {
         // Chọn archetype dựa trên ngữ cảnh: nếu có direction rõ ràng dùng Pullback,
         // nếu không dùng Breakout Retest (hấp thụ tại vùng giá)
         EEntryArchetype arch = (MathAbs(direction) > 0.5) ? ENTRY_PULLBACK : ENTRY_BREAKOUT_RETEST;
         if(m_thesisManager.GetArchetype() != arch)
            m_thesisManager.InitTrade(arch, atrPrice, state.auctRegimeConfidence, m_symbol);

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
      Configure(symbol, "AbsorptionEngine");
      m_absorptionScore = 0;
      m_directionBias   = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      int m5Count = state.marketData.m5Copied;
      if(m5Count < 3) return true;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         m_absorptionScore = 0.0;
         state.flow.absorptionScore = 0.0;
         return true;
        }

      // ATR in price (giữ nguyên)
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      double avgVol = 0;
      for(int i = 0; i < m5Count; i++)
         avgVol += (double)state.marketData.m5Rates[i].tick_volume;
      avgVol /= m5Count;
      if(avgVol <= 0) return true;

      int barsToCheck = MathMin(3, m5Count);
      double maxAbsorption = 0.0;
      double sumAbsorption = 0.0;

      for(int i = m5Count - barsToCheck; i < m5Count; i++)
        {
         double vol   = (double)state.marketData.m5Rates[i].tick_volume;
         double range = state.marketData.m5Rates[i].high - state.marketData.m5Rates[i].low;

         double volIntensity = Clamp01((vol / avgVol - 1.0) / 2.0);
         double rangeContraction = 1.0 - Clamp01(range / (atrPrice * 0.5));  // FIXED: atrPrice

         double barAbsorption = volIntensity * 0.6 + rangeContraction * 0.4;
         barAbsorption = Clamp01(barAbsorption);

         if(barAbsorption > maxAbsorption)
            maxAbsorption = barAbsorption;
         sumAbsorption += barAbsorption;
        }

      double avgAbsorption = sumAbsorption / barsToCheck;
      double baseScore = maxAbsorption * 0.6 + avgAbsorption * 0.4;
      baseScore = Clamp01(baseScore);

      // ---- 3. Volume Profile context multiplier (original) ----
      double vpMult = 1.0;
      if(state.vpValid)
        {
         if(!state.vpInsideVA)
            vpMult += 0.06;
         else
           {
            if(MathAbs(state.vpPriceVsPOC) < 0.15)
               vpMult += 0.10;
            else if(MathAbs(state.vpPriceVsVA) > 0.8)
               vpMult += 0.04;
           }

         if(state.vpDistToHVN_ATR < 0.4) vpMult += 0.08;
         if(state.vpDistToLVN_ATR < 0.4) vpMult -= 0.05;

         double vpDir = state.vpMigrationDirRaw;
         double vpMigScore = state.vpMigrationScore;
         if(vpMigScore > 0.3 && vpDir != 0)
            vpMult += 0.05;

         if(state.auctAcceptanceScore > 0.65) vpMult += 0.06;
         if(state.auctFailureScore > 0.4) vpMult -= 0.05;
        }

      // ---- 4. Auction regime & directional context ----
      double auctionMult = 1.0;
      double direction   = 0.0;

      if(regime == REGIME_BALANCED_ROTATION)
        {
         auctionMult = 1.25;
         direction   = 1.0;
        }
      else if(regime == REGIME_TREND_CONTINUATION || regime == REGIME_TREND_INITIATION)
        {
         auctionMult = 1.1;
         if(state.vpDevPOCSlope > 0.02) direction = 1.0;
         else if(state.vpDevPOCSlope < -0.02) direction = -1.0;
        }
      else if(regime == REGIME_TREND_EXHAUSTION)
        {
         auctionMult = 1.15;
         direction   = -1.0;
        }
      else if(regime == REGIME_FAILED_AUCTION)
        {
         auctionMult = 1.2;
         if(state.liquidity.premiumDiscountScore > 0.6) direction = -1.0;
         else if(state.liquidity.premiumDiscountScore < 0.4) direction = 1.0;
        }

      if(state.auctExhaustionScore > 0.6) direction = MathMin(direction, -0.5);
      if(state.auctContinuationScore > 0.7) direction = MathMax(direction, 0.5);

      if(MathAbs(state.vpDevPOCSlope) > 0.03)
        {
         if(state.vpDevPOCSlope > 0) direction = MathMax(direction, 0.8);
         else                         direction = MathMin(direction, -0.8);
        }

      // Composite profile (fixed thresholds)
      if(state.vpValid)
        {
         double bid = state.marketData.bid;
         if(MathAbs(bid - state.vpCompositeVAH) < atrPrice * 0.3)  // FIXED
           {
            auctionMult *= 1.15;
            if(direction == 0) direction = -0.5;
           }
         else if(MathAbs(bid - state.vpCompositeVAL) < atrPrice * 0.3) // FIXED
           {
            auctionMult *= 1.15;
            if(direction == 0) direction = 0.5;
           }
         if(bid > state.vpCompositePOC) direction = MathMax(direction, 0.3);
         else direction = MathMin(direction, -0.3);
        }

      // Naked POC
      if(state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.6)
        {
         if(state.marketData.bid < state.vpNearestNakedPOC)
           {
            auctionMult *= 1.1;
            direction = MathMax(direction, 0.7);
           }
         else
            direction = MathMin(direction, -0.7);
        }

      // ── v4.0: Structural context (bao gồm thesis health & composite) ──
      ApplyStructuralContext(state, auctionMult, direction, atrPrice);

      direction = MathMax(-1.0, MathMin(1.0, direction));
      m_directionBias = direction;

      double totalMult = vpMult * auctionMult;
      totalMult = MathMax(0.80, MathMin(1.50, totalMult));

      m_absorptionScore = Clamp01(baseScore * totalMult);

      state.flow.absorptionScore = m_absorptionScore;

      if(m_absorptionScore > 0.55 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_ABSORPTION;
         state.pendingEventScores[idx] = m_absorptionScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   double            AbsorptionScore(void) const { return m_absorptionScore; }
   double            DirectionBias(void)   const { return m_directionBias; }
  };

#endif