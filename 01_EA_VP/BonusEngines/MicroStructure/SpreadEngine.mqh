#ifndef __EA_ROOT_SPREADENGINE_MQH__
#define __EA_ROOT_SPREADENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

class CSpreadEngine : public CPipelineModuleBase
{
private:
  double m_spreadHistory[100]; // circular buffer of recent spreadPct values
  int m_histWritePos;          // next write position (0..99)
  int m_histCount;             // total samples written (used to compute window size)
  double m_spreadPercentile;
  double m_spreadVelocity;
  double m_prevSpread;

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "SpreadEngine");
    ArrayInitialize(m_spreadHistory, 0.0);
    m_histWritePos = 0;
    m_histCount = 0;
    m_spreadPercentile = 0.5;
    m_spreadVelocity = 0;
    m_prevSpread = 0;
  }

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);
    double currentSpread = state.marketData.spreadPoints;
    m_spreadVelocity = currentSpread - m_prevSpread;
    m_prevSpread = currentSpread;

    // Price-relative spread (instrument-independent)
    double spreadPct = (state.marketData.bid > 0.0)
                           ? (currentSpread * state.marketData.pointSize / state.marketData.bid)
                           : 0.005;

    // Push into circular buffer
    m_spreadHistory[m_histWritePos] = spreadPct;
    m_histWritePos = (m_histWritePos + 1) % 100;
    m_histCount++;

    // Compute actual percentile rank: fraction of history <= current
    int n = (m_histCount < 100) ? m_histCount : 100;
    int lessOrEqual = 0;
    for (int i = 0; i < n; i++)
      if (m_spreadHistory[i] <= spreadPct)
        lessOrEqual++;

    // percentile=1 means current spread is the worst ever seen → score=0
    // percentile=0 means spread is tightest ever → score=1
    m_spreadPercentile = 1.0 - ((double)lessOrEqual / (double)n);
    state.microstructure.spreadScore = m_spreadPercentile;
    return true;
  }

  double SpreadPercentile(void) const { return m_spreadPercentile; }
  double SpreadVelocity(void) const { return m_spreadVelocity; }
};

#endif
