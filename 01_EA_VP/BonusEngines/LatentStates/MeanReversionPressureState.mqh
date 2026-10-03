#ifndef __EA_ROOT_MEANREVERSIONPRESSURESTATE_MQH__
#define __EA_ROOT_MEANREVERSIONPRESSURESTATE_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Mean Reversion Pressure State (V2 8-State Architecture)           |
//| Answers: "Does market tend to revert to equilibrium?"             |
//|                                                                   |
//| This is NOT a reversal state (which detects liquidity sweeps).    |
//| This state detects RANGING/OSCILLATING market character:          |
//|   - price oscillates within boundaries                            |
//|   - structure is contained                                        |
//|   - auction balance confirms rotation                             |
//|                                                                   |
//| EXCLUSIVELY encodes (no overlap with DirectionalPersistence):     |
//|   - equalHighLowScore       (equal H/L clustering = channel)      |
//|   - premiumDiscountScore    (extremity within range)              |
//|   - VP auctBalanceScore     (auction balance = rotation)          |
//|   - VP auctProfileShape D   (balanced bell = mean-reverting)      |
//|                                                                   |
//| REMOVED (was overlapping with DirectionalPersistenceState):       |
//|   - trendStrength (inverted) — owned by DirectionalPersistence    |
//|   - bosScore (inverted)      — owned by DirectionalPersistence    |
//|                                                                   |
//| Output: state.latent.meanReversionPressure [0,1]                  |
//+------------------------------------------------------------------+
class CMeanReversionPressureState : public CPipelineModuleBase
  {
public:
   void Bootstrap(const string symbol) { Configure(symbol,"MeanReversionPressureState"); }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      // ─── Exclusive features (NOT used by any other state) ───
      double equalHL      = state.liquidity.equalHighLowScore;    // [0,1] channel boundary
      double premDiscount = state.liquidity.premiumDiscountScore; // [0,1] position within range

      // Premium/discount extremity: how far from middle of range?
      // At 0.0 or 1.0 = extreme (high mean-rev potential)
      // At 0.5 = middle (low mean-rev potential — already at equilibrium)
      double rangeExtremity = MathAbs(premDiscount - 0.5) * 2.0;  // [0,1]

      // Base: equalHL (channel detection) + range extremity (near boundary)
      // NOTE: premiumDiscountScore already VP-enhanced at engine level
      // (uses VAH/VAL, acceptance, composite VA). Adding auction fields HERE
      // would double-count VP signal. Keep state PURE: only exclusive features.
      double raw = equalHL * 0.55 + rangeExtremity * 0.45;

      state.latent.meanReversionPressure = Clamp01(raw);
      return true;
     }
  };

#endif
