#ifndef __EA_ROOT_STRUCTUREENGINE_MQH__
#define __EA_ROOT_STRUCTUREENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "SwingEngine.mqh"
#include "..\Volumeprofile\AuctionThesisManager.mqh"

//+------------------------------------------------------------------+
//| StructureEngine v4.0 — Auction‑Enhanced Market Structure          |
//| Hard regime filter, thesis health, composite confirmation        |
//+------------------------------------------------------------------+

enum EStructurePattern { STRUCTURE_HH_HL, STRUCTURE_LH_LL, STRUCTURE_MIXED };

class CStructureEngine : public CPipelineModuleBase
  {
private:
   EStructurePattern m_pattern;
   double            m_structureBias;
   bool              m_higherHighs;
   bool              m_higherLows;

   CAuctionThesisManager m_thesisManager;   // để lấy thesis health

   //+------------------------------------------------------------------+
   //| Điều chỉnh bias bằng VP + Auction (mở rộng từ v3.0)            |
   //+------------------------------------------------------------------+
   void AdjustBiasWithVP(const SPipelineState &state, double &bias)
     {
      if(!state.vpValid) return;

      // ── 1. POC migration ──────────────────────────────────
      double slope = state.vpDevPOCSlope;
      double migConf = state.vpMigrationConfidence;
      if(MathAbs(slope) > 0.02 && migConf > 0.4)
        {
         if((bias > 0.5 && slope > 0) || (bias < 0.5 && slope < 0))
            bias += 0.04 * migConf;
         else if((bias > 0.5 && slope < 0) || (bias < 0.5 && slope > 0))
            bias -= 0.06 * migConf;
        }

      // ── 2. VA Overlap bias ────────────────────────────────
      int vaBias = state.vpVAOverlapBias;
      if((bias > 0.5 && vaBias == 1) || (bias < 0.5 && vaBias == -1))
         bias += 0.03;
      else if((bias > 0.5 && vaBias == -1) || (bias < 0.5 && vaBias == 1))
         bias -= 0.03;

      // ── 3. Anchored breakout profile ──────────────────────
      if(state.vpBreakoutPOC > 0)
        {
         double bid = state.marketData.bid;
         if((bias > 0.5 && bid > state.vpBreakoutPOC) || (bias < 0.5 && bid < state.vpBreakoutPOC))
            bias += 0.04;
        }

      // ── 4. Composite position ─────────────────────────────
      int compPos = state.vpCompositePosition;
      if((bias > 0.5 && compPos == -1) || (bias < 0.5 && compPos == 1))
         bias += 0.03;

      // ── 5. Fake breakout traps ────────────────────────────
      if((bias > 0.5 && state.vpUpthrustDetected) || (bias < 0.5 && state.vpSpringDetected))
         bias -= 0.08;

      // ── 6. Profile thinness ───────────────────────────────
      if(state.vpThinnessRatio > 0 && state.vpThinnessRatio < 0.3)
        {
         if(bias > 0.5 || bias < 0.5)
            bias += 0.03;
        }

      // ── CÁC BỔ SUNG v4.0 ──────────────────────────────────
      // 7. Sức khỏe luận điểm (thesis health)
      double thesisHealth = 0.5;
      if(state.vpValid)
        {
         // Chọn archetype dựa trên bias hiện tại
         EEntryArchetype arch = (bias > 0.5) ? ENTRY_TREND_CONTINUATION : ENTRY_TREND_CONTINUATION;
         if(m_thesisManager.GetArchetype() != arch)
            m_thesisManager.InitTrade(arch, 0, state.auctRegimeConfidence, m_symbol);

         SThesisOutput thesisOut = m_thesisManager.Evaluate(state, 0.0, 0); // không cần ATR
         thesisHealth = thesisOut.thesis.thesisHealth;
        }

      // Xu hướng mạnh nếu thesis health cao, yếu nếu thấp
      if(bias > 0.5)
         bias += (thesisHealth - 0.5) * 0.10;
      else if(bias < 0.5)
         bias -= (thesisHealth - 0.5) * 0.10;

      // 8. Xác nhận composite đa khung thời gian
      if(state.vpValid && state.vpCompositeVAH > state.vpCompositeVAL)
        {
         double bid = state.marketData.bid;
         if(bias > 0.5 && bid > state.vpCompositeVAH)
            bias += 0.05;   // uptrend vượt composite VAH → mạnh
         else if(bias > 0.5 && bid < state.vpCompositeVAL)
            bias -= 0.06;   // uptrend nhưng giá dưới composite VAL → nghi ngờ
         else if(bias < 0.5 && bid < state.vpCompositeVAL)
            bias += 0.05;   // downtrend dưới VAL → mạnh
         else if(bias < 0.5 && bid > state.vpCompositeVAH)
            bias -= 0.06;   // downtrend nhưng giá trên VAH → nghi ngờ
        }

      // 9. Bộ lọc regime cứng: nếu regime không cho phép cấu trúc rõ ràng, ép về 0.5
      EAuctionRegime regime = (EAuctionRegime)state.auctRegime;
      double regimeConf = state.auctRegimeConfidence;
      if(regime == REGIME_CHAOTIC || regime == REGIME_EXCESS ||
         (regime == REGIME_FAILED_AUCTION && regimeConf > 0.6))
        {
         bias = 0.5;   // không có cấu trúc
        }

      // Giới hạn bias
      bias = MathMax(0.10, MathMin(0.90, bias));
     }

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol,"StructureEngine");
      m_pattern = STRUCTURE_MIXED;
      m_structureBias = 0.5;
      m_higherHighs = false; m_higherLows = false;
      m_thesisManager.Reset();
     }

   // Legacy method for backward compatibility
   void Analyze(const CSwingEngine &swings)
     {
      SSwingPoint lastHigh, prevHigh, lastLow, prevLow;
      bool hasLH = swings.LastSwingHigh(lastHigh) && swings.PrevSwingHigh(prevHigh);
      bool hasLL = swings.LastSwingLow(lastLow) && swings.PrevSwingLow(prevLow);

      m_higherHighs = hasLH && (lastHigh.price > prevHigh.price);
      m_higherLows  = hasLL && (lastLow.price > prevLow.price);

      if(m_higherHighs && m_higherLows)
        { m_pattern = STRUCTURE_HH_HL; m_structureBias = 0.8; }
      else if(!m_higherHighs && !m_higherLows)
        { m_pattern = STRUCTURE_LH_LL; m_structureBias = 0.2; }
      else
        { m_pattern = STRUCTURE_MIXED; m_structureBias = 0.5; }
     }

   virtual bool Execute(SPipelineState &state) override
     {
      CPipelineModuleBase::Execute(state);

      int hiCount = state.structure.swingHighCount;
      int loCount = state.structure.swingLowCount;

      if(hiCount >= 2)
         m_higherHighs = (state.structure.swingHighs[hiCount-1].price > state.structure.swingHighs[hiCount-2].price);
      else
         m_higherHighs = false;

      if(loCount >= 2)
         m_higherLows = (state.structure.swingLows[loCount-1].price > state.structure.swingLows[loCount-2].price);
      else
         m_higherLows = false;

      // Base bias from swing structure
      if(m_higherHighs && m_higherLows)
        { m_pattern = STRUCTURE_HH_HL; m_structureBias = 0.8; }
      else if(!m_higherHighs && !m_higherLows)
        { m_pattern = STRUCTURE_LH_LL; m_structureBias = 0.2; }
      else
        { m_pattern = STRUCTURE_MIXED; m_structureBias = 0.5; }

      // Apply VP/Auction adjustments (đã nâng cấp)
      AdjustBiasWithVP(state, m_structureBias);

      state.structure.structureBias = m_structureBias;
      return true;
     }

   bool IsUptrend(void) const { return m_pattern == STRUCTURE_HH_HL; }
   bool IsDowntrend(void) const { return m_pattern == STRUCTURE_LH_LL; }
   EStructurePattern Pattern(void) const { return m_pattern; }
  };

#endif