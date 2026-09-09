#ifndef __VP_EA_ENUMS_MQH__
#define __VP_EA_ENUMS_MQH__

// ─── Setup Types ───
enum ESetupType
{
   SETUP_NONE = -1,
   SETUP_BREAKOUT = 0,
   SETUP_BREAKOUT_RETEST = 1,
   SETUP_PULLBACK = 2,
   SETUP_TREND_CONTINUATION = 3,
   SETUP_SWEEP_REVERSAL = 4,
   SETUP_MEAN_REVERSION = 5,
   SETUP_NAKED_POC = 6,
   SETUP_ANCHORED_PULLBACK = 7
};

string SetupTypeToString(ESetupType t)
{
   switch(t)
   {
      case SETUP_BREAKOUT:           return "BREAKOUT";
      case SETUP_BREAKOUT_RETEST:    return "BREAKOUT_RETEST";
      case SETUP_PULLBACK:           return "PULLBACK";
      case SETUP_TREND_CONTINUATION: return "TREND_CONTINUATION";
      case SETUP_SWEEP_REVERSAL:     return "SWEEP_REVERSAL";
      case SETUP_MEAN_REVERSION:     return "MEAN_REVERSION";
      case SETUP_NAKED_POC:          return "NAKED_POC";
      case SETUP_ANCHORED_PULLBACK:  return "ANCHORED_PULLBACK";
      default:                       return "NONE";
   }
}

// ─── Auction Regimes (matches V2 AuctionEnums exactly) ───
enum EAuctionRegime
{
   REGIME_BALANCED_ROTATION  = 0,
   REGIME_COMPRESSION        = 1,
   REGIME_TREND_INITIATION   = 2,
   REGIME_TREND_CONTINUATION = 3,
   REGIME_RE_ACCUMULATION    = 4,
   REGIME_TREND_EXHAUSTION   = 5,
   REGIME_FAILED_AUCTION     = 6,
   REGIME_EXCESS             = 7,
   REGIME_CHAOTIC            = 8
};

// ─── Auction State ───
enum EAuctionState
{
   AUCTION_BALANCED     = 0,
   AUCTION_TRENDING     = 1,
   AUCTION_TRANSITIONAL = 2
};

// ─── Value Area State (matches V2: EXPANDING=0, CONTRACTING=1, STABLE=2) ───
enum EValueAreaState
{
   VA_EXPANDING   = 0,
   VA_CONTRACTING = 1,
   VA_STABLE      = 2
};

// ─── Profile Shape ───
enum EProfileShape
{
   PROFILE_D       = 0,
   PROFILE_P       = 1,
   PROFILE_b       = 2,
   PROFILE_B       = 3,
   PROFILE_THIN    = 4,
   PROFILE_UNKNOWN = 5
};

// ─── Auction Target Type (matches V2 AuctionEnums exactly) ───
enum EAuctionTargetType
{
   TARGET_NONE      = 0,
   TARGET_POC       = 1,
   TARGET_HVN       = 2,
   TARGET_LVN       = 3,
   TARGET_VAH       = 4,
   TARGET_VAL       = 5,
   TARGET_NAKED_POC = 6,
   TARGET_DEV_POC   = 7,
   TARGET_BEST_HVN  = 8,
   TARGET_VA_BOUNDARY = 4,  // alias for TARGET_VAH
   TARGET_COMPOSITE = 9
};

// ─── VP Data Source ───
enum EVPDataSource
{
   VP_SOURCE_M1_BARS    = 0,
   VP_SOURCE_REAL_TICKS = 1
};

// ─── Entry Archetype — defined in 02_VolumeProfile/AuctionThesisManager.mqh ───
// (not duplicated here)

// ─── Trailing Style — defined in 02_VolumeProfile/AuctionTrailingStop.mqh ───
// (not duplicated here)

// ─── Thesis Exit Severity — defined in 02_VolumeProfile/AuctionThesisManager.mqh ───
// (not duplicated here)

// ─── VP Symbol Archetype (from Behavior Profiler) ───
enum EVPSymbolArchetype
{
   VP_ARCH_UNKNOWN           = 0,
   VP_ARCH_TREND_FRIENDLY    = 1,
   VP_ARCH_RANGE_BOUND       = 2,
   VP_ARCH_VOLATILE_SWITCHING = 3,
   VP_ARCH_SPREAD_UNSTABLE   = 4
};

// ─── Session Type ───
enum ESessionType
{
   SESSION_UNKNOWN  = 0,
   SESSION_ASIAN    = 1,
   SESSION_LONDON   = 2,
   SESSION_NEWYORK  = 3,
   SESSION_OVERLAP  = 4
};

// ─── News Impact Level ───
enum ENewsImpact
{
   NEWS_NONE   = 0,
   NEWS_LOW    = 1,
   NEWS_MEDIUM = 2,
   NEWS_HIGH   = 3
};

// ─── Trading Mode (VP EA only uses DAYTRADING, kept for trigger compatibility) ───
enum ETradingMode
{
   MODE_DAYTRADING       = 0,
   MODE_SCALPING         = 1,
   MODE_SWING            = 2,
   MODE_RESEARCH_COLLECT = 3
};

// ─── Cooldown ───
#define SETUP_COOLDOWN_SEC 7200  // 2 hours between same-type triggers

// ─── Magic Number ───
#define VP_EA_MAGIC_NUMBER 202607

// ─── Event Types (used by AuctionTrailingStop event scanner) ───
#define EVENT_BOS            1
#define EVENT_CHOCH          2
#define EVENT_SWEEP          3
#define EVENT_STOP_CLUSTER   4
#define EVENT_COMPRESSION    5
#define EVENT_EXHAUSTION     6
#define EVENT_ABSORPTION     7
#define EVENT_DIVERGENCE     8
#define EVENT_TRIGGER_BREAKOUT        10
#define EVENT_TRIGGER_BREAKOUT_RETEST 11
#define EVENT_TRIGGER_PULLBACK        12
#define EVENT_TRIGGER_TREND_CONT      13
#define EVENT_TRIGGER_SWEEP_REVERSAL  14
#define EVENT_TRIGGER_MEAN_REVERSION  15

#endif
