#ifndef __VP_EA_SIMPLE_SWING_MQH__
#define __VP_EA_SIMPLE_SWING_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Simple Swing Detector — Pure Price Action                        |
//| Detects swing highs/lows from H1 rate data                      |
//| No VP/Auction dependency                                         |
//+------------------------------------------------------------------+

#define VP_MAX_SWINGS 20

struct SVPSwingPoint
{
   double   price;
   int      barIndex;
   datetime time;
};

class CSimpleSwingDetector : public CVPModuleBase
{
private:
   int m_lookback;  // bars on each side to confirm swing
   SVPSwingPoint m_swingHighs[VP_MAX_SWINGS];
   SVPSwingPoint m_swingLows[VP_MAX_SWINGS];
   int m_highCount;
   int m_lowCount;

   bool IsSwingHigh(const MqlRates &rates[], int idx, int n, int look)
   {
      if (idx < look || idx >= n - look) return false;
      double h = rates[idx].high;
      for (int i = 1; i <= look; i++)
      {
         if (rates[idx - i].high >= h) return false;
         if (rates[idx + i].high >= h) return false;
      }
      return true;
   }

   bool IsSwingLow(const MqlRates &rates[], int idx, int n, int look)
   {
      if (idx < look || idx >= n - look) return false;
      double l = rates[idx].low;
      for (int i = 1; i <= look; i++)
      {
         if (rates[idx - i].low <= l) return false;
         if (rates[idx + i].low <= l) return false;
      }
      return true;
   }

public:
   void Bootstrap(const string symbol, int lookback = 3)
   {
      Configure(symbol, "SimpleSwingDetector");
      m_lookback = lookback;
      m_highCount = 0;
      m_lowCount = 0;
   }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);
      int n = state.marketData.h1Copied;
      if (n < m_lookback * 2 + 3) return true;

      m_highCount = 0;
      m_lowCount = 0;

      // Scan H1 bars (skip last m_lookback bars — not confirmed yet)
      int scanEnd = n - m_lookback;
      int scanStart = MathMax(m_lookback, n - 60); // last 60 bars

      for (int i = scanStart; i < scanEnd; i++)
      {
         if (IsSwingHigh(state.marketData.h1Rates, i, n, m_lookback))
         {
            if (m_highCount < VP_MAX_SWINGS)
            {
               m_swingHighs[m_highCount].price = state.marketData.h1Rates[i].high;
               m_swingHighs[m_highCount].barIndex = i;
               m_swingHighs[m_highCount].time = state.marketData.h1Rates[i].time;
               m_highCount++;
            }
         }
         if (IsSwingLow(state.marketData.h1Rates, i, n, m_lookback))
         {
            if (m_lowCount < VP_MAX_SWINGS)
            {
               m_swingLows[m_lowCount].price = state.marketData.h1Rates[i].low;
               m_swingLows[m_lowCount].barIndex = i;
               m_swingLows[m_lowCount].time = state.marketData.h1Rates[i].time;
               m_lowCount++;
            }
         }
      }
      return true;
   }

   int HighCount(void) const { return m_highCount; }
   int LowCount(void) const { return m_lowCount; }
   SVPSwingPoint GetSwingHigh(int idx) const { return m_swingHighs[idx]; }
   SVPSwingPoint GetSwingLow(int idx) const { return m_swingLows[idx]; }
   double LastSwingHigh(void) const { return m_highCount > 0 ? m_swingHighs[m_highCount-1].price : 0; }
   double LastSwingLow(void) const { return m_lowCount > 0 ? m_swingLows[m_lowCount-1].price : 0; }
};

#endif
