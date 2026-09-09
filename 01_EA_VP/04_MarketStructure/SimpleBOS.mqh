#ifndef __VP_EA_SIMPLE_BOS_MQH__
#define __VP_EA_SIMPLE_BOS_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "SimpleSwingDetector.mqh"

//+------------------------------------------------------------------+
//| Simple BOS — Pure Price-Action Break of Structure                |
//| NO VP/Auction dependency. Uses H1 swing levels only.             |
//| Lifecycle: NONE → PENDING → TESTING → CONFIRMED                  |
//+------------------------------------------------------------------+

enum EVPBOSState
{
   VPBOS_NONE = 0,
   VPBOS_PENDING = 1,
   VPBOS_TESTING = 2,
   VPBOS_CONFIRMED = 3
};

class CSimpleBOS : public CVPModuleBase
{
private:
   EVPBOSState m_state;
   double   m_bosLevel;
   bool     m_isBullish;
   datetime m_lastBarTime;
   int      m_persistenceBars;
   int      m_persistenceThreshold;
   double   m_qualityScore;
   datetime m_confirmedTime;
   datetime m_lastFailedTime;
   double   m_lastFailedLevel;

   // Outputs
   bool     m_bosActive;       // confirmed and not invalidated
   double   m_bosScore;        // quality 0-1

   double ComputeFollowThrough(const SVPPipelineState &state, double atrPrice)
   {
      int n = state.marketData.h1Copied;
      if (n < 4 || atrPrice <= 0) return 0.0;

      double lastClose = state.marketData.h1Rates[n - 2].close;
      double dist = m_isBullish ? (lastClose - m_bosLevel) : (m_bosLevel - lastClose);
      double distNorm = Clamp01(dist / (atrPrice * 1.5));

      double bOpen = state.marketData.h1Rates[n - 2].open;
      double bClose = state.marketData.h1Rates[n - 2].close;
      double bRange = state.marketData.h1Rates[n - 2].high - state.marketData.h1Rates[n - 2].low;
      double bodyRatio = (bRange > 0) ? Clamp01(MathAbs(bClose - bOpen) / bRange) : 0.5;

      // Momentum: count directional bars in last 3
      int dirBars = 0;
      for (int i = n - 2; i >= MathMax(0, n - 4); i--)
      {
         double mv = state.marketData.h1Rates[i].close - state.marketData.h1Rates[i].open;
         if ((m_isBullish && mv > 0) || (!m_isBullish && mv < 0))
            dirBars++;
      }
      double momentum = (double)dirBars / 3.0;

      return Clamp01(distNorm * 0.40 + bodyRatio * 0.30 + momentum * 0.30);
   }

   bool IsInCooldown(double level)
   {
      if (m_lastFailedTime == 0) return false;
      if (MathAbs(level - m_lastFailedLevel) > level * 0.001) return false;
      return (TimeCurrent() - m_lastFailedTime < 14400); // 4h cooldown
   }

public:
   void Bootstrap(const string symbol)
   {
      Configure(symbol, "SimpleBOS");
      m_state = VPBOS_NONE;
      m_bosLevel = 0; m_isBullish = false;
      m_lastBarTime = 0; m_persistenceBars = 0;
      m_persistenceThreshold = 2;
      m_qualityScore = 0; m_confirmedTime = 0;
      m_lastFailedTime = 0; m_lastFailedLevel = 0;
      m_bosActive = false; m_bosScore = 0;
   }

   void Update(const SVPPipelineState &state, const CSimpleSwingDetector &swings)
   {
      int h1Bars = state.marketData.h1Copied;
      double bid = state.marketData.bid;
      double pointSize = state.marketData.pointSize;
      double atrPrice = state.marketData.atrProxy * pointSize;
      if (h1Bars < 5 || atrPrice <= 0) return;

      datetime currentBarTime = state.marketData.h1Rates[h1Bars - 1].time;
      bool isNewBar = (currentBarTime != m_lastBarTime);
      m_lastBarTime = currentBarTime;
      double lastClose = state.marketData.h1Rates[h1Bars - 2].close;

      switch (m_state)
      {
         case VPBOS_NONE:
         {
            // Check bullish BOS: price breaks above last swing high
            double swHigh = swings.LastSwingHigh();
            if (swHigh > 0 && !IsInCooldown(swHigh) && bid > swHigh + atrPrice * 0.05)
            {
               m_state = VPBOS_PENDING;
               m_bosLevel = swHigh;
               m_isBullish = true;
               m_persistenceBars = 0;
               break;
            }
            // Check bearish BOS
            double swLow = swings.LastSwingLow();
            if (swLow > 0 && !IsInCooldown(swLow) && bid < swLow - atrPrice * 0.05)
            {
               m_state = VPBOS_PENDING;
               m_bosLevel = swLow;
               m_isBullish = false;
               m_persistenceBars = 0;
            }
            break;
         }
         case VPBOS_PENDING:
         {
            bool closedBeyond = m_isBullish ? (lastClose > m_bosLevel) : (lastClose < m_bosLevel);
            if (closedBeyond && isNewBar)
            {
               m_state = VPBOS_TESTING;
               m_persistenceBars = 1;
            }
            else
            {
               bool failed = m_isBullish ? (bid < m_bosLevel * 0.997) : (bid > m_bosLevel * 1.003);
               if (failed) { _Fail(); }
            }
            break;
         }
         case VPBOS_TESTING:
         {
            if (!isNewBar) break;
            bool closedBeyond = m_isBullish ? (lastClose > m_bosLevel) : (lastClose < m_bosLevel);
            if (closedBeyond)
               m_persistenceBars++;
            else
            {
               double distBack = m_isBullish ? (m_bosLevel - lastClose) : (lastClose - m_bosLevel);
               if (distBack > atrPrice * 0.1) { _Fail(); break; }
               else m_persistenceBars = 0;
            }
            if (m_persistenceBars >= m_persistenceThreshold)
            {
               m_qualityScore = ComputeFollowThrough(state, atrPrice);
               m_state = VPBOS_CONFIRMED;
               m_confirmedTime = TimeCurrent();
               m_bosActive = true;
               m_bosScore = m_qualityScore;
            }
            break;
         }
         case VPBOS_CONFIRMED:
         {
            // Invalidate if price reverses significantly
            bool invalidated = m_isBullish
               ? (lastClose < m_bosLevel - atrPrice * 0.5)
               : (lastClose > m_bosLevel + atrPrice * 0.5);
            if (invalidated)
            {
               m_state = VPBOS_NONE;
               m_bosActive = false;
               m_bosScore = 0;
            }
            break;
         }
      }
   }

   void _Fail(void)
   {
      m_lastFailedTime = TimeCurrent();
      m_lastFailedLevel = m_bosLevel;
      m_state = VPBOS_NONE;
      m_bosActive = false;
      m_bosScore = 0;
   }

   // Accessors
   bool IsConfirmed(void) const { return m_state == VPBOS_CONFIRMED; }
   bool IsBullish(void) const { return m_isBullish; }
   bool IsActive(void) const { return m_bosActive; }
   double Score(void) const { return m_bosScore; }
   double Level(void) const { return m_bosLevel; }
   EVPBOSState State(void) const { return m_state; }
};

#endif
