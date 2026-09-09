#ifndef __EA_ROOT_TICKVELOCITYENGINE_MQH__
#define __EA_ROOT_TICKVELOCITYENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

class CTickVelocityEngine : public CPipelineModuleBase
{
private:
  double m_tickVelocity;
  double m_tickAcceleration;
  double m_prevVelocity;

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "TickVelocityEngine");
    m_tickVelocity = 0;
    m_tickAcceleration = 0;
    m_prevVelocity = 0;
  }

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);
    int count = state.marketData.tickCopied;
    if (count < 2)
    {
      state.microstructure.tickVelocity = 0.0;
      return true;
    }

    // Time-windowed velocity: count ticks in last 10s and 60s from cached data
    long nowMs = state.marketData.ticks[count - 1].time_msc;
    long t10Ms = nowMs - 10000; // 10 seconds ago
    long t60Ms = nowMs - 60000; // 60 seconds ago

    int count10s = 0, count60s = 0;
    for (int i = count - 1; i >= 0; i--)
    {
      long t = state.marketData.ticks[i].time_msc;
      if (t < t60Ms)
        break;
      count60s++;
      if (t >= t10Ms)
        count10s++;
    }

    double vel10s = count10s / 10.0; // ticks/sec in last 10s
    double vel60s = count60s / 60.0; // baseline ticks/sec over last 60s

    m_tickVelocity = vel10s;
    m_tickAcceleration = m_tickVelocity - m_prevVelocity;
    m_prevVelocity = m_tickVelocity;

    // Relative score: 1.0 = current short-window pace equals 60s baseline
    // >1.0 clamped to 1.0 = acceleration burst; <1.0 = slowing down
    double score = (vel60s > 0.0) ? MathMin(1.0, vel10s / vel60s) : 0.0;
    state.microstructure.tickVelocity = score;
    return true;
  }

  double TickVelocity(void) const { return m_tickVelocity; }
  double TickAcceleration(void) const { return m_tickAcceleration; }
};

#endif
