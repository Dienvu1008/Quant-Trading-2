#ifndef __VP_EA_SPREADMONITOR_MQH__
#define __VP_EA_SPREADMONITOR_MQH__

#include "..\Config\GlobalParameters.mqh"

#define SPREAD_HISTORY_SIZE 100

class CVPSpreadMonitor : public CVPModuleBase
{
private:
   double m_history[SPREAD_HISTORY_SIZE];
   int    m_histCount;
   int    m_histIdx;
   double m_avgSpread;

public:
   void Bootstrap(const string symbol)
   {
      Configure(symbol, "SpreadMonitor");
      ArrayInitialize(m_history, 0);
      m_histCount = 0;
      m_histIdx = 0;
      m_avgSpread = 0;
   }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);
      double spread = state.marketData.spreadPoints;

      m_history[m_histIdx] = spread;
      m_histIdx = (m_histIdx + 1) % SPREAD_HISTORY_SIZE;
      if (m_histCount < SPREAD_HISTORY_SIZE) m_histCount++;

      double sum = 0;
      for (int i = 0; i < m_histCount; i++) sum += m_history[i];
      m_avgSpread = (m_histCount > 0) ? sum / m_histCount : spread;

      state.marketData.avgSpreadPoints = m_avgSpread;
      return true;
   }

   double GetAvgSpread(void) const { return m_avgSpread; }
};

#endif
