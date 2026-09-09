#ifndef __VP_EA_SIMPLE_CHOCH_MQH__
#define __VP_EA_SIMPLE_CHOCH_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "SimpleSwingDetector.mqh"

//+------------------------------------------------------------------+
//| Simple CHOCH — Pure Price-Action Change of Character             |
//| NO VP/Auction dependency. Detects structural reversal from H1.   |
//| Requires: prior trend direction + break of counter-swing         |
//+------------------------------------------------------------------+

enum EVPCHOCHState
{
   VPCHOCH_NONE = 0,
   VPCHOCH_PROBE = 1,
   VPCHOCH_TESTING = 2,
   VPCHOCH_CONFIRMED = 3
};

class CSimpleCHOCH : public CVPModuleBase
{
private:
   EVPCHOCHState m_state;
   double   m_chochLevel;
   bool     m_bullishReversal;  // true = reversing from downtrend to uptrend
   datetime m_lastBarTime;
   int      m_reversalBars;
   int      m_reversalThreshold;
   double   m_qualityScore;
   datetime m_confirmedTime;
   datetime m_lastFailedTime;
   double   m_lastFailedLevel;

   // Trend detection from swings
   int      m_trendDir;  // +1=uptrend, -1=downtrend, 0=neutral

   // Outputs
   bool     m_chochActive;
   double   m_chochScore;

   int DetectTrend(const CSimpleSwingDetector &swings)
   {
      // Simple trend: compare last 2 swing highs and lows
      int hiCount = swings.HighCount();
      int loCount = swings.LowCount();
      if (hiCount < 2 || loCount < 2) return 0;

      double hi1 = swings.GetSwingHigh(hiCount - 1).price;
      double hi2 = swings.GetSwingHigh(hiCount - 2).price;
      double lo1 = swings.GetSwingLow(loCount - 1).price;
      double lo2 = swings.GetSwingLow(loCount - 2).price;

      bool higherHighs = (hi1 > hi2);
      bool higherLows = (lo1 > lo2);
      bool lowerHighs = (hi1 < hi2);
      bool lowerLows = (lo1 < lo2);

      if (higherHighs && higherLows) return 1;   // uptrend
      if (lowerHighs && lowerLows) return -1;    // downtrend
      return 0;
   }

   double ComputeReversalQuality(const SVPPipelineState &state, double atrPrice)
   {
      int n = state.marketData.h1Copied;
      if (n < 4 || atrPrice <= 0) return 0.0;

      double lastClose = state.marketData.h1Rates[n - 2].close;
      double dist = m_bullishReversal ? (lastClose - m_chochLevel) : (m_chochLevel - lastClose);
      double distNorm = Clamp01(dist / (atrPrice * 1.2));

      double bOpen = state.marketData.h1Rates[n - 2].open;
      double bClose = state.marketData.h1Rates[n - 2].close;
      double bRange = state.marketData.h1Rates[n - 2].high - state.marketData.h1Rates[n - 2].low;
      double bodyRatio = (bRange > 0) ? Clamp01(MathAbs(bClose - bOpen) / bRange) : 0.5;

      // Speed of reversal
      double speedScore = Clamp01(1.0 - (double)m_reversalBars / 5.0);

      return Clamp01(distNorm * 0.40 + bodyRatio * 0.30 + speedScore * 0.30);
   }

   bool IsInCooldown(double level)
   {
      if (m_lastFailedTime == 0) return false;
      if (MathAbs(level - m_lastFailedLevel) > level * 0.002) return false;
      return (TimeCurrent() - m_lastFailedTime < 7200); // 2h cooldown
   }

public:
   void Bootstrap(const string symbol)
   {
      Configure(symbol, "SimpleCHOCH");
      m_state = VPCHOCH_NONE;
      m_chochLevel = 0; m_bullishReversal = false;
      m_lastBarTime = 0; m_reversalBars = 0;
      m_reversalThreshold = 2;
      m_qualityScore = 0; m_confirmedTime = 0;
      m_lastFailedTime = 0; m_lastFailedLevel = 0;
      m_trendDir = 0;
      m_chochActive = false; m_chochScore = 0;
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

      // Detect current trend direction
      m_trendDir = DetectTrend(swings);

      switch (m_state)
      {
         case VPCHOCH_NONE:
         {
            // Bullish CHOCH: was downtrend, price breaks above last swing high
            if (m_trendDir == -1 && swings.HighCount() >= 1)
            {
               double swHigh = swings.LastSwingHigh();
               if (swHigh > 0 && !IsInCooldown(swHigh) && bid > swHigh + atrPrice * 0.03)
               {
                  m_state = VPCHOCH_PROBE;
                  m_chochLevel = swHigh;
                  m_bullishReversal = true;
                  m_reversalBars = 0;
                  break;
               }
            }
            // Bearish CHOCH: was uptrend, price breaks below last swing low
            if (m_trendDir == 1 && swings.LowCount() >= 1)
            {
               double swLow = swings.LastSwingLow();
               if (swLow > 0 && !IsInCooldown(swLow) && bid < swLow - atrPrice * 0.03)
               {
                  m_state = VPCHOCH_PROBE;
                  m_chochLevel = swLow;
                  m_bullishReversal = false;
                  m_reversalBars = 0;
               }
            }
            break;
         }
         case VPCHOCH_PROBE:
         {
            bool closedBeyond = m_bullishReversal
               ? (lastClose > m_chochLevel)
               : (lastClose < m_chochLevel);
            if (closedBeyond && isNewBar)
            {
               m_state = VPCHOCH_TESTING;
               m_reversalBars = 1;
            }
            else
            {
               bool failed = m_bullishReversal
                  ? (bid < m_chochLevel * 0.997)
                  : (bid > m_chochLevel * 1.003);
               if (failed) _Fail();
            }
            break;
         }
         case VPCHOCH_TESTING:
         {
            if (!isNewBar) break;
            bool closedBeyond = m_bullishReversal
               ? (lastClose > m_chochLevel)
               : (lastClose < m_chochLevel);
            if (closedBeyond)
               m_reversalBars++;
            else
            {
               double distBack = m_bullishReversal
                  ? (m_chochLevel - lastClose)
                  : (lastClose - m_chochLevel);
               if (distBack > atrPrice * 0.1) { _Fail(); break; }
               else m_reversalBars = 0;
            }
            if (m_reversalBars >= m_reversalThreshold)
            {
               m_qualityScore = ComputeReversalQuality(state, atrPrice);
               if (m_qualityScore >= 0.25) // minimal quality threshold
               {
                  m_state = VPCHOCH_CONFIRMED;
                  m_confirmedTime = TimeCurrent();
                  m_chochActive = true;
                  m_chochScore = m_qualityScore;
               }
               else
                  _Fail();
            }
            break;
         }
         case VPCHOCH_CONFIRMED:
         {
            // Invalidate if price reverses back significantly
            bool invalidated = m_bullishReversal
               ? (lastClose < m_chochLevel - atrPrice * 0.5)
               : (lastClose > m_chochLevel + atrPrice * 0.5);
            if (invalidated)
            {
               m_state = VPCHOCH_NONE;
               m_chochActive = false;
               m_chochScore = 0;
            }
            break;
         }
      }
   }

   void _Fail(void)
   {
      m_lastFailedTime = TimeCurrent();
      m_lastFailedLevel = m_chochLevel;
      m_state = VPCHOCH_NONE;
      m_chochActive = false;
      m_chochScore = 0;
   }

   // Accessors
   bool IsConfirmed(void) const { return m_state == VPCHOCH_CONFIRMED; }
   bool IsBullishReversal(void) const { return m_bullishReversal; }
   bool IsActive(void) const { return m_chochActive; }
   double Score(void) const { return m_chochScore; }
   double Level(void) const { return m_chochLevel; }
   int TrendDirection(void) const { return m_trendDir; }
   EVPCHOCHState State(void) const { return m_state; }
};

#endif
