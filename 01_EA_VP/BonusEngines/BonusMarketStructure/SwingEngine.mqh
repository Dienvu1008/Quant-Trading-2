#ifndef __EA_ROOT_SWINGENGINE_MQH__
#define __EA_ROOT_SWINGENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

// SSwingPoint is now defined in GlobalParameters.mqh

class CSwingEngine : public CPipelineModuleBase
  {
private:
   SSwingPoint m_swingHighs[];
   SSwingPoint m_swingLows[];
   int m_maxSwings;        // max kept (purge oldest beyond this)
   datetime m_lastBarTime; // track last fully-analyzed bar to avoid re-work

   // Check if a swing at this price/time already exists in the array
   bool IsDuplicate(const SSwingPoint &arr[], int count, double price, datetime t)
     {
      for(int i = count-1; i >= MathMax(0, count-5); i--) // only check recent 5
         if(arr[i].time == t && MathAbs(arr[i].price - price) < 0.0001)
            return true;
      return false;
     }

   // Purge swings older than maxAge bars (measured by barIndex from current)
   void PurgeOld(SSwingPoint &arr[], int copied)
     {
      int write = 0;
      int size = ArraySize(arr);
      for(int i = 0; i < size; i++)
        {
         // Keep if within last 200 bars relative to current dataset
         if(arr[i].barIndex >= 0)
            arr[write++] = arr[i];
        }
      ArrayResize(arr, write);
     }

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol,"SwingEngine");
      m_maxSwings = 30;
      m_lastBarTime = 0;
      ArrayResize(m_swingHighs, 0);
      ArrayResize(m_swingLows, 0);
     }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // Read H1 rates from shared cache (populated by RatesCache)
      int copied = state.marketData.h1Copied;
      if(copied < 20) return false;

      // Adaptive lookback from AdaptiveSwingDetector (written to state before us)
      int lookback = state.structure.adaptiveLookback;
      if(lookback < 2) lookback = 2;
      if(lookback > 5) lookback = 5;

      // ATR threshold for minimum swing significance
      double atrThreshold = state.marketData.atrProxy * 0.3;
      if(atrThreshold <= 0) atrThreshold = 0.0001;

      // Only process new bars since last run to avoid full re-scan
      datetime currentBarTime = state.marketData.h1Rates[copied-1].time;
      bool fullScan = (m_lastBarTime == 0 || ArraySize(m_swingHighs) == 0);

      int startBar = lookback;
      if(!fullScan)
        {
         // Find the index of the last bar we analyzed
         for(int i = copied-1; i >= lookback; i--)
           {
            if(state.marketData.h1Rates[i].time <= m_lastBarTime)
              { startBar = i + 1; break; }
           }
         if(startBar < lookback) startBar = lookback;
        }

      // Scan for new swing points (only confirmed swings — need bars on both sides)
      for(int i = startBar; i < copied - lookback; i++)
        {
         // --- Swing High detection ---
         bool isSwingHigh = true;
         for(int j = 1; j <= lookback; j++)
           {
            if(state.marketData.h1Rates[i].high <= state.marketData.h1Rates[i-j].high ||
               state.marketData.h1Rates[i].high <= state.marketData.h1Rates[i+j].high)
              { isSwingHigh = false; break; }
           }
         if(isSwingHigh)
           {
            double price = state.marketData.h1Rates[i].high;
            datetime t   = state.marketData.h1Rates[i].time;
            int hiCount  = ArraySize(m_swingHighs);
            // Dedup + minimum ATR distance from last swing
            if(!IsDuplicate(m_swingHighs, hiCount, price, t) &&
               (hiCount == 0 || MathAbs(price - m_swingHighs[hiCount-1].price) > atrThreshold))
              {
               ArrayResize(m_swingHighs, hiCount+1);
               m_swingHighs[hiCount].price    = price;
               m_swingHighs[hiCount].time     = t;
               m_swingHighs[hiCount].barIndex = i;
               m_swingHighs[hiCount].isHigh   = true;
              }
           }

         // --- Swing Low detection ---
         bool isSwingLow = true;
         for(int j = 1; j <= lookback; j++)
           {
            if(state.marketData.h1Rates[i].low >= state.marketData.h1Rates[i-j].low ||
               state.marketData.h1Rates[i].low >= state.marketData.h1Rates[i+j].low)
              { isSwingLow = false; break; }
           }
         if(isSwingLow)
           {
            double price = state.marketData.h1Rates[i].low;
            datetime t   = state.marketData.h1Rates[i].time;
            int loCount  = ArraySize(m_swingLows);
            if(!IsDuplicate(m_swingLows, loCount, price, t) &&
               (loCount == 0 || MathAbs(price - m_swingLows[loCount-1].price) > atrThreshold))
              {
               ArrayResize(m_swingLows, loCount+1);
               m_swingLows[loCount].price    = price;
               m_swingLows[loCount].time     = t;
               m_swingLows[loCount].barIndex = i;
               m_swingLows[loCount].isHigh   = false;
              }
           }
        }

      m_lastBarTime = currentBarTime;

      // Cap arrays to m_maxSwings (keep most recent)
      if(ArraySize(m_swingHighs) > m_maxSwings)
        {
         int excess = ArraySize(m_swingHighs) - m_maxSwings;
         ArrayCopy(m_swingHighs, m_swingHighs, 0, excess);
         ArrayResize(m_swingHighs, m_maxSwings);
        }
      if(ArraySize(m_swingLows) > m_maxSwings)
        {
         int excess = ArraySize(m_swingLows) - m_maxSwings;
         ArrayCopy(m_swingLows, m_swingLows, 0, excess);
         ArrayResize(m_swingLows, m_maxSwings);
        }

      // Write swing data to shared state for downstream modules
      int hiCount = MathMin(ArraySize(m_swingHighs), 30);
      int loCount = MathMin(ArraySize(m_swingLows), 30);
      for(int i = 0; i < hiCount; i++) state.structure.swingHighs[i] = m_swingHighs[ArraySize(m_swingHighs)-hiCount+i];
      for(int i = 0; i < loCount; i++) state.structure.swingLows[i]  = m_swingLows[ArraySize(m_swingLows)-loCount+i];
      state.structure.swingHighCount = hiCount;
      state.structure.swingLowCount  = loCount;

      int totalSwings = ArraySize(m_swingHighs) + ArraySize(m_swingLows);
      state.structure.swingStrength = Clamp01((double)totalSwings / 20.0);
      return true;
     }

   int SwingHighCount(void) const { return ArraySize(m_swingHighs); }
   int SwingLowCount(void)  const { return ArraySize(m_swingLows); }

   bool LastSwingHigh(SSwingPoint &point) const
     {
      int s = ArraySize(m_swingHighs);
      if(s == 0) return false;
      point = m_swingHighs[s-1];
      return true;
     }

   bool LastSwingLow(SSwingPoint &point) const
     {
      int s = ArraySize(m_swingLows);
      if(s == 0) return false;
      point = m_swingLows[s-1];
      return true;
     }

   bool PrevSwingHigh(SSwingPoint &point) const
     {
      int s = ArraySize(m_swingHighs);
      if(s < 2) return false;
      point = m_swingHighs[s-2];
      return true;
     }

   bool PrevSwingLow(SSwingPoint &point) const
     {
      int s = ArraySize(m_swingLows);
      if(s < 2) return false;
      point = m_swingLows[s-2];
      return true;
     }

   bool IsUptrend(void) const
     {
      int s = ArraySize(m_swingHighs);
      if(s < 2) return false;
      return m_swingHighs[s-1].price > m_swingHighs[s-2].price;
     }
  };

#endif


