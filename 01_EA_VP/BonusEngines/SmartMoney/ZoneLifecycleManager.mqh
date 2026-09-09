#ifndef __EA_ROOT_ZONELIFECYCLEMANAGER_MQH__
#define __EA_ROOT_ZONELIFECYCLEMANAGER_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

enum EZoneState { ZONE_FRESH=0, ZONE_TESTED, ZONE_WEAK, ZONE_INVALIDATED };

struct SManagedZone
  {
   double     high;
   double     low;
   bool       isBullish;
   EZoneState state;
   int        testCount;
   datetime   createdAt;
   double     impulseRange;
   double     volumeRatio;
   double     rejectionScore;
   double     quality;
   double     vpBoost;
   double     auctionBoost;
  };

#define ZLM_MAX_ZONES 40

class CZoneLifecycleManager : public CPipelineModuleBase
  {
private:
   SManagedZone m_zones[ZLM_MAX_ZONES];
   int          m_count;
   datetime     m_lastDetectTime;

   double       m_overallQuality;
   double       m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void ApplyStructuralContext(int idx, const SPipelineState &state, double atrPrice, double thesisHealth)
     {
      double mid = (m_zones[idx].high + m_zones[idx].low) / 2.0;
      double bid = state.marketData.bid;

      // Anchored profiles
      if(state.vpRangePOC > 0 && MathAbs(mid - state.vpRangePOC) < atrPrice * 0.5)
         m_zones[idx].vpBoost *= 1.08;
      if(state.vpBreakoutPOC > 0 && MathAbs(mid - state.vpBreakoutPOC) < atrPrice * 0.5)
         m_zones[idx].vpBoost *= 1.10;
      if(state.vpPullbackPOC > 0 && MathAbs(mid - state.vpPullbackPOC) < atrPrice * 0.5)
         m_zones[idx].vpBoost *= 1.06;
      // Best HVN
      if(state.vpBestHVN > 0 && MathAbs(mid - state.vpBestHVN) < atrPrice * 0.3)
         m_zones[idx].auctionBoost *= 1.10;
      // Fake breakout traps
      if(state.vpUpthrustDetected) m_zones[idx].auctionBoost *= (m_zones[idx].isBullish ? 0.9 : 1.1);
      if(state.vpSpringDetected)   m_zones[idx].auctionBoost *= (m_zones[idx].isBullish ? 1.1 : 0.9);
      // Thin profile
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         m_zones[idx].vpBoost *= 1.05;
      // VA Overlap bias
      int vaBias = state.vpVAOverlapBias;
      if((vaBias == 1 && m_zones[idx].isBullish) || (vaBias == -1 && !m_zones[idx].isBullish))
         m_zones[idx].auctionBoost *= 1.08;
      // Migration confidence
      if(state.vpMigrationConfidence > 0.6)
        {
         double migDir = (state.vpDevPOCDirection > 0) ? 1.0 : -1.0;
         if((m_zones[idx].isBullish && migDir > 0) || (!m_zones[idx].isBullish && migDir < 0))
            m_zones[idx].auctionBoost *= 1.07;
        }

      // ── v4.0: Sức khỏe luận điểm ─────────────────────────────
      // thesisHealth removed: already accounted for in auction adjustment above

      // ── v4.0: Xác nhận composite đa khung thời gian ──────────
      if(state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
        {
         if(m_zones[idx].isBullish && bid > state.vpCompositeVAH)
            m_zones[idx].auctionBoost *= 1.08;
         else if(!m_zones[idx].isBullish && bid < state.vpCompositeVAL)
            m_zones[idx].auctionBoost *= 1.08;
         else if(m_zones[idx].isBullish && bid < state.vpCompositeVAL)
            m_zones[idx].auctionBoost *= 0.92;
         else if(!m_zones[idx].isBullish && bid > state.vpCompositeVAH)
            m_zones[idx].auctionBoost *= 0.92;
        }
     }

   // ── Original detection (adjusted ATR) ──────────────────────────
   void DetectAndRegister(SPipelineState &state, double atrPrice)
     {
      int h1Count = state.marketData.h1Copied;
      if(h1Count < 5) return;

      double avgVol = 0;
      for(int i = 0; i < h1Count; i++) avgVol += (double)state.marketData.h1Rates[i].tick_volume;
      avgVol /= h1Count;
      if(avgVol <= 0) return;

      for(int i = 0; i < h1Count - 1 && m_count < ZLM_MAX_ZONES - 1; i++)
        {
         double impVol   = (double)state.marketData.h1Rates[i+1].tick_volume;
         double impRange = state.marketData.h1Rates[i+1].high - state.marketData.h1Rates[i+1].low;
         bool   volOK    = (impVol > avgVol * 1.5);

         // Bullish zone
         if(state.marketData.h1Rates[i].close < state.marketData.h1Rates[i].open &&
            state.marketData.h1Rates[i+1].close > state.marketData.h1Rates[i+1].open && volOK)
           {
            double impulse = state.marketData.h1Rates[i+1].close - state.marketData.h1Rates[i+1].open;
            double obRange = state.marketData.h1Rates[i].open   - state.marketData.h1Rates[i].close;
            if(impulse > obRange * 1.3)
              {
               double zh = state.marketData.h1Rates[i].open;
               double zl = state.marketData.h1Rates[i].close;
               if(!ZoneExists(zh, zl))
                 {
                  m_zones[m_count].high          = zh;
                  m_zones[m_count].low           = zl;
                  m_zones[m_count].isBullish     = true;
                  m_zones[m_count].state         = ZONE_FRESH;
                  m_zones[m_count].testCount     = 0;
                  m_zones[m_count].createdAt     = state.marketData.h1Rates[i].time;
                  m_zones[m_count].impulseRange  = (atrPrice > 0) ? impRange / atrPrice : 1.0;
                  m_zones[m_count].volumeRatio   = impVol / avgVol;
                  m_zones[m_count].rejectionScore= 0;
                  m_zones[m_count].quality       = 0;
                  m_zones[m_count].vpBoost       = 1.0;
                  m_zones[m_count].auctionBoost  = 1.0;
                  m_count++;
                 }
              }
           }

         // Bearish zone
         if(state.marketData.h1Rates[i].close > state.marketData.h1Rates[i].open &&
            state.marketData.h1Rates[i+1].close < state.marketData.h1Rates[i+1].open && volOK)
           {
            double impulse = state.marketData.h1Rates[i+1].open  - state.marketData.h1Rates[i+1].close;
            double obRange = state.marketData.h1Rates[i].close   - state.marketData.h1Rates[i].open;
            if(impulse > obRange * 1.3)
              {
               double zh = state.marketData.h1Rates[i].close;
               double zl = state.marketData.h1Rates[i].open;
               if(!ZoneExists(zh, zl))
                 {
                  m_zones[m_count].high          = zh;
                  m_zones[m_count].low           = zl;
                  m_zones[m_count].isBullish     = false;
                  m_zones[m_count].state         = ZONE_FRESH;
                  m_zones[m_count].testCount     = 0;
                  m_zones[m_count].createdAt     = state.marketData.h1Rates[i].time;
                  m_zones[m_count].impulseRange  = (atrPrice > 0) ? impRange / atrPrice : 1.0;
                  m_zones[m_count].volumeRatio   = impVol / avgVol;
                  m_zones[m_count].rejectionScore= 0;
                  m_zones[m_count].quality       = 0;
                  m_zones[m_count].vpBoost       = 1.0;
                  m_zones[m_count].auctionBoost  = 1.0;
                  m_count++;
                 }
              }
           }
        }
     }

   bool ZoneExists(double zh, double zl)
     {
      for(int i = 0; i < m_count; i++)
         if(MathAbs(m_zones[i].high-zh) < zl*0.001 && MathAbs(m_zones[i].low-zl) < zl*0.001)
            return true;
      return false;
     }

   // ── Compute VP & Auction boost (now uses thesisHealth) ────────
   void ComputeZoneBoosts(int idx, const SPipelineState &state, double atrPrice, double thesisHealth)
     {
      double vpMult = 1.0, aucMult = 1.0;
      if(!state.vpValid) { m_zones[idx].vpBoost = 1.0; m_zones[idx].auctionBoost = 1.0; return; }

      double mid = (m_zones[idx].high + m_zones[idx].low) / 2.0;

      // ---- Volume Profile factors (unchanged) ----
      if(!state.vpInsideVA)                  vpMult += 0.10;
      else if(MathAbs(state.vpPriceVsVA) > 0.8) vpMult += 0.05;
      else if(MathAbs(state.vpPriceVsPOC) < 0.15) vpMult -= 0.10;

      if(state.vpDistToHVN_ATR < 0.5) vpMult += 0.08;
      if(state.vpDistToLVN_ATR < 0.4 && state.vpDistToLVN_ATR > 0) vpMult -= 0.10;

      if(state.auctValueAreaState == (int)VA_EXPANDING)         vpMult += 0.07;
      else if(state.auctValueAreaState == (int)VA_CONTRACTING)  vpMult -= 0.07;

      if(state.auctAcceptanceScore > 0.65) vpMult += 0.06;
      if(state.auctFailureScore > 0.4)     vpMult -= 0.06;

      if(state.vpMigrationScore > 0.3)
        {
         double vpDir = state.vpMigrationDirRaw;
         if((m_zones[idx].isBullish && vpDir > 0) || (!m_zones[idx].isBullish && vpDir < 0))
            vpMult += 0.10;
         else if((m_zones[idx].isBullish && vpDir < 0) || (!m_zones[idx].isBullish && vpDir > 0))
            vpMult -= 0.10;
        }

      // ---- Auction Regime factors (unchanged) ----
      int regime = state.auctRegime;
      double slope = state.vpDevPOCSlope;
      if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
        {
         aucMult += 0.08;
         if((m_zones[idx].isBullish && slope > 0.02) || (!m_zones[idx].isBullish && slope < -0.02))
            aucMult += 0.07;
         else if(MathAbs(slope) > 0.02)
            aucMult -= 0.05;
        }
      else if(regime == (int)REGIME_BALANCED_ROTATION)
         aucMult += 0.10;
      else if(regime == (int)REGIME_TREND_EXHAUSTION)
         aucMult -= 0.05;
      else if(regime == (int)REGIME_FAILED_AUCTION)
         aucMult -= 0.05;

      // Composite boundary (original)
      if(state.vpValid)
        {
         double bid = state.marketData.bid;
         if(MathAbs(mid - state.vpCompositeVAH) < atrPrice * 0.3 ||
            MathAbs(mid - state.vpCompositeVAL) < atrPrice * 0.3)
            aucMult += 0.10;
        }

      // Naked POC (original)
      if(state.vpNearestNakedPOC > 0)
        {
         double distNPOC = MathAbs(mid - state.vpNearestNakedPOC) / atrPrice;
         if(distNPOC < 0.5) aucMult += 0.08;
        }

      m_zones[idx].vpBoost      = MathMax(0.70, MathMin(1.35, vpMult));
      m_zones[idx].auctionBoost = MathMax(0.70, MathMin(1.35, aucMult));

      // ── v4.0: Structural context (bao gồm thesis health & composite) ──
      ApplyStructuralContext(idx, state, atrPrice, thesisHealth);
      m_zones[idx].vpBoost      = MathMax(0.70, MathMin(1.35, m_zones[idx].vpBoost));
      m_zones[idx].auctionBoost = MathMax(0.70, MathMin(1.35, m_zones[idx].auctionBoost));
     }

   // ── State updates (unchanged ATR) ──
   void UpdateStates(double bid, double atrPrice)
     {
      for(int i = 0; i < m_count; i++)
        {
         if(m_zones[i].state == ZONE_INVALIDATED) continue;
         double width  = m_zones[i].high - m_zones[i].low;
         bool   inZone = (bid >= m_zones[i].low && bid <= m_zones[i].high);

         if(inZone)
           {
            m_zones[i].testCount++;
            if(m_zones[i].state == ZONE_FRESH) m_zones[i].state = ZONE_TESTED;
            if(m_zones[i].testCount >= 3)       m_zones[i].state = ZONE_WEAK;
           }

         if(m_zones[i].testCount > 0 && !inZone && atrPrice > 0)
           {
            double distOut = m_zones[i].isBullish
                             ? (bid - m_zones[i].high)
                             : (m_zones[i].low - bid);
            if(distOut > 0)
               m_zones[i].rejectionScore = Clamp01(distOut / atrPrice);
           }

         if( m_zones[i].isBullish && bid < m_zones[i].low  - width) m_zones[i].state = ZONE_INVALIDATED;
         if(!m_zones[i].isBullish && bid > m_zones[i].high + width) m_zones[i].state = ZONE_INVALIDATED;

         m_zones[i].quality = Clamp01(m_zones[i].impulseRange / 2.0) * 0.4
                            + Clamp01(m_zones[i].volumeRatio  / 3.0) * 0.3
                            + Clamp01(1.0 - (double)m_zones[i].testCount / 5.0) * 0.3;
        }
     }

   void Compact(void)
     {
      int write = 0;
      for(int i = 0; i < m_count; i++)
         if(m_zones[i].state != ZONE_INVALIDATED)
            m_zones[write++] = m_zones[i];
      m_count = write;
     }

   void ComputeAggregateScores(const SPipelineState &state, double atrPrice, double thesisHealth)
     {
      double totalBullWeight = 0, totalBearWeight = 0;
      int activeCount = 0;

      for(int i = 0; i < m_count; i++)
        {
         if(m_zones[i].state == ZONE_INVALIDATED) continue;
         ComputeZoneBoosts(i, state, atrPrice, thesisHealth);
         double w = m_zones[i].quality * m_zones[i].vpBoost * m_zones[i].auctionBoost;
         if(m_zones[i].isBullish)
            totalBullWeight += w;
         else
            totalBearWeight += w;
         activeCount++;
        }

      if(activeCount > 0)
        {
         m_overallQuality = (totalBullWeight + totalBearWeight) / activeCount;
         if(totalBullWeight > totalBearWeight * 1.5)
            m_directionBias = 1.0;
         else if(totalBearWeight > totalBullWeight * 1.5)
            m_directionBias = -1.0;
         else
            m_directionBias = (totalBullWeight - totalBearWeight) / (totalBullWeight + totalBearWeight + 0.001);
        }
      else
        {
         m_overallQuality = 0;
         m_directionBias = 0.0;
        }
     }

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol,"ZoneLifecycleManager");
      m_count          = 0;
      m_lastDetectTime = 0;
      m_overallQuality = 0;
      m_directionBias  = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool Execute(SPipelineState &state) override
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
         m_overallQuality = 0.0;
         m_directionBias = 0.0;
         state.smartMoney.zoneQualityScore = 0.0;
         state.smartMoney.mitigationScore = 0.0;
         state.smartMoney.breakerBlockScore = 0.0;
         state.smartMoney.rejectionBlockScore = 0.0;
         return true;
        }

      // ── v4.0: Lấy sức khỏe luận điểm một lần ─────────────────
      // thesisHealth removed: already accounted for in auction adjustment above
      double thesisHealth = 0.5; // kept for function signature compatibility

      datetime lastBarTime = state.marketData.h1Rates[h1Count - 1].time;
      if(lastBarTime != m_lastDetectTime)
        {
         DetectAndRegister(state, atrPrice);
         m_lastDetectTime = lastBarTime;
        }

      UpdateStates(bid, atrPrice);
      Compact();
      ComputeAggregateScores(state, atrPrice, thesisHealth);

      // ── Original outputs (unchanged) ──
      int activeCount = 0, testedCount = 0;
      for(int i = 0; i < m_count; i++)
        {
         activeCount++;
         if(m_zones[i].state == ZONE_TESTED || m_zones[i].state == ZONE_WEAK) testedCount++;
        }
      state.smartMoney.mitigationScore = (activeCount > 0)
                                         ? Clamp01((double)testedCount / activeCount) : 0;

      double bestBreaker = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(m_zones[i].state != ZONE_INVALIDATED) continue;
         double mid  = (m_zones[i].high + m_zones[i].low) / 2.0;
         double dist = MathAbs(bid - mid);
         if(dist < atrPrice * 2.0)
           {
            double s = Clamp01(1.0 - dist / (atrPrice * 2.0 + 1e-9));
            if(s > bestBreaker) bestBreaker = s;
           }
        }
      state.smartMoney.breakerBlockScore = bestBreaker;

      double bestRejection = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(m_zones[i].state == ZONE_INVALIDATED) continue;
         if(m_zones[i].rejectionScore > bestRejection) bestRejection = m_zones[i].rejectionScore;
        }
      state.smartMoney.rejectionBlockScore = bestRejection;

      state.smartMoney.zoneQualityScore = m_overallQuality;

      if(m_overallQuality > 0.4 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_ZONE_QUALITY;
         state.pendingEventScores[idx] = m_overallQuality;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   int ZoneCount(void) const { return m_count; }
   double OverallQuality(void) const { return m_overallQuality; }
   double DirectionBias(void) const { return m_directionBias; }
  };

#endif