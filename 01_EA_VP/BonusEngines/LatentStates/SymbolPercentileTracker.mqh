#ifndef __EA_ROOT_SYMBOLPERCENTILETRACKER_MQH__
#define __EA_ROOT_SYMBOLPERCENTILETRACKER_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Symbol Percentile Tracker                                         |
//| Maintains rolling history of latent state values per symbol and   |
//| converts raw values to percentile ranks (0..1).                   |
//|                                                                   |
//| WHY: Different symbols have vastly different typical score ranges |
//| after sigmoid compression. A threshold of 0.72 may be common for |
//| EURUSD but nearly impossible for GBPJPY. Percentile normalization |
//| makes thresholds mean "top X% for THIS symbol" — self-adapting.  |
//|                                                                   |
//| HOW: Ring buffer of last N observations per state. Percentile =  |
//| fraction of stored values <= current value. O(N) per call.        |
//+------------------------------------------------------------------+

#define PERCENTILE_STATES 8   // dir, exp, participation, rev, meanRev, execQ, stability, volRegime
#define PERCENTILE_DEFAULT_WINDOW 500
#define PERCENTILE_DEFAULT_WARMUP 100

class CSymbolPercentileTracker
  {
private:
   int    m_windowSize;       // max observations to retain
   int    m_warmupSize;       // min observations before normalization activates
   double m_buffer[];         // flat array: [state0[0..window-1], state1[0..window-1], ...]
   int    m_count;            // total observations recorded (capped at windowSize)
   int    m_writeIdx;         // next write position in ring (0..windowSize-1)
   bool   m_warmedUp;         // true once count >= warmupSize

   // Get buffer offset for state s, index i
   int    Offset(int s, int i) const { return s * m_windowSize + i; }

   // Compute percentile rank of value within stored values for state s
   double ComputePercentile(int s, double value) const
     {
      int n = MathMin(m_count, m_windowSize);
      if(n == 0) return value;  // fallback: return raw

      int countBelow = 0;
      int countEqual = 0;
      int baseOffset = s * m_windowSize;
      for(int i = 0; i < n; i++)
        {
         double stored = m_buffer[baseOffset + i];
         if(stored < value)
            countBelow++;
         else if(stored == value)
            countEqual++;
        }
      // Percentile: midpoint of ties
      return (countBelow + countEqual * 0.5) / (double)n;
     }

public:
   CSymbolPercentileTracker(void)
     {
      m_windowSize = PERCENTILE_DEFAULT_WINDOW;
      m_warmupSize = PERCENTILE_DEFAULT_WARMUP;
      m_count      = 0;
      m_writeIdx   = 0;
      m_warmedUp   = false;
     }

   void Configure(int windowSize, int warmupSize)
     {
      m_windowSize = MathMax(windowSize, 50);
      m_warmupSize = MathMax(warmupSize, 20);
      m_warmupSize = MathMin(m_warmupSize, m_windowSize);
      m_count      = 0;
      m_writeIdx   = 0;
      m_warmedUp   = false;
      ArrayResize(m_buffer, PERCENTILE_STATES * m_windowSize);
      ArrayInitialize(m_buffer, 0.0);
     }

   void Initialize(void)
     {
      if(ArraySize(m_buffer) != PERCENTILE_STATES * m_windowSize)
        {
         ArrayResize(m_buffer, PERCENTILE_STATES * m_windowSize);
         ArrayInitialize(m_buffer, 0.0);
        }
     }

   //+------------------------------------------------------------------+
   //| Record current latent state values and normalize to percentiles.  |
   //| Returns true if normalization was applied (warmup passed).        |
   //| If not warmed up, raw values are preserved — caller should skip   |
   //| trading until this returns true.                                  |
   //+------------------------------------------------------------------+
   bool RecordAndNormalize(SLatentStates &latent, SLatentStates &latentRaw)
     {
      // Extract raw values (order must match PERCENTILE_STATES = 8)
      double raw[PERCENTILE_STATES];
      raw[0] = latent.directionalPersistence;
      raw[1] = latent.expansionPressure;
      raw[2] = latent.participationQuality;
      raw[3] = latent.reversalPressure;
      raw[4] = latent.meanReversionPressure;
      raw[5] = latent.executionQuality;
      raw[6] = latent.marketStability;
      raw[7] = latent.volatilityRegime;

      // Store raw values for diagnostics
      latentRaw = latent;

      // Write to ring buffer
      for(int s = 0; s < PERCENTILE_STATES; s++)
         m_buffer[Offset(s, m_writeIdx)] = raw[s];

      m_writeIdx++;
      if(m_writeIdx >= m_windowSize) m_writeIdx = 0;
      if(m_count < m_windowSize) m_count++;

      // Check warmup
      if(m_count < m_warmupSize)
        {
         m_warmedUp = false;
         return false;  // keep raw values — don't trade yet
        }
      m_warmedUp = true;

      // Compute percentile ranks and overwrite latent states
      latent.directionalPersistence  = ComputePercentile(0, raw[0]);
      latent.expansionPressure       = ComputePercentile(1, raw[1]);
      latent.participationQuality    = ComputePercentile(2, raw[2]);
      latent.reversalPressure        = ComputePercentile(3, raw[3]);
      latent.meanReversionPressure   = ComputePercentile(4, raw[4]);
      latent.executionQuality        = ComputePercentile(5, raw[5]);
      latent.marketStability         = ComputePercentile(6, raw[6]);
      latent.volatilityRegime        = ComputePercentile(7, raw[7]);

      return true;
     }

   bool IsWarmedUp(void) const { return m_warmedUp; }
   int  SamplesCollected(void) const { return m_count; }
   int  WarmupRemaining(void) const { return MathMax(0, m_warmupSize - m_count); }
  };

#endif
