#ifndef __VP_EA_SESSIONDATA_MQH__
#define __VP_EA_SESSIONDATA_MQH__

#include "..\Config\GlobalParameters.mqh"

class CVPSessionData : public CVPModuleBase
{
public:
   void Bootstrap(const string symbol) { Configure(symbol, "SessionData"); }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);
      MqlDateTime dt;
      TimeCurrent(dt);
      int hour = dt.hour;

      // Simple session classification (broker time = GMT+2/+3 typical)
      if (hour >= 0 && hour < 8)
         state.session = SESSION_ASIAN;
      else if (hour >= 8 && hour < 13)
         state.session = SESSION_LONDON;
      else if (hour >= 13 && hour < 17)
         state.session = SESSION_OVERLAP;
      else if (hour >= 17 && hour < 22)
         state.session = SESSION_NEWYORK;
      else
         state.session = SESSION_ASIAN;

      return true;
   }
};

#endif
