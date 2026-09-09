#ifndef __VP_EA_BEHAVIOR_PROFILER_MQH__
#define __VP_EA_BEHAVIOR_PROFILER_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| VP Behavior Profiler — Per-Symbol Adaptive                       |
//| Tracks rolling stats of VP/Auction outputs to classify symbol    |
//| archetype and expose percentile-based interpretation             |
//+------------------------------------------------------------------+

#define VPP_WINDOW 200  // rolling window (H1 bars sampled)

class CVPBehaviorProfiler : public CVPModuleBase
{
private:
   // Rolling buffers
   double m_migrationBuf[VPP_WINDOW];
   double m_balanceBuf[VPP_WINDOW];
   double m_tradeQualityBuf[VPP_WINDOW];
   double m_continuationBuf[VPP_WINDOW];
   double m_devPOCAbsBuf[VPP_WINDOW];
   double m_thinnessRatioBuf[VPP_WINDOW];
   int    m_regimeCounts[9];         // time-in-regime distribution
   int    m_overlapBiasCounts[3];    // [0]=neutral, [1]=bull, [2]=bear
   int    m_writeIdx;
   int    m_sampleCount;
   int    m_warmupTarget;
   datetime m_lastSampleBar;

   // Computed stats
   double m_migMean, m_migP25, m_migP75;
   double m_balMean, m_balP25, m_balP75;
   double m_tqMean;
   double m_thinnMean;
   EVPSymbolArchetype m_archetype;

   double GetPercentile(const double &buf[], int count, double pct)
   {
      if (count < 5) return 0.5;
      double sorted[];
      ArrayResize(sorted, count);
      for (int i = 0; i < count; i++) sorted[i] = buf[i];
      ArraySort(sorted);
      int idx = (int)(count * pct);
      if (idx >= count) idx = count - 1;
      return sorted[idx];
   }

   double GetMean(const double &buf[], int count)
   {
      if (count <= 0) return 0;
      double sum = 0;
      for (int i = 0; i < count; i++) sum += buf[i];
      return sum / count;
   }

   void RecomputeStats(void)
   {
      int n = MathMin(m_sampleCount, VPP_WINDOW);
      m_migMean = GetMean(m_migrationBuf, n);
      m_migP25 = GetPercentile(m_migrationBuf, n, 0.25);
      m_migP75 = GetPercentile(m_migrationBuf, n, 0.75);
      m_balMean = GetMean(m_balanceBuf, n);
      m_balP25 = GetPercentile(m_balanceBuf, n, 0.25);
      m_balP75 = GetPercentile(m_balanceBuf, n, 0.75);
      m_tqMean = GetMean(m_tradeQualityBuf, n);
      m_thinnMean = GetMean(m_thinnessRatioBuf, n);

      // Classify archetype
      ClassifyArchetype();
   }

   void ClassifyArchetype(void)
   {
      // Find dominant regime
      int maxRegime = 0, maxCount = 0;
      int total = 0;
      for (int i = 0; i < 9; i++) { total += m_regimeCounts[i]; if (m_regimeCounts[i] > maxCount) { maxCount = m_regimeCounts[i]; maxRegime = i; } }

      double trendPct = (total > 0) ? (double)(m_regimeCounts[REGIME_TREND_INITIATION] + m_regimeCounts[REGIME_TREND_CONTINUATION]) / total : 0;
      double rangePct = (total > 0) ? (double)(m_regimeCounts[REGIME_BALANCED_ROTATION] + m_regimeCounts[REGIME_COMPRESSION]) / total : 0;
      double chaoticPct = (total > 0) ? (double)(m_regimeCounts[REGIME_CHAOTIC] + m_regimeCounts[REGIME_EXCESS]) / total : 0;

      if (m_tqMean < 0.25)
         m_archetype = VP_ARCH_SPREAD_UNSTABLE;
      else if (chaoticPct > 0.25 || (m_migP75 - m_migP25) > 0.5)
         m_archetype = VP_ARCH_VOLATILE_SWITCHING;
      else if (trendPct > 0.45 && m_migMean > 0.35)
         m_archetype = VP_ARCH_TREND_FRIENDLY;
      else if (rangePct > 0.45 && m_balMean > 0.50)
         m_archetype = VP_ARCH_RANGE_BOUND;
      else
         m_archetype = VP_ARCH_UNKNOWN;
   }

public:
   void Bootstrap(const string symbol, int warmup = 100)
   {
      Configure(symbol, "VPBehaviorProfiler");
      ArrayInitialize(m_migrationBuf, 0);
      ArrayInitialize(m_balanceBuf, 0);
      ArrayInitialize(m_tradeQualityBuf, 0);
      ArrayInitialize(m_continuationBuf, 0);
      ArrayInitialize(m_devPOCAbsBuf, 0);
      ArrayInitialize(m_thinnessRatioBuf, 0);
      ArrayInitialize(m_regimeCounts, 0);
      ArrayInitialize(m_overlapBiasCounts, 0);
      m_writeIdx = 0;
      m_sampleCount = 0;
      m_warmupTarget = warmup;
      m_lastSampleBar = 0;
      m_archetype = VP_ARCH_UNKNOWN;
      m_migMean = 0; m_migP25 = 0; m_migP75 = 0;
      m_balMean = 0; m_balP25 = 0; m_balP75 = 0;
      m_tqMean = 0; m_thinnMean = 0;
   }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);
      if (!state.vpValid) return true;

      // Sample once per H1 bar
      datetime barH1 = iTime(m_symbol, PERIOD_H1, 0);
      if (barH1 == m_lastSampleBar) 
      {
         // Still write profiler output even if not sampling
         WriteOutput(state);
         return true;
      }
      m_lastSampleBar = barH1;

      // Record sample
      m_migrationBuf[m_writeIdx] = state.vpMigrationConfidence;
      m_balanceBuf[m_writeIdx] = state.auctBalanceScore;
      m_tradeQualityBuf[m_writeIdx] = state.auctTradeQuality;
      m_continuationBuf[m_writeIdx] = state.auctContinuationScore;
      m_devPOCAbsBuf[m_writeIdx] = MathAbs(state.vpDevPOCDirection);
      m_thinnessRatioBuf[m_writeIdx] = state.vpThinnessRatio;
      m_writeIdx = (m_writeIdx + 1) % VPP_WINDOW;
      m_sampleCount++;

      // Track regime distribution
      int reg = state.auctRegime;
      if (reg >= 0 && reg < 9) m_regimeCounts[reg]++;

      // Track VA overlap bias
      int bias = state.vpVAOverlapBias;
      if (bias == 0) m_overlapBiasCounts[0]++;
      else if (bias > 0) m_overlapBiasCounts[1]++;
      else m_overlapBiasCounts[2]++;

      // Recompute stats every 10 samples
      if (m_sampleCount % 10 == 0)
         RecomputeStats();

      WriteOutput(state);
      return true;
   }

   void WriteOutput(SVPPipelineState &state)
   {
      state.profiler.archetype = m_archetype;
      state.profiler.migrationP25 = m_migP25;
      state.profiler.migrationP75 = m_migP75;
      state.profiler.migrationMean = m_migMean;
      state.profiler.balanceP25 = m_balP25;
      state.profiler.balanceP75 = m_balP75;
      state.profiler.balanceMean = m_balMean;
      state.profiler.tradeQualityMean = m_tqMean;
      state.profiler.thinnessRatioMean = m_thinnMean;
      state.profiler.samplesCollected = m_sampleCount;
      state.profiler.isReady = (m_sampleCount >= m_warmupTarget);
   }

   bool IsReady(void) const { return m_sampleCount >= m_warmupTarget; }
   int SamplesCollected(void) const { return m_sampleCount; }
   EVPSymbolArchetype GetArchetype(void) const { return m_archetype; }
};

#endif
