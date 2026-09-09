#ifndef __EA_ROOT_TICKIMBALANCEENGINE_MQH__
#define __EA_ROOT_TICKIMBALANCEENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

class CTickImbalanceEngine : public CPipelineModuleBase
{
private:
  double m_imbalance;

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "TickImbalanceEngine");
    m_imbalance = 0.5;
  }

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);
    int count = state.marketData.tickCopied;
    if (count < 10)
    {
      state.microstructure.tickImbalance = 0.5;
      return true;
    }

    int ups = 0, downs = 0;
    for (int i = 1; i < count; i++)
    {
      if (state.marketData.ticks[i].bid > state.marketData.ticks[i - 1].bid)
        ups++;
      else if (state.marketData.ticks[i].bid < state.marketData.ticks[i - 1].bid)
        downs++;
    }

    int total = ups + downs;
    m_imbalance = (total > 0) ? (double)ups / (double)total : 0.5;
    state.microstructure.tickImbalance = m_imbalance;
    return true;
  }

  double Imbalance(void) const { return m_imbalance; }
  bool BullishImbalance(void) const { return m_imbalance > 0.6; }
  bool BearishImbalance(void) const { return m_imbalance < 0.4; }
};

#endif
