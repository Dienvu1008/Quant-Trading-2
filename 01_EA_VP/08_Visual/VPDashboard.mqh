#ifndef __VP_DASHBOARD_MQH__
#define __VP_DASHBOARD_MQH__

//+------------------------------------------------------------------+
//| VPDashboard.mqh — Chart dashboard for the VP/Auction EA           |
//|                                                                   |
//| Reads the real SVPPipelineState and renders a compact panel:     |
//|   Header | Market context | VP levels | Auction regime |         |
//|   Structure/Bias | Bonus-engine snapshot | Last setup/decision   |
//|                                                                   |
//| Flicker-free: objects are created once (on first Update) and      |
//| thereafter only their text/color are updated in place. The panel  |
//| uses a fixed layout so every field keeps a stable Y position.     |
//|                                                                   |
//| Disabled in the Strategy Tester unless Visual Mode is on.        |
//+------------------------------------------------------------------+

#include "..\Config\GlobalParameters.mqh"

#define VPDASH_WIDTH        320
#define VPDASH_BG_COLOR     C'20,25,35'
#define VPDASH_BORDER_COLOR C'50,60,80'

class CVPDashboard
{
private:
   bool     m_enabled;
   bool     m_built;          // objects created?
   string   m_prefix;
   string   m_symbol;
   int      m_digits;

   // Cached last setup/decision (persist between ticks with no fresh setup)
   string   m_lastSetup;
   string   m_lastDecision;
   string   m_lastReason;
   double   m_lastWinProb;
   double   m_lastEdgeMult;

   void _DeleteObjects() { ObjectsDeleteAll(0, m_prefix); }

   // Create the background rectangle once.
   void _CreateBackground(int x, int y, int w, int h)
   {
      string full = m_prefix + "bg";
      if(ObjectFind(0, full) < 0)
         ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
      ObjectSetInteger(0, full, OBJPROP_XDISTANCE,    x);
      ObjectSetInteger(0, full, OBJPROP_YDISTANCE,    y);
      ObjectSetInteger(0, full, OBJPROP_XSIZE,        w);
      ObjectSetInteger(0, full, OBJPROP_YSIZE,        h);
      ObjectSetInteger(0, full, OBJPROP_BGCOLOR,      VPDASH_BG_COLOR);
      ObjectSetInteger(0, full, OBJPROP_BORDER_COLOR, VPDASH_BORDER_COLOR);
      ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
      ObjectSetInteger(0, full, OBJPROP_WIDTH,        1);
      ObjectSetInteger(0, full, OBJPROP_BACK,         false);
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE,   false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN,       true);
   }

   // Create one label at a fixed position (static props set once).
   void _CreateLabel(const string name, int x, int y, int sz)
   {
      string full = m_prefix + name;
      if(ObjectFind(0, full) < 0)
         ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetInteger(0, full, OBJPROP_XDISTANCE,  x);
      ObjectSetInteger(0, full, OBJPROP_YDISTANCE,  y);
      ObjectSetInteger(0, full, OBJPROP_FONTSIZE,   sz);
      ObjectSetString(0,  full, OBJPROP_FONT,       "Consolas");
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN,     true);
      ObjectSetString(0,  full, OBJPROP_TEXT,       "");
      ObjectSetInteger(0, full, OBJPROP_COLOR,      clrGray);
   }

   // Update text/color in place; only write when the value actually changed.
   void _Set(const string name, const string text, color clr)
   {
      string full = m_prefix + name;
      if(ObjectGetString(0, full, OBJPROP_TEXT) != text)
         ObjectSetString(0, full, OBJPROP_TEXT, text);
      if((color)ObjectGetInteger(0, full, OBJPROP_COLOR) != clr)
         ObjectSetInteger(0, full, OBJPROP_COLOR, clr);
   }

   // Score color: high=green, mid=khaki, low=orange/red
   color ScoreColor(double v)
   {
      if(v >= 0.70) return clrLimeGreen;
      if(v >= 0.50) return clrKhaki;
      if(v >= 0.30) return clrOrange;
      return clrOrangeRed;
   }

   string SessionStr(int s)
   {
      switch(s)
      {
         case SESSION_ASIAN:   return "ASIAN";
         case SESSION_LONDON:  return "LONDON";
         case SESSION_NEWYORK: return "NEWYORK";
         case SESSION_OVERLAP: return "OVERLAP";
         default:              return "UNKNOWN";
      }
   }

   string RegimeStr(int r, color &clrOut)
   {
      switch(r)
      {
         case 0: clrOut = clrKhaki;      return "BALANCED";
         case 1: clrOut = clrDodgerBlue; return "COMPRESSION";
         case 2: clrOut = clrLimeGreen;  return "INITIATION";
         case 3: clrOut = clrLimeGreen;  return "CONTINUATION";
         case 4: clrOut = clrCyan;       return "RE-ACCUM";
         case 5: clrOut = clrOrange;     return "EXHAUSTION";
         case 6: clrOut = clrOrangeRed;  return "FAILED";
         case 7: clrOut = clrMagenta;    return "EXCESS";
         case 8: clrOut = clrRed;        return "CHAOTIC";
         default: clrOut = clrGray;      return "?";
      }
   }

   string ShapeStr(int s, color &clrOut)
   {
      switch(s)
      {
         case 0: clrOut = clrKhaki;      return "D (balanced)";
         case 1: clrOut = clrLimeGreen;  return "P (bullish)";
         case 2: clrOut = clrOrangeRed;  return "b (bearish)";
         case 3: clrOut = clrDodgerBlue; return "B (bimodal)";
         case 4: clrOut = clrGray;       return "Thin";
         default: clrOut = clrGray;      return "?";
      }
   }

   // Build the full fixed layout once. Header labels get their (constant)
   // text here; dynamic labels get their text later in _Refresh().
   void _Build()
   {
      int pad = 6, x0 = 4, y0 = 4, lineH = 13;
      int x = x0 + pad, y = y0 + pad;
      // Fixed line count for a stable panel height (no conditional lines).
      int totalLines = 26;
      int panelH = totalLines * lineH + pad * 2;

      _CreateBackground(x0, y0, VPDASH_WIDTH, panelH);

      _CreateLabel("hdr",  x, y, 9); y += lineH + 2;

      _CreateLabel("ctx1", x, y, 8); y += lineH;
      _CreateLabel("ctx2", x, y, 8); y += lineH + 3;

      _CreateLabel("vp_hdr", x, y, 8); y += lineH;
      _CreateLabel("vp_poc", x, y, 8); y += lineH;
      _CreateLabel("vp_va",  x, y, 8); y += lineH;
      _CreateLabel("vp_pos", x, y, 8); y += lineH;
      _CreateLabel("vp_hvn", x, y, 8); y += lineH;
      _CreateLabel("vp_nk",  x, y, 8); y += lineH;
      _CreateLabel("vp_poc2",x, y, 8); y += lineH + 3;

      _CreateLabel("au_hdr", x, y, 8); y += lineH;
      _CreateLabel("au_reg", x, y, 8); y += lineH;
      _CreateLabel("au_q",   x, y, 8); y += lineH;
      _CreateLabel("au_c",   x, y, 8); y += lineH;
      _CreateLabel("au_sh",  x, y, 8); y += lineH + 3;

      _CreateLabel("st_hdr", x, y, 8); y += lineH;
      _CreateLabel("st_b",   x, y, 8); y += lineH;
      _CreateLabel("st_bos", x, y, 8); y += lineH + 3;

      _CreateLabel("en_hdr", x, y, 8); y += lineH;
      _CreateLabel("en_ms",  x, y, 8); y += lineH;
      _CreateLabel("en_of",  x, y, 8); y += lineH;
      _CreateLabel("en_ls",  x, y, 8); y += lineH + 3;

      _CreateLabel("dc_hdr", x, y, 8); y += lineH;
      _CreateLabel("dc_s",   x, y, 8); y += lineH;
      _CreateLabel("dc_d",   x, y, 9); y += lineH;
      _CreateLabel("dc_r",   x, y, 8);

      // Static header texts (never change) — set once.
      _Set("vp_hdr", "-- VOLUME PROFILE --", clrWhite);
      _Set("au_hdr", "-- AUCTION --",        clrWhite);
      _Set("st_hdr", "-- STRUCTURE --",      clrWhite);
      _Set("en_hdr", "-- ENGINES --",        clrWhite);
      _Set("dc_hdr", "-- LAST SETUP --",     clrWhite);

      m_built = true;
   }

   // Update only the dynamic labels' text/color.
   void _Refresh(const SVPPipelineState &state)
   {
      // ═══ HEADER ═══
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      _Set("hdr", StringFormat("VP EA | %s | %02d:%02d",
           m_symbol, dt.hour, dt.min), clrWhite);

      // ═══ MARKET CONTEXT ═══
      _Set("ctx1", StringFormat("Sess:%s  Spread:%.0f(avg%.0f)",
           SessionStr((int)state.session),
           state.marketData.spreadPoints, state.marketData.avgSpreadPoints),
           clrLightSteelBlue);
      _Set("ctx2", StringFormat("ATR:%.1f  DataQ:%.0f%%",
           state.marketData.atrProxy, state.marketData.dataQualityScore * 100),
           clrGray);

      // ═══ VOLUME PROFILE ═══
      if(state.vpValid)
      {
         _Set("vp_poc", StringFormat("  POC: %s",
              DoubleToString(state.vpPOC, m_digits)), clrRed);
         _Set("vp_va", StringFormat("  VAH: %s  VAL: %s",
              DoubleToString(state.vpVAH, m_digits),
              DoubleToString(state.vpVAL, m_digits)), clrRoyalBlue);

         string posStr = state.vpInsideVA ? "IN VA" :
                         (state.vpPriceVsPOC > 0 ? "ABOVE POC" : "BELOW POC");
         color  posClr = state.vpInsideVA ? clrLimeGreen :
                         (state.vpPriceVsPOC > 0 ? clrDodgerBlue : clrOrangeRed);
         _Set("vp_pos", StringFormat("  Pos: %s", posStr), posClr);

         if(state.vpBestHVN > 0)
            _Set("vp_hvn", StringFormat("  BestHVN: %s (%.2f)",
                 DoubleToString(state.vpBestHVN, m_digits), state.vpBestHVNScore), clrGold);
         else
            _Set("vp_hvn", "  BestHVN: -", clrGray);

         if(state.vpNearestNakedPOC > 0)
            _Set("vp_nk", StringFormat("  NakedPOC: %s (%.1f ATR)",
                 DoubleToString(state.vpNearestNakedPOC, m_digits),
                 state.vpDistToNakedPOC_ATR), clrLightSteelBlue);
         else
            _Set("vp_nk", "  NakedPOC: -", clrGray);

         string sp = (state.vpSessionPOC   > 0) ? DoubleToString(state.vpSessionPOC, m_digits)   : "-";
         string cp = (state.vpCompositePOC > 0) ? DoubleToString(state.vpCompositePOC, m_digits) : "-";
         _Set("vp_poc2", StringFormat("  SessPOC:%s CompPOC:%s", sp, cp), clrDarkTurquoise);
      }
      else
      {
         _Set("vp_poc", "  (profile not ready)", clrGray);
         _Set("vp_va",  "", clrGray);
         _Set("vp_pos", "", clrGray);
         _Set("vp_hvn", "", clrGray);
         _Set("vp_nk",  "", clrGray);
         _Set("vp_poc2","", clrGray);
      }

      // ═══ AUCTION ═══
      color regClr; string regStr = RegimeStr(state.auctRegime, regClr);
      _Set("au_reg", StringFormat("  Regime: %s (%.0f%%)",
           regStr, state.auctRegimeConfidence * 100), regClr);
      _Set("au_q", StringFormat("  Qual:%.0f%% Bal:%.0f%% Fail:%.0f%%",
           state.auctTradeQuality * 100, state.auctBalanceScore * 100,
           state.auctFailureScore * 100), ScoreColor(state.auctTradeQuality));
      _Set("au_c", StringFormat("  Cont:%.0f%% Rev:%.0f%% Exh:%.0f%%",
           state.auctContinuationScore * 100, state.auctReversalRiskScore * 100,
           state.auctExhaustionScore * 100), clrLightSteelBlue);
      color shpClr; string shpStr = ShapeStr(state.auctProfileShape, shpClr);
      _Set("au_sh", StringFormat("  Shape: %s (%.0f%%)",
           shpStr, state.auctProfileShapeConf * 100), shpClr);

      // ═══ STRUCTURE / BIAS ═══
      double bias = state.structure.structureBias;
      string biasStr = (bias > 0.58) ? "BULL" : (bias < 0.42) ? "BEAR" : "NEUTRAL";
      color  biasClr = (bias > 0.58) ? clrLimeGreen : (bias < 0.42) ? clrOrangeRed : clrGray;
      _Set("st_b", StringFormat("  Bias:%s  Trend:%s",
           biasStr, (state.trendDirection > 0 ? "UP" :
                     state.trendDirection < 0 ? "DOWN" : "FLAT")), biasClr);
      _Set("st_bos", StringFormat("  BOS:%s(%.2f)  CHOCH:%s(%.2f)",
           (state.bosConfirmed ? (state.bosBullish ? "up" : "dn") : "-"), state.bosScore,
           (state.chochConfirmed ? (state.chochBullish ? "up" : "dn") : "-"), state.chochScore),
           clrLightSteelBlue);

      // ═══ BONUS ENGINES ═══
      _Set("en_ms", StringFormat("  Comp:%.2f TickVel:%.2f LiqVac:%.2f",
           state.microstructure.compressionScore, state.microstructure.tickVelocity,
           state.microstructure.liquidityVacuumScore), clrLightSteelBlue);
      _Set("en_of", StringFormat("  Flow:%.2f Delta:%.2f Div:%.2f",
           state.flow.flowIntensityScore, state.flow.deltaProxy,
           state.flow.divergenceScore), clrLightSteelBlue);
      _Set("en_ls", StringFormat("  Sweep:%.2f LiqDen:%.2f Zone:%.2f",
           state.liquidity.sweepScore, state.liquidity.liquidityDensity,
           state.smartMoney.zoneQualityScore), clrLightSteelBlue);

      // ═══ LAST SETUP / DECISION ═══
      _Set("dc_s", StringFormat("  %s  WinP:%.0f%% Edge:%.2f",
           m_lastSetup, m_lastWinProb * 100, m_lastEdgeMult), clrLightSteelBlue);
      color decClr = (m_lastDecision == "APPROVED") ? clrLimeGreen :
                     (m_lastDecision == "BLOCKED")  ? clrOrangeRed : clrGray;
      _Set("dc_d", StringFormat("  >> %s", m_lastDecision), decClr);
      if(m_lastDecision == "BLOCKED" && m_lastReason != "")
         _Set("dc_r", "  " + m_lastReason, clrOrangeRed);
      else
         _Set("dc_r", "", clrGray);
   }

public:
   CVPDashboard(void) : m_enabled(false), m_built(false), m_prefix("VPDash_"),
      m_symbol(""), m_digits(5), m_lastSetup("NONE"), m_lastDecision("-"),
      m_lastReason(""), m_lastWinProb(0), m_lastEdgeMult(1.0) {}

   void Init(const string symbol, bool userEnabled = true)
   {
      m_symbol = symbol;
      m_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      bool inTester = (bool)MQLInfoInteger(MQL_TESTER);
      bool visual   = (bool)MQLInfoInteger(MQL_VISUAL_MODE);
      m_enabled = userEnabled && (!inTester || visual);
      m_built = false;
      if(!m_enabled) return;
      _DeleteObjects();
   }

   bool IsEnabled(void) const { return m_enabled; }

   // Cache the latest trigger decision so the panel keeps showing it.
   void CaptureDecision(const SVPPipelineState &state)
   {
      if(!m_enabled) return;
      if(state.primarySetup.setupType == SETUP_NONE) return;
      m_lastSetup    = SetupTypeToString(state.primarySetup.setupType);
      m_lastWinProb  = state.winProbability;
      m_lastEdgeMult = state.edgeGuardMultiplier;
      if(state.primarySetup.isValid && state.executionAllowed)
         m_lastDecision = "APPROVED";
      else
         m_lastDecision = "BLOCKED";
      m_lastReason = state.statusMessage;
   }

   void Update(const SVPPipelineState &state)
   {
      if(!m_enabled) return;
      if(!m_built) _Build();     // create objects once
      _Refresh(state);           // update text/color in place — no delete
      ChartRedraw(0);
   }

   void Deinit(void) { _DeleteObjects(); m_built = false; ChartRedraw(0); }
};

#endif // __VP_DASHBOARD_MQH__
