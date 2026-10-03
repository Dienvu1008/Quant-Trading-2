#ifndef __EA_ROOT_EXPANSIONPRESSURESTATE_MQH__
#define __EA_ROOT_EXPANSIONPRESSURESTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Expansion Pressure State (V2 Refactored)                          |
//| Answers: "Does the market have stored breakout energy?"           |
//|                                                                   |
//| EXCLUSIVELY encodes:                                              |
//|   - compressionScore    (stored energy from range tightening)     |
//|   - liquidityVacuumScore (vacuum = imminent breakout precursor)   |
//|   - tickVelocity         (velocity burst = breakout in progress)  |
//|                                                                   |
//| REMOVED (moved to dedicated states):                              |
//|   - participationScore  → ParticipationQualityState               |
//|   - volatilityScore     → VolatilityRegimeState                   |
//|                                                                   |
//| Output: state.latent.expansionPressure [0,1]                      |
//+------------------------------------------------------------------+
class CExpansionPressureState : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"ExpansionPressureState"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // Input features (EXCLUSIVELY owned by this state — no overlap)
      double compression = state.microstructure.compressionScore;       // [0,1] energy stored in tight range
      double vacuum      = state.microstructure.liquidityVacuumScore;   // [0,1] liquidity gap = imminent move
      double tickVel     = state.microstructure.tickVelocity;           // [0,1] velocity burst = breakout energy

      // Compression is the primary signal: energy building in a coiling market.
      // Vacuum confirms the breakout is about to happen (liquidity disappears before move).
      // Tick velocity captures the actual release of stored energy.
      double raw = compression * 0.45
                 + vacuum      * 0.35
                 + tickVel     * 0.20;

      // Pass raw score directly to percentile normalization.
      state.latent.expansionPressure = Clamp01(raw);
      return true;
     }
  };

#endif
