#ifndef __EA_ROOT_PHASEENGINE_MQH__
#define __EA_ROOT_PHASEENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"

enum EWyckoffPhase
{
  PHASE_ACCUMULATION,
  PHASE_MARKUP,
  PHASE_DISTRIBUTION,
  PHASE_MARKDOWN,
  PHASE_UNKNOWN
};

//+------------------------------------------------------------------+
//| Phase Engine v2 — Structural Wyckoff Phase Detection              |
//| Integrates Volume Profile v3.0 & Auction Intelligence.            |
//+------------------------------------------------------------------+
class CPhaseEngine : public CPipelineModuleBase
{
private:
  EWyckoffPhase m_phase;
  double m_phaseConfidence;

  // ── Compute phase scores based on multiple structural factors ──
  void EvaluatePhases(const SPipelineState &state,
                      double &accScore,
                      double &marScore,
                      double &disScore,
                      double &mdScore)
  {
    // Base inputs (unchanged, but we'll use them as anchors)
    double trend = state.structure.trendStrength;               // [0,1]
    double compression = state.microstructure.compressionScore; // [0,1]
    double structBias = state.structure.structureBias;          // [0,1] (0=bearish, 1=bullish)

    // Start from zero
    accScore = 0.0;
    marScore = 0.0;
    disScore = 0.0;
    mdScore = 0.0;

    // ── 1. Base from legacy inputs (anchors) ──────────────
    if (compression > 0.6 && structBias > 0.5)
      accScore += 0.30;
    if (trend > 0.5 && structBias > 0.6)
      marScore += 0.30;
    if (compression > 0.6 && structBias < 0.5)
      disScore += 0.30;
    if (trend > 0.5 && structBias < 0.4)
      mdScore += 0.30;

    // ── 2. Structural context from Volume Profile v3.0 ──
    if (state.vpValid)
    {
      // 2a. Anchored Range Profile → accumulation / distribution
      if (state.vpRangePOC > 0)
      {
        // A well‑defined range supports accumulation or distribution
        if (structBias > 0.5)
          accScore += 0.15;
        else
          disScore += 0.15;
      }

      // 2b. Anchored Breakout Profile → markup / markdown
      if (state.vpBreakoutPOC > 0)
      {
        double bid = state.marketData.bid;
        if (bid > state.vpBreakoutPOC)
          marScore += 0.20; // breaking higher
        else
          mdScore += 0.20; // breaking lower
      }

      // 2c. Anchored Pullback Profile → often within trend
      if (state.vpPullbackPOC > 0)
      {
        // Pullback trong xu hướng tăng → markup, giảm → markdown
        if (structBias > 0.6)
          marScore += 0.10;
        else if (structBias < 0.4)
          mdScore += 0.10;
      }

      // 2d. VA Overlap Bias → xác nhận xu hướng dài hạn
      int vaBias = state.vpVAOverlapBias; // -1,0,1
      if (vaBias == 1)
      {
        marScore += 0.10;
        accScore += 0.05;
      }
      if (vaBias == -1)
      {
        mdScore += 0.10;
        disScore += 0.05;
      }

      // 2e. Migration Confidence → POC đang di chuyển
      double migConf = state.vpMigrationConfidence;
      if (migConf > 0.5)
      {
        double migDir = (state.vpDevPOCDirection > 0) ? 1.0 : -1.0;
        if (migDir > 0)
          marScore += 0.10;
        else
          mdScore += 0.10;
      }

      // 2f. Fake Breakout → cuối pha tích lũy / phân phối
      if (state.vpUpthrustDetected)
      {
        disScore += 0.15; // upthrust = dấu hiệu phân phối
        mdScore += 0.10;
      }
      if (state.vpSpringDetected)
      {
        accScore += 0.15; // spring = dấu hiệu tích lũy
        marScore += 0.10;
      }

      // 2g. Profile Thinness → thị trường mỏng = markup/markdown mạnh
      if (state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
      {
        if (structBias > 0.5)
          marScore += 0.08;
        else
          mdScore += 0.08;
      }

      // 2h. Composite Position → discount/premium context
      int compPos = state.vpCompositePosition; // -1 discount, +1 premium
      if (compPos == -1)
      {
        accScore += 0.08;
        marScore += 0.05;
      } // discount: có thể đang tích lũy hoặc bắt đầu markup
      if (compPos == 1)
      {
        disScore += 0.08;
        mdScore += 0.05;
      } // premium: phân phối hoặc markdown

      // 2i. Composite VA — giá ngoài composite VAH/VAL củng cố markup/markdown
      double bid = state.marketData.bid;
      if (bid > state.vpCompositeVAH)
      {
        marScore += 0.12;
        disScore -= 0.05; // unlikely to be distribution when price above macro VA
      }
      else if (bid < state.vpCompositeVAL)
      {
        mdScore += 0.12;
        accScore -= 0.05;
      }
    }

    // ── 3. Auction Regime (5‑state) ──────────────────────
    int regime = state.auctRegime;
    double regimeConf = state.auctRegimeConfidence;
    switch (regime)
    {
    case (int)REGIME_BALANCED_ROTATION:
      if (structBias > 0.5)
        accScore += 0.10 * regimeConf;
      else
        disScore += 0.10 * regimeConf;
      break;
    case (int)REGIME_TREND_INITIATION:
      if (structBias > 0.5)
        marScore += 0.12 * regimeConf;
      else
        mdScore += 0.12 * regimeConf;
      break;
    case (int)REGIME_TREND_CONTINUATION:
      if (structBias > 0.5)
        marScore += 0.15 * regimeConf;
      else
        mdScore += 0.15 * regimeConf;
      break;
    case (int)REGIME_TREND_EXHAUSTION:
      // Cuối xu hướng → có thể chuẩn bị phân phối (nếu đang tăng) hoặc tích lũy (nếu đang giảm)
      if (structBias > 0.5)
        disScore += 0.10 * regimeConf;
      else
        accScore += 0.10 * regimeConf;
      break;
    case (int)REGIME_FAILED_AUCTION:
      // Phá vỡ thất bại → đảo chiều, thường vào pha ngược lại
      if (structBias > 0.5)
        mdScore += 0.10 * regimeConf;
      else
        marScore += 0.10 * regimeConf;
      break;
    }

    // ── 4. Continuation / Exhaustion scores ─────────────────
    if (state.auctContinuationScore > 0.7)
    {
      if (structBias > 0.5)
        marScore += 0.08;
      else
        mdScore += 0.08;
    }
    if (state.auctExhaustionScore > 0.6)
    {
      // Exhaustion shifts from trending to distribution/accumulation
      if (structBias > 0.5)
        disScore += 0.08;
      else
        accScore += 0.08;
    }
  }

public:
  void Bootstrap(const string symbol)
  {
    Configure(symbol, "PhaseEngine");
    m_phase = PHASE_UNKNOWN;
    m_phaseConfidence = 0.0;
  }

  virtual bool Execute(SPipelineState &state) override
  {
    CPipelineModuleBase::Execute(state);

    double accScore, marScore, disScore, mdScore;
    EvaluatePhases(state, accScore, marScore, disScore, mdScore);

    // Find the phase with highest score
    double maxScore = 0.0;
    EWyckoffPhase bestPhase = PHASE_UNKNOWN;

    if (accScore > maxScore)
    {
      maxScore = accScore;
      bestPhase = PHASE_ACCUMULATION;
    }
    if (marScore > maxScore)
    {
      maxScore = marScore;
      bestPhase = PHASE_MARKUP;
    }
    if (disScore > maxScore)
    {
      maxScore = disScore;
      bestPhase = PHASE_DISTRIBUTION;
    }
    if (mdScore > maxScore)
    {
      maxScore = mdScore;
      bestPhase = PHASE_MARKDOWN;
    }

    // Confidence = how much the winner stands out from the next best
    double secondBest = 0.0;
    if (bestPhase != PHASE_ACCUMULATION && accScore > secondBest)
      secondBest = accScore;
    if (bestPhase != PHASE_MARKUP && marScore > secondBest)
      secondBest = marScore;
    if (bestPhase != PHASE_DISTRIBUTION && disScore > secondBest)
      secondBest = disScore;
    if (bestPhase != PHASE_MARKDOWN && mdScore > secondBest)
      secondBest = mdScore;

    m_phaseConfidence = (maxScore > 0.0) ? (maxScore - secondBest) / maxScore : 0.0;
    m_phaseConfidence = Clamp01(m_phaseConfidence);

    // If confidence too low, stay unknown
    if (m_phaseConfidence < 0.15)
      m_phase = PHASE_UNKNOWN;
    else
      m_phase = bestPhase;

    // Output a composite phase score for downstream use
    // Normalise maxScore to [0,1] — typical max possible around 0.7-0.9
    state.structure.phaseScore = Clamp01(maxScore * 1.2);

    return true;
  }

  EWyckoffPhase Phase(void) const { return m_phase; }
  double Confidence(void) const { return m_phaseConfidence; }
};

#endif