#ifndef __VP_EA_RATESCACHE_MQH__
#define __VP_EA_RATESCACHE_MQH__

#include "..\Config\GlobalParameters.mqh"

class CVPRatesCache : public CVPModuleBase
{
private:
   MqlRates m_ratesM1[];
   MqlRates m_ratesM5[];
   MqlRates m_ratesH1[];
   MqlRates m_ratesH4[];
   MqlRates m_ratesD1[];
   int m_barsM1, m_barsM5, m_barsH1, m_barsH4, m_barsD1;
   datetime m_lastBarM5, m_lastBarH1, m_lastBarH4, m_lastBarD1;

public:
   void Bootstrap(const string symbol)
   {
      Configure(symbol, "RatesCache");
      m_barsM1 = 0; m_barsM5 = 0; m_barsH1 = 0; m_barsH4 = 0; m_barsD1 = 0;
      m_lastBarM5 = 0; m_lastBarH1 = 0; m_lastBarH4 = 0; m_lastBarD1 = 0;
   }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);
      m_barsM1 = CopyRates(m_symbol, PERIOD_M1, 0, 240, m_ratesM1);

      datetime barM5 = iTime(m_symbol, PERIOD_M5, 0);
      if (barM5 != m_lastBarM5 || m_barsM5 == 0)
      { m_barsM5 = CopyRates(m_symbol, PERIOD_M5, 0, 200, m_ratesM5); m_lastBarM5 = barM5; }

      datetime barH1 = iTime(m_symbol, PERIOD_H1, 0);
      if (barH1 != m_lastBarH1 || m_barsH1 == 0)
      { m_barsH1 = CopyRates(m_symbol, PERIOD_H1, 0, 100, m_ratesH1); m_lastBarH1 = barH1; }

      datetime barH4 = iTime(m_symbol, PERIOD_H4, 0);
      if (barH4 != m_lastBarH4 || m_barsH4 == 0)
      { m_barsH4 = CopyRates(m_symbol, PERIOD_H4, 0, 50, m_ratesH4); m_lastBarH4 = barH4; }

      datetime barD1 = iTime(m_symbol, PERIOD_D1, 0);
      if (barD1 != m_lastBarD1 || m_barsD1 == 0)
      { m_barsD1 = CopyRates(m_symbol, PERIOD_D1, 0, 30, m_ratesD1); m_lastBarD1 = barD1; }

      if (m_barsH1 > 0)
      { ArrayResize(state.marketData.h1Rates, m_barsH1); ArrayCopy(state.marketData.h1Rates, m_ratesH1, 0, 0, m_barsH1); state.marketData.h1Copied = m_barsH1; }
      if (m_barsM5 > 0)
      { int s = MathMin(m_barsM5, 30); ArrayResize(state.marketData.m5Rates, s); ArrayCopy(state.marketData.m5Rates, m_ratesM5, 0, m_barsM5 - s, s); state.marketData.m5Copied = s; }
      if (m_barsM1 > 0)
      { int s = MathMin(m_barsM1, 60); ArrayResize(state.marketData.m1Rates, s); ArrayCopy(state.marketData.m1Rates, m_ratesM1, 0, m_barsM1 - s, s); state.marketData.m1Copied = s; }
      if (m_barsH4 > 0)
      { ArrayResize(state.marketData.h4Rates, m_barsH4); ArrayCopy(state.marketData.h4Rates, m_ratesH4, 0, 0, m_barsH4); state.marketData.h4Copied = m_barsH4; }
      if (m_barsD1 > 0)
      { ArrayResize(state.marketData.d1Rates, m_barsD1); ArrayCopy(state.marketData.d1Rates, m_ratesD1, 0, 0, m_barsD1); state.marketData.d1Copied = m_barsD1; }

      return (m_barsM1 > 0);
   }

   int BarsH1(void) const { return m_barsH1; }
   int BarsM1(void) const { return m_barsM1; }
};

#endif
