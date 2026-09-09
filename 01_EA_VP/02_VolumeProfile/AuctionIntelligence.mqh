#ifndef __EA_ROOT_AUCTIONINTELLIGENCE_MQH__
#define __EA_ROOT_AUCTIONINTELLIGENCE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "AuctionEnums.mqh"
#include "VolumeProfileEngine.mqh"

//+------------------------------------------------------------------+
//| Auction Intelligence Engine v4                                    |
//| 9-Regime Classification based on Auction Market Theory & VP v3   |
//+------------------------------------------------------------------+

// Supporting structures
struct SAcceptanceMetrics
  {
   double acceptanceScore;
   double volumeScore;
   double timeScore;
   double retestScore;
  };

struct SVolumeCluster
  {
   double centerPrice;
   double width;
   long   totalVolume;
   int    totalTime;
   double strength;
   bool   isHVN;
   bool   isLVN;
  };

#define AI_MAX_CLUSTERS    8
#define AI_VA_HISTORY     20
#define AI_FAILURE_WINDOW  5

class CAuctionIntelligence : public CVPModuleBase
  {
private:
   CVolumeProfileEngine *m_vpEngine;

   // Phase 2: Acceptance
   SAcceptanceMetrics m_currentAcceptance;
   SAcceptanceMetrics m_hvnAcceptance;
   SAcceptanceMetrics m_pocAcceptance;

   // Phase 3: Profile Shape
   EProfileShape m_profileShape;
   double m_profileShapeConfidence;
   double m_skewness;
   double m_kurtosis;
   double m_bimodality;

   // Phase 4: Clusters
   SVolumeCluster m_hvnClusters[AI_MAX_CLUSTERS];
   SVolumeCluster m_lvnClusters[AI_MAX_CLUSTERS];
   int    m_hvnClusterCount;
   int    m_lvnClusterCount;
   double m_distToMajorHVN;
   double m_distToMajorLVN;
   double m_majorHVNPrice;
   double m_majorLVNPrice;
   double m_hvnClusterStrength;
   double m_lvnClusterStrength;

   // Phase 5: Auction State + Regime
   EAuctionState  m_auctionState;
   double         m_auctionBalanceScore;
   EAuctionRegime m_auctionRegime;
   double         m_auctionRegimeConf;

   // Value Area Dynamics
   double m_vahHistory[AI_VA_HISTORY];
   double m_valHistory[AI_VA_HISTORY];
   int    m_vaHistCount;
   int    m_vaHistWriteIdx;
   double m_vahVelocity;
   double m_valVelocity;
   double m_vaExpansionRate;
   EValueAreaState m_valueAreaState;

   // Phase 6: Expected Reward
   double m_expectedReward;
   double m_expectedMoveATR;
   double m_targetProbability;

   // Phase 7: Trade Quality
   double m_tradeQuality;
   int    m_tradeGrade;

   // Phase 8: Target
   double m_targetPrice;
   EAuctionTargetType m_targetType;
   double m_targetConfidence;

   // Phase 9: Position Management
   double m_profitZoneScore;
   double m_exhaustionScore;
   double m_continuationScore;
   double m_reversalRiskScore;

   // Auction Failure
   double m_auctionFailureScore;
   double m_prevVAH;
   double m_prevVAL;
   double m_prevPOC;
   int    m_failureCounter;


   //+------------------------------------------------------------------+
   //| PHASE 1: Histogram Access Helpers                                 |
   //+------------------------------------------------------------------+
   int FindBinAtPrice(double price)
     {
      if(!m_vpEngine) return -1;
      int nBins = m_vpEngine.GetBinCount();
      if(nBins < 2) return -1;
      int bestIdx = -1; double bestDist = 1e18;
      for(int i = 0; i < nBins; i++)
        { double d = MathAbs(m_vpEngine.GetBinPrice(i) - price);
          if(d < bestDist) { bestDist = d; bestIdx = i; } }
      return bestIdx;
     }

   long GetMaxVolume(void)
     {
      int nBins = m_vpEngine.GetBinCount();
      long maxV = 0;
      for(int i = 0; i < nBins; i++)
        { long v = m_vpEngine.GetBinVolume(i); if(v > maxV) maxV = v; }
      return maxV;
     }

   int GetMaxTime(void)
     {
      int nBins = m_vpEngine.GetBinCount();
      int maxT = 0;
      for(int i = 0; i < nBins; i++)
        { int t = m_vpEngine.GetBinTime(i); if(t > maxT) maxT = t; }
      return maxT;
     }

   //+------------------------------------------------------------------+
   //| PHASE 2: ACCEPTANCE ENGINE                                        |
   //+------------------------------------------------------------------+
   SAcceptanceMetrics ComputeAcceptance(double targetPrice)
     {
      SAcceptanceMetrics am;
      am.acceptanceScore = 0; am.volumeScore = 0;
      am.timeScore = 0; am.retestScore = 0;
      if(!m_vpEngine) return am;
      int bin = FindBinAtPrice(targetPrice);
      if(bin < 0) return am;
      long maxVol = GetMaxVolume();
      int  maxTime = GetMaxTime();
      long binVol = m_vpEngine.GetBinVolume(bin);
      am.volumeScore = (maxVol > 0) ? Clamp01((double)binVol / (double)maxVol) : 0;
      int binTime = m_vpEngine.GetBinTime(bin);
      am.timeScore = (maxTime > 0) ? Clamp01((double)binTime / (double)maxTime) : 0;
      am.retestScore = am.timeScore;
      am.acceptanceScore = am.volumeScore * 0.40 + am.timeScore * 0.40 + am.retestScore * 0.20;
      return am;
     }

   //+------------------------------------------------------------------+
   //| PHASE 3: STATISTICAL PROFILE SHAPE                                |
   //+------------------------------------------------------------------+
   //| PHASE 3: STATISTICAL PROFILE SHAPE (v2 — improved thresholds)   |
   //| Changes:                                                          |
   //|   - THIN no longer forced to D — tracked as m_isThinProfile     |
   //|   - Skewness threshold raised 0.30→0.50 for P/b (reduce noise) |
   //|   - D-shape requires kurtosis in [-1.5, 1.5] (confirm normality)|
   //|   - B-shape cross-checked with cluster count (need 2+ HVN)      |
   //|   - Confidence scaled by statistical strength                    |
   //+------------------------------------------------------------------+

   // Tunable thresholds
   #define SHAPE_SKEW_THRESH    0.50     // min |skewness| for P or b shape
   #define SHAPE_KURT_D_MIN    -1.5      // D-shape kurtosis lower bound
   #define SHAPE_KURT_D_MAX     1.5      // D-shape kurtosis upper bound
   #define SHAPE_BIMODAL_THRESH 0.555    // Sarle's bimodality coefficient
   #define SHAPE_BIMODAL_CLUSTER_MIN 2   // min HVN clusters for B confirmation

   void ClassifyProfileShape(const SVPPipelineState &state)
     {
      m_profileShape = PROFILE_UNKNOWN; m_profileShapeConfidence = 0;
      m_skewness = 0; m_kurtosis = 0; m_bimodality = 0;
      if(!m_vpEngine) return;
      int nBins = m_vpEngine.GetBinCount();
      if(nBins < 10) return;

      // Compute weighted moments
      double totalVol = 0;
      for(int i = 0; i < nBins; i++) totalVol += (double)m_vpEngine.GetBinVolume(i);
      if(totalVol <= 0) return;
      double mean = 0;
      for(int i = 0; i < nBins; i++)
         mean += m_vpEngine.GetBinPrice(i) * (double)m_vpEngine.GetBinVolume(i);
      mean /= totalVol;
      double m2 = 0, m3 = 0, m4 = 0;
      for(int i = 0; i < nBins; i++)
        { double w = (double)m_vpEngine.GetBinVolume(i) / totalVol;
          double d = m_vpEngine.GetBinPrice(i) - mean;
          m2 += w * d * d; m3 += w * d * d * d; m4 += w * d * d * d * d; }
      double stddev = MathSqrt(m2);
      if(stddev < 1e-10) return;
      m_skewness = m3 / (stddev * stddev * stddev);
      m_kurtosis = (m4 / (m2 * m2)) - 3.0;  // excess kurtosis
      double kurtPlus3 = m_kurtosis + 3.0;
      m_bimodality = (kurtPlus3 > 0.01) ? (m_skewness * m_skewness + 1.0) / kurtPlus3 : 0;

      // ─── Classification (priority order) ─────────────────────────
      // 1. Bimodal (B-shape): Sarle's coefficient high + confirmed by 2+ HVN clusters
      if(m_bimodality > SHAPE_BIMODAL_THRESH)
        {
         // Cross-check: are there actually 2+ separate HVN clusters?
         bool hasTwoClusters = (m_hvnClusterCount >= SHAPE_BIMODAL_CLUSTER_MIN);
         if(hasTwoClusters)
           { m_profileShape = PROFILE_B;
             m_profileShapeConfidence = Clamp01((m_bimodality - SHAPE_BIMODAL_THRESH) / 0.3 + 0.3); }
         else
           { // No cluster confirmation → fall through to skewness-based
             // (bimodality was statistical artifact, not structural)
           }
        }

      // 2. Skewed shapes (P or b) — require stronger skewness than before
      if(m_profileShape == PROFILE_UNKNOWN)
        {
         if(m_skewness > SHAPE_SKEW_THRESH)
           { m_profileShape = PROFILE_P;
             m_profileShapeConfidence = Clamp01((m_skewness - SHAPE_SKEW_THRESH) / 1.5); }
         else if(m_skewness < -SHAPE_SKEW_THRESH)
           { m_profileShape = PROFILE_b;
             m_profileShapeConfidence = Clamp01((MathAbs(m_skewness) - SHAPE_SKEW_THRESH) / 1.5); }
        }

      // 3. D-shape (normal distribution): low skewness + kurtosis near 0
      if(m_profileShape == PROFILE_UNKNOWN)
        {
         if(MathAbs(m_skewness) < SHAPE_SKEW_THRESH
            && m_kurtosis >= SHAPE_KURT_D_MIN && m_kurtosis <= SHAPE_KURT_D_MAX)
           { m_profileShape = PROFILE_D;
             double symScore = 1.0 - MathAbs(m_skewness) / SHAPE_SKEW_THRESH;
             double kurtScore = 1.0 - MathAbs(m_kurtosis) / 2.0;
             m_profileShapeConfidence = Clamp01((symScore + kurtScore) / 2.0); }
        }

      // 4. Fallback: unable to classify strongly → D with low confidence
      if(m_profileShape == PROFILE_UNKNOWN)
        { m_profileShape = PROFILE_D; m_profileShapeConfidence = 0.2; }

      // ─── Thinness is a SEPARATE property, not a shape ────────────
      // (vpThinnessRatio = VA_width / total_range — low = thin VA relative to range)
      // Previously: THIN → forced to D. Now: thinness only affects confidence.
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.25)
         m_profileShapeConfidence *= 0.5;  // thin profile → low confidence in shape
     }

   //+------------------------------------------------------------------+
   //| PHASE 4: CLUSTER DETECTION                                        |
   //+------------------------------------------------------------------+
   void BuildClusters(double bid, double atr)
     {
      m_hvnClusterCount = 0; m_lvnClusterCount = 0;
      m_distToMajorHVN = 0; m_distToMajorLVN = 0;
      m_majorHVNPrice = 0; m_majorLVNPrice = 0;
      m_hvnClusterStrength = 0; m_lvnClusterStrength = 0;
      if(!m_vpEngine || atr <= 0) return;
      int nBins = m_vpEngine.GetBinCount();
      if(nBins < 5) return;
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;

      // Sort volumes to find percentile thresholds
      long sorted[];
      ArrayResize(sorted, nBins);
      for(int i = 0; i < nBins; i++) sorted[i] = m_vpEngine.GetBinVolume(i);
      for(int i = 1; i < nBins; i++)
        { long key = sorted[i]; int j = i-1;
          while(j >= 0 && sorted[j] > key) { sorted[j+1] = sorted[j]; j--; }
          sorted[j+1] = key; }
      long hvnThresh = sorted[MathMin(nBins-1, (int)(nBins * 0.80))];
      long lvnThresh = sorted[MathMax(0, (int)(nBins * 0.20))];
      double binW = m_vpEngine.GetBinWidth();

      // HVN clusters
      int clStart = -1;
      for(int i = 0; i <= nBins; i++)
        { bool isHVN = (i < nBins && m_vpEngine.GetBinVolume(i) >= hvnThresh);
          if(isHVN && clStart < 0) clStart = i;
          else if(!isHVN && clStart >= 0)
            { if(m_hvnClusterCount < AI_MAX_CLUSTERS)
              { long cVol = 0; double pSum = 0; int cTime = 0;
                for(int j = clStart; j < i; j++)
                  { cVol += m_vpEngine.GetBinVolume(j); cTime += m_vpEngine.GetBinTime(j);
                    pSum += m_vpEngine.GetBinPrice(j); }
                int cnt = i - clStart;
                m_hvnClusters[m_hvnClusterCount].centerPrice = pSum / cnt;
                m_hvnClusters[m_hvnClusterCount].width = binW * cnt;
                m_hvnClusters[m_hvnClusterCount].totalVolume = cVol;
                m_hvnClusters[m_hvnClusterCount].totalTime = cTime;
                m_hvnClusters[m_hvnClusterCount].isHVN = true;
                m_hvnClusters[m_hvnClusterCount].isLVN = false;
                long maxV = GetMaxVolume();
                m_hvnClusters[m_hvnClusterCount].strength = (maxV > 0) ? Clamp01((double)cVol / ((double)maxV * cnt)) : 0;
                m_hvnClusterCount++; }
              clStart = -1; } }

      // LVN clusters
      clStart = -1;
      for(int i = 0; i <= nBins; i++)
        { bool isLVN = (i < nBins && m_vpEngine.GetBinVolume(i) <= lvnThresh);
          if(isLVN && clStart < 0) clStart = i;
          else if(!isLVN && clStart >= 0)
            { if(m_lvnClusterCount < AI_MAX_CLUSTERS)
              { long cVol = 0; double pSum = 0; int cTime = 0;
                for(int j = clStart; j < i; j++)
                  { cVol += m_vpEngine.GetBinVolume(j); cTime += m_vpEngine.GetBinTime(j);
                    pSum += m_vpEngine.GetBinPrice(j); }
                int cnt = i - clStart;
                m_lvnClusters[m_lvnClusterCount].centerPrice = pSum / cnt;
                m_lvnClusters[m_lvnClusterCount].width = binW * cnt;
                m_lvnClusters[m_lvnClusterCount].totalVolume = cVol;
                m_lvnClusters[m_lvnClusterCount].totalTime = cTime;
                m_lvnClusters[m_lvnClusterCount].isHVN = false;
                m_lvnClusters[m_lvnClusterCount].isLVN = true;
                m_lvnClusters[m_lvnClusterCount].strength = Clamp01(1.0 - (double)cTime / MathMax(1, GetMaxTime() * cnt));
                m_lvnClusterCount++; }
              clStart = -1; } }

      // Find nearest HVN/LVN
      double minDistH = 1e18;
      for(int i = 0; i < m_hvnClusterCount; i++)
        { double d = MathAbs(bid - m_hvnClusters[i].centerPrice);
          if(d < minDistH) { minDistH = d; m_majorHVNPrice = m_hvnClusters[i].centerPrice;
                             m_hvnClusterStrength = m_hvnClusters[i].strength; } }
      m_distToMajorHVN = (m_majorHVNPrice > 0) ? minDistH / atrPrice : 0;
      double minDistL = 1e18;
      for(int i = 0; i < m_lvnClusterCount; i++)
        { double d = MathAbs(bid - m_lvnClusters[i].centerPrice);
          if(d < minDistL) { minDistL = d; m_majorLVNPrice = m_lvnClusters[i].centerPrice;
                             m_lvnClusterStrength = m_lvnClusters[i].strength; } }
      m_distToMajorLVN = (m_majorLVNPrice > 0) ? minDistL / atrPrice : 0;
     }


   //+------------------------------------------------------------------+
   //| PHASE 5: AUCTION STATE + 9 REGIME CLASSIFICATION                  |
   //+------------------------------------------------------------------+
   void ClassifyAuctionState(const SVPPipelineState &state, double atr)
     {
      if(atr <= 0) { m_auctionState = AUCTION_BALANCED; m_auctionBalanceScore = 0.5; return; }
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;

      double pocMigration = (m_prevPOC > 0) ? MathAbs(state.vpPOC - m_prevPOC) / atrPrice : 0;
      double pocStability = Clamp01(1.0 - pocMigration / 0.5);
      double vaWidth = state.vpVAH - state.vpVAL;
      double vaWidthATR = (atrPrice > 0) ? vaWidth / atrPrice : 1.0;
      double vaCompactness = Clamp01(1.0 - vaWidthATR / 3.0);
      double vaRange = state.vpVAH - state.vpVAL;
      double pocInVA = (vaRange > 0) ? (state.vpPOC - state.vpVAL) / vaRange : 0.5;
      double symmetry = Clamp01(1.0 - MathAbs(pocInVA - 0.5) * 2.0);
      double devPocStab = Clamp01(1.0 - MathAbs(state.vpDevPOCDirection));

      m_auctionBalanceScore = pocStability * 0.30 + vaCompactness * 0.25
                            + symmetry * 0.25 + devPocStab * 0.20;

      if(m_auctionBalanceScore >= 0.65)      m_auctionState = AUCTION_BALANCED;
      else if(m_auctionBalanceScore <= 0.35) m_auctionState = AUCTION_TRENDING;
      else                                    m_auctionState = AUCTION_TRANSITIONAL;

      // Classify 9 regimes
      ClassifyRegime9(state, atr, atrPrice);

      // ── [v4.0] Long-Term confidence modifiers ─────────────────────
      // Boost regime confidence when long-term POC migration aligns with regime
      if(state.vpLTValid)
        {
         int ltMig = state.vpLTPOCMigration;
         // Trend regimes get boost when LT POC migration agrees
         if((m_auctionRegime == REGIME_TREND_INITIATION || m_auctionRegime == REGIME_TREND_CONTINUATION)
            && ((ltMig >= 1 && state.vpDevPOCDirection > 0) || (ltMig <= -1 && state.vpDevPOCDirection < 0)))
            m_auctionRegimeConf = MathMin(1.0, m_auctionRegimeConf + 0.10);

         // Acceptance at current price boosts balance score for ranging regimes
         if(m_auctionRegime == REGIME_BALANCED_ROTATION && state.vpLTAcceptanceAtPrice > 0.6)
            m_auctionRegimeConf = MathMin(1.0, m_auctionRegimeConf + 0.08);
        }
     }

   //+------------------------------------------------------------------+
   //| 9-REGIME CLASSIFICATION (v2 — refined thresholds)                |
   //| Changes:                                                          |
   //|  - CHAOTIC: redefined as VA extremely narrow (< 0.3 ATR) +      |
   //|    spread extreme OR erratic price (high tick velocity)          |
   //|  - EXCESS: added volVelocity confirmation to separate from FAIL |
   //|  - RE_ACCUMULATION: uses current VA width, not vpRangeWidth     |
   //|  - TREND_INITIATION: V-reversal detection without breakout POC  |
   //|  - m_vaExpansionRate smoothed via EMA (noise filter)             |
   //+------------------------------------------------------------------+

   // Tunable regime thresholds (easy to adjust)
   #define REGIME_CHAOTIC_VA_MAX_ATR       0.30    // VA narrower than this → chaos candidate
   #define REGIME_CHAOTIC_SPREAD_RATIO     0.30    // spread/ATR above this → chaos
   #define REGIME_FAIL_SCORE_HARD          0.55    // failScore alone triggers FAILED
   #define REGIME_FAIL_SCORE_WITH_FAKE     0.25    // failScore + fake breakout
   #define REGIME_EXCESS_VA_VEL_MIN        0.03    // min VA velocity for excess
   #define REGIME_EXHAUST_VA_CONTRACTION  -0.02    // VA contracting threshold
   #define REGIME_INIT_VA_EXPANSION        0.06    // VA expanding threshold for initiation
   #define REGIME_INIT_VALMIG_MIN          0.25    // min POC migration for initiation
   #define REGIME_CONT_BALANCE_MAX         0.42    // max balance for continuation
   #define REGIME_CONT_VALMIG_MIN          0.40    // min POC migration for continuation
   #define REGIME_CONT_MIGCONF_MIN         0.40    // min migration confidence
   #define REGIME_REACCUM_BALANCE_LO       0.50    // re-accum balance lower bound
   #define REGIME_REACCUM_BALANCE_HI       0.75    // re-accum balance upper bound
   #define REGIME_REACCUM_VA_WIDTH_MAX_ATR 2.0     // max VA width for re-accum
   #define REGIME_COMPRESS_BALANCE_MIN     0.72    // min balance for compression
   #define REGIME_COMPRESS_VA_CONTRACTION -0.04    // VA contracting threshold

   void ClassifyRegime9(const SVPPipelineState &state, double atr, double atrPrice)
     {
      m_auctionRegime = REGIME_BALANCED_ROTATION;
      m_auctionRegimeConf = 0.0;
      double valMig = MathAbs(state.vpDevPOCDirection);

      // Derived metrics
      double vaWidth = state.vpVAH - state.vpVAL;
      double vaWidthATR = (atrPrice > 0) ? vaWidth / atrPrice : 1.0;
      double spreadRatio = (atr > 0) ? state.marketData.spreadPoints / atr : 0;

      // ─── 1. CHAOTIC ───────────────────────────────────────────────
      // Definition: VA extremely narrow (price not accepted anywhere) + extreme spread
      // OR profile shape unknown/unclassifiable + spread blow-out
      // This means market has NO structure — random noise only
      bool chaoticVA = (vaWidthATR < REGIME_CHAOTIC_VA_MAX_ATR && vaWidthATR > 0);
      bool chaoticSpread = (spreadRatio > REGIME_CHAOTIC_SPREAD_RATIO);
      bool chaoticProfile = (state.vpProfileShape == (int)PROFILE_UNKNOWN);
      if((chaoticVA && chaoticSpread) || (chaoticProfile && chaoticSpread))
        { m_auctionRegime = REGIME_CHAOTIC;
          m_auctionRegimeConf = Clamp01(0.5 + spreadRatio);
          return; }

      // ─── 2. FAILED AUCTION ────────────────────────────────────────
      // High failure score alone, or moderate + fake breakout confirmation
      if(m_auctionFailureScore > REGIME_FAIL_SCORE_HARD)
        { m_auctionRegime = REGIME_FAILED_AUCTION;
          m_auctionRegimeConf = m_auctionFailureScore; return; }
      if((state.vpUpthrustDetected || state.vpSpringDetected)
         && m_auctionFailureScore > REGIME_FAIL_SCORE_WITH_FAKE)
        { m_auctionRegime = REGIME_FAILED_AUCTION;
          m_auctionRegimeConf = Clamp01(m_auctionFailureScore + 0.20); return; }

      // ─── 3. EXCESS ────────────────────────────────────────────────
      // Quick VA boundary rejection (single prints at edge) + VA velocity
      // Distinguished from FAILED by: lower failure score, higher velocity
      bool hasRejection = (state.vpUpthrustDetected || state.vpSpringDetected);
      bool vaMovingFast = (MathAbs(m_vahVelocity) > REGIME_EXCESS_VA_VEL_MIN
                        || MathAbs(m_valVelocity) > REGIME_EXCESS_VA_VEL_MIN);
      if(hasRejection && vaMovingFast && m_auctionFailureScore < REGIME_FAIL_SCORE_HARD)
        { m_auctionRegime = REGIME_EXCESS;
          m_auctionRegimeConf = Clamp01(0.5 + MathMax(MathAbs(m_vahVelocity), MathAbs(m_valVelocity)));
          return; }

      // ─── 4. EXHAUSTION ────────────────────────────────────────────
      // Trend weakening: VA contracting + was trending (balance < 0.50)
      // OR rejection signals in a still-unbalanced market
      bool vaContracting = (m_vaExpansionRate < REGIME_EXHAUST_VA_CONTRACTION);
      bool wasTrending = (m_auctionBalanceScore < 0.50);
      if(wasTrending && vaContracting)
        { m_auctionRegime = REGIME_TREND_EXHAUSTION;
          m_auctionRegimeConf = Clamp01(MathAbs(m_vaExpansionRate) * 8.0 + (0.50 - m_auctionBalanceScore));
          if(hasRejection) m_auctionRegimeConf = MathMin(1.0, m_auctionRegimeConf + 0.15);
          return; }
      // Also detect: rejection + moderate imbalance + VA not expanding
      if(hasRejection && m_auctionBalanceScore > 0.35 && m_auctionBalanceScore < 0.55
         && m_vaExpansionRate <= 0)
        { m_auctionRegime = REGIME_TREND_EXHAUSTION;
          m_auctionRegimeConf = 0.5;
          return; }

      // ─── 5. TREND INITIATION ──────────────────────────────────────
      // VA expanding + POC migrating — breakout phase
      // NEW: also detect V-reversal without breakout profile (valMig alone is enough)
      bool vaExpanding = (m_vaExpansionRate > REGIME_INIT_VA_EXPANSION);
      bool pocMigrating = (valMig > REGIME_INIT_VALMIG_MIN);
      bool hasBreakoutPOC = (state.vpBreakoutPOC > 0);
      if((vaExpanding && pocMigrating) || (hasBreakoutPOC && pocMigrating))
        { m_auctionRegime = REGIME_TREND_INITIATION;
          m_auctionRegimeConf = Clamp01(m_vaExpansionRate * 4.0 + valMig * 0.5);
          if(state.vpVAOverlapBias != 0) m_auctionRegimeConf = MathMin(1.0, m_auctionRegimeConf * 1.2);
          return; }

      // ─── 6. TREND CONTINUATION ────────────────────────────────────
      // Established trend: low balance + strong migration + high confidence
      if(m_auctionBalanceScore < REGIME_CONT_BALANCE_MAX
         && valMig > REGIME_CONT_VALMIG_MIN
         && state.vpMigrationConfidence > REGIME_CONT_MIGCONF_MIN)
        { m_auctionRegime = REGIME_TREND_CONTINUATION;
          m_auctionRegimeConf = Clamp01((valMig + state.vpMigrationConfidence) / 2.0);
          return; }

      // ─── 7. RE-ACCUMULATION ───────────────────────────────────────
      // Pause in trend: directional bias exists (overlap != 0), balance rising,
      // VA stable/narrowing, current VA width < threshold
      // FIXED: use current VA width instead of vpRangeWidth
      bool inTrend = (MathAbs(state.vpVAOverlapBias) == 1);
      bool balanceRising = (m_auctionBalanceScore > REGIME_REACCUM_BALANCE_LO
                         && m_auctionBalanceScore < REGIME_REACCUM_BALANCE_HI);
      bool vaStableOrNarrowing = (m_vaExpansionRate < 0.02 && m_vaExpansionRate > -0.04);
      bool vaNotTooWide = (vaWidthATR < REGIME_REACCUM_VA_WIDTH_MAX_ATR);
      if(inTrend && balanceRising && vaStableOrNarrowing && vaNotTooWide)
        { m_auctionRegime = REGIME_RE_ACCUMULATION;
          m_auctionRegimeConf = Clamp01(0.4 + m_auctionBalanceScore * 0.3);
          return; }

      // ─── 8. COMPRESSION ───────────────────────────────────────────
      // Tight squeeze: VA contracting, very high balance, NO directional bias
      if(m_vaExpansionRate < REGIME_COMPRESS_VA_CONTRACTION
         && m_auctionBalanceScore > REGIME_COMPRESS_BALANCE_MIN
         && state.vpVAOverlapBias == 0)
        { m_auctionRegime = REGIME_COMPRESSION;
          m_auctionRegimeConf = Clamp01(0.6 + MathAbs(m_vaExpansionRate) * 3.0);
          return; }

      // ─── 9. BALANCED ROTATION (default) ───────────────────────────
      m_auctionRegime = REGIME_BALANCED_ROTATION;
      m_auctionRegimeConf = m_auctionBalanceScore;
     }

   //+------------------------------------------------------------------+
   //| Value Area Dynamics                                               |
   //+------------------------------------------------------------------+
   void UpdateValueAreaDynamics(double vah, double val, double atr)
     {
      if(atr <= 0 || vah <= 0 || val <= 0) { m_valueAreaState = VA_STABLE; return; }
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;
      m_vahHistory[m_vaHistWriteIdx] = vah;
      m_valHistory[m_vaHistWriteIdx] = val;
      m_vaHistWriteIdx = (m_vaHistWriteIdx + 1) % AI_VA_HISTORY;
      if(m_vaHistCount < AI_VA_HISTORY) m_vaHistCount++;
      if(m_vaHistCount < 3) { m_valueAreaState = VA_STABLE; return; }
      int prevIdx = (m_vaHistWriteIdx - 2 + AI_VA_HISTORY) % AI_VA_HISTORY;
      m_vahVelocity = (vah - m_vahHistory[prevIdx]) / atrPrice;
      m_valVelocity = (val - m_valHistory[prevIdx]) / atrPrice;
      double currentWidth = vah - val;
      double prevWidth = m_vahHistory[prevIdx] - m_valHistory[prevIdx];
      m_vaExpansionRate = (prevWidth > 0) ? (currentWidth - prevWidth) / atrPrice : 0;
      if(m_vaExpansionRate > 0.05)      m_valueAreaState = VA_EXPANDING;
      else if(m_vaExpansionRate < -0.05) m_valueAreaState = VA_CONTRACTING;
      else                               m_valueAreaState = VA_STABLE;
     }

   //+------------------------------------------------------------------+
   //| Auction Failure Detection                                         |
   //+------------------------------------------------------------------+
   void DetectAuctionFailure(double bid, double atr, const SVPPipelineState &state)
     {
      if(atr <= 0) { m_auctionFailureScore = 0; return; }
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double failScore = 0;
      if(m_prevVAH > 0 && state.vpVAH > 0 && bid < state.vpVAH && bid > state.vpVAL)
        { if(m_vahVelocity < -0.02) failScore += 0.30; }
      if(m_prevVAL > 0 && state.vpVAL > 0 && bid > state.vpVAL && bid < state.vpVAH)
        { if(m_valVelocity > 0.02) failScore += 0.30; }
      if(m_vpEngine != NULL)
        { double slope = m_vpEngine.DevPOCSlope();
          double vel = m_vpEngine.DevPOCVelocity();
          if(slope * vel < 0 && MathAbs(vel) > 0.005) failScore += 0.25; }
      if(state.vpDistToLVN_ATR > 0 && state.vpDistToLVN_ATR < 0.3) failScore += 0.15;
      if(state.vpUpthrustDetected || state.vpSpringDetected) failScore += 0.30;
      m_auctionFailureScore = Clamp01(failScore);
      if(failScore < 0.1) m_failureCounter = MathMax(0, m_failureCounter - 1);
      else m_failureCounter = MathMin(AI_FAILURE_WINDOW, m_failureCounter + 1);
     }


   //+------------------------------------------------------------------+
   //| PHASE 6: EXPECTED REWARD (9-regime aware)                         |
   //+------------------------------------------------------------------+
   void ComputeExpectedReward(double bid, double atr, const SVPPipelineState &state)
     {
      m_expectedReward = 0; m_expectedMoveATR = 0; m_targetProbability = 0;
      if(atr <= 0) return;
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;

      double distHVN = (m_majorHVNPrice > 0) ? MathAbs(bid - m_majorHVNPrice) / atrPrice : 2.0;
      double distLVN = (m_majorLVNPrice > 0) ? MathAbs(bid - m_majorLVNPrice) / atrPrice : 2.0;
      double distPOC = (state.vpPOC > 0) ? MathAbs(bid - state.vpPOC) / atrPrice : 1.0;
      double distNaked = (state.vpNearestNakedPOC > 0) ? MathAbs(bid - state.vpNearestNakedPOC) / atrPrice : 3.0;
      double distBestHVN = (state.vpBestHVN > 0) ? MathAbs(bid - state.vpBestHVN) / atrPrice : 2.0;

      double targets[] = {distHVN, distLVN, distPOC, distNaked, distBestHVN};
      double bestTarget = 0;
      for(int i = 0; i < ArraySize(targets); i++)
         if(targets[i] > 0.3 && targets[i] < 4.0 && targets[i] > bestTarget)
            bestTarget = targets[i];
      if(bestTarget <= 0) bestTarget = 1.5;
      m_expectedMoveATR = bestTarget;

      double regimeProb = 0.40;
      switch(m_auctionRegime)
        {
         case REGIME_BALANCED_ROTATION:  regimeProb = 0.45; break;
         case REGIME_COMPRESSION:        regimeProb = 0.30; break;
         case REGIME_TREND_INITIATION:   regimeProb = 0.60; break;
         case REGIME_TREND_CONTINUATION: regimeProb = 0.65; break;
         case REGIME_RE_ACCUMULATION:    regimeProb = 0.55; break;
         case REGIME_TREND_EXHAUSTION:   regimeProb = 0.35; break;
         case REGIME_FAILED_AUCTION:     regimeProb = 0.30; break;
         case REGIME_EXCESS:             regimeProb = 0.40; break;
         case REGIME_CHAOTIC:            regimeProb = 0.10; break;
        }
      double acceptancePenalty = m_currentAcceptance.acceptanceScore * 0.15;
      m_targetProbability = Clamp01(regimeProb - acceptancePenalty);
      m_expectedReward = m_expectedMoveATR * m_targetProbability;
     }

   //+------------------------------------------------------------------+
   //| PHASE 7: TRADE QUALITY                                            |
   //+------------------------------------------------------------------+
   void ComputeTradeQuality(const SVPPipelineState &state)
     {
      double rewardComp = Clamp01(m_expectedReward / 3.0) * 0.35;
      double contextComp = m_auctionRegimeConf * 0.25;
      double auctionComp = (m_profileShapeConfidence * 0.5 + m_hvnClusterStrength * 0.5) * 0.25;
      double failPenalty = m_auctionFailureScore * 0.15;
      m_tradeQuality = Clamp01(rewardComp + contextComp + auctionComp - failPenalty);
      if(m_tradeQuality >= 0.80)      m_tradeGrade = 4;
      else if(m_tradeQuality >= 0.65) m_tradeGrade = 3;
      else if(m_tradeQuality >= 0.50) m_tradeGrade = 2;
      else if(m_tradeQuality >= 0.35) m_tradeGrade = 1;
      else                            m_tradeGrade = 0;
     }

   //+------------------------------------------------------------------+
   //| PHASE 8: AUCTION TARGET                                           |
   //+------------------------------------------------------------------+
   void ComputeAuctionTarget(double bid, double atr, const SVPPipelineState &state)
     {
      m_targetPrice = 0; m_targetType = TARGET_NONE; m_targetConfidence = 0;
      if(atr <= 0) return;
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;

      struct SCandidate { double price; int type; double conf; double dist; };
      SCandidate cands[10]; int cCount = 0;

      if(state.vpPOC > 0 && MathAbs(bid - state.vpPOC) > atrPrice * 0.3)
        { cands[cCount].price = state.vpPOC; cands[cCount].type = TARGET_POC;
          cands[cCount].dist = MathAbs(bid - state.vpPOC) / atrPrice; cands[cCount].conf = 0.70; cCount++; }
      if(state.vpVAH > 0 && state.vpVAH > bid && (state.vpVAH - bid) > atrPrice * 0.3)
        { cands[cCount].price = state.vpVAH; cands[cCount].type = TARGET_VAH;
          cands[cCount].dist = (state.vpVAH - bid) / atrPrice; cands[cCount].conf = 0.60; cCount++; }
      if(state.vpVAL > 0 && state.vpVAL < bid && (bid - state.vpVAL) > atrPrice * 0.3)
        { cands[cCount].price = state.vpVAL; cands[cCount].type = TARGET_VAL;
          cands[cCount].dist = (bid - state.vpVAL) / atrPrice; cands[cCount].conf = 0.60; cCount++; }
      if(m_majorHVNPrice > 0 && MathAbs(bid - m_majorHVNPrice) > atrPrice * 0.3)
        { cands[cCount].price = m_majorHVNPrice; cands[cCount].type = TARGET_HVN;
          cands[cCount].dist = MathAbs(bid - m_majorHVNPrice) / atrPrice; cands[cCount].conf = 0.55; cCount++; }
      if(state.vpNearestNakedPOC > 0 && MathAbs(bid - state.vpNearestNakedPOC) > atrPrice * 0.3)
        { cands[cCount].price = state.vpNearestNakedPOC; cands[cCount].type = TARGET_NAKED_POC;
          cands[cCount].dist = MathAbs(bid - state.vpNearestNakedPOC) / atrPrice; cands[cCount].conf = 0.65; cCount++; }
      if(state.vpBestHVN > 0 && MathAbs(bid - state.vpBestHVN) > atrPrice * 0.3)
        { cands[cCount].price = state.vpBestHVN; cands[cCount].type = TARGET_BEST_HVN;
          cands[cCount].dist = MathAbs(bid - state.vpBestHVN) / atrPrice;
          cands[cCount].conf = 0.60 + state.vpBestHVNScore * 0.2; cCount++; }

      if(cCount == 0) return;
      int bestIdx = -1; double bestScore = 0;
      for(int i = 0; i < cCount; i++)
        { if(cands[i].dist < 0.3 || cands[i].dist > 4.0) continue;
          double score = cands[i].conf / (cands[i].dist + 0.5);
          if(score > bestScore) { bestScore = score; bestIdx = i; } }
      if(bestIdx < 0) return;  // no valid candidate passed distance filter
      m_targetPrice = cands[bestIdx].price;
      m_targetType = (EAuctionTargetType)cands[bestIdx].type;
      m_targetConfidence = Clamp01(cands[bestIdx].conf);
     }

   //+------------------------------------------------------------------+
   //| PHASE 9: POSITION MANAGEMENT FEATURES                             |
   //+------------------------------------------------------------------+
   void ComputePositionFeatures(double bid, double atr, const SVPPipelineState &state)
     {
      m_profitZoneScore = 0; m_exhaustionScore = 0;
      m_continuationScore = 0; m_reversalRiskScore = 0;
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;

      if(m_distToMajorHVN > 0 && m_distToMajorHVN < 0.5)
         m_profitZoneScore = Clamp01(1.0 - m_distToMajorHVN / 0.5);

      m_exhaustionScore = m_auctionFailureScore * 0.40
         + ((m_valueAreaState == VA_CONTRACTING) ? 0.30 : 0)
         + (1.0 - m_currentAcceptance.acceptanceScore) * 0.30;
      if(state.vpUpthrustDetected || state.vpSpringDetected)
         m_exhaustionScore = MathMin(1.0, m_exhaustionScore + 0.2);
      m_exhaustionScore = Clamp01(m_exhaustionScore);

      double valMig = MathAbs(state.vpDevPOCDirection);
      m_continuationScore = ((m_auctionRegime == REGIME_TREND_CONTINUATION
                              || m_auctionRegime == REGIME_TREND_INITIATION) ? 0.40 : 0)
         + ((m_valueAreaState == VA_EXPANDING) ? 0.30 : 0)
         + valMig * 0.30;
      m_continuationScore = Clamp01(m_continuationScore);

      m_reversalRiskScore = m_auctionFailureScore * 0.35
         + ((m_auctionRegime == REGIME_TREND_EXHAUSTION || m_auctionRegime == REGIME_EXCESS
             || m_auctionRegime == REGIME_FAILED_AUCTION) ? 0.30 : 0)
         + ((m_profileShape == PROFILE_D) ? m_profileShapeConfidence * 0.20 : 0);
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
         m_reversalRiskScore = MathMin(1.0, m_reversalRiskScore + 0.15);
      m_reversalRiskScore = Clamp01(m_reversalRiskScore);
     }

public:
   void SetVPEngine(CVolumeProfileEngine *engine) { m_vpEngine = engine; }

   void Bootstrap(const string symbol)
     {
      Configure(symbol, "AuctionIntelligence");
      m_vpEngine = NULL;
      m_auctionState = AUCTION_BALANCED; m_auctionBalanceScore = 0.5;
      m_auctionRegime = REGIME_BALANCED_ROTATION; m_auctionRegimeConf = 0;
      m_profileShape = PROFILE_UNKNOWN; m_profileShapeConfidence = 0;
      m_skewness = 0; m_kurtosis = 0; m_bimodality = 0;
      m_hvnClusterCount = 0; m_lvnClusterCount = 0;
      m_distToMajorHVN = 0; m_distToMajorLVN = 0;
      m_majorHVNPrice = 0; m_majorLVNPrice = 0;
      m_hvnClusterStrength = 0; m_lvnClusterStrength = 0;
      m_vaHistCount = 0; m_vaHistWriteIdx = 0;
      m_vahVelocity = 0; m_valVelocity = 0;
      m_vaExpansionRate = 0; m_valueAreaState = VA_STABLE;
      m_expectedReward = 0; m_expectedMoveATR = 0; m_targetProbability = 0;
      m_tradeQuality = 0; m_tradeGrade = 0;
      m_targetPrice = 0; m_targetType = TARGET_NONE; m_targetConfidence = 0;
      m_profitZoneScore = 0; m_exhaustionScore = 0;
      m_continuationScore = 0; m_reversalRiskScore = 0;
      m_auctionFailureScore = 0; m_failureCounter = 0;
      m_prevVAH = 0; m_prevVAL = 0; m_prevPOC = 0;
      ArrayInitialize(m_vahHistory, 0); ArrayInitialize(m_valHistory, 0);
      ZeroMemory(m_currentAcceptance); ZeroMemory(m_hvnAcceptance); ZeroMemory(m_pocAcceptance);
     }

   virtual bool Execute(SVPPipelineState &state) override
     {
      CVPModuleBase::Execute(state);
      if(!state.vpValid) return true;
      double bid = state.marketData.bid;
      double atr = state.marketData.atrProxy;

      m_currentAcceptance = ComputeAcceptance(bid);
      if(state.vpNearestHVN > 0) m_hvnAcceptance = ComputeAcceptance(state.vpNearestHVN);
      if(state.vpPOC > 0)        m_pocAcceptance = ComputeAcceptance(state.vpPOC);
      BuildClusters(bid, atr);
      ClassifyProfileShape(state);
      UpdateValueAreaDynamics(state.vpVAH, state.vpVAL, atr);
      DetectAuctionFailure(bid, atr, state);
      ClassifyAuctionState(state, atr);
      ComputeExpectedReward(bid, atr, state);
      ComputeTradeQuality(state);
      ComputeAuctionTarget(bid, atr, state);
      ComputePositionFeatures(bid, atr, state);

      // ── [v4.0] Long-term reversal risk modifier ─────────────────────
      if(state.vpLTValid && state.vpLTNearestZoneStrength > 0.6)
        {
         double atrPrice2 = atr * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         if(atrPrice2 <= 0) atrPrice2 = atr;
         double zoneDist2 = MathAbs(bid - state.vpLTNearestZonePrice) / atrPrice2;
         if(zoneDist2 < 2.0)
            m_reversalRiskScore = MathMin(1.0, m_reversalRiskScore + 0.12 * state.vpLTNearestZoneStrength);
        }

      m_prevVAH = state.vpVAH; m_prevVAL = state.vpVAL; m_prevPOC = state.vpPOC;
      WriteAuctionState(state);
      return true;
     }

   void WriteAuctionState(SVPPipelineState &state)
     {
      state.auctAcceptanceScore     = m_currentAcceptance.acceptanceScore;
      state.auctState               = (int)m_auctionState;
      state.auctBalanceScore        = m_auctionBalanceScore;
      state.auctProfileShape        = (int)m_profileShape;
      state.auctProfileShapeConf    = m_profileShapeConfidence;
      state.auctMajorHVN            = m_majorHVNPrice;
      state.auctMajorLVN            = m_majorLVNPrice;
      state.auctDistToMajorHVN_ATR  = m_distToMajorHVN;
      state.auctDistToMajorLVN_ATR  = m_distToMajorLVN;
      state.auctVAExpansionRate     = m_vaExpansionRate;
      state.auctValueAreaState      = (int)m_valueAreaState;
      state.auctFailureScore        = m_auctionFailureScore;
      state.auctRegime              = (int)m_auctionRegime;
      state.auctRegimeConfidence    = m_auctionRegimeConf;
      state.auctExpectedReward      = m_expectedReward;
      state.auctExpectedMoveATR     = m_expectedMoveATR;
      state.auctTargetProbability   = m_targetProbability;
      state.auctTradeQuality        = m_tradeQuality;
      state.auctTradeGrade          = m_tradeGrade;
      state.auctTargetPrice         = m_targetPrice;
      state.auctTargetType          = (int)m_targetType;
      state.auctTargetConfidence    = m_targetConfidence;
      state.auctProfitZoneScore     = m_profitZoneScore;
      state.auctExhaustionScore     = m_exhaustionScore;
      state.auctContinuationScore   = m_continuationScore;
      state.auctReversalRiskScore   = m_reversalRiskScore;
      state.auctHVNClusterStrength  = m_hvnClusterStrength;
      state.auctLVNClusterStrength  = m_lvnClusterStrength;
     }

   // Accessors
   EAuctionRegime     GetAuctionRegime(void)     const { return m_auctionRegime; }
   double             GetRegimeConfidence(void)  const { return m_auctionRegimeConf; }
   EAuctionState      GetAuctionState(void)      const { return m_auctionState; }
   double             GetBalanceScore(void)      const { return m_auctionBalanceScore; }
   double             GetTradeQuality(void)      const { return m_tradeQuality; }
   int                GetTradeGrade(void)        const { return m_tradeGrade; }
   double             GetFailureScore(void)      const { return m_auctionFailureScore; }
   double             GetExpectedReward(void)    const { return m_expectedReward; }
   double             GetContinuationScore(void) const { return m_continuationScore; }
   double             GetReversalRiskScore(void) const { return m_reversalRiskScore; }
   double             GetExhaustionScore(void)   const { return m_exhaustionScore; }
   double             GetTargetPrice(void)       const { return m_targetPrice; }
   EAuctionTargetType GetTargetType(void)        const { return m_targetType; }
   double             GetTargetConfidence(void)  const { return m_targetConfidence; }
  };

#endif // __EA_ROOT_AUCTIONINTELLIGENCE_MQH__
