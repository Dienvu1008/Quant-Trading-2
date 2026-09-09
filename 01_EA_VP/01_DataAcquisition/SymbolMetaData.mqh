#ifndef __VP_EA_SYMBOLMETADATA_MQH__
#define __VP_EA_SYMBOLMETADATA_MQH__

#include "..\Config\GlobalParameters.mqh"

class CVPSymbolMetaData : public CVPModuleBase
{
public:
   void Bootstrap(const string symbol) { Configure(symbol, "SymbolMetaData"); }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);
      // Ensure symbol properties are current
      state.marketData.pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      state.marketData.tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      state.marketData.tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      return true;
   }
};

#endif
