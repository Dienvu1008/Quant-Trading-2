#ifndef __EA_ROOT_CVDPROXYENGINE_MQH__
#define __EA_ROOT_CVDPROXYENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

// Cumulative Volume Delta proxy using a 60-bar M1 sliding window.
// CVD increments as each new M1 bar closes: adds new bar's delta, drops oldest.
// Snapshots written to state.flow.cvdHistory[] for DivergenceEngine.

class CCVDProxyEngine : public CPipelineModuleBase
  {
private:
   double   m_barDeltas[60];  // circular buffer of per-M1-bar delta values
   int      m_bufHead;        // next write index in circular buffer
   int      m_bufSize;        // valid entries (0..60)
   double   m_runningCVD;     // sum of all deltas in buffer
   datetime m_lastBarTime;    // time of last processed M1 bar (dedup guard)

   double   m_snapshots[30];  // circular buffer of CVD snapshots (one per new bar)
   int      m_snapHead;
   int      m_snapSize;

   void AddBarDelta(double barDelta)
     {
      // Sliding window: remove oldest when buffer is full
      if(m_bufSize >= 60)
         m_runningCVD -= m_barDeltas[m_bufHead];
      else
         m_bufSize++;
      m_barDeltas[m_bufHead] = barDelta;
      m_runningCVD += barDelta;
      m_bufHead = (m_bufHead + 1) % 60;
      // Snapshot for divergence history
      m_snapshots[m_snapHead] = m_runningCVD;
      m_snapHead = (m_snapHead + 1) % 30;
      if(m_snapSize < 30) m_snapSize++;
     }

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol,"CVDProxyEngine");
      m_bufHead = 0; m_bufSize = 0; m_runningCVD = 0;
      m_lastBarTime = 0;
      m_snapHead = 0; m_snapSize = 0;
      ArrayInitialize(m_barDeltas,0);
      ArrayInitialize(m_snapshots,0);
     }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      int m1Count = state.marketData.m1Copied;
      if(m1Count < 2) return true;

      if(m_lastBarTime == 0)
        {
         // First run: seed buffer from all available M1 bars
         int startBar = MathMax(0, m1Count - 60);
         for(int i = startBar; i < m1Count; i++)
           {
            double vol = (double)state.marketData.m1Rates[i].tick_volume;
            double bd  = (state.marketData.m1Rates[i].close > state.marketData.m1Rates[i].open) ?  vol :
                         (state.marketData.m1Rates[i].close < state.marketData.m1Rates[i].open) ? -vol : 0;
            AddBarDelta(bd);
           }
         m_lastBarTime = state.marketData.m1Rates[m1Count-1].time;
        }
      else if(state.marketData.m1Rates[m1Count-1].time > m_lastBarTime)
        {
         // Incremental: only process bars newer than m_lastBarTime
         for(int i = 0; i < m1Count; i++)
           {
            if(state.marketData.m1Rates[i].time <= m_lastBarTime) continue;
            double vol = (double)state.marketData.m1Rates[i].tick_volume;
            double bd  = (state.marketData.m1Rates[i].close > state.marketData.m1Rates[i].open) ?  vol :
                         (state.marketData.m1Rates[i].close < state.marketData.m1Rates[i].open) ? -vol : 0;
            AddBarDelta(bd);
           }
         m_lastBarTime = state.marketData.m1Rates[m1Count-1].time;
        }

      // Normalize CVD to 0..1 relative to its snapshot history
      double cvdMA = 0;
      for(int i = 0; i < m_snapSize; i++) cvdMA += m_snapshots[i];
      if(m_snapSize > 0) cvdMA /= m_snapSize;
      double scale = MathAbs(cvdMA) + 1.0;
      state.flow.cvdProxy = Clamp01((m_runningCVD - cvdMA) / (scale * 2.0) + 0.5);

      // Write snapshot history to state (oldest first) for DivergenceEngine
      int oldest = (m_snapHead - m_snapSize + 300) % 30;
      for(int i = 0; i < m_snapSize; i++)
         state.flow.cvdHistory[i] = m_snapshots[(oldest + i) % 30];
      state.flow.cvdHistCount = m_snapSize;
      return true;
     }

   double CVD(void) const { return m_runningCVD; }
  };

#endif

