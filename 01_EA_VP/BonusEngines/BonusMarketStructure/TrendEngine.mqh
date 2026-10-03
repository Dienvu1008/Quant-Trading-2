#ifndef __EA_ROOT_TRENDENGINE_MQH__
#define __EA_ROOT_TRENDENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| Trend Engine v4.0 — Auction‑Aware Trend Detector                  |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

class CTrendEngine : public CPipelineModuleBase
{
private:
  double m_trendStrength; // [0,1]
  int m_trendDirection;   // +1 bullish, -1 bearish, 0 neutral
  double m_ema20, m_ema50;
  datetime m_lastBarTime;
  double m_rawDiff; // ATR-normalized EMA difference

  CAuctionThesisManager m_thesisManager; // đánh giá sức khỏe luận điểm

  // ── Compute ATR from price data (returns price ATR) ────────────
  double ComputeATR(const MqlRates &rates[], int count, int period)
  {
    if (count < period + 1)
      return 0;
    double sum = 0;
    for (int i = count - period; i < count; i++)
      sum += MathAbs(rates[i].high - rates[i].low);
    return sum / period;
  }

  //+------------------------------------------------------------------+
  //| Structural context (v3 logic + thesis health từ v4.0)            |
  //+------------------------------------------------------------------+
  void ApplyStructuralContext(const SPipelineState &state,
                              double &qualityFactor,
                              int &direction,
                              double atrPrice)
  {
    // ── 1. VA Overlap Bias ─────────────────────────────────────
    int vaBias = state.vpVAOverlapBias;
    if (vaBias != 0 && direction != 0)
    {
      if ((vaBias == 1 && direction == 1) || (vaBias == -1 && direction == -1))
        qualityFactor *= 1.1;
      else if (direction != 0)
        qualityFactor *= 0.9;
    }

    // ── 2. Migration Confidence ────────────────────────────────
    if (state.vpMigrationConfidence > 0.6 && direction != 0)
      qualityFactor *= 1.05;

    // ── 3. Anchored breakout profile ───────────────────────────
    double breakoutPOC = state.vpBreakoutPOC;
    if (breakoutPOC > 0)
    {
      double bid = state.marketData.bid;
      if ((direction == 1 && bid > breakoutPOC) || (direction == -1 && bid < breakoutPOC))
        qualityFactor *= 1.08;
    }

    // ── 4. Best HVN ────────────────────────────────────────────
    if (state.vpBestHVN > 0 && direction != 0)
    {
      double bid = state.marketData.bid;
      double distATR = MathAbs(bid - state.vpBestHVN) / atrPrice;
      if (distATR > 1.0 && ((direction == 1 && bid > state.vpBestHVN) ||
                            (direction == -1 && bid < state.vpBestHVN)))
        qualityFactor *= 1.07;
    }

    // ── 5. Fake breakout traps ─────────────────────────────────
    if (state.vpUpthrustDetected || state.vpSpringDetected)
    {
      if (state.vpUpthrustDetected && direction == 1)
        qualityFactor *= 0.85;
      if (state.vpSpringDetected && direction == -1)
        qualityFactor *= 0.85;
    }

    // ── 6. Profile thinness ────────────────────────────────────
    if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3 && direction != 0)
      qualityFactor *= 1.06;

    // ── 7. Composite position alignment ────────────────────────
    int compPos = state.vpCompositePosition;
    if (direction == 1 && compPos == -1)
      qualityFactor *= 1.05;
    if (direction == -1 && compPos == 1)
      qualityFactor *= 1.05;

    // ── v4.0: Sức khỏe luận điểm ─────────────────────────────
    if (state.vpValid && direction != 0)
    {
      // Dùng ENTRY_TREND_CONTINUATION vì đây là engine phát hiện xu hướng
      if (m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
        m_thesisManager.InitTrade(ENTRY_TREND_CONTINUATION, atrPrice,
                                  state.auctRegimeConfidence, m_symbol);

      // thesisHealth removed: already accounted for in auction adjustment above
    }
  }

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "TrendEngine");
    m_trendStrength = 0;
    m_trendDirection = 0;
    m_ema20 = m_ema50 = 0;
    m_lastBarTime = 0;
    m_rawDiff = 0;
    m_thesisManager.Reset();
  }

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);

    int copied = state.marketData.h1Copied;
    if (copied < 50)
      return true;

    datetime currentBar = state.marketData.h1Rates[copied - 1].time;
    if (currentBar == m_lastBarTime && m_ema20 != 0)
    {
      OutputToState(state);
      return true;
    }
    m_lastBarTime = currentBar;

    // ── 1. Compute EMA 20/50 (unchanged) ──────────────────────
    double k20 = 2.0 / 21.0;
    double k50 = 2.0 / 51.0;

    if (m_ema20 == 0)
    {
      double sum20 = 0, sum50 = 0;
      for (int i = 0; i < 20; i++)
        sum20 += state.marketData.h1Rates[i].close;
      for (int i = 0; i < 50; i++)
        sum50 += state.marketData.h1Rates[i].close;
      m_ema20 = sum20 / 20.0;
      m_ema50 = sum50 / 50.0;
      for (int i = 20; i < copied; i++)
        m_ema20 = state.marketData.h1Rates[i].close * k20 + m_ema20 * (1.0 - k20);
      for (int i = 50; i < copied; i++)
        m_ema50 = state.marketData.h1Rates[i].close * k50 + m_ema50 * (1.0 - k50);
    }
    else if (copied >= 2)
    {
      double lastClose = state.marketData.h1Rates[copied - 2].close;
      m_ema20 = lastClose * k20 + m_ema20 * (1.0 - k20);
      m_ema50 = lastClose * k50 + m_ema50 * (1.0 - k50);
    }

    // ── 2. ATR (giữ nguyên công thức của bạn) ──────────────────
    double atrPrice = state.marketData.atrProxy * state.marketData.pointSize;
    if (atrPrice <= 0 || atrPrice < state.marketData.pointSize * 2)
      atrPrice = ComputeATR(state.marketData.h1Rates, copied, 14);
    if (atrPrice <= 0)
      atrPrice = state.marketData.pointSize * 10;

    m_rawDiff = (m_ema20 - m_ema50) / atrPrice;

    // ── 3. Base direction with deadzone ───────────────────────
    int baseDirection = 0;
    if (m_rawDiff > 0.3)
      baseDirection = 1;
    else if (m_rawDiff < -0.3)
      baseDirection = -1;

    // ── 4. Base strength ──────────────────────────────────────
    double rawStrength = Clamp01(MathAbs(m_rawDiff) / 1.0);

    // ── 5. v4.0: Bộ lọc regime cứng ───────────────────────────
    EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
    double regimeConf = state.auctRegimeConfidence;
    if (regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
        (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
    {
      // Hủy hoàn toàn tín hiệu xu hướng
      m_trendStrength = 0.0;
      m_trendDirection = 0;
      OutputToState(state);
      return true;
    }

    // ── 6. Auction / VP Qualification (giữ nguyên, bổ sung v4.0) ──
    double qualityFactor = 1.0;
    int adjustedDirection = baseDirection;

    // 6a. Original VP migration
    if (state.vpValid)
    {
      double vpDir = state.vpMigrationDirRaw;
      double vpScore = state.vpMigrationScore;
      if (vpDir == baseDirection && baseDirection != 0)
        qualityFactor = MathMax(qualityFactor, 1.0 + vpScore * 0.2);
      else if (vpDir != 0 && baseDirection != 0 && vpDir == -baseDirection)
        qualityFactor = MathMax(qualityFactor, 1.0 - vpScore * 0.3);
    }

    // 6b. Auction Regime
    if (regimeConf > 0)
    {
      if (regime == REGIME_TREND_CONTINUATION || regime == REGIME_TREND_INITIATION)
        qualityFactor *= 1.0 + 0.25 * regimeConf;
      else if (regime == REGIME_BALANCED_ROTATION)
        qualityFactor *= 0.95;
      else if (regime == REGIME_TREND_EXHAUSTION || regime == REGIME_FAILED_AUCTION)
        qualityFactor *= 1.0 - 0.3 * regimeConf;

      if (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6)
        adjustedDirection = 0;
    }

    // 6c. Scores
    if (state.auctAcceptanceScore > 0.7)
      qualityFactor *= 0.9;
    if (state.auctExhaustionScore > 0.6)
      qualityFactor *= 0.9;
    if (state.auctContinuationScore > 0.7 && baseDirection != 0)
      qualityFactor *= 1.1;

    // 6d. DevPOC
    if (MathAbs(state.vpDevPOCSlope) > 0.02)
    {
      double devDir = (state.vpDevPOCSlope > 0) ? 1 : -1;
      if (devDir == baseDirection)
        qualityFactor *= 1.1;
      else if (baseDirection != 0 && devDir == -baseDirection)
        qualityFactor *= 0.85;
    }

    // 6e. Composite context (v4.0: thêm xác nhận đa khung thời gian)
    if (state.vpValid && atrPrice > 0)
    {
      double bid = state.marketData.bid;
      // Vị trí so với composite POC
      if (bid > state.vpCompositePOC && baseDirection == 1)
        qualityFactor *= 1.1;
      else if (bid < state.vpCompositePOC && baseDirection == -1)
        qualityFactor *= 1.1;
      else if (baseDirection != 0)
        qualityFactor *= 0.95;

      // Độ rộng composite
      double compWidth = state.vpCompositeVAH - state.vpCompositeVAL;
      double compWidthATR = compWidth / atrPrice;
      if (compWidthATR < 1.5)
        qualityFactor *= 1.05;

      // v4.0: Xác nhận vượt biên composite
      if ((baseDirection == 1 && bid > state.vpCompositeVAH) ||
          (baseDirection == -1 && bid < state.vpCompositeVAL))
        qualityFactor *= 1.10; // xu hướng mạnh khi vượt hẳn composite
      else if ((baseDirection == 1 && bid < state.vpCompositeVAL) ||
               (baseDirection == -1 && bid > state.vpCompositeVAH))
        qualityFactor *= 0.85; // xu hướng yếu khi giá ngược phía composite
    }

    // ── 7. Structural V3 context (đã có thesis health trong đó) ──
    ApplyStructuralContext(state, qualityFactor, adjustedDirection, atrPrice);

    // ── 8. Final strength & direction ─────────────────────────
    m_trendStrength = Clamp01(rawStrength * Clamp01(qualityFactor));
    m_trendDirection = adjustedDirection;
    if (m_trendStrength < 0.2)
      m_trendDirection = 0;

    OutputToState(state);
    return true;
  }

  void OutputToState(SPipelineState &state)
  {
    state.structure.trendStrength = m_trendStrength;
    if (m_trendDirection > 0)
      state.structure.structureBias = 0.65 + m_trendStrength * 0.15;
    else if (m_trendDirection < 0)
      state.structure.structureBias = 0.35 - m_trendStrength * 0.15;
  }

  int TrendDirection() const { return m_trendDirection; }
  double TrendStrength() const { return m_trendStrength; }
  bool IsBullish() const { return m_trendDirection > 0; }
  bool IsBearish() const { return m_trendDirection < 0; }
};

#endif