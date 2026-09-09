#ifndef __VP_EA_POSITIONSIZING_MQH__
#define __VP_EA_POSITIONSIZING_MQH__

#include "..\Config\GlobalParameters.mqh"

class CVPPositionSizing
{
public:
   // ─── Standard mode ───────────────────────────────────────────
   // fixedLot > 0 → fixed lot
   // fixedLot = 0 → risk-percent-based sizing
   static double ComputeLots(const string symbol, double slDistPrice, double riskPercent, double fixedLot)
   {
      if (fixedLot > 0) return fixedLot;
      if (slDistPrice <= 0) return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double risk = freeMargin * riskPercent / 100.0;
      double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSz  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if (tickVal <= 0 || tickSz <= 0) return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

      double lots = risk / (slDistPrice / tickSz * tickVal);
      return _Normalize(symbol, lots);
   }

   // ─── MaxLot + Calibration mode ───────────────────────────────
   // Caller is responsible for obtaining calMult from VPGetLotMultiplier()
   // (Phase 06 research output). Keeping this dependency-free allows
   // PositionSizing.mqh to compile standalone without VPEdgeGuardConfig.
   //
   // calMult: fractional Kelly multiplier [0.50, 1.50] from Phase 06
   // edgeGuardMult: SL risk multiplier from Phase 04 — only reduces lot
   // maxLot: ceiling lot size (0 = use symbol max)
   static double ComputeLotsMaxMode(const string symbol, double maxLot,
                                    double calMult, double edgeGuardMult = 1.0)
   {
      double symMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double base   = (maxLot > 0) ? MathMin(maxLot, symMax) : symMax;

      // EdgeGuard risk multiplier only reduces, never increases
      double safeMult = MathMin(1.0, edgeGuardMult);

      double lots = base * calMult * safeMult;
      return _Normalize(symbol, lots);
   }

private:
   static double _Normalize(const string symbol, double lots)
   {
      double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxL = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      if (step <= 0) step = 0.01;
      lots = MathFloor(lots / step) * step;
      return MathMax(minL, MathMin(maxL, lots));
   }
};

#endif
