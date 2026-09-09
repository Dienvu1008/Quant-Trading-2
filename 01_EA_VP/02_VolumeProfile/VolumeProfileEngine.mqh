#ifndef __EA_ROOT_VOLUMEPROFILEENGINE_MQH__
#define __EA_ROOT_VOLUMEPROFILEENGINE_MQH__

#include "..\Config\GlobalParameters.mqh"
#include "AuctionEnums.mqh"

//+------------------------------------------------------------------+
//| Volume Profile Engine v3.2 — ATR Reference for Sideway/Breakout  |
//|                                                                   |
//| Fixes over v3.1:                                                  |
//|  - Use reference ATR captured at sideway start to avoid          |
//|    dynamic threshold changes causing false/breakouts.            |
//+------------------------------------------------------------------+

#define VP_MAX_BINS 80
#define VP_VALUE_AREA_PCT 0.70
#define VP_MAX_NAKED_POCS 16
#define VP_DEV_POC_HISTORY 30

enum EValueMigration
  {
   VALUE_NEUTRAL = 0,
   VALUE_BULLISH = 1,
   VALUE_BEARISH = -1
  };

// VP Profile Shape now uses unified EProfileShape from GlobalParameters.mqh:
//   PROFILE_D=0, PROFILE_P=1, PROFILE_b=2, PROFILE_B=3, PROFILE_THIN=4, PROFILE_UNKNOWN=5

enum ENUM_VA_OVERLAP_BIAS
  {
   VA_BIAS_NEUTRAL,
   VA_BIAS_BULLISH,
   VA_BIAS_BEARISH
  };

struct SNakedPOCRecord
  {
   datetime sessionClose;
   double   pocPrice;
   bool     hasBeenRetested;
   int      ageBars;
  };

struct SVolumeProfileData
  {
   double poc, vah, val;
   double profileHigh, profileLow;
   double priceVsPOC, priceVsVA;
   bool   insideValueArea;
   double nearestHVN, nearestLVN;
   double distToHVN_ATR, distToLVN_ATR;
   double sessionPOC, sessionVAH, sessionVAL;
   bool   isValid;
   int    totalVolume, barsUsed;
   double thinnessRatio;
   EProfileShape profileShape;
   double nearestHighIntensityHVN;
   double distToHighIntensityHVN_ATR;
   double bestHVN;
   double bestHVNScore;
  };

struct SAnchoredProfile
  {
   datetime anchorTime;
   double   poc, vah, val;
   double   high, low;
   bool     isValid;
   bool     isActive; // for growing breakout profile
  };

struct SPreviousSessionVA
  {
   double vah, val;
   datetime sessionEnd;
  };

class CVolumeProfileEngine : public CVPModuleBase
  {
private:
   // ── Main Profile (M1, 240 bars) ──────────────────────────────────
   double m_binPrices[VP_MAX_BINS];
   long   m_binVolumes[VP_MAX_BINS];
   int    m_binTimeMins[VP_MAX_BINS];
   int    m_binCount;
   double m_binWidth;

   SVolumeProfileData m_profile;

   // ── Session Profile (M1) ─────────────────────────────────────────
   double m_sessBinPrices[VP_MAX_BINS];
   long   m_sessBinVolumes[VP_MAX_BINS];
   int    m_sessBinTime[VP_MAX_BINS];

   // ── Daily Composite (H1) ─────────────────────────────────────────
   double m_dailyBinPrices[VP_MAX_BINS];
   long   m_dailyBinVolumes[VP_MAX_BINS];
   double m_dailyPOC;
   int    m_lastNakedPOCDay;           // day-of-year when last session POC was registered
   double m_prevSessionPOC;            // previous session POC for naked registration

   // ── Composite Profile (36 H1 bars) ──────────────────────────────
   double m_compositeBinPrices[VP_MAX_BINS];
   long   m_compositeBinVolumes[VP_MAX_BINS];
   double m_compositePOC, m_compositeVAH, m_compositeVAL;
   bool   m_compositeValid;
   double m_prevCompositePOC;          // for naked POC registration on shift

   // ── Throttle & Parameters ────────────────────────────────────────
   datetime m_lastComputeBar;
   int      m_lookbackBars, m_sessionLookbackBars;
   EVPDataSource m_dataSource;        // M1 bars or real ticks
   int      m_tickLookbackSec;        // lookback in seconds for tick mode (default 14400 = 4h)

   // ── Naked POC Tracking ──────────────────────────────────────────
   SNakedPOCRecord m_nakedPOCs[VP_MAX_NAKED_POCS];
   int    m_nakedPOCCount;
   double m_nearestNakedPOC, m_distToNakedPOC_ATR;
   int    m_nakedPOCAge;

   // ── Developing POC ──────────────────────────────────────────────
   double m_devPOCHistory[VP_DEV_POC_HISTORY];
   int    m_devPOCHistCount, m_devPOCWriteIdx;
   double m_devPOC, m_devPOCVelocity, m_devPOCSlope, m_devPOCAcceleration;
   double m_prevDevPOCVelocity;
   EValueMigration m_migrationDir;
   int    m_migrationPersistence;
   double m_valueMigrationScore;

   // ── Overlapping VA ──────────────────────────────────────────────
   SPreviousSessionVA m_prevSessionVA;
   double m_vaOverlapRatio;
   ENUM_VA_OVERLAP_BIAS m_vaBias;

   // ── Anchored Profiles ───────────────────────────────────────────
   SAnchoredProfile m_rangeProfile;       // finished sideways range
   SAnchoredProfile m_breakoutProfile;    // active breakout profile (H1)
   SAnchoredProfile m_pullbackProfile;    // micro pullback (M1)
   // Sideway detection state
   bool   m_inSideway;
   datetime m_sidewayStart;
   double m_sidewayHigh, m_sidewayLow;
   datetime m_lastSidewayUpdateBar;       // track bar when sideway boundaries updated
   double m_sidewayRefATR;               // ★ ATR captured at sideway start
   // Breakout tracking
   bool   m_breakoutDetected;
   datetime m_breakoutTime;
   // Micro pullback state
   double m_lastSwingHigh, m_lastSwingLow;
   datetime m_swingHighTime, m_swingLowTime;

   // ── HVN Quality Score & Retest ──────────────────────────────────
   datetime m_binLastTouchTime[VP_MAX_BINS];
   int      m_binRetestCount[VP_MAX_BINS];
   double   m_bestHVNPrice, m_bestHVNScore;

   // ── Fake Breakout Trap ──────────────────────────────────────────
   bool     m_upthrustDetected, m_springDetected;

   // ── Composite Position ──────────────────────────────────────────
   int      m_compositePosition;

   // ── Migration Confidence ────────────────────────────────────────
   double   m_migrationConfidence;

   // ── [v4.0] Long-Term Auction Structure (H4 60-day) ─────────────
   #define LT_H4_LOOKBACK  360    // 60 days of H4 bars
   #define LT_MAX_BINS     100
   #define LT_HVN_ZSCORE   1.2
   #define LT_LVN_ZSCORE  -0.8
   #define LT_ACCEPTANCE_RADIUS_ATR 0.5

   datetime m_ltLastCompute;
   double   m_ltPOC60d, m_ltPOC30d, m_ltPOC10d;
   double   m_ltPOCVelocity, m_ltPOCAcceleration;
   int      m_ltPOCMigration;  // 0=stable, ±1=migrating, ±2=accelerating
   double   m_ltMajorHVNPrice, m_ltMajorHVNStrength;
   double   m_ltMajorLVNPrice, m_ltMajorLVNStrength;
   double   m_ltNearestZonePrice, m_ltNearestZoneStrength;
   int      m_ltNearestZoneDir;
   double   m_ltAcceptanceAtPrice;
   bool     m_ltValid;

   // LT Transition detection
   double   m_ltTransitionScore;
   double   m_ltBalanceStability;
   double   m_ltTrendDuration;
   double   m_ltTrendExhaustion;

   double _LT_ComputePOC(const MqlRates &rates[], int startIdx, int count, double atr)
     {
      if(count < 30) return 0;
      double high = rates[startIdx].high, low = rates[startIdx].low;
      for(int i = startIdx + 1; i < startIdx + count; i++)
        { if(rates[i].high > high) high = rates[i].high; if(rates[i].low < low) low = rates[i].low; }
      double range = high - low;
      if(range <= 0) return 0;

      int binCount = MathMax(40, MathMin(LT_MAX_BINS, (int)(range / (atr * 0.5))));
      double binWidth = range / binCount;
      long volumes[];
      ArrayResize(volumes, binCount);
      ArrayInitialize(volumes, 0);

      for(int i = startIdx; i < startIdx + count; i++)
        {
         double tp = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
         long vol = (long)rates[i].tick_volume;
         if(vol <= 0) vol = 1;
         int bin = MathMax(0, MathMin(binCount-1, (int)((tp - low) / binWidth)));
         volumes[bin] += vol;
        }
      int maxIdx = 0; long maxVol = volumes[0];
      for(int i = 1; i < binCount; i++) if(volumes[i] > maxVol) { maxVol = volumes[i]; maxIdx = i; }
      return low + binWidth * (maxIdx + 0.5);
     }

   void _LT_ComputeStructure(const MqlRates &h4[], int count, double atr, double bid)
     {
      m_ltValid = false;
      if(count < 100 || atr <= 0) return;

      // ── Multi-TF POC ─────────────────────────────────────────────
      int bars10d = MathMin(60, count);
      int bars30d = MathMin(180, count);
      int bars60d = count;
      m_ltPOC10d = _LT_ComputePOC(h4, count - bars10d, bars10d, atr);
      m_ltPOC30d = _LT_ComputePOC(h4, count - bars30d, bars30d, atr);
      m_ltPOC60d = _LT_ComputePOC(h4, 0, bars60d, atr);

      // ── POC Velocity & Migration ──────────────────────────────────
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double ltAtrPrice = atr * pointSize;  // convert ATR points → price
      double prevVelocity = m_ltPOCVelocity;
      m_ltPOCVelocity = (m_ltPOC30d > 0 && ltAtrPrice > 0) ? (m_ltPOC10d - m_ltPOC30d) / ltAtrPrice : 0;
      m_ltPOCAcceleration = m_ltPOCVelocity - prevVelocity;

      if(m_ltPOCVelocity > 0.05)
         m_ltPOCMigration = (m_ltPOCAcceleration > 0.02) ? 2 : 1;
      else if(m_ltPOCVelocity < -0.05)
         m_ltPOCMigration = (m_ltPOCAcceleration < -0.02) ? -2 : -1;
      else
         m_ltPOCMigration = 0;

      // ── Full 60d profile for zone detection ───────────────────────
      double high = h4[0].high, low = h4[0].low;
      for(int i = 1; i < count; i++)
        { if(h4[i].high > high) high = h4[i].high; if(h4[i].low < low) low = h4[i].low; }
      double range = high - low;
      if(range <= 0) return;

      int binCount = MathMax(50, MathMin(LT_MAX_BINS, (int)(range / (atr * 0.5))));
      double binWidth = range / binCount;

      double binPrices[];
      long   binVolumes[];
      ArrayResize(binPrices, binCount);
      ArrayResize(binVolumes, binCount);
      ArrayInitialize(binVolumes, 0);

      for(int b = 0; b < binCount; b++)
         binPrices[b] = low + binWidth * (b + 0.5);

      for(int i = 0; i < count; i++)
        {
         double tp = (h4[i].high + h4[i].low + h4[i].close) / 3.0;
         long vol = (long)h4[i].tick_volume;
         if(vol <= 0) vol = 1;
         int bin = MathMax(0, MathMin(binCount-1, (int)((tp - low) / binWidth)));
         // Gaussian spread to ±2 bins
         int s = MathMax(0, bin-2), e = MathMin(binCount-1, bin+2);
         double totalW = 0;
         double ws[5]; int wi = 0;
         for(int b = s; b <= e; b++)
           { double d = (binPrices[b] - tp) / (binWidth * 1.5); ws[wi] = MathExp(-0.5*d*d); totalW += ws[wi]; wi++; }
         if(totalW > 0) { wi = 0; for(int b = s; b <= e; b++) { binVolumes[b] += (long)(vol * ws[wi] / totalW); wi++; } }
        }

      // Stats
      double mean = 0, stddev = 0;
      for(int i = 0; i < binCount; i++) mean += binVolumes[i];
      mean /= binCount;
      double varSum = 0;
      for(int i = 0; i < binCount; i++) { double d = binVolumes[i] - mean; varSum += d*d; }
      stddev = MathSqrt(varSum / (binCount - 1));
      if(stddev < 1) stddev = 1;

      // ── Major HVN / LVN ───────────────────────────────────────────
      m_ltMajorHVNPrice = 0; m_ltMajorHVNStrength = 0;
      m_ltMajorLVNPrice = 0; m_ltMajorLVNStrength = 0;
      double bestHVNZ = 0, bestLVNZ = 0;

      for(int i = 1; i < binCount-1; i++)
        {
         double z = (binVolumes[i] - mean) / stddev;
         // HVN: local peak + high z-score
         if(z > LT_HVN_ZSCORE && binVolumes[i] > binVolumes[i-1] && binVolumes[i] > binVolumes[i+1])
           {
            if(z > bestHVNZ)
              { bestHVNZ = z; m_ltMajorHVNPrice = binPrices[i]; m_ltMajorHVNStrength = MathMin(1.0, z / 4.0); }
           }
         // LVN: local valley + low z-score
         if(z < LT_LVN_ZSCORE && binVolumes[i] < binVolumes[i-1] && binVolumes[i] < binVolumes[i+1])
           {
            if(z < bestLVNZ)
              { bestLVNZ = z; m_ltMajorLVNPrice = binPrices[i]; m_ltMajorLVNStrength = MathMin(1.0, MathAbs(z) / 3.0); }
           }
        }

      // ── Nearest significant zone ──────────────────────────────────
      m_ltNearestZonePrice = 0; m_ltNearestZoneStrength = 0; m_ltNearestZoneDir = 0;
      double minDist = 999.0;

      for(int i = 1; i < binCount-1; i++)
        {
         double z = (binVolumes[i] - mean) / stddev;
         if(MathAbs(z) < 1.0) continue;  // only significant zones
         if(!(binVolumes[i] > binVolumes[i-1] && binVolumes[i] > binVolumes[i+1]) &&
            !(binVolumes[i] < binVolumes[i-1] && binVolumes[i] < binVolumes[i+1]))
            continue;

         double dist = MathAbs(bid - binPrices[i]) / ltAtrPrice;
         if(dist < minDist && dist > 0.3)  // ignore if price is already AT the zone
           {
            minDist = dist;
            m_ltNearestZonePrice = binPrices[i];
            m_ltNearestZoneStrength = MathMin(1.0, MathAbs(z) / 3.0);
            m_ltNearestZoneDir = (binPrices[i] > bid) ? 1 : -1;
           }
        }

      // ── Acceptance at current price ───────────────────────────────
      // How much time price spent near current level (normalized)
      int currentBin = MathMax(0, MathMin(binCount-1, (int)((bid - low) / binWidth)));
      double currentZ = (binVolumes[currentBin] - mean) / stddev;
      m_ltAcceptanceAtPrice = Clamp01((currentZ + 1.0) / 4.0);  // map z=[-1,3] to [0,1]

      m_ltValid = true;
     }

   void _LT_DetectTransition()
     {
      // Transition score: measures post-trend chaos / regime change
      // Based on divergence between short-term and long-term POC + deceleration
      if(!m_ltValid || m_ltPOC60d <= 0) { m_ltTransitionScore = 0; m_ltBalanceStability = 1; m_ltTrendDuration = 0; m_ltTrendExhaustion = 0; return; }

      // POC divergence (10d vs 60d) normalized
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double pocDivergence = MathAbs(m_ltPOC10d - m_ltPOC60d) / (m_ltPOC60d * pointSize + 0.001);
      double normDiv = MathMin(1.0, pocDivergence / 50.0);  // saturate at 50 points divergence

      // Deceleration component: trend slowing = transition
      double decel = (MathAbs(m_ltPOCVelocity) > 0.01 && m_ltPOCAcceleration * m_ltPOCVelocity < 0)
                     ? MathMin(1.0, MathAbs(m_ltPOCAcceleration) / (MathAbs(m_ltPOCVelocity) + 0.01))
                     : 0;

      m_ltTransitionScore = Clamp01(normDiv * 0.5 + decel * 0.5);
      m_ltBalanceStability = 1.0 - m_ltTransitionScore;

      // Trend duration: how many H4 bars the current trend has lasted (estimated)
      m_ltTrendDuration = MathMin(200.0, MathAbs(m_ltPOC10d - m_ltPOC60d) / (MathAbs(m_ltPOCVelocity) + 0.001));

      // Exhaustion: high velocity + negative acceleration = exhausted
      double velMag = MathMin(1.0, MathAbs(m_ltPOCVelocity) / 0.3);
      double decelSign = (m_ltPOCVelocity > 0) ? -m_ltPOCAcceleration : m_ltPOCAcceleration;
      double decelNorm = MathMin(1.0, MathMax(0.0, decelSign / 0.1));
      m_ltTrendExhaustion = Clamp01(velMag * decelNorm);
     }

   //+------------------------------------------------------------------+
   //| Core histogram builder (unchanged)                               |
   //+------------------------------------------------------------------+
   void BuildHistogram(const MqlRates &rates[], int count,
                       double &prices[], long &volumes[], int &timeMins[], int &binCount,
                       double &outHigh, double &outLow)
     {
      if(count < 10) { binCount = 0; return; }
      double highestHigh = rates[0].high, lowestLow = rates[0].low;
      for(int i = 1; i < count; i++)
        {
         if(rates[i].high > highestHigh) highestHigh = rates[i].high;
         if(rates[i].low < lowestLow)    lowestLow = rates[i].low;
        }
      double range = highestHigh - lowestLow;
      if(range <= 0) { binCount = 0; return; }

      binCount = MathMin(VP_MAX_BINS, MathMax(20, (int)(range / m_binWidth)));
      double actualBinWidth = range / binCount;
      for(int b = 0; b < binCount; b++)
        { prices[b] = lowestLow + actualBinWidth * (b + 0.5);
          volumes[b] = 0; timeMins[b] = 0; }

      for(int i = 0; i < count; i++)
        {
         int binLo = MathMax(0, MathMin(binCount-1,
                     (int)((rates[i].low - lowestLow) / actualBinWidth)));
         int binHi = MathMax(0, MathMin(binCount-1,
                     (int)((rates[i].high - lowestLow) / actualBinWidth)));
         int span = binHi - binLo + 1;
         long vol = (long)rates[i].tick_volume;
         if(vol <= 0) vol = 1;
         long perBin = vol / MathMax(1, span);
         for(int b = binLo; b <= binHi; b++)
           { volumes[b] += perBin; timeMins[b]++; }
        }
      outHigh = highestHigh;
      outLow  = lowestLow;
     }

   //+------------------------------------------------------------------+
   //| Tick-based histogram builder — uses CopyTicksRange for precise   |
   //| volume distribution. Each tick contributes exactly 1 unit to     |
   //| its mid-price bin. Result: true market-accepted price levels.    |
   //+------------------------------------------------------------------+
   void BuildHistogramFromTicks(int lookbackSeconds,
                                double &prices[], long &volumes[], int &timeMins[], int &binCount,
                                double &outHigh, double &outLow)
     {
      binCount = 0; outHigh = 0; outLow = 0;

      MqlTick ticks[];
      datetime fromTime = TimeCurrent() - lookbackSeconds;
      long fromMs = (long)fromTime * 1000;
      int copied = CopyTicksRange(m_symbol, ticks, COPY_TICKS_ALL, fromMs, 0);

      if(copied < 100) { return; }

      // Pass 1: find price range (safe initialization)
      double highestHigh = -DBL_MAX, lowestLow = DBL_MAX;
      for(int i = 0; i < copied; i++)
        {
         double mid = (ticks[i].bid + ticks[i].ask) * 0.5;
         if(mid <= 0) continue;
         if(mid > highestHigh) highestHigh = mid;
         if(mid < lowestLow)   lowestLow = mid;
        }
      if(highestHigh <= 0 || lowestLow >= DBL_MAX) return;  // no valid ticks
      double range = highestHigh - lowestLow;
      if(range <= 0) { return; }

      // Determine bin count
      binCount = MathMin(VP_MAX_BINS, MathMax(20, (int)(range / m_binWidth)));
      double actualBinWidth = range / binCount;

      // Initialize bins
      for(int b = 0; b < binCount; b++)
        { prices[b] = lowestLow + actualBinWidth * (b + 0.5);
          volumes[b] = 0; timeMins[b] = 0; }

      // Pass 2: distribute ticks into bins + correct time-at-price
      // Strategy: group ticks by second, then mark ALL bins touched in that second
      datetime currentSec = 0;
      bool binsInSecond[];
      ArrayResize(binsInSecond, VP_MAX_BINS);

      for(int i = 0; i < copied; i++)
        {
         double mid = (ticks[i].bid + ticks[i].ask) * 0.5;
         if(mid <= 0) continue;
         int bin = MathMax(0, MathMin(binCount - 1,
                   (int)((mid - lowestLow) / actualBinWidth)));

         // Volume: each tick = 1 unit
         volumes[bin]++;

         // Time-at-price: track which bins are active per second
         datetime tickSec = (datetime)(ticks[i].time);
         if(tickSec != currentSec)
           {
            // New second started — flush previous second's bins
            if(currentSec != 0)
              {
               for(int b = 0; b < binCount; b++)
                  if(binsInSecond[b]) timeMins[b]++;
              }
            // Reset for new second
            ArrayInitialize(binsInSecond, false);
            currentSec = tickSec;
           }
         binsInSecond[bin] = true;
        }
      // Flush last second
      if(currentSec != 0)
        {
         for(int b = 0; b < binCount; b++)
            if(binsInSecond[b]) timeMins[b]++;
        }

      outHigh = highestHigh;
      outLow  = lowestLow;
     }

   double FindPOC(const double &prices[], const long &volumes[], int binCount)
     {
      if(binCount <= 0) return 0;
      int maxIdx = 0; long maxVol = volumes[0];
      for(int i = 1; i < binCount; i++)
         if(volumes[i] > maxVol) { maxVol = volumes[i]; maxIdx = i; }
      return prices[maxIdx];
     }

   void ComputeValueArea(const long &volumes[], int binCount,
                          double profileLow, double profileHigh,
                          double &vah, double &val)
     {
      if(binCount <= 0) { vah = 0; val = 0; return; }
      long totalVol = 0;
      for(int i = 0; i < binCount; i++) totalVol += volumes[i];
      if(totalVol <= 0) { vah = 0; val = 0; return; }
      long targetVol = (long)(totalVol * VP_VALUE_AREA_PCT);
      int pocIdx = 0; long maxV = volumes[0];
      for(int i = 1; i < binCount; i++)
         if(volumes[i] > maxV) { maxV = volumes[i]; pocIdx = i; }
      long accVol = volumes[pocIdx];
      int lo = pocIdx, hi = pocIdx;
      while(accVol < targetVol && (lo > 0 || hi < binCount-1))
        {
         long vLo = (lo > 0) ? volumes[lo-1] : 0;
         long vHi = (hi < binCount-1) ? volumes[hi+1] : 0;
         if(vHi >= vLo && hi < binCount-1) { hi++; accVol += volumes[hi]; }
         else if(lo > 0) { lo--; accVol += volumes[lo]; }
         else if(hi < binCount-1) { hi++; accVol += volumes[hi]; }
         else break;
        }
      double bw = (profileHigh - profileLow) / MathMax(1, binCount);
      val = profileLow + lo * bw;
      vah = profileLow + (hi+1) * bw;
     }

   void FindNodesPercentile(const double &prices[], const long &volumes[], int binCount,
                            double bid, double atr)
     {
      if(binCount < 5 || atr <= 0) return;
      // atr is in POINTS — convert to price for distance normalization
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;

      int sortIdx[];
      ArrayResize(sortIdx, binCount);
      for(int i = 0; i < binCount; i++) sortIdx[i] = i;
      for(int i = 1; i < binCount; i++)
        {
         int key = sortIdx[i];
         int j = i - 1;
         while(j >= 0 && volumes[sortIdx[j]] > volumes[key])
           { sortIdx[j+1] = sortIdx[j]; j--; }
         sortIdx[j+1] = key;
        }
      int p20 = MathMax(1, binCount / 5);
      double nearestHVN = 0, nearestLVN = 0;
      double minDistHVN = 999999, minDistLVN = 999999;
      for(int i = 0; i < p20; i++)
        {
         int idx = sortIdx[i];
         double dist = MathAbs(prices[idx] - bid);
         if(dist < minDistLVN) { minDistLVN = dist; nearestLVN = prices[idx]; }
        }
      for(int i = binCount - p20; i < binCount; i++)
        {
         int idx = sortIdx[i];
         double dist = MathAbs(prices[idx] - bid);
         if(dist < minDistHVN) { minDistHVN = dist; nearestHVN = prices[idx]; }
        }
      m_profile.nearestHVN = nearestHVN;
      m_profile.nearestLVN = nearestLVN;
      m_profile.distToHVN_ATR = (nearestHVN > 0 && atrPrice > 0) ? minDistHVN / atrPrice : 0;
      m_profile.distToLVN_ATR = (nearestLVN > 0 && atrPrice > 0) ? minDistLVN / atrPrice : 0;

      FindHighIntensityHVN(prices, volumes, binCount, bid, atr);
      ComputeBestHVN(prices, volumes, binCount, atr);
     }

   void FindHighIntensityHVN(const double &prices[], const long &volumes[],
                             int binCount, double bid, double atr)
     {
      if(binCount < 3) { m_profile.nearestHighIntensityHVN = 0; m_profile.distToHighIntensityHVN_ATR = 0; return; }

      // Find max volume within valid range (not ArrayMaximum which searches full array)
      long maxVol = 0;
      for(int i = 0; i < binCount; i++)
         if(volumes[i] > maxVol) maxVol = volumes[i];
      if(maxVol <= 0) { m_profile.nearestHighIntensityHVN = 0; m_profile.distToHighIntensityHVN_ATR = 0; return; }

      double maxIntensity = 0;
      int bestIdx = -1;
      for(int i = 0; i < binCount; i++)
        {
         if(m_binTimeMins[i] <= 0) continue;
         if(volumes[i] < (long)(0.3 * maxVol)) continue;
         double intensity = (double)volumes[i] / m_binTimeMins[i];
         if(intensity > maxIntensity)
           {
            maxIntensity = intensity;
            bestIdx = i;
           }
        }
      if(bestIdx >= 0)
        {
         double pointSz = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         if(pointSz <= 0) pointSz = 0.00001;
         m_profile.nearestHighIntensityHVN = prices[bestIdx];
         m_profile.distToHighIntensityHVN_ATR = MathAbs(prices[bestIdx] - bid) / (atr * pointSz);
        }
      else
        {
         m_profile.nearestHighIntensityHVN = 0;
         m_profile.distToHighIntensityHVN_ATR = 0;
        }
     }

   void ComputeBestHVN(const double &prices[], const long &volumes[],
                       int binCount, double atr)
     {
      if(binCount < 3) return;
      double wVol = 0.30, wFresh = 0.25, wSpeed = 0.35, wRetest = 0.10;

      long maxVol = 1;
      for(int i = 0; i < binCount; i++) if(volumes[i] > maxVol) maxVol = volumes[i];
      double maxIntensity = 0;
      for(int i = 0; i < binCount; i++)
        {
         int t = MathMax(1, m_binTimeMins[i]);
         double intensity = (double)volumes[i] / t;
         if(intensity > maxIntensity) maxIntensity = intensity;
        }
      if(maxIntensity <= 0) maxIntensity = 1;

      double bestScore = -999;
      double bestPrice = 0;

      datetime now = TimeCurrent();
      for(int i = 0; i < binCount; i++)
        {
         double volScore = (maxVol > 0) ? (double)volumes[i] / maxVol : 0;
         int t = MathMax(1, m_binTimeMins[i]);
         double intensity = (double)volumes[i] / t;
         double speedScore = intensity / maxIntensity;
         double ageMinutes = (double)(now - m_binLastTouchTime[i]) / 60.0;
         double freshScore = MathExp(-ageMinutes / 240.0);
         double retestPenalty = MathMin(1.0, m_binRetestCount[i] / 5.0);

         double score = wVol * volScore + wFresh * freshScore + wSpeed * speedScore
                        - wRetest * retestPenalty;

         if(score > bestScore)
           {
            bestScore = score;
            bestPrice = prices[i];
           }
        }

      m_bestHVNPrice = bestPrice;
      m_bestHVNScore = bestScore;
      m_profile.bestHVN = bestPrice;
      m_profile.bestHVNScore = bestScore;
     }

   void UpdateNakedPOCs(double bid, double atr, const MqlRates &lastBar)
     {
      for(int i = m_nakedPOCCount - 1; i >= 0; i--)
        {
         if(m_nakedPOCs[i].hasBeenRetested) continue;
         if(lastBar.high >= m_nakedPOCs[i].pocPrice &&
            lastBar.low <= m_nakedPOCs[i].pocPrice)
           {
            m_nakedPOCs[i].hasBeenRetested = true;
            for(int j = i; j < m_nakedPOCCount - 1; j++)
               m_nakedPOCs[j] = m_nakedPOCs[j+1];
            m_nakedPOCCount--;
           }
         else
           {
            m_nakedPOCs[i].ageBars++;
            // Expire very old POCs (> 240 H1 bars ≈ 10 trading days)
            if(m_nakedPOCs[i].ageBars > 240)
              {
               for(int j = i; j < m_nakedPOCCount - 1; j++)
                  m_nakedPOCs[j] = m_nakedPOCs[j+1];
               m_nakedPOCCount--;
              }
           }
        }
      m_nearestNakedPOC = 0; m_distToNakedPOC_ATR = 0; m_nakedPOCAge = 0;
      double minDist = 999999;
      for(int i = 0; i < m_nakedPOCCount; i++)
        {
         double d = MathAbs(bid - m_nakedPOCs[i].pocPrice);
         if(d < minDist)
           { minDist = d; m_nearestNakedPOC = m_nakedPOCs[i].pocPrice;
             m_nakedPOCAge = m_nakedPOCs[i].ageBars; }
        }
      if(m_nearestNakedPOC > 0 && atr > 0)
        {
         double pointSz = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         if(pointSz <= 0) pointSz = 0.00001;
         m_distToNakedPOC_ATR = minDist / (atr * pointSz);
        }
     }

   void RegisterSessionPOC(double pocPrice)
     {
      if(pocPrice <= 0 || m_nakedPOCCount >= VP_MAX_NAKED_POCS) return;
      for(int i = 0; i < m_nakedPOCCount; i++)
         if(MathAbs(m_nakedPOCs[i].pocPrice - pocPrice) < m_binWidth) return;
      m_nakedPOCs[m_nakedPOCCount].sessionClose = TimeCurrent();
      m_nakedPOCs[m_nakedPOCCount].pocPrice = pocPrice;
      m_nakedPOCs[m_nakedPOCCount].hasBeenRetested = false;
      m_nakedPOCs[m_nakedPOCCount].ageBars = 0;
      m_nakedPOCCount++;
     }

   void UpdateDevelopingPOC(double currentSessionPOC, double atr)
     {
      if(currentSessionPOC <= 0 || atr <= 0) return;
      // NOTE: atr here is atrProxy (in POINTS). Convert to PRICE for normalization.
      double pointSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSize <= 0) pointSize = 0.00001;
      double atrPrice = atr * pointSize;  // ATR in price units (same as POC)

      m_devPOCHistory[m_devPOCWriteIdx] = currentSessionPOC;
      m_devPOCWriteIdx = (m_devPOCWriteIdx + 1) % VP_DEV_POC_HISTORY;
      if(m_devPOCHistCount < VP_DEV_POC_HISTORY) m_devPOCHistCount++;
      m_devPOC = currentSessionPOC;

      if(m_devPOCHistCount < 3) return;

      // Velocity: difference between current and previous entry
      int prevIdx = (m_devPOCWriteIdx - 2 + VP_DEV_POC_HISTORY) % VP_DEV_POC_HISTORY;
      double prevPOC = m_devPOCHistory[prevIdx];
      if(prevPOC <= 0) return;  // guard against uninitialized entries
      m_prevDevPOCVelocity = m_devPOCVelocity;
      m_devPOCVelocity = (currentSessionPOC - prevPOC) / atrPrice;

      m_devPOCAcceleration = m_devPOCVelocity - m_prevDevPOCVelocity;

      // Slope via linear regression on last N entries
      int n = MathMin(m_devPOCHistCount, 10);
      int baseIdx = (m_devPOCWriteIdx - n + VP_DEV_POC_HISTORY) % VP_DEV_POC_HISTORY;
      double basePOC = m_devPOCHistory[baseIdx];
      if(basePOC <= 0) return;  // guard

      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int i = 0; i < n; i++)
        {
         int idx = (baseIdx + i) % VP_DEV_POC_HISTORY;
         double x = (double)i;
         double y = (m_devPOCHistory[idx] - basePOC) / atrPrice;
         sumX += x; sumY += y; sumXY += x*y; sumX2 += x*x;
        }
      double denom = n * sumX2 - sumX * sumX;
      m_devPOCSlope = (denom != 0) ? (n * sumXY - sumX * sumY) / denom : 0;

      if(m_devPOCSlope > 0.01)
        {
         if(m_migrationDir == VALUE_BULLISH) m_migrationPersistence++;
         else { m_migrationDir = VALUE_BULLISH; m_migrationPersistence = 1; }
        }
      else if(m_devPOCSlope < -0.01)
        {
         if(m_migrationDir == VALUE_BEARISH) m_migrationPersistence++;
         else { m_migrationDir = VALUE_BEARISH; m_migrationPersistence = 1; }
        }
      else
        {
         if(m_migrationDir == VALUE_NEUTRAL) m_migrationPersistence++;
         else { m_migrationDir = VALUE_NEUTRAL; m_migrationPersistence = 1; }
        }
     }

   double ComputeValueMigrationScore()
     {
      if(m_devPOCHistCount < 5) return 0.0;
      double slopeFactor = Clamp01(MathAbs(m_devPOCSlope) / 0.05);
      double persistFactor = Clamp01((double)m_migrationPersistence / 10.0);
      double consistFactor = (m_devPOCVelocity * m_devPOCSlope > 0) ? 1.0 : 0.3;
      return slopeFactor * 0.40 + persistFactor * 0.35 + consistFactor * 0.25;
     }

   void ClassifyProfileShape()
     {
      // Insufficient data → UNKNOWN
      if(m_binCount < 10)
        {
         m_profile.profileShape = PROFILE_UNKNOWN;
         m_profile.thinnessRatio = 0;
         return;
        }

      double range = m_profile.profileHigh - m_profile.profileLow;
      double vaRange = m_profile.vah - m_profile.val;
      m_profile.thinnessRatio = (range > 0) ? vaRange / range : 0;

      if(m_profile.thinnessRatio < 0.3)
        {
         m_profile.profileShape = PROFILE_THIN;
         return;
        }

      double volAbove = 0, volBelow = 0;
      for(int i = 0; i < m_binCount; i++)
        {
         if(m_binPrices[i] > m_profile.poc) volAbove += m_binVolumes[i];
         else if(m_binPrices[i] < m_profile.poc) volBelow += m_binVolumes[i];
        }
      double totalVol = volAbove + volBelow;
      if(totalVol <= 0) { m_profile.profileShape = PROFILE_D; return; }
      double aboveRatio = volAbove / totalVol;

      double pocPos = (range > 0) ? (m_profile.poc - m_profile.profileLow) / range : 0.5;

      if((aboveRatio > 0.7 && pocPos > 0.7) || (aboveRatio < 0.3 && pocPos < 0.3))
        {
         m_profile.profileShape = PROFILE_P;
         return;
        }
      if(pocPos < 0.2 || pocPos > 0.8)
        {
         m_profile.profileShape = PROFILE_b;
         return;
        }
      m_profile.profileShape = PROFILE_D;
     }

   void ComputeOverlappingVA()
     {
      if(m_prevSessionVA.sessionEnd == 0 || m_profile.sessionVAH == 0)
        {
         m_vaOverlapRatio = 0;
         m_vaBias = VA_BIAS_NEUTRAL;
         return;
        }
      double overlapTop = MathMin(m_profile.sessionVAH, m_prevSessionVA.vah);
      double overlapBottom = MathMax(m_profile.sessionVAL, m_prevSessionVA.val);
      double overlap = MathMax(0, overlapTop - overlapBottom);
      double currentRange = m_profile.sessionVAH - m_profile.sessionVAL;
      double prevRange = m_prevSessionVA.vah - m_prevSessionVA.val;
      double maxRange = MathMax(currentRange, prevRange);
      m_vaOverlapRatio = (maxRange > 0) ? overlap / maxRange : 0;

      if(m_vaOverlapRatio < 0.3)
        {
         if(m_profile.sessionVAL > m_prevSessionVA.vah)
            m_vaBias = VA_BIAS_BULLISH;
         else if(m_profile.sessionVAH < m_prevSessionVA.val)
            m_vaBias = VA_BIAS_BEARISH;
         else
            m_vaBias = VA_BIAS_NEUTRAL;
        }
      else
         m_vaBias = VA_BIAS_NEUTRAL;
     }

   //+------------------------------------------------------------------+
   //| [UPDATED v3.2] Sideway & Breakout Detection (Reference ATR)     |
   //+------------------------------------------------------------------+
   void UpdateAnchoredProfiles(const MqlRates &h1Rates[], int h1Bars, double atr)
     {
      if(h1Bars < 21) return;
      int lastCompleteIdx = h1Bars - 2; // last fully formed H1 bar
      if(lastCompleteIdx < 19) return;   // need 20 completed bars

      // Compute sideway boundaries over last 20 completed bars
      double highest = h1Rates[lastCompleteIdx-19].high, lowest = h1Rates[lastCompleteIdx-19].low;
      for(int i = lastCompleteIdx-18; i <= lastCompleteIdx; i++)
        {
         if(h1Rates[i].high > highest) highest = h1Rates[i].high;
         if(h1Rates[i].low  < lowest)  lowest  = h1Rates[i].low;
        }
      double range = highest - lowest;

      // ── Determine sideway state using reference ATR when inside ──
      if(!m_inSideway)
        {
         // Not currently in a sideway: check if new sideway forms
         if(range < 1.5 * atr)
           {
            m_inSideway = true;
            m_sidewayStart = h1Rates[lastCompleteIdx-19].time;
            m_sidewayRefATR = atr;               // ★ capture ATR at entry
            m_sidewayHigh = highest;
            m_sidewayLow  = lowest;
            m_lastSidewayUpdateBar = h1Rates[lastCompleteIdx].time;
            // Reset previous breakout state
            m_breakoutDetected = false;
            m_breakoutProfile.isValid = false;
            m_breakoutProfile.isActive = false;
            m_rangeProfile.isValid = false;
           }
        }
      else
        {
         // Already inside a sideway: use fixed reference ATR
         if(range < 1.5 * m_sidewayRefATR)
           {
            // Still within sideway envelope → update boundaries dynamically
            m_sidewayHigh = highest;
            m_sidewayLow  = lowest;
            m_lastSidewayUpdateBar = h1Rates[lastCompleteIdx].time;
           }
         else
           {
            // Range has expanded beyond reference threshold → potential breakout
            double close = h1Rates[lastCompleteIdx].close;
            double buffer = m_binWidth > 0 ? m_binWidth : atr * 0.1;
            if(close > m_sidewayHigh + buffer || close < m_sidewayLow - buffer)
              {
               // Confirmed breakout
               m_inSideway = false;
               m_breakoutDetected = true;

               // Build Range Profile anchored from sideway start to bar BEFORE breakout (exclude breakout bar)
               datetime rangeEnd = h1Rates[lastCompleteIdx-1].time; // last bar of sideway
               BuildAnchoredProfile(m_sidewayStart, rangeEnd, PERIOD_H1, m_rangeProfile);

               // Start Breakout Profile from the breakout bar itself
               m_breakoutProfile.anchorTime = h1Rates[lastCompleteIdx].time;
               m_breakoutProfile.isActive = true;
               m_breakoutTime = h1Rates[lastCompleteIdx].time;
              }
            else
              {
               // False breakout or noise, exit sideway without anchoring
               m_inSideway = false;
              }
           }
        }

      // Update active breakout profile (growing)
      if(m_breakoutDetected && m_breakoutProfile.isActive)
        {
         BuildAnchoredProfile(m_breakoutProfile.anchorTime, TimeCurrent(), PERIOD_H1, m_breakoutProfile);
        }
     }

   void BuildAnchoredProfile(datetime from, datetime to, ENUM_TIMEFRAMES tf, SAnchoredProfile &ap)
     {
      MqlRates rates[];
      int copied = CopyRates(m_symbol, tf, from, to, rates);
      if(copied < 10) { ap.isValid = false; return; }
      double prices[], low=0, high=0;
      long volumes[];
      int timeMins[];
      ArrayResize(prices, VP_MAX_BINS);
      ArrayResize(volumes, VP_MAX_BINS);
      ArrayResize(timeMins, VP_MAX_BINS);
      ArrayInitialize(timeMins, 0);
      int binCount = 0;
      BuildHistogram(rates, copied, prices, volumes, timeMins, binCount, high, low);
      if(binCount < 5) { ap.isValid = false; return; }
      ap.poc = FindPOC(prices, volumes, binCount);
      ComputeValueArea(volumes, binCount, low, high, ap.vah, ap.val);
      ap.high = high;
      ap.low = low;
      ap.isValid = true;
      ap.anchorTime = from;
     }

   //+------------------------------------------------------------------+
   //| Micro pullback profile (unchanged)                               |
   //+------------------------------------------------------------------+
   void UpdateMicroPullbackProfile(const MqlRates &m1Rates[], int m1Count, double atr)
     {
      if(m1Count < 40) return;
      double swingHigh = 0, swingLow = 99999;
      datetime highTime = 0, lowTime = 0;
      for(int i = m1Count-40; i < m1Count; i++)
        {
         if(m1Rates[i].high > swingHigh)
           {
            swingHigh = m1Rates[i].high;
            highTime = m1Rates[i].time;
           }
         if(m1Rates[i].low < swingLow)
           {
            swingLow = m1Rates[i].low;
            lowTime = m1Rates[i].time;
           }
        }
      double currentClose = m1Rates[m1Count-1].close;

      if(currentClose < swingHigh - 0.5 * atr && highTime > 0)
        {
         BuildAnchoredProfile(highTime, TimeCurrent(), PERIOD_M1, m_pullbackProfile);
        }
      else if(currentClose > swingLow + 0.5 * atr && lowTime > 0)
        {
         BuildAnchoredProfile(lowTime, TimeCurrent(), PERIOD_M1, m_pullbackProfile);
        }
      else
        {
         m_pullbackProfile.isValid = false;
        }
     }

   void DetectFakeBreakout(const MqlRates &lastBarH1, double vah, double val, long volumeSpikeThreshold)
     {
      m_upthrustDetected = false; m_springDetected = false;
      if(vah == 0 || val == 0) return;
      if(lastBarH1.high > vah && lastBarH1.close < vah)
        {
         if(lastBarH1.tick_volume > volumeSpikeThreshold)
            m_upthrustDetected = true;
        }
      if(lastBarH1.low < val && lastBarH1.close > val)
        {
         if(lastBarH1.tick_volume > volumeSpikeThreshold)
            m_springDetected = true;
        }
     }

   void UpdateCompositePosition(double bid)
     {
      if(!m_compositeValid) { m_compositePosition = 0; return; }
      if(bid > m_compositeVAH) m_compositePosition = 1;
      else if(bid < m_compositeVAL) m_compositePosition = -1;
      else m_compositePosition = 0;
     }

   void UpdateMigrationConfidence()
     {
      // Migration confidence combines:
      // 1. Slope magnitude (how fast POC moves, ATR-normalized)
      // 2. Persistence (how long it's been moving in same direction)
      // 3. Outside VA bonus (migration away from value = stronger signal)
      double slopeFactor = Clamp01(MathAbs(m_devPOCSlope) / 0.05); // 0.05 ATR/bar = full score
      double persistFactor = Clamp01((double)m_migrationPersistence / 8.0);
      bool outsideVA = !m_profile.insideValueArea;
      double vaBoost = outsideVA ? 1.2 : 0.8;
      m_migrationConfidence = Clamp01((slopeFactor * 0.50 + persistFactor * 0.50) * vaBoost);
     }

public:
   void Bootstrap(const string symbol)
     {
      Configure(symbol, "VolumeProfileEngine");
      m_binCount = 0; m_lastComputeBar = 0;
      m_lookbackBars = 240; m_sessionLookbackBars = 120;
      m_dataSource = VP_SOURCE_M1_BARS;
      m_tickLookbackSec = 14400;  // 4 hours
      m_dailyPOC = 0;
      m_lastNakedPOCDay = 0;
      m_prevSessionPOC = 0;
      m_compositePOC = 0; m_compositeVAH = 0; m_compositeVAL = 0; m_compositeValid = false;
      m_prevCompositePOC = 0;
      m_nakedPOCCount = 0; m_nearestNakedPOC = 0;
      m_distToNakedPOC_ATR = 0; m_nakedPOCAge = 0;
      m_devPOCHistCount = 0; m_devPOCWriteIdx = 0;
      m_devPOC = 0; m_devPOCVelocity = 0; m_devPOCSlope = 0;
      m_devPOCAcceleration = 0; m_prevDevPOCVelocity = 0;
      m_migrationDir = VALUE_NEUTRAL; m_migrationPersistence = 0;
      m_valueMigrationScore = 0;
      ZeroMemory(m_profile);
      ArrayInitialize(m_binPrices, 0);
      ArrayInitialize(m_binVolumes, 0); ArrayInitialize(m_binTimeMins, 0);
      ArrayInitialize(m_sessBinPrices, 0);
      ArrayInitialize(m_sessBinVolumes, 0); ArrayInitialize(m_sessBinTime, 0);
      ArrayInitialize(m_dailyBinPrices, 0);
      ArrayInitialize(m_dailyBinVolumes, 0);
      ArrayInitialize(m_devPOCHistory, 0);
      for(int i = 0; i < VP_MAX_NAKED_POCS; i++) ZeroMemory(m_nakedPOCs[i]);
      ZeroMemory(m_prevSessionVA);
      ZeroMemory(m_rangeProfile); ZeroMemory(m_breakoutProfile); ZeroMemory(m_pullbackProfile);
      m_inSideway = false; m_sidewayStart = 0; m_sidewayHigh = 0; m_sidewayLow = 0;
      m_lastSidewayUpdateBar = 0;
      m_sidewayRefATR = 0;            // ★
      m_breakoutDetected = false; m_breakoutTime = 0;
      m_bestHVNPrice = 0; m_bestHVNScore = 0;
      ArrayInitialize(m_binLastTouchTime, 0); ArrayInitialize(m_binRetestCount, 0);
      m_upthrustDetected = false; m_springDetected = false;
      m_compositePosition = 0;
      m_migrationConfidence = 0;
      m_swingHighTime = 0; m_swingLowTime = 0;
      // Long-term structure init
      m_ltLastCompute = 0; m_ltValid = false;
      m_ltPOC60d = 0; m_ltPOC30d = 0; m_ltPOC10d = 0;
      m_ltPOCVelocity = 0; m_ltPOCAcceleration = 0; m_ltPOCMigration = 0;
      m_ltMajorHVNPrice = 0; m_ltMajorHVNStrength = 0;
      m_ltMajorLVNPrice = 0; m_ltMajorLVNStrength = 0;
      m_ltNearestZonePrice = 0; m_ltNearestZoneStrength = 0; m_ltNearestZoneDir = 0;
      m_ltAcceptanceAtPrice = 0;
      m_ltTransitionScore = 0; m_ltBalanceStability = 1; m_ltTrendDuration = 0; m_ltTrendExhaustion = 0;
     }

   virtual bool Execute(SVPPipelineState &state) override
     {
      CVPModuleBase::Execute(state);
      double bid = state.marketData.bid;
      double atr = state.marketData.atrProxy;
      int h1Bars = state.marketData.h1Copied;
      int m1Bars = state.marketData.m1Copied;

      datetime currentBar = (h1Bars > 0) ? state.marketData.h1Rates[h1Bars-1].time : 0;
      if(currentBar == m_lastComputeBar && m_profile.isValid)
        { UpdateRelativePosition(bid, atr); WriteState(state); return true; }
      m_lastComputeBar = currentBar;

      m_binWidth = (atr > 0) ? atr / 20.0 : state.marketData.pointSize * 100;

      // ─── Main profile (M1 bars OR real ticks) ────────────────────
      int timeMins[];
      ArrayResize(timeMins, VP_MAX_BINS);
      ArrayInitialize(timeMins, 0);
      double mainHigh = 0, mainLow = 0;

      // These are needed by downstream code (HVN quality, session profile)
      MqlRates vpRates[];
      int copied = 0;

      if(m_dataSource == VP_SOURCE_REAL_TICKS)
        {
         // Tick-based: precise volume distribution from real tick data
         BuildHistogramFromTicks(m_tickLookbackSec,
            m_binPrices, m_binVolumes, timeMins, m_binCount, mainHigh, mainLow);
         if(m_binCount < 5) { m_profile.isValid = false; WriteState(state); return true; }
         // Still need M1 rates for session profile and HVN quality tracking
         copied = CopyRates(m_symbol, PERIOD_M1, 0, m_lookbackBars, vpRates);
         if(copied < 10) copied = 0;  // degrade gracefully
        }
      else
        {
         // M1-based: original behavior (fast, approximate)
         copied = CopyRates(m_symbol, PERIOD_M1, 0, m_lookbackBars, vpRates);
         if(copied < 30) { m_profile.isValid = false; WriteState(state); return true; }
         BuildHistogram(vpRates, copied, m_binPrices, m_binVolumes, timeMins, m_binCount,
                        mainHigh, mainLow);
         if(m_binCount < 5) { m_profile.isValid = false; WriteState(state); return true; }
        }
      for(int i = 0; i < m_binCount; i++) m_binTimeMins[i] = timeMins[i];

      // Update last touch times and retest counts for HVN quality
      for(int b = 0; b < m_binCount; b++)
        {
         datetime lastTouch = 0;
         int retests = 0;
         if(copied > 0)
           {
            for(int r = copied-1; r >= 0; r--)
              {
               if(vpRates[r].high >= m_binPrices[b] - m_binWidth*0.5 &&
                  vpRates[r].low <= m_binPrices[b] + m_binWidth*0.5)
                 {
                  if(lastTouch == 0) lastTouch = vpRates[r].time;
                  else retests++;
                 }
              }
           }
         m_binLastTouchTime[b] = (lastTouch != 0) ? lastTouch : TimeCurrent();
         m_binRetestCount[b] = retests;
        }

      m_profile.profileHigh = mainHigh;
      m_profile.profileLow  = mainLow;

      m_profile.poc = FindPOC(m_binPrices, m_binVolumes, m_binCount);
      ComputeValueArea(m_binVolumes, m_binCount, mainLow, mainHigh,
                       m_profile.vah, m_profile.val);
      FindNodesPercentile(m_binPrices, m_binVolumes, m_binCount, bid, atr);
      m_profile.totalVolume = 0;
      for(int i = 0; i < m_binCount; i++) m_profile.totalVolume += (int)m_binVolumes[i];
      m_profile.barsUsed = copied;
      m_profile.isValid = true;

      ClassifyProfileShape();

      // ─── Session profile ──────────────────────────────────────────
      int sessStart = MathMax(0, copied - m_sessionLookbackBars);
      int sessCount = copied - sessStart;
      if(sessCount >= 20)
        {
         MqlRates sessRates[];
         ArrayResize(sessRates, sessCount);
         for(int i = 0; i < sessCount; i++) sessRates[i] = vpRates[sessStart + i];
         int sBinCount = 0;
         int sBinTime[];
         ArrayResize(sBinTime, VP_MAX_BINS); ArrayInitialize(sBinTime, 0);
         double sessHigh = 0, sessLow = 0;
         BuildHistogram(sessRates, sessCount, m_sessBinPrices, m_sessBinVolumes, sBinTime,
                        sBinCount, sessHigh, sessLow);
         if(sBinCount >= 5)
           {
            m_profile.sessionPOC = FindPOC(m_sessBinPrices, m_sessBinVolumes, sBinCount);
            ComputeValueArea(m_sessBinVolumes, sBinCount, sessLow, sessHigh,
                             m_profile.sessionVAH, m_profile.sessionVAL);
           }
        }

      if(m_profile.sessionPOC > 0 && m_profile.sessionVAH > 0)
        {
         ComputeOverlappingVA();
         m_prevSessionVA.vah = m_profile.sessionVAH;
         m_prevSessionVA.val = m_profile.sessionVAL;
         m_prevSessionVA.sessionEnd = currentBar;
        }

      // ─── Daily composite ──────────────────────────────────────────
      if(h1Bars >= 24)
        {
         MqlRates dailyRates[];
         int dailyCopied = CopyRates(m_symbol, PERIOD_H1, 0, 24, dailyRates);
         if(dailyCopied >= 20)
           {
            int dBinCount = 0; int dBinTime[];
            ArrayResize(dBinTime, VP_MAX_BINS); ArrayInitialize(dBinTime, 0);
            double dailyHigh = 0, dailyLow = 0;
            BuildHistogram(dailyRates, dailyCopied, m_dailyBinPrices, m_dailyBinVolumes,
                           dBinTime, dBinCount, dailyHigh, dailyLow);
            if(dBinCount >= 5)
              {
               double newDailyPOC = FindPOC(m_dailyBinPrices, m_dailyBinVolumes, dBinCount);
               // Register old daily POC as naked when it shifts significantly (>= 2 bins)
               if(m_dailyPOC > 0 && MathAbs(newDailyPOC - m_dailyPOC) > m_binWidth * 2)
                  RegisterSessionPOC(m_dailyPOC);
               m_dailyPOC = newDailyPOC;
              }
           }

         // ─── Day-boundary naked POC: register session POC at new day ───
         MqlDateTime dt;
         TimeCurrent(dt);
         int today = dt.day_of_year;
         if(today != m_lastNakedPOCDay && m_lastNakedPOCDay > 0)
           {
            // New day started — register previous session POC as naked
            if(m_prevSessionPOC > 0)
               RegisterSessionPOC(m_prevSessionPOC);
           }
         m_lastNakedPOCDay = today;
         if(m_profile.sessionPOC > 0)
            m_prevSessionPOC = m_profile.sessionPOC;
        }

      // ─── Composite Profile (72 H1) ────────────────────────────────
      m_compositeValid = false;
      if(h1Bars >= 42)
        {
         int compCount = MathMin(h1Bars - 1, 72);
         int compStart = (h1Bars - 1) - compCount;
         MqlRates compRates[];
         ArrayResize(compRates, compCount);
         for(int i = 0; i < compCount; i++)
            compRates[i] = state.marketData.h1Rates[compStart + i];
         int cBinCount = 0; int cBinTime[];
         ArrayResize(cBinTime, VP_MAX_BINS); ArrayInitialize(cBinTime, 0);
         double compHigh = 0, compLow = 0;
         BuildHistogram(compRates, compCount, m_compositeBinPrices, m_compositeBinVolumes,
                        cBinTime, cBinCount, compHigh, compLow);
         if(cBinCount >= 5)
           {
            double newCompPOC = FindPOC(m_compositeBinPrices, m_compositeBinVolumes, cBinCount);
            // Register old composite POC as naked when it shifts >= 2 bins
            if(m_prevCompositePOC > 0 && MathAbs(newCompPOC - m_prevCompositePOC) > m_binWidth * 2)
               RegisterSessionPOC(m_prevCompositePOC);
            m_prevCompositePOC = newCompPOC;
            m_compositePOC = newCompPOC;
            ComputeValueArea(m_compositeBinVolumes, cBinCount, compLow, compHigh,
                             m_compositeVAH, m_compositeVAL);
            m_compositeValid = true;
           }
        }

      // ─── Naked POCs update (use completed H1 bar) ─────────────────
      if(h1Bars >= 2)
        {
         MqlRates lastCompletedBar = state.marketData.h1Rates[h1Bars - 2];
         UpdateNakedPOCs(bid, atr, lastCompletedBar);
        }

      // ─── Developing POC ───────────────────────────────────────────
      if(m_profile.sessionPOC > 0)
         UpdateDevelopingPOC(m_profile.sessionPOC, atr);
      m_valueMigrationScore = ComputeValueMigrationScore();
      UpdateMigrationConfidence();

      // ─── Anchored profiles ────────────────────────────────────────
      double atrPrice = atr * state.marketData.pointSize;
      if(h1Bars > 0)
         UpdateAnchoredProfiles(state.marketData.h1Rates, h1Bars, atrPrice);
      if(m1Bars > 0)
         UpdateMicroPullbackProfile(state.marketData.m1Rates, m1Bars, atrPrice);

      // ─── Fake breakout detection ──────────────────────────────────
      if(h1Bars > 0)
        {
         MqlRates checkBar = (h1Bars >= 2) ? state.marketData.h1Rates[h1Bars-2] : state.marketData.h1Rates[h1Bars-1];
         long avgVol = 0;
         for(int i = MathMax(0, h1Bars-20); i < h1Bars; i++) avgVol += state.marketData.h1Rates[i].tick_volume;
         avgVol /= 20;
         DetectFakeBreakout(checkBar, m_profile.vah, m_profile.val, avgVol * 2);
        }

      // ─── Composite position ──────────────────────────────────────
      UpdateCompositePosition(bid);

      // ─── [v4.0] Long-Term Structure (H4 60-day, recomputed every 4h) ───
      {
         int h4Bars = state.marketData.h4Copied;
         datetime h4Time = (h4Bars > 0) ? state.marketData.h4Rates[h4Bars-1].time : 0;
         if(h4Time != m_ltLastCompute && h4Bars >= 10)
           {
            m_ltLastCompute = h4Time;
            // Copy full 60-day H4 data (separate from shared cache which only has 50 bars)
            MqlRates ltRates[];
            int ltCopied = CopyRates(m_symbol, PERIOD_H4, 0, LT_H4_LOOKBACK, ltRates);
            if(ltCopied >= 100)
              {
               // Compute H4 ATR for normalization
               double h4Atr = 0;
               int atrPeriod = MathMin(14, ltCopied);
               for(int i = ltCopied - atrPeriod; i < ltCopied; i++)
                  h4Atr += MathAbs(ltRates[i].high - ltRates[i].low);
               h4Atr /= atrPeriod;
               if(h4Atr > 0)
                  _LT_ComputeStructure(ltRates, ltCopied, h4Atr, bid);
               _LT_DetectTransition();
              }
           }
      }

      UpdateRelativePosition(bid, atr);
      WriteState(state);
      return true;
     }

   void UpdateRelativePosition(double bid, double atr)
     {
      if(!m_profile.isValid || atr <= 0) return;
      double pointSz = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pointSz <= 0) pointSz = 0.00001;
      double atrPrice = atr * pointSz;
      m_profile.priceVsPOC = (atrPrice > 0) ? (bid - m_profile.poc) / atrPrice : 0;
      m_profile.insideValueArea = (bid >= m_profile.val && bid <= m_profile.vah);
      double vaRange = m_profile.vah - m_profile.val;
      m_profile.priceVsVA = (vaRange > 0) ? Clamp01((bid - m_profile.val) / vaRange) : 0.5;
     }

   void WriteState(SVPPipelineState &state)
     {
      state.vpValid              = m_profile.isValid;
      state.vpPOC                = m_profile.poc;
      state.vpVAH                = m_profile.vah;
      state.vpVAL                = m_profile.val;
      state.vpNearestHVN         = m_profile.nearestHVN;
      state.vpNearestLVN         = m_profile.nearestLVN;
      state.vpDistToHVN_ATR      = m_profile.distToHVN_ATR;
      state.vpDistToLVN_ATR      = m_profile.distToLVN_ATR;
      state.vpPriceVsPOC         = m_profile.priceVsPOC;
      state.vpPriceVsVA          = m_profile.priceVsVA;
      state.vpInsideVA           = m_profile.insideValueArea;
      state.vpSessionPOC         = m_profile.sessionPOC;
      state.vpDailyPOC           = m_dailyPOC;

      state.vpDevPOCDirection    = (double)m_migrationDir * m_valueMigrationScore;
      state.vpMigrationDirRaw    = (double)m_migrationDir;
      state.vpMigrationScore     = m_valueMigrationScore;
      state.vpDevPOCSlope        = m_devPOCSlope;

      state.vpNearestNakedPOC    = m_nearestNakedPOC;
      state.vpDistToNakedPOC_ATR = m_distToNakedPOC_ATR;

      state.vpCompositePOC       = m_compositeValid ? m_compositePOC : 0;
      state.vpCompositeVAH       = m_compositeValid ? m_compositeVAH : 0;
      state.vpCompositeVAL       = m_compositeValid ? m_compositeVAL : 0;
      state.vpCompositeInsideVA  = m_compositeValid
         ? (state.marketData.bid >= m_compositeVAL && state.marketData.bid <= m_compositeVAH) : false;
      state.vpDistToCompositePOC_ATR = (m_compositeValid && m_compositePOC > 0 && state.marketData.atrProxy > 0)
         ? MathAbs(state.marketData.bid - m_compositePOC) / state.marketData.atrProxy : 0;

      state.vpThinnessRatio           = m_profile.thinnessRatio;
      state.vpProfileShape            = (int)m_profile.profileShape;
      state.vpNearestHighIntensityHVN = m_profile.nearestHighIntensityHVN;
      state.vpDistToHighIntensityHVN_ATR = m_profile.distToHighIntensityHVN_ATR;
      state.vpBestHVN                 = m_profile.bestHVN;
      state.vpBestHVNScore            = m_profile.bestHVNScore;

      state.vpVAOverlapRatio = m_vaOverlapRatio;
      state.vpVAOverlapBias  = (int)m_vaBias;

      state.vpRangePOC   = m_rangeProfile.isValid ? m_rangeProfile.poc : 0;
      state.vpRangeVAH   = m_rangeProfile.isValid ? m_rangeProfile.vah : 0;
      state.vpRangeVAL   = m_rangeProfile.isValid ? m_rangeProfile.val : 0;
      state.vpBreakoutPOC = m_breakoutProfile.isValid ? m_breakoutProfile.poc : 0;
      state.vpBreakoutVAH = m_breakoutProfile.isValid ? m_breakoutProfile.vah : 0;
      state.vpBreakoutVAL = m_breakoutProfile.isValid ? m_breakoutProfile.val : 0;
      state.vpPullbackPOC = m_pullbackProfile.isValid ? m_pullbackProfile.poc : 0;

      state.vpUpthrustDetected = m_upthrustDetected;
      state.vpSpringDetected   = m_springDetected;

      state.vpCompositePosition = m_compositePosition;
      state.vpMigrationConfidence = m_migrationConfidence;

      // ── Long-Term Auction Structure ──────────────────────────────
      state.vpLTPOC60d              = m_ltPOC60d;
      state.vpLTPOC30d              = m_ltPOC30d;
      state.vpLTPOC10d              = m_ltPOC10d;
      state.vpLTPOCVelocity         = m_ltPOCVelocity;
      state.vpLTPOCAcceleration     = m_ltPOCAcceleration;
      state.vpLTPOCMigration        = m_ltPOCMigration;
      state.vpLTMajorHVNPrice       = m_ltMajorHVNPrice;
      state.vpLTMajorHVNStrength    = m_ltMajorHVNStrength;
      state.vpLTMajorLVNPrice       = m_ltMajorLVNPrice;
      state.vpLTMajorLVNStrength    = m_ltMajorLVNStrength;
      state.vpLTNearestZonePrice    = m_ltNearestZonePrice;
      state.vpLTNearestZoneStrength = m_ltNearestZoneStrength;
      state.vpLTNearestZoneDir      = m_ltNearestZoneDir;
      state.vpLTAcceptanceAtPrice   = m_ltAcceptanceAtPrice;
      state.vpLTValid               = m_ltValid;
      state.vpLTTransitionScore     = m_ltTransitionScore;
      state.vpLTBalanceStability    = m_ltBalanceStability;
      state.vpLTTrendDuration       = m_ltTrendDuration;
      state.vpLTTrendExhaustion     = m_ltTrendExhaustion;
     }

   // ─── Accessors ──────────────────────────────────────────────────
   SVolumeProfileData GetProfile(void) const { return m_profile; }
   bool   IsValid(void) const { return m_profile.isValid; }

   // ─── Configuration ──────────────────────────────────────────────
   void SetDataSource(EVPDataSource src) { m_dataSource = src; }
   void SetTickLookback(int seconds) { m_tickLookbackSec = seconds; }
   EVPDataSource GetDataSource(void) const { return m_dataSource; }
   double POC(void) const { return m_profile.poc; }
   double VAH(void) const { return m_profile.vah; }
   double VAL(void) const { return m_profile.val; }
   double SessionPOC(void) const { return m_profile.sessionPOC; }
   double SessionVAH(void) const { return m_profile.sessionVAH; }
   double SessionVAL(void) const { return m_profile.sessionVAL; }
   bool   InsideVA(void) const { return m_profile.insideValueArea; }
   double DistToHVN(void) const { return m_profile.distToHVN_ATR; }
   double DistToLVN(void) const { return m_profile.distToLVN_ATR; }
   double NearestHVN(void) const { return m_profile.nearestHVN; }
   double NearestLVN(void) const { return m_profile.nearestLVN; }
   double DevPOC(void) const { return m_devPOC; }
   double DevPOCVelocity(void) const { return m_devPOCVelocity; }
   double DevPOCSlope(void) const { return m_devPOCSlope; }
   double DevPOCAcceleration(void) const { return m_devPOCAcceleration; }
   EValueMigration MigrationDirection(void) const { return m_migrationDir; }
   double ValueMigrationScore(void) const { return m_valueMigrationScore; }
   double NearestNakedPOC(void) const { return m_nearestNakedPOC; }
   double DistToNakedPOC(void) const { return m_distToNakedPOC_ATR; }
   int    NakedPOCCount(void) const { return m_nakedPOCCount; }
   int    NakedPOCAge(void) const { return m_nakedPOCAge; }
   double CompositePOC(void) const { return m_compositePOC; }
   double CompositeVAH(void) const { return m_compositeVAH; }
   double CompositeVAL(void) const { return m_compositeVAL; }
   bool   CompositeValid(void) const { return m_compositeValid; }
   int    GetBinCount(void) const { return m_binCount; }
   double GetBinPrice(int idx) const { return (idx >= 0 && idx < m_binCount) ? m_binPrices[idx] : 0; }
   long   GetBinVolume(int idx) const { return (idx >= 0 && idx < m_binCount) ? m_binVolumes[idx] : 0; }
   int    GetBinTime(int idx) const { return (idx >= 0 && idx < m_binCount) ? m_binTimeMins[idx] : 0; }
   double GetBinWidth(void) const { return (m_binCount > 1) ? MathAbs(m_binPrices[1] - m_binPrices[0]) : m_binWidth; }

   // ─── Anchored Profile Accessors (for chart overlay) ───
   bool   RangeValid(void) const { return m_rangeProfile.isValid; }
   double RangePOC(void) const { return m_rangeProfile.poc; }
   double RangeVAH(void) const { return m_rangeProfile.vah; }
   double RangeVAL(void) const { return m_rangeProfile.val; }
   bool   BreakoutValid(void) const { return m_breakoutProfile.isValid; }
   double BreakoutPOC(void) const { return m_breakoutProfile.poc; }

   // ─── Fake Breakout Accessors (for chart overlay) ───
   bool     IsUpthrustDetected(void) const { return m_upthrustDetected; }
   bool     IsSpringDetected(void) const { return m_springDetected; }
   datetime GetUpthrustBarTime(void) const { return m_upthrustDetected ? iTime(m_symbol, PERIOD_H1, 1) : 0; }
   double   GetUpthrustPrice(void) const { return m_upthrustDetected ? m_profile.vah : 0; }
   datetime GetSpringBarTime(void) const { return m_springDetected ? iTime(m_symbol, PERIOD_H1, 1) : 0; }
   double   GetSpringPrice(void) const { return m_springDetected ? m_profile.val : 0; }

   // ─── High Intensity HVN ───
   double HighIntensityHVN(void) const { return m_profile.nearestHighIntensityHVN; }
   double DistToHighIntensityHVN(void) const { return m_profile.distToHighIntensityHVN_ATR; }
  };

#endif
