//+------------------------------------------------------------------+
//| Main_VP_EA.mq5                                                    |
//| Volume Profile Auction EA — Standalone Research & Validation      |
//| Architecture: VP/Auction Pure + VP Behavior Profiler              |
//| Purpose: Research VP edge per-symbol, collect labeled datasets    |
//+------------------------------------------------------------------+
#property copyright "Quant Trading"
#property version   "1.00"
#property strict

#include "SymbolManager\VPSymbolManager.mqh"
#include "07_Notify\TelegramNotifier.mqh"

// ═══════════════════════════════════════════════════════════════════
// INPUTS
// ═══════════════════════════════════════════════════════════════════
input group "RUN MODE";
input EVPRunMode InpMode             = RUN_MODE_LIVE;  // Live=trade w/ edgeguards | DataCollect=tester-only research (3-way trailing fan-out)
input group "GENERAL SETTINGS";
input string InpSymbols              = "";  // Comma-separated symbols (empty = current chart symbol)
input double InpRiskPercent          = 0.5;      // Risk % per trade (0 = use fixed lot)
input double InpFixedLot             = 0.01;     // Fixed lot (0 = risk-based)
input int    InpMaxPositionsPerSymbol = 2;       // Max concurrent positions per symbol
input int    InpTrailingStyle        = 1;        // Trailing: -1=Disabled, 0=Conservative, 1=Expansion
input int    InpTrailMinUpdateSecs   = 60;       // Trailing throttle: min seconds between stop advances (0=every tick)
input int    InpProfilerWarmup       = 100;      // H1 bars warmup before trading
input int    InpNewsBlockBefore      = 30;       // Block entries X mins before high-impact news
input int    InpNewsBlockAfter       = 15;
input int    InpMagicNumber          = 202607;
input int    InpLogVerbosity         = 1;        // 0=Silent, 1=Normal, 2=Verbose
input group "TRIGGERS SETTINGS";           // ─── Trigger Enable/Disable ───       // Block entries X mins after high-impact news
input bool   InpEnableBreakout       = true;
input bool   InpEnableBreakoutRetest = true;
input bool   InpEnablePullback       = true;
input bool   InpEnableTrendCont      = true;
input bool   InpEnableSweepReversal  = true;
input bool   InpEnableMeanReversion  = true;
input bool   InpEnableNakedPOC       = true; 
input bool   InpEnableAnchoredPullback = true;
input group "DATA COLLECT- LIVE TRADING MODE SWITCH";
input bool   InpLogFunnel            = false;     // CSV funnel logging
input bool   InpUseEdgeGuards        = true;    // Enable EdgeGuard filtering (from research)
input double InpMinTiltThreshold     = 0.0;     // Min cumulative soft-tilt to allow trade (0=off, 0.65=block weak setups)
input group "SIZING CALIBRATION (Phase 06)";
input bool   InpUseSizingCalibration = false;    // MaxLot mode: scale lot by research multiplier
input double InpMaxLot               = 0.10;     // Max lot ceiling when sizing calibration is ON (0=symbol max)
input group "TELEGRAM NOTIFICATIONS";
input bool   InpTelegramEnabled      = true;    // Send trade events to Telegram
input string InpTelegramBotToken     = "";       // Bot token from @BotFather
input string InpTelegramChatId       = "";       // Target chat id
input string InpTelegramPrefix       = "";       // Optional label shown in each message (e.g. account name)
input group "VISUALS";
input bool   InpShowDashboard        = false;    // On-chart info dashboard panel
input bool   InpShowOverlay          = false;    // Volume Profile levels overlay on price chart

// ═══════════════════════════════════════════════════════════════════
// GLOBALS
// ═══════════════════════════════════════════════════════════════════
CVPSymbolManager g_symbolManager;

//+------------------------------------------------------------------+
int OnInit()
{
   g_logVerbosity = (ELogVerbosity)InpLogVerbosity;

   SVPEAConfig config;
   SetDefaultVPConfig(config);
   config.presetMode = InpMode;
   config.riskPercent = InpRiskPercent;
   config.fixedLot = InpFixedLot;
   config.maxPositionsPerSymbol = InpMaxPositionsPerSymbol;
   config.trailingStyle = InpTrailingStyle;
   config.trailMinUpdateSecs = InpTrailMinUpdateSecs;
   config.profilerWarmupBars = InpProfilerWarmup;
   config.newsBlockMinsBefore = InpNewsBlockBefore;
   config.newsBlockMinsAfter = InpNewsBlockAfter;
   config.magicNumber = InpMagicNumber;
   config.enableBreakout = InpEnableBreakout;
   config.enableBreakoutRetest = InpEnableBreakoutRetest;
   config.enablePullback = InpEnablePullback;
   config.enableTrendCont = InpEnableTrendCont;
   config.enableSweepReversal = InpEnableSweepReversal;
   config.enableMeanReversion = InpEnableMeanReversion;
   config.enableNakedPOC = InpEnableNakedPOC;
   config.enableAnchoredPullback = InpEnableAnchoredPullback;
   config.logFunnel = InpLogFunnel;
   config.useEdgeGuards = InpUseEdgeGuards;
   config.minTiltThreshold = InpMinTiltThreshold;
   config.useSizingCalibration = InpUseSizingCalibration;
   config.maxLot = InpMaxLot;
   config.telegramEnabled = InpTelegramEnabled;
   config.telegramBotToken = InpTelegramBotToken;
   config.telegramChatId = InpTelegramChatId;
   config.telegramPrefix = InpTelegramPrefix;
   config.showDashboard = InpShowDashboard;
   config.showOverlay = InpShowOverlay;

   // ─── Preset mode overrides ───────────────────────────────────────
   // The mode presets the parameters that define each workflow, so the user
   // only picks a mode instead of juggling many inputs. Inputs that conflict
   // with the chosen mode are overridden here.
   bool inTester = (bool)MQLInfoInteger(MQL_TESTER);
   if (InpMode == RUN_MODE_DATACOLLECT)
   {
      // DataCollect is a research harness — it is meaningless (and unsafe) live.
      if (!inTester)
      {
         PrintFormat("[VP_EA] FATAL: DataCollect mode runs in the Strategy Tester only.");
         return INIT_FAILED;
      }
      // All triggers on, no position cap, funnel on, edgeguards off (collect raw).
      config.enableBreakout = true;
      config.enableBreakoutRetest = true;
      config.enablePullback = true;
      config.enableTrendCont = true;
      config.enableSweepReversal = true;
      config.enableMeanReversion = true;
      config.enableNakedPOC = true;
      config.enableAnchoredPullback = true;
      config.maxPositionsPerSymbol = VP_MAX_POSITIONS; // effectively uncapped; fan-out bypasses the cap anyway
      config.logFunnel = true;
      config.useEdgeGuards = false;
      // Sizing calibration MUST be off while collecting: it would scale lots by
      // the research lot-multipliers, making profitUSD (the research target)
      // reflect calibrated sizing instead of the raw signal edge — and create a
      // self-referential loop (collecting data with the multipliers we're trying
      // to discover). It also breaks the like-for-like 3-style fan-out. Raw,
      // consistent lots only.
      config.useSizingCalibration = false;
   }
   else // RUN_MODE_LIVE
   {
      // Live defaults: edgeguards on, funnel off. Works live or in tester.
      config.useEdgeGuards = true;
      config.logFunnel = false;
   }

   // If symbols input is empty, use the chart symbol
   string symbolsToUse = InpSymbols;
   if (StringLen(symbolsToUse) == 0 || symbolsToUse == "")
      symbolsToUse = _Symbol;

   if (!g_symbolManager.Initialize(symbolsToUse, config))
   {
      PrintFormat("[VP_EA] FATAL: No symbols initialized");
      return INIT_FAILED;
   }

   string modeStr = (InpMode == RUN_MODE_DATACOLLECT) ? "DATACOLLECT" : "LIVE";
   PrintFormat("[VP_EA] v1.00 initialized | mode=%s | symbols=%d | magic=%d | warmup=%d",
      modeStr, g_symbolManager.SymbolCount(), InpMagicNumber, InpProfilerWarmup);
   if (InpMode == RUN_MODE_DATACOLLECT)
      PrintFormat("[VP_EA] DataCollect: all triggers ON, no position cap, funnel ON, edgeguards OFF, sizing-calibration OFF, 3-way trailing fan-out (-1/0/1)");
   PrintFormat("[VP_EA] Triggers: BO=%d BOR=%d PB=%d TC=%d SR=%d MR=%d NPOC=%d APB=%d",
      InpEnableBreakout, InpEnableBreakoutRetest, InpEnablePullback,
      InpEnableTrendCont, InpEnableSweepReversal, InpEnableMeanReversion,
      InpEnableNakedPOC, InpEnableAnchoredPullback);

   // ─── Telegram startup notification ───────────────────────────────
   if (InpTelegramEnabled)
   {
      string trailStr;
      if      (InpMode == RUN_MODE_DATACOLLECT) trailStr = "3-way fan (-1/0/1)";
      else if (InpTrailingStyle == -1) trailStr = "OFF";
      else if (InpTrailingStyle ==  0) trailStr = "Conservative";
      else                             trailStr = "Expansion";

      // Reflect the effective (post-preset) sizing, not the raw input.
      string sizingStr = config.useSizingCalibration
         ? ("MaxLot " + DoubleToString(InpMaxLot, 2))
         : (InpFixedLot > 0
            ? ("Fixed " + DoubleToString(InpFixedLot, 2))
            : ("Risk " + DoubleToString(InpRiskPercent, 2) + "%"));

      // Reflect effective (post-preset) trigger set, not the raw inputs.
      string triggersOn = "";
      if (config.enableBreakout)        triggersOn += "BO ";
      if (config.enableBreakoutRetest)  triggersOn += "BOR ";
      if (config.enablePullback)        triggersOn += "PB ";
      if (config.enableTrendCont)       triggersOn += "TC ";
      if (config.enableSweepReversal)   triggersOn += "SR ";
      if (config.enableMeanReversion)   triggersOn += "MR ";
      if (config.enableNakedPOC)        triggersOn += "NPOC ";
      if (config.enableAnchoredPullback)triggersOn += "APB";
      StringTrimRight(triggersOn);

      string msg =
         "<b>[EA STARTED]</b> VP EA v1.00\n" +
         "Mode: <b>" + modeStr + "</b>\n" +
         "Account: <b>" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "</b>"
         + " | " + AccountInfoString(ACCOUNT_SERVER) + "\n" +
         "Symbol(s): " + (InpSymbols == "" ? _Symbol : InpSymbols) + "\n" +
         "Magic: " + IntegerToString(InpMagicNumber) + "\n" +
         "Sizing: " + sizingStr +
         " | MaxPos: " + IntegerToString(config.maxPositionsPerSymbol) + "\n" +
         "Trailing: " + trailStr + "\n" +
         "EdgeGuards: " + (config.useEdgeGuards ? "ON" : "OFF") +
         " | Funnel log: " + (config.logFunnel ? "ON" : "OFF") + "\n" +
         "Triggers: " + triggersOn;

      CVPTelegramNotifier startupBot;
      startupBot.Bootstrap(true, InpTelegramBotToken, InpTelegramChatId, InpTelegramPrefix);
      startupBot.NotifyText(msg);
   }

   EventSetTimer(30);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   g_symbolManager.OnTick();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   // Backup tick for symbols that may not tick frequently
   g_symbolManager.OnTick();
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   g_symbolManager.OnTradeTransaction(trans, request, result);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_symbolManager.Shutdown();
   PrintFormat("[VP_EA] Deinit reason=%d", reason);
}
