#ifndef __EA_ROOT_STOPCLUSTERDETECTOR_MQH__
#define __EA_ROOT_STOPCLUSTERDETECTOR_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Stop Cluster Detector v4.0 — Auction‑Enhanced Sweep Finder        |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+
class CStopClusterDetector : public CPipelineModuleBase
  {
private:
   double            m_clusterScore;
   double            m_clusterAbove;
   double            m_clusterBelow;
   double            m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (mở rộng với thesis health & composite) |
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double &clusterAbove,
                                            double &clusterBelow,
                                            double &direction,
                                            double &qualityMult,
                                            double atrPrice)
     {
      double bid = state.marketData.bid;

      // --- Các yếu tố ban đầu (giữ nguyên) ---
      if(state.vpRangePOC > 0 && MathAbs(bid - state.vpRangePOC) < atrPrice * 0.5)
        {
         if(state.vpRangePOC > bid) clusterAbove = MathMin(1.0, clusterAbove + 0.10);
         else                      clusterBelow = MathMin(1.0, clusterBelow + 0.10);
        }
      if(state.vpBreakoutPOC > 0 && MathAbs(bid - state.vpBreakoutPOC) < atrPrice * 0.5)
        {
         if(state.vpBreakoutPOC > bid) clusterAbove = MathMin(1.0, clusterAbove + 0.12);
         else                         clusterBelow = MathMin(1.0, clusterBelow + 0.12);
        }
      if(state.vpPullbackPOC > 0 && MathAbs(bid - state.vpPullbackPOC) < atrPrice * 0.5)
        {
         if(state.vpPullbackPOC > bid) clusterAbove = MathMin(1.0, clusterAbove + 0.08);
         else                         clusterBelow = MathMin(1.0, clusterBelow + 0.08);
        }

      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.4)
        {
         if(state.vpBestHVN > bid) clusterAbove = MathMin(1.0, clusterAbove + 0.12);
         else                     clusterBelow = MathMin(1.0, clusterBelow + 0.12);
        }

      if(state.vpUpthrustDetected)
        {
         clusterAbove = MathMin(1.0, clusterAbove + 0.15);
         direction = MathMin(direction, -0.8);
        }
      if(state.vpSpringDetected)
        {
         clusterBelow = MathMin(1.0, clusterBelow + 0.15);
         direction = MathMax(direction, 0.8);
        }

      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
        {
         clusterAbove = MathMin(1.0, clusterAbove + 0.05);
         clusterBelow = MathMin(1.0, clusterBelow + 0.05);
        }

      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.7);
      if(vaBias == -1) direction = MathMin(direction, -0.7);

      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm (Sweep Reversal) ──────────
      if(state.vpValid)
        {
         if(m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
            m_thesisManager.InitTrade(ENTRY_SWEEP_REVERSAL, atrPrice,
                                      state.auctRegimeConfidence, m_symbol);

         SThesisOutput out = m_thesisManager.Evaluate(state, 0.0, atrPrice);
         double health = out.thesis.thesisHealth;
         qualityMult *= (0.8 + health * 0.4);
         if(health < 0.3 && direction != 0) direction *= 0.5;
        }

      // ── v4.0: Xác nhận composite đa khung thời gian ─────────
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
      Configure(symbol, "StopClusterDetector");
      m_clusterScore  = 0;
      m_clusterAbove  = 0;
      m_clusterBelow  = 0;
      m_directionBias = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      double currentBid = state.marketData.bid;
      double pointSize  = state.marketData.pointSize;
      double atrPrice   = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         m_clusterScore = 0.0;
         state.liquidity.stopClusterScore = 0.0;
         return true;
        }

      int highCount = state.structure.swingHighCount;
      int lowCount  = state.structure.swingLowCount;

      // ── Swing-based stop counts (giữ nguyên) ──────────────────
      int aboveCount = 0;
      for(int i = 0; i < highCount; i++)
         if(state.structure.swingHighs[i].price > currentBid &&
            state.structure.swingHighs[i].price - currentBid < atrPrice * 2.0)
            aboveCount++;

      int belowCount = 0;
      for(int i = 0; i < lowCount; i++)
         if(state.structure.swingLows[i].price < currentBid &&
            currentBid - state.structure.swingLows[i].price < atrPrice * 2.0)
            belowCount++;

      // ── Round number bonus ────────────────────────────────────
      double pip       = pointSize * 10.0;
      double roundStep = pip * 50.0;
      double roundBonus = 0.0;
      if(roundStep > 0)
        {
         double mod = MathMod(currentBid, roundStep);
         if(MathMin(mod, roundStep - mod) < atrPrice * 0.2)
            roundBonus = 0.2;
        }

      m_clusterAbove = MathMin(Clamp01((double)aboveCount / 5.0) + roundBonus, 1.0);
      m_clusterBelow = MathMin(Clamp01((double)belowCount / 5.0) + roundBonus, 1.0);

      // ── Original VP enhancements ─────────────────────────────
      if(state.vpValid)
        {
         if(state.auctMajorHVN > currentBid && state.auctDistToMajorHVN_ATR < 1.5)
            m_clusterAbove = MathMin(1.0, m_clusterAbove + 0.12);
         if(state.auctMajorHVN > 0 && state.auctMajorHVN < currentBid && state.auctDistToMajorHVN_ATR < 1.5)
            m_clusterBelow = MathMin(1.0, m_clusterBelow + 0.12);

         if(state.vpDistToLVN_ATR < 0.8 && state.vpDistToLVN_ATR > 0)
           {
            if(state.vpNearestLVN > currentBid) m_clusterAbove = MathMin(1.0, m_clusterAbove + 0.08);
            else m_clusterBelow = MathMin(1.0, m_clusterBelow + 0.08);
           }

         if(state.auctProfileShape == (int)PROFILE_P && state.auctProfileShapeConf > 0.40)
            m_clusterAbove = MathMin(1.0, m_clusterAbove + 0.08);
         if(state.auctProfileShape == (int)PROFILE_b && state.auctProfileShapeConf > 0.40)
            m_clusterBelow = MathMin(1.0, m_clusterBelow + 0.08);
        }

      // ── Auction context & directional bias (cập nhật để dùng qualityMult động) ──
      double qualityMult = 1.0;
      double direction   = 0.0;

      if(regime == REGIME_BALANCED_ROTATION)
        {
         qualityMult = 1.25;
         if(m_clusterAbove > m_clusterBelow + 0.1) direction = 1.0;
         else if(m_clusterBelow > m_clusterAbove + 0.1) direction = -1.0;
        }
      else if(regime == REGIME_TREND_CONTINUATION || regime == REGIME_TREND_INITIATION)
        {
         double trendDir = 0;
         if(state.vpDevPOCSlope > 0.02) trendDir = 1.0;
         else if(state.vpDevPOCSlope < -0.02) trendDir = -1.0;
         if(trendDir > 0)
           {
            m_clusterAbove = MathMin(1.0, m_clusterAbove + 0.15);
            m_clusterBelow = MathMax(0.0, m_clusterBelow - 0.1);
            direction = 1.0;
           }
         else if(trendDir < 0)
           {
            m_clusterBelow = MathMin(1.0, m_clusterBelow + 0.15);
            m_clusterAbove = MathMax(0.0, m_clusterAbove - 0.1);
            direction = -1.0;
           }
         qualityMult = 1.15;
        }
      else if(regime == REGIME_TREND_EXHAUSTION)
        {
         if(state.vpPriceVsVA > 0.7 && m_clusterAbove > 0.4) direction = -1.0;
         else if(state.vpPriceVsVA < 0.3 && m_clusterBelow > 0.4) direction = 1.0;
         qualityMult = 1.1;
        }
      else if(regime == REGIME_FAILED_AUCTION)
        {
         qualityMult = 1.2;
         if(state.vpInsideVA && state.vpPriceVsVA > 0.5) direction = -1.0;
         else if(state.vpInsideVA && state.vpPriceVsVA < 0.5) direction = 1.0;
        }

      if(state.auctAcceptanceScore > 0.65) qualityMult *= 0.9;
      if(state.auctExhaustionScore > 0.6)  qualityMult *= 0.85;
      if(state.auctContinuationScore > 0.7) qualityMult *= 1.1;

      // ── Composite profile context ────────────────────────────
      if(state.vpValid)
        {
         double bid = state.marketData.bid;
         if(MathAbs(bid - state.vpCompositeVAH) < atrPrice * 0.3)
            m_clusterAbove = MathMin(1.0, m_clusterAbove + 0.15);
         if(MathAbs(bid - state.vpCompositeVAL) < atrPrice * 0.3)
            m_clusterBelow = MathMin(1.0, m_clusterBelow + 0.15);
         if(bid > state.vpCompositeVAH) direction = MathMax(direction, 0.5);
         if(bid < state.vpCompositeVAL) direction = MathMin(direction, -0.5);
         qualityMult *= 1.1;
        }

      // ── Naked POC magnet ─────────────────────────────────────
      if(state.vpNearestNakedPOC > 0)
        {
         double dist = MathAbs(currentBid - state.vpNearestNakedPOC);
         if(dist < atrPrice * 1.5)
           {
            if(currentBid < state.vpNearestNakedPOC)
               m_clusterAbove = MathMin(1.0, m_clusterAbove + 0.08);
            else
               m_clusterBelow = MathMin(1.0, m_clusterBelow + 0.08);
            if(currentBid < state.vpNearestNakedPOC && m_clusterAbove > 0.4) direction = MathMax(direction, 0.7);
            if(currentBid > state.vpNearestNakedPOC && m_clusterBelow > 0.4) direction = MathMin(direction, -0.7);
           }
        }

      // ── v4.0: Structural context (bao gồm thesis health & composite) ──
      ApplyStructuralContext(state, m_clusterAbove, m_clusterBelow, direction, qualityMult, atrPrice);

      direction = MathMax(-1.0, MathMin(1.0, direction));
      m_directionBias = direction;

      m_clusterScore = Clamp01(MathMax(m_clusterAbove, m_clusterBelow) * qualityMult);

      state.liquidity.stopClusterScore = m_clusterScore;

      if(m_clusterScore > 0.5 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_STOP_CLUSTER;
         state.pendingEventScores[idx] = m_clusterScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   double            ClusterAbove(void) const { return m_clusterAbove; }
   double            ClusterBelow(void) const { return m_clusterBelow; }
   double            ClusterScore(void)  const { return m_clusterScore; }
   double            DirectionBias(void) const { return m_directionBias; }
  };

#endif