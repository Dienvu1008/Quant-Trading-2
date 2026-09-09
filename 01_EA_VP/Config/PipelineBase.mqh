#ifndef __VP_EA_PIPELINE_BASE_MQH__
#define __VP_EA_PIPELINE_BASE_MQH__

// VPStructures.mqh is already included via GlobalParameters.mqh
// No need to re-include here (guard protects anyway)

class CVPModuleBase
{
protected:
   string m_symbol;
   string m_moduleName;

public:
   CVPModuleBase(void) { m_symbol = ""; m_moduleName = ""; }

   void Configure(const string symbol, const string moduleName)
   {
      m_symbol = symbol;
      m_moduleName = moduleName;
   }

   virtual bool Initialize(void)
   {
      if (m_symbol == "") return false;
      SymbolSelect(m_symbol, true);
      return true;
   }

   virtual bool Execute(SVPPipelineState &state)
   {
      state.executedModules++;
      state.lastModule = m_moduleName;
      state.lastUpdateTime = TimeCurrent();
      return true;
   }

   virtual void Shutdown(void) {}
};

#endif
