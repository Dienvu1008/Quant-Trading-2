#ifndef __EA_ROOT_LIQUIDITYENGINE_MQH__
#define __EA_ROOT_LIQUIDITYENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Liquidity Engine v4.0 — Auction‑Enhanced Liquidity Density        |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

struct SLiquidityZone
  {
   double priceHigh;
   double priceLow;
   double volumeWeight;
   bool   isTested;
  };

class CLiquidityEngine : public CPipelineModuleBase
  {
private:
   SLiquidityZone    m_zones[];
   double            m_liquidityDensity;
   double            m_liquidityDirection;

   CAuctionThesisManager m_thesisManager;   // đánh giá sức khỏe luận điểm

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double &rawDensity,
                                            double &direction,
                                            double atrPrice)
     {
      double bid = state.marketData.bid;

      // Anchored profiles: near an anchored POC → liquidity cluster
      double anchorPrices[] = { state.vpRangePOC, state.vpBreakoutPOC, state.vpPullbackPOC };
      for(int i = 0; i < 3; i++)
        {
         if(anchorPrices[i] > 0 && MathAbs(bid - anchorPrices[i]) < atrPrice * 0.5)
           {
            rawDensity = MathMin(1.0, rawDensity + 0.12);
            if(anchorPrices[i] > bid) direction = (direction == 0) ? 0.6 : (direction > 0 ? direction : 0.3);
            else direction = (direction == 0) ? -0.6 : (direction < 0 ? direction : -0.3);
            break;
           }
        }

      // Best HVN: strong magnet → increases density if near
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.4)
        {
         rawDensity = MathMin(1.0, rawDensity + 0.10);
         if(state.vpBestHVN > bid) direction = (direction == 0) ? 0.7 : (direction > 0 ? direction : 0.4);
         else direction = (direction == 0) ? -0.7 : (direction < 0 ? direction : -0.4);
        }

      // Fake breakout traps: liquidity distortion → density may be false
      if(state.vpUpthrustDetected || state.vpSpringDetected)
        {
         rawDensity = MathMax(0.0, rawDensity - 0.15);
         if(state.vpUpthrustDetected) direction = MathMin(direction, -0.6);
         if(state.vpSpringDetected)   direction = MathMax(direction, 0.6);
        }

      // Thin profile → liquidity is directional, not static
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         rawDensity = MathMin(1.0, rawDensity * 1.08);

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
         rawDensity *= (0.8 + health * 0.4);
         if(health < 0.3 && direction != 0) direction *= 0.5;
        }

      // ── v4.0: Xác nhận composite đa khung thời gian ──────────
      if(state.vpValid && direction != 0)
        {
         if((direction > 0 && bid > state.vpCompositeVAH) ||
            (direction < 0 && bid < state.vpCompositeVAL))
            rawDensity = MathMin(1.0, rawDensity * 1.08);
         else if((direction > 0 && bid < state.vpCompositeVAL) ||
                 (direction < 0 && bid > state.vpCompositeVAH))
            rawDensity = MathMax(0.0, rawDensity * 0.90);
        }
     }

public:
   void              Bootstrap(const string symbol)
     {
      Configure(symbol, "LiquidityEngine");
      m_liquidityDensity   = 0;
      m_liquidityDirection = 0;
      ArrayResize(m_zones, 0);
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      int h1Count = state.marketData.h1Copied;
      if(h1Count < 20) return true;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         m_liquidityDensity   = 0.0;
         m_liquidityDirection = 0.0;
         state.liquidity.liquidityDensity = 0.0;
         return true;
        }

      int useBars  = MathMin(h1Count, 50);
      int startIdx = h1Count - useBars;

      // ── 1. Build liquidity zones (unchanged) ─────────────────
      ArrayResize(m_zones, 0);
      double totalVol = 0;
      for(int i = startIdx; i < h1Count; i++)
         totalVol += (double)state.marketData.h1Rates[i].tick_volume;

      double minPrice = state.marketData.h1Rates[startIdx].low;
      double maxPrice = state.marketData.h1Rates[startIdx].high;
      for(int i = startIdx+1; i < h1Count; i++)
        {
         if(state.marketData.h1Rates[i].low  < minPrice) minPrice = state.marketData.h1Rates[i].low;
         if(state.marketData.h1Rates[i].high > maxPrice) maxPrice = state.marketData.h1Rates[i].high;
        }

      double zoneSize = (maxPrice - minPrice) / 10.0;
      if(zoneSize <= 0) return true;

      ArrayResize(m_zones, 10);
      for(int z = 0; z < 10; z++)
        {
         m_zones[z].priceLow    = minPrice + z * zoneSize;
         m_zones[z].priceHigh   = m_zones[z].priceLow + zoneSize;
         m_zones[z].volumeWeight = 0;
         m_zones[z].isTested    = false;

         for(int i = startIdx; i < h1Count; i++)
           {
            double mid = (state.marketData.h1Rates[i].high + state.marketData.h1Rates[i].low) / 2.0;
            if(mid >= m_zones[z].priceLow && mid < m_zones[z].priceHigh)
               m_zones[z].volumeWeight += (double)state.marketData.h1Rates[i].tick_volume;
           }
         if(totalVol > 0)
            m_zones[z].volumeWeight /= totalVol;
        }

      double currentBid = state.marketData.bid;
      for(int z = 0; z < 10; z++)
         if(currentBid >= m_zones[z].priceLow && currentBid < m_zones[z].priceHigh)
            m_zones[z].isTested = true;

      // ── 2. Density & direction calculation ──────────────────
      double rawDensity = 0.5;
      double direction  = 0.0;
      double atrPrice   = state.marketData.atrProxy * state.marketData.pointSize;
      if(atrPrice <= 0) atrPrice = state.marketData.pointSize * 10;

      if(state.vpValid)
        {
         // Core components
         double hvnProx = 0;
         if(state.vpDistToHVN_ATR > 0)
            hvnProx = Clamp01(1.0 - state.vpDistToHVN_ATR / 1.5);
         else if(state.vpNearestHVN > 0)
            hvnProx = 1.0;

         double vaWidth = state.vpVAH - state.vpVAL;
         double profileRange = maxPrice - minPrice;
         double vaCompact = (profileRange > 0)
            ? Clamp01(1.0 - (vaWidth / profileRange) / 0.6)
            : 0.5;

         double acceptFactor = state.auctAcceptanceScore;
         double balanceFactor = state.auctBalanceScore;

         rawDensity = hvnProx * 0.30
                    + vaCompact * 0.25
                    + acceptFactor * 0.25
                    + balanceFactor * 0.20;

         // Regime modifiers
         if(regime == (int)REGIME_BALANCED_ROTATION)
            rawDensity = MathMin(1.0, rawDensity * 1.2);
         else if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
            rawDensity = rawDensity * 0.95;
         else if(regime == (int)REGIME_TREND_EXHAUSTION)
            rawDensity = rawDensity * (1.0 - 0.3 * regimeConf);
         else if(regime == (int)REGIME_FAILED_AUCTION)
            rawDensity = rawDensity * 0.85;

         if(state.auctExhaustionScore > 0.65) rawDensity -= 0.1;
         if(state.auctContinuationScore > 0.7) rawDensity = MathMin(1.0, rawDensity + 0.05);

         double pocStability = 1.0 - Clamp01(MathAbs(state.vpDevPOCSlope) / 0.05);
         rawDensity *= 0.8 + 0.2 * pocStability;

         // Composite proximity (fixed units)
         if(state.vpValid)
           {
            double bid = state.marketData.bid;
            if(bid >= state.vpCompositeVAL && bid <= state.vpCompositeVAH)
               rawDensity = MathMin(1.0, rawDensity + 0.10);
            double distToCompPOC = MathAbs(bid - state.vpCompositePOC) / atrPrice;
            if(distToCompPOC < 0.5)
               rawDensity = MathMin(1.0, rawDensity + 0.05);
           }

         if(state.vpInsideVA)
            rawDensity = MathMin(1.0, rawDensity + 0.10);
         if(state.vpDistToLVN_ATR < 0.3 && state.vpDistToLVN_ATR > 0)
            rawDensity = MathMax(0.0, rawDensity - 0.15);

         // Directional bias (original logic preserved)
         double slope = state.vpDevPOCSlope;
         if(MathAbs(slope) > 0.02)
            direction = (slope > 0) ? 0.7 : -0.7;
         else if(state.vpInsideVA)
            direction = (state.vpPriceVsVA - 0.5) * 2.0;
         else
            direction = (state.marketData.bid > state.vpVAH) ? 1.0 : -1.0;

         // Refine with composite POC
         if(state.vpValid)
           {
            if(state.marketData.bid > state.vpCompositePOC)
               direction = MathMax(direction, 0.3);
            else
               direction = MathMin(direction, -0.3);
           }

         // ── v4.0: Structural context (có thesis & composite) ─
         ApplyStructuralContext(state, rawDensity, direction, atrPrice);
        }
      else
        {
         double maxZoneVol = 0;
         for(int z = 0; z < 10; z++)
            if(m_zones[z].volumeWeight > maxZoneVol) maxZoneVol = m_zones[z].volumeWeight;
         rawDensity = Clamp01(maxZoneVol * 5.0);
        }

      m_liquidityDensity  = Clamp01(rawDensity);
      m_liquidityDirection = MathMax(-1.0, MathMin(1.0, direction));

      // ── Write to state ──────────────────────────────────────
      state.liquidity.liquidityDensity = m_liquidityDensity;

      if(m_liquidityDensity > 0.70 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_LIQUIDITY_DENSITY;
         state.pendingEventScores[idx] = m_liquidityDensity;
         state.pendingEventDirs[idx]   = m_liquidityDirection;
        }

      return true;
     }

   int               ZoneCount(void)        const { return ArraySize(m_zones); }
   double            LiquidityDensity(void) const { return m_liquidityDensity; }
   double            LiquidityDirection(void) const { return m_liquidityDirection; }
  };

#endif