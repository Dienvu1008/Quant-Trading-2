#ifndef __EA_ROOT_BREAKOUTTRIGGER_MQH__
#define __EA_ROOT_BREAKOUTTRIGGER_MQH__

#include "..\Config\GlobalParameters.mqh"


//+------------------------------------------------------------------+
//| Breakout Trigger v6.0 — VP/Auction Data Collection               |
//| Hard gates only: regime + tradeQuality + vpValid                 |
//| Direction: sign-based (no thresholds)                            |
//| Quality score: computed for logging, NOT used to block           |
//+------------------------------------------------------------------+

#define BREAKOUT_MAX_VA_DISTANCE_ATR 3.0

class CSimpleBreakoutTrigger : public CVPModuleBase
{
private:
  datetime m_lastFired;
  ETradingMode m_tradingMode;

  bool IsRegimeCompatible(int regime)
  {
    return (regime == REGIME_TREND_INITIATION ||
            regime == REGIME_TREND_CONTINUATION ||
            regime == REGIME_RE_ACCUMULATION ||
            regime == REGIME_BALANCED_ROTATION ||
            regime == REGIME_COMPRESSION);
  }

  // Direction: positive=bull, negative=bear. Sign-based, no threshold.
  double ComputeDirectionScore(const SVPPipelineState &state)
  {
    double dirScore = 0.0;
    if (state.vpVAOverlapBias == 1) dirScore += 0.35;
    else if (state.vpVAOverlapBias == -1) dirScore -= 0.35;

    double devDir = state.vpDevPOCDirection;
    if (devDir > 0.02) dirScore += 0.30;
    else if (devDir < -0.02) dirScore -= 0.30;

    if (state.auctContinuationScore > 0.4) dirScore += 0.20;
    else if (state.auctContinuationScore < 0.3) dirScore -= 0.20;

    double bid = state.marketData.bid;
    if (state.vpVAH > 0 && bid > state.vpVAH) dirScore += 0.15;
    else if (state.vpVAL > 0 && bid < state.vpVAL) dirScore -= 0.15;

    return dirScore;
  }

  double ComputeBreakoutQuality(const SVPPipelineState &state, bool bullish)
  {
    double quality = 0.0;
    quality += state.vpMigrationConfidence * 0.30;
    quality += state.auctTradeQuality * 0.25;
    if (!state.vpInsideVA) quality += 0.10;
    int regime = state.auctRegime;
    if (regime == REGIME_TREND_INITIATION) quality += 0.10;
    else if (regime == REGIME_TREND_CONTINUATION) quality += 0.05;
    if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3) quality += 0.07;
    if (state.vpBreakoutPOC > 0)
    {
      bool pastBO = (bullish && state.marketData.bid > state.vpBreakoutPOC) ||
                    (!bullish && state.marketData.bid < state.vpBreakoutPOC);
      if (pastBO) quality += 0.08;
    }
    int compPos = state.vpCompositePosition;
    if ((bullish && compPos == -1) || (!bullish && compPos == 1)) quality += 0.05;
    return Clamp01(quality);
  }

public:
  void SetMode(ETradingMode mode) { m_tradingMode = mode; }
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "BreakoutTrigger");
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

    // ═══ HARD GATES ONLY ═══════════════════════════════════════
    int regime = state.auctRegime;
    if (regime == REGIME_CHAOTIC || regime == REGIME_EXCESS) return true;
    if (!IsRegimeCompatible(regime)) return true;
    if (state.auctTradeQuality < 0.15) return true;
    if (state.vpUpthrustDetected && state.vpSpringDetected) return true; // contradictory signals only

    double bid = state.marketData.bid;
    double atr = state.marketData.atrProxy * state.marketData.pointSize; // ATR in PRICE
    if (atr <= 0) return true;

    // ─── Direction (sign-based) ─────────────────────────────
    double dirScore = ComputeDirectionScore(state);
    bool bullish = (dirScore > 0);
    bool bearish = (dirScore < 0);
    if (!bullish && !bearish) return true;

    // ─── Price must be outside or near VA boundary ──────────
    if (bullish && state.vpVAH > 0 && (bid - state.vpVAH) > BREAKOUT_MAX_VA_DISTANCE_ATR * atr)
      return true;
    if (bearish && state.vpVAL > 0 && (state.vpVAL - bid) > BREAKOUT_MAX_VA_DISTANCE_ATR * atr)
      return true;

    // ═══ FIRE SETUP ═══════════════════════════════════════════
    double breakoutQuality = ComputeBreakoutQuality(state, bullish);

    state.primarySetup.isValid = true;
    state.primarySetup.setupType = SETUP_BREAKOUT;
    state.primarySetup.entryPrice = bid;
    state.primarySetup.detectedAt = TimeCurrent();
    state.winProbability = breakoutQuality;
    state.edgeGuardMultiplier = 1.0;

    // ─── SL ─────────────────────────────────────────────────
    double maxSLDist = atr * 2.0;
    if (bullish)
    {
      double vpSL = 0.0;
      if (state.vpBestHVN > 0 && state.vpBestHVN < bid) vpSL = fmax(vpSL, state.vpBestHVN);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN < bid) vpSL = fmax(vpSL, state.vpNearestHVN);
      if (state.vpPOC > 0 && state.vpPOC < bid) vpSL = fmax(vpSL, state.vpPOC);
      if (state.vpVAL > 0 && state.vpVAL < bid) vpSL = fmax(vpSL, state.vpVAL);
      double finalSL = (vpSL > 0 && bid - vpSL > atr * 0.3) ? vpSL - atr * 0.1 : bid - atr * 1.5;
      if (bid - finalSL > maxSLDist) finalSL = bid - maxSLDist;
      state.primarySetup.stopLoss = finalSL;

      double tp = bid + atr * 2.5;
      if (state.auctTargetPrice > bid && state.auctTargetConfidence > 0.40)
        tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > bid && state.vpNearestNakedPOC - bid < atr * 4.0)
        tp = state.vpNearestNakedPOC;
      else if (state.vpNearestLVN > bid && state.vpNearestLVN - bid > atr * 0.5 && state.vpNearestLVN - bid < atr * 3.5)
        tp = state.vpNearestLVN;
      else if (state.vpBreakoutPOC > bid && state.vpBreakoutPOC - bid < atr * 4.0)
        tp = state.vpBreakoutPOC;
      state.primarySetup.takeProfit = tp;
    }
    else
    {
      double vpSL = DBL_MAX;
      if (state.vpBestHVN > 0 && state.vpBestHVN > bid) vpSL = fmin(vpSL, state.vpBestHVN);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN > bid) vpSL = fmin(vpSL, state.vpNearestHVN);
      if (state.vpPOC > 0 && state.vpPOC > bid) vpSL = fmin(vpSL, state.vpPOC);
      if (state.vpVAH > 0 && state.vpVAH > bid) vpSL = fmin(vpSL, state.vpVAH);
      double finalSL = (vpSL < DBL_MAX && vpSL - bid > atr * 0.3) ? vpSL + atr * 0.1 : bid + atr * 1.5;
      if (finalSL - bid > maxSLDist) finalSL = bid + maxSLDist;
      state.primarySetup.stopLoss = finalSL;

      double tp = bid - atr * 2.5;
      if (state.auctTargetPrice > 0 && state.auctTargetPrice < bid && state.auctTargetConfidence > 0.40)
        tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > 0 && state.vpNearestNakedPOC < bid && bid - state.vpNearestNakedPOC < atr * 4.0)
        tp = state.vpNearestNakedPOC;
      else if (state.vpNearestLVN > 0 && state.vpNearestLVN < bid && bid - state.vpNearestLVN > atr * 0.5 && bid - state.vpNearestLVN < atr * 3.5)
        tp = state.vpNearestLVN;
      else if (state.vpBreakoutPOC > 0 && state.vpBreakoutPOC < bid && bid - state.vpBreakoutPOC < atr * 4.0)
        tp = state.vpBreakoutPOC;
      state.primarySetup.takeProfit = tp;
    }

    double slDist = MathAbs(bid - state.primarySetup.stopLoss);
    double tpDist = MathAbs(state.primarySetup.takeProfit - bid);
    state.primarySetup.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;

    // Min R:R safety (only block truly degenerate setups)
    if (state.primarySetup.riskReward < 1.0)
    { state.primarySetup.isValid = false; return true; }

    PrintFormat("[TRIGGER][%s] BREAKOUT v6.0: quality=%.2f dir=%.2f %s regime=%d RR=%.1f",
               m_symbol, breakoutQuality, dirScore, bullish?"BULL":"BEAR", regime, state.primarySetup.riskReward);
    m_lastFired = TimeCurrent();
    return true;
  }
};

#endif
