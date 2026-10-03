#ifndef __EA_ROOT_EXECUTIONQUALITYSTATE_MQH__
#define __EA_ROOT_EXECUTIONQUALITYSTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Execution Quality State                                           |
//| Encodes: spreadScore, slippage, dataQualityScore                  |
//| These features are EXCLUSIVELY owned by this state.               |
//| Output: state.latent.executionQuality [0,1]                       |
//+------------------------------------------------------------------+
class CExecutionQualityState : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"ExecutionQualityState"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // Input features (exclusive to this state)
      double spreadQ   = state.microstructure.spreadScore;      // [0,1] spread tightness
      double dataQ     = state.marketData.dataQualityScore;     // [0,1] data feed quality
      // Slippage penalty: 0 slippage = 1.0, 30+ pts = 0.0
      double slipPenalty = Clamp01(1.0 - state.marketData.slippageAvg / 30.0);

      // Simple weighted average — no sigmoid needed for permission states
      // (we want linear degradation, not binary)
      double raw = spreadQ     * 0.45
                 + dataQ       * 0.30
                 + slipPenalty * 0.25;

      state.latent.executionQuality = Clamp01(raw);
      return true;
     }
  };

#endif
