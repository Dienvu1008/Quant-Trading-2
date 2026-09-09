#ifndef __EA_ROOT_REJECTIONBLOCKENGINE_MQH__
#define __EA_ROOT_REJECTIONBLOCKENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

// A Rejection Block is an Order Block that held — price touched the zone and reversed.
// rejectionScore is computed by ZoneLifecycleManager per zone and reflects bounce strength.

class CRejectionBlockEngine : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol, "RejectionBlockEngine"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);
      // rejectionBlockScore written by ZoneLifecycleManager (runs first).
      // Bonus: CVD divergence supports the rejection (flow confirms reversal).
      double flowBonus = (state.flow.divergenceScore > 0.5) ? 0.1 : 0.0;
      state.smartMoney.rejectionBlockScore = Clamp01(
         state.smartMoney.rejectionBlockScore + flowBonus);
      return true;
     }
  };

#endif
