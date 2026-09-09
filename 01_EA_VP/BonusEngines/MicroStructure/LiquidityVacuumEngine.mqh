#ifndef __EA_ROOT_LIQUIDITYVACUUMENGINE_MQH__
#define __EA_ROOT_LIQUIDITYVACUUMENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Liquidity Vacuum Engine v4.0 — Auction‑Enhanced Thin‑Zone B/O     |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

class CLiquidityVacuumEngine : public CPipelineModuleBase
{
private:
  double m_vacuumScore;
  double m_prevClose;
  double m_prevLVN;
  double m_prevNakedPOC;
  bool m_prevVpValid;
  double m_directionBias;

  CAuctionThesisManager m_thesisManager; // đánh giá sức khỏe luận điểm

  //+------------------------------------------------------------------+
  //| Strong Marubozu detection (giữ nguyên)                           |
  //+------------------------------------------------------------------+
  bool IsStrongMarubozu(const MqlRates &bar, double atrPrice)
  {
    double range = bar.high - bar.low;
    if (range <= 0)
      return false;
    double body = MathAbs(bar.close - bar.open);
    return (body / range > 0.7) && (range > atrPrice * 0.5);
  }

  //+------------------------------------------------------------------+
  //| Structural context (v3 logic + thesis health từ v4.0)            |
  //+------------------------------------------------------------------+
  void ApplyStructuralContext(const SPipelineState &state,
                              double &qualityMult,
                              double &direction,
                              double atrPrice)
  {
    double bid = state.marketData.bid;
    // Anchored profiles near vacuum zone
    double nearestAnchorDist = 1e18;
    double anchorPrices[] = {state.vpRangePOC, state.vpBreakoutPOC, state.vpPullbackPOC};
    for (int i = 0; i < 3; i++)
    {
      if (anchorPrices[i] > 0)
      {
        double d = MathAbs(bid - anchorPrices[i]) / atrPrice;
        if (d < nearestAnchorDist)
          nearestAnchorDist = d;
      }
    }
    if (nearestAnchorDist < 0.5)
      qualityMult *= 1.2;

    // Best HVN as magnet
    if (state.vpBestHVN > 0)
    {
      double dist = MathAbs(bid - state.vpBestHVN) / atrPrice;
      if (dist < 0.4)
      {
        qualityMult *= 1.1;
        if (state.vpBestHVN > bid)
          direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
        else if (state.vpBestHVN < bid)
          direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
      }
    }

    // Fake breakout detection
    if (state.vpUpthrustDetected || state.vpSpringDetected)
    {
      qualityMult *= 1.25;
      if (state.vpUpthrustDetected)
        direction = MathMin(direction, -0.6);
      if (state.vpSpringDetected)
        direction = MathMax(direction, 0.6);
    }

    // Thin profile
    if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
      qualityMult *= 1.1;

    // VA Overlap bias
    int vaBias = state.vpVAOverlapBias;
    if (vaBias != 0 && MathAbs(state.vpDevPOCSlope) < 0.02)
    {
      double vaDir = (vaBias == 1) ? 0.7 : -0.7;
      if (direction == 0)
        direction = vaDir;
      else
        direction = direction * 0.6 + vaDir * 0.4;
    }

    // Migration confidence
    if (state.vpMigrationConfidence > 0.6 && direction != 0)
      direction = MathMax(-1.0, MathMin(1.0, direction * 1.2));

    // ── v4.0: Sức khỏe luận điểm ─────────────────────────────
    if (state.vpValid)
    {
      if (m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
        m_thesisManager.InitTrade(ENTRY_BREAKOUT, atrPrice, state.auctRegimeConfidence, m_symbol);

      SThesisOutput thesisOut = m_thesisManager.Evaluate(state, 0.0, atrPrice);
      double health = thesisOut.thesis.thesisHealth;

      // Điều chỉnh quality: luận điểm yếu làm giảm độ tin cậy của vacuum
      qualityMult *= (0.8 + health * 0.4);

      // Nếu health rất thấp, trung hòa direction
      if (health < 0.3 && direction != 0)
        direction *= 0.5;
    }
  }

  //+------------------------------------------------------------------+
  //| Context adjustment (v4.0: thêm bộ lọc regime cứng + composite)  |
  //+------------------------------------------------------------------+
  void ComputeContextAdjustment(const SPipelineState &state,
                                double &qualityMult,
                                double &direction,
                                double atrPrice)
  {
    qualityMult = 1.0;
    direction = 0.0;

    // ── v4.0: Bộ lọc regime cứng ─────────────────────────────
    EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
    double regimeConf = state.auctRegimeConfidence;
    if (regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
        (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
    {
      qualityMult = 0.0; // hủy tín hiệu vacuum
      return;
    }

    // ── 1. Regime filter ──────────────────────────────────────
    if (regime == REGIME_TREND_CONTINUATION || regime == REGIME_TREND_INITIATION)
      qualityMult *= 1.0 + 0.3 * regimeConf;
    else if (regime == REGIME_BALANCED_ROTATION)
      qualityMult *= 0.9;
    else if (regime == REGIME_TREND_EXHAUSTION)
      qualityMult *= 0.8;
    else if (regime == REGIME_FAILED_AUCTION)
      qualityMult *= 1.1;

    // ── 2. Acceptance / Exhaustion / Continuation ────────────
    if (state.auctAcceptanceScore > 0.65)
      qualityMult *= 0.85;
    if (state.auctExhaustionScore > 0.6)
      qualityMult *= 0.8;
    if (state.auctContinuationScore > 0.75)
      qualityMult *= 1.1;

    // ── 3. Directional bias (giữ nguyên) ──────────────────────
    if (MathAbs(state.vpDevPOCSlope) > 0.03)
      direction = (state.vpDevPOCSlope > 0) ? 1.0 : -1.0;
    else
    {
      if (m_prevLVN != 0 && state.vpValid)
      {
        double currClose = state.marketData.m1Rates[state.marketData.m1Copied - 1].close;
        if (m_prevClose < m_prevLVN && currClose > m_prevLVN)
          direction = 1.0;
        else if (m_prevClose > m_prevLVN && currClose < m_prevLVN)
          direction = -1.0;
      }
    }

    if (state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.5)
    {
      if (state.marketData.bid < state.vpNearestNakedPOC)
        direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
      else
        direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
    }

    // ── 4. Composite profile (v4.0: giữ nguyên, xác nhận đa khung) ──
    if (state.vpValid && atrPrice > 0)
    {
      double bid = state.marketData.bid;
      double distToTop = (state.vpCompositeVAH - bid) / atrPrice;
      double distToBot = (bid - state.vpCompositeVAL) / atrPrice;
      if (MathMin(distToTop, distToBot) < 0.3)
      {
        qualityMult *= 1.15;
        // Nếu vacuum ngay biên composite, thêm xác nhận hướng
        if (distToTop < distToBot)
          direction = (direction == 0) ? 1.0 : (direction > 0 ? direction : 0.5);
        else
          direction = (direction == 0) ? -1.0 : (direction < 0 ? direction : -0.5);
      }
    }

    // ── 5. Structural V3 context (đã có thesis bên trong) ────
    ApplyStructuralContext(state, qualityMult, direction, atrPrice);

    direction = MathMax(-1.0, MathMin(1.0, direction));
  }

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "LiquidityVacuumEngine");
    m_vacuumScore = 0;
    m_prevClose = 0;
    m_prevLVN = 0;
    m_prevNakedPOC = 0;
    m_prevVpValid = false;
    m_directionBias = 0.0;
    m_thesisManager.Reset();
  }

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);

    int copied = state.marketData.m1Copied;
    if (copied < 2)
      return true;

    // Giữ nguyên ATR calculation
    double pointSize = state.marketData.pointSize;
    double atrPrice = state.marketData.atrProxy * pointSize;
    if (atrPrice <= 0)
      atrPrice = 0.00001;

    const MqlRates currBar = state.marketData.m1Rates[copied - 1];
    double currClose = currBar.close;

    if (m_prevClose == 0)
    {
      m_prevClose = currClose;
      m_prevLVN = state.vpValid ? state.vpNearestLVN : 0;
      m_prevNakedPOC = state.vpValid ? state.vpNearestNakedPOC : 0;
      m_prevVpValid = state.vpValid;
      return true;
    }

    bool vpNow = state.vpValid && m_prevVpValid;
    double lvn = state.vpNearestLVN;
    double nakedPOC = state.vpNearestNakedPOC;

    bool currIsMarubozu = IsStrongMarubozu(currBar, atrPrice);

    bool crossedLVN = false;
    bool crossedNakedPOC = false;
    if (vpNow)
    {
      crossedLVN = (m_prevClose <= m_prevLVN && currClose > m_prevLVN) || (m_prevClose >= m_prevLVN && currClose < m_prevLVN);
      crossedNakedPOC = (m_prevNakedPOC != 0) &&
                        ((m_prevClose <= m_prevNakedPOC && currClose > m_prevNakedPOC) || (m_prevClose >= m_prevNakedPOC && currClose < m_prevNakedPOC));
    }

    double baseScore = 0;
    if (currIsMarubozu && (crossedLVN || crossedNakedPOC))
      baseScore = 1.0;
    else if (currIsMarubozu)
    {
      double distToLVN_ATR = state.vpValid ? state.vpDistToLVN_ATR : 999;
      double distToNaked_ATR = state.vpValid ? state.vpDistToNakedPOC_ATR : 999;
      double minDistATR = MathMin(distToLVN_ATR, distToNaked_ATR);
      if (minDistATR < 0.3)
        baseScore = 0.8;
      else if (minDistATR < 0.7)
        baseScore = 0.5;
      else
        baseScore = 0.3;
    }
    else
      baseScore = MathMax(0.0, m_vacuumScore - 0.1);

    double qualityMult = 1.0;
    double direction = 0.0;
    if (state.vpValid && baseScore > 0.2)
      ComputeContextAdjustment(state, qualityMult, direction, atrPrice);

    m_vacuumScore = Clamp01(baseScore * qualityMult);
    m_directionBias = direction;

    m_prevClose = currClose;
    m_prevLVN = lvn;
    m_prevNakedPOC = nakedPOC;
    m_prevVpValid = state.vpValid;

    state.microstructure.liquidityVacuumScore = m_vacuumScore;

    if (m_vacuumScore > 0.6 && state.pendingEventCount < 4)
    {
      int idx = state.pendingEventCount++;
      state.pendingEventTypes[idx] = (int)EVENT_LIQUIDITY_VACUUM;
      state.pendingEventScores[idx] = m_vacuumScore;
      state.pendingEventDirs[idx] = m_directionBias;
    }

    return true;
  }

  double VacuumScore(void) const { return m_vacuumScore; }
  double DirectionBias(void) const { return m_directionBias; }
};

#endif
