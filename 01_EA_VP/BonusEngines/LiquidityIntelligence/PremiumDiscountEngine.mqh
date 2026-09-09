#ifndef __EA_ROOT_PREMIUMDISCOUNTENGINE_MQH__
#define __EA_ROOT_PREMIUMDISCOUNTENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Premium/Discount Engine v4.0 — Auction‑Enhanced Fair Value        |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

class CPremiumDiscountEngine : public CPipelineModuleBase
  {
private:
   double            m_premiumDiscountScore;
   bool              m_inPremium;
   bool              m_inDiscount;
   double            m_premiumTrend;
   double            m_scoreHistory[5];
   int               m_histIdx;
   double            m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double &score,
                                            double &directionBias,
                                            double atrPrice)
     {
      double bid = state.marketData.bid;

      // Anchored profiles
      if(state.vpRangePOC > 0 && MathAbs(bid - state.vpRangePOC) < atrPrice * 0.4)
        {
         if(bid > state.vpRangePOC) score = MathMax(score, 0.65);
         else score = MathMin(score, 0.35);
        }
      if(state.vpBreakoutPOC > 0 && MathAbs(bid - state.vpBreakoutPOC) < atrPrice * 0.4)
        {
         if(bid > state.vpBreakoutPOC) score = MathMax(score, 0.7);
         else score = MathMin(score, 0.3);
        }
      if(state.vpPullbackPOC > 0 && MathAbs(bid - state.vpPullbackPOC) < atrPrice * 0.4)
        {
         if(bid > state.vpPullbackPOC) score = MathMax(score, 0.6);
         else score = MathMin(score, 0.4);
        }

      // Best HVN: strong fair value level, softens extreme scores
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.3)
        {
         score = score * 0.6 + 0.5 * 0.4;
         directionBias = (bid < state.vpBestHVN) ? MathMax(directionBias, 0.3) : MathMin(directionBias, -0.3);
        }

      // Fake breakout traps
      if(state.vpUpthrustDetected)
        { if(score > 0.6) directionBias = MathMin(directionBias, -0.7); }
      if(state.vpSpringDetected)
        { if(score < 0.4) directionBias = MathMax(directionBias, 0.7); }

      // Thin profile: score less reliable
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         score = score * 0.9 + 0.5 * 0.1;

      // VA Overlap bias
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1 && score > 0.5) directionBias = MathMax(directionBias, 0.5);
      if(vaBias == -1 && score < 0.5) directionBias = MathMin(directionBias, -0.5);

      // Migration confidence
      if(state.vpMigrationConfidence > 0.6)
        {
         double migDir = (state.vpDevPOCDirection > 0) ? 1.0 : -1.0;
         directionBias = directionBias * 0.5 + migDir * 0.5;
        }

      // ── v4.0: Sức khỏe luận điểm (Mean Reversion) ────────────
      if(state.vpValid)
        {
         if(m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
            m_thesisManager.InitTrade(ENTRY_MEAN_REVERSION, atrPrice,
                                      state.auctRegimeConfidence, m_symbol);

         SThesisOutput out = m_thesisManager.Evaluate(state, 0.0, atrPrice);
         double health = out.thesis.thesisHealth;
         // Khi luận điểm yếu, kéo score về 0.5 (mất hiệu lực premium/discount)
         score = score * (0.7 + health * 0.3) + 0.5 * (0.3 - health * 0.3);
         if(health < 0.3 && directionBias != 0) directionBias *= 0.5;
        }

      // ── v4.0: Xác nhận composite đa khung thời gian ──────────
      if(state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
        {
         if(score > 0.5 && bid > state.vpCompositeVAH)
            score = MathMax(score, 0.65);   // premium xác nhận
         else if(score < 0.5 && bid < state.vpCompositeVAL)
            score = MathMin(score, 0.35);   // discount xác nhận
         else if(score > 0.5 && bid < state.vpCompositePOC)
            score = score * 0.9 + 0.5 * 0.1; // premium không thuyết phục
         else if(score < 0.5 && bid > state.vpCompositePOC)
            score = score * 0.9 + 0.5 * 0.1; // discount không thuyết phục
        }
     }

public:
   void              Bootstrap(const string symbol)
     {
      Configure(symbol, "PremiumDiscountEngine");
      m_premiumDiscountScore = 0.5;
      m_inPremium = false;
      m_inDiscount = false;
      m_premiumTrend = 0;
      m_histIdx = 0;
      m_directionBias = 0.0;
      ArrayInitialize(m_scoreHistory, 0.5);
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         m_premiumDiscountScore = 0.5;   // không premium cũng không discount
         m_inPremium = false;
         m_inDiscount = false;
         m_directionBias = 0.0;
         state.liquidity.premiumDiscountScore = 0.5;
         return true;
        }

      // --- 1. D1 structural range (unchanged) ---
      MqlRates d1Rates[];
      int d1Copied = CopyRates(m_symbol, PERIOD_D1, 0, 5, d1Rates);
      if(d1Copied < 2) return true;

      double high = d1Rates[0].high, low = d1Rates[0].low;
      for(int i = 1; i < d1Copied; i++)
        {
         if(d1Rates[i].high > high) high = d1Rates[i].high;
         if(d1Rates[i].low  < low)  low  = d1Rates[i].low;
        }

      double rangeD1 = high - low;
      double currentPrice = state.marketData.bid;
      double structuralScore = 0.5;
      if(rangeD1 > 0)
         structuralScore = Clamp01((currentPrice - low) / rangeD1);

      // --- 2. VP-enhanced score (fixed unit) ---
      double vpScore = 0.5;
      double vpWeight = 0.0;

      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      if(state.vpValid && state.vpVAH > state.vpVAL)
        {
         double vpConfidence = state.vpInsideVA ? 0.8 : 0.6;
         double vaRange = state.vpVAH - state.vpVAL;

         if(currentPrice > state.vpVAH)
           {
            double distAbove = currentPrice - state.vpVAH;
            double factor = Clamp01(distAbove / MathMax(atrPrice, pointSize));
            vpScore = 0.70 + factor * 0.30;
           }
         else if(currentPrice < state.vpVAL)
           {
            double distBelow = state.vpVAL - currentPrice;
            double factor = Clamp01(distBelow / MathMax(atrPrice, pointSize));
            vpScore = 0.30 - factor * 0.30;
           }
         else
           {
            vpScore = 0.35 + 0.30 * ((currentPrice - state.vpVAL) / vaRange);
           }

         if(MathAbs(state.vpPriceVsPOC) < 0.2)
            vpScore = vpScore * 0.7 + 0.5 * 0.3;

         if(state.auctAcceptanceScore > 0.65)
           {
            if(vpScore > 0.6 || vpScore < 0.4)
               vpScore = vpScore * 0.6 + 0.5 * 0.4;
           }

         vpWeight = vpConfidence;
        }

      // --- 2b. Composite VP macro adjustment ---
      double compositeAdjust = 0;
      if(state.vpCompositeVAH > state.vpCompositeVAL && state.vpCompositePOC > 0)
        {
         if(currentPrice > state.vpCompositeVAH)
            compositeAdjust = +0.08;
         else if(currentPrice < state.vpCompositeVAL)
            compositeAdjust = -0.08;
        }

      // --- 3. Blend structural and VP scores ---
      if(vpWeight > 0.0)
        {
         double structuralWeight = 1.0 - vpWeight;
         m_premiumDiscountScore = vpScore * vpWeight + structuralScore * structuralWeight;
         m_premiumDiscountScore += compositeAdjust;
        }
      else
         m_premiumDiscountScore = structuralScore;

      m_premiumDiscountScore = Clamp01(m_premiumDiscountScore);

      // --- 4. Auction Context Adjustment ---
      double directionBias     = 0.0;
      double premiumScore      = m_premiumDiscountScore;

      if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
        {
         double soft = 0.3 * regimeConf;
         premiumScore = premiumScore * (1.0 - soft) + 0.5 * soft;
         if(state.vpDevPOCSlope > 0.01) directionBias = 1.0;
         else if(state.vpDevPOCSlope < -0.01) directionBias = -1.0;
        }
      else if(regime == (int)REGIME_BALANCED_ROTATION)
        {
         if(premiumScore > 0.6) directionBias = -1.0;
         else if(premiumScore < 0.4) directionBias = 1.0;
         if(premiumScore > 0.7) premiumScore = MathMin(1.0, premiumScore * 1.1);
         if(premiumScore < 0.3) premiumScore = MathMax(0.0, premiumScore * 0.9);
        }
      else if(regime == (int)REGIME_TREND_EXHAUSTION)
        {
         if(premiumScore > 0.6) directionBias = -1.0;
         else if(premiumScore < 0.4) directionBias = 1.0;
        }
      else if(regime == (int)REGIME_FAILED_AUCTION)
        {
         if(premiumScore > 0.6) directionBias = -1.0;
         else if(premiumScore < 0.4) directionBias = 1.0;
        }

      if(state.auctExhaustionScore > 0.7)
        {
         if(premiumScore > 0.6) directionBias = -1.0;
         if(premiumScore < 0.4) directionBias = 1.0;
        }
      if(state.auctContinuationScore > 0.7)
        {
         if(premiumScore > 0.6 && directionBias == -1.0) directionBias = -0.3;
         if(premiumScore < 0.4 && directionBias == 1.0) directionBias = 0.3;
        }

      if(state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.6)
        {
         if(currentPrice < state.vpNearestNakedPOC && premiumScore > 0.6)
            directionBias = MathMax(directionBias, 0.5);
         else if(currentPrice > state.vpNearestNakedPOC && premiumScore < 0.4)
            directionBias = MathMin(directionBias, -0.5);
        }

      if(state.vpCompositePOC > 0)
        {
         if(currentPrice > state.vpCompositePOC)
            directionBias = MathMax(directionBias, 0.2);
         else
            directionBias = MathMin(directionBias, -0.2);
        }

      // --- 5. Structural V3 + v4.0 (thesis + composite) ---
      ApplyStructuralContext(state, premiumScore, directionBias, atrPrice);

      directionBias = MathMax(-1.0, MathMin(1.0, directionBias));
      m_premiumDiscountScore = Clamp01(premiumScore);

      // --- 6. Trend detection (unchanged) ---
      m_scoreHistory[m_histIdx % 5] = m_premiumDiscountScore;
      m_histIdx++;
      double avg5 = 0.0;
      for(int i = 0; i < 5; i++) avg5 += m_scoreHistory[i];
      avg5 /= 5.0;
      m_premiumTrend = m_premiumDiscountScore - avg5;

      m_inPremium  = (m_premiumDiscountScore > 0.7);
      m_inDiscount = (m_premiumDiscountScore < 0.3);
      m_directionBias = directionBias;

      state.liquidity.premiumDiscountScore = m_premiumDiscountScore;

      if(m_inPremium && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_PREMIUM;
         state.pendingEventScores[idx] = m_premiumDiscountScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }
      else if(m_inDiscount && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_DISCOUNT;
         state.pendingEventScores[idx] = m_premiumDiscountScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   bool              InPremium(void)          const { return m_inPremium; }
   bool              InDiscount(void)         const { return m_inDiscount; }
   double            Score(void)              const { return m_premiumDiscountScore; }
   double            PremiumTrend(void)       const { return m_premiumTrend; }
   double            DirectionBias(void)      const { return m_directionBias; }
  };

#endif