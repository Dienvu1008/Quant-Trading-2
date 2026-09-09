#ifndef __VP_EA_TICKCACHE_MQH__
#define __VP_EA_TICKCACHE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| VP Tick Cache — populates shared tick buffer once per tick.      |
//| Downstream microstructure engines (TickImbalance, TickVelocity)  |
//| read state.marketData.ticks[] / tickCopied instead of calling    |
//| CopyTicks themselves.                                            |
//+------------------------------------------------------------------+
class CVPTickCache : public CVPModuleBase
{
private:
   MqlTick m_ticks[];
   MqlTick m_lastTick;
   int     m_tickCount;
   double  m_avgTicksPerSecond;
   datetime m_lastSampleTime;

public:
   void Bootstrap(const string symbol)
   {
      Configure(symbol, "TickCache");
      m_tickCount = 0;
      m_avgTicksPerSecond = 0.0;
      m_lastSampleTime = 0;
      ZeroMemory(m_lastTick);
   }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);
      if (!SymbolInfoTick(m_symbol, m_lastTick))
         return false;

      m_tickCount = CopyTicks(m_symbol, m_ticks, COPY_TICKS_ALL, 0, 500);
      if (m_tickCount > 1)
      {
         long timeDiffMs = m_ticks[m_tickCount - 1].time_msc - m_ticks[0].time_msc;
         if (timeDiffMs > 0)
            m_avgTicksPerSecond = (double)m_tickCount / ((double)timeDiffMs / 1000.0);
      }

      // Populate shared tick cache in state — downstream engines read from here
      if (m_tickCount > 0)
      {
         ArrayResize(state.marketData.ticks, m_tickCount);
         ArrayCopy(state.marketData.ticks, m_ticks, 0, 0, m_tickCount);
      }
      state.marketData.tickCopied = (m_tickCount > 0) ? m_tickCount : 0;

      m_lastSampleTime = TimeCurrent();
      return true;
   }

   MqlTick LastTick(void) const { return m_lastTick; }
   int TickCount(void) const { return m_tickCount; }
   double AvgTicksPerSecond(void) const { return m_avgTicksPerSecond; }

   int CountUpTicks(void) const
   {
      int ups = 0;
      for (int i = 1; i < m_tickCount; i++)
         if (m_ticks[i].last > m_ticks[i - 1].last)
            ups++;
      return ups;
   }

   int CountDownTicks(void) const
   {
      int downs = 0;
      for (int i = 1; i < m_tickCount; i++)
         if (m_ticks[i].last < m_ticks[i - 1].last)
            downs++;
      return downs;
   }
};

#endif
