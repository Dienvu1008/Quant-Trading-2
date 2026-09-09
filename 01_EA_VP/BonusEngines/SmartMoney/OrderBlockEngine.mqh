#ifndef __EA_ROOT_ORDERBLOCKENGINE_MQH__
#define __EA_ROOT_ORDERBLOCKENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Order Block Engine v4.0 — Auction‑Enhanced OB Analysis            |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

struct SOrderBlock
  {
   double   highPrice;
   double   lowPrice;
   datetime detectedAt;
   bool     isBullish;
   bool     isFresh;
   int      barsSinceFormed;
   double   qualityScore;
   double   impulseRatio;
   double   volumeRatio;
  };

class COrderBlockEngine : public CPipelineModuleBase
  {
private:
   SOrderBlock    m_blocks[];
   int            m_blockCount;
   datetime       m_lastBarTime;
   int            m_maxAge;

   double         m_overallScore;
   double         m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void           ApplyStructuralContext(const SOrderBlock &block,
                                         const SPipelineState &state,
                                         double &mult,
                                         double &direction,
                                         double atrPrice,
                                         double thesisHealth)
     {
      double mid = (block.highPrice + block.lowPrice) / 2.0;
      // Anchored profiles
      if(state.vpRangePOC > 0 && MathAbs(mid - state.vpRangePOC) < atrPrice * 0.5)
         mult += 0.10;
      if(state.vpBreakoutPOC > 0 && MathAbs(mid - state.vpBreakoutPOC) < atrPrice * 0.5)
         mult += 0.12;
      if(state.vpPullbackPOC > 0 && MathAbs(mid - state.vpPullbackPOC) < atrPrice * 0.5)
         mult += 0.08;
      // Best HVN
      if(state.vpBestHVN > 0 && MathAbs(mid - state.vpBestHVN) < atrPrice * 0.3)
         mult += 0.10;
      // Fake breakout
      if(state.vpUpthrustDetected) direction = MathMin(direction, -0.6);
      if(state.vpSpringDetected)   direction = MathMax(direction, 0.6);
      // Thin profile
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         mult += 0.05;
      // VA Overlap
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.5);
      if(vaBias == -1) direction = MathMin(direction, -0.5);
      // Migration confidence
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm ───────────────────────────
      // thesisHealth removed: already accounted for in auction adjustment above

      // ── v4.0: Xác nhận composite đa khung thời gian ────────
      double bid = state.marketData.bid;
      if(state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
        {
         if(direction > 0 && bid > state.vpCompositeVAH)
            mult += 0.08;
         else if(direction < 0 && bid < state.vpCompositeVAL)
            mult += 0.08;
         else if(direction > 0 && bid < state.vpCompositeVAL)
            mult -= 0.10;
         else if(direction < 0 && bid > state.vpCompositeVAH)
            mult -= 0.10;
        }
     }

   // ── Core helpers (giữ nguyên) ────────────────────────────────
   void           AddBlock(const SPipelineState &state, int idx, bool bullish, double avgVol)
     {
      const MqlRates obBar = state.marketData.h1Rates[idx];
      const MqlRates impBar = state.marketData.h1Rates[idx+1];
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      double impVol = (double)impBar.tick_volume;
      double volRatio = (avgVol > 0) ? impVol / avgVol : 1.0;
      double obRange = bullish ? (obBar.open - obBar.close) : (obBar.close - obBar.open);
      double impulse = bullish ? (impBar.close - impBar.open) : (impBar.open - impBar.close);
      double impRatio = (obRange > 1e-9) ? impulse / obRange : 1.0;

      int sz = ArraySize(m_blocks);
      if(sz <= m_blockCount)
         ArrayResize(m_blocks, sz + 8);

      m_blocks[m_blockCount].highPrice   = bullish ? obBar.open : obBar.close;
      m_blocks[m_blockCount].lowPrice    = bullish ? obBar.close : obBar.open;
      m_blocks[m_blockCount].detectedAt  = obBar.time;
      m_blocks[m_blockCount].isBullish   = bullish;
      m_blocks[m_blockCount].isFresh     = true;
      m_blocks[m_blockCount].barsSinceFormed = 0;
      m_blocks[m_blockCount].impulseRatio = impRatio;
      m_blocks[m_blockCount].volumeRatio  = volRatio;
      m_blockCount++;
     }

   void           UpdateFreshStatus(double bid)
     {
      for(int i = 0; i < m_blockCount; i++)
        {
         if(m_blocks[i].isBullish)
            m_blocks[i].isFresh = (bid > m_blocks[i].highPrice);
         else
            m_blocks[i].isFresh = (bid < m_blocks[i].lowPrice);
        }
     }

   void           Compact(void)
     {
      int write = 0;
      for(int i = 0; i < m_blockCount; i++)
        {
         if(m_blocks[i].isFresh && m_blocks[i].barsSinceFormed <= m_maxAge)
           {
            if(write != i)
               m_blocks[write] = m_blocks[i];
            write++;
           }
        }
      m_blockCount = write;
     }

   // ── Intrinsic quality (giữ nguyên) ──────────────────────────
   double         ComputeBlockQuality(const SOrderBlock &block, double bid, double atrPrice)
     {
      double impScore = Clamp01(block.impulseRatio / 3.0);
      double volScore = Clamp01(block.volumeRatio / 3.0);

      double dist = 0;
      if(block.isBullish)
         dist = block.lowPrice - bid;
      else
         dist = bid - block.highPrice;

      double proxScore = (atrPrice > 0) ? 1.0 - Clamp01(MathAbs(dist) / (atrPrice * 2.0)) : 0.5;
      proxScore = MathMax(0.2, proxScore);

      double recency = 1.0 - (double)block.barsSinceFormed / (double)m_maxAge;
      double recencyScore = Clamp01(recency);

      return Clamp01(impScore * 0.35 + volScore * 0.30 + proxScore * 0.25 + recencyScore * 0.10);
     }

   // ── Enhanced multiplier (v4.0: thêm thesisHealth) ───────────
   double         GetEnhancedMultiplier(const SOrderBlock &block, const SPipelineState &state,
                                        double atrPrice, double thesisHealth)
     {
      double mult = 1.0;
      if(!state.vpValid) return mult;

      double mid = (block.highPrice + block.lowPrice) / 2.0;

      // Original VP factors
      if(!state.vpInsideVA)
         mult += 0.10;
      else
        {
         if(MathAbs(state.vpPriceVsVA) > 0.8)    mult += 0.05;
         else if(MathAbs(state.vpPriceVsPOC) < 0.15) mult -= 0.10;
        }

      if(state.vpDistToHVN_ATR < 0.5) mult += 0.08;
      if(state.vpDistToLVN_ATR < 0.4 && state.vpDistToLVN_ATR > 0) mult -= 0.10;

      if(state.auctValueAreaState == (int)VA_EXPANDING)     mult += 0.07;
      else if(state.auctValueAreaState == (int)VA_CONTRACTING) mult -= 0.07;

      if(state.auctAcceptanceScore > 0.65) mult += 0.06;
      if(state.auctFailureScore > 0.4)    mult -= 0.06;

      if(state.vpMigrationScore > 0.3)
        {
         double vpDir = state.vpMigrationDirRaw;
         if((block.isBullish && vpDir > 0) || (!block.isBullish && vpDir < 0))
            mult += 0.10;
         else if((block.isBullish && vpDir < 0) || (!block.isBullish && vpDir > 0))
            mult -= 0.10;
        }

      // Auction Regime
      int regime = state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
        {
         mult += 0.08;
         double slope = state.vpDevPOCSlope;
         if((block.isBullish && slope > 0.02) || (!block.isBullish && slope < -0.02))
            mult += 0.07;
         else if(MathAbs(slope) > 0.02)
            mult -= 0.05;
        }
      else if(regime == (int)REGIME_BALANCED_ROTATION)
         mult += 0.10;
      else if(regime == (int)REGIME_TREND_EXHAUSTION)
         mult -= 0.05;
      else if(regime == (int)REGIME_FAILED_AUCTION)
         mult -= 0.05;

      // Composite profile (giữ nguyên)
      if(state.vpValid)
        {
         double bid = state.marketData.bid;
         if(MathAbs(mid - state.vpCompositeVAH) < atrPrice * 0.3 ||
            MathAbs(mid - state.vpCompositeVAL) < atrPrice * 0.3)
            mult += 0.10;
        }

      // Naked POC (giữ nguyên)
      if(state.vpNearestNakedPOC > 0)
        {
         double distNPOC = MathAbs(mid - state.vpNearestNakedPOC) / atrPrice;
         if(distNPOC < 0.5) mult += 0.08;
        }

      // ── v4.0: Structural context (bao gồm thesis health & composite) ──
      double direction = block.isBullish ? 1.0 : -1.0;
      ApplyStructuralContext(block, state, mult, direction, atrPrice, thesisHealth);

      return MathMax(0.70, MathMin(1.35, mult));
     }

public:
   void           Bootstrap(const string symbol)
     {
      Configure(symbol, "OrderBlockEngine");
      m_blockCount = 0;
      ArrayResize(m_blocks, 0);
      m_lastBarTime = 0;
      m_maxAge = 72;
      m_overallScore = 0;
      m_directionBias = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool   Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      int h1Count = state.marketData.h1Copied;
      if(h1Count < 5) return true;

      double bid = state.marketData.bid;
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         m_overallScore = 0.0;
         m_directionBias = 0.0;
         state.smartMoney.orderBlockScore = 0.0;
         return true;
        }

      datetime currentBarTime = state.marketData.h1Rates[h1Count-1].time;
      bool isNewBar = (currentBarTime != m_lastBarTime);

      // ── 1. New bar: age, scan, compact ──
      if(isNewBar)
        {
         m_lastBarTime = currentBarTime;

         for(int i = 0; i < m_blockCount; i++)
            m_blocks[i].barsSinceFormed++;

         double avgVol = 0;
         for(int i = 0; i < h1Count; i++)
            avgVol += (double)state.marketData.h1Rates[i].tick_volume;
         avgVol /= h1Count;

         if(h1Count >= 2)
           {
            int i = h1Count - 2;
            double impVol = (double)state.marketData.h1Rates[i+1].tick_volume;
            if(impVol > avgVol * 1.5)
              {
               if(state.marketData.h1Rates[i].close < state.marketData.h1Rates[i].open &&
                  state.marketData.h1Rates[i+1].close > state.marketData.h1Rates[i+1].open)
                 {
                  double impulse = state.marketData.h1Rates[i+1].close - state.marketData.h1Rates[i+1].open;
                  double obRange = state.marketData.h1Rates[i].open - state.marketData.h1Rates[i].close;
                  if(impulse > obRange * 1.3)
                     AddBlock(state, i, true, avgVol);
                 }
               if(state.marketData.h1Rates[i].close > state.marketData.h1Rates[i].open &&
                  state.marketData.h1Rates[i+1].close < state.marketData.h1Rates[i+1].open)
                 {
                  double impulse = state.marketData.h1Rates[i+1].open - state.marketData.h1Rates[i+1].close;
                  double obRange = state.marketData.h1Rates[i].close - state.marketData.h1Rates[i].open;
                  if(impulse > obRange * 1.3)
                     AddBlock(state, i, false, avgVol);
                 }
              }
           }
         Compact();
        }

      // ── 2. Update fresh status ──
      UpdateFreshStatus(bid);

      // ── v4.0: Lấy sức khỏe luận điểm một lần ────────────────
      // thesisHealth removed: already accounted for in auction adjustment above
      double thesisHealth = 0.5; // kept for function signature compatibility

      // ── 3. Compute overall score & directional bias ──
      double totalBullQuality = 0.0, totalBearQuality = 0.0;
      int freshCount = 0;
      double sumQuality = 0.0;

      for(int i = 0; i < m_blockCount; i++)
        {
         if(!m_blocks[i].isFresh) continue;
         double intrinsic = ComputeBlockQuality(m_blocks[i], bid, atrPrice);
         double vpMult = GetEnhancedMultiplier(m_blocks[i], state, atrPrice, thesisHealth);
         double weighted = intrinsic * vpMult;
         m_blocks[i].qualityScore = weighted;
         sumQuality += weighted;
         freshCount++;
         if(m_blocks[i].isBullish)
            totalBullQuality += weighted;
         else
            totalBearQuality += weighted;
        }

      if(freshCount > 0)
        {
         m_overallScore = Clamp01(sumQuality / freshCount);
         if(totalBullQuality > totalBearQuality * 1.5)
            m_directionBias = 1.0;
         else if(totalBearQuality > totalBullQuality * 1.5)
            m_directionBias = -1.0;
         else
            m_directionBias = (totalBullQuality - totalBearQuality) / (totalBullQuality + totalBearQuality + 0.001);
        }
      else
        {
         m_overallScore = 0.0;
         m_directionBias = 0.0;
        }

      state.smartMoney.orderBlockScore = m_overallScore;

      if(m_overallScore > 0.25 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_ORDERBLOCK;
         state.pendingEventScores[idx] = m_overallScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   int            BlockCount(void) const { return m_blockCount; }
   double         OverallScore(void) const { return m_overallScore; }
   double         DirectionBias(void) const { return m_directionBias; }

   bool           NearestBullishOB(double currentPrice, double &obHigh, double &obLow)
     {
      double minDist = 999999;
      bool found = false;
      for(int i = 0; i < m_blockCount; i++)
        {
         if(!m_blocks[i].isBullish || !m_blocks[i].isFresh) continue;
         double dist = currentPrice - m_blocks[i].highPrice;
         if(dist > 0 && dist < minDist)
           { minDist = dist; obHigh = m_blocks[i].highPrice; obLow = m_blocks[i].lowPrice; found = true; }
        }
      return found;
     }

   bool           NearestBearishOB(double currentPrice, double &obHigh, double &obLow)
     {
      double minDist = 999999;
      bool found = false;
      for(int i = 0; i < m_blockCount; i++)
        {
         if(m_blocks[i].isBullish || !m_blocks[i].isFresh) continue;
         double dist = m_blocks[i].lowPrice - currentPrice;
         if(dist > 0 && dist < minDist)
           { minDist = dist; obHigh = m_blocks[i].highPrice; obLow = m_blocks[i].lowPrice; found = true; }
        }
      return found;
     }
  };

#endif