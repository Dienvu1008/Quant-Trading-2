#ifndef __EA_ROOT_BOSENGINE_MQH__
#define __EA_ROOT_BOSENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "SwingEngine.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| BOSEngine v4.0 — Auction‑Enhanced Structural Break of Structure  |
//| Integrates Volume Profile, Auction Intelligence & Thesis Manager |
//| Hard regime filter, thesis health scoring, composite confirmation|
//+------------------------------------------------------------------+

#define BOS_FAILURE_COOLDOWN_SEC 14400 // 4 giờ

class CBOSEngine : public CPipelineModuleBase
{
private:
   EBOSLifecycle m_lifecycle;
   double m_bosLevel;
   bool m_isBullish;
   datetime m_pendingTime;
   datetime m_testingStartTime;
   datetime m_lastBarTime;
   int m_persistenceBars;
   int m_persistenceThreshold;
   double m_totalDistBeyond;
   double m_avgDistanceBeyond;
   double m_followThroughScore;
   double m_bosQualityScore;
   double m_swingRelevanceWeight;
   datetime m_lastFailedTime;
   double m_lastFailedLevel;
   int m_recentFailCount;
   double m_maxPenetration;
   int m_decayWindow;
   bool m_useVolumeProfile;
   double m_bosScore;

   CAuctionThesisManager m_thesisManager;

   //+------------------------------------------------------------------+
   //| Structural Boost (không thay đổi ATR)                            |
   //+------------------------------------------------------------------+
   double GetStructuralBoost(const SPipelineState &state, bool isBullish, double atrPrice) const
   {
      if (!m_useVolumeProfile || !state.vpValid)
         return 1.0;
      double boost = 1.0;
      double currentPrice = state.marketData.bid;

      if (isBullish && currentPrice > state.vpVAH)
         boost += 0.08;
      else if (!isBullish && currentPrice < state.vpVAL)
         boost += 0.08;
      else if (state.vpInsideVA)
         boost -= 0.05;

      int regime = state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if (regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
         boost += 0.10 * regimeConf;
      else if (regime == (int)REGIME_BALANCED_ROTATION)
         boost -= 0.05;
      else if (regime == (int)REGIME_TREND_EXHAUSTION)
         boost -= 0.08;
      else if (regime == (int)REGIME_FAILED_AUCTION)
         boost -= 0.12;

      double slope = state.vpDevPOCSlope;
      double migScore = state.vpMigrationScore;
      double migDir = state.vpMigrationDirRaw;
      if (MathAbs(slope) > 0.02)
      {
         if ((isBullish && slope > 0) || (!isBullish && slope < 0))
            boost += 0.06;
         else
            boost -= 0.08;
      }
      if (migScore > 0.4)
      {
         if ((isBullish && migDir > 0) || (!isBullish && migDir < 0))
            boost += 0.08;
         else
            boost -= 0.06;
      }

      if (atrPrice > 0)
      {
         double distToBestHVN = (state.vpBestHVN > 0) ? MathAbs(m_bosLevel - state.vpBestHVN) / atrPrice : 999;
         double distToLVN = (state.vpNearestLVN > 0) ? MathAbs(m_bosLevel - state.vpNearestLVN) / atrPrice : 999;
         if (distToBestHVN < 0.5)
            boost += 0.10;
         else if (state.vpNearestHVN > 0)
         {
            double distToHVN = MathAbs(m_bosLevel - state.vpNearestHVN) / atrPrice;
            if (distToHVN < 0.5)
               boost -= 0.10;
         }
         if (distToLVN < 0.5)
            boost += 0.06;
      }

      if (state.auctAcceptanceScore > 0.65)
         boost += 0.08;
      else if (state.auctAcceptanceScore < 0.25)
         boost -= 0.08;
      if (state.auctFailureScore > 0.4)
         boost -= 0.10;

      if (state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
      {
         bool outsideComp = isBullish ? (currentPrice > state.vpCompositeVAH)
                                      : (currentPrice < state.vpCompositeVAL);
         if (outsideComp)
            boost += 0.12;
      }

      if (state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.7)
      {
         bool towardNaked = isBullish ? (state.vpNearestNakedPOC > currentPrice)
                                      : (state.vpNearestNakedPOC < currentPrice);
         if (towardNaked)
            boost += 0.07;
      }

      if (state.flow.absorptionScore > 0.6)
         boost += 0.05;
      if (state.flow.exhaustionScore > 0.5)
         boost -= 0.08;

      if (state.vpBreakoutPOC > 0)
      {
         bool pastBreakout = isBullish ? (currentPrice > state.vpBreakoutPOC)
                                       : (currentPrice < state.vpBreakoutPOC);
         if (pastBreakout)
            boost += 0.12;
      }

      if (state.vpRangePOC > 0 && MathAbs(currentPrice - state.vpRangePOC) < atrPrice * 0.5)
         boost += 0.08;
      if (state.vpPullbackPOC > 0 && MathAbs(currentPrice - state.vpPullbackPOC) < atrPrice * 0.5)
         boost += 0.06;

      if ((isBullish && state.vpSpringDetected) || (!isBullish && state.vpUpthrustDetected))
         boost += 0.15;
      else if ((isBullish && state.vpUpthrustDetected) || (!isBullish && state.vpSpringDetected))
         boost -= 0.20;

      if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         boost += 0.07;

      int vaBias = state.vpVAOverlapBias;
      if ((isBullish && vaBias == 1) || (!isBullish && vaBias == -1))
         boost += 0.06;
      else if ((isBullish && vaBias == -1) || (!isBullish && vaBias == 1))
         boost -= 0.08;

      if (state.vpMigrationConfidence > 0.5)
         boost += 0.05;

      return MathMax(0.70, MathMin(1.30, boost));
   }

   double ComputeFollowThrough(const SPipelineState &state, double atrPrice)
   {
      int h1Bars = state.marketData.h1Copied;
      if (h1Bars < 4 || atrPrice <= 0)
         return 0.0;

      double lastClose = state.marketData.h1Rates[h1Bars - 2].close;
      double dist = m_isBullish ? (lastClose - m_bosLevel) : (m_bosLevel - lastClose);
      double distNorm = Clamp01(dist / (atrPrice * 1.5));

      double bHigh = state.marketData.h1Rates[h1Bars - 2].high;
      double bLow = state.marketData.h1Rates[h1Bars - 2].low;
      double bOpen = state.marketData.h1Rates[h1Bars - 2].open;
      double bClose = state.marketData.h1Rates[h1Bars - 2].close;
      double body = MathAbs(bClose - bOpen);
      double range = bHigh - bLow;
      double bodyRatio = (range > 0) ? Clamp01(body / range) : 0.5;

      int dirBars = 0;
      for (int i = h1Bars - 2; i >= MathMax(0, h1Bars - 4); i--)
      {
         double mv = state.marketData.h1Rates[i].close - state.marketData.h1Rates[i].open;
         if ((m_isBullish && mv > 0) || (!m_isBullish && mv < 0))
            dirBars++;
      }
      double momentum = (double)dirBars / 3.0;

      double raw = distNorm * 0.40 + bodyRatio * 0.30 + momentum * 0.30;
      double vpMult = GetStructuralBoost(state, m_isBullish, atrPrice);
      return Clamp01(raw * vpMult);
   }

   double ComputeQualityScore(const SPipelineState &state, double atrPrice)
   {
      double persistScore = Clamp01(m_avgDistanceBeyond / 0.5);
      double ftScore = m_followThroughScore;
      double particScore = state.latentRaw.participationQuality;
      double speedScore = Clamp01(1.0 - (double)(m_persistenceBars - 1) / 4.0);

      double raw = persistScore * 0.25 + ftScore * 0.30 + particScore * 0.25 + speedScore * 0.20;
      double weighted = raw * m_swingRelevanceWeight;

      // Sức khỏe luận điểm từ AuctionThesisManager (giả định lệnh theo hướng BOS)
      double thesisHealth = 0.5;
      if (m_useVolumeProfile && state.vpValid)
      {
         if (m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
            m_thesisManager.InitTrade(ENTRY_BREAKOUT, atrPrice, state.auctRegimeConfidence, m_symbol);

         SThesisOutput thesisOut = m_thesisManager.Evaluate(state, 0.0, atrPrice);
         thesisHealth = thesisOut.thesis.thesisHealth;
      }

      // Xác nhận composite profile
      double compositeBonus = 0.0;
      if (state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
      {
         bool outsideComp = m_isBullish ? (state.marketData.bid > state.vpCompositeVAH)
                                        : (state.marketData.bid < state.vpCompositeVAL);
         compositeBonus = outsideComp ? 0.15 : -0.15;
      }

      double vpMult = GetStructuralBoost(state, m_isBullish, atrPrice);
      double baseScore = Clamp01(weighted * vpMult);

      return Clamp01(baseScore * 0.5 + thesisHealth * 0.30 + (0.5 + compositeBonus) * 0.20);
   }

   double ComputeSwingRelevance(int barsAgo)
   {
      if (barsAgo <= 0)
         return 1.0;
      double decay = 1.0 - (double)barsAgo / (double)m_decayWindow;
      return MathMax(0.2, decay);
   }

   bool IsLevelInCooldown(double level)
   {
      if (m_lastFailedTime == 0)
         return false;
      if (MathAbs(level - m_lastFailedLevel) > m_bosLevel * 0.001)
         return false;
      return (TimeCurrent() - m_lastFailedTime < BOS_FAILURE_COOLDOWN_SEC);
   }

   void EmitEvent(SPipelineState &state, int eventType, double score, int dir)
   {
      if (state.pendingEventCount < 4)
      {
         int idx = state.pendingEventCount++;
         state.pendingEventTypes[idx] = eventType;
         state.pendingEventScores[idx] = score;
         state.pendingEventDirs[idx] = dir;
      }
   }

   void TransitionToFailed(SPipelineState &state, double atrPrice)
   {
      double failScore = (atrPrice > 0) ? Clamp01(m_maxPenetration / atrPrice) : 0.5;
      m_lastFailedTime = TimeCurrent();
      m_lastFailedLevel = m_bosLevel;
      m_recentFailCount++;
      EmitEvent(state, 11, failScore, m_isBullish ? 1 : -1);
      m_lifecycle = BOS_LIFECYCLE_NONE;
      m_bosQualityScore = 0.0;
      m_followThroughScore = 0.0;
      m_persistenceBars = 0;
      m_thesisManager.Reset();
   }

   //+------------------------------------------------------------------+
   //| Bộ lọc regime cứng – giữ nguyên ATR gốc                         |
   //+------------------------------------------------------------------+
   bool IsRegimeAllowedForBOS(const SPipelineState &state)
   {
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double conf = state.auctRegimeConfidence;

      if (regime == REGIME_CHAOTIC || regime == REGIME_EXCESS)
         return false;
      if (regime == REGIME_FAILED_AUCTION && conf > 0.6)
         return false;
      return true;
   }

public:
   void Bootstrap(const string symbol)
   {
      Configure(symbol, "BOSEngine");
      m_lifecycle = BOS_LIFECYCLE_NONE;
      m_bosLevel = 0;
      m_isBullish = false;
      m_pendingTime = 0;
      m_testingStartTime = 0;
      m_lastBarTime = 0;
      m_persistenceBars = 0;
      m_persistenceThreshold = 2;
      m_totalDistBeyond = 0;
      m_avgDistanceBeyond = 0;
      m_followThroughScore = 0;
      m_bosQualityScore = 0;
      m_swingRelevanceWeight = 1.0;
      m_lastFailedTime = 0;
      m_lastFailedLevel = 0;
      m_recentFailCount = 0;
      m_maxPenetration = 0;
      m_decayWindow = 48;
      m_useVolumeProfile = true;
      m_bosScore = 0;
      m_thesisManager.Reset();
   }

   void Detect(const CSwingEngine &swings, double currentPrice) {}

   virtual bool Execute(SPipelineState &state) override
   {
      CPipelineModuleBase::Execute(state);
      int h1Bars = state.marketData.h1Copied;
      int hiCount = state.structure.swingHighCount;
      int loCount = state.structure.swingLowCount;
      double bid = state.marketData.bid;

      // Giữ nguyên công thức tính atrPrice theo thiết kế gốc
      double pointSize = state.marketData.pointSize;
      double atrPrice = state.marketData.atrProxy * pointSize;

      if (h1Bars < 5 || atrPrice <= 0)
      {
         WriteState(state);
         return true;
      }

      datetime currentBarTime = state.marketData.h1Rates[h1Bars - 1].time;
      bool isNewBar = (currentBarTime != m_lastBarTime);
      m_lastBarTime = currentBarTime;

      double lastClose = state.marketData.h1Rates[h1Bars - 2].close;

      // ── Bộ lọc regime cứng ──
      if (!IsRegimeAllowedForBOS(state))
      {
         if (m_lifecycle != BOS_LIFECYCLE_NONE)
            TransitionToFailed(state, atrPrice);
         WriteState(state);
         return true;
      }

      int baseThreshold = m_persistenceThreshold;
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      if (regime == REGIME_TREND_EXHAUSTION)
         baseThreshold++;
      if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         baseThreshold = MathMax(baseThreshold, 3);

      switch (m_lifecycle)
      {
      case BOS_LIFECYCLE_NONE:
      {
         if (hiCount >= 1)
         {
            double swHigh = state.structure.swingHighs[hiCount - 1].price;
            int swBarIdx = state.structure.swingHighs[hiCount - 1].barIndex;
            int barsAgo = h1Bars - 1 - swBarIdx;
            if (!IsLevelInCooldown(swHigh) && bid > swHigh + atrPrice * 0.05)
            {
               double relevance = ComputeSwingRelevance(barsAgo);
               if (relevance > 0.3)
               {
                  m_lifecycle = BOS_LIFECYCLE_PENDING;
                  m_bosLevel = swHigh;
                  m_isBullish = true;
                  m_pendingTime = TimeCurrent();
                  m_swingRelevanceWeight = relevance;
                  m_maxPenetration = bid - swHigh;
                  m_persistenceBars = 0;
                  m_totalDistBeyond = 0;
               }
            }
         }
         if (m_lifecycle == BOS_LIFECYCLE_NONE && loCount >= 1)
         {
            double swLow = state.structure.swingLows[loCount - 1].price;
            int swBarIdx = state.structure.swingLows[loCount - 1].barIndex;
            int barsAgo = h1Bars - 1 - swBarIdx;
            if (!IsLevelInCooldown(swLow) && bid < swLow - atrPrice * 0.05)
            {
               double relevance = ComputeSwingRelevance(barsAgo);
               if (relevance > 0.3)
               {
                  m_lifecycle = BOS_LIFECYCLE_PENDING;
                  m_bosLevel = swLow;
                  m_isBullish = false;
                  m_pendingTime = TimeCurrent();
                  m_swingRelevanceWeight = relevance;
                  m_maxPenetration = swLow - bid;
                  m_persistenceBars = 0;
                  m_totalDistBeyond = 0;
               }
            }
         }
         break;
      }

      case BOS_LIFECYCLE_PENDING:
      {
         double pen = m_isBullish ? (bid - m_bosLevel) : (m_bosLevel - bid);
         if (pen > m_maxPenetration)
            m_maxPenetration = pen;
         bool closedBeyond = m_isBullish ? (lastClose > m_bosLevel) : (lastClose < m_bosLevel);
         if (closedBeyond && isNewBar)
         {
            m_lifecycle = BOS_LIFECYCLE_TESTING;
            m_testingStartTime = TimeCurrent();
            m_persistenceBars = 1;
            double dist = m_isBullish ? (lastClose - m_bosLevel) : (m_bosLevel - lastClose);
            m_totalDistBeyond = dist / atrPrice;
         }
         else
         {
            bool failed = m_isBullish ? (bid < m_bosLevel * 0.997) : (bid > m_bosLevel * 1.003);
            if (failed)
               TransitionToFailed(state, atrPrice);
         }
         break;
      }

      case BOS_LIFECYCLE_TESTING:
      {
         if (!isNewBar)
            break;
         double pen = m_isBullish ? (bid - m_bosLevel) : (m_bosLevel - bid);
         if (pen > m_maxPenetration)
            m_maxPenetration = pen;
         bool closedBeyond = m_isBullish ? (lastClose > m_bosLevel) : (lastClose < m_bosLevel);
         if (closedBeyond)
         {
            m_persistenceBars++;
            double dist = m_isBullish ? (lastClose - m_bosLevel) : (m_bosLevel - lastClose);
            m_totalDistBeyond += dist / atrPrice;
            m_avgDistanceBeyond = m_totalDistBeyond / m_persistenceBars;
         }
         else
         {
            double distFromLevel = m_isBullish ? (lastClose - m_bosLevel) : (m_bosLevel - lastClose);
            if (distFromLevel > -0.1 * atrPrice)
            {
               m_persistenceBars = 0;
               m_totalDistBeyond = 0;
            }
            else
            {
               TransitionToFailed(state, atrPrice);
               break;
            }
         }

         int threshold = baseThreshold;
         if (m_swingRelevanceWeight < 0.5)
            threshold++;
         if (m_persistenceBars >= threshold)
         {
            m_lifecycle = BOS_LIFECYCLE_ACCEPTED;
            m_followThroughScore = ComputeFollowThrough(state, atrPrice);
         }
         break;
      }

      case BOS_LIFECYCLE_ACCEPTED:
      {
         bool compositeOK = true;
         if (state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
         {
            if (m_isBullish && state.marketData.bid <= state.vpCompositeVAH)
               compositeOK = false;
            if (!m_isBullish && state.marketData.bid >= state.vpCompositeVAL)
               compositeOK = false;
         }

         if (m_followThroughScore >= 0.5 && compositeOK)
         {
            m_lifecycle = BOS_LIFECYCLE_CONFIRMED;
            m_bosQualityScore = ComputeQualityScore(state, atrPrice);
            m_bosScore = m_bosQualityScore;
            EmitEvent(state, 10, m_bosQualityScore, m_isBullish ? 1 : -1);
         }
         else if (m_followThroughScore < 0.3 || !compositeOK)
         {
            if (m_persistenceBars > baseThreshold + 3)
               TransitionToFailed(state, atrPrice);
            else if (isNewBar)
               m_followThroughScore = ComputeFollowThrough(state, atrPrice);
         }
         else
         {
            if (isNewBar)
               m_followThroughScore = ComputeFollowThrough(state, atrPrice);
            bool failed = m_isBullish ? (lastClose < m_bosLevel * 0.997) : (lastClose > m_bosLevel * 1.003);
            if (failed)
               TransitionToFailed(state, atrPrice);
         }
         break;
      }

      case BOS_LIFECYCLE_CONFIRMED:
      {
         bool invalidated = m_isBullish ? (lastClose < m_bosLevel - atrPrice * 0.5)
                                        : (lastClose > m_bosLevel + atrPrice * 0.5);
         if (invalidated)
         {
            m_lifecycle = BOS_LIFECYCLE_NONE;
            m_bosQualityScore = 0;
            m_bosScore = 0;
            m_thesisManager.Reset();
         }
         break;
      }

      case BOS_LIFECYCLE_FAILED:
      {
         m_lifecycle = BOS_LIFECYCLE_NONE;
         m_thesisManager.Reset();
         break;
      }
      }

      WriteState(state);
      return true;
   }

   void WriteState(SPipelineState &state)
   {
      state.structure.bosScore = m_bosScore;
      state.structure.bosLifecycleState = (int)m_lifecycle;
      state.structure.bosFollowThrough = m_followThroughScore;
      state.structure.bosQualityScore = m_bosQualityScore;
      state.structure.bosPersistenceBars = m_persistenceBars;
   }

   EBOSLifecycle Lifecycle(void) const { return m_lifecycle; }
   bool IsBullishBOS(void) const { return m_lifecycle == BOS_LIFECYCLE_CONFIRMED && m_isBullish; }
   bool IsBearishBOS(void) const { return m_lifecycle == BOS_LIFECYCLE_CONFIRMED && !m_isBullish; }
   bool IsAccepted(void) const { return m_lifecycle >= BOS_LIFECYCLE_ACCEPTED; }
   double BOSLevel(void) const { return m_bosLevel; }
   int RecentFailCount(void) const { return m_recentFailCount; }
};

#endif