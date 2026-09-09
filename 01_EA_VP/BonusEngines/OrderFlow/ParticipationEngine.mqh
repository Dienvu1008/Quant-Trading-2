#ifndef __EA_ROOT_PARTICIPATIONENGINE_MQH__
#define __EA_ROOT_PARTICIPATIONENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Participation Engine v4.0 — Auction‑Enhanced Participation        |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+
class CParticipationEngine : public CPipelineModuleBase
  {
private:
   double            m_participation;
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

      // Anchored profiles: high participation near anchored level = breakout fuel
      if(state.vpRangePOC > 0 && MathAbs(bid - state.vpRangePOC) < atrPrice * 0.4)
        {
         auctionMult *= 1.1;
         if(bid > state.vpRangePOC) direction = MathMax(direction, 0.6);
         else                        direction = MathMin(direction, -0.6);
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
         if(bid > state.vpPullbackPOC) direction = MathMax(direction, 0.5);
         else                           direction = MathMin(direction, -0.5);
        }

      // Best HVN: strong volume at key level
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.3)
        {
         auctionMult *= 1.1;
         if(bid > state.vpBestHVN) direction = MathMax(direction, 0.5);
         else                       direction = MathMin(direction, -0.5);
        }

      // Fake breakout: upthrust + high bearish participation = strong sell
      if(state.vpUpthrustDetected) direction = MathMin(direction, -0.7);
      if(state.vpSpringDetected)   direction = MathMax(direction, 0.7);

      // Thin profile: participation likely directional continuation
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         auctionMult *= 1.05;  // keep existing direction

      // VA Overlap bias: strong directional cue
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.7);
      if(vaBias == -1) direction = MathMin(direction, -0.7);

      // Migration confidence strengthens direction
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm (Trend Continuation / Breakout) ──
      if(state.vpValid)
        {
         EEntryArchetype arch = (MathAbs(direction) > 0.5) ? ENTRY_TREND_CONTINUATION : ENTRY_BREAKOUT;
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
      Configure(symbol, "ParticipationEngine");
      m_participation = 0;
      m_directionBias = 0.0;
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
         m_participation = 0.0;
         state.flow.participationScore = 0.0;
         return true;
        }

      // ATR in price (giữ nguyên)
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      // ---- 1. Volume averages (unchanged) ----
      int    window       = MathMin(20, m5Count);
      int    recentStart  = m5Count - window;
      double recentVol    = 0;
      for(int i = recentStart; i < m5Count; i++)
         recentVol += (double)state.marketData.m5Rates[i].tick_volume;
      recentVol /= window;

      double histVol = 0;
      int    histCount = 0;
      for(int i = 0; i < recentStart; i++)
        {
         histVol += (double)state.marketData.m5Rates[i].tick_volume;
         histCount++;
        }
      if(histCount > 0)
         histVol /= histCount;
      else
         histVol = recentVol;

      double baseParticipation = (histVol > 0) ? Clamp01(recentVol / (histVol * 2.0)) : 0.5;

      // ---- 2. Directional filter (unchanged) ----
      double upVol = 0, downVol = 0;
      for(int i = recentStart; i < m5Count; i++)
        {
         double vol = (double)state.marketData.m5Rates[i].tick_volume;
         if(state.marketData.m5Rates[i].close > state.marketData.m5Rates[i].open)
            upVol += vol;
         else if(state.marketData.m5Rates[i].close < state.marketData.m5Rates[i].open)
            downVol += vol;
        }
      double totalDirVol = upVol + downVol;
      double directionality = 0.5;
      if(totalDirVol > 0)
         directionality = upVol / totalDirVol;

      double directionalBias = MathAbs(directionality - 0.5) * 2.0;
      double rawParticipation = baseParticipation * 0.6 + baseParticipation * directionalBias * 0.4;

      // ---- 3. Original VP context (preserved) ----
      double vpMult = 1.0;
      if(state.vpValid)
        {
         if(!state.vpInsideVA) vpMult *= 1.08;
         else if(MathAbs(state.vpPriceVsVA) > 0.8) vpMult *= 1.04;
         if(MathAbs(state.vpPriceVsPOC) < 0.15) vpMult *= 1.10;
         if(state.auctValueAreaState == (int)VA_EXPANDING) vpMult *= 1.07;
         else if(state.auctValueAreaState == (int)VA_CONTRACTING) vpMult *= 0.95;
         if(state.auctAcceptanceScore > 0.65) vpMult *= 1.06;
         else if(state.auctAcceptanceScore < 0.25) vpMult *= 0.94;
         if(state.auctFailureScore > 0.4) vpMult *= 0.95;
         if(state.vpMigrationScore > 0.3)
           {
            double vpDir = state.vpMigrationDirRaw;
            if((vpDir > 0 && directionality > 0.6) || (vpDir < 0 && directionality < 0.4))
               vpMult *= 1.08;
            else if((vpDir > 0 && directionality < 0.4) || (vpDir < 0 && directionality > 0.6))
               vpMult *= 0.95;
           }
        }

      // ---- 4. Auction Regime & Advanced Context ----
      double auctionMult = 1.0;
      double direction   = (directionality > 0.5) ? 1.0 : -1.0;

      if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
        {
         auctionMult = 1.15;
         double trendDir = (state.vpDevPOCSlope > 0.02) ? 1.0 : ((state.vpDevPOCSlope < -0.02) ? -1.0 : 0);
         if(direction * trendDir > 0) auctionMult *= 1.1;
         else if(trendDir != 0) auctionMult *= 0.9;
         direction = trendDir != 0 ? trendDir : direction;
        }
      else if(regime == (int)REGIME_BALANCED_ROTATION)
        {
         auctionMult = 1.05;
        }
      else if(regime == (int)REGIME_TREND_EXHAUSTION)
        {
         auctionMult = 1.1;
         direction = (directionality > 0.5) ? -0.7 : 0.7;
        }
      else if(regime == (int)REGIME_FAILED_AUCTION)
        {
         auctionMult = 1.2;
         direction = (directionality > 0.5) ? -0.8 : 0.8;
        }

      if(state.auctExhaustionScore > 0.65) auctionMult *= 0.9;
      if(state.auctContinuationScore > 0.7) auctionMult *= 1.1;

      if(MathAbs(state.vpDevPOCSlope) > 0.03)
        {
         if(state.vpDevPOCSlope > 0) direction = MathMax(direction, 0.6);
         else                         direction = MathMin(direction, -0.6);
        }

      // Composite profile context (giữ nguyên)
      if(state.vpValid)
        {
         double bid = state.marketData.bid;
         if(MathAbs(bid - state.vpCompositeVAH) < atrPrice * 0.3 ||
            MathAbs(bid - state.vpCompositeVAL) < atrPrice * 0.3)
            auctionMult *= 1.1;
         if(bid > state.vpCompositePOC) direction = MathMax(direction, 0.3);
         else direction = MathMin(direction, -0.3);
        }

      // Naked POC
      if(state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.6)
        {
         if(state.marketData.bid < state.vpNearestNakedPOC) direction = MathMax(direction, 0.6);
         else direction = MathMin(direction, -0.6);
        }

      // ── v4.0: Structural context (bao gồm thesis health & composite) ──
      ApplyStructuralContext(state, auctionMult, direction, atrPrice);

      direction = MathMax(-1.0, MathMin(1.0, direction));
      m_directionBias = direction;

      double totalMult = vpMult * auctionMult;
      totalMult = MathMax(0.80, MathMin(1.35, totalMult));

      m_participation = Clamp01(rawParticipation * totalMult);
      state.flow.participationScore = m_participation;

      if(m_participation > 0.55 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_PARTICIPATION;
         state.pendingEventScores[idx] = m_participation;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   double            Participation(void)  const { return m_participation; }
   double            DirectionBias(void)  const { return m_directionBias; }
  };

#endif