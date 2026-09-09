#ifndef __EA_ROOT_AUCTIONTHESISMANAGER_MQH__
#define __EA_ROOT_AUCTIONTHESISMANAGER_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "AuctionEnums.mqh"

//+------------------------------------------------------------------+
//| Auction Thesis Manager v4 — 9-Regime Integrated Thesis Engine    |
//| Synchronised with CAuctionIntelligence v4 (EAuctionRegime 9).    |
//+------------------------------------------------------------------+

// Note: EAuctionRegime is defined in GlobalParameters.mqh:
//   0=BALANCED_ROTATION, 1=COMPRESSION, 2=TREND_INITIATION,
//   3=TREND_CONTINUATION, 4=RE_ACCUMULATION, 5=EXHAUSTION,
//   6=FAILED_AUCTION, 7=EXCESS, 8=CHAOTIC

enum EEntryArchetype
  {
   ENTRY_UNKNOWN            = 0,
   ENTRY_BREAKOUT           = 1,
   ENTRY_BREAKOUT_RETEST    = 2,
   ENTRY_PULLBACK           = 3,
   ENTRY_TREND_CONTINUATION = 4,
   ENTRY_SWEEP_REVERSAL     = 5,
   ENTRY_MEAN_REVERSION     = 6
  };

enum ETradeLifecycle
  {
   TRADE_INITIATION   = 0,
   TRADE_CONFIRMATION = 1,
   TRADE_DEVELOPMENT  = 2,
   TRADE_EXPANSION    = 3,
   TRADE_MATURE       = 4,
   TRADE_EXHAUSTION   = 5
  };

enum EExitSeverity
  {
   EXIT_NONE    = 0,
   EXIT_TIGHTEN = 1,
   EXIT_REDUCE  = 2,
   EXIT_PARTIAL = 3,
   EXIT_FULL    = 4
  };

struct STradeThesis
  {
   double thesisStrength;
   double thesisHealth;
   double thesisInvalidationRisk;
   bool   thesisBroken;
  };

struct STrailingProfile
  {
   double baseATRMultiplier;
   double expansionMultiplier;
   double thesisProtectionWeight;
   double structureWeight;
   double continuationWeight;
   double failureSensitivity;
  };

#define THESIS_STRUCT_MEMORY_SIZE 5

struct SStructureMemoryT
  {
   double poc;
   double hvn;
   double lvn;
   double vah;
   double val;
   double acceptanceDuration;
   double migrationVelocity;
   double rejectionStrength;
   int    age;
  };

struct SThesisOutput
  {
   STradeThesis     thesis;
   STrailingProfile profile;
   ETradeLifecycle  lifecycle;
   EExitSeverity    exitSeverity;
   double           conviction;
   double           expectedRemainingReward;
   double           adjustedATRMultiplier;
  };


class CAuctionThesisManager
  {
private:
   EEntryArchetype    m_archetype;
   ETradeLifecycle    m_lifecycle;
   double             m_conviction;
   STradeThesis       m_thesis;
   STrailingProfile   m_profile;
   SStructureMemoryT  m_memory[THESIS_STRUCT_MEMORY_SIZE];
   int                m_memoryCount;
   int                m_memoryWriteIdx;
   int                m_ticksSinceEntry;
   double             m_entryATR;
   double             m_entryConviction;
   string             m_symbol;

   STrailingProfile GetArchetypeProfile(EEntryArchetype arch)
     {
      STrailingProfile p;
      p.baseATRMultiplier = 1.5; p.expansionMultiplier = 2.0;
      p.thesisProtectionWeight = 0.60; p.structureWeight = 0.60;
      p.continuationWeight = 0.60; p.failureSensitivity = 0.70;
      switch(arch)
        {
         case ENTRY_BREAKOUT:
            p.baseATRMultiplier=1.5; p.expansionMultiplier=2.0;
            p.thesisProtectionWeight=0.70; p.failureSensitivity=0.85; break;
         case ENTRY_BREAKOUT_RETEST:
            p.baseATRMultiplier=1.8; p.expansionMultiplier=2.2;
            p.structureWeight=0.75; p.failureSensitivity=0.70; break;
         case ENTRY_PULLBACK:
            p.baseATRMultiplier=2.0; p.expansionMultiplier=2.8;
            p.continuationWeight=0.75; p.failureSensitivity=0.60; break;
         case ENTRY_TREND_CONTINUATION:
            p.baseATRMultiplier=2.2; p.expansionMultiplier=3.5;
            p.continuationWeight=0.90; p.failureSensitivity=0.50; break;
         case ENTRY_SWEEP_REVERSAL:
            p.baseATRMultiplier=1.2; p.expansionMultiplier=1.5;
            p.thesisProtectionWeight=0.90; p.failureSensitivity=0.95; break;
         case ENTRY_MEAN_REVERSION:
            p.baseATRMultiplier=1.0; p.expansionMultiplier=1.3;
            p.thesisProtectionWeight=0.75; p.structureWeight=0.80;
            p.continuationWeight=0.20; p.failureSensitivity=0.80; break;
         default: break;
        }
      return p;
     }

   bool IsRegimeCompatible(EEntryArchetype arch, EAuctionRegime regime)
     {
      switch(arch)
        {
         case ENTRY_BREAKOUT:
            return (regime==REGIME_TREND_INITIATION || regime==REGIME_TREND_CONTINUATION);
         case ENTRY_BREAKOUT_RETEST:
            return (regime==REGIME_TREND_INITIATION || regime==REGIME_RE_ACCUMULATION);
         case ENTRY_PULLBACK:
            return (regime==REGIME_TREND_CONTINUATION || regime==REGIME_RE_ACCUMULATION);
         case ENTRY_TREND_CONTINUATION:
            return (regime==REGIME_TREND_CONTINUATION);
         case ENTRY_SWEEP_REVERSAL:
            return (regime==REGIME_FAILED_AUCTION || regime==REGIME_EXCESS);
         case ENTRY_MEAN_REVERSION:
            return (regime==REGIME_BALANCED_ROTATION || regime==REGIME_COMPRESSION);
         default: return true;
        }
     }

   double GetRegimeProfileBoost(EAuctionRegime regime)
     {
      switch(regime)
        {
         case REGIME_TREND_INITIATION:   return 1.1;
         case REGIME_TREND_CONTINUATION: return 1.0;
         case REGIME_RE_ACCUMULATION:    return 0.9;
         case REGIME_BALANCED_ROTATION:  return 0.85;
         case REGIME_COMPRESSION:        return 0.7;
         case REGIME_TREND_EXHAUSTION:         return 0.75;
         case REGIME_FAILED_AUCTION:     return 0.6;
         case REGIME_EXCESS:             return 0.5;
         case REGIME_CHAOTIC:            return 0.4;
         default: return 1.0;
        }
     }

   void EvaluateThesis(const SVPPipelineState &state, double floatingProfit, double atr)
     {
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;

      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS)
        { m_thesis.thesisStrength=0; m_thesis.thesisInvalidationRisk=1;
          m_thesis.thesisBroken=true; m_thesis.thesisHealth=0; return; }

      double strength = 0.5, invalidRisk = 0.0;
      bool broken = false;
      double contScore = state.auctContinuationScore;
      double failScore = state.auctFailureScore;
      double exhaustScore = state.auctExhaustionScore;
      double reversalRisk = state.auctReversalRiskScore;
      double balanceScore = state.auctBalanceScore;
      double devPOCDir = MathAbs(state.vpDevPOCDirection);
      double migConf = state.vpMigrationConfidence;
      bool insideVA = state.vpInsideVA;
      bool isFake = (state.vpUpthrustDetected || state.vpSpringDetected);
      double regimePenalty = IsRegimeCompatible(m_archetype, regime) ? 1.0 : 0.6;

      switch(m_archetype)
        {
         case ENTRY_BREAKOUT:
            strength = contScore*0.30 + (!insideVA?0.25:0) + (1.0-failScore)*0.15;
            strength *= regimePenalty;
            invalidRisk = failScore*0.40 + (insideVA?0.20:0) + (isFake?0.25:0);
            broken = (insideVA && failScore>0.60) || isFake || regime==REGIME_FAILED_AUCTION;
            break;
         case ENTRY_BREAKOUT_RETEST:
           {
            // Retest: acceptance at level + continuation + low failure
            double acceptScore = state.auctAcceptanceScore;
            strength = acceptScore*0.25 + contScore*0.25 + (1.0-failScore)*0.20 + migConf*0.15;
            strength *= regimePenalty;
            invalidRisk = failScore*0.35 + reversalRisk*0.25 + (1.0-acceptScore)*0.15 + (isFake?0.20:0);
            broken = (failScore>0.70 && acceptScore<0.20) || isFake || regime==REGIME_FAILED_AUCTION;
            break;
           }
         case ENTRY_PULLBACK:
            strength = contScore*0.30 + (1.0-reversalRisk)*0.20 + (devPOCDir>0.3?0.20:0.10);
            strength *= regimePenalty;
            invalidRisk = reversalRisk*0.35 + exhaustScore*0.25 + failScore*0.20;
            broken = (reversalRisk>0.75 && contScore<0.15) || (regime==REGIME_TREND_EXHAUSTION && exhaustScore>0.7);
            break;
         case ENTRY_TREND_CONTINUATION:
            strength = contScore*0.25 + (1.0-exhaustScore)*0.15 + (1.0-failScore)*0.15 + migConf*0.20;
            strength *= regimePenalty;
            invalidRisk = exhaustScore*0.30 + failScore*0.25 + reversalRisk*0.15 + (isFake?0.15:0);
            broken = (exhaustScore>0.70 && failScore>0.50) || (isFake && contScore<0.30);
            break;
         case ENTRY_SWEEP_REVERSAL:
            strength = failScore*0.20 + reversalRisk*0.25 + (1.0-contScore)*0.30 + (isFake?0.35:0);
            strength *= regimePenalty;
            invalidRisk = contScore*0.45 + (1.0-failScore)*0.25;
            broken = (contScore>0.70 && failScore<0.20) || (regime==REGIME_TREND_CONTINUATION && contScore>0.6);
            break;
         case ENTRY_MEAN_REVERSION:
           {
            double distPOC = (state.vpPOC>0) ? MathAbs(state.marketData.bid-state.vpPOC)/(atr*pointSize) : 1.0;
            strength = balanceScore*0.25 + (distPOC<0.5?0.35:0) + (1.0-contScore)*0.10;
            strength *= regimePenalty;
            invalidRisk = contScore*0.30 + devPOCDir*0.25 + (isFake?0.20:0);
            broken = (contScore>0.65 && state.auctValueAreaState==(int)VA_EXPANDING);
            break;
           }
         default:
            strength = 0.5; invalidRisk = 0.3;
        }
      m_thesis.thesisStrength = Clamp01(strength);
      m_thesis.thesisInvalidationRisk = Clamp01(invalidRisk);
      m_thesis.thesisBroken = broken;
      m_thesis.thesisHealth = Clamp01(strength - invalidRisk * 0.5);
     }

   void UpdateLifecycle(double floatingProfit, double atr)
     {
      if(atr <= 0) { m_lifecycle = TRADE_INITIATION; return; }
      double profitATR = floatingProfit / atr;
      m_ticksSinceEntry++;
      if(profitATR < 0.3 || m_thesis.thesisHealth < 0.2) m_lifecycle = TRADE_INITIATION;
      else if(profitATR < 1.0) m_lifecycle = TRADE_CONFIRMATION;
      else if(profitATR < 2.0) m_lifecycle = TRADE_DEVELOPMENT;
      else if(profitATR < 4.0 && m_thesis.thesisHealth > 0.45) m_lifecycle = TRADE_EXPANSION;
      else if(m_thesis.thesisHealth > 0.35) m_lifecycle = TRADE_MATURE;
      else m_lifecycle = TRADE_EXHAUSTION;
     }

   void UpdateConviction(const SVPPipelineState &state)
     {
      m_conviction = m_entryConviction * 0.25
         + m_thesis.thesisHealth * 0.35
         + state.auctRegimeConfidence * 0.15
         + state.auctTradeQuality * 0.15
         + state.vpMigrationConfidence * 0.10;
      m_conviction = Clamp01(m_conviction);
     }

   double ComputeRemainingReward(const SVPPipelineState &state, double floatingProfit, double atr)
     {
      if(atr <= 0) return 0;
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double totalExp = state.auctExpectedMoveATR;
      if(state.vpBestHVN > 0)
        { double d = MathAbs(state.marketData.bid - state.vpBestHVN) / (atr*pointSize);
          if(d > totalExp) totalExp = d; }
      double captured = floatingProfit / atr;
      double remaining = MathMax(0, totalExp - captured);
      remaining *= m_thesis.thesisHealth * (0.5 + state.auctContinuationScore * 0.5);
      return remaining;
     }

   EExitSeverity ClassifyExitSeverity(void) const
     {
      if(m_thesis.thesisBroken) return EXIT_FULL;
      double risk = m_thesis.thesisInvalidationRisk;
      if(risk > 0.80) return EXIT_PARTIAL;
      if(risk > 0.60 && m_thesis.thesisHealth < 0.30) return EXIT_REDUCE;
      if(risk > 0.45 && (int)m_lifecycle >= (int)TRADE_MATURE) return EXIT_TIGHTEN;
      return EXIT_NONE;
     }

   double ComputeAdjustedATR(const SVPPipelineState &state, double remainingReward)
     {
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double baseMult = m_profile.baseATRMultiplier;
      double regimeBoost = GetRegimeProfileBoost(regime);
      double convScale = 0.8 + m_conviction * 0.4;
      double lcScale = 1.0;
      switch(m_lifecycle)
        { case TRADE_INITIATION:   lcScale=0.80; break;
          case TRADE_CONFIRMATION: lcScale=0.90; break;
          case TRADE_DEVELOPMENT:  lcScale=1.00; break;
          case TRADE_EXPANSION:    lcScale=1.20; break;
          case TRADE_MATURE:       lcScale=0.95; break;
          case TRADE_EXHAUSTION:   lcScale=0.70; break; }
      double rewardScale = 1.0 + Clamp01(remainingReward / 3.0) * 0.3;
      double thesisScale = 0.7 + m_thesis.thesisHealth * 0.3;
      return baseMult * regimeBoost * convScale * lcScale * rewardScale * thesisScale;
     }

public:
   CAuctionThesisManager(void) { Reset(); }

   void Reset(void)
     {
      m_archetype = ENTRY_UNKNOWN;
      m_lifecycle = TRADE_INITIATION;
      m_conviction = 0.5;
      m_thesis.thesisStrength = 0.5; m_thesis.thesisHealth = 0.5;
      m_thesis.thesisInvalidationRisk = 0; m_thesis.thesisBroken = false;
      m_memoryCount = 0; m_memoryWriteIdx = 0;
      m_ticksSinceEntry = 0; m_entryATR = 0; m_entryConviction = 0.5;
      m_symbol = "";
      ZeroMemory(m_profile);
      for(int i = 0; i < THESIS_STRUCT_MEMORY_SIZE; i++) ZeroMemory(m_memory[i]);
     }

   void InitTrade(EEntryArchetype archetype, double entryATR, double entryConviction, string symbol)
     {
      Reset();
      m_archetype = archetype;
      m_entryATR = entryATR;
      m_entryConviction = Clamp01(entryConviction);
      m_symbol = (symbol != "") ? symbol : _Symbol;
      m_profile = GetArchetypeProfile(archetype);
     }

   // Simplified InitThesis for backward compatibility with TradeManager
   void InitThesis(int setupType, double entryATR, double entryConviction)
     {
      EEntryArchetype arch = (EEntryArchetype)setupType;
      InitTrade(arch, entryATR, entryConviction, _Symbol);
     }

   SThesisOutput Evaluate(const SVPPipelineState &state, double floatingProfit, double atr)
     {
      SThesisOutput out;
      EvaluateThesis(state, floatingProfit, atr);
      UpdateLifecycle(floatingProfit, atr);
      UpdateConviction(state);
      double remaining = ComputeRemainingReward(state, floatingProfit, atr);
      out.thesis = m_thesis;
      out.profile = m_profile;
      out.lifecycle = m_lifecycle;
      out.exitSeverity = ClassifyExitSeverity();
      out.conviction = m_conviction;
      out.expectedRemainingReward = remaining;
      out.adjustedATRMultiplier = ComputeAdjustedATR(state, remaining);
      return out;
     }

   // Accessors
   EEntryArchetype GetArchetype(void)    const { return m_archetype; }
   ETradeLifecycle GetLifecycle(void)    const { return m_lifecycle; }
   double          GetConviction(void)   const { return m_conviction; }
   STradeThesis    GetThesis(void)       const { return m_thesis; }
   bool            IsThesisBroken(void)  const { return m_thesis.thesisBroken; }
   double          GetThesisHealth(void) const { return m_thesis.thesisHealth; }
   EExitSeverity   GetExitSeverity(void) const { return ClassifyExitSeverity(); }
  };

#endif // __EA_ROOT_AUCTIONTHESISMANAGER_MQH__
