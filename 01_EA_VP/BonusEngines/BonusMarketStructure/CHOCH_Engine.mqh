#ifndef __EA_ROOT_CHOCH_ENGINE_MQH__
#define __EA_ROOT_CHOCH_ENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "SwingEngine.mqh"
#include "..\VolumeProfile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| CHOCH Engine v4.0 — Auction‑Enhanced Change of Character          |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

enum ECHOCHLifecycle
{
  CHOCH_LIFECYCLE_NONE = 0,
  CHOCH_LIFECYCLE_PROBE = 1,
  CHOCH_LIFECYCLE_REVERSAL_TEST = 2,
  CHOCH_LIFECYCLE_ACCEPTED = 3,
  CHOCH_LIFECYCLE_CONFIRMED = 4,
  CHOCH_LIFECYCLE_FAILED = 5
};

#define CHOCH_FAILURE_COOLDOWN_SEC 7200 // 2 hours

class CCHOCH_Engine : public CPipelineModuleBase
{
private:
  ECHOCHLifecycle m_lifecycle;
  double m_chochLevel;
  bool m_bullishReversal;
  datetime m_probeTime;
  datetime m_lastBarTime;
  int m_reversalBars;
  int m_reversalThreshold;
  double m_exhaustionScore;
  double m_rejectionScore;
  double m_chochQualityScore;
  double m_followThroughScore;
  datetime m_lastFailedTime;
  double m_lastFailedLevel;
  double m_chochScore;

  // ── Các thành phần mới cho v4.0 ───────────────────────────────
  CAuctionThesisManager m_thesisManager; // đánh giá sức khỏe luận điểm
  int m_acceptedPersistence;             // số nến chờ composite

  //+------------------------------------------------------------------+
  //| Structural Multiplier – giữ nguyên logic gốc, chỉ thêm comment   |
  //+------------------------------------------------------------------+
  double GetStructuralMultiplier(const SPipelineState &state, double atrPrice) const
  {
    if (!state.vpValid)
      return 1.0;

    double mult = 1.0;
    double bid = state.marketData.bid;

    // 1. Vị trí so với Value Area
    if (!state.vpInsideVA)
      mult += 0.07;
    else
    {
      if (MathAbs(state.vpPriceVsVA) > 0.8)
        mult += 0.04;
      else if (MathAbs(state.vpPriceVsPOC) < 0.15)
        mult -= 0.05;
    }

    // 2. Khoảng trống thanh khoản / tắc nghẽn
    if (state.vpDistToLVN_ATR < 0.5)
      mult += 0.08;
    if (state.vpDistToHVN_ATR < 0.4)
      mult -= 0.08;

    // 3. Chế độ đấu giá
    int regime = state.auctRegime;
    double regimeConf = state.auctRegimeConfidence;
    if (regime == (int)REGIME_TREND_EXHAUSTION || regime == (int)REGIME_FAILED_AUCTION)
      mult += 0.12 * regimeConf;
    else if (regime == (int)REGIME_BALANCED_ROTATION)
      mult += 0.05;
    else if (regime == (int)REGIME_TREND_CONTINUATION || regime == (int)REGIME_TREND_INITIATION)
    {
      if (state.auctContinuationScore > 0.6)
        mult -= 0.12;
      else
        mult -= 0.06;
    }

    // 4. DevPOC & Di cư
    double slope = state.vpDevPOCSlope;
    if (MathAbs(slope) > 0.02)
    {
      if ((m_bullishReversal && slope > 0) || (!m_bullishReversal && slope < 0))
        mult += 0.10;
      else
        mult -= 0.10;
    }

    double migScore = state.vpMigrationScore;
    double migDir = state.vpMigrationDirRaw;
    if (migScore > 0.3)
    {
      if ((m_bullishReversal && migDir > 0) || (!m_bullishReversal && migDir < 0))
        mult += 0.08;
      else
        mult -= 0.08;
    }

    // 5. Chấp nhận / Thất bại
    if (state.auctAcceptanceScore > 0.65)
      mult += 0.06;
    else if (state.auctAcceptanceScore < 0.25)
      mult -= 0.06;
    if (state.auctFailureScore > 0.4)
      mult -= 0.07;

    // 6. Composite Profile
    if (state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
    {
      bool nearBoundary = (MathAbs(bid - state.vpCompositeVAH) < atrPrice * 0.5) ||
                          (MathAbs(bid - state.vpCompositeVAL) < atrPrice * 0.5);
      if (nearBoundary)
        mult += 0.10;
    }

    // 7. Naked POC
    if (state.vpNearestNakedPOC > 0 && state.vpDistToNakedPOC_ATR < 0.7)
    {
      bool towardNaked = m_bullishReversal
                             ? (state.vpNearestNakedPOC > bid)
                             : (state.vpNearestNakedPOC < bid);
      if (towardNaked)
        mult += 0.07;
    }

    // 8. Hấp thụ / Kiệt sức (flow)
    if (state.flow.absorptionScore > 0.6)
      mult += 0.06;
    if (state.flow.exhaustionScore > 0.5)
      mult += 0.05;

    // 9. Profile neo
    if (state.vpPullbackPOC > 0 && MathAbs(bid - state.vpPullbackPOC) < atrPrice * 0.5)
      mult += 0.10;
    if (state.vpBreakoutPOC > 0 && MathAbs(bid - state.vpBreakoutPOC) < atrPrice * 0.5)
      mult += 0.12;
    if (state.vpRangePOC > 0 && MathAbs(bid - state.vpRangePOC) < atrPrice * 0.5)
      mult += 0.08;

    // 10. Best HVN
    if (state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) < atrPrice * 0.3)
      mult += 0.10;

    // 11. Bẫy phá vỡ giả
    if ((m_bullishReversal && state.vpSpringDetected) || (!m_bullishReversal && state.vpUpthrustDetected))
      mult += 0.18;
    else if ((m_bullishReversal && state.vpUpthrustDetected) || (!m_bullishReversal && state.vpSpringDetected))
      mult -= 0.15;

    // 12. Độ mỏng profile
    if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
      mult += 0.06;

    // 13. VA Overlap bias
    int vaBias = state.vpVAOverlapBias;
    if ((m_bullishReversal && vaBias == 1) || (!m_bullishReversal && vaBias == -1))
      mult += 0.08;
    else if ((m_bullishReversal && vaBias == -1) || (!m_bullishReversal && vaBias == 1))
      mult -= 0.06;

    // 14. Migration confidence
    if (state.vpMigrationConfidence > 0.5)
      mult += 0.05;

    return MathMax(0.75, MathMin(1.30, mult));
  }

  // ─── Các hàm phụ trợ giữ nguyên ──────────────────────────────────
  double ComputeExhaustionEvidence(const SPipelineState &state)
  {
    double revPressure = state.latentRaw.reversalPressure;
    double flowExhaust = state.flow.exhaustionScore;
    double dirWeakness = 1.0 - state.latentRaw.directionalPersistence;
    double deltaDiv = 0.0;
    if (m_bullishReversal && state.flow.bullishDivergence)
      deltaDiv = 0.8;
    if (!m_bullishReversal && state.flow.bearishDivergence)
      deltaDiv = 0.8;
    return Clamp01(revPressure * 0.35 + flowExhaust * 0.25 + dirWeakness * 0.20 + deltaDiv * 0.20);
  }

  double ComputeRejectionQuality(const SPipelineState &state)
  {
    double rejectBlock = state.smartMoney.rejectionBlockScore;
    double sweep = state.liquidity.sweepScore;
    double discount = state.liquidity.premiumDiscountScore;
    double extremity = MathAbs(discount - 0.5) * 2.0;
    double compression = state.microstructure.compressionScore;
    return Clamp01(rejectBlock * 0.30 + sweep * 0.30 + extremity * 0.20 + compression * 0.20);
  }

  double ComputeReversalFollowThrough(const SPipelineState &state, double atrPrice)
  {
    int h1Bars = state.marketData.h1Copied;
    if (h1Bars < 4)
      return 0.0;
    if (atrPrice <= 0)
      return 0.0;
    double lastClose = state.marketData.h1Rates[h1Bars - 2].close;
    double dist = m_bullishReversal ? (lastClose - m_chochLevel) : (m_chochLevel - lastClose);
    double distNorm = Clamp01(dist / (atrPrice * 1.2));
    double bOpen = state.marketData.h1Rates[h1Bars - 2].open;
    double bClose = state.marketData.h1Rates[h1Bars - 2].close;
    double bRange = state.marketData.h1Rates[h1Bars - 2].high - state.marketData.h1Rates[h1Bars - 2].low;
    double bodyRatio = (bRange > 0) ? Clamp01(MathAbs(bClose - bOpen) / bRange) : 0.5;
    double participation = state.latentRaw.participationQuality;
    return distNorm * 0.35 + bodyRatio * 0.30 + participation * 0.35;
  }

  //+------------------------------------------------------------------+
  //| Chất lượng CHOCH – v4.0: thêm thesisHealth & composite           |
  //+------------------------------------------------------------------+
  double ComputeQualityScore(const SPipelineState &state, double atrPrice)
  {
    double raw = m_exhaustionScore * 0.30 + m_rejectionScore * 0.25 + m_followThroughScore * 0.25 + Clamp01((double)m_reversalBars / 3.0) * 0.20;

    double vpMult = GetStructuralMultiplier(state, atrPrice);
    double baseScore = Clamp01(raw * vpMult);

    // ── Sức khỏe luận điểm từ AuctionThesisManager ──
    double thesisHealth = 0.5;
    if (state.vpValid)
    {
      // Khởi tạo nếu chưa, dùng ENTRY_SWEEP_REVERSAL cho đảo chiều
      if (m_thesisManager.GetArchetype() == ENTRY_UNKNOWN)
        m_thesisManager.InitTrade(ENTRY_SWEEP_REVERSAL, atrPrice, state.auctRegimeConfidence, m_symbol);

      SThesisOutput thesisOut = m_thesisManager.Evaluate(state, 0.0, atrPrice);
      thesisHealth = thesisOut.thesis.thesisHealth;
    }

    // ── Thưởng composite (nếu đã vượt) ──
    double compositeBonus = 0.0;
    if (state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
    {
      bool outsideComp = m_bullishReversal
                             ? (state.marketData.bid > state.vpCompositeVAH)
                             : (state.marketData.bid < state.vpCompositeVAL);
      compositeBonus = outsideComp ? 0.10 : -0.10;
    }

    // Kết hợp: base 50%, thesis 30%, composite+base offset 20%
    return Clamp01(baseScore * 0.5 + thesisHealth * 0.30 + (0.5 + compositeBonus) * 0.20);
  }

  bool IsInCooldown(double level)
  {
    if (m_lastFailedTime == 0)
      return false;
    if (MathAbs(level - m_lastFailedLevel) > level * 0.002)
      return false;
    return (TimeCurrent() - m_lastFailedTime < CHOCH_FAILURE_COOLDOWN_SEC);
  }

  void TransitionToFailed(SPipelineState &state)
  {
    m_lastFailedTime = TimeCurrent();
    m_lastFailedLevel = m_chochLevel;
    m_lifecycle = CHOCH_LIFECYCLE_NONE;
    m_chochQualityScore = 0;
    m_chochScore = 0;
    m_followThroughScore = 0;
    m_reversalBars = 0;
    m_acceptedPersistence = 0;
    m_thesisManager.Reset();
  }

  void EmitEvent(SPipelineState &state, int eventType, double score, int dir)
  {
    if (state.pendingEventCount < 4)
    {
      int idx = state.pendingEventCount++;
      state.pendingEventTypes[idx] = eventType;
      state.pendingEventScores[idx] = score;
      state.pendingEventDirs[idx] = dir;
    }
  }

  //+------------------------------------------------------------------+
  //| Bộ lọc regime cứng – chỉ cho phép CHOCH trong môi trường phù hợp|
  //+------------------------------------------------------------------+
  bool IsRegimeAllowedForCHOCH(const SPipelineState &state)
  {
    EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
    double conf = state.auctRegimeConfidence;

    if (regime == REGIME_CHAOTIC || regime == REGIME_EXCESS)
      return false;
    if (regime == REGIME_FAILED_AUCTION && conf > 0.6)
      return false;
    return true;
  }

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "CHOCH_Engine");
    m_lifecycle = CHOCH_LIFECYCLE_NONE;
    m_chochLevel = 0;
    m_bullishReversal = false;
    m_probeTime = 0;
    m_lastBarTime = 0;
    m_reversalBars = 0;
    m_reversalThreshold = 2;
    m_exhaustionScore = 0;
    m_rejectionScore = 0;
    m_chochQualityScore = 0;
    m_followThroughScore = 0;
    m_lastFailedTime = 0;
    m_lastFailedLevel = 0;
    m_chochScore = 0;
    m_acceptedPersistence = 0;
    m_thesisManager.Reset();
  }

  void Detect(const CSwingEngine &swings, double currentPrice, bool wasDowntrend) {}

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);

    int h1Bars = state.marketData.h1Copied;
    int hiCount = state.structure.swingHighCount;
    int loCount = state.structure.swingLowCount;
    double bid = state.marketData.bid;

    // Giữ nguyên công thức ATR của hệ thống
    double pointSize = state.marketData.pointSize;
    double atrPrice = state.marketData.atrProxy * pointSize;
    if (h1Bars < 5 || atrPrice <= 0)
    {
      WriteState(state);
      return true;
    }

    datetime currentBarTime = state.marketData.h1Rates[h1Bars - 1].time;
    bool isNewBar = (currentBarTime != m_lastBarTime);
    m_lastBarTime = currentBarTime;

    double lastClose = state.marketData.h1Rates[h1Bars - 2].close;

    // ── Bộ lọc regime cứng (v4.0) ──
    if (!IsRegimeAllowedForCHOCH(state))
    {
      if (m_lifecycle != CHOCH_LIFECYCLE_NONE)
        TransitionToFailed(state);
      WriteState(state);
      return true;
    }

    bool wasDowntrend = (state.structure.structureBias < 0.42);
    bool wasUptrend = (state.structure.structureBias > 0.58);

    switch (m_lifecycle)
    {
    case CHOCH_LIFECYCLE_NONE:
    {
      if (wasDowntrend && hiCount >= 1)
      {
        double swHigh = state.structure.swingHighs[hiCount - 1].price;
        if (!IsInCooldown(swHigh) && bid > swHigh + atrPrice * 0.03)
        {
          m_lifecycle = CHOCH_LIFECYCLE_PROBE;
          m_chochLevel = swHigh;
          m_bullishReversal = true;
          m_probeTime = TimeCurrent();
          m_reversalBars = 0;
          m_acceptedPersistence = 0;
        }
      }
      if (m_lifecycle == CHOCH_LIFECYCLE_NONE && wasUptrend && loCount >= 1)
      {
        double swLow = state.structure.swingLows[loCount - 1].price;
        if (!IsInCooldown(swLow) && bid < swLow - atrPrice * 0.03)
        {
          m_lifecycle = CHOCH_LIFECYCLE_PROBE;
          m_chochLevel = swLow;
          m_bullishReversal = false;
          m_probeTime = TimeCurrent();
          m_reversalBars = 0;
          m_acceptedPersistence = 0;
        }
      }
      break;
    }

    case CHOCH_LIFECYCLE_PROBE:
    {
      bool closedBeyond = m_bullishReversal
                              ? (lastClose > m_chochLevel)
                              : (lastClose < m_chochLevel);
      if (closedBeyond && isNewBar)
      {
        m_exhaustionScore = ComputeExhaustionEvidence(state);
        m_rejectionScore = ComputeRejectionQuality(state);
        if (m_exhaustionScore >= 0.15)
        {
          m_lifecycle = CHOCH_LIFECYCLE_REVERSAL_TEST;
          m_reversalBars = 1;
        }
        else
        {
          TransitionToFailed(state);
        }
      }
      else
      {
        bool failed = m_bullishReversal
                          ? (bid < m_chochLevel * 0.997)
                          : (bid > m_chochLevel * 1.003);
        if (failed)
          TransitionToFailed(state);
      }
      break;
    }

    case CHOCH_LIFECYCLE_REVERSAL_TEST:
    {
      if (!isNewBar)
        break;
      bool closedBeyond = m_bullishReversal
                              ? (lastClose > m_chochLevel)
                              : (lastClose < m_chochLevel);
      if (closedBeyond)
      {
        m_reversalBars++;
      }
      else
      {
        double distBack = m_bullishReversal
                              ? (m_chochLevel - lastClose)
                              : (lastClose - m_chochLevel);
        if (distBack > atrPrice * 0.1)
        {
          TransitionToFailed(state);
          break;
        }
        else
          m_reversalBars = 0;
      }
      if (m_reversalBars >= m_reversalThreshold)
      {
        m_followThroughScore = ComputeReversalFollowThrough(state, atrPrice);
        m_lifecycle = CHOCH_LIFECYCLE_ACCEPTED;
        m_acceptedPersistence = 0; // reset bộ đếm chờ composite
      }
      break;
    }

    case CHOCH_LIFECYCLE_ACCEPTED:
    {
      // ── Kiểm tra composite (v4.0) ──
      bool compositeOK = true;
      if (state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
      {
        if (m_bullishReversal)
          compositeOK = (state.marketData.bid > state.vpCompositeVAH);
        else
          compositeOK = (state.marketData.bid < state.vpCompositeVAL);
      }

      if (m_followThroughScore >= 0.40 && compositeOK)
      {
        m_lifecycle = CHOCH_LIFECYCLE_CONFIRMED;
        m_chochQualityScore = ComputeQualityScore(state, atrPrice);
        m_chochScore = m_chochQualityScore;
        EmitEvent(state, 12, m_chochQualityScore, m_bullishReversal ? 1 : -1);
      }
      else if (m_followThroughScore < 0.20 || !compositeOK)
      {
        // Nếu chất lượng kém hoặc chưa vượt composite, chờ thêm
        if (isNewBar)
        {
          m_acceptedPersistence++;
          m_followThroughScore = ComputeReversalFollowThrough(state, atrPrice);
        }
        // Quá 5 nến không đạt thì hủy
        if (m_acceptedPersistence > 5)
        {
          TransitionToFailed(state);
        }
      }
      else
      {
        if (isNewBar)
        {
          m_followThroughScore = ComputeReversalFollowThrough(state, atrPrice);
          m_acceptedPersistence++;
        }
        bool failed = m_bullishReversal
                          ? (lastClose < m_chochLevel * 0.997)
                          : (lastClose > m_chochLevel * 1.003);
        if (failed)
          TransitionToFailed(state);
      }
      break;
    }

    case CHOCH_LIFECYCLE_CONFIRMED:
    {
      bool invalidated = m_bullishReversal
                             ? (lastClose < m_chochLevel - atrPrice * 0.5)
                             : (lastClose > m_chochLevel + atrPrice * 0.5);
      if (invalidated)
      {
        m_lifecycle = CHOCH_LIFECYCLE_NONE;
        m_chochQualityScore = 0;
        m_chochScore = 0;
        m_thesisManager.Reset();
      }
      break;
    }

    case CHOCH_LIFECYCLE_FAILED:
    {
      m_lifecycle = CHOCH_LIFECYCLE_NONE;
      m_thesisManager.Reset();
      break;
    }
    }

    WriteState(state);
    return true;
  }

  void WriteState(SPipelineState &state)
  {
    state.structure.chochScore = m_chochScore;
  }

  ECHOCHLifecycle Lifecycle(void) const { return m_lifecycle; }
  bool IsBullishCHOCH(void) const { return m_lifecycle == CHOCH_LIFECYCLE_CONFIRMED && m_bullishReversal; }
  bool IsBearishCHOCH(void) const { return m_lifecycle == CHOCH_LIFECYCLE_CONFIRMED && !m_bullishReversal; }
  double QualityScore(void) const { return m_chochQualityScore; }
};

#endif