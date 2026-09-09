#ifndef __VP_EA_SYMBOL_MANAGER_MQH__
#define __VP_EA_SYMBOL_MANAGER_MQH__

#include "VPTradingPipeline.mqh"

#define VP_MAX_SYMBOLS 20

class CVPSymbolManager
{
private:
   CVPTradingPipeline m_pipelines[VP_MAX_SYMBOLS];
   string             m_symbols[VP_MAX_SYMBOLS];
   int                m_symbolCount;
   SVPEAConfig        m_config;

public:
   CVPSymbolManager(void) { m_symbolCount = 0; }

   bool Initialize(const string symbolList, const SVPEAConfig &config)
   {
      m_config = config;
      m_symbolCount = 0;

      // Parse comma-separated symbol list
      string symbols[];
      int count = StringSplit(symbolList, ',', symbols);

      for (int i = 0; i < count && m_symbolCount < VP_MAX_SYMBOLS; i++)
      {
         string sym = symbols[i];
         StringTrimLeft(sym);
         StringTrimRight(sym);
         if (StringLen(sym) == 0) continue;

         // Verify symbol exists
         if (!SymbolSelect(sym, true))
         {
            PrintFormat("[VP_MGR] Symbol %s not found, skipping", sym);
            continue;
         }

         m_symbols[m_symbolCount] = sym;
         if (m_pipelines[m_symbolCount].Initialize(sym, config))
            m_symbolCount++;
         else
            PrintFormat("[VP_MGR] Failed to initialize pipeline for %s", sym);
      }

      PrintFormat("[VP_MGR] Initialized %d symbols, magic=%d", m_symbolCount, config.magicNumber);
      return (m_symbolCount > 0);
   }

   void OnTick(void)
   {
      for (int i = 0; i < m_symbolCount; i++)
         m_pipelines[i].Update();
   }

   void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
   {
      // Detect closed deals
      if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
      if (trans.deal == 0) return;

      if (!HistoryDealSelect(trans.deal)) return;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

      long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      if (magic != m_config.magicNumber) return;

      string dealSymbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
      double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                      HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                      HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      ulong posId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

      // Route to correct pipeline
      for (int i = 0; i < m_symbolCount; i++)
      {
         if (m_pipelines[i].Symbol() == dealSymbol)
         {
            m_pipelines[i].OnTradeClosed(posId, profit);
            break;
         }
      }
   }

   void Shutdown(void)
   {
      for (int i = 0; i < m_symbolCount; i++)
         m_pipelines[i].Shutdown();
      PrintFormat("[VP_MGR] All pipelines shut down");
   }

   int SymbolCount(void) const { return m_symbolCount; }
};

#endif
