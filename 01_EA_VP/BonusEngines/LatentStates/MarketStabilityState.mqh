#ifndef __EA_ROOT_MARKETSTABILITYSTATE_MQH__
#define __EA_ROOT_MARKETSTABILITYSTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Market Stability State                                            |
//| Encodes: newsRiskScore, correlationRisk, sessionQuality, regime   |
//| These features are EXCLUSIVELY owned by this state.               |
//| Output: state.latent.marketStability [0,1]                        |
//+------------------------------------------------------------------+
class CMarketStabilityState : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"MarketStabilityState"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // Input features (exclusive to this state)
      // newsRiskScore: high = dangerous → invert for stability
      double newsStability = Clamp01(1.0 - state.marketContext.newsRiskScore);
      // correlationRiskScore: high = portfolio danger → invert
      double corrStability = Clamp01(1.0 - state.marketContext.correlationRiskScore);
      // Session quality: overlap/London = best; Asian = worst
      double sessionQ = 0.5;
      switch(state.marketContext.session)
        {
         case SESSION_OVERLAP: sessionQ = 1.0;  break;
         case SESSION_LONDON:  sessionQ = 0.85; break;
         case SESSION_NEWYORK: sessionQ = 0.75; break;
         case SESSION_ASIAN:   sessionQ = 0.35; break;
         default:              sessionQ = 0.50; break;
        }
      // Regime clarity: UNKNOWN is unstable; clear regime = stable
      double regimeClarity = (state.marketContext.regime != MARKET_REGIME_UNKNOWN) ? 0.8 : 0.3;
      // Crisis regime override
      if(state.marketContext.riskRegime == RISK_REGIME_CRISIS)
         regimeClarity = 0.0;

      double raw = newsStability * 0.30
                 + corrStability * 0.25
                 + sessionQ     * 0.25
                 + regimeClarity * 0.20;

      state.latent.marketStability = Clamp01(raw);
      return true;
     }
  };

#endif
