#ifndef __EA_ROOT_ADAPTIVESWINGDETECTOR_MQH__
#define __EA_ROOT_ADAPTIVESWINGDETECTOR_MQH__

#include "..\Config\GlobalParameters.mqh"

class CAdaptiveSwingDetector : public CPipelineModuleBase
{
private:
  int m_lookback;

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "AdaptiveSwingDetector");
    m_lookback = 3;
  }

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);
    // Adapt lookback based on ATR: higher volatility = wider lookback
    double atr = state.marketData.atrProxy;
    double point = state.marketData.pointSize;
    if (point > 0 && atr > 0)
    {
      double atrPips = atr / point;
      if (atrPips > 100)
        m_lookback = 5;
      else if (atrPips > 50)
        m_lookback = 4;
      else
        m_lookback = 3;
    }
    // Write to shared state so SwingEngine can read it
    state.structure.adaptiveLookback = m_lookback;
    return true;
  }

  int AdaptiveLookback(void) const { return m_lookback; }
};

#endif
