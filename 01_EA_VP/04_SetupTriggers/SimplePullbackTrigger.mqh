#ifndef __EA_ROOT_PULLBACKTRIGGER_MQH__
#define __EA_ROOT_PULLBACKTRIGGER_MQH__

#include "..\Config\GlobalParameters.mqh"


//+------------------------------------------------------------------+
//| Pullback Trigger v6.0 — VP/Auction Data Collection               |
//| Hard gates: regime + tradeQuality + direction + inside VA        |
//| No numeric threshold gates                                       |
//+------------------------------------------------------------------+

class CSimplePullbackTrigger : public CVPModuleBase
{
private:
  datetime m_lastFired;
  ETradingMode m_tradingMode;

  bool IsRegimeCompatible(int regime)
  {
    return (regime == REGIME_TREND_CONTINUATION ||
            regime == REGIME_RE_ACCUMULATION ||
            regime == REGIME_TREND_INITIATION ||
            regime == REGIME_BALANCED_ROTATION ||
            regime == REGIME_COMPRESSION);
  }

public:
  void SetMode(ETradingMode mode) { m_tradingMode = mode; }
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "PullbackTrigger");
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

    double bid = state.marketData.bid;
    double atr = state.marketData.atrProxy * state.marketData.pointSize; // ATR in PRICE
    if (atr <= 0) return true;

    // ─── Direction (sign-based) ─────────────────────────────
    double dirScore = 0.0;
    if (state.vpVAOverlapBias == 1) dirScore += 0.35;
    else if (state.vpVAOverlapBias == -1) dirScore -= 0.35;
    if (state.vpDevPOCDirection > 0.02) dirScore += 0.30;
    else if (state.vpDevPOCDirection < -0.02) dirScore -= 0.30;
    if (state.auctContinuationScore > 0.4) dirScore += 0.20;
    else if (state.auctContinuationScore < 0.3) dirScore -= 0.20;

    bool bullish = (dirScore > 0);
    bool bearish = (dirScore < 0);
    if (!bullish && !bearish) return true;

    // ─── Pullback context: must be inside VA or near VP level ─
    // (Pullback = price has retraced into value area from breakout)
    bool insideVA = state.vpInsideVA;
    bool nearHVN = (state.vpDistToHVN_ATR > 0 && state.vpDistToHVN_ATR < 1.0);
    bool nearPOC = false;
    if (state.vpPullbackPOC > 0)
    {
      double dist = MathAbs(bid - state.vpPullbackPOC) / atr;
      nearPOC = (dist < 1.0);
    }
    if (!insideVA && !nearHVN && !nearPOC) return true;

    // ═══ FIRE SETUP ═══
    double thesis = state.vpMigrationConfidence * 0.30 + state.auctContinuationScore * 0.30 + state.auctTradeQuality * 0.25 + (insideVA ? 0.15 : 0.0);

    state.primarySetup.isValid = true;
    state.primarySetup.setupType = SETUP_PULLBACK;
    state.primarySetup.entryPrice = bid;
    state.primarySetup.detectedAt = TimeCurrent();
    state.winProbability = Clamp01(thesis);
    state.edgeGuardMultiplier = 1.0;

    // ─── SL ─────────────────────────────────────────────────
    if (bullish)
    {
      double sl = bid - atr * 1.5;
      double bestSupport = 0;
      if (state.vpPullbackPOC > 0 && state.vpPullbackPOC < bid) bestSupport = fmax(bestSupport, state.vpPullbackPOC);
      if (state.vpBestHVN > 0 && state.vpBestHVN < bid) bestSupport = fmax(bestSupport, state.vpBestHVN);
      if (state.vpPOC > 0 && state.vpPOC < bid) bestSupport = fmax(bestSupport, state.vpPOC);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN < bid) bestSupport = fmax(bestSupport, state.vpNearestHVN);
      if (state.vpVAL > 0 && state.vpVAL < bid) bestSupport = fmax(bestSupport, state.vpVAL);
      if (bestSupport > 0 && bid - bestSupport > atr * 0.3) sl = bestSupport - atr * 0.1;
      state.primarySetup.stopLoss = sl;

      double tp = bid + atr * 3.0;
      if (state.auctTargetPrice > bid && state.auctTargetConfidence > 0.40) tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > bid && state.vpNearestNakedPOC - bid < atr * 4.0) tp = state.vpNearestNakedPOC;
      else if (state.vpNearestLVN > bid && state.vpNearestLVN - bid > atr * 0.5 && state.vpNearestLVN - bid < atr * 3.5) tp = state.vpNearestLVN;
      else if (state.vpCompositeVAH > bid && state.vpCompositeVAH - bid < atr * 4.0) tp = state.vpCompositeVAH;
      state.primarySetup.takeProfit = tp;
    }
    else
    {
      double sl = bid + atr * 1.5;
      double bestResist = DBL_MAX;
      if (state.vpPullbackPOC > 0 && state.vpPullbackPOC > bid) bestResist = fmin(bestResist, state.vpPullbackPOC);
      if (state.vpBestHVN > 0 && state.vpBestHVN > bid) bestResist = fmin(bestResist, state.vpBestHVN);
      if (state.vpPOC > 0 && state.vpPOC > bid) bestResist = fmin(bestResist, state.vpPOC);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN > bid) bestResist = fmin(bestResist, state.vpNearestHVN);
      if (state.vpVAH > 0 && state.vpVAH > bid) bestResist = fmin(bestResist, state.vpVAH);
      if (bestResist < DBL_MAX && bestResist - bid > atr * 0.3) sl = bestResist + atr * 0.1;
      state.primarySetup.stopLoss = sl;

      double tp = bid - atr * 3.0;
      if (state.auctTargetPrice > 0 && state.auctTargetPrice < bid && state.auctTargetConfidence > 0.40) tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > 0 && state.vpNearestNakedPOC < bid && bid - state.vpNearestNakedPOC < atr * 4.0) tp = state.vpNearestNakedPOC;
      else if (state.vpNearestLVN > 0 && state.vpNearestLVN < bid && bid - state.vpNearestLVN > atr * 0.5 && bid - state.vpNearestLVN < atr * 3.5) tp = state.vpNearestLVN;
      else if (state.vpCompositeVAL > 0 && state.vpCompositeVAL < bid && bid - state.vpCompositeVAL < atr * 4.0) tp = state.vpCompositeVAL;
      state.primarySetup.takeProfit = tp;
    }

    double slDist = MathAbs(bid - state.primarySetup.stopLoss);
    double tpDist = MathAbs(state.primarySetup.takeProfit - bid);
    state.primarySetup.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;
    if (state.primarySetup.riskReward < 1.0)
    { state.primarySetup.isValid = false; return true; }

    PrintFormat("[TRIGGER][%s] PULLBACK v6.0: thesis=%.2f %s regime=%d RR=%.1f",
               m_symbol, thesis, bullish?"BULL":"BEAR", regime, state.primarySetup.riskReward);
    m_lastFired = TimeCurrent();
    return true;
  }
};

#endif
