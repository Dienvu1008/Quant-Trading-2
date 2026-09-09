#ifndef __EA_ROOT_TRENDCONTINUATIONTRIGGER_MQH__
#define __EA_ROOT_TRENDCONTINUATIONTRIGGER_MQH__

#include "..\Config\GlobalParameters.mqh"


//+------------------------------------------------------------------+
//| Trend Continuation Trigger v6.0 — VP/Auction Data Collection     |
//| Hard gates: regime + tradeQuality + outside VA + direction       |
//| No numeric threshold gates — direction sign-based                |
//+------------------------------------------------------------------+

#define TREND_CONT_MAX_VA_DISTANCE_ATR 2.5

class CSimpleTrendContinuationTrigger : public CVPModuleBase
{
private:
  datetime m_lastFired;
  ETradingMode m_tradingMode;

  bool IsRegimeCompatible(int regime)
  {
    return (regime == REGIME_TREND_CONTINUATION ||
            regime == REGIME_TREND_INITIATION ||
            regime == REGIME_RE_ACCUMULATION);
  }

public:
  void SetMode(ETradingMode mode) { m_tradingMode = mode; }
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "TrendContinuationTrigger");
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
    if (regime == REGIME_FAILED_AUCTION) return true;
    if (state.auctTradeQuality < 0.15) return true;

    double bid = state.marketData.bid;
    double atr = state.marketData.atrProxy * state.marketData.pointSize; // ATR in PRICE
    if (atr <= 0) return true;

    // ─── Direction (sign-based) ─────────────────────────────
    double dirScore = 0.0;
    if (state.vpVAOverlapBias == 1) dirScore += 0.35;
    else if (state.vpVAOverlapBias == -1) dirScore -= 0.35;
    if (state.vpDevPOCDirection > 0.02) dirScore += 0.35;
    else if (state.vpDevPOCDirection < -0.02) dirScore -= 0.35;
    if (state.auctContinuationScore > 0.4) dirScore += 0.20;
    else if (state.auctContinuationScore < 0.3) dirScore -= 0.20;

    bool bullish = (dirScore > 0);
    bool bearish = (dirScore < 0);
    if (!bullish && !bearish) return true;

    // ─── Must be outside VA or showing directional movement ──
    // Relaxed: allow inside VA if direction is clear (for data collection)
    bool outsideVA = bullish ? (bid > state.vpVAH) : (bid < state.vpVAL);
    // Only block if inside VA AND no directional signal at all
    if (!outsideVA && state.vpInsideVA && MathAbs(state.vpDevPOCDirection) < 0.01) return true;

    // ─── Not too far from VA ────────────────────────────────
    if (bullish && state.vpVAH > 0 && (bid - state.vpVAH) > TREND_CONT_MAX_VA_DISTANCE_ATR * atr) return true;
    if (bearish && state.vpVAL > 0 && (state.vpVAL - bid) > TREND_CONT_MAX_VA_DISTANCE_ATR * atr) return true;

    // ─── Fake breakout in trade direction = invalidates ─────
    if ((bullish && state.vpUpthrustDetected) || (bearish && state.vpSpringDetected)) return true;

    // ═══ FIRE SETUP ═══
    double thesis = state.vpMigrationConfidence * 0.35 + state.auctContinuationScore * 0.35 + state.auctTradeQuality * 0.30;

    state.primarySetup.isValid = true;
    state.primarySetup.setupType = SETUP_TREND_CONTINUATION;
    state.primarySetup.entryPrice = bid;
    state.primarySetup.detectedAt = TimeCurrent();
    state.winProbability = Clamp01(thesis);
    state.edgeGuardMultiplier = 1.0;

    // ─── SL ─────────────────────────────────────────────────
    double minDist = atr * 0.3;
    double finalSL;
    if (bullish)
    {
      double slATR = bid - atr * 1.2;
      double bestSupport = 0;
      if (state.vpBestHVN > 0 && state.vpBestHVN < bid) bestSupport = fmax(bestSupport, state.vpBestHVN);
      if (state.vpPullbackPOC > 0 && state.vpPullbackPOC < bid) bestSupport = fmax(bestSupport, state.vpPullbackPOC);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN < bid) bestSupport = fmax(bestSupport, state.vpNearestHVN);
      if (state.vpPOC > 0 && state.vpPOC < bid) bestSupport = fmax(bestSupport, state.vpPOC);
      if (state.vpVAL > 0 && state.vpVAL < bid) bestSupport = fmax(bestSupport, state.vpVAL);
      double slStruct = (bestSupport > 0) ? bestSupport - atr * 0.1 : 0;
      finalSL = (slStruct > 0 && slStruct < bid) ? MathMin(slATR, slStruct) : slATR;
      if (finalSL > bid - minDist) finalSL = bid - minDist;
    }
    else
    {
      double slATR = bid + atr * 1.2;
      double bestResist = DBL_MAX;
      if (state.vpBestHVN > 0 && state.vpBestHVN > bid) bestResist = fmin(bestResist, state.vpBestHVN);
      if (state.vpPullbackPOC > 0 && state.vpPullbackPOC > bid) bestResist = fmin(bestResist, state.vpPullbackPOC);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN > bid) bestResist = fmin(bestResist, state.vpNearestHVN);
      if (state.vpPOC > 0 && state.vpPOC > bid) bestResist = fmin(bestResist, state.vpPOC);
      if (state.vpVAH > 0 && state.vpVAH > bid) bestResist = fmin(bestResist, state.vpVAH);
      double slStruct = (bestResist < DBL_MAX) ? bestResist + atr * 0.1 : 0;
      finalSL = (slStruct > 0 && slStruct > bid) ? MathMax(slATR, slStruct) : slATR;
      if (finalSL < bid + minDist) finalSL = bid + minDist;
    }
    state.primarySetup.stopLoss = finalSL;

    // ─── TP ─────────────────────────────────────────────────
    double tp;
    if (bullish)
    {
      tp = bid + atr * 2.5;
      if (state.auctTargetPrice > bid && state.auctTargetConfidence > 0.40 && state.auctTargetPrice - bid < atr * 5.0) tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > bid && state.vpNearestNakedPOC - bid < atr * 4.0) tp = state.vpNearestNakedPOC;
      else if (state.vpNearestLVN > bid && state.vpNearestLVN - bid > atr * 0.5 && state.vpNearestLVN - bid < atr * 3.5) tp = state.vpNearestLVN;
    }
    else
    {
      tp = bid - atr * 2.5;
      if (state.auctTargetPrice > 0 && state.auctTargetPrice < bid && state.auctTargetConfidence > 0.40 && bid - state.auctTargetPrice < atr * 5.0) tp = state.auctTargetPrice;
      else if (state.vpNearestNakedPOC > 0 && state.vpNearestNakedPOC < bid && bid - state.vpNearestNakedPOC < atr * 4.0) tp = state.vpNearestNakedPOC;
      else if (state.vpNearestLVN > 0 && state.vpNearestLVN < bid && bid - state.vpNearestLVN > atr * 0.5 && bid - state.vpNearestLVN < atr * 3.5) tp = state.vpNearestLVN;
    }
    state.primarySetup.takeProfit = tp;

    double slDist = MathAbs(bid - state.primarySetup.stopLoss);
    double tpDist = MathAbs(state.primarySetup.takeProfit - bid);
    state.primarySetup.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;
    if (state.primarySetup.riskReward < 1.0)
    { state.primarySetup.isValid = false; return true; }

    m_lastFired = TimeCurrent();
    return true;
  }
};

#endif
