#ifndef __EA_ROOT_PARTICIPATIONQUALITYSTATE_MQH__
#define __EA_ROOT_PARTICIPATIONQUALITYSTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Participation Quality State (NEW — V2 8-State Architecture)       |
//| Answers: "Is the current move backed by real participation?"      |
//|                                                                   |
//| EXCLUSIVELY encodes:                                              |
//|   - participationScore    (volume breadth / tick activity)        |
//|   - flowIntensityScore    (strength of directional flow)          |
//|   - deltaProxy alignment  (directional consensus in order flow)   |
//|   - sessionLiquidityScore (liquidity depth of current session)    |
//|                                                                   |
//| SHAP justification:                                               |
//|   - participation: SHAP_profit = 40.78                            |
//|   - flowIntensity: SHAP_profit = 45.91                            |
//|   - deltaProxy:    SHAP_profit = 232.70 (highest after lots!)     |
//|   - sessionLiq:    SHAP_exec   = 0.137                            |
//|   - participation ↔ flowIntensity corr = 0.857 (same dimension)   |
//|                                                                   |
//| This state captures whether a price move has "institutional"      |
//| backing vs a thin-market drift. High participation = real move.   |
//|                                                                   |
//| Output: state.latent.participationQuality [0,1]                   |
//+------------------------------------------------------------------+
class CParticipationQualityState : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"ParticipationQualityState"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // Input features (EXCLUSIVELY owned by this state)
      double participation = state.flow.participationScore;           // [0,1] volume breadth
      double flowIntensity = state.flow.flowIntensityScore;           // [0,1] flow strength
      double sessionLiq    = state.liquidity.sessionLiquidityScore;   // [0,1] session depth

      // Delta alignment: how directional is the order flow?
      // deltaProxy = 0.5 means balanced; deviation from 0.5 = directional conviction
      double deltaAlign = MathAbs(state.flow.deltaProxy - 0.5) * 2.0; // [0,1]

      // Participation + flowIntensity are the core signals (corr=0.857 — same phenomenon).
      // Delta alignment confirms the flow has directional conviction.
      // Session liquidity provides context (thin market = unreliable participation).
      double raw = participation * 0.30
                 + flowIntensity * 0.30
                 + deltaAlign   * 0.25
                 + sessionLiq   * 0.15;

      state.latent.participationQuality = Clamp01(raw);
      return true;
     }
  };

#endif
