#ifndef __EA_ROOT_VOLATILITYREGIMESTATE_MQH__
#define __EA_ROOT_VOLATILITYREGIMESTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Volatility Regime State (NEW — V2 8-State Architecture)           |
//| Answers: "Is the market orderly or chaotic?"                      |
//|                                                                   |
//| PERMISSION STATE: high = orderly/stable, low = chaotic/unstable.  |
//| Used by PermissionGate to block trades in disorderly markets.     |
//|                                                                   |
//| EXCLUSIVELY encodes:                                              |
//|   - volatilityScore       (current ATR level vs historical)       |
//|   - spread instability    (current spread vs average spread)      |
//|   - ATR rate of change    (how fast volatility is shifting)       |
//|                                                                   |
//| This is distinct from MarketStability (news/correlation/session)  |
//| and ExecutionQuality (spread/slippage cost). VolatilityRegime     |
//| captures the PREDICTABILITY of price behavior.                    |
//|                                                                   |
//| Output: state.latent.volatilityRegime [0,1] (1.0 = orderly)      |
//+------------------------------------------------------------------+
class CVolatilityRegimeState : public CPipelineModuleBase
  {
private:
   double m_prevATR;
   double m_atrChangeHistory[20];
   int    m_histWriteIdx;
   int    m_histCount;

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol, "VolatilityRegimeState");
      m_prevATR = 0.0;
      ArrayInitialize(m_atrChangeHistory, 0.0);
      m_histWriteIdx = 0;
      m_histCount = 0;
     }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // ─── Feature 1: Current volatility level ───
      // volatilityScore from RegimeEngine: 0=calm, 1=explosive
      double volLevel = state.marketContext.volatilityScore;

      // ─── Feature 2: ATR rate of change (volatility instability) ───
      double atr = state.marketData.atrProxy;
      double atrChange = 0.0;
      if(m_prevATR > 0.0 && atr > 0.0)
         atrChange = MathAbs(atr - m_prevATR) / m_prevATR;
      m_prevATR = atr;

      // Store in ring buffer for clustering detection
      m_atrChangeHistory[m_histWriteIdx] = atrChange;
      m_histWriteIdx = (m_histWriteIdx + 1) % 20;
      if(m_histCount < 20) m_histCount++;

      // Volatility clustering: average rate of change over recent history
      double meanChange = 0.0;
      for(int i = 0; i < m_histCount; i++)
         meanChange += m_atrChangeHistory[i];
      meanChange /= MathMax(m_histCount, 1);
      // 15% mean change = max clustering (very unstable)
      double volClustering = Clamp01(meanChange / 0.15);

      // ─── Feature 3: Spread instability ───
      // Current spread vs average: ratio > 1.0 = widening (chaotic)
      double spreadRatio = 1.0;
      if(state.marketData.avgSpreadPoints > 0.0)
         spreadRatio = state.marketData.spreadPoints / state.marketData.avgSpreadPoints;
      // 3× average spread = max instability
      double spreadInstab = Clamp01((spreadRatio - 1.0) / 2.0);

      // ─── Combine: HIGH raw = CHAOTIC, then INVERT for permission semantics ───
      // Permission states use 1.0 = "safe/good", so we invert.
      double chaosRaw = volLevel      * 0.35
                      + volClustering * 0.30
                      + spreadInstab  * 0.20
                      + atrChange     * 0.15;  // instantaneous instability

      // Output: 1.0 = orderly, predictable; 0.0 = chaotic, unpredictable
      state.latent.volatilityRegime = Clamp01(1.0 - chaosRaw);
      return true;
     }
  };

#endif
