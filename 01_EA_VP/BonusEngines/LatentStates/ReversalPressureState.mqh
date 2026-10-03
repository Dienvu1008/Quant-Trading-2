#ifndef __EA_ROOT_REVERSALPRESSURESTATE_MQH__
#define __EA_ROOT_REVERSALPRESSURESTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Reversal Pressure State                                           |
//| Encodes: sweepScore, exhaustionScore, chochScore, rejectionBlock  |
//| These features are EXCLUSIVELY owned by this state.               |
//| Output: state.latent.reversalPressure [0,1]                       |
//+------------------------------------------------------------------+
class CReversalPressureState : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"ReversalPressureState"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // Input features (exclusive to this state)
      double sweep      = state.liquidity.sweepScore;             // [0,1] liquidity grab detected
      double exhaustion = state.flow.exhaustionScore;             // [0,1] momentum dying (Research)
      double choch      = state.structure.chochScore;             // [0,1] change of character
      double rejection  = state.smartMoney.rejectionBlockScore;   // [0,1] rejection at key level

      // In Production mode: exhaustion and choch may be at seed values.
      // Use delta divergence as proxy for exhaustion in Production:
      // deltaProxy < 0.3 or > 0.7 = directional exhaustion signal
      double deltaExhaustion = MathAbs(state.flow.deltaProxy - 0.5) * 2.0;

      // Take the stronger signal between actual exhaustion and delta-based proxy
      double effectiveExhaustion = MathMax(exhaustion, deltaExhaustion * 0.7);

      // Sweep is the primary reversal trigger; others confirm
      double raw = sweep              * 0.40
                 + effectiveExhaustion * 0.25
                 + choch              * 0.20
                 + rejection          * 0.15;

      // Pass raw score directly to percentile normalization (no sigmoid).
      // Percentile tracker handles "top X% for this symbol" adaptively.
      state.latent.reversalPressure = Clamp01(raw);
      return true;
     }
  };

#endif
