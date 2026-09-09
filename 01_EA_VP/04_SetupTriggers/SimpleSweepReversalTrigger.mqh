#ifndef __EA_ROOT_SWEEPREVERSALTRIGGER_MQH__
#define __EA_ROOT_SWEEPREVERSALTRIGGER_MQH__

#include "..\Config\GlobalParameters.mqh"


//+------------------------------------------------------------------+
//| Sweep Reversal Trigger v6.0 — VP/Auction Data Collection         |
//| Hard gates: regime + tradeQuality + reversal signal present      |
//| Direction from spring/upthrust or VP position                    |
//+------------------------------------------------------------------+

class CSimpleSweepReversalTrigger : public CVPModuleBase
{
private:
  datetime m_lastFired;
  ETradingMode m_tradingMode;

  bool IsRegimeCompatible(int regime)
  {
    return (regime == REGIME_FAILED_AUCTION ||
            regime == REGIME_EXCESS ||
            regime == REGIME_TREND_EXHAUSTION ||
            regime == REGIME_BALANCED_ROTATION ||
            regime == REGIME_COMPRESSION);
  }

public:
  void SetMode(ETradingMode mode) { m_tradingMode = mode; }
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "SweepReversalTrigger");
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
    if (regime == REGIME_CHAOTIC) return true;
    if (!IsRegimeCompatible(regime)) return true;
    if (state.auctTradeQuality < 0.15) return true;

    // ─── Reversal signal must be present ────────────────────
    // ANY of: spring, upthrust, high failure score, or outside VA
    bool hasSpring = state.vpSpringDetected;
    bool hasUpthrust = state.vpUpthrustDetected;
    bool hasAuctionFail = (state.auctFailureScore > 0.40);
    bool outsideVA = !state.vpInsideVA;
    if (!hasSpring && !hasUpthrust && !hasAuctionFail && !outsideVA) return true;

    double bid = state.marketData.bid;
    double atr = state.marketData.atrProxy * state.marketData.pointSize; // ATR in PRICE
    if (atr <= 0) return true;

    // ─── Direction ──────────────────────────────────────────
    bool bullSweep = hasSpring || (bid < state.vpPOC && outsideVA);
    bool bearSweep = hasUpthrust || (bid > state.vpPOC && outsideVA);
    if (bullSweep && bearSweep)
    {
      // Disambiguate: price below POC = buy, above = sell
      if (state.vpPOC > 0)
      { if (bid < state.vpPOC) { bullSweep = true; bearSweep = false; }
        else { bullSweep = false; bearSweep = true; } }
      else return true;
    }
    if (!bullSweep && !bearSweep) return true;

    // ═══ FIRE SETUP ═══
    double thesis = state.auctFailureScore * 0.30 + state.auctReversalRiskScore * 0.25
                  + state.auctTradeQuality * 0.25 + (hasSpring || hasUpthrust ? 0.20 : 0.0);

    state.primarySetup.isValid = true;
    state.primarySetup.setupType = SETUP_SWEEP_REVERSAL;
    state.primarySetup.entryPrice = bid;
    state.primarySetup.detectedAt = TimeCurrent();
    state.winProbability = Clamp01(thesis);
    state.edgeGuardMultiplier = 1.0;

    // ─── SL ─────────────────────────────────────────────────
    if (bullSweep)
    {
      double sl = bid - atr * 1.0;
      double vpSupport = 0;
      if (state.vpBestHVN > 0 && state.vpBestHVN < bid) vpSupport = fmax(vpSupport, state.vpBestHVN);
      if (state.vpPOC > 0 && state.vpPOC < bid) vpSupport = fmax(vpSupport, state.vpPOC);
      if (state.vpVAL > 0 && state.vpVAL < bid) vpSupport = fmax(vpSupport, state.vpVAL);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN < bid) vpSupport = fmax(vpSupport, state.vpNearestHVN);
      if (vpSupport > 0 && bid - vpSupport > atr * 0.2 && bid - vpSupport < atr * 2.0) sl = vpSupport - atr * 0.1;
      state.primarySetup.stopLoss = sl;

      double tp = bid + atr * 2.0;
      if (state.auctTargetPrice > bid && state.auctTargetConfidence > 0.40) tp = state.auctTargetPrice;
      else if (state.vpPOC > bid) tp = state.vpPOC;
      else if (state.vpCompositePOC > bid) tp = state.vpCompositePOC;
      state.primarySetup.takeProfit = tp;
    }
    else
    {
      double sl = bid + atr * 1.0;
      double vpResist = DBL_MAX;
      if (state.vpBestHVN > 0 && state.vpBestHVN > bid) vpResist = fmin(vpResist, state.vpBestHVN);
      if (state.vpPOC > 0 && state.vpPOC > bid) vpResist = fmin(vpResist, state.vpPOC);
      if (state.vpVAH > 0 && state.vpVAH > bid) vpResist = fmin(vpResist, state.vpVAH);
      if (state.vpNearestHVN > 0 && state.vpNearestHVN > bid) vpResist = fmin(vpResist, state.vpNearestHVN);
      if (vpResist < DBL_MAX && vpResist - bid > atr * 0.2 && vpResist - bid < atr * 2.0) sl = vpResist + atr * 0.1;
      state.primarySetup.stopLoss = sl;

      double tp = bid - atr * 2.0;
      if (state.auctTargetPrice > 0 && state.auctTargetPrice < bid && state.auctTargetConfidence > 0.40) tp = state.auctTargetPrice;
      else if (state.vpPOC > 0 && state.vpPOC < bid) tp = state.vpPOC;
      else if (state.vpCompositePOC > 0 && state.vpCompositePOC < bid) tp = state.vpCompositePOC;
      state.primarySetup.takeProfit = tp;
    }

    double slDist = MathAbs(bid - state.primarySetup.stopLoss);
    double tpDist = MathAbs(state.primarySetup.takeProfit - bid);
    state.primarySetup.riskReward = (slDist > 0) ? tpDist / slDist : 2.0;
    if (state.primarySetup.riskReward < 0.8)
    { state.primarySetup.isValid = false; return true; }

    PrintFormat("[TRIGGER][%s] SWEEP_REVERSAL v6.0: thesis=%.2f %s regime=%d fake=%s RR=%.1f",
               m_symbol, thesis, bullSweep?"BULL":"BEAR", regime,
               (hasSpring||hasUpthrust)?"YES":"NO", state.primarySetup.riskReward);
    m_lastFired = TimeCurrent();
    return true;
  }
};

#endif
