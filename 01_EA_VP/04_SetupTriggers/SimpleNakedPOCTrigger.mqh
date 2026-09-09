//+------------------------------------------------------------------+
//| SimpleNakedPOCTrigger.mqh — v6.1 Data Collection                 |
//| Trades toward unretested POC levels (support/resistance magnet)   |
//| Hard gates: vpValid + nakedPOC exists + distance + regime        |
//| Direction: toward naked POC (POC acts as price magnet)            |
//| Note: This trigger is exempt from structural direction check     |
//|       because POC attraction operates independently of BOS/CHOCH |
//+------------------------------------------------------------------+
#property copyright "Quant Trading"
#property version   "6.10"
#include "..\Config\GlobalParameters.mqh"

class CSimpleNakedPOCTrigger : public CVPModuleBase
  {
private:
   datetime m_lastFired;

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol, "SimpleNakedPOC");
      m_lastFired = 0;
     }

   virtual bool Execute(SVPPipelineState &state) override
     {
      CVPModuleBase::Execute(state);
      if(state.primarySetup.isValid) return true;
      if(m_lastFired > 0 && TimeCurrent() - m_lastFired < SETUP_COOLDOWN_SEC) return true;
      if(!state.vpValid) return true;

      double bid = state.marketData.bid;
      double atr = state.marketData.atrProxy;
      if(atr <= 0) return true;
      double pointSize = state.marketData.pointSize;
      double atrPrice = atr * pointSize;

      // ═══ HARD GATES ═══
      double nakedPOC = state.vpNearestNakedPOC;
      if(nakedPOC <= 0) return true;

      // Distance: price must be approaching but not already at the POC
      // Too close (< 0.15 ATR) = already at POC, no trade
      // Too far (> 3.5 ATR) = low probability of reaching
      double distATR = MathAbs(bid - nakedPOC) / atrPrice;
      if(distATR < 0.15 || distATR > 3.5) return true;

      // Block in chaotic or excess regimes
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS) return true;
      if(state.auctTradeQuality < 0.10) return true;

      // ─── Direction: toward Naked POC (POC as price magnet) ─────
      bool bullish = (nakedPOC > bid);
      bool bearish = (nakedPOC < bid);
      if(!bullish && !bearish) return true;

      // ─── Optional confirmation signals (boost thesis, don't block) ─
      double confirmBonus = 0;
      // Migration toward POC direction
      if(bullish && state.vpDevPOCDirection > 0.01) confirmBonus += 0.10;
      if(bearish && state.vpDevPOCDirection < -0.01) confirmBonus += 0.10;
      // Trade quality adds confidence
      if(state.auctTradeQuality > 0.5) confirmBonus += 0.08;
      // Continuation in POC direction
      if(bullish && state.auctContinuationScore > 0.5) confirmBonus += 0.08;
      if(bearish && state.auctContinuationScore < 0.4) confirmBonus += 0.08;
      // Closer = more magnetic
      if(distATR < 1.0) confirmBonus += 0.10;

      // ═══ FIRE SETUP ═══
      double thesis = state.auctTradeQuality * 0.30
                    + state.vpMigrationConfidence * 0.20
                    + Clamp01(1.0 - distATR / 3.5) * 0.30
                    + confirmBonus;

      state.primarySetup.isValid = true;
      state.primarySetup.setupType = SETUP_NAKED_POC;
      state.primarySetup.entryPrice = bullish ? state.marketData.ask : bid;
      state.primarySetup.detectedAt = TimeCurrent();
      state.winProbability = Clamp01(thesis);

      // ─── SL & TP ─────────────────────────────────────────
      if(bullish)
        {
         // SL below recent support
         double support = bid - atrPrice * 1.2;
         if(state.vpVAL > 0 && state.vpVAL < bid && state.vpVAL > support)
            support = state.vpVAL;
         if(state.auctMajorLVN > 0 && state.auctMajorLVN < bid && state.auctMajorLVN > support)
            support = state.auctMajorLVN;
         state.primarySetup.stopLoss = support - atrPrice * 0.15;

         // TP at or beyond the naked POC
         double tp = nakedPOC;
         // If auction target is beyond POC, use that
         if(state.auctTargetPrice > nakedPOC && state.auctTargetConfidence > 0.35)
            tp = state.auctTargetPrice;
         // Minimum TP distance
         if(tp - state.marketData.ask < atrPrice * 0.5)
            tp = state.marketData.ask + atrPrice * 1.5;
         state.primarySetup.takeProfit = tp;
        }
      else
        {
         // SL above recent resistance
         double resistance = bid + atrPrice * 1.2;
         if(state.vpVAH > 0 && state.vpVAH > bid && state.vpVAH < resistance)
            resistance = state.vpVAH;
         if(state.auctMajorHVN > 0 && state.auctMajorHVN > bid && state.auctMajorHVN < resistance)
            resistance = state.auctMajorHVN;
         state.primarySetup.stopLoss = resistance + atrPrice * 0.15;

         // TP at or beyond the naked POC
         double tp = nakedPOC;
         if(state.auctTargetPrice > 0 && state.auctTargetPrice < nakedPOC && state.auctTargetConfidence > 0.35)
            tp = state.auctTargetPrice;
         // Minimum TP distance
         if(bid - tp < atrPrice * 0.5)
            tp = bid - atrPrice * 1.5;
         state.primarySetup.takeProfit = tp;
        }

      // ─── RR validation ────────────────────────────────────
      state.primarySetup.riskReward = MathAbs(state.primarySetup.takeProfit - state.primarySetup.entryPrice) /
                                      MathMax(MathAbs(state.primarySetup.entryPrice - state.primarySetup.stopLoss), pointSize);
      if(state.primarySetup.riskReward < 1.0)
        { state.primarySetup.isValid = false; return true; }

      m_lastFired = TimeCurrent();
      return true;
     }
  };
