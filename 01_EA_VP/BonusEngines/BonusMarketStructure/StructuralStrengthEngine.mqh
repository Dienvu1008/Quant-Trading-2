#ifndef __EA_ROOT_STRUCTURALSTRENGTHENGINE_MQH__
#define __EA_ROOT_STRUCTURALSTRENGTHENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

class CStructuralStrengthEngine : public CPipelineModuleBase
  {
private:
   double m_overallStrength;

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol,"StructuralStrengthEngine");
      m_overallStrength = 0;
     }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      double bos = state.structure.bosScore;
      double choch = state.structure.chochScore;
      double trend = state.structure.trendStrength;

      m_overallStrength = Clamp01((bos * 0.4 + choch * 0.3 + trend * 0.3));
      return true;
     }

   double OverallStrength(void) const { return m_overallStrength; }
  };

#endif
