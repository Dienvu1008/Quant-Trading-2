#ifndef __EA_ROOT_DIRECTIONALPERSISTENCESTATE_MQH__
#define __EA_ROOT_DIRECTIONALPERSISTENCESTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Directional Persistence State                                     |
//| Encodes: trendStrength, bosScore, structureBias, htfBias          |
//| These features are EXCLUSIVELY owned by this state — they must    |
//| NOT appear in any other latent state or downstream scoring.       |
//| Output: state.latent.directionalPersistence [0,1]                 |
//+------------------------------------------------------------------+
class CDirectionalPersistenceState : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"DirectionalPersistenceState"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // Input features (each contributes HERE ONLY)
      double trend   = state.structure.trendStrength;     // [0,1] how strong is the trend
      double bos     = state.structure.bosScore;          // [0,1] break of structure confirmation
      double bias    = MathAbs(state.structure.structureBias - 0.5) * 2.0;  // [0,1] directional clarity
      double htf     = MathAbs(state.marketContext.htfBias - 0.5) * 2.0;    // [0,1] HTF alignment

      // Weighted combination — trend is dominant signal, BOS confirms, bias/HTF align
      double raw = trend * 0.45
                 + bos   * 0.25
                 + bias  * 0.15
                 + htf   * 0.15;


      // Pass raw score directly to percentile normalization (no sigmoid).
      // Percentile tracker handles "top X% for this symbol" adaptively.
      // Sigmoid was destroying variance before percentile could rank it.
      state.latent.directionalPersistence = Clamp01(raw);
      return true;
     }
  };

#endif
