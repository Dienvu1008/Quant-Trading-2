#ifndef __EA_ROOT_SWEEPENGINE_MQH__
#define __EA_ROOT_SWEEPENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Sweep Engine v4.0 — Auction‑Enhanced Liquidity Sweep              |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+
class CSweepEngine : public CPipelineModuleBase
  {
private:
   double            m_sweepScore;
   bool              m_bullishSweep;
   bool              m_bearishSweep;
   double            m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double sweptLevel,
                                            bool isBullish,
                                            double &qualityMult,
                                            double &direction,
                                            double atrPrice)
     {
      double bid = state.marketData.bid;

      // Anchored profiles at swept level
      double anchors[] = { state.vpRangePOC, state.vpBreakoutPOC, state.vpPullbackPOC };
      for(int i = 0; i < 3; i++)
        {
         if(anchors[i] > 0 && MathAbs(sweptLevel - anchors[i]) < atrPrice * 0.4)
           {
            qualityMult *= 1.2;
            if(isBullish) direction = MathMax(direction, 0.8);
            else         direction = MathMin(direction, -0.8);
            break;
           }
        }
      // Best HVN swept
      if(state.vpBestHVN > 0 && MathAbs(sweptLevel - state.vpBestHVN) < atrPrice * 0.3)
         qualityMult *= 1.15;
      // Fake breakout: if we just had an upthrust and now a bearish sweep, great
      if(state.vpUpthrustDetected && !isBullish)  qualityMult *= 1.2;
      if(state.vpSpringDetected && isBullish)     qualityMult *= 1.2;
      // Thin profile: sweeps more explosive
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         qualityMult *= 1.1;
      // VA Overlap bias
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.7);
      if(vaBias == -1) direction = MathMin(direction, -0.7);
      // Migration confidence
      if(state.vpMigrationConfidence > 0.6)
        {
         double migDir = (state.vpDevPOCDirection > 0) ? 1.0 : -1.0;
         direction = direction * 0.6 + migDir * 0.4;
        }

      // ── v4.0: Sức khỏe luận điểm (Sweep Reversal) ───────────
      if(state.vpValid)
        {
         if(m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
            m_thesisManager.InitTrade(ENTRY_SWEEP_REVERSAL, atrPrice,
                                      state.auctRegimeConfidence, m_symbol);

         // thesisHealth removed: already accounted for in auction adjustment above
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
      Configure(symbol, "SweepEngine");
      m_sweepScore = 0;
      m_bullishSweep = false;
      m_bearishSweep = false;
      m_directionBias = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      m_bullishSweep = false;
      m_bearishSweep = false;
      m_sweepScore = 0;
      m_directionBias = 0.0;

      int m5Count   = state.marketData.m5Copied;
      int highCount = state.structure.swingHighCount;
      int lowCount  = state.structure.swingLowCount;
      if(m5Count < 5 || highCount < 1 || lowCount < 1) return true;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         state.liquidity.sweepScore = 0.0;
         return true;
        }

      // ATR in price (giữ nguyên)
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      double swingLow  = state.structure.swingLows[lowCount-1].price;
      double swingHigh = state.structure.swingHighs[highCount-1].price;
      int    last      = m5Count - 1;

      double avgVol = 0;
      for(int i = 0; i < m5Count; i++)
         avgVol += (double)state.marketData.m5Rates[i].tick_volume;
      avgVol /= m5Count;

      // ─── Bullish Sweep Detection ────────────────────────────
      bool anyPiercedLow = false;
      int  piercedLowIdx = -1;
      for(int i = MathMax(0, m5Count-5); i < m5Count; i++)
        {
         if(state.marketData.m5Rates[i].low < swingLow)
           {
            anyPiercedLow = true;
            piercedLowIdx = i;
            break;
           }
        }

      if(anyPiercedLow && state.marketData.m5Rates[last].close > swingLow)
        {
         m_bullishSweep = true;
         double volSpike    = ((double)state.marketData.m5Rates[piercedLowIdx].tick_volume > avgVol * 1.5) ? 1.0 : 0.0;
         double reversalBar = (state.marketData.m5Rates[last].close > state.marketData.m5Rates[last].open) ? 1.0 : 0.0;
         double sweepDepth  = (swingLow - state.marketData.m5Rates[piercedLowIdx].low) / (atrPrice + 1e-9);

         double baseScore = Clamp01(sweepDepth * 2.0);
         double condMet = 1.0 + volSpike + reversalBar;
         double condMultiplier = Clamp01(0.5 + 0.25 * condMet);
         m_sweepScore = baseScore * condMultiplier;

         ApplySweepContext(state, swingLow, true, atrPrice);
        }

      // ─── Bearish Sweep Detection ────────────────────────────
      bool anyPiercedHigh = false;
      int  piercedHighIdx = -1;
      for(int i = MathMax(0, m5Count-5); i < m5Count; i++)
        {
         if(state.marketData.m5Rates[i].high > swingHigh)
           {
            anyPiercedHigh = true;
            piercedHighIdx = i;
            break;
           }
        }

      if(anyPiercedHigh && state.marketData.m5Rates[last].close < swingHigh)
        {
         m_bearishSweep = true;
         double volSpike    = ((double)state.marketData.m5Rates[piercedHighIdx].tick_volume > avgVol * 1.5) ? 1.0 : 0.0;
         double reversalBar = (state.marketData.m5Rates[last].close < state.marketData.m5Rates[last].open) ? 1.0 : 0.0;
         double sweepDepth  = (state.marketData.m5Rates[piercedHighIdx].high - swingHigh) / (atrPrice + 1e-9);

         double baseScore = Clamp01(sweepDepth * 2.0);
         double condMet = 1.0 + volSpike + reversalBar;
         double condMultiplier = Clamp01(0.5 + 0.25 * condMet);
         m_sweepScore = baseScore * condMultiplier;

         ApplySweepContext(state, swingHigh, false, atrPrice);
        }

      state.liquidity.sweepScore = m_sweepScore;

      if(m_sweepScore > 0.20 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_SWEEP;
         state.pendingEventScores[idx] = m_sweepScore;
         double dir = m_bullishSweep ? 1.0 : -1.0;
         if(MathAbs(m_directionBias) > 0.1)
            dir = m_directionBias;
         state.pendingEventDirs[idx] = dir;
        }

      return true;
     }

private:
   void              ApplySweepContext(SPipelineState &state, double sweptLevel, bool isBullish, double atrPrice)
     {
      double qualityMult = 1.0;
      double direction   = (isBullish) ? 1.0 : -1.0;

      // ── Original VP adjustments (giữ nguyên) ─────────────────
      if(state.vpValid)
        {
         double distToHVN = MathAbs(sweptLevel - state.vpNearestHVN) / atrPrice;
         double distToLVN = MathAbs(sweptLevel - state.vpNearestLVN) / atrPrice;

         if(distToHVN < 0.5) qualityMult *= 1.20;
         if(distToLVN < 0.3) qualityMult *= 0.80;

         if(state.auctAcceptanceScore < 0.25) qualityMult *= 1.15;
         if(state.auctFailureScore > 0.40)    qualityMult *= 1.15;
         if(state.auctState == (int)AUCTION_TRENDING && state.auctBalanceScore < 0.35)
            qualityMult *= 0.75;
        }

      // ── Cross-module checks (preserved) ─────────────────────
      if(state.liquidity.equalHighLowScore > 0.6)
         qualityMult *= 1.15;
      if(state.microstructure.compressionScore > 0.55)
         qualityMult *= 1.10;
      if(isBullish && state.liquidity.premiumDiscountScore < 0.3)
         qualityMult *= 1.10;
      else if(!isBullish && state.liquidity.premiumDiscountScore > 0.7)
         qualityMult *= 1.10;
      if(state.microstructure.liquidityVacuumScore > 0.7)
         qualityMult *= 0.85;

      // ── Auction Regime & Advanced VP ────────────────────────
      int regime = state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;

      if(regime == REGIME_BALANCED_ROTATION)
         qualityMult *= 1.25;
      else if(regime == REGIME_TREND_CONTINUATION || regime == REGIME_TREND_INITIATION)
        {
         qualityMult *= 0.80;
         double trendDir = (state.vpDevPOCSlope > 0.02) ? 1.0 : ((state.vpDevPOCSlope < -0.02) ? -1.0 : 0);
         if((isBullish && trendDir < 0) || (!isBullish && trendDir > 0))
            qualityMult *= 1.2;
        }
      else if(regime == REGIME_TREND_EXHAUSTION)
         qualityMult *= 1.15;
      else if(regime == REGIME_FAILED_AUCTION)
         qualityMult *= 1.30;

      if(state.auctExhaustionScore > 0.65) qualityMult *= 1.1;
      if(state.auctContinuationScore > 0.7) qualityMult *= 0.9;

      if(MathAbs(state.vpDevPOCSlope) > 0.03)
        {
         if(state.vpDevPOCSlope > 0 && isBullish) qualityMult *= 1.1;
         if(state.vpDevPOCSlope < 0 && !isBullish) qualityMult *= 1.1;
         if(isBullish && state.vpDevPOCSlope < 0) direction = 1.0;
         else if(!isBullish && state.vpDevPOCSlope > 0) direction = -1.0;
        }

      // ── Composite profile (giữ nguyên) ──────────────────────
      if(state.vpValid)
        {
         if(MathAbs(sweptLevel - state.vpCompositeVAH) < atrPrice * 0.5 ||
            MathAbs(sweptLevel - state.vpCompositeVAL) < atrPrice * 0.5)
           {
            qualityMult *= 1.20;
           }
        }

      // ── Naked POC magnet (giữ nguyên) ────────────────────────
      if(state.vpNearestNakedPOC > 0)
        {
         double dist = MathAbs(sweptLevel - state.vpNearestNakedPOC) / atrPrice;
         if(dist < 0.8)
           {
            qualityMult *= 1.10;
            if(isBullish && sweptLevel < state.vpNearestNakedPOC) direction = MathMax(direction, 0.7);
            else if(!isBullish && sweptLevel > state.vpNearestNakedPOC) direction = MathMin(direction, -0.7);
           }
        }

      // ── v4.0: Structural context (bao gồm thesis health & composite) ──
      ApplyStructuralContext(state, sweptLevel, isBullish, qualityMult, direction, atrPrice);

      direction = MathMax(-1.0, MathMin(1.0, direction));
      m_sweepScore = Clamp01(m_sweepScore * qualityMult);
      m_directionBias = direction;
     }

public:
   bool              IsBullishSweep(void) const { return m_bullishSweep; }
   bool              IsBearishSweep(void) const { return m_bearishSweep; }
   double            SweepScore(void)     const { return m_sweepScore; }
   double            DirectionBias(void)  const { return m_directionBias; }
  };

#endif

