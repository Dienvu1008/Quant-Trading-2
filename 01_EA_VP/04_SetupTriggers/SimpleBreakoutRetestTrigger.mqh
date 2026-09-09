#ifndef __EA_ROOT_BREAKOUTRETESTTRIGGER_MQH__
#define __EA_ROOT_BREAKOUTRETESTTRIGGER_MQH__

#include "..\Config\GlobalParameters.mqh"


//+------------------------------------------------------------------+
//| Breakout Retest Trigger v6.0 — VP/Auction Data Collection        |
//| Hard gates: regime + tradeQuality + vpValid + fib retracement    |
//| Direction: sign-based from VP signals                            |
//+------------------------------------------------------------------+

class CSimpleBreakoutRetestTrigger : public CVPModuleBase
{
private:
  datetime m_lastFired;
  ETradingMode m_tradingMode;

  bool IsRegimeCompatible(int regime)
  {
    return (regime == REGIME_TREND_INITIATION ||
            regime == REGIME_RE_ACCUMULATION ||
            regime == REGIME_TREND_CONTINUATION ||
            regime == REGIME_BALANCED_ROTATION ||
            regime == REGIME_COMPRESSION);
  }

public:
  void SetMode(ETradingMode mode) { m_tradingMode = mode; }
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "BreakoutRetestTrigger");
    m_lastFired = 0;
    m_tradingMode = MODE_DAYTRADING;
  }
  void ResetCooldownShort(datetime newLastFired) { m_lastFired = newLastFired; }

  virtual bool Execute(SVPPipelineState &state) override
  {
    CVPModuleBase::Execute(state);
    if (state.primarySetup.isValid) return true;
    if (m_lastFired > 0 && TimeCurrent() - m_lastFired < SETUP_COOLDOWN_SEC) return true;
    if (!state.vpValid) return true;

    // ═══ HARD GATES ═══
    int regime = state.auctRegime;
    if (regime == REGIME_CHAOTIC || regime == REGIME_EXCESS) return true;
    if (!IsRegimeCompatible(regime)) return true;
    if (state.auctTradeQuality < 0.15) return true;
    if (state.vpUpthrustDetected && state.vpSpringDetected) return true; // contradictory only

    double bid = state.marketData.bid;
    double atr = state.marketData.atrProxy * state.marketData.pointSize; // ATR in PRICE
    if (atr <= 0) return true;

    // ─── Direction (sign-based) ─────────────────────────────
    int vaBias = state.vpVAOverlapBias;
    double devDir = state.vpDevPOCDirection;
    bool bullish = (vaBias == 1) || (vaBias == 0 && devDir > 0);
    bool bearish = (vaBias == -1) || (vaBias == 0 && devDir < 0);
    if (!bullish && !bearish) return true;

    // ─── BOS level from VP (VAH/VAL or BreakoutPOC) ────────
    double bosLevel = 0, impulseStart = 0;
    if (bullish)
    {
      bosLevel = (state.vpBreakoutPOC > 0 && state.vpBreakoutPOC > state.vpVAH) ? state.vpBreakoutPOC : state.vpVAH;
      impulseStart = state.vpVAL;
    }
    else
    {
      bosLevel = (state.vpBreakoutPOC > 0 && state.vpBreakoutPOC < state.vpVAL) ? state.vpBreakoutPOC : state.vpVAL;
      impulseStart = state.vpVAH;
    }
    if (bosLevel <= 0 || impulseStart <= 0) return true;
    double impulseRange = MathAbs(bosLevel - impulseStart);
    if (impulseRange <= 0) return true;

    // ─── Fibonacci retracement (structural gate — relaxed for data collection) ───
    double ret = bullish ? (bosLevel - bid) / impulseRange : (bid - bosLevel) / impulseRange;
    if (ret < 0.05 || ret > 0.95) return true;  // only block extreme degenerate cases
    if (bullish && bid <= impulseStart) return true;
    if (!bullish && bid >= impulseStart) return true;

    // ═══ FIRE SETUP ═══
    double thesis = state.vpMigrationConfidence * 0.40 + state.auctTradeQuality * 0.30 + state.auctContinuationScore * 0.30;

    state.primarySetup.isValid = true;
    state.primarySetup.setupType = SETUP_BREAKOUT_RETEST;
    state.primarySetup.entryPrice = bid;
    state.primarySetup.detectedAt = TimeCurrent();
    state.winProbability = Clamp01(thesis);
    state.edgeGuardMultiplier = 1.0;

    // ─── SL ─────────────────────────────────────────────────
    double maxSLDist = atr * 2.5;
    if (bullish)
    {
      double rawSL = impulseStart - atr * 0.1;
      double bestSupport = 0;
      if (state.vpNearestHVN > 0 && state.vpNearestHVN < bid) bestSupport = fmax(bestSupport, state.vpNearestHVN);
      if (state.vpPOC > 0 && state.vpPOC < bid) bestSupport = fmax(bestSupport, state.vpPOC);
      if (state.vpVAL > 0 && state.vpVAL < bid) bestSupport = fmax(bestSupport, state.vpVAL);
      if (bestSupport > 0 && bestSupport - atr * 0.1 > rawSL) rawSL = bestSupport - atr * 0.1;
      if (bid - rawSL > maxSLDist) rawSL = bid - maxSLDist;
      if (rawSL > bid - atr * 0.3) rawSL = bid - atr * 0.3;
      state.primarySetup.stopLoss = rawSL;

      double tp = bosLevel + impulseRange * 0.50;
      if (state.auctTargetPrice > bid && state.auctTargetConfidence > 0.40) tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > bid && state.vpNearestNakedPOC - bid < atr * 4.0) tp = state.vpNearestNakedPOC;
      if (tp - bid > atr * 4.0) tp = bid + atr * 4.0;
      state.primarySetup.takeProfit = tp;
    }
    else
    {
      double rawSL = impulseStart + atr * 0.1;
      double bestResist = DBL_MAX;
      if (state.vpNearestHVN > 0 && state.vpNearestHVN > bid) bestResist = fmin(bestResist, state.vpNearestHVN);
      if (state.vpPOC > 0 && state.vpPOC > bid) bestResist = fmin(bestResist, state.vpPOC);
      if (state.vpVAH > 0 && state.vpVAH > bid) bestResist = fmin(bestResist, state.vpVAH);
      if (bestResist < DBL_MAX && bestResist + atr * 0.1 < rawSL) rawSL = bestResist + atr * 0.1;
      if (rawSL - bid > maxSLDist) rawSL = bid + maxSLDist;
      if (rawSL < bid + atr * 0.3) rawSL = bid + atr * 0.3;
      state.primarySetup.stopLoss = rawSL;

      double tp = bosLevel - impulseRange * 0.50;
      if (state.auctTargetPrice > 0 && state.auctTargetPrice < bid && state.auctTargetConfidence > 0.40) tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > 0 && state.vpNearestNakedPOC < bid && bid - state.vpNearestNakedPOC < atr * 4.0) tp = state.vpNearestNakedPOC;
      if (bid - tp > atr * 4.0) tp = bid - atr * 4.0;
      state.primarySetup.takeProfit = tp;
    }

    double slDist = MathAbs(bid - state.primarySetup.stopLoss);
    double tpDist = MathAbs(state.primarySetup.takeProfit - bid);
    state.primarySetup.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;
    if (state.primarySetup.riskReward < 1.0)
    { state.primarySetup.isValid = false; return true; }

    PrintFormat("[TRIGGER][%s] BREAKOUT_RETEST v6.0: thesis=%.2f ret=%.2f %s regime=%d RR=%.1f",
               m_symbol, thesis, ret, bullish?"BULL":"BEAR", regime, state.primarySetup.riskReward);
    m_lastFired = TimeCurrent();
    return true;
  }
};

#endif
