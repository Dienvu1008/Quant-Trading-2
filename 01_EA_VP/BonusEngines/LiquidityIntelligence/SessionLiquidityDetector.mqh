#ifndef __EA_ROOT_SESSIONLIQUIDITYDETECTOR_MQH__
#define __EA_ROOT_SESSIONLIQUIDITYDETECTOR_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Session Liquidity Detector v4.0 — Auction‑Enhanced Flow           |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

class CSessionLiquidityDetector : public CPipelineModuleBase
  {
private:
   double            m_sessionHigh;
   double            m_sessionLow;
   int               m_brokerGMTOffset;
   double            m_directionBias;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Apply structural context (v3 + thesis health & composite confirm)|
   //+------------------------------------------------------------------+
   void              ApplyStructuralContext(const SPipelineState &state,
                                            double &qualityMult,
                                            double &direction,
                                            double atrPrice)
     {
      double bid = state.marketData.bid;

      // Anchored profiles crossing session range
      if(state.vpRangePOC > 0 && bid >= m_sessionLow && bid <= m_sessionHigh)
        {
         if(MathAbs(bid - state.vpRangePOC) < atrPrice * 0.5)
           {
            qualityMult *= 1.1;
            if(bid > state.vpRangePOC) direction = MathMax(direction, 0.5);
            else direction = MathMin(direction, -0.5);
           }
        }
      if(state.vpBreakoutPOC > 0 && MathAbs(bid - state.vpBreakoutPOC) < atrPrice * 0.5)
        {
         qualityMult *= 1.15;
         direction = (bid > state.vpBreakoutPOC) ? MathMax(direction, 0.7) : MathMin(direction, -0.7);
        }

      // Best HVN inside session range -> strong liquidity anchor
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.4)
        {
         qualityMult *= 1.1;
         if(state.vpBestHVN > bid) direction = MathMax(direction, 0.4);
         else direction = MathMin(direction, -0.4);
        }

      // Fake breakout traps -> session liquidity may be false
      if(state.vpUpthrustDetected) direction = MathMin(direction, -0.7);
      if(state.vpSpringDetected)   direction = MathMax(direction, 0.7);

      // Thin profile -> range likely directional
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         qualityMult *= 1.05;

      // VA Overlap bias provides strong directional cue
      int vaBias = state.vpVAOverlapBias;
      if(vaBias == 1) direction = MathMax(direction, 0.6);
      if(vaBias == -1) direction = MathMin(direction, -0.6);

      // Migration confidence enhances direction
      if(state.vpMigrationConfidence > 0.6 && direction != 0)
         direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

      // ── v4.0: Sức khỏe luận điểm (Breakout / Reversal) ───────
      if(state.vpValid)
        {
         EEntryArchetype arch = (MathAbs(direction) > 0.4) ? ENTRY_BREAKOUT : ENTRY_MEAN_REVERSION;
         if(m_thesisManager.GetArchetype() != arch)
            m_thesisManager.InitTrade(arch, atrPrice, state.auctRegimeConfidence, m_symbol);

         SThesisOutput out = m_thesisManager.Evaluate(state, 0.0, atrPrice);
         double health = out.thesis.thesisHealth;
         qualityMult *= (0.8 + health * 0.4);
         if(health < 0.3 && direction != 0) direction *= 0.5;
        }

      // ── v4.0: Xác nhận composite đa khung thời gian ──────────
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
      Configure(symbol, "SessionLiquidityDetector");
      m_sessionHigh      = 0;
      m_sessionLow       = 0;
      m_brokerGMTOffset  = DetectBrokerGMTOffset();
      m_directionBias    = 0.0;
      m_thesisManager.Reset();
     }

   virtual bool      Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      int m5Count = state.marketData.m5Copied;
      if(m5Count < 3) return true;

      // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         state.liquidity.sessionLiquidityScore = 0.0;
         m_directionBias = 0.0;
         return true;
        }

      int gmtHour = GetCurrentGMTHour();
      ESessionType curSession = ClassifySessionGMT(gmtHour);

      int gmtSessionStart;
      if(curSession == SESSION_NEWYORK || curSession == SESSION_OVERLAP)
         gmtSessionStart = SESSION_NY_START_GMT;
      else if(curSession == SESSION_LONDON)
         gmtSessionStart = SESSION_LONDON_START_GMT;
      else
         gmtSessionStart = SESSION_ASIAN_START_GMT;

      int serverSessionStart = (gmtSessionStart + m_brokerGMTOffset) % 24;
      if(serverSessionStart < 0) serverSessionStart += 24;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime todayMidnight = TimeCurrent()
                               - (datetime)(dt.hour * 3600 + dt.min * 60 + dt.sec);

      datetime sessionStartTime;
      if(dt.hour >= serverSessionStart)
         sessionStartTime = todayMidnight + (datetime)(serverSessionStart * 3600);
      else
         sessionStartTime = todayMidnight - 86400 + (datetime)(serverSessionStart * 3600);

      m_sessionHigh = 0;
      m_sessionLow  = DBL_MAX;
      bool found = false;

      for(int i = 0; i < m5Count; i++)
        {
         if(state.marketData.m5Rates[i].time >= sessionStartTime)
           {
            if(!found || state.marketData.m5Rates[i].high > m_sessionHigh)
               m_sessionHigh = state.marketData.m5Rates[i].high;
            if(!found || state.marketData.m5Rates[i].low < m_sessionLow)
               m_sessionLow = state.marketData.m5Rates[i].low;
            found = true;
           }
        }

      if(!found || m_sessionLow == DBL_MAX)
        {
         m_sessionHigh = state.marketData.m5Rates[0].high;
         m_sessionLow  = state.marketData.m5Rates[0].low;
         for(int i = 1; i < m5Count; i++)
           {
            if(state.marketData.m5Rates[i].high > m_sessionHigh) m_sessionHigh = state.marketData.m5Rates[i].high;
            if(state.marketData.m5Rates[i].low < m_sessionLow)   m_sessionLow  = state.marketData.m5Rates[i].low;
           }
        }

      // --- ATR in price (giữ nguyên) ---
      double pointSize = state.marketData.pointSize;
      double atrPrice  = state.marketData.atrProxy * pointSize;
      if(atrPrice <= 0) atrPrice = pointSize * 10;

      double range     = m_sessionHigh - m_sessionLow;
      double baseScore = (range > 0 && atrPrice > 0)
                         ? Clamp01(range / (atrPrice * 3.0))
                         : 0.5;

      double acceptRatio = 0.5;
      if(state.vpValid && state.vpVAH > state.vpVAL)
        {
         double vaWidth = state.vpVAH - state.vpVAL;
         acceptRatio = (range > 0) ? Clamp01(vaWidth / range) : 0.5;
         double expansionBoost = 0.0;
         if(state.auctValueAreaState == (int)VA_EXPANDING)    expansionBoost = 0.10;
         else if(state.auctValueAreaState == (int)VA_CONTRACTING) expansionBoost = -0.10;
         baseScore = baseScore * (0.5 + 0.5 * acceptRatio) + expansionBoost;
        }

      double qualityMult = 1.0;
      double direction   = 0.0;

      if(regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
        {
         qualityMult = 1.0 + 0.3 * regimeConf;
         if(state.vpDevPOCSlope > 0.02) direction = 1.0;
         else if(state.vpDevPOCSlope < -0.02) direction = -1.0;
        }
      else if(regime == (int)REGIME_BALANCED_ROTATION)
        {
         if(acceptRatio > 0.6) qualityMult = 1.2;
         else                  qualityMult = 0.8;
         if(MathAbs(state.vpDevPOCSlope) > 0.02) direction = (state.vpDevPOCSlope > 0) ? 1.0 : -1.0;
        }
      else if(regime == (int)REGIME_TREND_EXHAUSTION)
        {
         qualityMult = 1.1;
         double mid = (m_sessionHigh + m_sessionLow) / 2.0;
         if(state.marketData.bid > mid) direction = -0.8;
         else                            direction = 0.8;
        }
      else if(regime == (int)REGIME_FAILED_AUCTION)
        {
         qualityMult = 1.15;
         if(acceptRatio < 0.4)
           {
            double mid = (m_sessionHigh + m_sessionLow) / 2.0;
            if(state.marketData.bid > mid) direction = -1.0;
            else                            direction = 1.0;
           }
        }

      if(state.auctExhaustionScore > 0.65) qualityMult *= 0.9;
      if(state.auctContinuationScore > 0.7) qualityMult *= 1.05;

      if(state.vpValid)
        {
         double bid = state.marketData.bid;
         if(m_sessionHigh > state.vpCompositeVAH || m_sessionLow < state.vpCompositeVAL)
            qualityMult *= 1.15;
         if(bid > state.vpCompositeVAH) direction = MathMax(direction, 0.5);
         if(bid < state.vpCompositeVAL) direction = MathMin(direction, -0.5);
        }

      if(state.vpNearestNakedPOC > 0)
        {
         double dist = MathAbs(state.marketData.bid - state.vpNearestNakedPOC);
         if(dist < atrPrice * 1.5)
           {
            qualityMult *= 1.1;
            if(state.marketData.bid < state.vpNearestNakedPOC) direction = MathMax(direction, 0.3);
            else direction = MathMin(direction, -0.3);
           }
        }

      // --- Structural V3 + v4.0 (thesis + composite) ---
      ApplyStructuralContext(state, qualityMult, direction, atrPrice);

      direction = MathMax(-1.0, MathMin(1.0, direction));
      m_directionBias = direction;

      double finalScore = Clamp01(baseScore * qualityMult);

      state.liquidity.sessionLiquidityScore = finalScore;

      if(finalScore > 0.65 && state.pendingEventCount < 4)
        {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx]  = (int)EVENT_SESSION_LIQUIDITY;
         state.pendingEventScores[idx] = finalScore;
         state.pendingEventDirs[idx]   = m_directionBias;
        }

      return true;
     }

   double            SessionHigh(void) const { return m_sessionHigh; }
   double            SessionLow(void)  const { return m_sessionLow; }
   double            DirectionBias(void) const { return m_directionBias; }
  };

#endif