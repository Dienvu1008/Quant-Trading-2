#ifndef __EA_ROOT_COMPRESSIONENGINE_MQH__
#define __EA_ROOT_COMPRESSIONENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Compression Engine v4.0 — Auction‑Enhanced Squeeze Detector       |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

class CCompressionEngine : public CPipelineModuleBase
{
private:
   double m_compressionScore;
   bool m_isSqueeze;
   double m_directionBias; // -1.0 (bearish) .. +1.0 (bullish)

   CAuctionThesisManager m_thesisManager; // dùng để đánh giá sức khỏe luận điểm

   // ── Helpers (giữ nguyên) ────────────────────────────────────────
   double AverageRange(const MqlRates &rates[], int from, int to)
   {
      double sum = 0;
      for (int i = from; i < to; i++)
         sum += rates[i].high - rates[i].low;
      return sum / (to - from);
   }

   double AverageVolume(const MqlRates &rates[], int from, int to)
   {
      double sum = 0;
      for (int i = from; i < to; i++)
         sum += (double)rates[i].tick_volume;
      return sum / (to - from);
   }

   //+------------------------------------------------------------------+
   //| Structural V3 context (giữ nguyên, chỉ thêm thesis health)       |
   //+------------------------------------------------------------------+
   void ApplyStructuralV3Context(const SPipelineState &state,
                                 double &boost,
                                 double &direction,
                                 double atrPrice)
   {
      if (atrPrice <= 0)
         return;

      double bid = state.marketData.bid;
      // ── Anchored profiles ─────────────────────────────────────
      double nearestAnchoredDist = 1e18;
      double anchoredPrice = 0;
      double checkPrices[] = {state.vpRangePOC, state.vpBreakoutPOC, state.vpPullbackPOC};
      for (int i = 0; i < 3; i++)
      {
         if (checkPrices[i] > 0)
         {
            double d = MathAbs(bid - checkPrices[i]) / atrPrice;
            if (d < nearestAnchoredDist)
            {
               nearestAnchoredDist = d;
               anchoredPrice = checkPrices[i];
            }
         }
      }
      if (nearestAnchoredDist < 0.4)
      {
         boost *= 1.15;
         if (anchoredPrice > bid)
            direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
         else if (anchoredPrice < bid)
            direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
      }

      // ── Best HVN ──────────────────────────────────────────────
      if (state.vpBestHVN > 0)
      {
         double distHVN = MathAbs(bid - state.vpBestHVN) / atrPrice;
         if (distHVN < 0.3)
         {
            boost *= 1.10;
            if (state.vpBestHVN > bid)
               direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
            else if (state.vpBestHVN < bid)
               direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
         }
      }

      // ── Fake breakout traps ──────────────────────────────────
      if (state.vpUpthrustDetected || state.vpSpringDetected)
      {
         boost *= 1.25;
         if (state.vpUpthrustDetected)
            direction = MathMin(direction, -0.5);
         else if (state.vpSpringDetected)
            direction = MathMax(direction, 0.5);
      }

      // ── Profile Thinness ─────────────────────────────────────
      if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         boost *= 1.10;

      // ── VA Overlap Bias ──────────────────────────────────────
      int vaBias = state.vpVAOverlapBias;
      if (vaBias != 0 && MathAbs(state.vpDevPOCSlope) < 0.02)
      {
         double vaDir = (vaBias == 1) ? 0.7 : -0.7;
         if (direction == 0)
            direction = vaDir;
         else
            direction = (MathAbs(direction) < 0.5) ? vaDir : direction * 0.7 + vaDir * 0.3;
      }

      // ── Migration Confidence ─────────────────────────────────
      if (state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm ─────────────────────────────
      // thesisHealth removed: already accounted for in auction adjustment above
   }

   //+------------------------------------------------------------------+
   //| Auction & Volume Profile adjustment (v4.0 – thêm regime filter) |
   //+------------------------------------------------------------------+
   void ComputeAuctionAdjustment(const SPipelineState &state,
                                 double &auctionBoost,
                                 double &direction,
                                 double atrPrice)
   {
      auctionBoost = 1.0;
      direction = 0.0;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if (regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
          (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
      {
         auctionBoost = 0.0; // triệt tiêu hoàn toàn tín hiệu squeeze
         return;
      }

      // ── 1. Auction Regime ─────────────────────────────────────
      if (regime == REGIME_BALANCED_ROTATION)
         auctionBoost *= 1.25;
      else if (regime == REGIME_TREND_EXHAUSTION ||
               regime == REGIME_FAILED_AUCTION)
         auctionBoost *= 1.15;
      else if (regime == REGIME_TREND_CONTINUATION)
         auctionBoost *= 0.90;

      // ── 2. Acceptance filter ─────────────────────────────────
      if (state.auctAcceptanceScore > 0.70)
         auctionBoost *= 0.85;
      else if (state.auctAcceptanceScore < 0.25)
         auctionBoost *= 1.15;

      // ── 3. Exhaustion / Continuation ─────────────────────────
      if (state.auctExhaustionScore > 0.70)
         auctionBoost *= 0.90;
      if (state.auctContinuationScore > 0.80)
         auctionBoost *= 1.05;

      // ── 4. Developing POC (directional bias) ─────────────────
      if (MathAbs(state.vpDevPOCSlope) > 0.03)
         direction = (state.vpDevPOCSlope > 0) ? 1.0 : -1.0;
      else if (!state.vpInsideVA)
      {
         double bid = state.marketData.bid;
         direction = (bid > state.vpVAH) ? 1.0 : -1.0;
      }
      else if (state.vpInsideVA && state.vpPriceVsVA > 0.70)
         direction = 1.0;
      else if (state.vpInsideVA && state.vpPriceVsVA < 0.30)
         direction = -1.0;

      // ── 5. Composite (institutional) context ─────────────────
      if (state.vpValid && atrPrice > 0)
      {
         double bid = state.marketData.bid;
         double distToTop = (state.vpCompositeVAH - bid) / atrPrice;
         double distToBot = (bid - state.vpCompositeVAL) / atrPrice;
         if (MathMin(distToTop, distToBot) < 0.3)
         {
            auctionBoost *= 1.20; // vẫn giữ như cũ
            // v4.0: thêm xác nhận composite nếu squeeze đúng ngay biên
            if (distToTop < distToBot)
               direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
            else
               direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
         }
      }

      // ── 6. Naked POC (magnet / resistance) ───────────────────
      if (state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.5)
      {
         auctionBoost *= 1.10;
         if (state.marketData.bid < state.vpNearestNakedPOC)
            direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
         else
            direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
      }

      // ── 7. Structural V3 context (đã có thesis bên trong) ────
      ApplyStructuralV3Context(state, auctionBoost, direction, atrPrice);

      direction = MathMax(-1.0, MathMin(1.0, direction));
   }

public:
   void Bootstrap(const string symbol)
   {
      Configure(symbol, "CompressionEngine");
      m_compressionScore = 0;
      m_isSqueeze = false;
      m_directionBias = 0.0;
      m_thesisManager.Reset();
   }

   virtual bool Execute(SPipelineState &state) override
   {
      CPipelineModuleBase::Execute(state);

      int copied = state.marketData.m5Copied;
      if (copied < 20)
         return true;

      // ── 1. Original range/volume/BB scores ────────────────────
      double recentRange = AverageRange(state.marketData.m5Rates, copied - 5, copied);
      double historicalRange = AverageRange(state.marketData.m5Rates, 0, copied - 5);
      double rangeScore = (historicalRange > 0) ? Clamp01(1.0 - recentRange / historicalRange) : 0;

      double recentVol = AverageVolume(state.marketData.m5Rates, copied - 5, copied);
      double historicalVol = AverageVolume(state.marketData.m5Rates, 0, copied - 5);
      double volScore = (historicalVol > 0) ? Clamp01(1.0 - recentVol / historicalVol) : 0;

      double sumClose = 0;
      for (int i = copied - 20; i < copied; i++)
         sumClose += state.marketData.m5Rates[i].close;
      double sma = sumClose / 20.0;
      double sqSum = 0;
      for (int i = copied - 20; i < copied; i++)
         sqSum += MathPow(state.marketData.m5Rates[i].close - sma, 2);
      double stddev = MathSqrt(sqSum / 20.0);
      double bbWidth = (sma > 0) ? (stddev * 2.0) / sma : 0;
      double bbScore = (bbWidth < 0.01) ? 1.0 : (bbWidth < 0.02 ? 0.7 : 0.2);

      double baseCompression = 0.4 * rangeScore + 0.4 * volScore + 0.2 * bbScore;

      // ── 2. Volume Profile boost ──────────────────────────────
      double vpBoost = 1.0;
      if (state.vpValid)
      {
         if (state.vpDistToLVN_ATR < 0.4)
            vpBoost = 1.3;
         if (state.vpInsideVA && (state.vpPriceVsVA > 0.7 || state.vpPriceVsVA < 0.3))
            vpBoost = MathMax(vpBoost, 1.2);
         if (MathAbs(state.vpPriceVsPOC) < 0.1)
            vpBoost = MathMax(vpBoost, 1.15);
      }

      // ── 3. Auction/VP advanced adjustment (v4.0) ─────────────
      double auctionBoost = 1.0;
      double direction = 0.0;

      double atrPrice = state.marketData.atrProxy * state.marketData.pointSize;
      if (atrPrice <= 0)
         atrPrice = 0.00001;

      if (state.auctTradeQuality > 0.0 || state.auctRegime != 0)
         ComputeAuctionAdjustment(state, auctionBoost, direction, atrPrice);

      // ── 4. Final compression score ────────────────────────────
      m_compressionScore = Clamp01(baseCompression * vpBoost * auctionBoost);
      m_directionBias = direction;

      // v4.0: nếu auctionBoost về 0 (regime filter), hủy squeeze
      m_isSqueeze = (m_compressionScore > 0.55 && auctionBoost > 0.0);

      // ── 5. Write event ────────────────────────────────────────
      state.microstructure.compressionScore = m_compressionScore;

      if (m_isSqueeze && state.pendingEventCount < 4)
      {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx] = (int)EVENT_COMPRESSION;
         state.pendingEventScores[idx] = m_compressionScore;
         state.pendingEventDirs[idx] = m_directionBias;
      }

      return true;
   }

   double CompressionScore(void) const { return m_compressionScore; }
   bool IsSqueeze(void) const { return m_isSqueeze; }
   double GetDirectionBias(void) const { return m_directionBias; }
};

#endif
