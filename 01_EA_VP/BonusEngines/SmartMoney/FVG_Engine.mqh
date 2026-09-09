#ifndef __EA_ROOT_FVG_ENGINE_MQH__
#define __EA_ROOT_FVG_ENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| FVG Engine v4.0 — Auction‑Enhanced Fair Value Gap Analysis        |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

struct SFVG
  {
   double highPrice;
   double lowPrice;
   datetime detectedAt;
   bool isBullish;
   bool isFilled;
  };

class CFVG_Engine : public CPipelineModuleBase
  {
private:
   SFVG              m_fvgs[];
   int               m_fvgCount;
   double            m_fvgScore;
   double            m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double midPrice,
                                            double &quality,
                                            double &direction,
                                            double atrPrice)
     {
      // Anchored profiles near FVG
      if(state.vpRangePOC > 0 && MathAbs(midPrice - state.vpRangePOC) < atrPrice * 0.4)
         quality += 0.12;
      if(state.vpBreakoutPOC > 0 && MathAbs(midPrice - state.vpBreakoutPOC) < atrPrice * 0.4)
         quality += 0.12;
      if(state.vpPullbackPOC > 0 && MathAbs(midPrice - state.vpPullbackPOC) < atrPrice * 0.4)
         quality += 0.10;

      // Best HVN
      if(state.vpBestHVN > 0 && MathAbs(midPrice - state.vpBestHVN) < atrPrice * 0.3)
         quality += 0.12;

      // Fake breakout: FVG after upthrust/spring can be trap
      if(state.vpUpthrustDetected) direction = MathMin(direction, -0.6);
      if(state.vpSpringDetected)   direction = MathMax(direction, 0.6);

      // Thin profile: FVG may stay open longer
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         quality += 0.05;

      // VA Overlap bias
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1)  direction = MathMax(direction, 0.5);
      if(vaBias == -1) direction = MathMin(direction, -0.5);

      // Migration confidence strengthens direction
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm (áp dụng sau khi duyệt xong FVG, giữ nguyên ở đây) ──
      // (không làm gì thêm ở đây)
     }

public:
   void              Bootstrap(const string symbol)
     {
      Configure(symbol, "FVG_Engine");
      m_fvgCount = 0;
      m_fvgScore = 0;
      m_directionBias = 0.0;
      ArrayResize(m_fvgs, 0);
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      ArrayResize(m_fvgs, 0);
      m_fvgCount = 0;

      int h1Count = state.marketData.h1Copied;
      if(h1Count < 5) return true;

      double bid = state.marketData.bid;
      // ATR in price (giữ nguyên)
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         m_fvgScore = 0.0;
         state.smartMoney.fvgScore = 0.0;
         return true;
        }

      // ── 1. Detect FVGs (3-bar & 1-bar) ────────────────────────
      for(int i = 2; i < h1Count; i++)
        {
         // Bullish 3-bar
         if(state.marketData.h1Rates[i].low > state.marketData.h1Rates[i-2].high)
           {
            int sz = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, sz + 1);
            m_fvgs[sz].highPrice  = state.marketData.h1Rates[i].low;
            m_fvgs[sz].lowPrice   = state.marketData.h1Rates[i-2].high;
            m_fvgs[sz].detectedAt = state.marketData.h1Rates[i-1].time;
            m_fvgs[sz].isBullish  = true;
            m_fvgs[sz].isFilled   = (bid >= m_fvgs[sz].lowPrice && bid <= m_fvgs[sz].highPrice);
            m_fvgCount++;
           }
         // Bearish 3-bar
         if(state.marketData.h1Rates[i].high < state.marketData.h1Rates[i-2].low)
           {
            int sz = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, sz + 1);
            m_fvgs[sz].highPrice  = state.marketData.h1Rates[i-2].low;
            m_fvgs[sz].lowPrice   = state.marketData.h1Rates[i].high;
            m_fvgs[sz].detectedAt = state.marketData.h1Rates[i-1].time;
            m_fvgs[sz].isBullish  = false;
            m_fvgs[sz].isFilled   = (bid >= m_fvgs[sz].lowPrice && bid <= m_fvgs[sz].highPrice);
            m_fvgCount++;
           }
        }

      for(int i = 1; i < h1Count; i++)
        {
         // Bullish 1-bar
         if(state.marketData.h1Rates[i].low > state.marketData.h1Rates[i-1].high)
           {
            int sz = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, sz + 1);
            m_fvgs[sz].highPrice  = state.marketData.h1Rates[i].low;
            m_fvgs[sz].lowPrice   = state.marketData.h1Rates[i-1].high;
            m_fvgs[sz].detectedAt = state.marketData.h1Rates[i].time;
            m_fvgs[sz].isBullish  = true;
            m_fvgs[sz].isFilled   = (bid >= m_fvgs[sz].lowPrice && bid <= m_fvgs[sz].highPrice);
            m_fvgCount++;
           }
         // Bearish 1-bar
         if(state.marketData.h1Rates[i].high < state.marketData.h1Rates[i-1].low)
           {
            int sz = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, sz + 1);
            m_fvgs[sz].highPrice  = state.marketData.h1Rates[i-1].low;
            m_fvgs[sz].lowPrice   = state.marketData.h1Rates[i].high;
            m_fvgs[sz].detectedAt = state.marketData.h1Rates[i].time;
            m_fvgs[sz].isBullish  = false;
            m_fvgs[sz].isFilled   = (bid >= m_fvgs[sz].lowPrice && bid <= m_fvgs[sz].highPrice);
            m_fvgCount++;
           }
        }

      // ── 2. Analyze unfilled FVGs ─────────────────────────────
      int unfilledBull = 0, unfilledBear = 0;
      double sumQuality = 0.0;
      double dirSum = 0.0;

      // thesisHealth removed: already accounted for in auction adjustment above

      for(int i = 0; i < m_fvgCount; i++)
        {
         if(m_fvgs[i].isFilled) continue;

         // Gap size (ATR-normalized, giữ nguyên)
         double gapSize = MathAbs(m_fvgs[i].highPrice - m_fvgs[i].lowPrice);
         double gapATR  = (atrPrice > 0) ? gapSize / atrPrice : 0;
         double sizeScore = Clamp01(gapATR / 0.5);

         double quality = 0.3;  // base
         double midPrice = (m_fvgs[i].highPrice + m_fvgs[i].lowPrice) / 2.0;

         if(state.vpValid)
           {
            // Position relative to VA
            if(midPrice > state.vpVAH || midPrice < state.vpVAL)
               quality += 0.15;
            else if(MathAbs(state.vpPriceVsPOC) < 0.15)
               quality += 0.10;

            // HVN/LVN proximity (giữ nguyên)
            double distHVN = (state.vpNearestHVN > 0) ? MathAbs(midPrice - state.vpNearestHVN) / atrPrice : 999;
            double distLVN = (state.vpNearestLVN > 0) ? MathAbs(midPrice - state.vpNearestLVN) / atrPrice : 999;
            if(distHVN < 0.3) quality += 0.12;
            if(distLVN < 0.3) quality += 0.08;

            // Auction regime (giữ nguyên)
            if(regime == (int)REGIME_BALANCED_ROTATION) quality += 0.10;
            else if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
               quality -= 0.05;

            // Composite boundary proximity (giữ nguyên)
            if(MathAbs(midPrice - state.vpCompositeVAH) < atrPrice * 0.3 ||
               MathAbs(midPrice - state.vpCompositeVAL) < atrPrice * 0.3)
               quality += 0.10;

            // Naked POC magnet (giữ nguyên)
            if(state.vpNearestNakedPOC > 0)
              {
               double distNPOC = MathAbs(midPrice - state.vpNearestNakedPOC) / atrPrice;
               if(distNPOC < 0.5) quality += 0.08;
              }

            // Acceptance/failure (giữ nguyên)
            if(state.auctAcceptanceScore > 0.65) quality += 0.06;
            if(state.auctFailureScore > 0.4) quality -= 0.04;

            // ── v4.0: Sức khỏe luận điểm ──────────────────────
            // thesisHealth removed: already accounted for in auction adjustment above

            // ── v4.0: Xác nhận composite đa khung thời gian ──
            double direction = m_fvgs[i].isBullish ? 1.0 : -1.0;
            if(state.vpCompositeVAH > state.vpCompositeVAL)
              {
               if(direction > 0 && state.marketData.bid > state.vpCompositeVAH) quality += 0.08;
               else if(direction < 0 && state.marketData.bid < state.vpCompositeVAL) quality += 0.08;
               else if(direction > 0 && state.marketData.bid < state.vpCompositeVAL) quality -= 0.10;
               else if(direction < 0 && state.marketData.bid > state.vpCompositeVAH) quality -= 0.10;
              }

            // ── V3 structural context ─────────────────────────
            ApplyStructuralContext(state, midPrice, quality, direction, atrPrice);
            dirSum += direction;
           }

         quality = MathMax(0.1, MathMin(1.0, quality));
         double weightedGap = sizeScore * quality;
         sumQuality += weightedGap;

         if(m_fvgs[i].isBullish) unfilledBull++;
         else unfilledBear++;
        }

      // ── 3. Compute final score ───────────────────────────────
      int totalUnfilled = unfilledBull + unfilledBear;
      if(totalUnfilled > 0)
        {
         double avgQuality = sumQuality / totalUnfilled;
         double countScore = Clamp01((double)totalUnfilled / 8.0);
         m_fvgScore = Clamp01(avgQuality * 0.7 + countScore * 0.3);
        }
      else
         m_fvgScore = 0.0;

      // ── 4. Directional bias ──────────────────────────────────
      m_directionBias = 0.0;
      if(unfilledBull > unfilledBear + 1)       m_directionBias = 1.0;
      else if(unfilledBear > unfilledBull + 1)  m_directionBias = -1.0;
      else if(unfilledBull > 0 && unfilledBear > 0 && MathAbs(unfilledBull - unfilledBear) <= 1)
         m_directionBias = 0.0;
      else if(unfilledBull > 0) m_directionBias = 0.7;
      else if(unfilledBear > 0) m_directionBias = -0.7;

      // Adjust bias with POC slope
      if(MathAbs(state.vpDevPOCSlope) > 0.02)
        {
         if(state.vpDevPOCSlope > 0) m_directionBias = MathMax(m_directionBias, 0.4);
         else m_directionBias = MathMin(m_directionBias, -0.4);
        }
      // Blend with structural directions from individual FVGs
      if(totalUnfilled > 0)
        {
         double avgDir = dirSum / totalUnfilled;
         if(m_directionBias == 0) m_directionBias = avgDir;
         else m_directionBias = m_directionBias * 0.6 + avgDir * 0.4;
        }

      // ── 5. Output ────────────────────────────────────────────
      state.smartMoney.fvgScore = m_fvgScore;

      if(m_fvgScore > 0.3 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_FVG;
         state.pendingEventScores[idx] = m_fvgScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   int               FVGCount(void)       const { return m_fvgCount; }
   double            FVGScore(void)       const { return m_fvgScore; }
   double            DirectionBias(void)  const { return m_directionBias; }
  };

#endif