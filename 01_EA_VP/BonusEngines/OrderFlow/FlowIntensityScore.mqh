#ifndef __EA_ROOT_FLOWINTENSITYSCORE_MQH__
#define __EA_ROOT_FLOWINTENSITYSCORE_MQH__

#include "..\Config\GlobalParameters.mqh"

class CFlowIntensityScore : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"FlowIntensityScore"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      state.flow.flowIntensityScore = Clamp01(
         (state.flow.participationScore * 0.4 +
          state.flow.absorptionScore * 0.3 +
          MathAbs(state.flow.deltaProxy - 0.5) * 2.0 * 0.3));
      return true;
     }
  };

#endif
