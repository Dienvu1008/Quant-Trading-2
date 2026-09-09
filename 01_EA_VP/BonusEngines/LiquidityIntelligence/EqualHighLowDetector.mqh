#ifndef __EA_ROOT_EQUALHIGHLOWDETECTOR_MQH__
#define __EA_ROOT_EQUALHIGHLOWDETECTOR_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Equal High/Low Detector v4.0 — Auction‑Enhanced Liquidity Pool    |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

class CEqualHighLowDetector : public CPipelineModuleBase
  {
private:
   double            m_equalHighLowScore;
   int               m_equalHighs;
   int               m_equalLows;
   double            m_toleranceATRMult;
   double            m_directionBias;

   CAuctionThesisManager m_thesisManager;   // đánh giá sức khỏe luận điểm

public:
   CEqualHighLowDetector() : m_equalHighLowScore(0),
                              m_equalHighs(0),
                              m_equalLows(0),
                              m_toleranceATRMult(0.1),
                              m_directionBias(0.0) {}

   void              Bootstrap(const string symbol)
     {
      Configure(symbol, "EqualHighLowDetector");
      m_equalHighLowScore = 0;
      m_equalHighs = 0;
      m_equalLows = 0;
      m_directionBias = 0.0;
      m_thesisManager.Reset();
     }

   void              SetToleranceMultiplier(double multiplier)
     {
      m_toleranceATRMult = MathMax(0.01, multiplier);
     }

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double &qualityMult,
                                            double &direction,
                                            double atrPrice)
     {
      // Anchored profiles near equal highs/lows -> breakout potential
      double anchorPrices[] = { state.vpRangePOC, state.vpBreakoutPOC, state.vpPullbackPOC };
      double bid = state.marketData.bid;
      for(int i = 0; i < 3; i++)
        {
         if(anchorPrices[i] > 0 && MathAbs(bid - anchorPrices[i]) < atrPrice * 0.4)
           {
            qualityMult *= 1.15;
            if(anchorPrices[i] > bid) direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
            else direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
            break;
           }
        }

      // Best HVN
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.4)
        {
         qualityMult *= 1.1;
         if(state.vpBestHVN > bid) direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
         else direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
        }

      // Fake breakout -> liquidity trap, reversal likely
      if(state.vpUpthrustDetected || state.vpSpringDetected)
        {
         qualityMult *= 1.2;
         if(state.vpUpthrustDetected) direction = MathMin(direction, -0.6);
         if(state.vpSpringDetected)   direction = MathMax(direction, 0.6);
        }

      // Thin profile -> breakout more explosive
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         qualityMult *= 1.1;

      // VA Overlap bias
      int vaBias = state.vpVAOverlapBias;
      if(vaBias != 0 && MathAbs(state.vpDevPOCSlope) < 0.02)
        {
         double vaDir = (vaBias == 1) ? 0.7 : -0.7;
         if(direction == 0) direction = vaDir;
         else direction = direction * 0.6 + vaDir * 0.4;
        }

      // Migration confidence
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm ─────────────────────────────
      if(state.vpValid)
        {
         if(m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
            m_thesisManager.InitTrade(ENTRY_BREAKOUT, atrPrice,
                                      state.auctRegimeConfidence, m_symbol);

         SThesisOutput out = m_thesisManager.Evaluate(state, 0.0, atrPrice);
         double health = out.thesis.thesisHealth;
         qualityMult *= (0.8 + health * 0.4);
         if(health < 0.3 && direction != 0) direction *= 0.5;
        }

      // ── v4.0: Xác nhận composite đa khung thời gian ──────────
      if(state.vpValid && direction != 0)
        {
         if((direction == 1 && bid > state.vpCompositeVAH) ||
            (direction == -1 && bid < state.vpCompositeVAL))
            qualityMult *= 1.08;   // giá đã vượt hẳn biên composite
         else if((direction == 1 && bid < state.vpCompositeVAL) ||
                 (direction == -1 && bid > state.vpCompositeVAH))
            qualityMult *= 0.90;   // giá ngược phía, tín hiệu yếu
        }
     }

   //+------------------------------------------------------------------+
   //| Compute auction & VP quality adjustment (v4.0: bộ lọc regime)    |
   //+------------------------------------------------------------------+
   void              ComputeContextAdjustment(const SPipelineState &state,
                                              double &qualityMult,
                                              double &direction,
                                              double atrPrice)
     {
      qualityMult = 1.0;
      direction   = 0.0;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         qualityMult = 0.0;   // triệt tiêu tín hiệu
         return;
        }

      // ── 1. Auction Regime ───────────────────────────────────
      if(regime == REGIME_BALANCED_ROTATION)
         qualityMult *= 1.0 + 0.3 * regimeConf;
      else if(regime == REGIME_TREND_CONTINUATION ||
              regime == REGIME_TREND_INITIATION)
         qualityMult *= 0.9;
      else if(regime == REGIME_TREND_EXHAUSTION)
         qualityMult *= 0.8;
      else if(regime == REGIME_FAILED_AUCTION)
         qualityMult *= 1.15;

      // ── 2. Acceptance / Exhaustion ──────────────────────────
      if(state.auctAcceptanceScore > 0.65) qualityMult *= 0.85;
      if(state.auctExhaustionScore > 0.6)  qualityMult *= 0.85;
      if(state.auctContinuationScore > 0.7) qualityMult *= 1.1;

      // ── 3. Directional bias from developing POC & VA position ──
      if(MathAbs(state.vpDevPOCSlope) > 0.03)
         direction = (state.vpDevPOCSlope > 0) ? 1.0 : -1.0;
      else
        {
         if(m_equalHighs > m_equalLows) direction = -0.3;
         else if(m_equalLows > m_equalHighs) direction = 0.3;

         if(state.vpInsideVA)
           {
            if(state.vpPriceVsVA > 0.7) direction = 1.0;
            else if(state.vpPriceVsVA < 0.3) direction = -1.0;
           }
         else
            direction = (state.marketData.bid > state.vpVAH) ? 1.0 : -1.0;
        }

      // ── 4. Composite (institutional) boundary ───────────────
      if(state.vpValid && atrPrice > 0)
        {
         double bid = state.marketData.bid;
         double distToTop = (state.vpCompositeVAH - bid) / atrPrice;
         double distToBot = (bid - state.vpCompositeVAL) / atrPrice;
         if(MathMin(distToTop, distToBot) < 0.3)
           {
            qualityMult *= 1.2;
            if(distToTop < distToBot)
               direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
            else
               direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
           }
        }

      // ── 5. Naked POC proximity ──────────────────────────────
      if(state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.5)
        {
         qualityMult *= 1.1;
         if(state.marketData.bid < state.vpNearestNakedPOC)
            direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
         else
            direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
        }

      // ── 6. Structural V3 context (đã có thesis & composite trong đó) ──
      ApplyStructuralContext(state, qualityMult, direction, atrPrice);

      direction = MathMax(-1.0, MathMin(1.0, direction));
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      m_equalHighs = 0;
      m_equalLows = 0;

      int highCount = state.structure.swingHighCount;
      int lowCount  = state.structure.swingLowCount;

      // ── Dynamic tolerance (giữ nguyên) ──────────────────────
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;
      double tolerance = atrPrice * m_toleranceATRMult;
      if(tolerance <= 0) tolerance = pointSize * 5;

      // ── Count equal high pairs ──────────────────────────────
      if(highCount >= 2)
        {
         int eqHigh = 0;
         for(int i = 0; i < highCount - 1; i++)
            for(int j = i + 1; j < highCount; j++)
               if(MathAbs(state.structure.swingHighs[i].price - state.structure.swingHighs[j].price) <= tolerance)
                  eqHigh++;
         m_equalHighs = eqHigh;
        }

      // ── Count equal low pairs ───────────────────────────────
      if(lowCount >= 2)
        {
         int eqLow = 0;
         for(int i = 0; i < lowCount - 1; i++)
            for(int j = i + 1; j < lowCount; j++)
               if(MathAbs(state.structure.swingLows[i].price - state.structure.swingLows[j].price) <= tolerance)
                  eqLow++;
         m_equalLows = eqLow;
        }

      // ── Raw score ───────────────────────────────────────────
      double maxRatio = 0.0;
      if(highCount >= 2)
        {
         double totalHighPairs = (highCount * (highCount - 1)) / 2.0;
         maxRatio = MathMax(maxRatio, (double)m_equalHighs / totalHighPairs);
        }
      if(lowCount >= 2)
        {
         double totalLowPairs = (lowCount * (lowCount - 1)) / 2.0;
         maxRatio = MathMax(maxRatio, (double)m_equalLows / totalLowPairs);
        }

      // ── Volume Profile boost ────────────────────────────────
      double vpBoost = 1.0;
      if(state.vpValid)
        {
         if(state.vpDistToLVN_ATR < 0.5) vpBoost = MathMax(vpBoost, 1.5);
         if(state.vpInsideVA && MathAbs(state.vpPriceVsVA) > 0.8) vpBoost = MathMax(vpBoost, 1.3);
         if(MathAbs(state.vpPriceVsPOC) < 0.2) vpBoost = MathMax(vpBoost, 1.4);
        }

      double baseScore = maxRatio * vpBoost;

      // ── Auction / advanced VP adjustment ───────────────────
      double auctionMult = 1.0;
      double direction   = 0.0;
      if(state.vpValid && baseScore > 0.15)
         ComputeContextAdjustment(state, auctionMult, direction, atrPrice);

      m_equalHighLowScore = Clamp01(baseScore * auctionMult);
      m_directionBias     = direction;

      // ── Write to state ─────────────────────────────────────
      state.liquidity.equalHighLowScore = m_equalHighLowScore;

      if(m_equalHighLowScore > 0.5 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_EQUAL_HIGH_LOW;
         state.pendingEventScores[idx] = m_equalHighLowScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   double            EqualHighLowScore() const { return m_equalHighLowScore; }
   int               EqualHighs()        const { return m_equalHighs; }
   int               EqualLows()         const { return m_equalLows; }
   double            DirectionBias()     const { return m_directionBias; }
  };

#endif