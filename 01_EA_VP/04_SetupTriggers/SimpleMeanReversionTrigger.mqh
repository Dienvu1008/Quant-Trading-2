#ifndef __EA_ROOT_MEANREVERSIONTRIGGER_MQH__
#define __EA_ROOT_MEANREVERSIONTRIGGER_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Mean Reversion Trigger v6.0 — VP/Auction Data Collection         |
//| Hard gates: regime (balanced/compression) + tradeQuality         |
//| Direction: price position relative to VA (above VAH = sell,      |
//|            below VAL = buy, near boundary = trigger)             |
//+------------------------------------------------------------------+

class CSimpleMeanReversionTrigger : public CVPModuleBase
{
private:
  datetime m_lastFired;
  ETradingMode m_tradingMode;

public:
  void SetMode(ETradingMode mode) { m_tradingMode = mode; }
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "MeanReversionTrigger");
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
    EAuctionRegime auctRegime = (EAuctionRegime)state.auctRegime;
    if (auctRegime == REGIME_CHAOTIC || auctRegime == REGIME_EXCESS) return true;
    // Mean reversion works in balanced/compression/re-accumulation
    if (auctRegime != REGIME_BALANCED_ROTATION &&
        auctRegime != REGIME_COMPRESSION &&
        auctRegime != REGIME_RE_ACCUMULATION) return true;
    if (state.auctTradeQuality < 0.15) return true;

    double bid = state.marketData.bid;
    double atr = state.marketData.atrProxy * state.marketData.pointSize; // ATR in PRICE
    if (atr <= 0) return true;
    if (state.vpVAH <= 0 || state.vpVAL <= 0) return true;

    // ─── Direction: price position relative to VA ───────────
    // Near/above VAH = overbought → sell to POC
    // Near/below VAL = oversold → buy to POC
    double vaRange = state.vpVAH - state.vpVAL;
    if (vaRange <= 0) return true;

    double relPos = (bid - state.vpVAL) / vaRange; // 0 = at VAL, 1 = at VAH
    bool oversold = (relPos < 0.25) || (bid < state.vpVAL);
    bool overbought = (relPos > 0.75) || (bid > state.vpVAH);
    if (!oversold && !overbought) return true;

    // ═══ FIRE SETUP ═══
    double thesis = state.auctBalanceScore * 0.40
                  + (1.0 - state.auctContinuationScore) * 0.30
                  + state.auctTradeQuality * 0.30;

    state.primarySetup.isValid = true;
    state.primarySetup.setupType = SETUP_MEAN_REVERSION;
    state.primarySetup.entryPrice = bid;
    state.primarySetup.detectedAt = TimeCurrent();
    state.winProbability = Clamp01(thesis);
    state.edgeGuardMultiplier = 1.0;

    // ─── SL & TP ────────────────────────────────────────────
    if (oversold) // BUY toward POC
    {
      double sl = bid - atr * 0.8;
      double vpSupport = 0;
      if (state.vpBestHVN > 0 && state.vpBestHVN < bid) vpSupport = fmax(vpSupport, state.vpBestHVN);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN < bid) vpSupport = fmax(vpSupport, state.vpNearestHVN);
      if (state.vpVAL > 0 && state.vpVAL < bid) vpSupport = fmax(vpSupport, state.vpVAL);
      if (vpSupport > 0 && bid - vpSupport > atr * 0.2) sl = vpSupport - atr * 0.1;
      state.primarySetup.stopLoss = sl;

      // TP: revert to POC or nearest HVN above
      double tp = state.vpPOC > bid ? state.vpPOC : bid + atr * 1.5;
      if (state.auctTargetPrice > bid && state.auctTargetConfidence > 0.40 && state.auctTargetPrice - bid < atr * 3.0)
        tp = state.auctTargetPrice;
      state.primarySetup.takeProfit = tp;
    }
    else // SELL toward POC
    {
      double sl = bid + atr * 0.8;
      double vpResist = DBL_MAX;
      if (state.vpBestHVN > 0 && state.vpBestHVN > bid) vpResist = fmin(vpResist, state.vpBestHVN);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN > bid) vpResist = fmin(vpResist, state.vpNearestHVN);
      if (state.vpVAH > 0 && state.vpVAH > bid) vpResist = fmin(vpResist, state.vpVAH);
      if (vpResist < DBL_MAX && vpResist - bid > atr * 0.2) sl = vpResist + atr * 0.1;
      state.primarySetup.stopLoss = sl;

      double tp = (state.vpPOC > 0 && state.vpPOC < bid) ? state.vpPOC : bid - atr * 1.5;
      if (state.auctTargetPrice > 0 && state.auctTargetPrice < bid && state.auctTargetConfidence > 0.40 && bid - state.auctTargetPrice < atr * 3.0)
        tp = state.auctTargetPrice;
      state.primarySetup.takeProfit = tp;
    }

    double slDist = MathAbs(bid - state.primarySetup.stopLoss);
    double tpDist = MathAbs(state.primarySetup.takeProfit - bid);
    state.primarySetup.riskReward = (slDist > 0) ? tpDist / slDist : 1.5;
    if (state.primarySetup.riskReward < 0.8)
    { state.primarySetup.isValid = false; return true; }

    PrintFormat("[TRIGGER][%s] MEAN_REVERSION v6.0: %s thesis=%.2f regime=%d relPos=%.2f RR=%.1f",
               m_symbol, oversold?"BUY":"SELL", thesis, (int)auctRegime, relPos, state.primarySetup.riskReward);
    m_lastFired = TimeCurrent();
    return true;
  }
};

#endif
