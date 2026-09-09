#ifndef __VP_CHART_OVERLAY_MQH__
#define __VP_CHART_OVERLAY_MQH__

//+------------------------------------------------------------------+
//| VP Chart Overlay v4 — Enhanced with Naked POC, High-Intensity    |
//| HVN, Range/Breakout POC, Fake Breakout markers                   |
//|                                                                   |
//| 3 columns tight against price axis (right edge of chart shift):  |
//|   Col 1 (rightmost): Main VA + POC + BestHVN + HighIntensityHVN  |
//|   Col 2 (middle): Session VA + POC                               |
//|   Col 3 (leftmost): Composite VA + POC                           |
//+------------------------------------------------------------------+

#include "..\02_VolumeProfile\VolumeProfileEngine.mqh"

#define VP_OBJ_PREFIX "VP_OVL_"

// ── Main chart lines ────────────────────────────────────────────
#define VP_POC_COLOR           clrRed
#define VP_NAKEDPOC_COLOR      clrGray
#define VP_RANGEPOC_COLOR      clrMediumOrchid
#define VP_BREAKOUTPOC_COLOR   clrSandyBrown

// ── Column 1 (Main VA) ─────────────────────────────────────────
#define VP_C1_VA_COLOR               clrRoyalBlue
#define VP_C1_POC_COLOR              clrRed
#define VP_C1_HVN_COLOR              clrGold
#define VP_C1_HIGHINTENSITY_HVN_COLOR clrDarkOrange

// ── Column 2 (Session) ─────────────────────────────────────────
#define VP_C2_VA_COLOR     clrDarkTurquoise
#define VP_C2_POC_COLOR    clrWhite

// ── Column 3 (Composite) ───────────────────────────────────────
#define VP_C3_VA_COLOR     clrForestGreen
#define VP_C3_POC_COLOR    clrYellow

// ── Histogram ──────────────────────────────────────────────────
#define VP_HISTO_COLOR     C'60,90,150'


class CVPChartOverlay
  {
private:
   bool     m_enabled;
   bool     m_showHistogram;
   bool     m_showSession;
   bool     m_showComposite;
   bool     m_showNakedPOC;
   bool     m_showHighIntensityHVN;
   bool     m_showRangeProfile;
   bool     m_showBreakoutProfile;
   bool     m_showFakeBreakout;
   int      m_histoBarsBack;
   datetime m_lastDrawTime;
   string   m_symbol;

   //+------------------------------------------------------------------+
   void _HLine(const string name, double price, color clr, int width,
               int style, string tip)
     {
      string obj = VP_OBJ_PREFIX + name;
      if(price <= 0) { ObjectDelete(0, obj); return; }
      if(ObjectFind(0, obj) < 0)
         ObjectCreate(0, obj, OBJ_HLINE, 0, 0, price);
      else
         ObjectSetDouble(0, obj, OBJPROP_PRICE, price);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj, OBJPROP_STYLE, style);
      ObjectSetInteger(0, obj, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, obj, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, obj, OBJPROP_TOOLTIP, tip);
     }

   void _HLine(const string name, double price, color clr, int width, string tip)
     { _HLine(name, price, clr, width, STYLE_SOLID, tip); }

   //+------------------------------------------------------------------+
   void _Band(const string name, double top, double bot,
              datetime t1, datetime t2, color clr, string tip)
     {
      string obj = VP_OBJ_PREFIX + name;
      if(top <= 0 || bot <= 0 || top <= bot) { ObjectDelete(0, obj); return; }

      if(ObjectFind(0, obj) < 0)
         ObjectCreate(0, obj, OBJ_RECTANGLE, 0, t1, top, t2, bot);
      else
        {
         ObjectSetInteger(0, obj, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, obj, OBJPROP_PRICE, 0, top);
         ObjectSetInteger(0, obj, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, obj, OBJPROP_PRICE, 1, bot);
        }
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj, OBJPROP_FILL, true);
      ObjectSetInteger(0, obj, OBJPROP_BACK, false);   // FOREGROUND
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, obj, OBJPROP_TOOLTIP, tip);
     }

   //+------------------------------------------------------------------+
   void _Stripe(const string name, double price, double height,
                datetime t1, datetime t2, color clr, string tip)
     {
      double half = height * 0.5;
      if(half < price * 0.00015) half = price * 0.00015;
      _Band(name, price + half, price - half, t1, t2, clr, tip);
     }

   //+------------------------------------------------------------------+
   void _Arrow(const string name, datetime time, double price, color clr, int code)
     {
      string obj = VP_OBJ_PREFIX + name;
      if(ObjectFind(0, obj) < 0)
         ObjectCreate(0, obj, OBJ_ARROW, 0, time, price);
      else
        {
         ObjectSetInteger(0, obj, OBJPROP_TIME, time);
         ObjectSetDouble(0, obj, OBJPROP_PRICE, price);
        }
      ObjectSetInteger(0, obj, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, obj, OBJPROP_BACK, false);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
     }

   //+------------------------------------------------------------------+
   void _HistoBar(int idx, double price, double ratio, datetime anchor, double bw)
     {
      string obj = VP_OBJ_PREFIX + "H" + IntegerToString(idx);
      double p1 = price - bw * 0.4;
      double p2 = price + bw * 0.4;
      int bars = (int)MathMax(1, MathRound(ratio * m_histoBarsBack));
      datetime t2 = anchor + bars * PeriodSeconds();

      if(ObjectFind(0, obj) < 0)
         ObjectCreate(0, obj, OBJ_RECTANGLE, 0, anchor, p1, t2, p2);
      else
        {
         ObjectSetInteger(0, obj, OBJPROP_TIME, 0, anchor);
         ObjectSetDouble(0, obj, OBJPROP_PRICE, 0, p1);
         ObjectSetInteger(0, obj, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, obj, OBJPROP_PRICE, 1, p2);
        }
      ObjectSetInteger(0, obj, OBJPROP_COLOR, VP_HISTO_COLOR);
      ObjectSetInteger(0, obj, OBJPROP_FILL, true);
      ObjectSetInteger(0, obj, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
     }

   //+------------------------------------------------------------------+
   void _Del(const string name) { ObjectDelete(0, VP_OBJ_PREFIX + name); }

   void _DeleteAll(void)
     {
      for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
        {
         string n = ObjectName(0, i);
         if(StringFind(n, VP_OBJ_PREFIX) == 0) ObjectDelete(0, n);
        }
     }

public:
   CVPChartOverlay(void) : m_enabled(false), m_showHistogram(true),
      m_showSession(true), m_showComposite(true),
      m_showNakedPOC(true), m_showHighIntensityHVN(true),
      m_showRangeProfile(true), m_showBreakoutProfile(true),
      m_showFakeBreakout(true),
      m_histoBarsBack(25), m_lastDrawTime(0), m_symbol("") {}

   void Init(const string symbol,
             bool showHistogram = true,
             bool showSession = true,
             bool showComposite = true,
             bool showNakedPOC = true,
             bool showHighIntensityHVN = true,
             bool showRangeProfile = true,
             bool showBreakoutProfile = true,
             bool showFakeBreakout = true)
     {
      m_symbol = symbol;
      m_enabled = true;
      m_showHistogram = showHistogram;
      m_showSession = showSession;
      m_showComposite = showComposite;
      m_showNakedPOC = showNakedPOC;
      m_showHighIntensityHVN = showHighIntensityHVN;
      m_showRangeProfile = showRangeProfile;
      m_showBreakoutProfile = showBreakoutProfile;
      m_showFakeBreakout = showFakeBreakout;
      ChartSetInteger(0, CHART_SHIFT, true);
      ChartSetDouble(0, CHART_SHIFT_SIZE, 18.0);
     }

   void SetEnabled(bool en) { m_enabled = en; if(!en) _DeleteAll(); }
   bool IsEnabled(void) const { return m_enabled; }

   //+------------------------------------------------------------------+
   //| Main update                                                       |
   //+------------------------------------------------------------------+
   void Update(CVolumeProfileEngine *vp)
     {
      if(!m_enabled || vp == NULL || !vp.IsValid()) return;

      datetime curBar = iTime(m_symbol, PERIOD_CURRENT, 0);
      if(curBar == m_lastDrawTime) return;
      m_lastDrawTime = curBar;

      SVolumeProfileData prof = vp.GetProfile();
      double bw = vp.GetBinWidth();
      int period = PeriodSeconds();
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      // ─── Compute column positions: tight to right edge ─────────
      int visibleBars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS);
      double shiftPct = ChartGetDouble(0, CHART_SHIFT_SIZE);
      shiftPct = MathMax(5.0, MathMin(50.0, shiftPct));
      int futureBars = (int)MathRound(visibleBars * shiftPct / 100.0);
      if(futureBars < 3) futureBars = 3;

      datetime barEnd = iTime(m_symbol, PERIOD_CURRENT, 0) + period;
      datetime chartRight = barEnd + (futureBars - 1) * period;

      // Col 1 = rightmost (Main VA): tight against price axis
      datetime c1R = chartRight;
      datetime c1L = chartRight - (datetime)(period * 0.8);
      // Col 2 = middle (Session): small gap left of Col 1
      datetime c2R = c1L - (datetime)(period * 0.3);
      datetime c2L = c2R - (datetime)(period * 0.8);
      // Col 3 = leftmost (Composite): small gap left of Col 2
      datetime c3R = c2L - (datetime)(period * 0.3);
      datetime c3L = c3R - (datetime)(period * 0.8);

      // ═══════════════════════════════════════════════════════════
      // MAIN CHART: POC only (+ optional extra lines)
      // ═══════════════════════════════════════════════════════════
      _HLine("POC", prof.poc, VP_POC_COLOR, 2,
             "POC: " + DoubleToString(prof.poc, digits));

      // Clean old objects
      _Del("VAH"); _Del("VAL"); _Del("HVN"); _Del("LVN");
      _Del("BEST_HVN"); _Del("DEV_POC"); _Del("VA_ZONE");

      // ── Naked POC (dashed gray, only when close) ─────────────
      if(m_showNakedPOC)
        {
         double nakedPOC = vp.NearestNakedPOC();
         double nakedDist = vp.DistToNakedPOC();
         if(nakedPOC > 0 && nakedDist < 2.0)
            _HLine("NAKEDPOC", nakedPOC, VP_NAKEDPOC_COLOR, 1, STYLE_DASH,
                   StringFormat("Naked POC: %s (dist %.1f ATR, age %d)",
                                DoubleToString(nakedPOC, digits),
                                nakedDist, vp.NakedPOCAge()));
         else
            _Del("NAKEDPOC");
        }
      else
         _Del("NAKEDPOC");

      // ── Range POC (dotted purple) ────────────────────────────
      if(m_showRangeProfile && vp.RangeValid())
         _HLine("RANGE_POC", vp.RangePOC(), VP_RANGEPOC_COLOR, 1, STYLE_DOT,
                StringFormat("Range POC: %s", DoubleToString(vp.RangePOC(), digits)));
      else
         _Del("RANGE_POC");

      // ── Breakout POC (dotted sandy) ──────────────────────────
      if(m_showBreakoutProfile && vp.BreakoutValid())
         _HLine("BREAKOUT_POC", vp.BreakoutPOC(), VP_BREAKOUTPOC_COLOR, 1, STYLE_DOT,
                StringFormat("Breakout POC: %s", DoubleToString(vp.BreakoutPOC(), digits)));
      else
         _Del("BREAKOUT_POC");

      // ── Fake Breakout markers (arrows) ───────────────────────
      if(m_showFakeBreakout)
        {
         _Del("UPTHRUST"); _Del("SPRING");
         if(vp.IsUpthrustDetected())
           {
            datetime t = vp.GetUpthrustBarTime();
            double   p = vp.GetUpthrustPrice();
            if(t > 0 && p > 0)
               _Arrow("UPTHRUST", t, p, clrRed, 234);   // down arrow
           }
         if(vp.IsSpringDetected())
           {
            datetime t = vp.GetSpringBarTime();
            double   p = vp.GetSpringPrice();
            if(t > 0 && p > 0)
               _Arrow("SPRING", t, p, clrLime, 233);    // up arrow
           }
        }
      else
        { _Del("UPTHRUST"); _Del("SPRING"); }

      // ═══════════════════════════════════════════════════════════
      // COLUMN 1: Main VA (rightmost — tight to price axis)
      // ═══════════════════════════════════════════════════════════
      _Band("C1_VA", prof.vah, prof.val, c1L, c1R, VP_C1_VA_COLOR,
            StringFormat("Main VA: %s - %s",
                         DoubleToString(prof.val, digits),
                         DoubleToString(prof.vah, digits)));
      _Stripe("C1_POC", prof.poc, bw * 1.5, c1L, c1R, VP_C1_POC_COLOR,
              StringFormat("POC: %s", DoubleToString(prof.poc, digits)));

      // Best HVN (gold stripe)
      if(prof.bestHVN > 0)
         _Stripe("C1_HVN", prof.bestHVN, bw, c1L, c1R, VP_C1_HVN_COLOR,
                 StringFormat("Best HVN: %s (%.2f)",
                              DoubleToString(prof.bestHVN, digits),
                              prof.bestHVNScore));
      else
         _Del("C1_HVN");

      // High-Intensity HVN (dark orange stripe)
      if(m_showHighIntensityHVN && prof.nearestHighIntensityHVN > 0
         && prof.nearestHighIntensityHVN != prof.bestHVN)
         _Stripe("C1_HIHVN", prof.nearestHighIntensityHVN, bw * 1.2, c1L, c1R,
                 VP_C1_HIGHINTENSITY_HVN_COLOR,
                 StringFormat("HI-HVN: %s (%.1f ATR)",
                              DoubleToString(prof.nearestHighIntensityHVN, digits),
                              prof.distToHighIntensityHVN_ATR));
      else
         _Del("C1_HIHVN");

      // ═══════════════════════════════════════════════════════════
      // COLUMN 2: Session (middle)
      // ═══════════════════════════════════════════════════════════
      if(m_showSession && prof.sessionPOC > 0)
        {
         double sH = (prof.sessionVAH > 0) ? prof.sessionVAH : prof.sessionPOC * 1.002;
         double sL = (prof.sessionVAL > 0) ? prof.sessionVAL : prof.sessionPOC * 0.998;
         if(sH <= sL) { sH = prof.sessionPOC * 1.002; sL = prof.sessionPOC * 0.998; }

         _Band("C2_VA", sH, sL, c2L, c2R, VP_C2_VA_COLOR,
               StringFormat("Session VA: %s - %s",
                            DoubleToString(sL, digits),
                            DoubleToString(sH, digits)));
         _Stripe("C2_POC", prof.sessionPOC, bw * 1.5, c2L, c2R, VP_C2_POC_COLOR,
                 StringFormat("Session POC: %s",
                              DoubleToString(prof.sessionPOC, digits)));
        }
      else
        { _Del("C2_VA"); _Del("C2_POC"); }

      // ═══════════════════════════════════════════════════════════
      // COLUMN 3: Composite (leftmost of three)
      // ═══════════════════════════════════════════════════════════
      if(m_showComposite && vp.CompositeValid())
        {
         double cP = vp.CompositePOC();
         double cH = (vp.CompositeVAH() > 0) ? vp.CompositeVAH() : cP * 1.002;
         double cL = (vp.CompositeVAL() > 0) ? vp.CompositeVAL() : cP * 0.998;
         if(cH <= cL) { cH = cP * 1.002; cL = cP * 0.998; }

         _Band("C3_VA", cH, cL, c3L, c3R, VP_C3_VA_COLOR,
               StringFormat("Composite VA: %s - %s",
                            DoubleToString(cL, digits),
                            DoubleToString(cH, digits)));
         _Stripe("C3_POC", cP, bw * 1.5, c3L, c3R, VP_C3_POC_COLOR,
                 StringFormat("Composite POC: %s",
                              DoubleToString(cP, digits)));
        }
      else
        { _Del("C3_VA"); _Del("C3_POC"); }

      // ═══════════════════════════════════════════════════════════
      // HISTOGRAM (optional)
      // ═══════════════════════════════════════════════════════════
      if(m_showHistogram)
        {
         int cnt = vp.GetBinCount();
         long mx = 1;
         for(int i = 0; i < cnt; i++)
           { long v = vp.GetBinVolume(i); if(v > mx) mx = v; }
         datetime anch = iTime(m_symbol, PERIOD_CURRENT, m_histoBarsBack);
         for(int i = 0; i < cnt; i++)
            _HistoBar(i, vp.GetBinPrice(i), (double)vp.GetBinVolume(i) / (double)mx, anch, bw);
         for(int i = cnt; i < VP_MAX_BINS; i++)
            ObjectDelete(0, VP_OBJ_PREFIX "H" + IntegerToString(i));
        }
      else
        {
         for(int i = 0; i < VP_MAX_BINS; i++)
            ObjectDelete(0, VP_OBJ_PREFIX "H" + IntegerToString(i));
        }

      ChartRedraw(0);
     }

   //+------------------------------------------------------------------+
   void Deinit(void) { _DeleteAll(); ChartRedraw(0); }
  };

#endif // __VP_CHART_OVERLAY_MQH__
