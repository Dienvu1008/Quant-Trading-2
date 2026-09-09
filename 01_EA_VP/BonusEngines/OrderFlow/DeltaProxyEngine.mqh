#ifndef __EA_ROOT_DELTAPROXYENGINE_MQH__
#define __EA_ROOT_DELTAPROXYENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

class CDeltaProxyEngine : public CPipelineModuleBase
  {
private:
   double m_delta;
   double m_buyVolume;
   double m_sellVolume;

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol,"DeltaProxyEngine");
      m_delta = 0; m_buyVolume = 0; m_sellVolume = 0;
     }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      // Use shared M1 rates from RatesCache (no redundant CopyRates)
      int m1Count = state.marketData.m1Copied;
      if(m1Count < 5) return true;

      int startIdx = MathMax(0, m1Count - 20);  // last 20 M1 bars
      m_buyVolume = 0; m_sellVolume = 0;
      for(int i = startIdx; i < m1Count; i++)
        {
         double vol = (double)state.marketData.m1Rates[i].tick_volume;
         if(state.marketData.m1Rates[i].close > state.marketData.m1Rates[i].open)
            m_buyVolume += vol;
         else if(state.marketData.m1Rates[i].close < state.marketData.m1Rates[i].open)
            m_sellVolume += vol;
         else
           { m_buyVolume += vol * 0.5; m_sellVolume += vol * 0.5; }
        }

      double total = m_buyVolume + m_sellVolume;
      m_delta = (total > 0) ? (m_buyVolume - m_sellVolume) / total : 0;
      double rawDelta = (m_delta + 1.0) / 2.0;  // [0,1] where 0.5=neutral

      state.flow.deltaProxy = Clamp01(rawDelta);
      return true;
     }

   double Delta(void) const { return m_delta; }
   double BuyVolume(void) const { return m_buyVolume; }
   double SellVolume(void) const { return m_sellVolume; }
  };

#endif

