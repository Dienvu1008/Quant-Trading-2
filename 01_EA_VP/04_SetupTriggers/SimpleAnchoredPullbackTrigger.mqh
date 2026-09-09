//+------------------------------------------------------------------+
//| SimpleAnchoredPullbackTrigger.mqh — v6.0 Data Collection         |
//| Hard gates: vpValid + anchor POC exists + close to POC + regime  |
//| Direction: from continuation + devPOC + price vs POC             |
//+------------------------------------------------------------------+
#property copyright "Quant Trading"
#property version   "6.00"
#include "..\Config\GlobalParameters.mqh"

class CSimpleAnchoredPullbackTrigger : public CVPModuleBase
  {
private:
   datetime m_lastFired;

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol, "SimpleAnchoredPullback");
      m_lastFired = 0;
     }

   virtual bool Execute(SVPPipelineState &state) override
     {
      CVPModuleBase::Execute(state);
      if(state.primarySetup.isValid) return true;
      if(m_lastFired > 0 && TimeCurrent() - m_lastFired < SETUP_COOLDOWN_SEC) return true;
      if(!state.vpValid) return true;

      // ═══ HARD GATES ═══
      // Select anchor POC (priority: pullback > range > breakout)
      double anchorPOC = 0;
      if(state.vpPullbackPOC > 0)      anchorPOC = state.vpPullbackPOC;
      else if(state.vpRangePOC > 0)    anchorPOC = state.vpRangePOC;
      else if(state.vpBreakoutPOC > 0) anchorPOC = state.vpBreakoutPOC;
      if(anchorPOC <= 0) return true;

      double bid = state.marketData.bid;
      double ask = state.marketData.ask;
      double atr = state.marketData.atrProxy;
      if(atr <= 0) return true;
      double pointSize = state.marketData.pointSize;
      double atrPrice = atr * pointSize;

      // Price must be close to anchor POC (max 0.7 ATR)
      double distATR = MathAbs(bid - anchorPOC) / atrPrice;
      if(distATR > 0.7) return true;

      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS || regime == REGIME_FAILED_AUCTION) return true;
      if(state.auctTradeQuality < 0.15) return true;

      // ─── Direction (sign-based from VP signals) ───────────
      double dirScore = 0;
      if(state.auctContinuationScore > 0.4) dirScore += 0.30;
      else if(state.auctContinuationScore < 0.3) dirScore -= 0.30;
      if(state.vpDevPOCDirection > 0.02) dirScore += 0.30;
      else if(state.vpDevPOCDirection < -0.02) dirScore -= 0.30;
      if(state.vpVAOverlapBias == 1) dirScore += 0.20;
      else if(state.vpVAOverlapBias == -1) dirScore -= 0.20;
      // Price vs anchor: above POC = likely bull continuation
      if(bid > anchorPOC) dirScore += 0.10;
      else dirScore -= 0.10;

      bool bullish = (dirScore > 0);
      bool bearish = (dirScore < 0);
      if(!bullish && !bearish) return true;

      // Fake breakout against direction = block
      if(bullish && state.vpUpthrustDetected) return true;
      if(bearish && state.vpSpringDetected)  return true;

      // ═══ FIRE SETUP ═══
      double thesis = state.auctTradeQuality * 0.35 + state.auctContinuationScore * 0.30 + Clamp01(1.0 - distATR / 0.7) * 0.35;

      state.primarySetup.isValid = true;
      state.primarySetup.setupType = SETUP_ANCHORED_PULLBACK;
      state.primarySetup.entryPrice = bullish ? ask : bid;
      state.primarySetup.detectedAt = TimeCurrent();
      state.winProbability = Clamp01(thesis);

      // ─── SL & TP ─────────────────────────────────────────
      if(bullish)
        {
         double support = anchorPOC - atrPrice * 0.2;
         if(state.vpVAL > 0 && state.vpVAL > support) support = state.vpVAL;
         if(state.auctMajorLVN > 0 && state.auctMajorLVN < bid && state.auctMajorLVN > support) support = state.auctMajorLVN;
         state.primarySetup.stopLoss = support - atrPrice * 0.1;

         double tp = (state.auctTargetPrice > bid) ? state.auctTargetPrice
                   : ((state.vpVAH > bid) ? state.vpVAH : bid + atrPrice * 2.0);
         if(tp <= bid) tp = bid + atrPrice * 1.5;
         state.primarySetup.takeProfit = tp;
        }
      else
        {
         double resistance = anchorPOC + atrPrice * 0.2;
         if(state.vpVAH > 0 && state.vpVAH < resistance) resistance = state.vpVAH;
         if(state.auctMajorHVN > 0 && state.auctMajorHVN > bid && state.auctMajorHVN < resistance) resistance = state.auctMajorHVN;
         state.primarySetup.stopLoss = resistance + atrPrice * 0.1;

         double tp = (state.auctTargetPrice > 0 && state.auctTargetPrice < bid) ? state.auctTargetPrice
                   : ((state.vpVAL > 0 && state.vpVAL < bid) ? state.vpVAL : bid - atrPrice * 2.0);
         if(tp >= bid) tp = bid - atrPrice * 1.5;
         state.primarySetup.takeProfit = tp;
        }

      state.primarySetup.riskReward = MathAbs(state.primarySetup.takeProfit - state.primarySetup.entryPrice) /
                                      MathMax(MathAbs(state.primarySetup.entryPrice - state.primarySetup.stopLoss), pointSize);
      if(state.primarySetup.riskReward < 0.8)
        { state.primarySetup.isValid = false; return true; }

      m_lastFired = TimeCurrent();
      return true;
     }
  };
