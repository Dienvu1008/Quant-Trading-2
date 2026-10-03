#ifndef __VP_EA_EDGEGUARD_CONFIG_MQH__
#define __VP_EA_EDGEGUARD_CONFIG_MQH__

// ============================================================
// VP EdgeGuard Config -- RESEARCH MODE (dev-validated only)
// Generated  : 2026-09-28 08:55
// Experiment : EXP-2026-09-28-001
// WARNING: NOT HOLDOUT-CONFIRMED.
//   Use with small lots for out-of-sample validation only.
// ============================================================

// 1. Hard gate blocking -- 0 rules [RESEARCH]
double VPGetEdgeMultiplier(const string symbol, const string setup,
                            const string feature, double value)
{
   return 1.0;
}

// 2. Soft gate tilt -- 2107 tilts [RESEARCH]
// Returns [0.5,1.0]. Does NOT block.
// Tilt DOWN on unfavourable side of feature median.
//   direction=+1: high value good -> tilt when value <= median
//   direction=-1: low value good  -> tilt when value >= median
double VPGetEdgeTiltMultiplier(const string symbol, const string setup,
                               const string feature, double value)
{
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationConf" && value>=0.800000) return 0.6000; // lift=+0.095 p=0.0000 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.636000) return 0.6000; // lift=+0.154 p=0.0000 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="liqContext" && value>=0.447400) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=0.105940) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.700000) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.099 p=0.0000 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.692500) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.680000) return 0.6000; // lift=+0.068 p=0.0000 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.688500) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.708000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.627000) return 0.6000; // lift=+0.071 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.625000) return 0.6000; // lift=+0.188 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.239794) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.493000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.412000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.705000) return 0.6000; // lift=+0.130 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="liqContext" && value>=0.480400) return 0.6000; // lift=+0.082 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.082 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.703000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.320167) return 0.7000; // lift=+0.035 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.476000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.382000) return 0.7000; // lift=+0.044 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="auctExhaustion" && value<=0.228000) return 0.7000; // lift=+0.045 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.709500) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.044 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.711000) return 0.6000; // lift=+0.075 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.504250) return 0.7000; // lift=+0.042 p=0.0000 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=0.003126) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-0.003584) return 0.7000; // lift=+0.044 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=0.000000) return 0.7000; // lift=+0.055 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="vpDevPOCSlope" && value>=0.006700) return 0.7000; // lift=+0.058 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.690000) return 0.7000; // lift=+0.054 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="atrProxy" && value>=94.300000) return 0.7000; // lift=+0.065 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.634000) return 0.6000; // lift=+0.130 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.381000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.321333) return 0.6000; // lift=+0.111 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=91.600000) return 0.6000; // lift=+0.094 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=-0.000119) return 0.7000; // lift=+0.041 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=-0.419450) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=-0.019500) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctExpReward" && value<=1.003000) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.706000) return 0.6000; // lift=+0.072 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.317500) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="atrProxy" && value>=93.700000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=-0.294900) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCSlope" && value>=-0.013850) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.707000) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.367000) return 0.7000; // lift=+0.042 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="smZoneQuality" && value>=0.859000) return 0.7000; // lift=+0.044 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=93.700000) return 0.6000; // lift=+0.078 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-0.000021) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.000000) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=-0.008000) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.705000) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="smZoneQuality" && value>=0.860000) return 0.7000; // lift=+0.048 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="atrProxy" && value>=93.600000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.640000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK" && feature=="atrProxy" && value>=92.400000) return 0.7000; // lift=+0.054 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.292000) return 0.6000; // lift=+0.072 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.674000) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.686000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.408000) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.275000) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.713000) return 0.6000; // lift=+0.121 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.319833) return 0.6000; // lift=+0.083 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="atrProxy" && value>=92.600000) return 0.6000; // lift=+0.098 p=0.0000 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="NAKED_POC" && feature=="atrProxy" && value>=95.800000) return 0.6000; // lift=+0.102 p=0.0000 tilt=0.60
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.675000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.098900) return 0.7000; // lift=+0.039 p=0.0000 tilt=0.70
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.617000) return 0.6000; // lift=+0.163 p=0.0000 tilt=0.60
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.373000) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   if(symbol=="EURJPYm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.684000) return 0.6000; // lift=+0.079 p=0.0000 tilt=0.60
   if(symbol=="EURJPYm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.366500) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.701000) return 0.6000; // lift=+0.113 p=0.0000 tilt=0.60
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.366000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.314000) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="EURJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCDir" && value>=0.615000) return 0.7000; // lift=+0.048 p=0.0000 tilt=0.70
   if(symbol=="EURJPYm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.691000) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="EURJPYm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.035 p=0.0000 tilt=0.70
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.688000) return 0.6000; // lift=+0.071 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.685000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.722000) return 0.6000; // lift=+0.132 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.368000) return 0.6000; // lift=+0.086 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.318250) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.172 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.707000) return 0.6000; // lift=+0.083 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.361000) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.698000) return 0.6000; // lift=+0.086 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.065 p=0.0000 tilt=0.70
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.691000) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.043 p=0.0000 tilt=0.70
   if(symbol=="EURUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.617500) return 0.6000; // lift=+0.164 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.380000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.640000) return 0.6000; // lift=+0.094 p=0.0000 tilt=0.60
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.706000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="EURCADm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.622500) return 0.7000; // lift=+0.055 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.669000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="EURCADm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.387000) return 0.7000; // lift=+0.043 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.243000) return 0.7000; // lift=+0.042 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.896000) return 0.7000; // lift=+0.035 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.682000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.322833) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-0.002432) return 0.7000; // lift=+0.035 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.682000) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST" && feature=="auctTargetProb" && value<=0.365000) return 0.7000; // lift=+0.038 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.358000) return 0.7000; // lift=+0.035 p=0.0000 tilt=0.70
   if(symbol=="EURCADm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.616000) return 0.6000; // lift=+0.158 p=0.0000 tilt=0.60
   if(symbol=="EURCADm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.369000) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=0.006273) return 0.6000; // lift=+0.095 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.902000) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.720000) return 0.6000; // lift=+0.143 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.370000) return 0.6000; // lift=+0.083 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.311000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.722000) return 0.6000; // lift=+0.105 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-0.289227) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-0.690093) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.716000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.373000) return 0.6000; // lift=+0.082 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.325500) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.021615) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.108499) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.709000) return 0.6000; // lift=+0.090 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.371000) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.630000) return 0.6000; // lift=+0.197 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.385000) return 0.6000; // lift=+0.090 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.652000) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.710000) return 0.6000; // lift=+0.075 p=0.0000 tilt=0.60
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.318000) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.618000) return 0.6000; // lift=+0.197 p=0.0000 tilt=0.60
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.369000) return 0.6000; // lift=+0.107 p=0.0000 tilt=0.60
   if(symbol=="GBPJPYm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.687000) return 0.6000; // lift=+0.118 p=0.0000 tilt=0.60
   if(symbol=="GBPJPYm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="ANCHORED_PULLBACK" && feature=="auctTradeQuality" && value>=0.447000) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.624500) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.677000) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.684000) return 0.6000; // lift=+0.092 p=0.0000 tilt=0.60
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.679000) return 0.6000; // lift=+0.109 p=0.0000 tilt=0.60
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.358000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.317667) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.684000) return 0.6000; // lift=+0.084 p=0.0000 tilt=0.60
   if(symbol=="GBPJPYm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="NAKED_POC" && feature=="vpDistToLVN" && value<=0.271000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="US30m" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.695000) return 0.6000; // lift=+0.079 p=0.0000 tilt=0.60
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="vpDistToLVN" && value<=0.262000) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-28.073550) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.738000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.376000) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.691000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="US30m" && setup=="MEAN_REVERSION" && feature=="msContext" && value>=0.389250) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="US30m" && setup=="BREAKOUT" && feature=="vpDistCompPOC" && value>=0.267000) return 0.7000; // lift=+0.054 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-29.722945) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.774300) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.426500) return 0.7000; // lift=+0.054 p=0.0000 tilt=0.70
   if(symbol=="US30m" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.577000) return 0.6000; // lift=+0.181 p=0.0000 tilt=0.60
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.695000) return 0.6000; // lift=+0.082 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.716000) return 0.6000; // lift=+0.092 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.001057) return 0.7000; // lift=+0.043 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-0.304938) return 0.7000; // lift=+0.055 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.054934) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.042 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.391000) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.710000) return 0.6000; // lift=+0.092 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.368000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.227000) return 0.7000; // lift=+0.055 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.731000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.358000) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.908000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.717000) return 0.6000; // lift=+0.128 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.367000) return 0.6000; // lift=+0.085 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.210150) return 0.6000; // lift=+0.077 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="auctTradeQuality" && value>=0.424000) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.709000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.234300) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.637500) return 0.6000; // lift=+0.105 p=0.0000 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.587500) return 0.6000; // lift=+0.197 p=0.0000 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.687000) return 0.7000; // lift=+0.039 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.039 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.324333) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.319900) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.019382) return 0.7000; // lift=+0.065 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.686000) return 0.6000; // lift=+0.118 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="msContext" && value>=0.399500) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.483000) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.615500) return 0.6000; // lift=+0.175 p=0.0000 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.326500) return 0.6000; // lift=+0.098 p=0.0000 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.694000) return 0.6000; // lift=+0.071 p=0.0000 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.058 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.308200) return 0.7000; // lift=+0.045 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.681000) return 0.6000; // lift=+0.075 p=0.0000 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.338100) return 0.7000; // lift=+0.048 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.737000) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.099300) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpBestHVNScore" && value>=0.738000) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.647000) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>=0.197600) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDailyPOC" && value<=-0.280171) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompPOC" && value<=-0.366930) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompVAH" && value<=-0.029107) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.681000) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="smContext" && value<=0.110800) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>=0.283300) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.357000) return 0.7000; // lift=+0.038 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.677000) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.689000) return 0.6000; // lift=+0.080 p=0.0000 tilt=0.60
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.646000) return 0.6000; // lift=+0.121 p=0.0000 tilt=0.60
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.683000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="smContext" && value<=0.111200) return 0.7000; // lift=+0.035 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.314750) return 0.7000; // lift=+0.039 p=0.0000 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.677000) return 0.7000; // lift=+0.038 p=0.0000 tilt=0.70
   if(symbol=="USOILm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.710000) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.713000) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="USOILm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.373000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USOILm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.320333) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.563000) return 0.6000; // lift=+0.203 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.382000) return 0.6000; // lift=+0.091 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.714000) return 0.6000; // lift=+0.138 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.376000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.321500) return 0.6000; // lift=+0.083 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.629500) return 0.6000; // lift=+0.094 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAOverlapRatio" && value<=0.471500) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="BREAKOUT_RETEST" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   if(symbol=="USOILm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.740000) return 0.6000; // lift=+0.104 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.364000) return 0.6000; // lift=+0.084 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USOILm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.318333) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="USOILm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.705000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   if(symbol=="XAUGBPm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.703000) return 0.7500; // lift=+0.027 p=0.0000 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.408200) return 0.7000; // lift=+0.034 p=0.0000 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.238000) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.434500) return 0.7000; // lift=+0.038 p=0.0000 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.687500) return 0.7000; // lift=+0.034 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="XAUGBPm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.493200) return 0.7500; // lift=+0.028 p=0.0000 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=0.072180) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.634000) return 0.6000; // lift=+0.116 p=0.0000 tilt=0.60
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.411200) return 0.7000; // lift=+0.068 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.689500) return 0.7000; // lift=+0.055 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.364500) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="smContext" && value<=0.373200) return 0.7000; // lift=+0.048 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.319000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.018644) return 0.6000; // lift=+0.093 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.240000) return 0.7000; // lift=+0.065 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.414000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.908000) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.675000) return 0.6000; // lift=+0.147 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="msContext" && value>=0.395000) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.361000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="smContext" && value<=0.379600) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.294800) return 0.6000; // lift=+0.089 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.016093) return 0.6000; // lift=+0.091 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.487000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.604000) return 0.6000; // lift=+0.197 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.318900) return 0.6000; // lift=+0.079 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.023947) return 0.7000; // lift=+0.036 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.393000) return 0.7000; // lift=+0.034 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="auctExhaustion" && value<=0.237000) return 0.7000; // lift=+0.044 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.694000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.306050) return 0.7000; // lift=+0.042 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.142209) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.686000) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.323500) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.336700) return 0.7000; // lift=+0.043 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.728000) return 0.7000; // lift=+0.065 p=0.0000 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.097800) return 0.6000; // lift=+0.078 p=0.0000 tilt=0.60
   if(symbol=="US500m" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.565500) return 0.6000; // lift=+0.206 p=0.0000 tilt=0.60
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.690000) return 0.6000; // lift=+0.133 p=0.0000 tilt=0.60
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.383000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="US500m" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.720000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.427000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.389000) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="MEAN_REVERSION" && feature=="auctReversalRisk" && value<=0.140000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="bosQuality")
   if(symbol=="GBPCHFm" && setup=="BREAKOUT" && feature=="bosQuality" && value>=0.000000) return 0.6000; // lift=+0.319 p=0.0000 tilt=0.60
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpVAOverlapRatio" && value<=0.464000) return 0.6000; // lift=+0.075 p=0.0000 tilt=0.60
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=0.046050) return 0.6000; // lift=+0.071 p=0.0000 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.709000) return 0.6000; // lift=+0.120 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.309333) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.142000) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.428000) return 0.7000; // lift=+0.054 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.666000) return 0.6000; // lift=+0.134 p=0.0000 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.605000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.676000) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.683000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.038 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=0.143200) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.668000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="BREAKOUT" && feature=="auctVAExpRate" && value>=0.000000) return 0.6000; // lift=+0.113 p=0.0000 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.668000) return 0.7000; // lift=+0.065 p=0.0000 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.361000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.000052) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="vpPriceVsPOC" && value>=-0.652000) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.710000) return 0.6000; // lift=+0.135 p=0.0000 tilt=0.60
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.369000) return 0.6000; // lift=+0.077 p=0.0000 tilt=0.60
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.619500) return 0.6000; // lift=+0.203 p=0.0000 tilt=0.60
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.376000) return 0.6000; // lift=+0.072 p=0.0000 tilt=0.60
   if(symbol=="USDCADm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.690000) return 0.6000; // lift=+0.081 p=0.0000 tilt=0.60
   if(symbol=="USDCADm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDCADm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.316667) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="USDCADm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.685500) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="USDCADm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.701000) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="USDCADm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.371000) return 0.7000; // lift=+0.040 p=0.0000 tilt=0.70
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.632000) return 0.6000; // lift=+0.083 p=0.0000 tilt=0.60
   if(symbol=="USTECm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.689000) return 0.6000; // lift=+0.077 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USTECm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.324833) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.732000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.157000) return 0.6000; // lift=+0.151 p=0.0000 tilt=0.60
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.423000) return 0.6000; // lift=+0.124 p=0.0000 tilt=0.60
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.569000) return 0.6000; // lift=+0.189 p=0.0000 tilt=0.60
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.381000) return 0.6000; // lift=+0.118 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.305167) return 0.6000; // lift=+0.109 p=0.0000 tilt=0.60
   if(symbol=="USTECm" && setup=="NAKED_POC" && feature=="auctLVNStrength" && value<=0.902000) return 0.6000; // lift=+0.117 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.732000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.370000) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.740500) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.033475) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.731000) return 0.6000; // lift=+0.075 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.100159) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.281000) return 0.6000; // lift=+0.099 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.408000) return 0.6000; // lift=+0.100 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.713000) return 0.6000; // lift=+0.126 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.369000) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.588500) return 0.6000; // lift=+0.219 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.376045) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.347643) return 0.6000; // lift=+0.081 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-1.105498) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.067050) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-0.876426) return 0.6000; // lift=+0.081 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=2.169047) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=0.615000) return 0.6000; // lift=+0.121 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCSlope" && value>=0.061550) return 0.6000; // lift=+0.114 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="smZoneQuality" && value>=0.858000) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.678000) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.761000) return 0.6000; // lift=+0.079 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.369000) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.317667) return 0.6000; // lift=+0.094 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="atrProxy" && value>=1934.400000) return 0.6000; // lift=+0.078 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="auctTradeQuality" && value>=0.394000) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="vpLTTransitionScore" && value>=0.028000) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="vpLTBalanceStability" && value<=0.972000) return 0.7000; // lift=+0.067 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.582500) return 0.6000; // lift=+0.153 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=1846.100000) return 0.6000; // lift=+0.098 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="NAKED_POC" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpPOC" && value<=-0.361623) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpVAH" && value<=0.409766) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpVAL" && value<=-1.148983) return 0.6000; // lift=+0.072 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpPriceVsPOC" && value>=0.083900) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=-0.840452) return 0.6000; // lift=+0.084 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-0.904811) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=2.294904) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=0.580600) return 0.6000; // lift=+0.085 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpDevPOCSlope" && value>=0.054700) return 0.6000; // lift=+0.091 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="smZoneQuality" && value>=0.865000) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="atrProxy" && value>=1893.300000) return 0.7000; // lift=+0.058 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-0.836000) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.615000) return 0.6000; // lift=+0.104 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=0.060800) return 0.6000; // lift=+0.098 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="msCompression" && value>=0.757000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="smZoneQuality" && value>=0.865000) return 0.6000; // lift=+0.071 p=0.0000 tilt=0.60
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=-0.578985) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.315833) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.241944) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.712500) return 0.6000; // lift=+0.084 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpVAH" && value<=0.203495) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpVAL" && value<=-1.293254) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpDistToHVN" && value<=0.129000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=-2.032157) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-2.668997) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=0.606104) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpBestHVNScore" && value>=0.698000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.790000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpMigrationScore" && value>=0.790000) return 0.6000; // lift=+0.075 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctAcceptance" && value>=0.560000) return 0.6000; // lift=+0.091 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctBalance" && value<=0.651000) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctTargetProb" && value<=0.375000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctExhaustion" && value<=0.217000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctContinuation" && value>=0.247000) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.717000) return 0.6000; // lift=+0.106 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="msContext" && value>=0.450500) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.385000) return 0.6000; // lift=+0.104 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.321833) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="smZoneQuality" && value>=0.936000) return 0.6000; // lift=+0.086 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="smContext" && value<=0.377800) return 0.6000; // lift=+0.081 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="atrProxy" && value>=1445.500000) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.163919) return 0.7000; // lift=+0.045 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="msCompression" && value>=0.731000) return 0.7000; // lift=+0.041 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="auctHVNStrength" && value<=0.823000) return 0.7000; // lift=+0.036 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.742500) return 0.7000; // lift=+0.050 p=0.0000 tilt=0.70
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.569000) return 0.6000; // lift=+0.150 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.313500) return 0.6000; // lift=+0.075 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.342600) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.761000) return 0.6000; // lift=+0.086 p=0.0000 tilt=0.60
   if(symbol=="STOXX50m" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.686500) return 0.6000; // lift=+0.092 p=0.0000 tilt=0.60
   if(symbol=="XAUEURm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.693000) return 0.7500; // lift=+0.033 p=0.0000 tilt=0.75
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.690000) return 0.7000; // lift=+0.042 p=0.0000 tilt=0.70
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.174100) return 0.7000; // lift=+0.048 p=0.0000 tilt=0.70
   if(symbol=="XAUEURm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.696000) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.696000) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.311200) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAL" && value<=-0.256711) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompVAH" && value<=-0.032502) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="vpPOC" && value<=0.096622) return 0.6000; // lift=+0.071 p=0.0000 tilt=0.60
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.637000) return 0.6000; // lift=+0.125 p=0.0000 tilt=0.60
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.372800) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="EURAUDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.729000) return 0.6000; // lift=+0.091 p=0.0000 tilt=0.60
   if(symbol=="EURAUDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7000; // lift=+0.045 p=0.0000 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.426000) return 0.7000; // lift=+0.058 p=0.0000 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.673000) return 0.6000; // lift=+0.137 p=0.0000 tilt=0.60
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.669500) return 0.6000; // lift=+0.085 p=0.0000 tilt=0.60
   if(symbol=="EURAUDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.615000) return 0.6000; // lift=+0.082 p=0.0000 tilt=0.60
   if(symbol=="EURAUDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.668000) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="EURAUDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.673000) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.675000) return 0.7000; // lift=+0.068 p=0.0000 tilt=0.70
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.043 p=0.0000 tilt=0.70
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=0.000080) return 0.6000; // lift=+0.086 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpPOC" && value<=0.000131) return 0.6000; // lift=+0.108 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpVAH" && value<=0.000792) return 0.6000; // lift=+0.081 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpVAL" && value<=-0.000457) return 0.6000; // lift=+0.091 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpPriceVsPOC" && value>=-0.112700) return 0.6000; // lift=+0.069 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=0.000451) return 0.6000; // lift=+0.086 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=0.000678) return 0.7000; // lift=+0.057 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-0.002387) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=-0.545000) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpDevPOCSlope" && value>=-0.033850) return 0.6000; // lift=+0.096 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.665000) return 0.7000; // lift=+0.043 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="smZoneQuality" && value>=0.887000) return 0.6000; // lift=+0.068 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.000025) return 0.7000; // lift=+0.056 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.000705) return 0.7000; // lift=+0.068 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=0.000543) return 0.7000; // lift=+0.068 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=0.000768) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=-0.615000) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=-0.053000) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.684000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="smZoneQuality" && value>=0.897000) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.000622) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=0.000446) return 0.6000; // lift=+0.081 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=0.000732) return 0.7000; // lift=+0.059 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=-0.615000) return 0.6000; // lift=+0.114 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCSlope" && value>=-0.058950) return 0.6000; // lift=+0.120 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="auctExpReward" && value<=1.050000) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.388000) return 0.7000; // lift=+0.045 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="smZoneQuality" && value>=0.895000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDistToHVN" && value<=0.103000) return 0.7500; // lift=+0.028 p=0.0000 tilt=0.75
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=0.000331) return 0.7000; // lift=+0.048 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=0.003997) return 0.7000; // lift=+0.038 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=-0.650000) return 0.7000; // lift=+0.061 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=-0.068400) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.682000) return 0.6000; // lift=+0.080 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.598000) return 0.6000; // lift=+0.102 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.323500) return 0.6000; // lift=+0.100 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.669000) return 0.7000; // lift=+0.053 p=0.0000 tilt=0.70
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.682000) return 0.7000; // lift=+0.043 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.321667) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.118 p=0.0000 tilt=0.60
   if(symbol=="EURGBPm" && setup=="NAKED_POC" && feature=="vpDistToHVN" && value<=0.190000) return 0.6000; // lift=+0.148 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.695000) return 0.6000; // lift=+0.120 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.357000) return 0.7000; // lift=+0.054 p=0.0000 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.316333) return 0.7000; // lift=+0.051 p=0.0000 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.682000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.361000) return 0.7000; // lift=+0.047 p=0.0000 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.686500) return 0.6000; // lift=+0.103 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.363000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=-0.000055) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.635000) return 0.6000; // lift=+0.229 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.368000) return 0.6000; // lift=+0.090 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.000458) return 0.7000; // lift=+0.049 p=0.0000 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.290000) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.407000) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.277000) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.704000) return 0.6000; // lift=+0.117 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.363000) return 0.6000; // lift=+0.078 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.315000) return 0.7000; // lift=+0.062 p=0.0000 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.620000) return 0.6000; // lift=+0.101 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.685000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.044 p=0.0000 tilt=0.70
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.694500) return 0.7000; // lift=+0.034 p=0.0000 tilt=0.70
   if(symbol=="GBPCADm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.664000) return 0.7000; // lift=+0.035 p=0.0000 tilt=0.70
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.000690) return 0.7000; // lift=+0.034 p=0.0000 tilt=0.70
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.662000) return 0.6000; // lift=+0.072 p=0.0000 tilt=0.60
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.667000) return 0.7000; // lift=+0.066 p=0.0000 tilt=0.70
   if(symbol=="GBPCADm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.595000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="GBPCADm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.614000) return 0.6000; // lift=+0.097 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPCADm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.302333) return 0.7000; // lift=+0.064 p=0.0000 tilt=0.70
   if(symbol=="GBPCADm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.682000) return 0.6000; // lift=+0.097 p=0.0000 tilt=0.60
   if(symbol=="AAPLm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.798000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="AAPLm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.777000) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="NVDAm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.752000) return 0.6000; // lift=+0.105 p=0.0000 tilt=0.60
   if(symbol=="NVDAm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.345000) return 0.6000; // lift=+0.092 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NVDAm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.301167) return 0.6000; // lift=+0.081 p=0.0000 tilt=0.60
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST" && feature=="auctAcceptance" && value>=0.576000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST" && feature=="auctTargetProb" && value<=0.375000) return 0.6000; // lift=+0.087 p=0.0000 tilt=0.60
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST" && feature=="auctExhaustion" && value<=0.206000) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.683000) return 0.6000; // lift=+0.085 p=0.0000 tilt=0.60
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK" && feature=="smZoneQuality" && value>=0.961000) return 0.6000; // lift=+0.085 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.312500) return 0.7000; // lift=+0.046 p=0.0000 tilt=0.70
   if(symbol=="NVDAm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.631000) return 0.6000; // lift=+0.174 p=0.0000 tilt=0.60
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.770000) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-2.464674) return 0.6000; // lift=+0.097 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=1.562734) return 0.6000; // lift=+0.090 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-6.870682) return 0.6000; // lift=+0.077 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=0.720000) return 0.6000; // lift=+0.098 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCSlope" && value>=0.132700) return 0.6000; // lift=+0.084 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.643500) return 0.6000; // lift=+0.120 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST" && feature=="vpVAH" && value<=0.516763) return 0.6000; // lift=+0.077 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-1.275687) return 0.7000; // lift=+0.052 p=0.0000 tilt=0.70
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=0.129000) return 0.7000; // lift=+0.060 p=0.0000 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpPOC" && value<=-0.680165) return 0.6000; // lift=+0.080 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpVAH" && value<=0.112456) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpVAL" && value<=-1.548346) return 0.6000; // lift=+0.080 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-2.326342) return 0.6000; // lift=+0.073 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=1.590398) return 0.6000; // lift=+0.080 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=0.720000) return 0.6000; // lift=+0.093 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpDevPOCSlope" && value>=0.115400) return 0.6000; // lift=+0.080 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.749000) return 0.6000; // lift=+0.070 p=0.0000 tilt=0.60
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.169050) return 0.7000; // lift=+0.063 p=0.0000 tilt=0.70
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL" && feature=="vpLTTransitionScore" && value>=0.080000) return 0.6000; // lift=+0.132 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL" && feature=="vpLTBalanceStability" && value<=0.920000) return 0.6000; // lift=+0.132 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpPOC" && value<=-0.020064) return 0.6000; // lift=+0.123 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpPriceVsPOC" && value>=-0.046300) return 0.6000; // lift=+0.113 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=-0.192732) return 0.6000; // lift=+0.123 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=0.383100) return 0.6000; // lift=+0.138 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpDevPOCSlope" && value>=0.013900) return 0.6000; // lift=+0.133 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="auctTradeQuality" && value>=0.398000) return 0.6000; // lift=+0.107 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=-0.510000) return 0.6000; // lift=+0.123 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=-0.034750) return 0.6000; // lift=+0.121 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.000000) return 0.6000; // lift=+0.167 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=-0.004850) return 0.6000; // lift=+0.172 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-0.382261) return 0.6000; // lift=+0.192 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-0.816332) return 0.6000; // lift=+0.176 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-5.874580) return 0.6000; // lift=+0.130 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=0.000000) return 0.6000; // lift=+0.175 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCSlope" && value>=-0.002300) return 0.6000; // lift=+0.176 p=0.0000 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="auctTradeQuality" && value>=0.394000) return 0.6000; // lift=+0.119 p=0.0000 tilt=0.60
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.674500) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="liqContext" && value>=0.465300) return 0.6000; // lift=+0.076 p=0.0000 tilt=0.60
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.698000) return 0.6000; // lift=+0.100 p=0.0000 tilt=0.60
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.213000) return 0.6000; // lift=+0.074 p=0.0000 tilt=0.60
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.680000) return 0.6000; // lift=+0.084 p=0.0000 tilt=0.60
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.580000) return 0.6000; // lift=+0.185 p=0.0000 tilt=0.60
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.6000; // lift=+0.109 p=0.0000 tilt=0.60
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.664500) return 0.6000; // lift=+0.118 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.319130) return 0.6000; // lift=+0.080 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.504166) return 0.6000; // lift=+0.096 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-1.263569) return 0.6000; // lift=+0.096 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-1.134474) return 0.6000; // lift=+0.096 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.685000) return 0.6000; // lift=+0.098 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=0.114400) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.732000) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.488810) return 0.6000; // lift=+0.096 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-1.284356) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-1.275973) return 0.6000; // lift=+0.119 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=2.877437) return 0.6000; // lift=+0.088 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=0.685000) return 0.6000; // lift=+0.124 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCSlope" && value>=0.108750) return 0.6000; // lift=+0.103 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.737000) return 0.6000; // lift=+0.097 p=0.0000 tilt=0.60
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.615000) return 0.6000; // lift=+0.103 p=0.0000 tilt=0.60
   if(symbol=="JPMm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.662000) return 0.6000; // lift=+0.126 p=0.0000 tilt=0.60
   if(symbol=="JPMm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.723000) return 0.6000; // lift=+0.096 p=0.0000 tilt=0.60
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpPOC" && value<=-0.230845) return 0.6000; // lift=+0.093 p=0.0000 tilt=0.60
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpPriceVsPOC" && value>=-0.027550) return 0.6000; // lift=+0.093 p=0.0000 tilt=0.60
   if(symbol=="JPMm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.688000) return 0.6000; // lift=+0.111 p=0.0000 tilt=0.60
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL" && feature=="auctTradeQuality" && value>=0.385000) return 0.6000; // lift=+0.084 p=0.0000 tilt=0.60
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.633000) return 0.6000; // lift=+0.156 p=0.0000 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpBestHVNScore" && value>=0.742000) return 0.7000; // lift=+0.055 p=0.0020 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.681000) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.685000) return 0.7000; // lift=+0.049 p=0.0020 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.054 p=0.0020 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.257000) return 0.7000; // lift=+0.067 p=0.0020 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.282000) return 0.7000; // lift=+0.062 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="msContext" && value>=0.429625) return 0.7000; // lift=+0.043 p=0.0020 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.749000) return 0.7000; // lift=+0.041 p=0.0020 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.356000) return 0.7000; // lift=+0.034 p=0.0020 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="vpDistToHVN" && value<=0.109000) return 0.7500; // lift=+0.029 p=0.0020 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.691000) return 0.6000; // lift=+0.093 p=0.0020 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-0.000098) return 0.7000; // lift=+0.042 p=0.0020 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.039 p=0.0020 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="smZoneQuality" && value>=0.854500) return 0.7000; // lift=+0.038 p=0.0020 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.044 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURJPYm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.322833) return 0.7000; // lift=+0.040 p=0.0020 tilt=0.70
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="auctHVNStrength" && value<=0.866000) return 0.7500; // lift=+0.031 p=0.0020 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.318833) return 0.7500; // lift=+0.033 p=0.0020 tilt=0.75
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctBalance" && value<=0.642000) return 0.7000; // lift=+0.056 p=0.0020 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.439000) return 0.7000; // lift=+0.036 p=0.0020 tilt=0.70
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.000743) return 0.7000; // lift=+0.035 p=0.0020 tilt=0.70
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.368000) return 0.7500; // lift=+0.028 p=0.0020 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURCADm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.304000) return 0.7000; // lift=+0.054 p=0.0020 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.483500) return 0.7000; // lift=+0.050 p=0.0020 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.283000) return 0.7000; // lift=+0.057 p=0.0020 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.691500) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=0.790000) return 0.7000; // lift=+0.040 p=0.0020 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpMigrationScore" && value>=0.790000) return 0.7000; // lift=+0.041 p=0.0020 tilt=0.70
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.054 p=0.0020 tilt=0.70
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.466000) return 0.7000; // lift=+0.067 p=0.0020 tilt=0.70
   if(symbol=="USDCHFm" && setup=="PULLBACK" && feature=="atrProxy" && value>=97.600000) return 0.6000; // lift=+0.074 p=0.0020 tilt=0.60
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=8.177936) return 0.7000; // lift=+0.056 p=0.0020 tilt=0.70
   if(symbol=="US30m" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.908000) return 0.7000; // lift=+0.065 p=0.0020 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=7.310382) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="vpMigrationScore" && value>=0.790000) return 0.7000; // lift=+0.056 p=0.0020 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.393000) return 0.7000; // lift=+0.051 p=0.0020 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="msCompression" && value>=0.742500) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   if(symbol=="US30m" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationScore" && value>=0.755000) return 0.6000; // lift=+0.088 p=0.0020 tilt=0.60
   if(symbol=="US30m" && setup=="SWEEP_REVERSAL" && feature=="auctContinuation" && value>=0.226000) return 0.6000; // lift=+0.080 p=0.0020 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="US30m" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.305833) return 0.6000; // lift=+0.087 p=0.0020 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.003000) return 0.7000; // lift=+0.050 p=0.0020 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.012498) return 0.7000; // lift=+0.063 p=0.0020 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="auctRegimeConf" && value<=0.698000) return 0.7000; // lift=+0.036 p=0.0020 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.057 p=0.0020 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.294700) return 0.7000; // lift=+0.065 p=0.0020 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpBestHVNScore" && value>=0.745000) return 0.7000; // lift=+0.036 p=0.0020 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpPOC" && value<=-0.159375) return 0.7000; // lift=+0.054 p=0.0020 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.230000) return 0.6000; // lift=+0.069 p=0.0020 tilt=0.60
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.354000) return 0.7500; // lift=+0.028 p=0.0020 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="smContext" && value<=0.111800) return 0.7000; // lift=+0.064 p=0.0020 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="vpDistToLVN" && value<=0.333000) return 0.7500; // lift=+0.029 p=0.0020 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.003000) return 0.7500; // lift=+0.030 p=0.0020 tilt=0.75
   if(symbol=="USOILm" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=369.800000) return 0.7000; // lift=+0.045 p=0.0020 tilt=0.70
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=-0.137986) return 0.6000; // lift=+0.073 p=0.0020 tilt=0.60
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationScore" && value>=0.755000) return 0.6000; // lift=+0.074 p=0.0020 tilt=0.60
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.662000) return 0.6000; // lift=+0.070 p=0.0020 tilt=0.60
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="auctContinuation" && value>=0.226000) return 0.6000; // lift=+0.074 p=0.0020 tilt=0.60
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="auctReversalRisk" && value<=0.152000) return 0.6000; // lift=+0.074 p=0.0020 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.321667) return 0.6000; // lift=+0.082 p=0.0020 tilt=0.60
   if(symbol=="XAUGBPm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.493650) return 0.7500; // lift=+0.031 p=0.0020 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=-0.190881) return 0.7000; // lift=+0.053 p=0.0020 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.166150) return 0.7000; // lift=+0.053 p=0.0020 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.303600) return 0.7000; // lift=+0.035 p=0.0020 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.067 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.324333) return 0.7500; // lift=+0.032 p=0.0020 tilt=0.75
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.061 p=0.0020 tilt=0.70
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="auctLVNStrength" && value<=0.910000) return 0.7000; // lift=+0.056 p=0.0020 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-0.315049) return 0.7000; // lift=+0.036 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="msContext" && value>=0.506625) return 0.7000; // lift=+0.036 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="smContext" && value<=0.375800) return 0.7000; // lift=+0.043 p=0.0020 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.073522) return 0.7000; // lift=+0.040 p=0.0020 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.357000) return 0.7000; // lift=+0.044 p=0.0020 tilt=0.70
   if(symbol=="US500m" && setup=="SWEEP_REVERSAL" && feature=="auctReversalRisk" && value<=0.166000) return 0.6000; // lift=+0.072 p=0.0020 tilt=0.60
   if(symbol=="US500m" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.370000) return 0.7000; // lift=+0.051 p=0.0020 tilt=0.70
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="auctExpReward" && value<=0.711500) return 0.7000; // lift=+0.054 p=0.0020 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7000; // lift=+0.065 p=0.0020 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="BREAKOUT" && feature=="atrProxy" && value>=107.100000) return 0.7000; // lift=+0.052 p=0.0020 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="PULLBACK" && feature=="atrProxy" && value>=107.950000) return 0.7000; // lift=+0.054 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPCHFm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.316167) return 0.6000; // lift=+0.080 p=0.0020 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.469000) return 0.7000; // lift=+0.044 p=0.0020 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.053 p=0.0020 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.478000) return 0.7000; // lift=+0.057 p=0.0020 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.044 p=0.0020 tilt=0.70
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.408000) return 0.7000; // lift=+0.051 p=0.0020 tilt=0.70
   if(symbol=="USDCADm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.688000) return 0.7000; // lift=+0.040 p=0.0020 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.721000) return 0.7000; // lift=+0.058 p=0.0020 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.032185) return 0.7000; // lift=+0.057 p=0.0020 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="vpPriceVsPOC" && value>=0.178800) return 0.7000; // lift=+0.052 p=0.0020 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=0.008171) return 0.6000; // lift=+0.069 p=0.0020 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-1.080416) return 0.7000; // lift=+0.046 p=0.0020 tilt=0.70
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.058 p=0.0020 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="vpBestHVNScore" && value>=0.714000) return 0.7000; // lift=+0.057 p=0.0020 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.680000) return 0.7000; // lift=+0.064 p=0.0020 tilt=0.70
   if(symbol=="FR40m" && setup=="NAKED_POC" && feature=="auctAcceptance" && value>=0.373000) return 0.6000; // lift=+0.080 p=0.0020 tilt=0.60
   if(symbol=="FR40m" && setup=="NAKED_POC" && feature=="auctExhaustion" && value<=0.288000) return 0.6000; // lift=+0.073 p=0.0020 tilt=0.60
   if(symbol=="FR40m" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.703500) return 0.6000; // lift=+0.088 p=0.0020 tilt=0.60
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.615000) return 0.7000; // lift=+0.051 p=0.0020 tilt=0.70
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=0.424326) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.284000) return 0.7000; // lift=+0.053 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.315167) return 0.7000; // lift=+0.048 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="liqContext" && value>=0.465600) return 0.7000; // lift=+0.047 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.312150) return 0.7000; // lift=+0.047 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpPOC" && value<=-0.452111) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAL" && value<=-6.462039) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpDistCompPOC" && value>=0.020000) return 0.7000; // lift=+0.065 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.065 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctExpReward" && value<=0.923000) return 0.7000; // lift=+0.053 p=0.0020 tilt=0.70
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.392000) return 0.7000; // lift=+0.036 p=0.0020 tilt=0.70
   if(symbol=="XAUEURm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.400000) return 0.7500; // lift=+0.029 p=0.0020 tilt=0.75
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="vpVAL" && value<=-0.131990) return 0.7000; // lift=+0.037 p=0.0020 tilt=0.70
   if(symbol=="XAUEURm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.376700) return 0.7000; // lift=+0.035 p=0.0020 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpPOC" && value<=-0.182000) return 0.7000; // lift=+0.039 p=0.0020 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpDailyPOC" && value<=-0.299080) return 0.7000; // lift=+0.046 p=0.0020 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompPOC" && value<=-0.366415) return 0.7000; // lift=+0.039 p=0.0020 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistCompPOC" && value>=0.003000) return 0.7000; // lift=+0.041 p=0.0020 tilt=0.70
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.010797) return 0.6000; // lift=+0.076 p=0.0020 tilt=0.60
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpDistToHVN" && value<=0.099500) return 0.6000; // lift=+0.077 p=0.0020 tilt=0.60
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.004375) return 0.7000; // lift=+0.037 p=0.0020 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="auctExpReward" && value<=1.064000) return 0.7000; // lift=+0.034 p=0.0020 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=0.004253) return 0.7000; // lift=+0.045 p=0.0020 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-0.002427) return 0.7000; // lift=+0.046 p=0.0020 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.418500) return 0.7000; // lift=+0.042 p=0.0020 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.682000) return 0.7000; // lift=+0.046 p=0.0020 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpVAH" && value<=0.000537) return 0.7000; // lift=+0.038 p=0.0020 tilt=0.70
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.664000) return 0.7000; // lift=+0.059 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="bosQuality")
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="bosQuality" && value>=0.000000) return 0.6000; // lift=+0.193 p=0.0020 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.6000; // lift=+0.079 p=0.0020 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpPOC" && value<=-0.000268) return 0.7000; // lift=+0.057 p=0.0020 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.603000) return 0.6000; // lift=+0.108 p=0.0020 tilt=0.60
   if(symbol=="XPTUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.649000) return 0.7000; // lift=+0.037 p=0.0020 tilt=0.70
   if(symbol=="XPTUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7500; // lift=+0.030 p=0.0020 tilt=0.75
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="vpPriceVsPOC" && value>=0.211000) return 0.7000; // lift=+0.034 p=0.0020 tilt=0.70
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=0.000696) return 0.7000; // lift=+0.041 p=0.0020 tilt=0.70
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-0.006387) return 0.7500; // lift=+0.031 p=0.0020 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="vpBestHVNScore" && value>=0.739000) return 0.7500; // lift=+0.029 p=0.0020 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="AAPLm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.318500) return 0.7000; // lift=+0.055 p=0.0020 tilt=0.70
   if(symbol=="NVDAm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.040354) return 0.7000; // lift=+0.062 p=0.0020 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NVDAm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.317583) return 0.7000; // lift=+0.052 p=0.0020 tilt=0.70
   if(symbol=="NVDAm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.141100) return 0.6000; // lift=+0.089 p=0.0020 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NVDAm" && setup=="NAKED_POC" && feature=="ofContext" && value<=0.306500) return 0.6000; // lift=+0.087 p=0.0020 tilt=0.60
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.329500) return 0.7000; // lift=+0.052 p=0.0020 tilt=0.70
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.403000) return 0.7000; // lift=+0.052 p=0.0020 tilt=0.70
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=56.400000) return 0.7000; // lift=+0.067 p=0.0020 tilt=0.70
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-2.438895) return 0.7000; // lift=+0.060 p=0.0020 tilt=0.70
   if(symbol=="MSFTm" && setup=="NAKED_POC" && feature=="vpDevPOCDir" && value>=-0.435700) return 0.7000; // lift=+0.055 p=0.0020 tilt=0.70
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-0.383785) return 0.6000; // lift=+0.133 p=0.0020 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-5.612172) return 0.6000; // lift=+0.103 p=0.0020 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=3.694846) return 0.6000; // lift=+0.124 p=0.0020 tilt=0.60
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompVAL" && value<=-8.401755) return 0.6000; // lift=+0.111 p=0.0020 tilt=0.60
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK" && feature=="auctBalance" && value<=0.624000) return 0.6000; // lift=+0.111 p=0.0020 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK" && feature=="smContext" && value<=0.373000) return 0.6000; // lift=+0.111 p=0.0020 tilt=0.60
   if(symbol=="EBAYm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.729000) return 0.6000; // lift=+0.103 p=0.0020 tilt=0.60
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.125500) return 0.6000; // lift=+0.118 p=0.0020 tilt=0.60
   if(symbol=="EBAYm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.610000) return 0.6000; // lift=+0.102 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.756000) return 0.6000; // lift=+0.079 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpVAH" && value<=0.486168) return 0.6000; // lift=+0.076 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpThinnessRatio" && value>=0.500000) return 0.6000; // lift=+0.091 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpDevPOCSlope" && value>=0.094850) return 0.6000; // lift=+0.091 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpPriceVsPOC" && value>=0.082500) return 0.6000; // lift=+0.076 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-7.224941) return 0.6000; // lift=+0.080 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.354000) return 0.6000; // lift=+0.089 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-1.682328) return 0.6000; // lift=+0.080 p=0.0020 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="GOOGLm" && setup=="MEAN_REVERSION" && feature=="smContext" && value<=0.388400) return 0.6000; // lift=+0.076 p=0.0020 tilt=0.60
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="vpThinnessRatio" && value>=0.450000) return 0.6000; // lift=+0.091 p=0.0020 tilt=0.60
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.688500) return 0.7000; // lift=+0.057 p=0.0020 tilt=0.70
   if(symbol=="JPMm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.627000) return 0.6000; // lift=+0.084 p=0.0020 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=-2.808649) return 0.7000; // lift=+0.064 p=0.0020 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.680000) return 0.7000; // lift=+0.064 p=0.0020 tilt=0.70
   if(symbol=="METAm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.363000) return 0.6000; // lift=+0.070 p=0.0020 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.330500) return 0.7000; // lift=+0.043 p=0.0040 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="vpLTTrendDuration" && value<=14.600000) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.500750) return 0.7500; // lift=+0.032 p=0.0040 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpCompVAH" && value<=4.032053) return 0.7000; // lift=+0.064 p=0.0040 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="liqContext" && value>=0.458500) return 0.7000; // lift=+0.060 p=0.0040 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.636146) return 0.7000; // lift=+0.047 p=0.0040 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.683000) return 0.7000; // lift=+0.046 p=0.0040 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.697000) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.375000) return 0.7000; // lift=+0.036 p=0.0040 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-0.000055) return 0.7000; // lift=+0.036 p=0.0040 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-0.000177) return 0.7000; // lift=+0.038 p=0.0040 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.003171) return 0.7000; // lift=+0.038 p=0.0040 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="auctContinuation" && value>=0.226000) return 0.7000; // lift=+0.044 p=0.0040 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.382000) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.036 p=0.0040 tilt=0.70
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.118 p=0.0040 tilt=0.60
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.094 p=0.0040 tilt=0.60
   if(symbol=="EURJPYm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.102100) return 0.7500; // lift=+0.031 p=0.0040 tilt=0.75
   if(symbol=="EURUSDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.038 p=0.0040 tilt=0.70
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.682000) return 0.7000; // lift=+0.053 p=0.0040 tilt=0.70
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.362000) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=0.000833) return 0.7500; // lift=+0.031 p=0.0040 tilt=0.75
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCDir" && value>=0.755000) return 0.7500; // lift=+0.025 p=0.0040 tilt=0.75
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpMigrationScore" && value>=0.755000) return 0.7500; // lift=+0.025 p=0.0040 tilt=0.75
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.391000) return 0.7500; // lift=+0.031 p=0.0040 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="liqContext" && value>=0.467700) return 0.7500; // lift=+0.028 p=0.0040 tilt=0.75
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.408000) return 0.7000; // lift=+0.056 p=0.0040 tilt=0.70
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.052407) return 0.7000; // lift=+0.050 p=0.0040 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.037458) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.148000) return 0.6000; // lift=+0.071 p=0.0040 tilt=0.60
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.427000) return 0.7000; // lift=+0.066 p=0.0040 tilt=0.70
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctReversalRisk" && value<=0.147000) return 0.7000; // lift=+0.062 p=0.0040 tilt=0.70
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=-0.029666) return 0.7000; // lift=+0.052 p=0.0040 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.044994) return 0.7000; // lift=+0.064 p=0.0040 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPJPYm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.309833) return 0.7000; // lift=+0.051 p=0.0040 tilt=0.70
   if(symbol=="USDCHFm" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=97.600000) return 0.7000; // lift=+0.066 p=0.0040 tilt=0.70
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.001050) return 0.7000; // lift=+0.058 p=0.0040 tilt=0.70
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="auctBalance" && value<=0.623000) return 0.6000; // lift=+0.080 p=0.0040 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.131613) return 0.7000; // lift=+0.040 p=0.0040 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="auctExhaustion" && value<=0.233000) return 0.7000; // lift=+0.040 p=0.0040 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="vpDistToLVN" && value<=0.306000) return 0.7000; // lift=+0.055 p=0.0040 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.058 p=0.0040 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.387000) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpCompVAH" && value<=0.413509) return 0.6000; // lift=+0.071 p=0.0040 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpCompVAL" && value<=-0.326242) return 0.6000; // lift=+0.071 p=0.0040 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.221950) return 0.6000; // lift=+0.075 p=0.0040 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="vpBestHVNScore" && value>=0.745000) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.228000) return 0.7000; // lift=+0.057 p=0.0040 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.687000) return 0.7000; // lift=+0.049 p=0.0040 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.416000) return 0.7000; // lift=+0.055 p=0.0040 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.074116) return 0.7000; // lift=+0.045 p=0.0040 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.015402) return 0.7000; // lift=+0.055 p=0.0040 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.046 p=0.0040 tilt=0.70
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="auctFailure" && value<=0.250000) return 0.7000; // lift=+0.068 p=0.0040 tilt=0.70
   if(symbol=="USOILm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.272000) return 0.7000; // lift=+0.054 p=0.0040 tilt=0.70
   if(symbol=="USOILm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.384000) return 0.7000; // lift=+0.054 p=0.0040 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="USOILm" && setup=="PULLBACK" && feature=="smContext" && value<=0.401200) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>=0.351300) return 0.7000; // lift=+0.044 p=0.0040 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.000437) return 0.7000; // lift=+0.053 p=0.0040 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.416500) return 0.7500; // lift=+0.033 p=0.0040 tilt=0.75
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.074 p=0.0040 tilt=0.60
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="auctHVNStrength" && value<=0.833000) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.149200) return 0.7000; // lift=+0.034 p=0.0040 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="smContext" && value<=0.375400) return 0.7000; // lift=+0.041 p=0.0040 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="vpLTPOCVelocity" && value>=11480.496500) return 0.7000; // lift=+0.054 p=0.0040 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.054 p=0.0040 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.324000) return 0.7000; // lift=+0.047 p=0.0040 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpBestHVNScore" && value>=0.732000) return 0.7000; // lift=+0.052 p=0.0040 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.039 p=0.0040 tilt=0.70
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.281000) return 0.7000; // lift=+0.051 p=0.0040 tilt=0.70
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="auctHVNStrength" && value<=0.845000) return 0.7000; // lift=+0.052 p=0.0040 tilt=0.70
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.383000) return 0.7000; // lift=+0.049 p=0.0040 tilt=0.70
   if(symbol=="USTECm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.727000) return 0.7000; // lift=+0.046 p=0.0040 tilt=0.70
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.369000) return 0.7000; // lift=+0.048 p=0.0040 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-2.652192) return 0.7000; // lift=+0.049 p=0.0040 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.653500) return 0.6000; // lift=+0.069 p=0.0040 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.379000) return 0.6000; // lift=+0.088 p=0.0040 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="NAKED_POC" && feature=="spreadToATR" && value>=0.021400) return 0.6000; // lift=+0.112 p=0.0040 tilt=0.60
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.039 p=0.0040 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="atrProxy" && value>=1871.150000) return 0.7000; // lift=+0.043 p=0.0040 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=0.063800) return 0.7000; // lift=+0.053 p=0.0040 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpPriceVsPOC" && value>=0.081700) return 0.7000; // lift=+0.053 p=0.0040 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT" && feature=="vpDistCompPOC" && value>=0.023000) return 0.7500; // lift=+0.027 p=0.0040 tilt=0.75
   if(symbol=="STOXX50m" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.748000) return 0.7500; // lift=+0.028 p=0.0040 tilt=0.75
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.048827) return 0.7000; // lift=+0.060 p=0.0040 tilt=0.70
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.394000) return 0.7000; // lift=+0.056 p=0.0040 tilt=0.70
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=-0.195627) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7000; // lift=+0.049 p=0.0040 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.156500) return 0.7000; // lift=+0.054 p=0.0040 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURAUDm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.321667) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=0.001579) return 0.7500; // lift=+0.032 p=0.0040 tilt=0.75
   if(symbol=="EURCHFm" && setup=="MEAN_REVERSION" && feature=="auctReversalRisk" && value<=0.140000) return 0.6000; // lift=+0.069 p=0.0040 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EURCHFm" && setup=="MEAN_REVERSION" && feature=="liqContext" && value>=0.463000) return 0.6000; // lift=+0.072 p=0.0040 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.366000) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.105 p=0.0040 tilt=0.60
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.000672) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpPriceVsPOC" && value>=-0.055900) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-0.002512) return 0.7000; // lift=+0.037 p=0.0040 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.000626) return 0.7000; // lift=+0.035 p=0.0040 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.368000) return 0.7000; // lift=+0.035 p=0.0040 tilt=0.70
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.000724) return 0.7500; // lift=+0.031 p=0.0040 tilt=0.75
   if(symbol=="NVDAm" && setup=="NAKED_POC" && feature=="ofFlowIntensity" && value<=0.335000) return 0.6000; // lift=+0.071 p=0.0040 tilt=0.60
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.261000) return 0.7000; // lift=+0.052 p=0.0040 tilt=0.70
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.705000) return 0.7000; // lift=+0.066 p=0.0040 tilt=0.70
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-1.891098) return 0.7000; // lift=+0.057 p=0.0040 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=0.118450) return 0.6000; // lift=+0.077 p=0.0040 tilt=0.60
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-1.859528) return 0.7000; // lift=+0.060 p=0.0040 tilt=0.70
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-6.810913) return 0.7000; // lift=+0.052 p=0.0040 tilt=0.70
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpVAL" && value<=-0.944297) return 0.6000; // lift=+0.103 p=0.0040 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=4.053890) return 0.6000; // lift=+0.103 p=0.0040 tilt=0.60
   if(symbol=="LMTm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompPOC" && value<=-0.588567) return 0.6000; // lift=+0.135 p=0.0040 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.6000; // lift=+0.127 p=0.0040 tilt=0.60
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="auctExpReward" && value<=0.817000) return 0.7000; // lift=+0.053 p=0.0040 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=0.669100) return 0.6000; // lift=+0.076 p=0.0040 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=3.070171) return 0.6000; // lift=+0.072 p=0.0040 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.390765) return 0.6000; // lift=+0.088 p=0.0040 tilt=0.60
   if(symbol=="GOOGLm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.783000) return 0.6000; // lift=+0.083 p=0.0040 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="liqContext" && value>=0.424600) return 0.6000; // lift=+0.086 p=0.0040 tilt=0.60
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK" && feature=="auctReversalRisk" && value<=0.140000) return 0.6000; // lift=+0.091 p=0.0040 tilt=0.60
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-2.439014) return 0.7000; // lift=+0.046 p=0.0040 tilt=0.70
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="auctTradeQuality" && value>=0.393500) return 0.7000; // lift=+0.047 p=0.0040 tilt=0.70
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.358000) return 0.7000; // lift=+0.047 p=0.0040 tilt=0.70
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpDailyPOC" && value<=-0.409381) return 0.6000; // lift=+0.093 p=0.0040 tilt=0.60
   if(symbol=="METAm" && setup=="BREAKOUT_RETEST" && feature=="auctLVNStrength" && value<=0.912000) return 0.7000; // lift=+0.057 p=0.0040 tilt=0.70
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.304000) return 0.6000; // lift=+0.075 p=0.0040 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.122500) return 0.7000; // lift=+0.057 p=0.0060 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.042 p=0.0060 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="auctContinuation" && value>=0.226000) return 0.7500; // lift=+0.028 p=0.0060 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=0.000047) return 0.7000; // lift=+0.036 p=0.0060 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="NAKED_POC" && feature=="vpLTPOCVelocity" && value>=131.076100) return 0.6000; // lift=+0.085 p=0.0060 tilt=0.60
   if(symbol=="AUDUSDm" && setup=="NAKED_POC" && feature=="vpLTPOCMigration" && value>=0.500000) return 0.6000; // lift=+0.085 p=0.0060 tilt=0.60
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION" && feature=="auctExpReward" && value<=1.135000) return 0.7000; // lift=+0.044 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.318167) return 0.7000; // lift=+0.039 p=0.0060 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpDistToHVN" && value<=0.159000) return 0.7500; // lift=+0.030 p=0.0060 tilt=0.75
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="auctExpReward" && value<=0.988000) return 0.7500; // lift=+0.030 p=0.0060 tilt=0.75
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.419000) return 0.7500; // lift=+0.031 p=0.0060 tilt=0.75
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.676000) return 0.7000; // lift=+0.062 p=0.0060 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="MEAN_REVERSION" && feature=="vpCompPOC" && value<=0.056385) return 0.7000; // lift=+0.047 p=0.0060 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION" && feature=="vpDistToHVN" && value<=0.157000) return 0.7000; // lift=+0.036 p=0.0060 tilt=0.70
   if(symbol=="USDCHFm" && setup=="NAKED_POC" && feature=="auctAcceptance" && value>=0.425500) return 0.6000; // lift=+0.128 p=0.0060 tilt=0.60
   if(symbol=="USDCHFm" && setup=="NAKED_POC" && feature=="auctTargetProb" && value<=0.385000) return 0.6000; // lift=+0.128 p=0.0060 tilt=0.60
   if(symbol=="USDCHFm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-0.000456) return 0.7000; // lift=+0.044 p=0.0060 tilt=0.70
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.6000; // lift=+0.076 p=0.0060 tilt=0.60
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-72.289988) return 0.7000; // lift=+0.048 p=0.0060 tilt=0.70
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="vpDistCompPOC" && value>=0.265000) return 0.7000; // lift=+0.054 p=0.0060 tilt=0.70
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="auctExpReward" && value<=0.634500) return 0.7000; // lift=+0.048 p=0.0060 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.232000) return 0.7000; // lift=+0.035 p=0.0060 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.388000) return 0.7000; // lift=+0.051 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.334917) return 0.7000; // lift=+0.054 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="smContext" && value<=0.380400) return 0.7000; // lift=+0.062 p=0.0060 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION" && feature=="auctHVNStrength" && value<=0.839000) return 0.7000; // lift=+0.034 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION" && feature=="smContext" && value<=0.114600) return 0.7000; // lift=+0.042 p=0.0060 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.307900) return 0.7000; // lift=+0.050 p=0.0060 tilt=0.70
   if(symbol=="USOILm" && setup=="NAKED_POC" && feature=="ofFlowIntensity" && value<=0.367000) return 0.6000; // lift=+0.082 p=0.0060 tilt=0.60
   if(symbol=="USOILm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.642500) return 0.7000; // lift=+0.063 p=0.0060 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.247954) return 0.7000; // lift=+0.046 p=0.0060 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=0.162350) return 0.7000; // lift=+0.040 p=0.0060 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.703500) return 0.7000; // lift=+0.035 p=0.0060 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.143892) return 0.7000; // lift=+0.036 p=0.0060 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.003000) return 0.7000; // lift=+0.036 p=0.0060 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.236000) return 0.7000; // lift=+0.035 p=0.0060 tilt=0.70
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.6000; // lift=+0.072 p=0.0060 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="US500m" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.319167) return 0.7000; // lift=+0.049 p=0.0060 tilt=0.70
   if(symbol=="US500m" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.060200) return 0.7000; // lift=+0.040 p=0.0060 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.462500) return 0.6000; // lift=+0.071 p=0.0060 tilt=0.60
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="auctContinuation" && value>=0.229000) return 0.7000; // lift=+0.049 p=0.0060 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.204650) return 0.7000; // lift=+0.057 p=0.0060 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationConf" && value>=0.825000) return 0.7000; // lift=+0.040 p=0.0060 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.040 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPAUDm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.322167) return 0.7000; // lift=+0.040 p=0.0060 tilt=0.70
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.000816) return 0.7000; // lift=+0.041 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.304500) return 0.7000; // lift=+0.053 p=0.0060 tilt=0.70
   if(symbol=="USTECm" && setup=="MEAN_REVERSION" && feature=="vpPriceVsPOC" && value>=-0.644700) return 0.7000; // lift=+0.064 p=0.0060 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.359000) return 0.7000; // lift=+0.048 p=0.0060 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.279500) return 0.7000; // lift=+0.059 p=0.0060 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="NAKED_POC" && feature=="vpLTPOCMigration" && value>=0.000000) return 0.6000; // lift=+0.121 p=0.0060 tilt=0.60
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.899000) return 0.7000; // lift=+0.045 p=0.0060 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.449733) return 0.7000; // lift=+0.038 p=0.0060 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.749000) return 0.7000; // lift=+0.045 p=0.0060 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.359000) return 0.7000; // lift=+0.048 p=0.0060 tilt=0.70
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK" && feature=="vpPOC" && value<=-0.613085) return 0.7000; // lift=+0.049 p=0.0060 tilt=0.70
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK" && feature=="vpPriceVsPOC" && value>=0.255500) return 0.7000; // lift=+0.049 p=0.0060 tilt=0.70
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.023000) return 0.7500; // lift=+0.032 p=0.0060 tilt=0.75
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.346650) return 0.7500; // lift=+0.029 p=0.0060 tilt=0.75
   if(symbol=="STOXX50m" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.399000) return 0.7000; // lift=+0.047 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAUEURm" && setup=="PULLBACK" && feature=="msContext" && value>=0.526000) return 0.7500; // lift=+0.028 p=0.0060 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURAUDm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.312000) return 0.7000; // lift=+0.035 p=0.0060 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpBestHVNScore" && value>=0.736000) return 0.7000; // lift=+0.046 p=0.0060 tilt=0.70
   if(symbol=="EURCHFm" && setup=="SWEEP_REVERSAL" && feature=="auctLVNStrength" && value<=0.901000) return 0.6000; // lift=+0.081 p=0.0060 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURCHFm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.318167) return 0.7000; // lift=+0.047 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPUSDm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.317833) return 0.7000; // lift=+0.035 p=0.0060 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.682000) return 0.7000; // lift=+0.039 p=0.0060 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="GBPUSDm" && setup=="PULLBACK" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.122 p=0.0060 tilt=0.60
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.034 p=0.0060 tilt=0.70
   if(symbol=="GBPCADm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.683000) return 0.7000; // lift=+0.035 p=0.0060 tilt=0.70
   if(symbol=="NVDAm" && setup=="NAKED_POC" && feature=="spreadToATR" && value>=0.138600) return 0.6000; // lift=+0.078 p=0.0060 tilt=0.60
   if(symbol=="NFLXm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.506300) return 0.7000; // lift=+0.053 p=0.0060 tilt=0.70
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.720000) return 0.7000; // lift=+0.053 p=0.0060 tilt=0.70
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK" && feature=="vpPriceVsPOC" && value>=0.487800) return 0.6000; // lift=+0.069 p=0.0060 tilt=0.60
   if(symbol=="LMTm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompVAL" && value<=-5.552581) return 0.6000; // lift=+0.115 p=0.0060 tilt=0.60
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-4.450267) return 0.7000; // lift=+0.058 p=0.0060 tilt=0.70
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.401000) return 0.7000; // lift=+0.061 p=0.0060 tilt=0.70
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.6000; // lift=+0.115 p=0.0060 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpDistToHVN" && value<=0.241500) return 0.6000; // lift=+0.068 p=0.0060 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=-1.259592) return 0.6000; // lift=+0.068 p=0.0060 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-1.622773) return 0.6000; // lift=+0.068 p=0.0060 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="auctReversalRisk" && value<=0.140000) return 0.7000; // lift=+0.061 p=0.0060 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.729000) return 0.6000; // lift=+0.069 p=0.0060 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpBestHVNScore" && value>=0.701000) return 0.6000; // lift=+0.072 p=0.0060 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpDistToLVN" && value<=0.440000) return 0.7000; // lift=+0.065 p=0.0060 tilt=0.70
   if(symbol=="METAm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.171000) return 0.7000; // lift=+0.035 p=0.0060 tilt=0.70
   if(symbol=="METAm" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.180000) return 0.7000; // lift=+0.054 p=0.0060 tilt=0.70
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.375000) return 0.6000; // lift=+0.075 p=0.0060 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.567465) return 0.7000; // lift=+0.055 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="msContext" && value>=0.502500) return 0.7500; // lift=+0.028 p=0.0080 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpCompPOC" && value<=0.570954) return 0.7000; // lift=+0.054 p=0.0080 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="vpCompPOC" && value<=0.228659) return 0.7000; // lift=+0.040 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.118 p=0.0080 tilt=0.60
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.508000) return 0.7500; // lift=+0.033 p=0.0080 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-0.003754) return 0.7000; // lift=+0.036 p=0.0080 tilt=0.70
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.670000) return 0.7000; // lift=+0.058 p=0.0080 tilt=0.70
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.687000) return 0.7500; // lift=+0.028 p=0.0080 tilt=0.75
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.153300) return 0.7000; // lift=+0.041 p=0.0080 tilt=0.70
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.050875) return 0.7000; // lift=+0.050 p=0.0080 tilt=0.70
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="auctContinuation" && value>=0.247000) return 0.7000; // lift=+0.049 p=0.0080 tilt=0.70
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTPOCVelocity" && value>=144.693700) return 0.7000; // lift=+0.047 p=0.0080 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-0.699455) return 0.7000; // lift=+0.047 p=0.0080 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7500; // lift=+0.029 p=0.0080 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.322167) return 0.7500; // lift=+0.033 p=0.0080 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpPriceVsPOC" && value>=0.173100) return 0.7500; // lift=+0.031 p=0.0080 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="NAKED_POC" && feature=="ofFlowIntensity" && value<=0.361000) return 0.6000; // lift=+0.080 p=0.0080 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="msContext" && value>=0.499500) return 0.7500; // lift=+0.032 p=0.0080 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.012226) return 0.7000; // lift=+0.055 p=0.0080 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="auctRegimeConf" && value<=0.688000) return 0.7000; // lift=+0.036 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.323667) return 0.7000; // lift=+0.039 p=0.0080 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7500; // lift=+0.032 p=0.0080 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.695500) return 0.7500; // lift=+0.033 p=0.0080 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-0.346541) return 0.7500; // lift=+0.029 p=0.0080 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.028 p=0.0080 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.325000) return 0.7500; // lift=+0.031 p=0.0080 tilt=0.75
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.105881) return 0.7000; // lift=+0.055 p=0.0080 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompVAH" && value<=-0.055928) return 0.7000; // lift=+0.044 p=0.0080 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.687000) return 0.7000; // lift=+0.040 p=0.0080 tilt=0.70
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.369000) return 0.7000; // lift=+0.057 p=0.0080 tilt=0.70
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK" && feature=="auctRegimeConf" && value<=0.725000) return 0.7000; // lift=+0.047 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGEURm" && setup=="BREAKOUT_RETEST" && feature=="smContext" && value<=0.387600) return 0.7000; // lift=+0.048 p=0.0080 tilt=0.70
   if(symbol=="US500m" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.382000) return 0.7000; // lift=+0.061 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.313250) return 0.7000; // lift=+0.062 p=0.0080 tilt=0.70
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="auctLVNStrength" && value<=0.896000) return 0.7000; // lift=+0.040 p=0.0080 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.283000) return 0.7000; // lift=+0.059 p=0.0080 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="NAKED_POC" && feature=="vpDistToHVN" && value<=0.139000) return 0.6000; // lift=+0.126 p=0.0080 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.000027) return 0.7000; // lift=+0.038 p=0.0080 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctTradeQuality" && value>=0.439000) return 0.7000; // lift=+0.044 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="liqContext" && value>=0.433200) return 0.7000; // lift=+0.042 p=0.0080 tilt=0.70
   if(symbol=="USDCADm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.660000) return 0.6000; // lift=+0.100 p=0.0080 tilt=0.60
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.114 p=0.0080 tilt=0.60
   if(symbol=="USDCADm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.417000) return 0.7500; // lift=+0.029 p=0.0080 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.333833) return 0.7000; // lift=+0.049 p=0.0080 tilt=0.70
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.534386) return 0.6000; // lift=+0.083 p=0.0080 tilt=0.60
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.664000) return 0.6000; // lift=+0.075 p=0.0080 tilt=0.60
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="auctLVNStrength" && value<=0.892000) return 0.7000; // lift=+0.051 p=0.0080 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAH" && value<=0.155939) return 0.7000; // lift=+0.057 p=0.0080 tilt=0.70
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="auctExpMoveATR" && value>=2.893000) return 0.7000; // lift=+0.045 p=0.0080 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.763000) return 0.7000; // lift=+0.044 p=0.0080 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.316100) return 0.7500; // lift=+0.028 p=0.0080 tilt=0.75
   if(symbol=="STOXX50m" && setup=="NAKED_POC" && feature=="vpCompPOC" && value<=-0.525026) return 0.7000; // lift=+0.066 p=0.0080 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>=0.323000) return 0.7000; // lift=+0.039 p=0.0080 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.320000) return 0.7000; // lift=+0.041 p=0.0080 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.000012) return 0.7000; // lift=+0.042 p=0.0080 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="smZoneQuality" && value>=0.879000) return 0.7000; // lift=+0.038 p=0.0080 tilt=0.70
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.484000) return 0.7000; // lift=+0.058 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="bosQuality")
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="bosQuality" && value>=0.000000) return 0.6000; // lift=+0.247 p=0.0080 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.056 p=0.0080 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.670000) return 0.7000; // lift=+0.035 p=0.0080 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=0.000617) return 0.7000; // lift=+0.047 p=0.0080 tilt=0.70
   if(symbol=="AAPLm" && setup=="PULLBACK" && feature=="vpLTTransitionScore" && value>=0.092000) return 0.7000; // lift=+0.055 p=0.0080 tilt=0.70
   if(symbol=="AAPLm" && setup=="PULLBACK" && feature=="vpLTBalanceStability" && value<=0.908000) return 0.7000; // lift=+0.055 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="AAPLm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.305000) return 0.7000; // lift=+0.050 p=0.0080 tilt=0.70
   if(symbol=="AAPLm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.709500) return 0.6000; // lift=+0.087 p=0.0080 tilt=0.60
   if(symbol=="NVDAm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.123800) return 0.6000; // lift=+0.072 p=0.0080 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.312500) return 0.7000; // lift=+0.060 p=0.0080 tilt=0.70
   if(symbol=="NVDAm" && setup=="BREAKOUT" && feature=="auctFailure" && value<=0.150000) return 0.7000; // lift=+0.038 p=0.0080 tilt=0.70
   if(symbol=="NVDAm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.123100) return 0.7500; // lift=+0.030 p=0.0080 tilt=0.75
   if(symbol=="MSFTm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.195550) return 0.6000; // lift=+0.079 p=0.0080 tilt=0.60
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.444664) return 0.7000; // lift=+0.044 p=0.0080 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=-1.885013) return 0.7000; // lift=+0.051 p=0.0080 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-6.634466) return 0.7000; // lift=+0.058 p=0.0080 tilt=0.70
   if(symbol=="MSFTm" && setup=="NAKED_POC" && feature=="vpDevPOCSlope" && value>=-0.022450) return 0.7000; // lift=+0.052 p=0.0080 tilt=0.70
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="vpVAH" && value<=0.817017) return 0.6000; // lift=+0.089 p=0.0080 tilt=0.60
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-0.322739) return 0.6000; // lift=+0.097 p=0.0080 tilt=0.60
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7000; // lift=+0.058 p=0.0080 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.318167) return 0.7000; // lift=+0.058 p=0.0080 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="auctLVNStrength" && value<=0.934000) return 0.6000; // lift=+0.070 p=0.0080 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.6000; // lift=+0.073 p=0.0080 tilt=0.60
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.431000) return 0.7000; // lift=+0.055 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.500400) return 0.7500; // lift=+0.028 p=0.0100 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="smZoneQuality" && value>=0.848000) return 0.7500; // lift=+0.034 p=0.0100 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.000107) return 0.7500; // lift=+0.031 p=0.0100 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.000609) return 0.7000; // lift=+0.036 p=0.0100 tilt=0.70
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.144000) return 0.7000; // lift=+0.053 p=0.0100 tilt=0.70
   if(symbol=="EURJPYm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.624000) return 0.7000; // lift=+0.039 p=0.0100 tilt=0.70
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7000; // lift=+0.035 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURCADm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.323667) return 0.7500; // lift=+0.033 p=0.0100 tilt=0.75
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST" && feature=="auctAcceptance" && value>=0.614000) return 0.7500; // lift=+0.026 p=0.0100 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDJPYm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.317833) return 0.7000; // lift=+0.041 p=0.0100 tilt=0.70
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-0.194763) return 0.7000; // lift=+0.035 p=0.0100 tilt=0.70
   if(symbol=="USDJPYm" && setup=="NAKED_POC" && feature=="auctReversalRisk" && value<=0.154500) return 0.7000; // lift=+0.061 p=0.0100 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.380000) return 0.7000; // lift=+0.037 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPJPYm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.322917) return 0.7500; // lift=+0.031 p=0.0100 tilt=0.75
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.153 p=0.0100 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.318333) return 0.7000; // lift=+0.066 p=0.0100 tilt=0.70
   if(symbol=="US30m" && setup=="NAKED_POC" && feature=="auctRegimeConf" && value<=0.702000) return 0.7000; // lift=+0.043 p=0.0100 tilt=0.70
   if(symbol=="US30m" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.732500) return 0.7000; // lift=+0.041 p=0.0100 tilt=0.70
   if(symbol=="US30m" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.748500) return 0.7000; // lift=+0.042 p=0.0100 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-0.697885) return 0.7000; // lift=+0.037 p=0.0100 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.001946) return 0.7000; // lift=+0.034 p=0.0100 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.128344) return 0.7000; // lift=+0.034 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.374750) return 0.7000; // lift=+0.060 p=0.0100 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.142075) return 0.7500; // lift=+0.030 p=0.0100 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.322833) return 0.7500; // lift=+0.033 p=0.0100 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.054 p=0.0100 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.130000) return 0.7000; // lift=+0.045 p=0.0100 tilt=0.70
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.430000) return 0.7000; // lift=+0.059 p=0.0100 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=-0.011906) return 0.7000; // lift=+0.034 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK" && feature=="msContext" && value>=0.535750) return 0.7000; // lift=+0.050 p=0.0100 tilt=0.70
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.028000) return 0.7000; // lift=+0.036 p=0.0100 tilt=0.70
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.091 p=0.0100 tilt=0.60
   if(symbol=="US500m" && setup=="BREAKOUT" && feature=="vpLTTrendDuration" && value<=0.300000) return 0.7000; // lift=+0.042 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="bosQuality")
   if(symbol=="GBPCHFm" && setup=="MEAN_REVERSION" && feature=="bosQuality" && value>=0.000000) return 0.6000; // lift=+0.230 p=0.0100 tilt=0.60
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.048 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.320333) return 0.7000; // lift=+0.046 p=0.0100 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.363500) return 0.7000; // lift=+0.047 p=0.0100 tilt=0.70
   if(symbol=="USDCADm" && setup=="NAKED_POC" && feature=="auctLVNStrength" && value<=0.891000) return 0.6000; // lift=+0.100 p=0.0100 tilt=0.60
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=1881.450000) return 0.7500; // lift=+0.032 p=0.0100 tilt=0.75
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.670000) return 0.7000; // lift=+0.043 p=0.0100 tilt=0.70
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="vpLTTransitionScore" && value>=0.028000) return 0.7000; // lift=+0.043 p=0.0100 tilt=0.70
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="vpLTBalanceStability" && value<=0.972000) return 0.7000; // lift=+0.043 p=0.0100 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="vpVAOverlapRatio" && value<=0.442000) return 0.7000; // lift=+0.043 p=0.0100 tilt=0.70
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=0.237008) return 0.7500; // lift=+0.026 p=0.0100 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.330000) return 0.7500; // lift=+0.024 p=0.0100 tilt=0.75
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.661000) return 0.7000; // lift=+0.048 p=0.0100 tilt=0.70
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="vpLTTrendDuration" && value<=0.300000) return 0.7000; // lift=+0.053 p=0.0100 tilt=0.70
   if(symbol=="XAUEURm" && setup=="BREAKOUT" && feature=="vpDistToHVN" && value<=0.136000) return 0.7500; // lift=+0.022 p=0.0100 tilt=0.75
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.236000) return 0.7500; // lift=+0.026 p=0.0100 tilt=0.75
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.444200) return 0.7500; // lift=+0.026 p=0.0100 tilt=0.75
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=-0.106786) return 0.7500; // lift=+0.032 p=0.0100 tilt=0.75
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.052 p=0.0100 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.676000) return 0.7000; // lift=+0.041 p=0.0100 tilt=0.70
   if(symbol=="EURCHFm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.155000) return 0.7000; // lift=+0.067 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST" && feature=="liqContext" && value>=0.483100) return 0.7000; // lift=+0.060 p=0.0100 tilt=0.70
   if(symbol=="EURGBPm" && setup=="NAKED_POC" && feature=="atrProxy" && value>=60.100000) return 0.6000; // lift=+0.102 p=0.0100 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.318500) return 0.7000; // lift=+0.037 p=0.0100 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpPriceVsPOC" && value>=0.117900) return 0.7000; // lift=+0.047 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPUSDm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.319167) return 0.7500; // lift=+0.032 p=0.0100 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPCADm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.323500) return 0.7500; // lift=+0.020 p=0.0100 tilt=0.75
   if(symbol=="GBPCADm" && setup=="BREAKOUT_RETEST" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.027 p=0.0100 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.390000) return 0.7500; // lift=+0.025 p=0.0100 tilt=0.75
   if(symbol=="AAPLm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.351000) return 0.7000; // lift=+0.060 p=0.0100 tilt=0.70
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.752000) return 0.7000; // lift=+0.060 p=0.0100 tilt=0.70
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.352000) return 0.7000; // lift=+0.060 p=0.0100 tilt=0.70
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK" && feature=="auctLVNStrength" && value<=0.928500) return 0.7000; // lift=+0.058 p=0.0100 tilt=0.70
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.948500) return 0.7000; // lift=+0.041 p=0.0100 tilt=0.70
   if(symbol=="NFLXm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.794500) return 0.7000; // lift=+0.053 p=0.0100 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NFLXm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.320500) return 0.7000; // lift=+0.035 p=0.0100 tilt=0.70
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-1.280419) return 0.7000; // lift=+0.050 p=0.0100 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="vpPriceVsPOC" && value>=0.204200) return 0.7000; // lift=+0.058 p=0.0100 tilt=0.70
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="msCompression" && value>=0.696500) return 0.6000; // lift=+0.091 p=0.0100 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpVAL" && value<=-1.372051) return 0.6000; // lift=+0.068 p=0.0100 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.120600) return 0.6000; // lift=+0.073 p=0.0100 tilt=0.60
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-7.132530) return 0.7000; // lift=+0.065 p=0.0100 tilt=0.70
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="vpDistToHVN" && value<=0.296000) return 0.6000; // lift=+0.086 p=0.0100 tilt=0.60
   if(symbol=="JPMm" && setup=="ANCHORED_PULLBACK" && feature=="auctContinuation" && value>=0.247000) return 0.6000; // lift=+0.078 p=0.0100 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.053 p=0.0100 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.361000) return 0.7500; // lift=+0.028 p=0.0120 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctExpReward" && value<=0.920000) return 0.7500; // lift=+0.030 p=0.0120 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.720000) return 0.7500; // lift=+0.027 p=0.0120 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.059 p=0.0120 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.223000) return 0.7500; // lift=+0.029 p=0.0120 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7000; // lift=+0.035 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.319000) return 0.7500; // lift=+0.031 p=0.0120 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="auctReversalRisk" && value<=0.140000) return 0.7000; // lift=+0.038 p=0.0120 tilt=0.70
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.669000) return 0.7000; // lift=+0.040 p=0.0120 tilt=0.70
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.386000) return 0.7500; // lift=+0.031 p=0.0120 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.454250) return 0.7000; // lift=+0.035 p=0.0120 tilt=0.70
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.278000) return 0.7500; // lift=+0.034 p=0.0120 tilt=0.75
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-0.006044) return 0.7500; // lift=+0.024 p=0.0120 tilt=0.75
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="auctExpReward" && value<=0.995000) return 0.7500; // lift=+0.024 p=0.0120 tilt=0.75
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="auctContinuation" && value>=0.237000) return 0.7000; // lift=+0.035 p=0.0120 tilt=0.70
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.688500) return 0.7000; // lift=+0.055 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.371500) return 0.7000; // lift=+0.060 p=0.0120 tilt=0.70
   if(symbol=="USDCHFm" && setup=="NAKED_POC" && feature=="vpDistToHVN" && value<=0.128000) return 0.6000; // lift=+0.104 p=0.0120 tilt=0.60
   if(symbol=="USDCHFm" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-0.004279) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="auctContinuation" && value>=0.237000) return 0.7000; // lift=+0.047 p=0.0120 tilt=0.70
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.391000) return 0.6000; // lift=+0.068 p=0.0120 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.074037) return 0.7500; // lift=+0.030 p=0.0120 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.275842) return 0.7000; // lift=+0.037 p=0.0120 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.037 p=0.0120 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.160811) return 0.7500; // lift=+0.025 p=0.0120 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="smContext" && value<=0.110200) return 0.7500; // lift=+0.025 p=0.0120 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.430000) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.051 p=0.0120 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.678000) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.064982) return 0.7000; // lift=+0.049 p=0.0120 tilt=0.70
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.676000) return 0.7000; // lift=+0.049 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.376000) return 0.7000; // lift=+0.052 p=0.0120 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.075049) return 0.7500; // lift=+0.033 p=0.0120 tilt=0.75
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.061600) return 0.7000; // lift=+0.035 p=0.0120 tilt=0.70
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.061550) return 0.7000; // lift=+0.040 p=0.0120 tilt=0.70
   if(symbol=="US500m" && setup=="BREAKOUT" && feature=="auctExpReward" && value<=0.745000) return 0.7500; // lift=+0.034 p=0.0120 tilt=0.75
   if(symbol=="US500m" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.683000) return 0.7000; // lift=+0.059 p=0.0120 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=108.200000) return 0.7000; // lift=+0.049 p=0.0120 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST" && feature=="auctExhaustion" && value<=0.193000) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="SWEEP_REVERSAL" && feature=="auctHVNStrength" && value<=0.841000) return 0.7000; // lift=+0.066 p=0.0120 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="NAKED_POC" && feature=="vpPOC" && value<=-0.000261) return 0.6000; // lift=+0.118 p=0.0120 tilt=0.60
   if(symbol=="USDCADm" && setup=="NAKED_POC" && feature=="atrProxy" && value>=122.000000) return 0.6000; // lift=+0.100 p=0.0120 tilt=0.60
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK" && feature=="auctLVNStrength" && value<=0.897000) return 0.7000; // lift=+0.046 p=0.0120 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT" && feature=="spreadToATR" && value>=0.035400) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.030469) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.168400) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.105550) return 0.7000; // lift=+0.044 p=0.0120 tilt=0.70
   if(symbol=="FR40m" && setup=="MEAN_REVERSION" && feature=="auctTradeQuality" && value>=0.410000) return 0.7000; // lift=+0.039 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.314167) return 0.7000; // lift=+0.050 p=0.0120 tilt=0.70
   if(symbol=="FR40m" && setup=="NAKED_POC" && feature=="auctExpReward" && value<=0.681500) return 0.7000; // lift=+0.058 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="ofContext" && value<=0.320833) return 0.7000; // lift=+0.038 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.120 p=0.0120 tilt=0.60
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="vpDailyPOC" && value<=0.644850) return 0.7500; // lift=+0.034 p=0.0120 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="STOXX50m" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.337333) return 0.7000; // lift=+0.047 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.514750) return 0.7500; // lift=+0.023 p=0.0120 tilt=0.75
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpPriceVsPOC" && value>=0.730350) return 0.7500; // lift=+0.032 p=0.0120 tilt=0.75
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="auctBalance" && value<=0.644000) return 0.7500; // lift=+0.028 p=0.0120 tilt=0.75
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="auctFailure" && value<=0.150000) return 0.7000; // lift=+0.039 p=0.0120 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.039 p=0.0120 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.375000) return 0.7000; // lift=+0.043 p=0.0120 tilt=0.70
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.387000) return 0.7500; // lift=+0.029 p=0.0120 tilt=0.75
   if(symbol=="EURCHFm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.465000) return 0.7000; // lift=+0.057 p=0.0120 tilt=0.70
   if(symbol=="EURCHFm" && setup=="PULLBACK" && feature=="smZoneQuality" && value>=0.878000) return 0.7000; // lift=+0.053 p=0.0120 tilt=0.70
   if(symbol=="EURCHFm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.240500) return 0.7000; // lift=+0.043 p=0.0120 tilt=0.70
   if(symbol=="EURCHFm" && setup=="NAKED_POC" && feature=="vpDistToHVN" && value<=0.166000) return 0.6000; // lift=+0.090 p=0.0120 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.085 p=0.0120 tilt=0.60
   if(symbol=="GBPCADm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.691000) return 0.7500; // lift=+0.027 p=0.0120 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.322667) return 0.7500; // lift=+0.027 p=0.0120 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7500; // lift=+0.025 p=0.0120 tilt=0.75
   if(symbol=="GBPCADm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.669000) return 0.7500; // lift=+0.034 p=0.0120 tilt=0.75
   if(symbol=="NVDAm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.708000) return 0.6000; // lift=+0.070 p=0.0120 tilt=0.60
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.344000) return 0.7000; // lift=+0.041 p=0.0120 tilt=0.70
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK" && feature=="vpPOC" && value<=-1.076592) return 0.6000; // lift=+0.069 p=0.0120 tilt=0.60
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=-0.275808) return 0.6000; // lift=+0.069 p=0.0120 tilt=0.60
   if(symbol=="LMTm" && setup=="MEAN_REVERSION" && feature=="auctTradeQuality" && value>=0.389000) return 0.6000; // lift=+0.081 p=0.0120 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.326000) return 0.6000; // lift=+0.089 p=0.0120 tilt=0.60
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-8.808047) return 0.7000; // lift=+0.062 p=0.0120 tilt=0.70
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.429000) return 0.6000; // lift=+0.085 p=0.0120 tilt=0.60
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="vpLTTransitionScore" && value>=0.126000) return 0.6000; // lift=+0.084 p=0.0120 tilt=0.60
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="vpLTBalanceStability" && value<=0.874000) return 0.6000; // lift=+0.084 p=0.0120 tilt=0.60
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.263000) return 0.7000; // lift=+0.047 p=0.0120 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="METAm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.334833) return 0.7000; // lift=+0.054 p=0.0120 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.678000) return 0.7000; // lift=+0.049 p=0.0140 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.380500) return 0.7000; // lift=+0.049 p=0.0140 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.279000) return 0.7000; // lift=+0.036 p=0.0140 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="vpDistCompPOC" && value>=0.020000) return 0.7500; // lift=+0.028 p=0.0140 tilt=0.75
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="auctVAExpRate" && value>=0.000000) return 0.6000; // lift=+0.162 p=0.0140 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="BTCUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.326500) return 0.7000; // lift=+0.046 p=0.0140 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="NAKED_POC" && feature=="auctExpMoveATR" && value>=2.064500) return 0.6000; // lift=+0.074 p=0.0140 tilt=0.60
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.276000) return 0.7500; // lift=+0.030 p=0.0140 tilt=0.75
   if(symbol=="EURCADm" && setup=="BREAKOUT" && feature=="auctExpReward" && value<=0.998000) return 0.7500; // lift=+0.029 p=0.0140 tilt=0.75
   if(symbol=="USDJPYm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7000; // lift=+0.041 p=0.0140 tilt=0.70
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.060 p=0.0140 tilt=0.70
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="auctReversalRisk" && value<=0.155000) return 0.7000; // lift=+0.047 p=0.0140 tilt=0.70
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="atrProxy" && value>=96.800000) return 0.7000; // lift=+0.058 p=0.0140 tilt=0.70
   if(symbol=="USDCHFm" && setup=="PULLBACK" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.058 p=0.0140 tilt=0.70
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=2.164836) return 0.7000; // lift=+0.035 p=0.0140 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.276000) return 0.7000; // lift=+0.042 p=0.0140 tilt=0.70
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="vpPriceVsPOC" && value>=0.631800) return 0.7000; // lift=+0.062 p=0.0140 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.060384) return 0.7500; // lift=+0.031 p=0.0140 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="auctFailure" && value<=0.150000) return 0.7000; // lift=+0.035 p=0.0140 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.654000) return 0.6000; // lift=+0.080 p=0.0140 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.673000) return 0.7000; // lift=+0.042 p=0.0140 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.290500) return 0.7000; // lift=+0.042 p=0.0140 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpBestHVNScore" && value>=0.744000) return 0.7000; // lift=+0.050 p=0.0140 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.041647) return 0.7000; // lift=+0.035 p=0.0140 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.030 p=0.0140 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistCompPOC" && value>=0.003000) return 0.7000; // lift=+0.043 p=0.0140 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=0.065954) return 0.7500; // lift=+0.028 p=0.0140 tilt=0.75
   if(symbol=="USOILm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.374000) return 0.7000; // lift=+0.036 p=0.0140 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpPOC" && value<=0.089278) return 0.7000; // lift=+0.043 p=0.0140 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.071 p=0.0140 tilt=0.60
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="auctHVNStrength" && value<=0.834000) return 0.7500; // lift=+0.029 p=0.0140 tilt=0.75
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="vpBestHVNScore" && value>=0.743000) return 0.7000; // lift=+0.048 p=0.0140 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpVAH" && value<=-0.010616) return 0.7500; // lift=+0.030 p=0.0140 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="liqContext" && value>=0.464000) return 0.7500; // lift=+0.030 p=0.0140 tilt=0.75
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="vpDistToHVN" && value<=0.151000) return 0.7500; // lift=+0.027 p=0.0140 tilt=0.75
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>=0.217500) return 0.7000; // lift=+0.050 p=0.0140 tilt=0.70
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.476000) return 0.7000; // lift=+0.052 p=0.0140 tilt=0.70
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && feature=="vpDistCompPOC" && value>=0.027000) return 0.7000; // lift=+0.035 p=0.0140 tilt=0.70
   if(symbol=="US500m" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.385000) return 0.7000; // lift=+0.051 p=0.0140 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.305000) return 0.6000; // lift=+0.069 p=0.0140 tilt=0.60
   if(symbol=="USDCADm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7500; // lift=+0.030 p=0.0140 tilt=0.75
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctTradeQuality" && value>=0.420000) return 0.7000; // lift=+0.047 p=0.0140 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-1.022935) return 0.7500; // lift=+0.032 p=0.0140 tilt=0.75
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.355000) return 0.7000; // lift=+0.037 p=0.0140 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAL" && value<=0.000330) return 0.7000; // lift=+0.041 p=0.0140 tilt=0.70
   if(symbol=="EURAUDm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.000276) return 0.7500; // lift=+0.030 p=0.0140 tilt=0.75
   if(symbol=="EURCHFm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.426000) return 0.7000; // lift=+0.064 p=0.0140 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.244000) return 0.7500; // lift=+0.032 p=0.0140 tilt=0.75
   if(symbol=="XPTUSDm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.604200) return 0.7500; // lift=+0.030 p=0.0140 tilt=0.75
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION" && feature=="vpLTTransitionScore" && value>=0.104000) return 0.7500; // lift=+0.027 p=0.0140 tilt=0.75
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION" && feature=="vpLTBalanceStability" && value<=0.896000) return 0.7500; // lift=+0.027 p=0.0140 tilt=0.75
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION" && feature=="vpLTPOCVelocity" && value>=1.152000) return 0.7500; // lift=+0.027 p=0.0140 tilt=0.75
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.001357) return 0.7500; // lift=+0.027 p=0.0140 tilt=0.75
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7500; // lift=+0.027 p=0.0140 tilt=0.75
   if(symbol=="AAPLm" && setup=="NAKED_POC" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.6000; // lift=+0.101 p=0.0140 tilt=0.60
   if(symbol=="NFLXm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.756500) return 0.7000; // lift=+0.036 p=0.0140 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NFLXm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.312417) return 0.7000; // lift=+0.053 p=0.0140 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.471750) return 0.7000; // lift=+0.050 p=0.0140 tilt=0.70
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=1.750133) return 0.7000; // lift=+0.044 p=0.0140 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.310833) return 0.7000; // lift=+0.056 p=0.0140 tilt=0.70
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-0.646494) return 0.6000; // lift=+0.086 p=0.0140 tilt=0.60
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="auctExhaustion" && value<=0.267500) return 0.7000; // lift=+0.053 p=0.0140 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-7.038852) return 0.6000; // lift=+0.068 p=0.0140 tilt=0.60
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="auctTargetProb" && value<=0.414000) return 0.6000; // lift=+0.070 p=0.0140 tilt=0.60
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="auctReversalRisk" && value<=0.140000) return 0.7000; // lift=+0.044 p=0.0140 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="msContext" && value>=0.404000) return 0.7000; // lift=+0.041 p=0.0160 tilt=0.70
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.428000) return 0.7000; // lift=+0.049 p=0.0160 tilt=0.70
   if(symbol=="EURUSDm" && setup=="BREAKOUT" && feature=="vpBestHVNScore" && value>=0.706000) return 0.7500; // lift=+0.028 p=0.0160 tilt=0.75
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="vpLTTransitionScore" && value>=0.122000) return 0.7500; // lift=+0.027 p=0.0160 tilt=0.75
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="vpLTBalanceStability" && value<=0.878000) return 0.7500; // lift=+0.027 p=0.0160 tilt=0.75
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="atrProxy" && value>=108.900000) return 0.7500; // lift=+0.027 p=0.0160 tilt=0.75
   if(symbol=="EURUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.330500) return 0.7000; // lift=+0.049 p=0.0160 tilt=0.70
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.036 p=0.0160 tilt=0.70
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.409000) return 0.7500; // lift=+0.031 p=0.0160 tilt=0.75
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.095525) return 0.7000; // lift=+0.046 p=0.0160 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-0.194435) return 0.7000; // lift=+0.035 p=0.0160 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=0.790000) return 0.7000; // lift=+0.038 p=0.0160 tilt=0.70
   if(symbol=="USDCHFm" && setup=="BREAKOUT_RETEST" && feature=="auctBalance" && value<=0.663000) return 0.7000; // lift=+0.057 p=0.0160 tilt=0.70
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.500000) return 0.7000; // lift=+0.058 p=0.0160 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGUSDm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.322667) return 0.7500; // lift=+0.032 p=0.0160 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-0.284316) return 0.7000; // lift=+0.034 p=0.0160 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.671000) return 0.7000; // lift=+0.054 p=0.0160 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.070 p=0.0160 tilt=0.60
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAL" && value<=-0.249811) return 0.7000; // lift=+0.036 p=0.0160 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.017719) return 0.7000; // lift=+0.034 p=0.0160 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.296000) return 0.7000; // lift=+0.041 p=0.0160 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.428000) return 0.7500; // lift=+0.031 p=0.0160 tilt=0.75
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.389000) return 0.7500; // lift=+0.031 p=0.0160 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="US500m" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.304833) return 0.7000; // lift=+0.057 p=0.0160 tilt=0.70
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && feature=="auctExpReward" && value<=0.700500) return 0.7000; // lift=+0.036 p=0.0160 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.580000) return 0.7000; // lift=+0.051 p=0.0160 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7500; // lift=+0.033 p=0.0160 tilt=0.75
   if(symbol=="USDCADm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=0.000681) return 0.7500; // lift=+0.029 p=0.0160 tilt=0.75
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=6020.600000) return 0.7000; // lift=+0.067 p=0.0160 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.361000) return 0.7000; // lift=+0.037 p=0.0160 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=2.325260) return 0.7000; // lift=+0.035 p=0.0160 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.772434) return 0.7000; // lift=+0.038 p=0.0160 tilt=0.70
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK" && feature=="auctLVNStrength" && value<=0.900000) return 0.7000; // lift=+0.045 p=0.0160 tilt=0.70
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpVAH" && value<=-0.235146) return 0.7500; // lift=+0.029 p=0.0160 tilt=0.75
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-3.285887) return 0.7500; // lift=+0.029 p=0.0160 tilt=0.75
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.390000) return 0.7500; // lift=+0.024 p=0.0160 tilt=0.75
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="vpDailyPOC" && value<=0.090247) return 0.7000; // lift=+0.042 p=0.0160 tilt=0.70
   if(symbol=="EURCHFm" && setup=="TREND_CONTINUATION" && feature=="auctTradeQuality" && value>=0.417000) return 0.7000; // lift=+0.040 p=0.0160 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="liqContext" && value>=0.453400) return 0.7000; // lift=+0.035 p=0.0160 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="bosQuality")
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="bosQuality" && value>=0.000000) return 0.6000; // lift=+0.178 p=0.0160 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.478500) return 0.7000; // lift=+0.052 p=0.0160 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.425000) return 0.7000; // lift=+0.051 p=0.0160 tilt=0.70
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.344000) return 0.7000; // lift=+0.039 p=0.0160 tilt=0.70
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.126500) return 0.7000; // lift=+0.039 p=0.0160 tilt=0.70
   if(symbol=="NFLXm" && setup=="BREAKOUT" && feature=="vpDistToLVN" && value<=0.377500) return 0.7000; // lift=+0.036 p=0.0160 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.066 p=0.0160 tilt=0.70
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK" && feature=="smZoneQuality" && value>=0.851000) return 0.6000; // lift=+0.069 p=0.0160 tilt=0.60
   if(symbol=="LMTm" && setup=="NAKED_POC" && feature=="vpCompPOC" && value<=0.031783) return 0.6000; // lift=+0.089 p=0.0160 tilt=0.60
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="vpMigrationConf" && value>=0.800000) return 0.6000; // lift=+0.090 p=0.0160 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="msContext" && value>=0.467875) return 0.7000; // lift=+0.053 p=0.0160 tilt=0.70
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="auctExhaustion" && value<=0.298000) return 0.6000; // lift=+0.073 p=0.0160 tilt=0.60
   if(symbol=="JPMm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.332000) return 0.7000; // lift=+0.067 p=0.0160 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=-0.001829) return 0.7000; // lift=+0.040 p=0.0160 tilt=0.70
   if(symbol=="METAm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.809268) return 0.7000; // lift=+0.045 p=0.0160 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.086000) return 0.7000; // lift=+0.038 p=0.0180 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT" && feature=="vpMigrationScore" && value>=0.755000) return 0.7500; // lift=+0.026 p=0.0180 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.369000) return 0.7000; // lift=+0.037 p=0.0180 tilt=0.70
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="auctReversalRisk" && value<=0.140000) return 0.7000; // lift=+0.035 p=0.0180 tilt=0.70
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=0.152400) return 0.7000; // lift=+0.035 p=0.0180 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-0.303883) return 0.7000; // lift=+0.036 p=0.0180 tilt=0.70
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.377000) return 0.7000; // lift=+0.060 p=0.0180 tilt=0.70
   if(symbol=="US30m" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-17.108322) return 0.7000; // lift=+0.041 p=0.0180 tilt=0.70
   if(symbol=="US30m" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-29.412091) return 0.7000; // lift=+0.038 p=0.0180 tilt=0.70
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="vpLTPOCVelocity" && value>=6.426600) return 0.7000; // lift=+0.058 p=0.0180 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="BREAKOUT" && feature=="vpDistCompPOC" && value>=0.003000) return 0.7500; // lift=+0.032 p=0.0180 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpCompPOC" && value<=0.074720) return 0.7000; // lift=+0.056 p=0.0180 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.128000) return 0.7000; // lift=+0.045 p=0.0180 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpVAH" && value<=-0.011692) return 0.7500; // lift=+0.032 p=0.0180 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpPriceVsPOC" && value>=0.168800) return 0.7500; // lift=+0.032 p=0.0180 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.362000) return 0.7500; // lift=+0.025 p=0.0180 tilt=0.75
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.480000) return 0.7000; // lift=+0.056 p=0.0180 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="NAKED_POC" && feature=="spreadToATR" && value>=0.353500) return 0.7000; // lift=+0.054 p=0.0180 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.038 p=0.0180 tilt=0.70
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.128000) return 0.7000; // lift=+0.055 p=0.0180 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="smContext" && value<=0.377800) return 0.7000; // lift=+0.054 p=0.0180 tilt=0.70
   if(symbol=="US500m" && setup=="ANCHORED_PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.050 p=0.0180 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST" && feature=="auctLVNStrength" && value<=0.892000) return 0.7000; // lift=+0.047 p=0.0180 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="PULLBACK" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.046 p=0.0180 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="NAKED_POC" && feature=="atrProxy" && value>=102.300000) return 0.6000; // lift=+0.107 p=0.0180 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="GBPAUDm" && setup=="BREAKOUT_RETEST" && feature=="msContext" && value>=0.454250) return 0.7000; // lift=+0.035 p=0.0180 tilt=0.70
   if(symbol=="USDCADm" && setup=="TREND_CONTINUATION" && feature=="auctHVNStrength" && value<=0.848000) return 0.7500; // lift=+0.028 p=0.0180 tilt=0.75
   if(symbol=="USTECm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.470000) return 0.7000; // lift=+0.055 p=0.0180 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.044 p=0.0180 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="msContext" && value>=0.459000) return 0.7000; // lift=+0.046 p=0.0180 tilt=0.70
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.035 p=0.0180 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="auctFailure" && value<=0.250000) return 0.7000; // lift=+0.045 p=0.0180 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.262500) return 0.7000; // lift=+0.038 p=0.0180 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.411000) return 0.7000; // lift=+0.039 p=0.0180 tilt=0.70
   if(symbol=="XAUEURm" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.056 p=0.0180 tilt=0.70
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.021764) return 0.7500; // lift=+0.028 p=0.0180 tilt=0.75
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.896000) return 0.7500; // lift=+0.029 p=0.0180 tilt=0.75
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=0.000061) return 0.7000; // lift=+0.052 p=0.0180 tilt=0.70
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAL" && value<=-0.002974) return 0.7000; // lift=+0.052 p=0.0180 tilt=0.70
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=-0.049700) return 0.7000; // lift=+0.060 p=0.0180 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=0.004183) return 0.7500; // lift=+0.030 p=0.0180 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=145.700000) return 0.7500; // lift=+0.031 p=0.0180 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.419000) return 0.7500; // lift=+0.020 p=0.0180 tilt=0.75
   if(symbol=="AAPLm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.358000) return 0.7000; // lift=+0.045 p=0.0180 tilt=0.70
   if(symbol=="AAPLm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.790000) return 0.7000; // lift=+0.041 p=0.0180 tilt=0.70
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.389000) return 0.7000; // lift=+0.066 p=0.0180 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.320417) return 0.7000; // lift=+0.042 p=0.0180 tilt=0.70
   if(symbol=="NFLXm" && setup=="PULLBACK" && feature=="auctExhaustion" && value<=0.246000) return 0.7000; // lift=+0.035 p=0.0180 tilt=0.70
   if(symbol=="NFLXm" && setup=="PULLBACK" && feature=="vpLTTransitionScore" && value>=0.162000) return 0.7000; // lift=+0.035 p=0.0180 tilt=0.70
   if(symbol=="NFLXm" && setup=="PULLBACK" && feature=="vpLTBalanceStability" && value<=0.838000) return 0.7000; // lift=+0.035 p=0.0180 tilt=0.70
   if(symbol=="LMTm" && setup=="BREAKOUT" && feature=="auctVAExpRate" && value>=0.000000) return 0.6000; // lift=+0.185 p=0.0180 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAL" && value<=-5.453083) return 0.6000; // lift=+0.089 p=0.0180 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.199250) return 0.6000; // lift=+0.089 p=0.0180 tilt=0.60
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="auctTargetProb" && value<=0.415500) return 0.7000; // lift=+0.048 p=0.0180 tilt=0.70
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.033000) return 0.7000; // lift=+0.050 p=0.0180 tilt=0.70
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.104 p=0.0180 tilt=0.60
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK" && feature=="auctLVNStrength" && value<=0.935000) return 0.6000; // lift=+0.093 p=0.0180 tilt=0.60
   if(symbol=="EBAYm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.357000) return 0.7000; // lift=+0.058 p=0.0180 tilt=0.70
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-1.674855) return 0.7000; // lift=+0.064 p=0.0180 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="JPMm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.306667) return 0.6000; // lift=+0.079 p=0.0180 tilt=0.60
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="auctFailure" && value<=0.150000) return 0.7000; // lift=+0.041 p=0.0180 tilt=0.70
   if(symbol=="JPMm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.387000) return 0.7000; // lift=+0.066 p=0.0180 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.051 p=0.0200 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="NAKED_POC" && feature=="vpCompVAH" && value<=3.658880) return 0.7000; // lift=+0.048 p=0.0200 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && value>=0.087700) return 0.7000; // lift=+0.043 p=0.0200 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctReversalRisk" && value<=0.140000) return 0.7500; // lift=+0.031 p=0.0200 tilt=0.75
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCDir" && value>=0.213100) return 0.7000; // lift=+0.038 p=0.0200 tilt=0.70
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="auctReversalRisk" && value<=0.140000) return 0.7500; // lift=+0.029 p=0.0200 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="msContext" && value>=0.387000) return 0.7500; // lift=+0.034 p=0.0200 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURCADm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.329833) return 0.7500; // lift=+0.033 p=0.0200 tilt=0.75
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpDevPOCSlope" && value>=0.138100) return 0.7500; // lift=+0.026 p=0.0200 tilt=0.75
   if(symbol=="EURCADm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.153000) return 0.7000; // lift=+0.039 p=0.0200 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="EURCADm" && setup=="SWEEP_REVERSAL" && feature=="smContext" && value<=0.404000) return 0.7000; // lift=+0.036 p=0.0200 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.677000) return 0.7000; // lift=+0.040 p=0.0200 tilt=0.70
   if(symbol=="USDCHFm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.370000) return 0.7000; // lift=+0.039 p=0.0200 tilt=0.70
   if(symbol=="USDCHFm" && setup=="PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.055 p=0.0200 tilt=0.70
   if(symbol=="US30m" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.405000) return 0.7000; // lift=+0.048 p=0.0200 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-0.210634) return 0.7500; // lift=+0.034 p=0.0200 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.436000) return 0.7500; // lift=+0.025 p=0.0200 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.376000) return 0.7000; // lift=+0.050 p=0.0200 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.371000) return 0.7000; // lift=+0.050 p=0.0200 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="vpBestHVNScore" && value>=0.746000) return 0.7500; // lift=+0.029 p=0.0200 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=-0.086850) return 0.7000; // lift=+0.045 p=0.0200 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=-0.025471) return 0.7500; // lift=+0.025 p=0.0200 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpBestHVNScore" && value>=0.742000) return 0.7500; // lift=+0.033 p=0.0200 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.037 p=0.0200 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="msContext" && value>=0.503750) return 0.7500; // lift=+0.029 p=0.0200 tilt=0.75
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="smZoneQuality" && value>=1.014000) return 0.7500; // lift=+0.031 p=0.0200 tilt=0.75
   if(symbol=="GBPCHFm" && setup=="NAKED_POC" && feature=="auctAcceptance" && value>=0.425000) return 0.6000; // lift=+0.107 p=0.0200 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="GBPAUDm" && setup=="BREAKOUT_RETEST" && feature=="liqContext" && value>=0.487300) return 0.7000; // lift=+0.035 p=0.0200 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPAUDm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.321667) return 0.7500; // lift=+0.029 p=0.0200 tilt=0.75
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="vpLTTransitionScore" && value>=0.120000) return 0.7000; // lift=+0.046 p=0.0200 tilt=0.70
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="vpLTBalanceStability" && value<=0.880000) return 0.7000; // lift=+0.046 p=0.0200 tilt=0.70
   if(symbol=="USTECm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.681000) return 0.6000; // lift=+0.076 p=0.0200 tilt=0.60
   if(symbol=="XAUUSDm" && setup=="BREAKOUT" && feature=="auctLVNStrength" && value<=0.901000) return 0.7000; // lift=+0.040 p=0.0200 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.038 p=0.0200 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="liqContext" && value>=0.504800) return 0.7000; // lift=+0.038 p=0.0200 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.900000) return 0.7500; // lift=+0.034 p=0.0200 tilt=0.75
   if(symbol=="STOXX50m" && setup=="NAKED_POC" && feature=="vpDistToLVN" && value<=0.301500) return 0.7000; // lift=+0.053 p=0.0200 tilt=0.70
   if(symbol=="EURAUDm" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7500; // lift=+0.025 p=0.0200 tilt=0.75
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="vpBestHVNScore" && value>=0.734000) return 0.7500; // lift=+0.025 p=0.0200 tilt=0.75
   if(symbol=="EURCHFm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.432500) return 0.7000; // lift=+0.042 p=0.0200 tilt=0.70
   if(symbol=="EURCHFm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.387000) return 0.7000; // lift=+0.039 p=0.0200 tilt=0.70
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpPOC" && value<=-0.000122) return 0.7500; // lift=+0.028 p=0.0200 tilt=0.75
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.103 p=0.0200 tilt=0.60
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.074 p=0.0200 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctRegimeConf" && value<=0.697000) return 0.7000; // lift=+0.034 p=0.0200 tilt=0.70
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION" && feature=="auctExpReward" && value<=1.124500) return 0.7500; // lift=+0.027 p=0.0200 tilt=0.75
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="vpBestHVNScore" && value>=0.739000) return 0.7500; // lift=+0.023 p=0.0200 tilt=0.75
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.738000) return 0.7000; // lift=+0.039 p=0.0200 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.442200) return 0.7000; // lift=+0.058 p=0.0200 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="JPMm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.330000) return 0.7000; // lift=+0.065 p=0.0200 tilt=0.70
   if(symbol=="METAm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.367000) return 0.7000; // lift=+0.057 p=0.0200 tilt=0.70
   if(symbol=="METAm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.168800) return 0.7000; // lift=+0.045 p=0.0200 tilt=0.70
   if(symbol=="METAm" && setup=="NAKED_POC" && feature=="auctAcceptance" && value>=0.348000) return 0.7000; // lift=+0.049 p=0.0200 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.033 p=0.0220 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpCompVAL" && value<=-3.170461) return 0.7000; // lift=+0.044 p=0.0220 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="vpMigrationScore" && value>=0.755000) return 0.7500; // lift=+0.026 p=0.0220 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EURJPYm" && setup=="PULLBACK" && feature=="liqContext" && value>=0.467200) return 0.7500; // lift=+0.022 p=0.0220 tilt=0.75
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.381000) return 0.7000; // lift=+0.035 p=0.0220 tilt=0.70
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpBestHVNScore" && value>=0.726000) return 0.7500; // lift=+0.024 p=0.0220 tilt=0.75
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="auctExhaustion" && value<=0.241000) return 0.7500; // lift=+0.023 p=0.0220 tilt=0.75
   if(symbol=="EURCADm" && setup=="SWEEP_REVERSAL" && feature=="vpLTPOCVelocity" && value>=925.639700) return 0.7000; // lift=+0.036 p=0.0220 tilt=0.70
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="auctTradeQuality" && value>=0.447000) return 0.7000; // lift=+0.047 p=0.0220 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="vpBestHVNScore" && value>=0.723000) return 0.7500; // lift=+0.029 p=0.0220 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.368000) return 0.7500; // lift=+0.031 p=0.0220 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="XAGUSDm" && setup=="ANCHORED_PULLBACK" && feature=="liqContext" && value>=0.488900) return 0.7000; // lift=+0.043 p=0.0220 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.057 p=0.0220 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAUAUDm" && setup=="BREAKOUT" && feature=="smContext" && value<=0.109800) return 0.7500; // lift=+0.024 p=0.0220 tilt=0.75
   if(symbol=="USOILm" && setup=="NAKED_POC" && feature=="auctRegimeConf" && value<=0.707000) return 0.7000; // lift=+0.059 p=0.0220 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USOILm" && setup=="NAKED_POC" && feature=="ofContext" && value<=0.316833) return 0.7000; // lift=+0.064 p=0.0220 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=-0.111363) return 0.7000; // lift=+0.036 p=0.0220 tilt=0.70
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.905000) return 0.7000; // lift=+0.048 p=0.0220 tilt=0.70
   if(symbol=="US500m" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.059200) return 0.7000; // lift=+0.038 p=0.0220 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.408000) return 0.7500; // lift=+0.032 p=0.0220 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.276000) return 0.7500; // lift=+0.031 p=0.0220 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.371000) return 0.7000; // lift=+0.038 p=0.0220 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.384000) return 0.7000; // lift=+0.040 p=0.0220 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.317000) return 0.7000; // lift=+0.041 p=0.0220 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.318333) return 0.7500; // lift=+0.033 p=0.0220 tilt=0.75
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.233000) return 0.7500; // lift=+0.028 p=0.0220 tilt=0.75
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.415000) return 0.7500; // lift=+0.029 p=0.0220 tilt=0.75
   if(symbol=="EURCHFm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.375000) return 0.7000; // lift=+0.060 p=0.0220 tilt=0.70
   if(symbol=="EURCHFm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.052 p=0.0220 tilt=0.70
   if(symbol=="EURCHFm" && setup=="NAKED_POC" && feature=="auctTargetProb" && value<=0.399000) return 0.6000; // lift=+0.076 p=0.0220 tilt=0.60
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="auctVAExpRate" && value>=0.000000) return 0.6000; // lift=+0.087 p=0.0220 tilt=0.60
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.699000) return 0.7000; // lift=+0.034 p=0.0220 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.313667) return 0.7000; // lift=+0.048 p=0.0220 tilt=0.70
   if(symbol=="GBPCADm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.215500) return 0.7000; // lift=+0.039 p=0.0220 tilt=0.70
   if(symbol=="GBPCADm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.457000) return 0.7500; // lift=+0.030 p=0.0220 tilt=0.75
   if(symbol=="GBPCADm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.362000) return 0.7500; // lift=+0.029 p=0.0220 tilt=0.75
   if(symbol=="AAPLm" && setup=="SWEEP_REVERSAL" && feature=="smZoneQuality" && value>=0.862000) return 0.7000; // lift=+0.058 p=0.0220 tilt=0.70
   if(symbol=="AAPLm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.358000) return 0.7000; // lift=+0.063 p=0.0220 tilt=0.70
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCSlope" && value>=0.115800) return 0.7000; // lift=+0.067 p=0.0220 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.332833) return 0.7000; // lift=+0.066 p=0.0220 tilt=0.70
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL" && feature=="auctFailure" && value<=0.150000) return 0.7000; // lift=+0.050 p=0.0220 tilt=0.70
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.444355) return 0.7000; // lift=+0.043 p=0.0220 tilt=0.70
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="auctAcceptance" && value>=0.313500) return 0.7000; // lift=+0.053 p=0.0220 tilt=0.70
   if(symbol=="GOOGLm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.705000) return 0.6000; // lift=+0.077 p=0.0220 tilt=0.60
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpVAH" && value<=0.705655) return 0.6000; // lift=+0.072 p=0.0220 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="auctContinuation" && value>=0.247000) return 0.7000; // lift=+0.039 p=0.0220 tilt=0.70
   if(symbol=="METAm" && setup=="NAKED_POC" && feature=="vpCompPOC" && value<=0.275186) return 0.7000; // lift=+0.049 p=0.0220 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.498000) return 0.7000; // lift=+0.046 p=0.0240 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.700000) return 0.7000; // lift=+0.044 p=0.0240 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.965291) return 0.7500; // lift=+0.033 p=0.0240 tilt=0.75
   if(symbol=="BTCUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.293000) return 0.7000; // lift=+0.039 p=0.0240 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.384375) return 0.7000; // lift=+0.044 p=0.0240 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.372000) return 0.7000; // lift=+0.039 p=0.0240 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && feature=="auctExpReward" && value<=0.968500) return 0.7500; // lift=+0.025 p=0.0240 tilt=0.75
   if(symbol=="EURJPYm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.615000) return 0.7000; // lift=+0.058 p=0.0240 tilt=0.70
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.100600) return 0.7500; // lift=+0.029 p=0.0240 tilt=0.75
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="auctHVNStrength" && value<=0.865000) return 0.7500; // lift=+0.032 p=0.0240 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="EURUSDm" && setup=="BREAKOUT_RETEST" && feature=="msContext" && value>=0.461125) return 0.7000; // lift=+0.035 p=0.0240 tilt=0.70
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-0.679498) return 0.7500; // lift=+0.032 p=0.0240 tilt=0.75
   if(symbol=="USDCHFm" && setup=="NAKED_POC" && feature=="smZoneQuality" && value>=0.819000) return 0.6000; // lift=+0.103 p=0.0240 tilt=0.60
   if(symbol=="USDCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=0.017900) return 0.7000; // lift=+0.049 p=0.0240 tilt=0.70
   if(symbol=="US30m" && setup=="BREAKOUT" && feature=="vpDistToLVN" && value<=0.265000) return 0.7000; // lift=+0.038 p=0.0240 tilt=0.70
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationConf" && value>=0.825000) return 0.7000; // lift=+0.060 p=0.0240 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7500; // lift=+0.031 p=0.0240 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="msContext" && value>=0.506500) return 0.7500; // lift=+0.032 p=0.0240 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.380000) return 0.7000; // lift=+0.040 p=0.0240 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCDir" && value>=0.720000) return 0.7000; // lift=+0.041 p=0.0240 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST" && feature=="auctBalance" && value<=0.658000) return 0.7500; // lift=+0.029 p=0.0240 tilt=0.75
   if(symbol=="USOILm" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.165000) return 0.7500; // lift=+0.033 p=0.0240 tilt=0.75
   if(symbol=="USOILm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.040 p=0.0240 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="msContext" && value>=0.535750) return 0.7000; // lift=+0.036 p=0.0240 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpBestHVNScore" && value>=0.757000) return 0.7000; // lift=+0.039 p=0.0240 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="vpBestHVNScore" && value>=0.744000) return 0.7500; // lift=+0.026 p=0.0240 tilt=0.75
   if(symbol=="US500m" && setup=="BREAKOUT_RETEST" && feature=="auctAcceptance" && value>=0.591000) return 0.7000; // lift=+0.038 p=0.0240 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST" && feature=="vpBestHVNScore" && value>=0.733000) return 0.7000; // lift=+0.041 p=0.0240 tilt=0.70
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.366287) return 0.7000; // lift=+0.036 p=0.0240 tilt=0.70
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.035800) return 0.7000; // lift=+0.036 p=0.0240 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.729500) return 0.7000; // lift=+0.038 p=0.0240 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="vpVAL" && value<=-1.019759) return 0.7000; // lift=+0.042 p=0.0240 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="smZoneQuality" && value>=0.848000) return 0.7500; // lift=+0.034 p=0.0240 tilt=0.75
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK" && feature=="smZoneQuality" && value>=0.847000) return 0.7000; // lift=+0.036 p=0.0240 tilt=0.70
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-7.000950) return 0.7500; // lift=+0.029 p=0.0240 tilt=0.75
   if(symbol=="STOXX50m" && setup=="BREAKOUT" && feature=="vpVAH" && value<=-0.453161) return 0.7500; // lift=+0.024 p=0.0240 tilt=0.75
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.043 p=0.0240 tilt=0.70
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.689000) return 0.7500; // lift=+0.033 p=0.0240 tilt=0.75
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.086 p=0.0240 tilt=0.60
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST" && feature=="auctLVNStrength" && value<=0.891000) return 0.7500; // lift=+0.030 p=0.0240 tilt=0.75
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.438000) return 0.7500; // lift=+0.025 p=0.0240 tilt=0.75
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.412000) return 0.7000; // lift=+0.038 p=0.0240 tilt=0.70
   if(symbol=="EURGBPm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.621500) return 0.7000; // lift=+0.036 p=0.0240 tilt=0.70
   if(symbol=="EURGBPm" && setup=="NAKED_POC" && feature=="auctHVNStrength" && value<=0.840000) return 0.6000; // lift=+0.093 p=0.0240 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION" && feature=="auctTradeQuality" && value>=0.428000) return 0.7500; // lift=+0.032 p=0.0240 tilt=0.75
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="vpVAH" && value<=-0.000065) return 0.7500; // lift=+0.024 p=0.0240 tilt=0.75
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="atrProxy" && value>=162.600000) return 0.7500; // lift=+0.027 p=0.0240 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="AAPLm" && setup=="PULLBACK" && feature=="liqContext" && value>=0.456200) return 0.7000; // lift=+0.046 p=0.0240 tilt=0.70
   if(symbol=="NVDAm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-8.696827) return 0.7000; // lift=+0.043 p=0.0240 tilt=0.70
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=3.804654) return 0.6000; // lift=+0.075 p=0.0240 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpBestHVNScore" && value>=0.693000) return 0.6000; // lift=+0.078 p=0.0240 tilt=0.60
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-8.793071) return 0.7000; // lift=+0.047 p=0.0240 tilt=0.70
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.358000) return 0.7000; // lift=+0.051 p=0.0240 tilt=0.70
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="auctLVNStrength" && value<=0.920000) return 0.7000; // lift=+0.051 p=0.0240 tilt=0.70
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="auctAcceptance" && value>=0.245000) return 0.6000; // lift=+0.069 p=0.0240 tilt=0.60
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.693000) return 0.6000; // lift=+0.069 p=0.0240 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GOOGLm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.311333) return 0.6000; // lift=+0.077 p=0.0240 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="JPMm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.306750) return 0.7000; // lift=+0.058 p=0.0240 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="vpMigrationScore" && value>=0.790000) return 0.7000; // lift=+0.041 p=0.0240 tilt=0.70
   if(symbol=="JPMm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.364000) return 0.7000; // lift=+0.056 p=0.0240 tilt=0.70
   if(symbol=="METAm" && setup=="MEAN_REVERSION" && feature=="msCompression" && value>=0.766000) return 0.7000; // lift=+0.045 p=0.0240 tilt=0.70
   if(symbol=="METAm" && setup=="NAKED_POC" && feature=="vpCompVAL" && value<=-4.241998) return 0.7000; // lift=+0.049 p=0.0240 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.410000) return 0.7500; // lift=+0.027 p=0.0260 tilt=0.75
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="vpLTPOCVelocity" && value>=7.053700) return 0.7500; // lift=+0.025 p=0.0260 tilt=0.75
   if(symbol=="BTCUSDm" && setup=="ANCHORED_PULLBACK" && feature=="atrProxy" && value>=46560.300000) return 0.7000; // lift=+0.039 p=0.0260 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.041 p=0.0260 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="vpDailyPOC" && value<=0.532082) return 0.7500; // lift=+0.033 p=0.0260 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && feature=="vpDistCompPOC" && value>=0.021000) return 0.7500; // lift=+0.025 p=0.0260 tilt=0.75
   if(symbol=="EURJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationScore" && value>=0.768000) return 0.7500; // lift=+0.030 p=0.0260 tilt=0.75
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDailyPOC" && value<=-0.000050) return 0.7000; // lift=+0.035 p=0.0260 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="vpPriceVsPOC" && value>=-0.647950) return 0.7000; // lift=+0.039 p=0.0260 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.082 p=0.0260 tilt=0.60
   if(symbol=="USDJPYm" && setup=="NAKED_POC" && feature=="auctFailure" && value<=0.250000) return 0.7000; // lift=+0.065 p=0.0260 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="vpMigrationScore" && value>=0.790000) return 0.7500; // lift=+0.033 p=0.0260 tilt=0.75
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpCompVAH" && value<=0.399013) return 0.7000; // lift=+0.050 p=0.0260 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="GBPJPYm" && setup=="ANCHORED_PULLBACK" && feature=="msContext" && value>=0.513125) return 0.7000; // lift=+0.034 p=0.0260 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="BREAKOUT" && feature=="vpDistToHVN" && value<=0.147000) return 0.7500; // lift=+0.026 p=0.0260 tilt=0.75
   if(symbol=="USDCHFm" && setup=="BREAKOUT_RETEST" && feature=="auctRegimeConf" && value<=0.696000) return 0.7000; // lift=+0.046 p=0.0260 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.426000) return 0.7500; // lift=+0.031 p=0.0260 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctReversalRisk" && value<=0.140000) return 0.7500; // lift=+0.032 p=0.0260 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpBestHVNScore" && value>=0.723000) return 0.7000; // lift=+0.053 p=0.0260 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctHVNStrength" && value<=0.846000) return 0.7000; // lift=+0.056 p=0.0260 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.142055) return 0.7500; // lift=+0.029 p=0.0260 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="auctAcceptance" && value>=0.413000) return 0.7500; // lift=+0.029 p=0.0260 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.899000) return 0.7500; // lift=+0.027 p=0.0260 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST" && feature=="msContext" && value>=0.443000) return 0.7000; // lift=+0.037 p=0.0260 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.257441) return 0.7500; // lift=+0.028 p=0.0260 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USOILm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.321333) return 0.7500; // lift=+0.033 p=0.0260 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.093 p=0.0260 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="auctContinuation" && value>=0.247000) return 0.7000; // lift=+0.036 p=0.0260 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=0.001220) return 0.7500; // lift=+0.031 p=0.0260 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="BREAKOUT" && feature=="vpDevPOCDir" && value>=0.755000) return 0.7500; // lift=+0.028 p=0.0260 tilt=0.75
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="auctExpMoveATR" && value>=3.000000) return 0.7000; // lift=+0.060 p=0.0260 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.310000) return 0.7500; // lift=+0.032 p=0.0260 tilt=0.75
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.676000) return 0.7000; // lift=+0.059 p=0.0260 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.059 p=0.0260 tilt=0.70
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-4.971100) return 0.7500; // lift=+0.029 p=0.0260 tilt=0.75
   if(symbol=="FR40m" && setup=="NAKED_POC" && feature=="auctTargetProb" && value<=0.392000) return 0.7000; // lift=+0.058 p=0.0260 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.346691) return 0.7500; // lift=+0.030 p=0.0260 tilt=0.75
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.388000) return 0.7500; // lift=+0.034 p=0.0260 tilt=0.75
   if(symbol=="STOXX50m" && setup=="NAKED_POC" && feature=="vpCompVAL" && value<=-4.511816) return 0.7000; // lift=+0.053 p=0.0260 tilt=0.70
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="auctLVNStrength" && value<=0.911000) return 0.7500; // lift=+0.032 p=0.0260 tilt=0.75
   if(symbol=="EURAUDm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.000150) return 0.7500; // lift=+0.027 p=0.0260 tilt=0.75
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.263000) return 0.7000; // lift=+0.038 p=0.0260 tilt=0.70
   if(symbol=="EURGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationConf" && value>=0.800000) return 0.7500; // lift=+0.033 p=0.0260 tilt=0.75
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.459000) return 0.7500; // lift=+0.027 p=0.0260 tilt=0.75
   if(symbol=="AAPLm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>=0.671000) return 0.7000; // lift=+0.058 p=0.0260 tilt=0.70
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="auctBalance" && value<=0.645000) return 0.7500; // lift=+0.031 p=0.0260 tilt=0.75
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK" && feature=="auctVAExpRate" && value>=0.000000) return 0.6000; // lift=+0.086 p=0.0260 tilt=0.60
   if(symbol=="EBAYm" && setup=="PULLBACK" && feature=="vpCompPOC" && value<=-4.391337) return 0.7000; // lift=+0.051 p=0.0260 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpPOC" && value<=-0.430347) return 0.7000; // lift=+0.053 p=0.0260 tilt=0.70
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.651000) return 0.6000; // lift=+0.072 p=0.0260 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAL" && value<=-9.172849) return 0.7000; // lift=+0.038 p=0.0260 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="vpDistCompPOC" && value>=0.031000) return 0.7500; // lift=+0.030 p=0.0260 tilt=0.75
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-0.005858) return 0.7500; // lift=+0.023 p=0.0280 tilt=0.75
   if(symbol=="EURCADm" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.160000) return 0.7500; // lift=+0.021 p=0.0280 tilt=0.75
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctExpReward" && value<=1.128000) return 0.7000; // lift=+0.039 p=0.0280 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.035 p=0.0280 tilt=0.70
   if(symbol=="USDCHFm" && setup=="TREND_CONTINUATION" && feature=="auctTradeQuality" && value>=0.427000) return 0.7000; // lift=+0.045 p=0.0280 tilt=0.70
   if(symbol=="US30m" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.481000) return 0.7000; // lift=+0.045 p=0.0280 tilt=0.70
   if(symbol=="US30m" && setup=="SWEEP_REVERSAL" && feature=="auctReversalRisk" && value<=0.168000) return 0.7000; // lift=+0.052 p=0.0280 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="BREAKOUT" && feature=="auctTargetProb" && value<=0.393000) return 0.7500; // lift=+0.029 p=0.0280 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.003000) return 0.7500; // lift=+0.033 p=0.0280 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.394000) return 0.7500; // lift=+0.031 p=0.0280 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.389000) return 0.7500; // lift=+0.028 p=0.0280 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST" && feature=="auctBalance" && value<=0.655000) return 0.7500; // lift=+0.032 p=0.0280 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="USOILm" && setup=="TREND_CONTINUATION" && feature=="smContext" && value<=0.401400) return 0.7500; // lift=+0.032 p=0.0280 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpLTPOCVelocity" && value>=283.491250) return 0.7500; // lift=+0.034 p=0.0280 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.042 p=0.0280 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.900000) return 0.7500; // lift=+0.026 p=0.0280 tilt=0.75
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.219000) return 0.7000; // lift=+0.044 p=0.0280 tilt=0.70
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK" && feature=="msCompression" && value>=0.638000) return 0.7000; // lift=+0.044 p=0.0280 tilt=0.70
   if(symbol=="US500m" && setup=="BREAKOUT" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.050 p=0.0280 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="PULLBACK" && feature=="auctContinuation" && value>=0.227000) return 0.7000; // lift=+0.040 p=0.0280 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.110 p=0.0280 tilt=0.60
   if(symbol=="USTECm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.987501) return 0.7000; // lift=+0.051 p=0.0280 tilt=0.70
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.163350) return 0.7000; // lift=+0.036 p=0.0280 tilt=0.70
   if(symbol=="USTECm" && setup=="ANCHORED_PULLBACK" && feature=="smZoneQuality" && value>=0.908000) return 0.7000; // lift=+0.042 p=0.0280 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.100560) return 0.7000; // lift=+0.035 p=0.0280 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7500; // lift=+0.029 p=0.0280 tilt=0.75
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="auctExhaustion" && value<=0.203000) return 0.7000; // lift=+0.035 p=0.0280 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctReversalRisk" && value<=0.140000) return 0.7000; // lift=+0.042 p=0.0280 tilt=0.70
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpDevPOCSlope" && value>=0.156450) return 0.7500; // lift=+0.025 p=0.0280 tilt=0.75
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7500; // lift=+0.033 p=0.0280 tilt=0.75
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.895000) return 0.7000; // lift=+0.034 p=0.0280 tilt=0.70
   if(symbol=="EURGBPm" && setup=="ANCHORED_PULLBACK" && feature=="auctLVNStrength" && value<=0.902000) return 0.7000; // lift=+0.034 p=0.0280 tilt=0.70
   if(symbol=="EURGBPm" && setup=="NAKED_POC" && feature=="auctAcceptance" && value>=0.367500) return 0.6000; // lift=+0.093 p=0.0280 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.490750) return 0.7500; // lift=+0.031 p=0.0280 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.147500) return 0.7500; // lift=+0.029 p=0.0280 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.148100) return 0.7500; // lift=+0.022 p=0.0280 tilt=0.75
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-3.788494) return 0.7500; // lift=+0.031 p=0.0280 tilt=0.75
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.720000) return 0.7000; // lift=+0.058 p=0.0280 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.685000) return 0.7000; // lift=+0.043 p=0.0280 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="vpDistCompPOC" && value>=0.033000) return 0.7000; // lift=+0.054 p=0.0280 tilt=0.70
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpDistToHVN" && value<=0.312000) return 0.6000; // lift=+0.072 p=0.0280 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=0.556575) return 0.7000; // lift=+0.038 p=0.0280 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.755000) return 0.7000; // lift=+0.040 p=0.0280 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpVAL" && value<=-1.977085) return 0.7000; // lift=+0.040 p=0.0280 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-4.405700) return 0.7000; // lift=+0.040 p=0.0280 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="auctTradeQuality" && value>=0.403000) return 0.7000; // lift=+0.040 p=0.0280 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.303333) return 0.7000; // lift=+0.065 p=0.0280 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-1.854980) return 0.7500; // lift=+0.025 p=0.0300 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-1.166905) return 0.7500; // lift=+0.026 p=0.0300 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.155500) return 0.7000; // lift=+0.035 p=0.0300 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.670000) return 0.7000; // lift=+0.035 p=0.0300 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.687000) return 0.7000; // lift=+0.035 p=0.0300 tilt=0.70
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="vpPOC" && value<=-0.045441) return 0.7500; // lift=+0.023 p=0.0300 tilt=0.75
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAL" && value<=-0.005574) return 0.7500; // lift=+0.022 p=0.0300 tilt=0.75
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST" && feature=="vpMigrationScore" && value>=0.755000) return 0.7500; // lift=+0.022 p=0.0300 tilt=0.75
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.273000) return 0.7000; // lift=+0.039 p=0.0300 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.253290) return 0.7500; // lift=+0.033 p=0.0300 tilt=0.75
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7000; // lift=+0.054 p=0.0300 tilt=0.70
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.390000) return 0.7000; // lift=+0.041 p=0.0300 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.323000) return 0.7500; // lift=+0.033 p=0.0300 tilt=0.75
   if(symbol=="USDCHFm" && setup=="BREAKOUT" && feature=="atrProxy" && value>=98.400000) return 0.7000; // lift=+0.037 p=0.0300 tilt=0.70
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.116 p=0.0300 tilt=0.60
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="vpDistToLVN" && value<=0.262000) return 0.7000; // lift=+0.037 p=0.0300 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="NAKED_POC" && feature=="vpBestHVNScore" && value>=0.727000) return 0.6000; // lift=+0.089 p=0.0300 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="NAKED_POC" && feature=="ofFlowIntensity" && value<=0.363500) return 0.6000; // lift=+0.104 p=0.0300 tilt=0.60
   if(symbol=="XAGUSDm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=0.037106) return 0.7500; // lift=+0.032 p=0.0300 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.176800) return 0.7000; // lift=+0.038 p=0.0300 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="NAKED_POC" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.105 p=0.0300 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="auctExpMoveATR" && value>=3.000000) return 0.7000; // lift=+0.048 p=0.0300 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.030 p=0.0300 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.498400) return 0.7500; // lift=+0.022 p=0.0300 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.676000) return 0.7000; // lift=+0.036 p=0.0300 tilt=0.70
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=341.200000) return 0.7000; // lift=+0.048 p=0.0300 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpDailyPOC" && value<=-0.296687) return 0.7000; // lift=+0.036 p=0.0300 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="MEAN_REVERSION" && feature=="vpBestHVNScore" && value>=0.753000) return 0.7500; // lift=+0.024 p=0.0300 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.305500) return 0.7500; // lift=+0.034 p=0.0300 tilt=0.75
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.675000) return 0.7000; // lift=+0.042 p=0.0300 tilt=0.70
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.287000) return 0.7000; // lift=+0.043 p=0.0300 tilt=0.70
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.307000) return 0.7000; // lift=+0.045 p=0.0300 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.508250) return 0.7500; // lift=+0.025 p=0.0300 tilt=0.75
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.790000) return 0.7000; // lift=+0.034 p=0.0300 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="vpPriceVsPOC" && value>=-0.641900) return 0.7000; // lift=+0.042 p=0.0300 tilt=0.70
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.261500) return 0.7000; // lift=+0.037 p=0.0300 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL" && feature=="liqContext" && value>=0.436300) return 0.7000; // lift=+0.040 p=0.0300 tilt=0.70
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="vpVAOverlapRatio" && value<=0.449000) return 0.7500; // lift=+0.020 p=0.0300 tilt=0.75
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.122700) return 0.7500; // lift=+0.030 p=0.0300 tilt=0.75
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.026 p=0.0300 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="structAlign")
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="structAlign" && value>=0.500000) return 0.6000; // lift=+0.133 p=0.0300 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="GBPUSDm" && setup=="BREAKOUT" && feature=="chochQuality" && value>=0.000000) return 0.6000; // lift=+0.080 p=0.0300 tilt=0.60
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-0.002533) return 0.7500; // lift=+0.022 p=0.0300 tilt=0.75
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.341000) return 0.7000; // lift=+0.050 p=0.0300 tilt=0.70
   if(symbol=="EBAYm" && setup=="BREAKOUT" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.071 p=0.0300 tilt=0.60
   if(symbol=="GOOGLm" && setup=="BREAKOUT_RETEST" && feature=="vpLTPOCVelocity" && value>=63.722100) return 0.7000; // lift=+0.051 p=0.0300 tilt=0.70
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="auctRegimeConf" && value<=0.674000) return 0.7000; // lift=+0.052 p=0.0300 tilt=0.70
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="vpVAL" && value<=-1.228315) return 0.6000; // lift=+0.069 p=0.0300 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="auctExhaustion" && value<=0.206000) return 0.7000; // lift=+0.038 p=0.0300 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="smZoneQuality" && value>=0.924000) return 0.7000; // lift=+0.040 p=0.0300 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.021000) return 0.7500; // lift=+0.025 p=0.0320 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=0.003165) return 0.7500; // lift=+0.025 p=0.0320 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCSlope" && value>=0.008850) return 0.7500; // lift=+0.029 p=0.0320 tilt=0.75
   if(symbol=="EURJPYm" && setup=="TREND_CONTINUATION" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.050 p=0.0320 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.308833) return 0.7500; // lift=+0.027 p=0.0320 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="USDCHFm" && setup=="BREAKOUT" && feature=="liqContext" && value>=0.457600) return 0.7000; // lift=+0.035 p=0.0320 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpDistCompPOC" && value>=0.002000) return 0.7000; // lift=+0.062 p=0.0320 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="vpDailyPOC" && value<=0.061112) return 0.7000; // lift=+0.037 p=0.0320 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.430000) return 0.7000; // lift=+0.044 p=0.0320 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAH" && value<=-0.099351) return 0.7000; // lift=+0.036 p=0.0320 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.090118) return 0.7500; // lift=+0.022 p=0.0320 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.361000) return 0.7500; // lift=+0.022 p=0.0320 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.271450) return 0.7500; // lift=+0.031 p=0.0320 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpVAL" && value<=-0.127695) return 0.7500; // lift=+0.033 p=0.0320 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAL" && value<=-0.620456) return 0.7500; // lift=+0.033 p=0.0320 tilt=0.75
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.047 p=0.0320 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="NAKED_POC" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.165 p=0.0320 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.373000) return 0.7500; // lift=+0.032 p=0.0320 tilt=0.75
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.032 p=0.0320 tilt=0.75
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="atrProxy" && value>=108.100000) return 0.7500; // lift=+0.032 p=0.0320 tilt=0.75
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.386000) return 0.7500; // lift=+0.032 p=0.0320 tilt=0.75
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="vpDistCompPOC" && value>=0.025000) return 0.7000; // lift=+0.055 p=0.0320 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="vpDistCompPOC" && value>=0.025000) return 0.7000; // lift=+0.039 p=0.0320 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.056 p=0.0320 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctContinuation" && value>=0.226000) return 0.7000; // lift=+0.056 p=0.0320 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.664000) return 0.7000; // lift=+0.040 p=0.0320 tilt=0.70
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.308500) return 0.7500; // lift=+0.025 p=0.0320 tilt=0.75
   if(symbol=="STOXX50m" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>=0.288500) return 0.7000; // lift=+0.039 p=0.0320 tilt=0.70
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.255784) return 0.7500; // lift=+0.031 p=0.0320 tilt=0.75
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.707000) return 0.7500; // lift=+0.031 p=0.0320 tilt=0.75
   if(symbol=="XAUEURm" && setup=="NAKED_POC" && feature=="vpMigrationScore" && value>=0.755000) return 0.7000; // lift=+0.065 p=0.0320 tilt=0.70
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST" && feature=="auctAcceptance" && value>=0.598500) return 0.7500; // lift=+0.026 p=0.0320 tilt=0.75
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST" && feature=="auctExpMoveATR" && value>=3.000000) return 0.7000; // lift=+0.067 p=0.0320 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.316500) return 0.7500; // lift=+0.026 p=0.0320 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctBalance" && value<=0.640000) return 0.7000; // lift=+0.038 p=0.0320 tilt=0.70
   if(symbol=="GBPCADm" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=153.300000) return 0.7500; // lift=+0.029 p=0.0320 tilt=0.75
   if(symbol=="GOOGLm" && setup=="BREAKOUT_RETEST" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.080 p=0.0320 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="msContext" && value>=0.470750) return 0.7000; // lift=+0.053 p=0.0320 tilt=0.70
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.936000) return 0.7000; // lift=+0.057 p=0.0320 tilt=0.70
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="ofFlowIntensity" && value<=0.346000) return 0.7000; // lift=+0.054 p=0.0320 tilt=0.70
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.371000) return 0.7000; // lift=+0.066 p=0.0320 tilt=0.70
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpVAL" && value<=-1.205630) return 0.6000; // lift=+0.072 p=0.0320 tilt=0.60
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpCompVAL" && value<=-5.097951) return 0.6000; // lift=+0.072 p=0.0320 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.746000) return 0.7000; // lift=+0.038 p=0.0320 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctRegimeConf" && value<=0.738000) return 0.7500; // lift=+0.033 p=0.0340 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.335000) return 0.7000; // lift=+0.039 p=0.0340 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="vpDistToLVN" && value<=0.346000) return 0.7500; // lift=+0.023 p=0.0340 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="auctExpReward" && value<=0.948000) return 0.7500; // lift=+0.022 p=0.0340 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.321667) return 0.7500; // lift=+0.021 p=0.0340 tilt=0.75
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.285000) return 0.7500; // lift=+0.029 p=0.0340 tilt=0.75
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.408000) return 0.7500; // lift=+0.029 p=0.0340 tilt=0.75
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.000111) return 0.7500; // lift=+0.023 p=0.0340 tilt=0.75
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCDir" && value>=0.755000) return 0.7500; // lift=+0.021 p=0.0340 tilt=0.75
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.092200) return 0.7500; // lift=+0.031 p=0.0340 tilt=0.75
   if(symbol=="USDCHFm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=0.003009) return 0.7000; // lift=+0.036 p=0.0340 tilt=0.70
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=93.650000) return 0.7000; // lift=+0.051 p=0.0340 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="US30m" && setup=="NAKED_POC" && feature=="ofContext" && value<=0.317167) return 0.7000; // lift=+0.040 p=0.0340 tilt=0.70
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="vpPOC" && value<=-11.110279) return 0.7000; // lift=+0.055 p=0.0340 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && feature=="auctHVNStrength" && value<=0.836000) return 0.7500; // lift=+0.024 p=0.0340 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="PULLBACK" && feature=="auctLVNStrength" && value<=0.899000) return 0.7500; // lift=+0.025 p=0.0340 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCSlope" && value>=0.107100) return 0.7000; // lift=+0.036 p=0.0340 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION" && feature=="vpPriceVsPOC" && value>=0.183850) return 0.7500; // lift=+0.022 p=0.0340 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpCompVAH" && value<=0.374138) return 0.7500; // lift=+0.033 p=0.0340 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USOILm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.321167) return 0.7500; // lift=+0.033 p=0.0340 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION" && feature=="vpVAOverlapRatio" && value<=0.459000) return 0.7500; // lift=+0.023 p=0.0340 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.482400) return 0.7500; // lift=+0.033 p=0.0340 tilt=0.75
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.382000) return 0.7000; // lift=+0.035 p=0.0340 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.019800) return 0.7000; // lift=+0.039 p=0.0340 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="auctHVNStrength" && value<=0.850000) return 0.7000; // lift=+0.040 p=0.0340 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.370000) return 0.7000; // lift=+0.038 p=0.0340 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpCompVAL" && value<=-4.814032) return 0.7500; // lift=+0.029 p=0.0340 tilt=0.75
   if(symbol=="XAUEURm" && setup=="PULLBACK" && feature=="auctExpMoveATR" && value>=3.000000) return 0.7000; // lift=+0.039 p=0.0340 tilt=0.70
   if(symbol=="EURAUDm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.677000) return 0.7500; // lift=+0.027 p=0.0340 tilt=0.75
   if(symbol=="EURCHFm" && setup=="MEAN_REVERSION" && feature=="vpVAL" && value<=-0.001355) return 0.7000; // lift=+0.045 p=0.0340 tilt=0.70
   if(symbol=="EURCHFm" && setup=="BREAKOUT" && feature=="auctAcceptance" && value>=0.413000) return 0.7500; // lift=+0.033 p=0.0340 tilt=0.75
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="vpDistToHVN" && value<=0.156000) return 0.7500; // lift=+0.027 p=0.0340 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctBalance" && value<=0.664000) return 0.7500; // lift=+0.031 p=0.0340 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION" && feature=="atrProxy" && value>=142.900000) return 0.7500; // lift=+0.031 p=0.0340 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="vpDistToHVN" && value<=0.159000) return 0.7500; // lift=+0.022 p=0.0340 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="auctContinuation" && value>=0.237000) return 0.7500; // lift=+0.022 p=0.0340 tilt=0.75
   if(symbol=="AAPLm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-2.706298) return 0.7000; // lift=+0.041 p=0.0340 tilt=0.70
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="vpLTTransitionScore" && value>=0.159000) return 0.7500; // lift=+0.031 p=0.0340 tilt=0.75
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="vpLTBalanceStability" && value<=0.841000) return 0.7500; // lift=+0.031 p=0.0340 tilt=0.75
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.272597) return 0.7000; // lift=+0.043 p=0.0340 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.730000) return 0.7000; // lift=+0.055 p=0.0340 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="auctExhaustion" && value<=0.273000) return 0.7000; // lift=+0.053 p=0.0340 tilt=0.70
   if(symbol=="JPMm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.407000) return 0.7000; // lift=+0.056 p=0.0340 tilt=0.70
   if(symbol=="METAm" && setup=="NAKED_POC" && feature=="vpCompVAH" && value<=5.213695) return 0.7000; // lift=+0.049 p=0.0340 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.000093) return 0.7500; // lift=+0.023 p=0.0360 tilt=0.75
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="vpVAL" && value<=-0.118809) return 0.7500; // lift=+0.023 p=0.0360 tilt=0.75
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="auctVAExpRate" && value>=0.000000) return 0.7000; // lift=+0.064 p=0.0360 tilt=0.70
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.439000) return 0.7500; // lift=+0.025 p=0.0360 tilt=0.75
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctReversalRisk" && value<=0.140000) return 0.7000; // lift=+0.035 p=0.0360 tilt=0.70
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.037 p=0.0360 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.073 p=0.0360 tilt=0.60
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="auctExpReward" && value<=1.109000) return 0.7000; // lift=+0.042 p=0.0360 tilt=0.70
   if(symbol=="US30m" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.299000) return 0.7000; // lift=+0.046 p=0.0360 tilt=0.70
   if(symbol=="US30m" && setup=="BREAKOUT" && feature=="auctContinuation" && value>=0.247000) return 0.7000; // lift=+0.036 p=0.0360 tilt=0.70
   if(symbol=="US30m" && setup=="PULLBACK" && feature=="smZoneQuality" && value>=0.974000) return 0.7500; // lift=+0.029 p=0.0360 tilt=0.75
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK" && feature=="vpVAOverlapRatio" && value<=0.479000) return 0.7000; // lift=+0.055 p=0.0360 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="BREAKOUT" && feature=="vpCompPOC" && value<=-0.296541) return 0.7500; // lift=+0.028 p=0.0360 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="PULLBACK" && feature=="auctLVNStrength" && value<=0.898000) return 0.7500; // lift=+0.022 p=0.0360 tilt=0.75
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="vpCompVAH" && value<=0.340744) return 0.7000; // lift=+0.041 p=0.0360 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT" && feature=="vpVAH" && value<=-0.034790) return 0.7500; // lift=+0.023 p=0.0360 tilt=0.75
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="smZoneQuality" && value>=1.017000) return 0.7500; // lift=+0.024 p=0.0360 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.032 p=0.0360 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.283000) return 0.7500; // lift=+0.029 p=0.0360 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.676000) return 0.7500; // lift=+0.032 p=0.0360 tilt=0.75
   if(symbol=="USDCADm" && setup=="PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.025 p=0.0360 tilt=0.75
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.363000) return 0.7000; // lift=+0.037 p=0.0360 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="smContext" && value<=0.400400) return 0.7000; // lift=+0.039 p=0.0360 tilt=0.70
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST" && feature=="vpDevPOCSlope" && value>=0.160250) return 0.7000; // lift=+0.038 p=0.0360 tilt=0.70
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="auctExpReward" && value<=0.900000) return 0.7500; // lift=+0.032 p=0.0360 tilt=0.75
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationConf" && value>=0.825000) return 0.7000; // lift=+0.035 p=0.0360 tilt=0.70
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.673284) return 0.7500; // lift=+0.034 p=0.0360 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="smContext" && value<=0.378000) return 0.7500; // lift=+0.021 p=0.0360 tilt=0.75
   if(symbol=="EURAUDm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.001119) return 0.7500; // lift=+0.026 p=0.0360 tilt=0.75
   if(symbol=="EURCHFm" && setup=="NAKED_POC" && feature=="auctAcceptance" && value>=0.372000) return 0.6000; // lift=+0.076 p=0.0360 tilt=0.60
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.375000) return 0.7000; // lift=+0.038 p=0.0360 tilt=0.70
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="vpLTTransitionScore" && value>=0.047000) return 0.7500; // lift=+0.031 p=0.0360 tilt=0.75
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="vpLTBalanceStability" && value<=0.953000) return 0.7500; // lift=+0.031 p=0.0360 tilt=0.75
   if(symbol=="EURGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAL" && value<=-0.000410) return 0.7000; // lift=+0.036 p=0.0360 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAL" && value<=-0.001133) return 0.7000; // lift=+0.037 p=0.0360 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpMigrationConf" && value>=0.800000) return 0.7000; // lift=+0.037 p=0.0360 tilt=0.70
   if(symbol=="AAPLm" && setup=="TREND_CONTINUATION" && feature=="auctBalance" && value<=0.665500) return 0.7500; // lift=+0.033 p=0.0360 tilt=0.75
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.296000) return 0.7000; // lift=+0.047 p=0.0360 tilt=0.70
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.290500) return 0.7000; // lift=+0.067 p=0.0360 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK" && feature=="smContext" && value<=0.384300) return 0.7000; // lift=+0.066 p=0.0360 tilt=0.70
   if(symbol=="JPMm" && setup=="PULLBACK" && feature=="vpMigrationScore" && value>=0.825000) return 0.7000; // lift=+0.057 p=0.0360 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpDistCompPOC" && value>=0.036000) return 0.7000; // lift=+0.040 p=0.0360 tilt=0.70
   if(symbol=="METAm" && setup=="NAKED_POC" && feature=="msCompression" && value>=0.659500) return 0.7000; // lift=+0.049 p=0.0360 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="BREAKOUT_RETEST" && feature=="vpDistToHVN" && value<=0.090000) return 0.7500; // lift=+0.024 p=0.0380 tilt=0.75
   if(symbol=="BTCUSDm" && setup=="NAKED_POC" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.041 p=0.0380 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="ETHUSDm" && setup=="NAKED_POC" && feature=="liqContext" && value>=0.494000) return 0.7000; // lift=+0.053 p=0.0380 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.321333) return 0.7500; // lift=+0.024 p=0.0380 tilt=0.75
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=130.700000) return 0.7500; // lift=+0.026 p=0.0380 tilt=0.75
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-0.277618) return 0.7500; // lift=+0.032 p=0.0380 tilt=0.75
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompVAL" && value<=-0.648477) return 0.7000; // lift=+0.036 p=0.0380 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="auctContinuation" && value>=0.247000) return 0.7500; // lift=+0.032 p=0.0380 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="liqContext" && value>=0.455200) return 0.7000; // lift=+0.045 p=0.0380 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.057382) return 0.7500; // lift=+0.028 p=0.0380 tilt=0.75
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=-0.011289) return 0.7500; // lift=+0.024 p=0.0380 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCSlope" && value>=0.107900) return 0.7000; // lift=+0.036 p=0.0380 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST" && feature=="ofFlowIntensity" && value<=0.357000) return 0.7500; // lift=+0.033 p=0.0380 tilt=0.75
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.688000) return 0.7000; // lift=+0.041 p=0.0380 tilt=0.70
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.046 p=0.0380 tilt=0.70
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<=0.243000) return 0.7500; // lift=+0.030 p=0.0380 tilt=0.75
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION" && feature=="auctBalance" && value<=0.665000) return 0.7500; // lift=+0.030 p=0.0380 tilt=0.75
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.058 p=0.0380 tilt=0.70
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.470000) return 0.7000; // lift=+0.054 p=0.0380 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT" && feature=="auctLVNStrength" && value<=0.897000) return 0.7500; // lift=+0.031 p=0.0380 tilt=0.75
   if(symbol=="USTECm" && setup=="BREAKOUT" && feature=="msCompression" && value>=0.728000) return 0.7500; // lift=+0.033 p=0.0380 tilt=0.75
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && value>=0.018900) return 0.7000; // lift=+0.039 p=0.0380 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.186500) return 0.7500; // lift=+0.027 p=0.0380 tilt=0.75
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=2.299931) return 0.7000; // lift=+0.034 p=0.0380 tilt=0.70
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST" && feature=="auctRegimeConf" && value<=0.679000) return 0.7000; // lift=+0.037 p=0.0380 tilt=0.70
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.489000) return 0.7000; // lift=+0.037 p=0.0380 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="chochQuality")
   if(symbol=="EURGBPm" && setup=="PULLBACK" && feature=="chochQuality" && value>=0.000000) return 0.7000; // lift=+0.064 p=0.0380 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.896000) return 0.7500; // lift=+0.026 p=0.0380 tilt=0.75
   if(symbol=="NVDAm" && setup=="BREAKOUT" && feature=="vpVAH" && value<=-0.229851) return 0.7500; // lift=+0.026 p=0.0380 tilt=0.75
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL" && feature=="vpPOC" && value<=0.893532) return 0.7000; // lift=+0.049 p=0.0380 tilt=0.70
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL" && feature=="auctTradeQuality" && value>=0.375000) return 0.7000; // lift=+0.041 p=0.0380 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAH" && value<=1.668244) return 0.7000; // lift=+0.054 p=0.0380 tilt=0.70
   if(symbol=="MSFTm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.307019) return 0.7000; // lift=+0.036 p=0.0380 tilt=0.70
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.676000) return 0.7000; // lift=+0.049 p=0.0380 tilt=0.70
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="vpLTTrendDuration" && value<=0.000000) return 0.7000; // lift=+0.049 p=0.0380 tilt=0.70
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpDistToLVN" && value<=0.517000) return 0.6000; // lift=+0.073 p=0.0380 tilt=0.60
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpLTPOCVelocity" && value>=53.428700) return 0.6000; // lift=+0.073 p=0.0380 tilt=0.60
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="spreadToATR" && value>=0.226900) return 0.7000; // lift=+0.065 p=0.0380 tilt=0.70
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION" && feature=="atrProxy" && value>=47.700000) return 0.7000; // lift=+0.047 p=0.0380 tilt=0.70
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpDevPOCSlope" && value>=-0.023150) return 0.6000; // lift=+0.072 p=0.0380 tilt=0.60
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-3.650708) return 0.7000; // lift=+0.038 p=0.0380 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpLTPOCVelocity" && value>=355.628400) return 0.7000; // lift=+0.040 p=0.0380 tilt=0.70
   if(symbol=="METAm" && setup=="NAKED_POC" && feature=="spreadToATR" && value>=0.181550) return 0.7000; // lift=+0.049 p=0.0380 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.680000) return 0.7000; // lift=+0.038 p=0.0400 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && feature=="vpDailyPOC" && value<=-1.197602) return 0.7500; // lift=+0.022 p=0.0400 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExpMoveATR" && value>=3.000000) return 0.6000; // lift=+0.077 p=0.0400 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.319667) return 0.7500; // lift=+0.028 p=0.0400 tilt=0.75
   if(symbol=="EURUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.162000) return 0.7000; // lift=+0.039 p=0.0400 tilt=0.70
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="vpMigrationScore" && value>=0.755000) return 0.7500; // lift=+0.024 p=0.0400 tilt=0.75
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION" && feature=="auctContinuation" && value>=0.226000) return 0.7500; // lift=+0.024 p=0.0400 tilt=0.75
   if(symbol=="USDJPYm" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.069 p=0.0400 tilt=0.60
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpDailyPOC" && value<=-0.157476) return 0.7000; // lift=+0.036 p=0.0400 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=0.049957) return 0.7500; // lift=+0.024 p=0.0400 tilt=0.75
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION" && feature=="spreadToATR" && value>=0.095600) return 0.7500; // lift=+0.026 p=0.0400 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="BREAKOUT_RETEST" && feature=="vpPOC" && value<=-0.034443) return 0.7500; // lift=+0.030 p=0.0400 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.310667) return 0.7000; // lift=+0.038 p=0.0400 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="NAKED_POC" && feature=="spreadToATR" && value>=0.323700) return 0.7000; // lift=+0.057 p=0.0400 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="XAUAUDm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.322833) return 0.7500; // lift=+0.020 p=0.0400 tilt=0.75
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="auctExpMoveATR" && value>=3.000000) return 0.7000; // lift=+0.038 p=0.0400 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="smContext" && value<=0.401400) return 0.7000; // lift=+0.037 p=0.0400 tilt=0.70
   if(symbol=="XAGEURm" && setup=="BREAKOUT_RETEST" && feature=="smZoneQuality" && value>=0.935000) return 0.7500; // lift=+0.031 p=0.0400 tilt=0.75
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-3.419775) return 0.7500; // lift=+0.030 p=0.0400 tilt=0.75
   if(symbol=="US500m" && setup=="ANCHORED_PULLBACK" && feature=="vpLTTransitionScore" && value>=0.039000) return 0.7000; // lift=+0.046 p=0.0400 tilt=0.70
   if(symbol=="US500m" && setup=="ANCHORED_PULLBACK" && feature=="vpLTBalanceStability" && value<=0.961000) return 0.7000; // lift=+0.046 p=0.0400 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTPOCVelocity" && value>=3366.388300) return 0.7500; // lift=+0.034 p=0.0400 tilt=0.75
   if(symbol=="USDCADm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.001283) return 0.7500; // lift=+0.022 p=0.0400 tilt=0.75
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK" && feature=="auctTargetProb" && value<=0.422000) return 0.7000; // lift=+0.036 p=0.0400 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="vpCompVAL" && value<=-7.456114) return 0.7500; // lift=+0.031 p=0.0400 tilt=0.75
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.338000) return 0.7000; // lift=+0.052 p=0.0400 tilt=0.70
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.030 p=0.0400 tilt=0.75
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="auctReversalRisk" && value<=0.172000) return 0.7000; // lift=+0.036 p=0.0400 tilt=0.70
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpVAL" && value<=-1.118667) return 0.7500; // lift=+0.027 p=0.0400 tilt=0.75
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="auctExpReward" && value<=1.074000) return 0.7500; // lift=+0.028 p=0.0400 tilt=0.75
   if(symbol=="EURGBPm" && setup=="BREAKOUT" && feature=="auctContinuation" && value>=0.226000) return 0.7500; // lift=+0.024 p=0.0400 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="msContext" && value>=0.452125) return 0.7500; // lift=+0.025 p=0.0400 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.159000) return 0.7000; // lift=+0.042 p=0.0400 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTTransitionScore" && value>=0.160000) return 0.7000; // lift=+0.037 p=0.0400 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTBalanceStability" && value<=0.840000) return 0.7000; // lift=+0.037 p=0.0400 tilt=0.70
   if(symbol=="GBPCADm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.213600) return 0.7500; // lift=+0.022 p=0.0400 tilt=0.75
   if(symbol=="NVDAm" && setup=="SWEEP_REVERSAL" && feature=="ofFlowIntensity" && value<=0.359000) return 0.7000; // lift=+0.058 p=0.0400 tilt=0.70
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="auctContinuation" && value>=0.237000) return 0.7000; // lift=+0.044 p=0.0400 tilt=0.70
   if(symbol=="LMTm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompVAH" && value<=3.663822) return 0.6000; // lift=+0.077 p=0.0400 tilt=0.60
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.321750) return 0.7000; // lift=+0.064 p=0.0400 tilt=0.70
   if(symbol=="JPMm" && setup=="NAKED_POC" && feature=="vpDevPOCDir" && value>=-0.458250) return 0.6000; // lift=+0.072 p=0.0400 tilt=0.60
   if(symbol=="JPMm" && setup=="PULLBACK" && feature=="vpDevPOCDir" && value>=0.790000) return 0.7000; // lift=+0.056 p=0.0400 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpPOC" && value<=-1.033315) return 0.7000; // lift=+0.040 p=0.0400 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="vpPriceVsPOC" && value>=0.437100) return 0.7000; // lift=+0.040 p=0.0400 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="vpDistCompPOC" && value>=0.021000) return 0.7500; // lift=+0.022 p=0.0420 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="smContext" && value<=0.352200) return 0.7500; // lift=+0.024 p=0.0420 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.292000) return 0.7500; // lift=+0.033 p=0.0420 tilt=0.75
   if(symbol=="EURJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.033 p=0.0420 tilt=0.75
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="vpBestHVNScore" && value>=0.729000) return 0.7500; // lift=+0.025 p=0.0420 tilt=0.75
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="auctExhaustion" && value<=0.195000) return 0.7500; // lift=+0.023 p=0.0420 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST" && feature=="msContext" && value>=0.467500) return 0.7500; // lift=+0.026 p=0.0420 tilt=0.75
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="vpVAH" && value<=0.003361) return 0.7500; // lift=+0.029 p=0.0420 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.900000) return 0.7500; // lift=+0.025 p=0.0420 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="XAGGBPm" && setup=="NAKED_POC" && feature=="smContext" && value<=0.383200) return 0.7000; // lift=+0.057 p=0.0420 tilt=0.70
   if(symbol=="XAUGBPm" && setup=="MEAN_REVERSION" && feature=="vpCompVAH" && value<=0.377666) return 0.7500; // lift=+0.022 p=0.0420 tilt=0.75
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="vpPOC" && value<=0.104147) return 0.7000; // lift=+0.039 p=0.0420 tilt=0.70
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="auctExpMoveATR" && value>=3.000000) return 0.7000; // lift=+0.048 p=0.0420 tilt=0.70
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=-0.072981) return 0.7500; // lift=+0.030 p=0.0420 tilt=0.75
   if(symbol=="GBPCHFm" && setup=="MEAN_REVERSION" && feature=="auctFailure" && value<=0.150000) return 0.7000; // lift=+0.047 p=0.0420 tilt=0.70
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION" && feature=="auctVAExpRate" && value>=0.000000) return 0.6000; // lift=+0.143 p=0.0420 tilt=0.60
   if(symbol=="GBPAUDm" && setup=="PULLBACK" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.031 p=0.0420 tilt=0.75
   if(symbol=="USDCADm" && setup=="NAKED_POC" && feature=="vpMigrationScore" && value>=0.825000) return 0.6000; // lift=+0.082 p=0.0420 tilt=0.60
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.677000) return 0.7000; // lift=+0.043 p=0.0420 tilt=0.70
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="vpMigrationScore" && value>=0.790000) return 0.7500; // lift=+0.033 p=0.0420 tilt=0.75
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST" && feature=="auctTradeGrade" && value<=1.000000) return 0.7000; // lift=+0.052 p=0.0420 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.316833) return 0.7500; // lift=+0.026 p=0.0420 tilt=0.75
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST" && feature=="auctTargetProb" && value<=0.369000) return 0.7000; // lift=+0.043 p=0.0420 tilt=0.70
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION" && feature=="auctFailure" && value<=0.150000) return 0.7500; // lift=+0.031 p=0.0420 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExpReward" && value<=1.223500) return 0.7000; // lift=+0.040 p=0.0420 tilt=0.70
   if(symbol=="GBPUSDm" && setup=="NAKED_POC" && feature=="vpDistToLVN" && value<=0.294000) return 0.6000; // lift=+0.068 p=0.0420 tilt=0.60
   if(symbol=="GBPCADm" && setup=="ANCHORED_PULLBACK" && feature=="atrProxy" && value>=156.200000) return 0.7500; // lift=+0.031 p=0.0420 tilt=0.75
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION" && feature=="vpDailyPOC" && value<=-2.554960) return 0.7500; // lift=+0.031 p=0.0420 tilt=0.75
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK" && feature=="auctTradeQuality" && value>=0.419000) return 0.7000; // lift=+0.049 p=0.0420 tilt=0.70
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="vpMigrationScore" && value>=0.790000) return 0.7000; // lift=+0.044 p=0.0420 tilt=0.70
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpBestHVNScore" && value>=0.698000) return 0.6000; // lift=+0.072 p=0.0420 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="vpLTPOCVelocity" && value>=36.193800) return 0.7000; // lift=+0.048 p=0.0420 tilt=0.70
   if(symbol=="JPMm" && setup=="SWEEP_REVERSAL" && feature=="auctAcceptance" && value>=0.116000) return 0.7000; // lift=+0.063 p=0.0420 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.436300) return 0.7000; // lift=+0.036 p=0.0420 tilt=0.70
   if(symbol=="JPMm" && setup=="BREAKOUT" && feature=="auctBalance" && value<=0.631000) return 0.7000; // lift=+0.040 p=0.0420 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.041 p=0.0440 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAH" && value<=1.336496) return 0.7500; // lift=+0.023 p=0.0440 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.495000) return 0.7000; // lift=+0.041 p=0.0440 tilt=0.70
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION" && feature=="vpCompVAL" && value<=-3.477623) return 0.7500; // lift=+0.030 p=0.0440 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="ETHUSDm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.317667) return 0.7500; // lift=+0.023 p=0.0440 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="NAKED_POC" && feature=="auctExhaustion" && value<=0.268000) return 0.7000; // lift=+0.053 p=0.0440 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=0.000540) return 0.7500; // lift=+0.025 p=0.0440 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDevPOCDir" && value>=0.000000) return 0.7500; // lift=+0.025 p=0.0440 tilt=0.75
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctLVNStrength" && value<=0.908000) return 0.7000; // lift=+0.036 p=0.0440 tilt=0.70
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.031 p=0.0440 tilt=0.75
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="atrProxy" && value>=105.000000) return 0.7500; // lift=+0.029 p=0.0440 tilt=0.75
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpVAOverlapRatio" && value<=0.487500) return 0.7000; // lift=+0.050 p=0.0440 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="NAKED_POC" && feature=="vpBestHVNScore" && value>=0.740500) return 0.7000; // lift=+0.057 p=0.0440 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="liqContext" && value>=0.438900) return 0.7000; // lift=+0.037 p=0.0440 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && value>=0.376750) return 0.7500; // lift=+0.034 p=0.0440 tilt=0.75
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-0.232419) return 0.7500; // lift=+0.024 p=0.0440 tilt=0.75
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK" && feature=="ofFlowIntensity" && value<=0.379000) return 0.7000; // lift=+0.037 p=0.0440 tilt=0.70
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.673000) return 0.7000; // lift=+0.045 p=0.0440 tilt=0.70
   if(symbol=="US500m" && setup=="ANCHORED_PULLBACK" && feature=="vpDistCompPOC" && value>=0.028000) return 0.7000; // lift=+0.042 p=0.0440 tilt=0.70
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION" && feature=="vpDistToLVN" && value<=0.304000) return 0.7000; // lift=+0.040 p=0.0440 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.332667) return 0.7500; // lift=+0.034 p=0.0440 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="liqContext" && value>=0.473400) return 0.7000; // lift=+0.038 p=0.0440 tilt=0.70
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION" && feature=="vpVAH" && value<=-0.263957) return 0.7500; // lift=+0.022 p=0.0440 tilt=0.75
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="auctAcceptance" && value>=0.428000) return 0.7500; // lift=+0.020 p=0.0440 tilt=0.75
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="vpDistToLVN" && value<=0.310000) return 0.7500; // lift=+0.025 p=0.0440 tilt=0.75
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.031 p=0.0440 tilt=0.75
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST" && feature=="vpDistToHVN" && value<=0.120000) return 0.7500; // lift=+0.024 p=0.0440 tilt=0.75
   if(symbol=="EURAUDm" && setup=="ANCHORED_PULLBACK" && feature=="auctContinuation" && value>=0.247000) return 0.7000; // lift=+0.034 p=0.0440 tilt=0.70
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="auctExpReward" && value<=1.051000) return 0.7500; // lift=+0.021 p=0.0440 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.465800) return 0.7500; // lift=+0.025 p=0.0440 tilt=0.75
   if(symbol=="EURCHFm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.390000) return 0.7500; // lift=+0.033 p=0.0440 tilt=0.75
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.365000) return 0.7500; // lift=+0.027 p=0.0440 tilt=0.75
   if(symbol=="EURGBPm" && setup=="NAKED_POC" && feature=="vpLTTransitionScore" && value>=0.044000) return 0.6000; // lift=+0.093 p=0.0440 tilt=0.60
   if(symbol=="EURGBPm" && setup=="NAKED_POC" && feature=="vpLTBalanceStability" && value<=0.956000) return 0.6000; // lift=+0.093 p=0.0440 tilt=0.60
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctReversalRisk" && value<=0.140000) return 0.7000; // lift=+0.037 p=0.0440 tilt=0.70
   if(symbol=="XPTUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.306000) return 0.7500; // lift=+0.023 p=0.0440 tilt=0.75
   if(symbol=="GBPCADm" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.156000) return 0.7500; // lift=+0.020 p=0.0440 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="AAPLm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.313667) return 0.7000; // lift=+0.039 p=0.0440 tilt=0.70
   if(symbol=="NFLXm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTTransitionScore" && value>=0.157000) return 0.7000; // lift=+0.052 p=0.0440 tilt=0.70
   if(symbol=="NFLXm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTBalanceStability" && value<=0.843000) return 0.7000; // lift=+0.052 p=0.0440 tilt=0.70
   if(symbol=="EBAYm" && setup=="BREAKOUT_RETEST" && feature=="msCompression" && value>=0.714000) return 0.7000; // lift=+0.051 p=0.0440 tilt=0.70
   if(symbol=="GOOGLm" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=-0.904391) return 0.7000; // lift=+0.042 p=0.0440 tilt=0.70
   if(symbol=="GOOGLm" && setup=="NAKED_POC" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.125 p=0.0440 tilt=0.60
   if(symbol=="METAm" && setup=="BREAKOUT" && feature=="vpLTPOCVelocity" && value>=10.653500) return 0.7500; // lift=+0.025 p=0.0440 tilt=0.75
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.490000) return 0.7500; // lift=+0.027 p=0.0460 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="vpDistToHVN" && value<=0.107000) return 0.7500; // lift=+0.023 p=0.0460 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="NAKED_POC" && feature=="ofFlowIntensity" && value<=0.358000) return 0.7000; // lift=+0.054 p=0.0460 tilt=0.70
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctAcceptance" && value>=0.624000) return 0.7500; // lift=+0.024 p=0.0460 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION" && feature=="auctContinuation" && value>=0.226000) return 0.7500; // lift=+0.023 p=0.0460 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="PULLBACK" && feature=="vpVAL" && value<=-0.000788) return 0.7500; // lift=+0.023 p=0.0460 tilt=0.75
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && feature=="vpDistToLVN" && value<=0.336000) return 0.7500; // lift=+0.020 p=0.0460 tilt=0.75
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpDistToLVN" && value<=0.327000) return 0.7000; // lift=+0.035 p=0.0460 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION" && feature=="smContext" && value<=0.393800) return 0.7500; // lift=+0.025 p=0.0460 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="ofContext" && value<=0.324667) return 0.7500; // lift=+0.026 p=0.0460 tilt=0.75
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpLTPOCVelocity" && value>=122.610950) return 0.7000; // lift=+0.041 p=0.0460 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="smZoneQuality" && value>=0.910000) return 0.7500; // lift=+0.029 p=0.0460 tilt=0.75
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION" && feature=="auctReversalRisk" && value<=0.140000) return 0.7500; // lift=+0.020 p=0.0460 tilt=0.75
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.045 p=0.0460 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="NAKED_POC" && feature=="spreadToATR" && value>=0.253600) return 0.6000; // lift=+0.101 p=0.0460 tilt=0.60
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapRatio" && value<=0.476000) return 0.7000; // lift=+0.037 p=0.0460 tilt=0.70
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAL" && value<=-0.237853) return 0.7000; // lift=+0.039 p=0.0460 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION" && feature=="vpPOC" && value<=0.063569) return 0.7500; // lift=+0.027 p=0.0460 tilt=0.75
   if(symbol=="USOILm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.389000) return 0.7500; // lift=+0.030 p=0.0460 tilt=0.75
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.678000) return 0.7000; // lift=+0.044 p=0.0460 tilt=0.70
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="auctRegimeConf" && value<=0.675000) return 0.7000; // lift=+0.037 p=0.0460 tilt=0.70
   if(symbol=="US500m" && setup=="MEAN_REVERSION" && feature=="auctTargetProb" && value<=0.409000) return 0.7000; // lift=+0.039 p=0.0460 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDCADm" && setup=="NAKED_POC" && feature=="ofContext" && value<=0.320667) return 0.7000; // lift=+0.064 p=0.0460 tilt=0.70
   if(symbol=="USTECm" && setup=="MEAN_REVERSION" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.042 p=0.0460 tilt=0.70
   if(symbol=="USTECm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.369000) return 0.7500; // lift=+0.030 p=0.0460 tilt=0.75
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="auctTradeQuality" && value>=0.425000) return 0.7500; // lift=+0.030 p=0.0460 tilt=0.75
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="vpDistToLVN" && value<=0.307000) return 0.7500; // lift=+0.027 p=0.0460 tilt=0.75
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION" && feature=="msCompression" && value>=0.769000) return 0.7500; // lift=+0.023 p=0.0460 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURAUDm" && setup=="BREAKOUT" && feature=="ofContext" && value<=0.321667) return 0.7500; // lift=+0.021 p=0.0460 tilt=0.75
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION" && feature=="auctExhaustion" && value<=0.284000) return 0.7500; // lift=+0.030 p=0.0460 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAOverlapRatio" && value<=0.500000) return 0.7000; // lift=+0.037 p=0.0460 tilt=0.70
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION" && feature=="vpCompVAL" && value<=-8.801162) return 0.7500; // lift=+0.031 p=0.0460 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="NVDAm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.300167) return 0.7000; // lift=+0.058 p=0.0460 tilt=0.70
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="auctTradeQuality" && value>=0.398000) return 0.7000; // lift=+0.043 p=0.0460 tilt=0.70
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION" && feature=="auctBalance" && value<=0.643000) return 0.7000; // lift=+0.050 p=0.0460 tilt=0.70
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION" && feature=="vpDistCompPOC" && value>=0.033000) return 0.7000; // lift=+0.037 p=0.0460 tilt=0.70
   if(symbol=="METAm" && setup=="MEAN_REVERSION" && feature=="vpPriceVsPOC" && value>=-0.661900) return 0.7000; // lift=+0.037 p=0.0460 tilt=0.70
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION" && feature=="auctAcceptance" && value>=0.271000) return 0.7500; // lift=+0.025 p=0.0480 tilt=0.75
   if(symbol=="BTCUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctHVNStrength" && value<=0.851000) return 0.7500; // lift=+0.033 p=0.0480 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.000214) return 0.7500; // lift=+0.027 p=0.0480 tilt=0.75
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.286500) return 0.7500; // lift=+0.029 p=0.0480 tilt=0.75
   if(symbol=="EURUSDm" && setup=="BREAKOUT" && feature=="auctExhaustion" && value<=0.245000) return 0.7500; // lift=+0.024 p=0.0480 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="EURUSDm" && setup=="SWEEP_REVERSAL" && feature=="ofContext" && value<=0.317833) return 0.7000; // lift=+0.035 p=0.0480 tilt=0.70
   if(symbol=="USDJPYm" && setup=="BREAKOUT_RETEST" && feature=="vpDailyPOC" && value<=-0.161075) return 0.7500; // lift=+0.031 p=0.0480 tilt=0.75
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK" && feature=="vpCompPOC" && value<=-0.244625) return 0.7000; // lift=+0.036 p=0.0480 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.690000) return 0.7000; // lift=+0.041 p=0.0480 tilt=0.70
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST" && feature=="auctReversalRisk" && value<=0.140000) return 0.7500; // lift=+0.029 p=0.0480 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST" && feature=="liqContext" && value>=0.483900) return 0.7500; // lift=+0.027 p=0.0480 tilt=0.75
   if(symbol=="USDCHFm" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.370000) return 0.7000; // lift=+0.043 p=0.0480 tilt=0.70
   if(symbol=="US30m" && setup=="BREAKOUT" && feature=="auctExpReward" && value<=0.631000) return 0.7500; // lift=+0.034 p=0.0480 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="PULLBACK" && feature=="auctTradeQuality" && value>=0.425000) return 0.7500; // lift=+0.026 p=0.0480 tilt=0.75
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.044 p=0.0480 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL" && feature=="vpMigrationConf" && value>=0.800000) return 0.7500; // lift=+0.033 p=0.0480 tilt=0.75
   if(symbol=="XAUAUDm" && setup=="BREAKOUT" && feature=="auctReversalRisk" && value<=0.140000) return 0.7500; // lift=+0.020 p=0.0480 tilt=0.75
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<=0.332000) return 0.7000; // lift=+0.042 p=0.0480 tilt=0.70
   if(symbol=="USOILm" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.902000) return 0.7000; // lift=+0.035 p=0.0480 tilt=0.70
   if(symbol=="USOILm" && setup=="ANCHORED_PULLBACK" && feature=="auctBalance" && value<=0.624500) return 0.7000; // lift=+0.036 p=0.0480 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="smContext")
   if(symbol=="USOILm" && setup=="BREAKOUT_RETEST" && feature=="smContext" && value<=0.401200) return 0.7500; // lift=+0.033 p=0.0480 tilt=0.75
   if(symbol=="XAGEURm" && setup=="PULLBACK" && feature=="vpPriceVsPOC" && value>=0.182550) return 0.7500; // lift=+0.024 p=0.0480 tilt=0.75
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION" && feature=="vpCompPOC" && value<=-0.291472) return 0.7500; // lift=+0.022 p=0.0480 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK" && feature=="vpDistToLVN" && value<=0.239000) return 0.7500; // lift=+0.034 p=0.0480 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION" && feature=="auctLVNStrength" && value<=0.901000) return 0.7500; // lift=+0.024 p=0.0480 tilt=0.75
   if(symbol=="USDCADm" && setup=="PULLBACK" && feature=="auctTradeQuality" && value>=0.423000) return 0.7500; // lift=+0.021 p=0.0480 tilt=0.75
   if(symbol=="USDCADm" && setup=="TREND_CONTINUATION" && feature=="auctTargetProb" && value<=0.388000) return 0.7500; // lift=+0.023 p=0.0480 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="ofContext" && value<=0.317000) return 0.7500; // lift=+0.033 p=0.0480 tilt=0.75
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST" && feature=="spreadToATR" && value>=0.035700) return 0.7500; // lift=+0.033 p=0.0480 tilt=0.75
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctTargetProb" && value<=0.428000) return 0.7000; // lift=+0.051 p=0.0480 tilt=0.70
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="auctLVNStrength" && value<=0.902000) return 0.7500; // lift=+0.034 p=0.0480 tilt=0.75
   if(symbol=="FR40m" && setup=="BREAKOUT" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7500; // lift=+0.027 p=0.0480 tilt=0.75
   if(symbol=="FR40m" && setup=="PULLBACK" && feature=="vpDistToLVN" && value<=0.314000) return 0.7500; // lift=+0.027 p=0.0480 tilt=0.75
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.026 p=0.0480 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="liqContext")
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION" && feature=="liqContext" && value>=0.498000) return 0.7500; // lift=+0.020 p=0.0480 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="NAKED_POC" && feature=="ofFlowIntensity" && value<=0.368000) return 0.6000; // lift=+0.068 p=0.0480 tilt=0.60
   if(symbol=="GBPCADm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.684000) return 0.7500; // lift=+0.029 p=0.0480 tilt=0.75
   if(symbol=="NFLXm" && setup=="MEAN_REVERSION" && feature=="auctExpReward" && value<=0.645500) return 0.7000; // lift=+0.039 p=0.0480 tilt=0.70
   if(symbol=="MSFTm" && setup=="BREAKOUT" && feature=="auctExpReward" && value<=0.826000) return 0.7000; // lift=+0.036 p=0.0480 tilt=0.70
   if(symbol=="LMTm" && setup=="PULLBACK" && feature=="vpCompVAL" && value<=-5.860493) return 0.7000; // lift=+0.065 p=0.0480 tilt=0.70
   if(symbol=="GOOGLm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.668000) return 0.7000; // lift=+0.066 p=0.0480 tilt=0.70
   if(symbol=="METAm" && setup=="PULLBACK" && feature=="auctExhaustion" && value<=0.240000) return 0.7000; // lift=+0.034 p=0.0480 tilt=0.70
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL" && feature=="auctFailure" && value<=0.150000) return 0.7000; // lift=+0.055 p=0.0480 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="msContext")
   if(symbol=="BTCUSDm" && setup=="BREAKOUT_RETEST" && feature=="msContext" && value>=0.464500) return 0.7500; // lift=+0.022 p=0.0500 tilt=0.75
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="ETHUSDm" && setup=="PULLBACK" && feature=="ofContext" && value<=0.321500) return 0.7500; // lift=+0.021 p=0.0500 tilt=0.75
   if(symbol=="ETHUSDm" && setup=="NAKED_POC" && feature=="auctVAExpRate" && value>=0.000000) return 0.6000; // lift=+0.082 p=0.0500 tilt=0.60
   if(symbol=="EURUSDm" && setup=="PULLBACK" && feature=="vpMigrationScore" && value>=0.755000) return 0.7500; // lift=+0.021 p=0.0500 tilt=0.75
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctRegimeConf" && value<=0.708000) return 0.7500; // lift=+0.029 p=0.0500 tilt=0.75
   if(symbol=="USDJPYm" && setup=="BREAKOUT" && feature=="vpCompVAH" && value<=0.039989) return 0.7500; // lift=+0.026 p=0.0500 tilt=0.75
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.041 p=0.0500 tilt=0.70
   if(symbol=="USDCHFm" && setup=="TREND_CONTINUATION" && feature=="vpPOC" && value<=-0.000120) return 0.7000; // lift=+0.039 p=0.0500 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION" && feature=="ofContext" && value<=0.319833) return 0.7000; // lift=+0.043 p=0.0500 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION" && feature=="auctTradeQuality" && value>=0.428000) return 0.7000; // lift=+0.035 p=0.0500 tilt=0.70
   if(symbol=="XAGUSDm" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>=0.182350) return 0.7000; // lift=+0.037 p=0.0500 tilt=0.70
   if(symbol=="XAUAUDm" && setup=="NAKED_POC" && feature=="vpCompPOC" && value<=-0.109672) return 0.6000; // lift=+0.074 p=0.0500 tilt=0.60
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.028 p=0.0500 tilt=0.75
   if(symbol=="XAUGBPm" && setup=="MEAN_REVERSION" && feature=="ofFlowIntensity" && value<=0.360000) return 0.7500; // lift=+0.022 p=0.0500 tilt=0.75
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL" && feature=="vpVAH" && value<=0.158351) return 0.7000; // lift=+0.039 p=0.0500 tilt=0.70
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="vpDailyPOC" && value<=-2.196870) return 0.7500; // lift=+0.030 p=0.0500 tilt=0.75
   if(symbol=="US500m" && setup=="PULLBACK" && feature=="ofFlowIntensity" && value<=0.374000) return 0.7500; // lift=+0.030 p=0.0500 tilt=0.75
   if(symbol=="US500m" && setup=="BREAKOUT" && feature=="auctTargetProb" && value<=0.400000) return 0.7500; // lift=+0.027 p=0.0500 tilt=0.75
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION" && feature=="vpLTPOCMigration" && value>=1.000000) return 0.7500; // lift=+0.029 p=0.0500 tilt=0.75
   if(symbol=="USDCADm" && setup=="PULLBACK" && feature=="auctTargetProb" && value<=0.392000) return 0.7500; // lift=+0.021 p=0.0500 tilt=0.75
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL" && feature=="vpThinnessRatio" && value>=0.500000) return 0.7000; // lift=+0.040 p=0.0500 tilt=0.70
   if(symbol=="STOXX50m" && setup=="PULLBACK" && feature=="vpPOC" && value<=-0.898075) return 0.7500; // lift=+0.021 p=0.0500 tilt=0.75
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION" && feature=="auctLVNStrength" && value<=0.906000) return 0.7500; // lift=+0.024 p=0.0500 tilt=0.75
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK" && feature=="auctReversalRisk" && value<=0.140000) return 0.7500; // lift=+0.023 p=0.0500 tilt=0.75
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL" && feature=="auctHVNStrength" && value<=0.838000) return 0.7500; // lift=+0.033 p=0.0500 tilt=0.75
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctRegimeConf" && value<=0.680000) return 0.7000; // lift=+0.042 p=0.0500 tilt=0.70
   // COMPOSITE: requires EA VPFunnelLogger v2+ (feature="ofContext")
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<=0.323833) return 0.7500; // lift=+0.032 p=0.0500 tilt=0.75
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION" && feature=="vpVAL" && value<=-0.001264) return 0.7500; // lift=+0.022 p=0.0500 tilt=0.75
   if(symbol=="AAPLm" && setup=="PULLBACK" && feature=="vpVAH" && value<=0.325479) return 0.7000; // lift=+0.037 p=0.0500 tilt=0.70
   if(symbol=="AAPLm" && setup=="PULLBACK" && feature=="vpCompVAH" && value<=1.054242) return 0.7000; // lift=+0.037 p=0.0500 tilt=0.70
   if(symbol=="LMTm" && setup=="MEAN_REVERSION" && feature=="atrProxy" && value>=263.100000) return 0.7000; // lift=+0.061 p=0.0500 tilt=0.70
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST" && feature=="vpCompPOC" && value<=-0.506232) return 0.6000; // lift=+0.073 p=0.0500 tilt=0.60
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="vpLTTrendDuration" && value<=0.100000) return 0.6000; // lift=+0.074 p=0.0500 tilt=0.60
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="auctTradeGrade" && value<=1.000000) return 0.6000; // lift=+0.085 p=0.0500 tilt=0.60
   if(symbol=="GOOGLm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<=0.655000) return 0.7000; // lift=+0.067 p=0.0500 tilt=0.70
   if(symbol=="GOOGLm" && setup=="SWEEP_REVERSAL" && feature=="atrProxy" && value>=128.350000) return 0.7000; // lift=+0.066 p=0.0500 tilt=0.70
   if(symbol=="METAm" && setup=="MEAN_REVERSION" && feature=="vpVAH" && value<=1.614433) return 0.7000; // lift=+0.037 p=0.0500 tilt=0.70
   return 1.0;
}

// 3. Regime blocking -- stub
bool VPIsBlocked(const string symbol, const string setup, int regime)
{ return false; }

// 4. SL risk multiplier -- stub
double VPGetSLRiskMultiplier(const string symbol, const string setup,
                              const string feature, double value)
{ return 1.0; }

// 5. Symbol blocking -- stub
bool VPIsSymbolBlocked(const string symbol)
{ return false; }

// 6. Lot multiplier -- stub
double VPGetLotMultiplier(const string symbol, const string setup)
{ return 1.0; }

// 7. Trigger enable/disable per symbol -- stub (always enabled)
// Preserves architecture for future per-symbol/setup trigger control.
bool VPIsTriggerEnabled(const string symbol, int setupType)
{
   return true; // all triggers enabled by default
}

// 8. Bad-entry filter -- 322 group blocks + 57 global fallback rules [RESEARCH]
// 8b. Bad-entry vote function — 322 symbol/setup groups, block if votes >= 2
// Derived from L10 canary analysis: sl_count >= 2 across 3 trailing styles.
//
// Usage (call once per feature, then check):
//   VPBadEntryVote("__reset__", sym, setup, feat, 0);  // start of signal
//   VPBadEntryVote("__vote__",  sym, setup, feat, val); // each feature
//   bool bad = VPBadEntryVote("__check__", sym, setup, feat, 0); // query
int _g_bev_votes  = 0;
string _g_bev_sym = "";
string _g_bev_stp = "";

bool VPBadEntryVote(const string cmd, const string symbol, const string setup,
                    const string feat, double val)
{
   if(cmd == "__reset__")
   {
      _g_bev_votes = 0;
      _g_bev_sym   = symbol;
      _g_bev_stp   = setup;
      return false;
   }
   if(cmd == "__check__")
      return (_g_bev_votes >= 1);
   // cmd == "__vote__" -- check feature against per-group rules
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.507000 && val<=0.904600) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.000953 && val<=0.000880) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000110 && val<=0.001494) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001487 && val<=-0.000068) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.014000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.056000 && val<=0.380300) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.647130 && val<=0.570730) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.001660 && val<=0.001211) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.003534 && val<=0.001830) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.787000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.780000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.627000 && val<=0.718000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.337000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.288900) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.703700) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.209700 && val<=0.335000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.627500) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.277317) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.140320) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.566700 && val<=0.854000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.489227 && val<=1.236132) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.995049) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.280874 && val<=2.118699) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.225764 && val<=0.552413) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.045700 && val<=0.340000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.803920 && val<=-0.337400) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-2.627022) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.211618 && val<=2.180867) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-1.606806) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.797000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.357000 && val<=0.633300) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.250560) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.783000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.632000 && val<=0.723000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.818100) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.278900) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.656800) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.271000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.791000 && val<=0.897000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.875000 && val<=0.940000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.997000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.366925 && val<=0.465000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.045000) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=1.236833 && val<=1.554271) _g_bev_votes++;
      if(feat=="vpVAH" && val<=1.431914) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.687307 && val<=2.420695) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.260642 && val<=0.864723) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.013000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.181500 && val<=0.511000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.999600 && val<=-0.803900) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.721788 && val<=2.512783) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.797000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.026000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.784500) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.819000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.645500 && val<=0.745000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.507000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.355000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.822000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.446000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.363750 && val<=0.390125) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.397500 && val<=0.480300) _g_bev_votes++;
      if(feat=="smContext" && val>=0.366100) _g_bev_votes++;
      if(feat=="atrProxy" && val<=29653.900000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.065000) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="auctAcceptance" && val>=0.814200) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.328000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.534200 && val<=0.896600) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.353534 && val<=1.073608) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.886398) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.147555 && val<=1.945784) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.416030 && val<=0.409281) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.012000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.038000 && val<=0.285800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.730560 && val<=-0.286400) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.111918 && val<=1.859061) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-7.126627) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-1.920484) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.806000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.468800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.789000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.635200 && val<=0.727000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.822000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.653000 && val<=0.751000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.502000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.271400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.646000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.140400) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.807000 && val<=0.906000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.293333 && val<=0.326967) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.436000 && val<=0.514920) _g_bev_votes++;
      if(feat=="smContext" && val>=0.373440 && val<=0.391000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=1507.960000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.104560) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.548360) _g_bev_votes++;
      if(feat=="vpPOC" && val<=0.186878) _g_bev_votes++;
      if(feat=="vpPOC" && val>=1.167708 && val<=1.396256) _g_bev_votes++;
      if(feat=="vpVAH" && val<=1.206797) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.557070 && val<=2.345770) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.100917 && val<=0.729541) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.949100 && val<=-0.801300) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-2.221207) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.364195 && val<=2.171005) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-6.377664) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-1.218847) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-10.737532) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.648000 && val<=0.710000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.815600) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.232420) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.102720 && val<=0.080480) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.600000 && val<=0.857800) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.059000 && val<=0.226400) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.793800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.627000 && val<=0.728000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.827800) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.509000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.355000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.808000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.412000 && val<=0.441000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.284000 && val<=0.382000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.801000 && val<=0.905000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.451000 && val<=0.797000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.363250 && val<=0.393200) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.338000 && val<=0.421000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.402160 && val<=0.491160) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.041800) _g_bev_votes++;
      if(feat=="smContext" && val>=0.371800 && val<=0.389800) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.104680) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="msCompression" && val>=0.577000 && val<=0.889000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.687455 && val<=0.040484) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.049889 && val<=-0.469015) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-5.097122 && val<=-0.189310) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-1.278929 && val<=4.346842) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.109000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.832000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.287000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.005000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.995000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.500000 && val<=1.900000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.403960) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.542200 && val<=0.894800) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000269 && val<=0.001140) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000821) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001111 && val<=0.002068) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000466 && val<=0.000368) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.017000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.056000 && val<=0.378700) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.184000 && val<=0.505000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.852370 && val<=-0.299300) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.781900) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.307300 && val<=0.605900) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.755000 && val<=0.644390) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.138310 && val<=0.075280) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.780000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.809300) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.502000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.311000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.768100) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.248000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.676000) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=0.505300 && val<=0.842100) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.001008 && val<=0.001400) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.001174) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001515 && val<=0.002330) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.000018 && val<=0.000652) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.070000 && val<=0.435400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.025800 && val<=-0.804530) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.801900) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.755000 && val<=0.615000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.034100) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.780000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.810000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.511000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.392000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.941100) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.445000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.048300 && val<=0.263700) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.736300 && val<=0.951700) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.355500) _g_bev_votes++;
      if(feat=="msContext" && val>=0.367250 && val<=0.384425) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.270667) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.229690) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000939 && val<=0.001465) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.001137) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001479 && val<=0.002617) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000066 && val<=0.000574) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.016000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.161100 && val<=-0.807700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000338 && val<=0.002354) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.801000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.086000 && val<=0.283800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.764300) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.502000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.361000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.855100) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.853100 && val<=0.924000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.007000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.993000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.348675) _g_bev_votes++;
      if(feat=="msContext" && val>=0.368500 && val<=0.411975) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.482000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.359000 && val<=0.457960) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.000329 && val<=0.000795) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.490940 && val<=0.205590) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000372 && val<=0.001435) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001169 && val<=0.000029) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.600000 && val<=0.827400) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.649400 && val<=0.766600) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.996000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.426860 && val<=0.520380) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=-0.000424) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=0.262990) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.001755 && val<=-0.001300) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000893 && val<=-0.000274) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001472) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002736 && val<=-0.001785) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.809200 && val<=1.094870) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002519 && val<=-0.000701) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.004535) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.007840) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.006915 && val<=-0.003098) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.784000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.072760 && val<=0.106270) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.386300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.915300) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.444000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.772000 && val<=0.887100) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.025000 && val<=0.083100) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.916900 && val<=0.975000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.632250) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpVAH" && val>=0.000332 && val<=0.001592) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.683180 && val<=0.211280) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.000407 && val<=0.000756) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001206 && val<=-0.000040) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.061000 && val<=0.420800) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.963800) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000910 && val<=0.001385) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.001905 && val<=0.002479) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.005466 && val<=-0.001023) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.800000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.778800) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.803000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.330000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.829000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.856000 && val<=0.928000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-468929.054100) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.535200 && val<=0.903000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.625000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.278667) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.812000 && val<=0.928000) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="PULLBACK")
   {
      if(feat=="vpDevPOCDir" && val>=-0.398000 && val<=0.790000) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001685 && val<=-0.000553) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.965800) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.005492) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.003490 && val<=0.001565) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.000015 && val<=0.005691) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.930000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.949200) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.996000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-489124.207040) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.332400 && val<=0.409000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.284500) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.557480) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpVAH" && val>=0.003418) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.001278 && val<=0.001100) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000040 && val<=0.001996) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001605 && val<=0.000311) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.021000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.085000 && val<=0.483000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.137000 && val<=0.517000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.913740 && val<=0.800220) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.001117 && val<=0.001546) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.001970 && val<=0.002458) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-0.012502) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.005767 && val<=-0.001081) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.692000 && val<=0.750000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.778000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.800800) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.500000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.386600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.912800) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.627500) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpVAL" && val>=-0.001751 && val<=-0.000485) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.410840 && val<=0.790000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.018220 && val<=0.151480) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.005493) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.930000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.924600) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.535000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.663400 && val<=1.200000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.308000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.996000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.284733) _g_bev_votes++;
      if(feat=="atrProxy" && val>=88.360000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.163140) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="msCompression" && val>=0.535000 && val<=0.831000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.058749 && val<=0.000413) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.011000) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.029212) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.151225 && val<=-0.063709) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.132900 && val<=0.240300) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.779000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.460000 && val<=0.786000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.768000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.616000 && val<=0.714000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.635000 && val<=0.747000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.900000 && val<=1.126000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.337000 && val<=0.391000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.169000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.216000 && val<=0.269000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.850000 && val<=0.923000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.457000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.543000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=8984.529000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.470000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.362167) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.030348 && val<=0.120214) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.080458) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.109897 && val<=0.205864) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.048767 && val<=0.040106) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.055400 && val<=0.390000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.878340 && val<=-0.312140) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.050447 && val<=0.173912) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.625400 && val<=0.723000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.807200) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.305000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.786400) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=9357.711840) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.296000 && val<=0.326833) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.175620) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.525000 && val<=0.901100) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000288 && val<=0.001225) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001174 && val<=0.002168) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000459 && val<=0.000436) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.065000 && val<=0.419100) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.842860 && val<=-0.257380) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000065 && val<=0.002143) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-0.011937) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.502300) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.471500) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.831700) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.774000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.798000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.633000 && val<=0.729000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.340000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.325300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.798900) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.325300) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.110000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.151000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.762300) _g_bev_votes++;
      if(feat=="msContext" && val>=0.613350) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.383740 && val<=0.476620) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="BREAKOUT")
   {
      if(feat=="vpCompPOC" && val<=-9.419739) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-4.255237) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.067000 && val<=0.462300) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.110540 && val<=5.237579) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.930000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.317000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.954000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.788000 && val<=0.901000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.738000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=377.440570) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.357175) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.277000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=3422.440000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.709380) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.551500 && val<=0.979000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.392100) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-1.042759 && val<=0.644187) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.077407 && val<=1.459806) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.702628 && val<=-0.264002) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.089000 && val<=0.531500) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.652550 && val<=0.648550) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-1.760046 && val<=1.190117) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.930000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.494000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.287500) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.710000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.106000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.210000 && val<=0.333500) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.274250) _g_bev_votes++;
      if(feat=="smContext" && val<=0.368200) _g_bev_votes++;
      if(feat=="atrProxy" && val>=3420.550000) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.483400) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-1.295628 && val<=1.032559) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.228562 && val<=1.727797) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.912684 && val<=-0.044170) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.021000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.098000 && val<=0.566400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.817300 && val<=0.805980) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-1.690668 && val<=1.365320) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-3.074780 && val<=2.344250) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.797000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.106880 && val<=0.125400) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.506800) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.772000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.803000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.618000 && val<=0.744000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.294000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.480600) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.335400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.832000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.153000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.125000 && val<=0.279000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.349000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.577600) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.404933) _g_bev_votes++;
      if(feat=="atrProxy" && val<=1156.880000) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.552000 && val<=0.882600) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000364 && val<=0.001205) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000881) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001171 && val<=0.002128) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000387 && val<=0.000409) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.067000 && val<=0.434600) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.875680 && val<=-0.376700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000284 && val<=0.002302) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-0.004254) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.000073) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-0.007469) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.784200) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.442600) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.784000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.631000 && val<=0.725000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.810000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.644000 && val<=0.740000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.501000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.438800) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.146000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.289000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.333000 && val<=0.400000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.338760) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.526200 && val<=0.840000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000171 && val<=0.001133) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000953 && val<=0.002173) _g_bev_votes++;
      if(feat=="vpVAL" && val<=-0.000899) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000558 && val<=0.000225) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.070000 && val<=0.402200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.982540 && val<=-0.360580) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.002305) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000162 && val<=0.002135) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.790600) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.770000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.793800) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.354000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.500800) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.455400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.142800) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.761000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.343000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.013800) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpCompVAL" && val<=-0.015494) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.001400) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.056000 && val<=0.398000) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.004646 && val<=-0.000403) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000970 && val<=0.003420) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.008513 && val<=-0.003391) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=0.032880) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-444168.153700) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=495342.029600) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-101285.349860 && val<=55463.589340) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=117.800000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.410560) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.000174) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000863) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000482) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.231460) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.001307 && val<=-0.000387) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000558 && val<=0.000345) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002276 && val<=-0.001237) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.063000 && val<=0.411300) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.232550 && val<=0.813610) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002096 && val<=-0.000103) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.006526) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.010129) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.001765) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.787100) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.818000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.498100) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.323700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.799600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.783700 && val<=0.896000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-679832.614490) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-193148.082410 && val<=95288.356420) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.934000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.331730) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.000821) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001295) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000149) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.804640) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.001654 && val<=-0.001288) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000913 && val<=-0.000086) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002709 && val<=-0.001669) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019600) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.071000 && val<=0.454000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.801800 && val<=1.028640) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002530 && val<=-0.000403) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.006824) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.010222) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.786000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.798400) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.650000 && val<=0.720000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.076060 && val<=0.106600) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.783400) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.505000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.375600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.897000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.453000 && val<=0.803600) _g_bev_votes++;
      if(feat=="msContext" && val>=0.633100) _g_bev_votes++;
      if(feat=="atrProxy" && val>=85.160000 && val<=115.320000) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="msCompression" && val>=0.534000 && val<=0.820000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.058764 && val<=0.001854) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.006639) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.112200 && val<=0.262950) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.773000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.957000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.356750) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.972000) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.536300 && val<=0.846000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.291100) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.040613 && val<=0.125942) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.088698) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.118608 && val<=0.215085) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.033289 && val<=0.045564) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.060000 && val<=0.412000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.913170 && val<=-0.421060) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.239823) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.005333 && val<=0.197817) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.146612) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.772000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.784000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.799000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.504000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.460700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.165600) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.257000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.950000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.953900) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.166720) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="msCompression" && val>=0.532700 && val<=0.836000) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.515894 && val<=-0.064311) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.872524 && val<=-0.401998) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.541800) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.309000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=5670.829440) _g_bev_votes++;
      if(feat=="smContext" && val<=0.388400) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.183780) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.000430 && val<=0.000145) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000165 && val<=0.000892) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000178) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.012000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.155320 && val<=0.196760) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002516 && val<=-0.000210) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-0.009476) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.794600) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.541800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.771000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.614000 && val<=0.713000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.636400 && val<=0.750000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.389400 && val<=0.449000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.225400) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.763000 && val<=1.113000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.611000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.060000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.256000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.366667) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.516000 && val<=0.888000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.285000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000250 && val<=0.001226) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001113 && val<=0.002170) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000464 && val<=0.000432) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.058000 && val<=0.388500) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.173000 && val<=0.506500) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.836550 && val<=-0.242450) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000255 && val<=0.002102) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.800500) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.675000 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.143000 && val<=0.500500) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777500) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.630000 && val<=0.729000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.363000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.886000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.375000 && val<=0.429000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.768000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.358375) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.100650) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.001128 && val<=0.001524) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001487 && val<=0.002518) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000066 && val<=0.000697) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.081000 && val<=0.449900) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.010760 && val<=-0.801000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000007 && val<=0.002445) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.001232 && val<=0.003856) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.005791 && val<=0.000303) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.801300) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.118820 && val<=0.088960) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.489000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.030900) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.792400) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.626000 && val<=0.731000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.504000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.401900) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.962800) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.445000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.447000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.147000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.803000 && val<=0.901300) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.696058 && val<=-0.002856) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.773558 && val<=-0.642442) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.138400 && val<=0.275720) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.648028 && val<=-0.719348) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-5.714183 && val<=-0.624025) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-1.694251 && val<=2.727604) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-1.818853) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.009000 && val<=0.036400) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.675000 && val<=1.000000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.368000 && val<=0.443400) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.484600 && val<=1.125400) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.558000 && val<=0.888800) _g_bev_votes++;
      if(feat=="msContext" && val>=0.378500 && val<=0.539250) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.339600 && val<=0.456400) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.274733) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.882000 && val<=0.997400) _g_bev_votes++;
      if(feat=="smContext" && val>=0.376920 && val<=0.391800) _g_bev_votes++;
      if(feat=="atrProxy" && val>=1089.100000 && val<=1651.300000) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.170547) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.347349) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.827200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.606000 && val<=0.713000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.300000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.624600 && val<=0.741000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.310200) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.187000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.505000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.345600 && val<=0.406000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.265800) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.094200) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.905800) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=1066.064240) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.597600) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.400300) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="TREND_CONTINUATION")
   {
      if(feat=="msCompression" && val>=0.543000 && val<=0.969500) _g_bev_votes++;
      if(feat=="vpVAH" && val>=2.108599) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.033500) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-22.551276) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.318000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.192500) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.845000 && val<=0.928000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.374000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=698.700000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.082900) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.501000 && val<=0.886000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000314 && val<=0.001162) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000852) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001142 && val<=0.002302) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000446 && val<=0.000386) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.014000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.052000 && val<=0.390000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.878600 && val<=-0.340500) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.002537) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000000 && val<=0.002217) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.792000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.145000 && val<=0.497000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.774000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.611000 && val<=0.715000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.797000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.293000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.704000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.241000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.294000 && val<=0.327833) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.001038 && val<=0.001513) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.001226) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.000024 && val<=0.000675) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.065100 && val<=0.433000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.079880 && val<=-0.807400) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.800600) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.508500) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.038700) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.092100 && val<=0.301000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.771600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.796600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.495000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.333000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.869000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.444000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.400000 && val<=0.435900) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.273000 && val<=0.377000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.153000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.775000 && val<=0.894000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.960000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=650527.509900) _g_bev_votes++;
      if(feat=="msContext" && val>=0.368500 && val<=0.415475) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.224460) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="BREAKOUT")
   {
      if(feat=="atrProxy" && val>=148.900000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.084300) _g_bev_votes++;
      if(feat=="vpPOC" && val<=-0.000866) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.526800) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000192 && val<=0.002429) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-0.005452) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000601 && val<=0.003494) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.000356) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-0.010088) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.675000 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.784000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.502000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.900000 && val<=1.239000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=2.926000 && val<=3.000000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.954000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.550200) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.746000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=66.400000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.211900) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="atrProxy" && val>=153.420000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.082890) _g_bev_votes++;
      if(feat=="vpPOC" && val<=-0.000842) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.000259 && val<=0.000319) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000085) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000113) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.068000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.507360) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000217 && val<=0.002735) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-0.004621) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=0.000436) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-0.009473) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.004054 && val<=0.000252) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.675000 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.992100) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.767000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.609000 && val<=0.716300) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.642000 && val<=0.755300) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.220900) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.590800) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.301900) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.263000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-645102.510080) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.429940 && val<=0.509120) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION")
   {
      if(feat=="atrProxy" && val>=144.960000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.087440) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.001481 && val<=-0.000476) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000621 && val<=0.000272) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001054) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002471 && val<=-0.001358) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.016000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.055000 && val<=0.377800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.294310 && val<=0.920110) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002541 && val<=-0.000313) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.000001 && val<=0.005048) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.001510) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.153000 && val<=0.511800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.617000 && val<=0.717900) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.806000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.623000 && val<=0.727000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.340000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.337000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.919100 && val<=1.257000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.844400) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.377000 && val<=0.430000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.250300) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.757700) _g_bev_votes++;
      if(feat=="msContext" && val>=0.631250) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.292700) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.291000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.012000) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="PULLBACK")
   {
      if(feat=="atrProxy" && val>=149.620000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.084540) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000532 && val<=0.001656) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000346 && val<=0.003017) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000208 && val<=0.004291) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.004364 && val<=0.000920) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.680000 && val<=0.739000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.317800 && val<=0.599000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.222000 && val<=0.641200) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.900000 && val<=1.225000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=2.941200 && val<=3.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.355000 && val<=0.421000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.760000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.292000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.280000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.867000 && val<=0.979000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=66.460000) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpVAH" && val>=0.000000) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001382) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.650000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=139.500000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.089760) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.001767 && val<=-0.001293) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000861 && val<=-0.000163) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002741 && val<=-0.001755) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.017000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.063400 && val<=0.444000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.804800 && val<=1.089560) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002749 && val<=-0.000659) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.006929) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.011804) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.001303) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.778000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.786000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.509800) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.786200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.616400 && val<=0.711000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.802000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.507000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.402200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.987000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.153000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.634500) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.315067 && val<=0.348267) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.034000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.417040) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="atrProxy" && val>=148.020000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.085270) _g_bev_votes++;
      if(feat=="vpPOC" && val<=-0.001952) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.000948) _g_bev_votes++;
      if(feat=="vpVAL" && val<=-0.002693) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=1.214220) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.001568) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.000069) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.700000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.682000 && val<=0.739000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.304810) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.650400 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.070000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.565700) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.957000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-629087.173420) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.623650) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.279283) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.526000 && val<=0.895000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.044065 && val<=0.132166) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.097063) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.125775 && val<=0.215054) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.033030 && val<=0.053803) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.013000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.052000 && val<=0.320000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.876900 && val<=-0.361300) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.690000 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.136000 && val<=0.513000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.625000 && val<=0.716000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.637000 && val<=0.735000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.415000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.975000 && val<=1.266000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.083000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.762000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.350750) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.271667) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.782000 && val<=0.899000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=149.900000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.081100) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpVAH" && val>=0.372264) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.120851 && val<=0.154037) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.132523) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.166091 && val<=0.242895) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.012949 && val<=0.080425) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.013000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.023150 && val<=-0.803900) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.018779 && val<=0.236354) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.181893) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.803500) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.860000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.781000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.508000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.427000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.059000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.402500 && val<=0.438000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.275000 && val<=0.366000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.364250 && val<=0.393750) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.541500) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.264500) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.361200 && val<=0.462800) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="BREAKOUT")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.185241 && val<=0.281152) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.150950 && val<=0.027990) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.317000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-5241.733070) _g_bev_votes++;
      if(feat=="smContext" && val>=0.409800) _g_bev_votes++;
      if(feat=="atrProxy" && val<=195.870000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.092710) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.502200 && val<=0.922400) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.134997 && val<=-0.033673) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.053204 && val<=0.038534) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.245670 && val<=-0.117543) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.063000 && val<=0.419600) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.204780 && val<=0.843260) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.267864 && val<=-0.000768) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=1.048092) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.675000 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.770000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.617000 && val<=0.708400) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.623600 && val<=0.721000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.322000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.280000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.667000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.767000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.239600 && val<=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.500000 && val<=0.760400) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-5349.389140) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.024000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.041760 && val<=0.071180) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="PULLBACK")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.048040 && val<=0.150228) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.053000 && val<=0.366100) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.190389 && val<=0.314016) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.594613 && val<=0.000125) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.767000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.388300) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.210900 && val<=0.624200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.613900 && val<=0.722000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.358000 && val<=0.424000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.767000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.275500) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.345040) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.885000 && val<=0.991000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=192.400000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.093300) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.162000 && val<=-0.058304) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.077840 && val<=-0.001151) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.261190 && val<=-0.151190) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.060000 && val<=0.456200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.357660 && val<=1.008140) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.771200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.612000 && val<=0.707000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.799000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.495000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.339800) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.810800) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.765800) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-5614.876240) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=4429.171840) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.418160 && val<=0.509120) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.171374 && val<=0.291434) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.181991 && val<=0.731524) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.001000 && val<=0.003000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.770000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.613000 && val<=0.721900) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.634000 && val<=0.748000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.353100 && val<=0.424000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.971000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.334000 && val<=0.440000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=193.450000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=260.910000 && val<=469.430000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.039610 && val<=0.069400) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.495000 && val<=0.909300) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.649995 && val<=1.446439) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.303625 && val<=2.419696) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.262750 && val<=0.562168) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.056000 && val<=0.418300) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.940340 && val<=-0.427790) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-2.578217 && val<=3.113719) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-3.360671) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.623000 && val<=0.715300) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.484000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.276800) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.651000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.946000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=29.810000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=1025.952240) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.292333 && val<=0.331333) _g_bev_votes++;
      if(feat=="smContext" && val>=0.419400) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="msCompression" && val>=0.557000 && val<=0.925700) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.337924 && val<=2.223865) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=0.545000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.545000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.165000 && val<=0.306000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=1013.898470) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.566000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.391000 && val<=0.406340) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="BREAKOUT")
   {
      if(feat=="msCompression" && val>=0.541200 && val<=0.854600) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.000880) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.146102 && val<=-0.044402) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.073633) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.243740 && val<=-0.119304) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.046000 && val<=0.376000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.160420) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.440804 && val<=-0.136629) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.791600) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.323000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.467000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.385600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.960000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.336000 && val<=0.394000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.309700 && val<=0.337500) _g_bev_votes++;
      if(feat=="atrProxy" && val<=102.480000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.408700) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="msCompression" && val>=0.572000 && val<=0.875000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.065866 && val<=-0.002999) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.028058) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.166708 && val<=-0.066871) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.220000 && val<=0.559000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.111400 && val<=0.282500) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.780000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.685000 && val<=0.860000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.434000 && val<=0.768000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.770000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.601000 && val<=0.709000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.620000 && val<=0.738000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.314000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.450000 && val<=1.103000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.258000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.301000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.428800) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.484200 && val<=0.802600) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.048071 && val<=0.118124) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.075364) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.111645 && val<=0.198930) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.044186 && val<=0.037761) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.175400 && val<=0.497000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.910340 && val<=-0.587340) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.346213) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.355227) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.453279) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.007000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.791000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.784800) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.299940) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.330000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.493000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.288400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.685000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.760000 && val<=0.886000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.807400) _g_bev_votes++;
      if(feat=="msContext" && val>=0.373750 && val<=0.472650) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.336000 && val<=0.399000) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="PULLBACK")
   {
      if(feat=="msCompression" && val>=0.539000 && val<=0.849000) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.209138 && val<=-0.093285) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.430381 && val<=-0.120094) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.718548 && val<=-0.128220) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.303064 && val<=0.245607) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-1.186050 && val<=-0.534769) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.791000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.614000 && val<=0.716000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.629000 && val<=0.734000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.325000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.216000 && val<=0.269000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.958400) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-4308.301800) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.335000 && val<=0.407000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.355200 && val<=0.393400) _g_bev_votes++;
      if(feat=="atrProxy" && val<=101.900000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.408400) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="msCompression" && val>=0.525000 && val<=0.848100) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.117933 && val<=-0.020552) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.206044 && val<=-0.086225) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.046000 && val<=0.380100) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.427019 && val<=-0.117048) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.792000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.938400) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.308000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.955000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-4270.163370) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=99.000000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.427580) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="PULLBACK")
   {
      if(feat=="ofFlowIntensity" && val<=0.303000) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.204162 && val<=-0.094364) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.447632 && val<=-0.123590) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.300986 && val<=0.240735) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.205600 && val<=0.650000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.355600 && val<=0.425000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.780200) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.558560) _g_bev_votes++;
      if(feat=="smContext" && val>=0.351400 && val<=0.380800) _g_bev_votes++;
      if(feat=="atrProxy" && val<=89.400000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.395980) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="BREAKOUT")
   {
      if(feat=="msCompression" && val>=0.538900 && val<=0.869200) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.221714 && val<=-0.103690) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.171530) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.665626) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.224204) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.321900 && val<=0.603100) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.382000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.857000 && val<=0.932000) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.392860) _g_bev_votes++;
      if(feat=="atrProxy" && val<=120.830000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.292920) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.108382 && val<=0.154923) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.121312) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.155000 && val<=0.232948) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.012811 && val<=0.073751) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.061000 && val<=0.369700) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.148300 && val<=0.477700) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.061400 && val<=-0.804700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.012126 && val<=0.219555) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.796020 && val<=-0.133409) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.780000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.798500) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.860000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.779000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.628300 && val<=0.716000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.801900) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.639300 && val<=0.734000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.333000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.511000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.365000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.835000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.354750) _g_bev_votes++;
      if(feat=="msContext" && val>=0.366750 && val<=0.411425) _g_bev_votes++;
      if(feat=="atrProxy" && val<=113.510000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.306340) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="msCompression" && val>=0.518000 && val<=0.858000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.101167 && val<=-0.011592) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.193685 && val<=-0.074035) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.672854) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.772000 && val<=1.199000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.500000 && val<=0.502000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.498000 && val<=0.500000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.397000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=120.000000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.294400) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=0.512000 && val<=0.751800) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.087996 && val<=0.134517) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.108251) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.141633 && val<=0.217992) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.006590 && val<=0.060924) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.059000 && val<=0.430800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.059800 && val<=-0.811500) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.021800 && val<=0.195151) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.145862 && val<=0.236602) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.199350) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.584270 && val<=-0.070759) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.789600) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.337000 && val<=0.617800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.793000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.631000 && val<=0.728000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.826000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.653200 && val<=0.754800) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.500600) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.364000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.837000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.446600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.411000 && val<=0.441000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.762000 && val<=0.885000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.288833 && val<=0.311667) _g_bev_votes++;
      if(feat=="atrProxy" && val<=10652.960000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.426200) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION")
   {
      if(feat=="msCompression" && val>=0.567000 && val<=0.820200) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.030816 && val<=0.108855) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.054500) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.094005 && val<=0.187723) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.052575 && val<=0.028736) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.919100 && val<=-0.587020) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.025762 && val<=0.158161) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.704395 && val<=-0.127833) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.784400) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.650000 && val<=0.941000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.645000 && val<=0.745400) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.289000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.675800) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.022000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.978000) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpDistToHVN" && val>=1.074700) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.371143) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.224446) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.629500) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.961600) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.528200 && val<=0.758800) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.063061 && val<=0.123875) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.074382) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.119573 && val<=0.198535) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.020969 && val<=0.050566) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.063000 && val<=0.436000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.015160 && val<=-0.809930) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.008491 && val<=0.178585) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.215801 && val<=0.226482) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.285332) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.666055 && val<=-0.112920) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.799300) _g_bev_votes++;
      if(feat=="vpVAOverlapBias" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.776000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.621000 && val<=0.712000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.642000 && val<=0.735000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.504000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.369700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.845700) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.204000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.363600) _g_bev_votes++;
      if(feat=="msContext" && val>=0.372750 && val<=0.411750) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.272667) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.289183 && val<=0.312667) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.409260 && val<=0.485400) _g_bev_votes++;
      if(feat=="atrProxy" && val<=5034.290000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.651560) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpCompVAL" && val>=-0.080512) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.048249) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.124224) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.040007) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.031600) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.158200 && val<=0.560400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.320500) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.159237) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.372557) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.187160) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.852600) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.266800) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.680200) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.303000) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val<=-0.198840) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.114400) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.216000 && val<=0.300000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.292000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.293700) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.710000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.411400) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.126620 && val<=0.159721) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.145801) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.171193 && val<=0.238378) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.022159 && val<=0.082886) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.057600 && val<=0.393800) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.178600 && val<=0.507000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.981960 && val<=-0.801400) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.237816) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.032212 && val<=0.218040) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.159664 && val<=0.307958) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.800800) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.027000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.783000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.631600 && val<=0.723000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.808000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.503000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.363000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.856600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.446000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.284000 && val<=0.385000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.944800) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=3.300000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.333750) _g_bev_votes++;
      if(feat=="msContext" && val>=0.357750 && val<=0.385850) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.774000 && val<=0.997000) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.018000) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=6.773731) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.948339) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.628000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.794000) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.383000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.326000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.326000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.128000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.319000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.616000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.747000) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.331904) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.286540) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.533604 && val<=-0.863601) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-11.587291 && val<=-4.053919) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.672600 && val<=0.737400) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.545000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.368050) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.082020 && val<=0.133540) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpVAH" && val<=-0.080735) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.251691) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.672400 && val<=0.734000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.764200) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.635400 && val<=0.753000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.153400) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.074200) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.857400 && val<=0.943000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=119.780000 && val<=166.100000) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.360797 && val<=1.228853) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.221964 && val<=2.168099) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.399411 && val<=0.477961) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.080500 && val<=0.543000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.873050 && val<=-0.310050) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.011000 && val<=0.042000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.359625) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.374500 && val<=0.482200) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="NAKED_POC")
   {
      if(feat=="vpDistToHVN" && val>=0.100800 && val<=0.519000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=4.237578) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.013000 && val<=0.049800) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.321600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.298400) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.224600 && val<=0.391600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.955600) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.500000) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-1.975207 && val<=-0.768176) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.406478 && val<=-0.747452) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-5.957079 && val<=-0.791553) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-1.582138 && val<=3.248992) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.772400) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=0.029680) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.092040 && val<=0.252380) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.073400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.517200) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.319400) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.680600) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.559680) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=1.054795 && val<=1.483015) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.505906 && val<=2.558097) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.032052 && val<=0.781661) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.106700 && val<=0.650800) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=1.140000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.064730 && val<=-0.802770) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.500000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.111040 && val<=0.131160) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.079700 && val<=0.338600) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.820900) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.868400 && val<=0.956300) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.336800) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.663200) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.069980) _g_bev_votes++;
   }
   if(symbol=="AAPLm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="auctReversalRisk" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.043400 && val<=0.182400) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.817600 && val<=0.956600) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.374000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.563600) _g_bev_votes++;
   }
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-0.001034 && val<=0.000557) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000280 && val<=0.001358) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001857 && val<=-0.000348) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.027000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.370120 && val<=0.565200) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005652) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.010221) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.239640) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.488000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.872600) _g_bev_votes++;
      if(feat=="auctRegime" && val>=0.000000 && val<=1.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.749600 && val<=1.261800) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.302000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.110000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.959000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.008000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.992000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.307533 && val<=0.346933) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.431880 && val<=0.526000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.706000) _g_bev_votes++;
   }
   if(symbol=="AUDUSDm" && setup=="BREAKOUT")
   {
      if(feat=="auctTargetProb" && val>=0.356000 && val<=0.424400) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.031000 && val<=0.120000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.880000 && val<=0.969000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.302500 && val<=0.338167) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.785000 && val<=0.891000) _g_bev_votes++;
   }
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000452 && val<=0.000171) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000209) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001342 && val<=-0.000473) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.157400 && val<=0.215840) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.005008) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002084 && val<=0.000426) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.676000 && val<=0.733000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.781000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.464000 && val<=0.788000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.771400) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.609800 && val<=0.711000) _g_bev_votes++;
      if(feat=="auctRegime" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.641000 && val<=0.748000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.199000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.303000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.337000 && val<=0.392000) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.961400) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.770000 && val<=0.881000) _g_bev_votes++;
   }
   if(symbol=="AUDUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpVAH" && val>=0.000058 && val<=0.001209) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.764500) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-325063.480350) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.330000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.361000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.280500) _g_bev_votes++;
   }
   if(symbol=="AUDUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.001566 && val<=-0.000479) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.004217 && val<=0.001445) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000261 && val<=0.004947) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.000000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.683000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.567000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.783000 && val<=0.891000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.390400 && val<=0.403000) _g_bev_votes++;
   }
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=-0.001298 && val<=0.001173) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000281 && val<=0.001894) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001799 && val<=0.000379) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.066000 && val<=0.413000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.816300 && val<=0.807700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.001772 && val<=0.001506) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.003603 && val<=0.001907) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.000368 && val<=0.005573) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.007605 && val<=-0.001289) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.774000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.800000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.099000 && val<=0.117800) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.038000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.775000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.620000 && val<=0.714000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.796000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.632000 && val<=0.732000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.502000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.365000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.862000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.444000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.278000 && val<=0.365000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.206000 && val<=0.247000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.804000 && val<=0.903000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.631000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.342000 && val<=0.435000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=65.700000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.141400) _g_bev_votes++;
   }
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDistToHVN" && val>=0.909000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.044000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.005243) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000263 && val<=0.004791) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.073000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.389350 && val<=0.588250) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.286495) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=1.984703) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-8.330807) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.059000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.700000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.296290) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.856000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.770100) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.338000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.242700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.610000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.302900) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.109000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.314200) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.954100) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.802000) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.221946) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-2.013668 && val<=-0.805092) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.045000 && val<=0.330000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.887200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.175020) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.618800 && val<=0.719000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.576600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.346000 && val<=0.427000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.155000 && val<=0.289200) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=9.780000 && val<=34.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=475.597200) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.288500) _g_bev_votes++;
      if(feat=="atrProxy" && val>=88032.200000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.021000) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.384290 && val<=0.155548) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.044389) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.145245) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.259645 && val<=-0.403269) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.136120 && val<=0.205800) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=9.005132) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.760000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777400) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegime" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.656000 && val<=0.763000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.167000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.442800 && val<=1.068600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.474000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.334000 && val<=0.387000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.052600) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.286000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.967000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.626750) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.331000 && val<=0.387000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.302167 && val<=0.329333) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.476400 && val<=0.533600) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.518468 && val<=0.450755) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.328855 && val<=-0.202945) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.331150 && val<=0.267200) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=2.892154) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.310500) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-430.243900) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.366000) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-1.563956 && val<=-0.579499) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-4.251061 && val<=-0.066074) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-1.080732 && val<=4.294448) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.630000 && val<=0.726000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.345000 && val<=0.418000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.298800) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.121400) _g_bev_votes++;
      if(feat=="atrProxy" && val>=87208.020000) _g_bev_votes++;
   }
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpPOC" && val>=-0.725500 && val<=0.051780) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.017797 && val<=0.658442) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.042000 && val<=0.307200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.070440 && val<=0.415220) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-8.350109) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.650000 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.629000 && val<=0.725200) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.654000 && val<=0.757000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.535800 && val<=1.124000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=482.350180) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.564000 && val<=0.819200) _g_bev_votes++;
      if(feat=="msContext" && val>=0.630600) _g_bev_votes++;
      if(feat=="atrProxy" && val>=86897.460000) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.634770) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.340098) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.589227) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.075500) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.598250) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.400000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.293000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.291250) _g_bev_votes++;
      if(feat=="atrProxy" && val>=85.550000) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=-2.291903 && val<=-0.690591) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-3.475119 && val<=-1.598968) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.101700 && val<=0.681200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.240880 && val<=1.227380) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-4.687273 && val<=2.051559) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.006000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.550000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.405000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.238200) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.293800) _g_bev_votes++;
      if(feat=="atrProxy" && val>=86.920000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.120500) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.839347 && val<=0.071136) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.413870) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.208990 && val<=0.340280) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.805100) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.746000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.603800 && val<=0.731300) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.174300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.472600) _g_bev_votes++;
      if(feat=="msContext" && val>=0.622775) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.288300) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.254320) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.711220 && val<=1.669582) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.949957) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.349916 && val<=2.862336) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.022000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.120600 && val<=0.635000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.043100) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.288920 && val<=-0.649030) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.750000 && val<=0.992500) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.596000 && val<=0.693700) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.599600 && val<=0.698000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.269200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.661100) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.803500) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-822.118780) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="NAKED_POC")
   {
      if(feat=="vpVAH" && val<=-1.813440) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.039500) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-5.460199) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.331000 && val<=0.594500) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.908000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.625500) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.006000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.994000) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-2.975813 && val<=-1.040612) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.045600) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-23.874436) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.031000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.952400) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.298000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.295700) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val<=0.780940) _g_bev_votes++;
      if(feat=="vpVAH" && val<=1.318760) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.045873 && val<=0.822991) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.209900 && val<=0.772800) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.035700) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.800470) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.586390 && val<=-0.834390) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.595000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.042300 && val<=0.252900) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.597100 && val<=0.692900) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.360700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.831400) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.407100 && val<=0.442000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-619.914760) _g_bev_votes++;
      if(feat=="msContext" && val<=0.339025) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.268850) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.321660 && val<=0.423980) _g_bev_votes++;
   }
   if(symbol=="EBAYm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpVAH" && val>=-0.750777 && val<=0.831413) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-3.102683 && val<=-0.991367) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.110300 && val<=0.685400) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.041100) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.089350 && val<=0.940230) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-8.968202 && val<=-1.809025) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-23.507176) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.600000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.637500) _g_bev_votes++;
      if(feat=="msContext" && val>=0.622500) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.119560) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.241576) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.029000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=1.984295) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=6.109387) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=10.250961) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.645565) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.744000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.197800) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.843800) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.393000 && val<=0.483000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.311000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.120000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.954900) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.823200) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.006000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.994000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.298100) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.329009) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.833619 && val<=-0.756178) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.871400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.256980) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.059573 && val<=-0.613956) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-1.320065 && val<=4.273072) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.109000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.054440 && val<=0.196060) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.622000 && val<=0.715600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.341000 && val<=0.419000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.958000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.811800) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.290000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.285833) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.428164 && val<=0.109005) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.008177) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.172182) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.010000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.100000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.242000 && val<=0.528000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.123380 && val<=0.198850) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.784000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.490000 && val<=0.828900) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.779300) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.626000 && val<=0.723000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctRegime" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.660000 && val<=0.766000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.377000 && val<=0.451000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.173700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.482000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.330000 && val<=0.386000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.289300) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.302517 && val<=0.331317) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.375969 && val<=0.423713) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.210472 && val<=1.068057) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.175589 && val<=-0.329696) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.333000 && val<=0.192880) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.795100) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.550000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.450400) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val>=0.056830) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.601600) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=502.276530) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.555800 && val<=0.876900) _g_bev_votes++;
      if(feat=="msContext" && val>=0.415375 && val<=0.583200) _g_bev_votes++;
      if(feat=="smContext" && val>=0.405440) _g_bev_votes++;
   }
   if(symbol=="ETHUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-1.549885 && val<=-0.608688) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.873100) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.075036 && val<=-0.479397) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-5.177245 && val<=-0.196649) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-1.398975 && val<=4.371820) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.111900) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=0.422490) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=0.018890) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.274000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.958000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.807000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.005000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.995000) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.000304) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001169) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000603) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.037700) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.294260) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005814) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.001210) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.354100 && val<=0.619800) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.210700) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.778600) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.572500) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.323000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.131700) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.779400) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.500000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.366850) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.295733) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.384540) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.593640) _g_bev_votes++;
      if(feat=="smContext" && val<=0.372540) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.000106) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001118) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.223580) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000072) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.072500) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.269400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.688900) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-305375.657400 && val<=5274.403470) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.682700) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=0.000531) _g_bev_votes++;
      if(feat=="vpPOC" && val>=-0.000662 && val<=-0.000019) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.000159) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000343) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.043000 && val<=0.275000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.479980) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.155360 && val<=0.250100) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.000078 && val<=0.004132) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.000065) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.774000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.644800 && val<=0.761000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.335400) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.193000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.805000 && val<=0.901000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.954400) _g_bev_votes++;
      if(feat=="msContext" && val>=0.625350) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.453000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.356500) _g_bev_votes++;
      if(feat=="smContext" && val>=0.428200) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="NAKED_POC")
   {
      if(feat=="auctAcceptance" && val>=0.126400 && val<=0.527800) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.060000 && val<=0.243000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.757000 && val<=0.940000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-326273.044540 && val<=16061.515900) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.309733 && val<=0.341533) _g_bev_votes++;
      if(feat=="smContext" && val>=0.380760 && val<=0.420400) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="PULLBACK")
   {
      if(feat=="vpCompPOC" && val>=-0.004069 && val<=0.000045) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000330 && val<=0.004337) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.006956 && val<=-0.002903) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.921000 && val<=1.227900) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.183000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.761000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-310734.466200 && val<=4821.416130) _g_bev_votes++;
      if(feat=="msContext" && val>=0.629750) _g_bev_votes++;
      if(feat=="atrProxy" && val>=304.410000) _g_bev_votes++;
   }
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDevPOCDir" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.554400) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.575000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.305400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.799800) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.801000 && val<=0.901000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-313371.803320 && val<=4815.304500) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-0.000066) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000972) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000855) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.049600) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.197810) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000986) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.000098) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.719700) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.343300) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.374900) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.929900) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.328000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.136300) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.787000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.403000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.597000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.368300) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.598540) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.437360 && val<=0.531220) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.722600) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.000000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.035000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.191320) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-0.012865) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.010200) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.406000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.594000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.989800) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=-1.000000 && val<=1.000000) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000752 && val<=-0.000093) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.000244) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000389) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.014000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.127280 && val<=0.267440) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.004487 && val<=-0.000807) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=0.510000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=0.029310) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.539000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777300) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.252000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.010000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.990000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.301867 && val<=0.331833) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.395080) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.271000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.162130 && val<=0.225400) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.000351 && val<=0.001170) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000777) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001083 && val<=0.002204) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000497 && val<=0.000333) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.063000 && val<=0.472400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.947600 && val<=-0.450410) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.002691) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.256210) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.771000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.298100) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.714200) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.008000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.992000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=507637.038640) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.290000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.390860 && val<=0.480280) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="NAKED_POC")
   {
      if(feat=="vpDailyPOC" && val>=-0.000369 && val<=0.002175) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=0.891500 && val<=2.259500) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.713000 && val<=0.829000) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.002064 && val<=-0.000887) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.037000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.003830 && val<=-0.001091) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.005041 && val<=-0.000916) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.001634 && val<=0.002767) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.010000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.990000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=440862.982160) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.294000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=95.560000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.304600) _g_bev_votes++;
   }
   if(symbol=="EURCADm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.008400) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.991600) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=430877.485060) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.284833) _g_bev_votes++;
      if(feat=="atrProxy" && val<=95.500000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.307720) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.777200) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAH" && val>=0.000672 && val<=0.001785) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.016000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.038500) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.964000) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000651 && val<=0.003217) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.002141 && val<=0.006537) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.004028 && val<=-0.000124) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.720000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.116050) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.335500) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.183000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.817000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-566598.010750) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.294000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.419500 && val<=0.514400) _g_bev_votes++;
      if(feat=="atrProxy" && val>=60.450000 && val<=78.400000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.304600 && val<=0.407000) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000213 && val<=0.000464) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000122) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000479 && val<=0.001289) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.046000 && val<=0.258500) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=1.260000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.289450 && val<=0.131850) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.000404) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.510000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.030800) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.510000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.434500 && val<=0.760500) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.770000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.626000 && val<=0.751500) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.230500) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.764000 && val<=1.129500) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.577000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.340000 && val<=0.396500) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.160000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.325000 && val<=0.390000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.005500) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.240800 && val<=0.304600) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=-0.001424 && val<=-0.000479) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000670 && val<=0.000144) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001089) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002421 && val<=-0.001407) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.297400 && val<=0.889830) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.001672) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002265 && val<=-0.000358) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.004983) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.008270) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.000711) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.341200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.848700) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.765000 && val<=0.888000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.183900) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.816100) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.478900) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.371650) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.443720 && val<=0.523340) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.971900) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="PULLBACK")
   {
      if(feat=="vpVAH" && val>=0.000546 && val<=0.001544) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.014000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=1.027200) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000278 && val<=0.002603) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000478 && val<=0.003784) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.002409 && val<=0.007066) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.003914 && val<=0.000490) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.648200) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.562600) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.656600) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.278867) _g_bev_votes++;
   }
   if(symbol=="EURCHFm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpVAH" && val>=0.000530 && val<=0.001593) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000924 && val<=0.000031) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000331 && val<=0.002618) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000395 && val<=0.003716) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.002491 && val<=0.006892) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.003709 && val<=0.000402) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.069000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.410000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-569753.224200) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.334500 && val<=0.406000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.280333) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.417900 && val<=0.510900) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.525500) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-0.001723 && val<=0.000545) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000904 && val<=0.001490) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002500 && val<=-0.000462) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.046000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.401260 && val<=0.769700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002715 && val<=0.000947) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.650000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.253080) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.551000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.360000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.323600) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.136000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.860800 && val<=0.935000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.411800 && val<=0.508440) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.738000) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="BREAKOUT")
   {
      if(feat=="vpDistToLVN" && val<=0.040000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.951100) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.290620) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.675000 && val<=0.975000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.093300) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-84559.913500 && val<=267859.027420) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=-1.000000 && val<=1.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.329000 && val<=0.404100) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.304317 && val<=0.337833) _g_bev_votes++;
      if(feat=="atrProxy" && val>=88.600000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.160900) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000602 && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.000226) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.135530 && val<=0.201380) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.452300 && val<=0.766800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.776600) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.644000 && val<=0.754000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.198700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.553800) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.255000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.426660) _g_bev_votes++;
   }
   if(symbol=="EURGBPm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.000719 && val<=0.000193) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000148 && val<=0.000740) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.212020 && val<=0.367920) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.890400) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.113800) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.711200) _g_bev_votes++;
      if(feat=="smContext" && val>=0.426200) _g_bev_votes++;
      if(feat=="bosQuality" && val>=0.319168) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.038521) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.108352) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.046625) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.030000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.371080) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.107246) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.699000 && val<=0.753000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.190770) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.762800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.594900 && val<=0.710100) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.310600) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.130600) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.290000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.374000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.717300) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.020283) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.103434) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.213659 && val<=-0.098192) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.243160) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.704000 && val<=0.755000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.083000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.348000 && val<=0.427000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.387400) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.774300) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.365600) _g_bev_votes++;
      if(feat=="msContext" && val<=0.370500) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.288717) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.390200) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.182140) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="NAKED_POC")
   {
      if(feat=="vpDistToLVN" && val<=0.041400) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.114400 && val<=0.230800) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.194654 && val<=-0.078018) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.014900) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.926100) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.200099 && val<=0.228169) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.951675 && val<=-0.441210) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.650000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.349000 && val<=0.424000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-1369.938700) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.561800) _g_bev_votes++;
      if(feat=="smContext" && val>=0.379600 && val<=0.391800) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.183210) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.108079 && val<=0.152376) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.112822) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.153599 && val<=0.246088) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.002153 && val<=0.069372) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.037000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.077380 && val<=-0.804570) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000783 && val<=0.214495) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.823100) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.860000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.075000 && val<=0.268000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.780100) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.621000 && val<=0.719300) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.805100) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.632000 && val<=0.735600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.503000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.373000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.884400) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.445100) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.408700 && val<=0.438000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.200000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.951000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.790000 && val<=0.901000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.366750 && val<=0.401025) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.174960) _g_bev_votes++;
   }
   if(symbol=="EURJPYm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDistToLVN" && val<=0.044000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.570000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-1427.543500) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=8919.476400) _g_bev_votes++;
      if(feat=="atrProxy" && val<=144.920000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.183400) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.002470 && val<=-0.000923) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.032000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.150400 && val<=0.609900) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.796300) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.234740) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.865900) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.406000 && val<=0.475000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.304000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.112000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.517900) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.278300) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.774700) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.288283) _g_bev_votes++;
      if(feat=="atrProxy" && val>=190.580000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.044670) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.000635) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.002053 && val<=-0.000759) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.432880) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005103) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.010273) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.781000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.720000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.522300) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.649000 && val<=0.762000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.347000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.368000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.632000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=86.100000) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000455 && val<=0.000163) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000005) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000202) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.160680 && val<=0.214760) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005120) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.009769) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.000049) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.771000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.216200) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.691800 && val<=1.106000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.576000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.339000 && val<=0.389000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.373000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.627000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=830869.775720) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.372167) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.388160) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.102840) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpVAH" && val>=-0.000008 && val<=0.001021) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-0.011903) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.265880) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.322200) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.001707 && val<=-0.000616) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.903000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.003252 && val<=-0.000266) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.004487 && val<=0.001111) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000615 && val<=0.004300) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.513000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.339000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.284000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.747000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.162000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-43750.000000 && val<=257856.550600) _g_bev_votes++;
      if(feat=="msContext" && val>=0.628750) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.780000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.395800) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.001150 && val<=0.001540) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001544 && val<=0.002498) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.000000 && val<=0.000709) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.066000 && val<=0.431000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.160000 && val<=0.519000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.036500 && val<=-0.803000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.002832) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000334 && val<=0.002440) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.005521 && val<=0.000330) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.620000 && val<=0.716000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.804000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.628000 && val<=0.739000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.386000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.333000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.946000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.444000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.364500 && val<=0.415750) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.355600 && val<=0.453800) _g_bev_votes++;
   }
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpVAL" && val>=-0.001681 && val<=-0.000594) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.043000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.003241 && val<=-0.000272) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.341000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.496000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.013000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.369800) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.630200) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.987000) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.356240) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.768000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.428560) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.043700) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-1.335483 && val<=0.614830) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.558394 && val<=1.455008) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-2.318122 && val<=-0.366803) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.043200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.415060 && val<=0.666680) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-2.420619 && val<=1.100673) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-14.752176) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.775000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.110200) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.826200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.561000 && val<=0.686000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.244000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.661000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.307400) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val<=-0.150100) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.123000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.586400) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.300000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=436.142800) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.286400) _g_bev_votes++;
      if(feat=="atrProxy" && val>=3237.880000) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.538282 && val<=0.183128) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.058959) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.662799 && val<=-0.541356) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.191090 && val<=0.253440) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.970200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.754000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.589000 && val<=0.697000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.615000 && val<=0.729000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.198900) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.550900) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.306000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.802000 && val<=0.906000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.833000 && val<=0.926000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.100000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-345.414490) _g_bev_votes++;
      if(feat=="atrProxy" && val>=3283.820000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=1581.230000 && val<=2273.320000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.049780) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-1.183354 && val<=0.231010) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.443242 && val<=0.929320) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.902104 && val<=-0.642952) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.379580 && val<=0.478780) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-1.809567 && val<=1.116360) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.944440 && val<=6.160095) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.832800) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.646000 && val<=0.750000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.351000 && val<=0.432000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.240000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.686200) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.119000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.951800) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.308600 && val<=0.422000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.290833 && val<=0.342667) _g_bev_votes++;
      if(feat=="atrProxy" && val>=3043.940000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.889620) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="PULLBACK")
   {
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.315800 && val<=0.607000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.662600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.789000 && val<=0.899000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.001000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.999000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=436.389680) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.624600) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.278000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=3311.520000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.603420) _g_bev_votes++;
   }
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpVAH" && val<=-1.389529) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-2.464923 && val<=1.117878) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-14.254619) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.667000 && val<=0.738000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.088450 && val<=0.156550) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.320000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.536500 && val<=1.146000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.593000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.274000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.675500) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.001000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.999000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=418.827700) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.280000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.799550) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.000517) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001264) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000450) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.039000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.435440) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.814600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.356000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.315000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.128400) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.284600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.786200 && val<=0.898000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=269641.391800) _g_bev_votes++;
      if(feat=="msContext" && val<=0.370700) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.300400) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.295033) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.738000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.090860 && val<=0.122100) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.000211) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.245480) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-0.007658) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.153960) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.010540) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.540000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.698800) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.292000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.845000 && val<=0.973800) _g_bev_votes++;
      if(feat=="atrProxy" && val<=171.180000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.147860) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpVAL" && val>=-0.000255) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.305600 && val<=0.628000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.452200 && val<=0.777000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.783600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.651000 && val<=0.762000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.916000 && val<=1.158800) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.338000 && val<=0.393000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.256600) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.851000 && val<=0.934000) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="NAKED_POC")
   {
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="PULLBACK")
   {
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.781000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.934000 && val<=1.244300) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.023000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.977000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.435080 && val<=0.515320) _g_bev_votes++;
      if(feat=="atrProxy" && val>=341.010000) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.001096 && val<=0.001495) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.001154) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001533 && val<=0.002407) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.000117 && val<=0.000718) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.022000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.092600 && val<=0.459000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.058700 && val<=-0.803760) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.000545 && val<=0.002519) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.003286 && val<=0.001086) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.798000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.033000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.786800) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.812000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.506800) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.453000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.109000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.445000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.367750 && val<=0.410600) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.342920 && val<=0.449920) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.027600) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.160600) _g_bev_votes++;
   }
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDistToHVN" && val>=0.931800) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.055000 && val<=0.395000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.035100) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.005247) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.344460) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.293000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.432920 && val<=0.510540) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.153380) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-0.000311) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000961) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001052) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.046730) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.004532 && val<=-0.000319) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.001137 && val<=0.003604) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.755000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.633300) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.171500) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.792700) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.300233) _g_bev_votes++;
      if(feat=="smContext" && val<=0.361800) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.234340 && val<=0.331360) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAL" && val>=-0.002539 && val<=-0.001227) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.050000 && val<=0.364000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.929000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.166500) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.003972 && val<=-0.001387) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.005084 && val<=-0.000730) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.001563 && val<=0.002893) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.008786 && val<=-0.003782) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.078000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.226000 && val<=0.668000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.494000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.853000 && val<=0.928000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.007000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.993000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-436900.091700) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=469364.224100) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.299000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.574600) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000845 && val<=-0.000227) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000488) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001818 && val<=-0.000799) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.083920 && val<=0.301380) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.432600 && val<=0.751000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.783800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.607600 && val<=0.711000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.632600 && val<=0.755000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.908200 && val<=1.151400) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.341600 && val<=0.396000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.078400) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.356967) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.213560 && val<=0.280300) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.000939 && val<=0.000012) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.000311 && val<=0.000482) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001487 && val<=-0.000565) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.429000 && val<=0.999000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.453320) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.002119 && val<=-0.001008) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.055000 && val<=0.392300) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.890400) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.004823 && val<=-0.000375) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.001295 && val<=0.003537) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.008545 && val<=-0.003401) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.788000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.191000 && val<=0.647000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.354000 && val<=0.426000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-440325.912000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=511515.248170) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.569540) _g_bev_votes++;
   }
   if(symbol=="GBPCADm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.000807 && val<=0.001450) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000995) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000134 && val<=0.000535) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.021000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.193420 && val<=-0.808730) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.002123) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.004645 && val<=0.000232) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.301000 && val<=0.611100) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.765900) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.356000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.507000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.493100) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.237600) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-444766.996200) _g_bev_votes++;
      if(feat=="msContext" && val>=0.369750 && val<=0.409425) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.437510) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.233390 && val<=0.343750) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.000900 && val<=0.000561) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.034700) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000846 && val<=0.003650) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.806500) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.891500 && val<=1.258000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.310700) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.120000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.148700) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.777100) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.469200 && val<=0.773000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.291700) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAH" && val>=0.000508 && val<=0.001727) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000692 && val<=0.002985) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.004263 && val<=-0.000040) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.650000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.063000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.797000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.140000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.365000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.560000) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000301 && val<=0.000247) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000050) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000150) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.010000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.184000 && val<=0.158950) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.003752 && val<=0.000441) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.349000 && val<=0.620000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.778000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.610000 && val<=0.719000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.651500 && val<=0.763500) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.801000 && val<=0.899000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.391900 && val<=0.404200) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.000541 && val<=0.000420) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000124 && val<=0.000991) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001293 && val<=-0.000275) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.258050 && val<=0.336350) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.626500 && val<=0.714000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.550000) _g_bev_votes++;
      if(feat=="auctRegime" && val>=5.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.295500) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.256500) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.501500) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-179252.262850 && val<=24664.268600) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.259833) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.602500) _g_bev_votes++;
      if(feat=="atrProxy" && val>=150.950000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.150150) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=0.000923) _g_bev_votes++;
      if(feat=="vpInsideVA" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.927500) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000520 && val<=0.003600) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.002445 && val<=0.007068) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.004186 && val<=0.000542) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.650000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=2.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.070000) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.543000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.328900) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.351000 && val<=0.423700) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.764000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.622975) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.329820) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.564000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.792300 && val<=0.895000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.384800) _g_bev_votes++;
   }
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpInsideVA" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.000527 && val<=0.003477) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.002412 && val<=0.006948) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.004039 && val<=0.000348) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.064000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.841000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.496000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.323600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.442000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.395600) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.354250) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.036860) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.108807) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.053576) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.034700) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.350090) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.111990) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.673000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.172780) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.765200) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.426800) _g_bev_votes++;
      if(feat=="auctRegime" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.317000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.141700) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.577600) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.302300) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.699700) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=5598.750750) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.371000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.373250) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.671100) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.016569) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.102781) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.217241 && val<=-0.101737) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.015000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.195890) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.598507) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.412000 && val<=0.473000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=5707.310140) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.371000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.372250) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.290000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.159190) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="NAKED_POC")
   {
      if(feat=="vpCompPOC" && val<=-0.544996) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.201881) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.242100) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.512500) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.785500) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.153500) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-95.523900 && val<=2773.422600) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.937000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=434.550000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.052150) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.183905 && val<=-0.074961) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.519854 && val<=-0.057522) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.160984 && val<=0.246468) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.859534 && val<=-0.402752) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.085000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.564000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.566000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.500000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.354000 && val<=0.425000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.161000 && val<=0.307000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.959000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=5650.498500) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.296000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.286500) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.848000 && val<=0.935000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.159700) _g_bev_votes++;
   }
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val<=0.028717) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.113081 && val<=0.154898) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.122541) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.157648 && val<=0.241607) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.012146 && val<=0.073177) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.018000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.081000 && val<=0.441000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.061620 && val<=-0.805900) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.207697) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.018701 && val<=0.227578) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.132258) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.789000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.797000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.395200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.785000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.803600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.643000 && val<=0.746000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.515600) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.478200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.212800) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.279000 && val<=0.358000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.270000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.803400 && val<=0.904000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.288667 && val<=0.318000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.982000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.165700) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000020 && val<=0.005096) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.862800) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.873000 && val<=1.292000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.308000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.120000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.956000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.769200) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-618672.026540) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.403240) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAL" && val>=-0.002069 && val<=-0.000700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002923 && val<=-0.000450) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000486 && val<=0.004135) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.356000 && val<=0.428000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.248100) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.759000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.011000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.989000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-319169.990000 && val<=112586.201810) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.366475) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.283150) _g_bev_votes++;
      if(feat=="smContext" && val<=0.347380) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.099720) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.000410 && val<=0.000292) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000158 && val<=0.000928) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001226 && val<=-0.000267) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.245850 && val<=0.201000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000594 && val<=0.001326) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.001296 && val<=0.006376) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.300000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-433426.980200 && val<=-1227.402100) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.001728 && val<=-0.000609) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002855 && val<=-0.000312) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.004356 && val<=0.000884) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.000498 && val<=0.004671) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.008552 && val<=-0.002422) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.642000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.778000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.046670 && val<=0.199990) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.161700 && val<=0.302300) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.808000 && val<=0.901000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.365000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.286000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.433600 && val<=0.511040) _g_bev_votes++;
   }
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpBestHVNScore" && val<=0.643900) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.049770 && val<=0.203460) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.900000 && val<=1.196300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=2.488800 && val<=3.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.010000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.990000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-298646.899000 && val<=133268.666100) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.290000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.426340 && val<=0.509200) _g_bev_votes++;
      if(feat=="smContext" && val<=0.349800) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.100130) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-1.840896 && val<=0.295354) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.922521 && val<=1.301775) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.207600 && val<=0.884000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.223640 && val<=0.965460) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-4.074497 && val<=0.567072) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.251600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.612000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.149800) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.538000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.462000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.414600 && val<=0.819000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.278000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.303767 && val<=0.348167) _g_bev_votes++;
      if(feat=="atrProxy" && val<=109.300000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=246.900000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.122080) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="BREAKOUT")
   {
      if(feat=="vpDistToHVN" && val>=0.083500 && val<=0.574000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.119000 && val<=0.538500) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.526500) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.372500 && val<=0.446500) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.597500) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=107.150000) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.630036 && val<=0.117689) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.177450 && val<=0.249390) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.612000 && val<=0.725000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.216000 && val<=0.300000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.541300) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.458700) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.312000 && val<=0.391300) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=-0.457203 && val<=1.120248) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.388049 && val<=2.225006) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.438907 && val<=0.122618) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.084800 && val<=0.679000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.869080 && val<=0.245860) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.673400 && val<=0.735000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.965000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.600000 && val<=0.697600) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.000000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.606400 && val<=0.709200) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.197000) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="NAKED_POC")
   {
      if(feat=="auctLVNStrength" && val>=0.897200 && val<=0.993000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.526000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.474000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=2460.670500) _g_bev_votes++;
      if(feat=="bosQuality" && val>=0.428061) _g_bev_votes++;
      if(feat=="atrProxy" && val<=102.540000) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-2.364876 && val<=-0.736934) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.081000 && val<=0.572600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.551200) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.308200) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.367600 && val<=0.438400) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.280000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.214540) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=-1.287246 && val<=1.428240) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.013255 && val<=2.423396) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.748713 && val<=0.534077) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.141800 && val<=0.751400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.046950 && val<=0.801310) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=0.000000 && val<=2.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.676800 && val<=0.738100) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.930000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.037000 && val<=0.225200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.600000 && val<=0.702100) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.611000 && val<=0.718100) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.355300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.814600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.414000 && val<=0.444000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.281800 && val<=0.391100) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.216000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.792600) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.888900 && val<=0.985100) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=26.377510 && val<=1238.893730) _g_bev_votes++;
      if(feat=="msContext" && val<=0.361575) _g_bev_votes++;
      if(feat=="msContext" && val>=0.627750) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.272800) _g_bev_votes++;
   }
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpCompVAH" && val<=-6.772057) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.545000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.598800) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.792400) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.395600 && val<=0.475280) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.692140) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.845877) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.578810) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.005000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.515000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.368000 && val<=0.456200) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.179000) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="BREAKOUT")
   {
      if(feat=="vpDistToLVN" && val<=0.060500) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-15.530203) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-21.519077) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.018000 && val<=0.056000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.651100 && val<=0.892300) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.199000 && val<=0.336500) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=951.071100) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.614375) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.283000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.423600 && val<=0.509300) _g_bev_votes++;
      if(feat=="atrProxy" && val<=118.500000) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.874288 && val<=-0.115705) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.130520 && val<=0.311380) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.432800 && val<=0.761800) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.440411 && val<=1.620789) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.796755) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.581832 && val<=0.411782) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.110200 && val<=0.645400) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.042400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.288080 && val<=-0.641020) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.282400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.684000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.009000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.991000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="NAKED_POC")
   {
      if(feat=="vpDistToLVN" && val>=0.186200 && val<=0.595400) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.276624 && val<=5.575136) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.326400) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.379200 && val<=0.454000) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="PULLBACK")
   {
      if(feat=="vpDailyPOC" && val>=-4.671045 && val<=-1.143579) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-8.128418 && val<=-1.233310) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-3.174766 && val<=2.864783) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-13.387151 && val<=-5.439427) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.160000 && val<=0.583000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.618000 && val<=0.729000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.500000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.369000 && val<=0.435000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=1033.720400) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.292000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=115.900000) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpVAH" && val<=1.127135) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.094649 && val<=0.633373) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.182600 && val<=0.814000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.665900 && val<=0.725000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.830800) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.365000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.855300) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.010300) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.989700) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.515760) _g_bev_votes++;
   }
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpCompPOC" && val<=-15.450486) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-7.574629) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-21.632581) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.094300) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.017100 && val<=0.055900) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.754600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.615100 && val<=0.723000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=117.320000) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-1.087821 && val<=1.274535) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.057695 && val<=2.307347) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-2.069616 && val<=0.238421) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.793320 && val<=0.493340) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-2.012639 && val<=2.534768) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=19.719491) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.790000 && val<=0.755000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.734600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.332700) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.033000 && val<=0.288000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.712000 && val<=0.967000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=-1.000000 && val<=1.000000) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAH" && val>=0.243626 && val<=2.228940) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-1.957377 && val<=1.987315) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-4.724645 && val<=3.604702) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.504400) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val>=0.096480) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.206000 && val<=0.356000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.360000) _g_bev_votes++;
      if(feat=="chochQuality" && val<=-0.267383) _g_bev_votes++;
      if(feat=="atrProxy" && val<=188.400000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.177520 && val<=0.287140) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpCompVAH" && val>=18.626308) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.443100 && val<=0.800900) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.738300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=0.831600 && val<=2.419700) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.261300) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.996300) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.036100 && val<=0.258000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.742000 && val<=0.963900) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-465.953100) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.396700) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.355100) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.071200) _g_bev_votes++;
      if(feat=="atrProxy" && val>=488.760000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.275700) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=-1.244669 && val<=0.434355) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.404285 && val<=1.320501) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-2.418049 && val<=-0.594641) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.519900 && val<=0.774620) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-2.897024 && val<=1.424462) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.783000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.750000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.772400) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.944400) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.795200) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.307833 && val<=0.342500) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.507067 && val<=0.915902) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.282867 && val<=2.061906) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.190500 && val<=0.647200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.696840 && val<=0.231960) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-4.138952) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.057300) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.314800) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.946400) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.738700) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.371225) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.298500) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="PULLBACK")
   {
      if(feat=="vpDistToHVN" && val>=0.090200 && val<=0.589400) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-4.691582 && val<=3.643977) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-18.441687) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.545000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.858600) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.952800) _g_bev_votes++;
      if(feat=="chochQuality" && val<=-0.267139) _g_bev_votes++;
      if(feat=="atrProxy" && val<=194.740000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.172960 && val<=0.279100) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=-1.758368 && val<=0.937289) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-2.682493 && val<=-0.124166) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.026700) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.818740 && val<=1.081730) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.058099 && val<=1.250805) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.804600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.590300 && val<=0.713900) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.896100 && val<=0.977900) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.309250 && val<=0.347483) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.048000) _g_bev_votes++;
   }
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDistToHVN" && val<=0.018200) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-1.967613 && val<=1.972916) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-4.274785 && val<=3.657693) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.576400) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.606600 && val<=0.717000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.484400) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.172800) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-726.286960) _g_bev_votes++;
      if(feat=="atrProxy" && val<=190.340000) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.021100) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.053000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAL" && val>=-2.658457 && val<=-1.136940) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-16.191850) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.773000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.761000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.749000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.306000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.900000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpDistToHVN" && val<=0.013000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.162970 && val<=0.262300) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.756000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.303000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.343700 && val<=0.403300) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.060000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.314700 && val<=0.414000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.296000 && val<=0.335933) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.534930 && val<=1.439390) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.861649) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.255008 && val<=2.302538) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.442385 && val<=0.500724) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.086400 && val<=0.592200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.098280 && val<=-0.500640) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.188211 && val<=2.836446) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=15.086481) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.120200 && val<=0.454200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.623000 && val<=0.701200) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.264800) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.665600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.383000 && val<=0.432600) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.209400 && val<=0.340600) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.352960 && val<=0.458920) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="NAKED_POC")
   {
      if(feat=="vpCompPOC" && val>=-1.232009 && val<=4.853707) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.297800 && val<=0.597400) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.796400) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.636000 && val<=0.720200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.733400) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.099200) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.959400) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="PULLBACK")
   {
      if(feat=="vpCompPOC" && val>=-7.372035 && val<=-0.500464) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.809334 && val<=4.100734) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.685000 && val<=0.860000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.625000 && val<=0.727500) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.361000 && val<=0.422000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.216000 && val<=0.258000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=1.100000) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=1.017579 && val<=1.701679) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.051743 && val<=0.743197) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.022000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.091300 && val<=0.706600) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.040400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.304320 && val<=-0.809620) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.077000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.814600) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.274100 && val<=0.613900) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.545000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.089100 && val<=0.315300) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.763300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.827500) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.397000 && val<=0.436000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.164000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.885000 && val<=0.966000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.320400 && val<=0.436900) _g_bev_votes++;
   }
   if(symbol=="METAm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpPOC" && val>=-1.264702 && val<=-0.081732) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.125280 && val<=0.629080) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.901600) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.310000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=1.080000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-312.973940 && val<=458.827520) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=325.140000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.292690) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.743700) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="BREAKOUT")
   {
      if(feat=="vpDistToLVN" && val<=0.057400) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.181000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.949000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.309000 && val<=0.410000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.559920) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.054900) _g_bev_votes++;
      if(feat=="smContext" && val>=0.414800) _g_bev_votes++;
      if(feat=="atrProxy" && val<=170.140000) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.595786 && val<=0.088483) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.123606 && val<=0.939641) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.348400 && val<=0.962200) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.150620 && val<=0.249420) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-3.186190 && val<=-0.087678) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.021400 && val<=0.216140) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=-0.103201 && val<=0.940862) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.676413 && val<=1.911431) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.882605 && val<=0.119474) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.021000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.896390 && val<=-0.123140) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.614900 && val<=0.711000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.282600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.694300) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=1497.598850) _g_bev_votes++;
      if(feat=="msContext" && val<=0.361450) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.372760 && val<=0.482480) _g_bev_votes++;
      if(feat=="atrProxy" && val<=162.780000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.534150) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.921831 && val<=0.668306) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019500) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.706370 && val<=0.345740) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.247700 && val<=0.536000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.206000 && val<=0.247000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.874400 && val<=0.961000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.500000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=1.400000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-322.420880 && val<=147.384900) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.991400) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="PULLBACK")
   {
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.068000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.208300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.554900) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.365600) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.841900 && val<=0.970000) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.353977 && val<=1.338876) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.995978 && val<=2.205168) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.542468 && val<=0.428206) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.027000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.134200 && val<=0.720000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.110120 && val<=-0.733860) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=1.647972 && val<=7.702239) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.076200 && val<=0.305600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.478600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.828400) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.400000 && val<=0.438000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.360250) _g_bev_votes++;
      if(feat=="msContext" && val>=0.611950) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.561860) _g_bev_votes++;
   }
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpCompInsideVA" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.300000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=4.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.927600) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.316000 && val<=0.415000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.049900) _g_bev_votes++;
      if(feat=="atrProxy" && val<=162.390000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.531740) _g_bev_votes++;
   }
   if(symbol=="NFLXm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.267720) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.314000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.662000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.922200) _g_bev_votes++;
      if(feat=="msContext" && val<=0.372400) _g_bev_votes++;
   }
   if(symbol=="NFLXm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=-1.991798 && val<=-0.771598) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.015000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.088800 && val<=0.885600) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.948717 && val<=3.701911) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.842500) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegime" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.616000 && val<=0.760500) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.549500) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.815500) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-548.981100) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.420500 && val<=0.491000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.380600) _g_bev_votes++;
      if(feat=="atrProxy" && val>=97.600000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.544000) _g_bev_votes++;
   }
   if(symbol=="NFLXm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpLTTransitionScore" && val>=0.095000 && val<=0.308800) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.691200 && val<=0.905000) _g_bev_votes++;
   }
   if(symbol=="NFLXm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.126442 && val<=1.111968) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.004300 && val<=-0.395500) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.755000 && val<=0.641160) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.788600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.622600 && val<=0.740600) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.800000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.528620) _g_bev_votes++;
   }
   if(symbol=="NFLXm" && setup=="PULLBACK")
   {
      if(feat=="vpDistToLVN" && val>=0.195000 && val<=0.725500) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-7.419854 && val<=-0.265163) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.358609 && val<=4.158004) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.104500 && val<=0.261050) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.306500) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.814000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-508.507500) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.358500) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.414300 && val<=0.484000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.548200) _g_bev_votes++;
   }
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpVAH" && val<=0.796150) _g_bev_votes++;
      if(feat=="vpVAL" && val<=-0.798881) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.770700) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.328000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=1.321700) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.811300) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.695500 && val<=0.853200) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.554370) _g_bev_votes++;
   }
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDistToHVN" && val<=0.013000) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=10.273261) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.093552 && val<=4.602789) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.768500) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.206000 && val<=0.247000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.813000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-764.289500) _g_bev_votes++;
      if(feat=="msContext" && val<=0.366625) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.353800) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.830000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.900000 && val<=1.011000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.396800 && val<=0.412300) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.596750) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.806000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.366650) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.101940 && val<=0.161620) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.148632) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.209800) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.958100) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.174000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.375880) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.568630 && val<=-0.022541) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.120520 && val<=0.242560) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.662000 && val<=0.732400) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.589000 && val<=0.702000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.801000 && val<=0.900800) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.878000 && val<=0.947400) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val<=-0.058952) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.316166 && val<=1.392370) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.729450) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.150825 && val<=2.283208) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.509575 && val<=0.365150) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.019000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.080000 && val<=0.588000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.135800 && val<=-0.589400) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.349085 && val<=2.104296) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-2.618729) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.366800) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.781000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.807000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.313000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.279000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.676000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.800000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.414833) _g_bev_votes++;
      if(feat=="smContext" && val<=0.382000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.406600) _g_bev_votes++;
      if(feat=="atrProxy" && val<=101.100000) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="NAKED_POC")
   {
      if(feat=="vpDailyPOC" && val>=-1.436279 && val<=1.496458) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.673000 && val<=0.745000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=-0.720000 && val<=0.685000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.311000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.287833 && val<=0.332333) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="PULLBACK")
   {
      if(feat=="vpCompVAH" && val>=-1.826397 && val<=2.983496) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003900) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.605100 && val<=0.715000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.256300) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.270900) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.654565 && val<=1.754031) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.414712 && val<=2.610753) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.118925 && val<=0.699864) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.021000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.087700 && val<=0.727300) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.673700 && val<=0.750000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.284000 && val<=0.396300) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.129000 && val<=0.242000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.878700 && val<=0.959300) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.322140 && val<=0.443160) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.773000 && val<=0.930600) _g_bev_votes++;
   }
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDistToLVN" && val>=1.308600) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-8.664310) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.780400) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.955000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.486400) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.304000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val<=0.629000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.500000) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.337760) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.089457) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.770794) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.205010) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.756600) _g_bev_votes++;
      if(feat=="auctRegime" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.331000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.322900) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.567000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.729900) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.010111) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.955363) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.042000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.172850) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.168469) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-11.667657) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-6.379661) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-16.811226) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.600000 && val<=0.706000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.316000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.759500 && val<=0.884000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.015000 && val<=0.046000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.954000 && val<=0.985000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=832.678850) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.418700) _g_bev_votes++;
      if(feat=="smContext" && val>=0.398000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=891.200000) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.334698 && val<=1.265199) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.128246 && val<=2.237054) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.015550 && val<=-0.479950) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.252411 && val<=2.106434) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-2.278139 && val<=2.611520) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-14.242152) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.784000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.285000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.680500) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.006000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.116000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.884000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.994000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.335000 && val<=0.448000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.420300 && val<=0.510500) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.521500) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="NAKED_POC")
   {
      if(feat=="vpDistToHVN" && val<=0.020400) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-5.700922) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-11.408664) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.062600) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.238200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.638400) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.200000 && val<=0.800000) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="PULLBACK")
   {
      if(feat=="vpDistToHVN" && val>=0.869400) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-6.346335 && val<=-1.111161) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.328989 && val<=2.557230) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.347200 && val<=0.633400) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.318200) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.200000 && val<=0.900000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=808.374740) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.917600 && val<=1.023000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.399000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=874.120000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=2544.420000) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.860182 && val<=1.522670) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.454028 && val<=2.574754) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.140831 && val<=0.615980) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.173100 && val<=-0.812700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.155381 && val<=2.628081) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-1.720321 && val<=2.938288) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.795000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.330000 && val<=0.625000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.860000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=-0.141200 && val<=0.099000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.774000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.793000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.616000 && val<=0.722000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.487000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.357000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.844000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.274000 && val<=0.382000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.748000 && val<=0.887000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.790000 && val<=0.943000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=832.100000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.580200) _g_bev_votes++;
   }
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpPOC" && val<=-2.704821) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-1.462805) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.041000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-1.209760) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.300753) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-6.025202 && val<=-1.005989) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=2.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.794100) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=0.035070) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.615700 && val<=0.715300) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.313900) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.399300) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.014000 && val<=0.046000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.954000 && val<=0.986000) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.399780) _g_bev_votes++;
      if(feat=="smContext" && val>=0.399200) _g_bev_votes++;
      if(feat=="atrProxy" && val<=859.090000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.546140) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpVAL" && val>=-3.936766) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.032000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.806700) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.232200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.603600) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.135300) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.284067) _g_bev_votes++;
      if(feat=="smContext" && val>=0.413140) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=2.502342) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-21.441663 && val<=-7.215050) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.872800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.180360) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.095700) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.554700) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.310000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.350000 && val<=0.436000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.437000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.362950) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.278000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=517.190000) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-3.449107 && val<=1.407929) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.997972 && val<=7.658763) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.137755) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.051000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.108800 && val<=0.186500) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.410400) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.782000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.635000 && val<=0.759000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.304000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.185000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.481000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.306000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.301500 && val<=0.341667) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=4.818246 && val<=13.788705) _g_bev_votes++;
      if(feat=="vpVAH" && val>=12.765216 && val<=24.321193) _g_bev_votes++;
      if(feat=="vpVAL" && val<=-5.090785) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.790376 && val<=6.066297) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.061000 && val<=0.455400) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.976000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.896600 && val<=-0.326980) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-32.877014) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.795400) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.134000 && val<=0.513600) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.628000 && val<=0.723600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.634000 && val<=0.735000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.275000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.646800) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.193000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.345650) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.025200) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.011480) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.043640) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="NAKED_POC")
   {
      if(feat=="vpVAH" && val>=-1.474030 && val<=7.843255) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.056000 && val<=0.360500) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-87.306557) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.818000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.788700) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.400000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.236000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.663300) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.389250 && val<=0.582750) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.431140 && val<=0.511820) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.026000) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-17.916843 && val<=-5.583802) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-21.004776 && val<=34.338735) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.861000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.095000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.381000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.811000 && val<=0.907000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.631250) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.285000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.388000 && val<=0.403800) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=12.348197 && val<=17.990644) _g_bev_votes++;
      if(feat=="vpVAH" && val>=16.907593 && val<=28.317784) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.858860 && val<=8.492050) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.068000 && val<=0.453900) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.160000 && val<=0.572800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.147460 && val<=-0.801400) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=1.560067 && val<=27.231751) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-127.490019) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-42.161528) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=122.148612) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-205.366216) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.874900) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.795500) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.825000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.341400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.809000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.868000 && val<=0.940000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.337175) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.058900) _g_bev_votes++;
      if(feat=="atrProxy" && val<=457.860000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.046030) _g_bev_votes++;
   }
   if(symbol=="US30m" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpCompPOC" && val<=-134.408370) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.850800) _g_bev_votes++;
      if(feat=="auctAcceptance" && val<=0.072600) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.317000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.444000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.389000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.550607) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.484739) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.034000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.399900) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.006000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.225800) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.800000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.254000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.638000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.312000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.130000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.855000 && val<=0.929000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.752000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.364800) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.232770) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.947498) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-2.287225 && val<=-0.859017) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.186800) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-23.120319) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.324000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.174000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.193000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.960000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.202800) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.797200) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.374000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.528000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.373400 && val<=0.387200) _g_bev_votes++;
      if(feat=="atrProxy" && val<=697.480000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.083280) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.480215 && val<=0.083322) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.171354) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-1.440150 && val<=-0.483032) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.101200 && val<=0.243200) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.500000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.302000 && val<=0.596000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.768000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.623000 && val<=0.740000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.309000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.172000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.466000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.021000 && val<=0.062000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.938000 && val<=0.979000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.300000 && val<=1.500000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.300000 && val<=0.342167) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.411600) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.565134 && val<=1.317213) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.259886 && val<=2.413826) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.288077 && val<=0.537450) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.054000 && val<=0.400200) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.149400 && val<=0.457600) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.887480 && val<=-0.392900) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-12.588196) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-4.765910) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.860000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.315000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.261600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.643800) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.192600) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-240.939640) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.497800 && val<=0.923000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.349650) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.268800) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.415280 && val<=0.501600) _g_bev_votes++;
      if(feat=="smContext" && val<=0.368200) _g_bev_votes++;
      if(feat=="smContext" && val>=0.375080 && val<=0.388000) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="NAKED_POC")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.524000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.450000) _g_bev_votes++;
      if(feat=="auctRegime" && val>=6.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.304000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val<=-0.109800) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.593000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.723000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.366750) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.215000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.253500) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.605000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.360400) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-1.852819 && val<=-0.642950) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-4.221346 && val<=-1.031679) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.578330 && val<=2.342485) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-22.218183) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.593000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.320000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.084900 && val<=0.186000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.002000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.998000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.100000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=25.060000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=1114.091700) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.374000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=693.640000) _g_bev_votes++;
   }
   if(symbol=="US500m" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=1.192995 && val<=1.685236) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.065057 && val<=0.807120) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.016200) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.068600 && val<=0.453400) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.152000 && val<=0.516400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.100720 && val<=-0.802060) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-3.946243) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.014613 && val<=2.505840) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.480000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.806000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.021000 && val<=0.064400) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.935600 && val<=0.979000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.447200 && val<=0.805800) _g_bev_votes++;
      if(feat=="msContext" && val<=0.342950) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.367800 && val<=0.476280) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.126600) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.000261) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.001207) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.000579) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.026000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.285380) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005839) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.011590) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=0.001289) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.781200) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.317900) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.120000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.563400) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.007900) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.992100) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.367300) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.818900) _g_bev_votes++;
      if(feat=="atrProxy" && val>=158.920000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.096290) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="BREAKOUT")
   {
      if(feat=="vpDistToLVN" && val>=0.936800) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.005678) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005125) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.010349) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.350820) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=1.507600 && val<=3.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.075000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.906000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=510009.960200) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.374000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.287233) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.884000 && val<=0.970000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.380400) _g_bev_votes++;
      if(feat=="atrProxy" && val<=71.920000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=156.840000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.098120) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.215300) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.000637 && val<=-0.000036) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.000139) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000048 && val<=0.000700) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001569 && val<=-0.000651) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.130920 && val<=0.241560) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.643000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.628000 && val<=0.747000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.188000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.501000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.306400) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=496728.000820) _g_bev_votes++;
      if(feat=="msContext" && val>=0.378300 && val<=0.548500) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.368900) _g_bev_votes++;
      if(feat=="smContext" && val>=0.359800 && val<=0.372800) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.000763 && val<=0.000157) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001444 && val<=-0.000372) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.232300 && val<=0.306100) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.760000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.074000 && val<=0.205000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.795000 && val<=0.926000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=162.200000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.094800) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.002040 && val<=-0.000838) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005509) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.005206 && val<=-0.000389) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.001770 && val<=0.003592) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.009353 && val<=-0.003499) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.086600) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.737000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=509190.197180) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.374000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.627250) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.555000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.382200) _g_bev_votes++;
      if(feat=="atrProxy" && val<=70.320000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=154.380000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.099900) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.217200) _g_bev_votes++;
   }
   if(symbol=="USDCADm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpPOC" && val<=-0.002490) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.001176) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=1.376560) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.005565) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.010870) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.533000) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.487000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=1.613000 && val<=3.000000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.007000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.993000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=507817.154920) _g_bev_votes++;
      if(feat=="atrProxy" && val>=154.820000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.098780) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val<=-0.000641) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.000387) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.028000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.400300) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.000253 && val<=0.001982) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.774000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.902000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.299000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.867700 && val<=1.244000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.300000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.116000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.200100) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.962000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.567400) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.687000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.089500) _g_bev_votes++;
   }
   if(symbol=="USDCHFm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.000502 && val<=0.000524) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.000057 && val<=0.001307) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.001212 && val<=-0.000235) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.333850 && val<=0.309250) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.004018) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.450000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.878500) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.300000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.133000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.378750 && val<=0.554500) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.052322) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.124556) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.034009) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.031000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.396620) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.160950) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.397763) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.366000 && val<=0.651100) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.798200) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.307300) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.143000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.762000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-134.410800 && val<=2496.285390) _g_bev_votes++;
      if(feat=="msContext" && val<=0.368250) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.778000 && val<=0.919100) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.017708) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.100141) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.217264 && val<=-0.091700) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.058300) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=1.128900) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.162700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.339636 && val<=-0.109363) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-1.137538) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val>=0.007000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.084670 && val<=0.231210) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.969000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.303000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-143.576140 && val<=2584.873230) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.532000 && val<=0.838100) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.286333) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.387200) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.072550) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.046199 && val<=0.012000) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.017114) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.012000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.081000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.127840 && val<=0.223080) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.771800) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.790800) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.478200 && val<=0.789000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.770000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.639000 && val<=0.757000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.930600 && val<=1.145000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.304000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.708000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.384200 && val<=0.398800) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.073480) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="NAKED_POC")
   {
      if(feat=="vpDistToLVN" && val<=0.048000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.672000 && val<=0.736500) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.901500) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.100000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.206000 && val<=0.269000) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.179515 && val<=-0.065903) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.045000) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.323584 && val<=-0.076503) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-1.115278) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.187793 && val<=0.311575) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.311200 && val<=0.600400) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.359000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.450200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=1.238000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.380800) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-130.519200 && val<=2725.521960) _g_bev_votes++;
      if(feat=="msContext" && val<=0.365750) _g_bev_votes++;
   }
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpDistToHVN" && val<=0.014500) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.052500) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.322583 && val<=-0.079366) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.212000 && val<=0.258000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-129.912000 && val<=2739.296200) _g_bev_votes++;
      if(feat=="msCompression" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.307750 && val<=0.345500) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.373400) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.077400) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=-0.023309 && val<=0.112719) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.057930 && val<=0.208457) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.118578 && val<=0.034489) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.022000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.135200 && val<=0.541000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.713840 && val<=0.132840) _g_bev_votes++;
      if(feat=="vpCompPOC" && val<=-0.718776) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.309960) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.900800) _g_bev_votes++;
      if(feat=="auctFailure" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.209200) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.566000 && val<=1.198800) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.583200) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.302000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.102200) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.390267) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.578040) _g_bev_votes++;
      if(feat=="smContext" && val>=0.408360) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.032470 && val<=0.029405) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.007865) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.027175 && val<=0.112407) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.011802) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.012000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.079600) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.184170 && val<=0.199700) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.029395 && val<=0.194069) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.151486 && val<=0.314226) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.334800 && val<=0.606100) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.457000 && val<=0.772100) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.775000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.640900 && val<=0.749000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.309000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.173600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.467000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.338900 && val<=0.392000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.262400) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.251000 && val<=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.500000 && val<=0.749000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.358000) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.388060) _g_bev_votes++;
      if(feat=="atrProxy" && val>=268.100000 && val<=514.760000) _g_bev_votes++;
   }
   if(symbol=="USOILm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.028614 && val<=0.058633) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.025329 && val<=0.132386) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.091751 && val<=-0.003964) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.039600 && val<=0.305800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.382080 && val<=0.178100) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.247200) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.935600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.307000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.053000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.060800) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.526600) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.473400) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.939200) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.577000) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.552268) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.376933) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.206600 && val<=0.688700) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.371290) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.139100) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.088000 && val<=0.208700) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.746400) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.217878) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.165450) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.353000 && val<=0.436500) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.175500 && val<=0.313000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.002500) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.997500) _g_bev_votes++;
      if(feat=="msContext" && val<=0.368375) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpVAL" && val>=-0.152079) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.038000 && val<=0.220800) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.051000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.772000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.609000 && val<=0.713000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.632000 && val<=0.744000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.158000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.425200) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.305000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.352000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.266600) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="NAKED_POC")
   {
      if(feat=="vpDistToHVN" && val<=0.013900) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-1.018707 && val<=2.034694) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.003000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.550000) _g_bev_votes++;
      if(feat=="auctRegime" && val>=6.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.644000 && val<=0.750000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.241600) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val<=-0.084620) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="msCompression" && val<=0.245700) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.208100) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.217433) _g_bev_votes++;
      if(feat=="liqContext" && val<=0.201000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.477000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.325980) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-1.756040 && val<=-0.623597) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-2.588914 && val<=2.430099) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.300000 && val<=0.594000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=0.035700) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.356000 && val<=0.424000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.178000 && val<=0.309000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.366250) _g_bev_votes++;
      if(feat=="msContext" && val>=0.631750) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.291000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.380167) _g_bev_votes++;
      if(feat=="smContext" && val>=0.391200 && val<=0.407200) _g_bev_votes++;
   }
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=1.227512 && val<=1.818699) _g_bev_votes++;
      if(feat=="vpVAH" && val<=1.401544) _g_bev_votes++;
      if(feat=="vpVAH" && val>=1.693849 && val<=2.827835) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.158858 && val<=0.842710) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.021000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.068000 && val<=0.462800) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.152000 && val<=0.554000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.154440 && val<=-0.801300) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-2.915333) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.366711 && val<=2.827037) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-2.834415) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.004000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.772600) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.247200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.774000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.609200 && val<=0.711800) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.789000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.493000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.345000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.805000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.340350) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.378200 && val<=0.481560) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.065200) _g_bev_votes++;
      if(feat=="smContext" && val>=0.417720) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.038424) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.103980) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.060105) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.026800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.342820) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.055844) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.284630) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.691534) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.146546) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.784000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.321800) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.137000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.174000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.952000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.774400 && val<=0.887000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.786400) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.867000 && val<=0.937000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.584040) _g_bev_votes++;
      if(feat=="atrProxy" && val>=1098.240000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.037500) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="NAKED_POC")
   {
      if(feat=="vpPriceVsPOC" && val>=-0.466700 && val<=0.288940) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.797000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.310400) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.750200 && val<=0.886000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.863200 && val<=0.934000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.564200) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.435800) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.425240 && val<=0.521120) _g_bev_votes++;
      if(feat=="smContext" && val<=0.327560) _g_bev_votes++;
   }
   if(symbol=="XAGEURm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val<=0.040796) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.092602 && val<=0.144358) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.108512) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.144176 && val<=0.227779) _g_bev_votes++;
      if(feat=="vpVAL" && val<=-0.035395) _g_bev_votes++;
      if(feat=="vpVAL" && val>=0.001933 && val<=0.068356) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.016000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.068000 && val<=0.402800) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.721620) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.041620 && val<=-0.809900) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.003253 && val<=0.194648) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.824891 && val<=-0.126354) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.786200) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.363000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.833000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.940600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.756000 && val<=0.876800) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.800800) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.448000 && val<=0.748000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.352000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.370750 && val<=0.428550) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.290500 && val<=0.316967) _g_bev_votes++;
      if(feat=="atrProxy" && val<=93.500000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.456700) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.031016) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.106511) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.058172) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.290520) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.077818) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.121624) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.550000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.762600) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.264800) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.657800) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.324400) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.134600) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.784800) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.313000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.300967) _g_bev_votes++;
      if(feat=="atrProxy" && val>=907.000000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.038600) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.001507) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.085326) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.242503 && val<=-0.115983) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.161410) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.032095) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.212199) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.786000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.602000 && val<=0.708000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.174000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.775400) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.291833) _g_bev_votes++;
      if(feat=="smContext" && val>=0.350220 && val<=0.379380) _g_bev_votes++;
      if(feat=="atrProxy" && val<=88.380000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.406700) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.062476 && val<=-0.003467) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.027471) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.104800 && val<=0.256540) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.777700) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.711840 && val<=0.860000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.720000 && val<=0.860000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.765000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.614000 && val<=0.738000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.181000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.456600 && val<=1.106000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.509300) _g_bev_votes++;
      if(feat=="msContext" && val>=0.620675) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.790000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.414800) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.045324 && val<=0.119607) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.079714) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.112739 && val<=0.199337) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.041742 && val<=0.035325) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.015000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.920600 && val<=-0.600200) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.023091 && val<=0.183748) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.363585) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.781000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.255000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.108000 && val<=0.428000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.779000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.790000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.327000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.292000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.720000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.386000 && val<=0.434000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.374000 && val<=0.465500) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.135000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.351000 && val<=0.390600) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.436800) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="NAKED_POC")
   {
      if(feat=="vpBestHVNScore" && val>=0.792500) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.287900 && val<=0.548700) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.935400) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=9856.075890) _g_bev_votes++;
      if(feat=="smContext" && val<=0.336000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.352120 && val<=0.393660) _g_bev_votes++;
      if(feat=="atrProxy" && val>=106.170000 && val<=405.830000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.088690 && val<=0.345670) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.094507 && val<=0.145486) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.107614) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.144368 && val<=0.231925) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.004053 && val<=0.065198) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.016000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.061000 && val<=0.380600) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.059210 && val<=-0.809410) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.004166 && val<=0.212095) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.337983) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.777000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.617000 && val<=0.715000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.796100) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.325000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.360000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.835900) _g_bev_votes++;
      if(feat=="msContext" && val>=0.370500 && val<=0.433900) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.176000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=77.100000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.468050) _g_bev_votes++;
   }
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpPOC" && val>=-0.115411 && val<=-0.021312) _g_bev_votes++;
      if(feat=="vpVAH" && val>=-0.047017 && val<=0.039495) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.204088 && val<=-0.084350) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.049000 && val<=0.357000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.186500 && val<=0.554000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.042200 && val<=0.515250) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.423266 && val<=-0.115669) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.257315) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.788000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.949500) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.309000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.085000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.782000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.351600 && val<=0.379500) _g_bev_votes++;
      if(feat=="atrProxy" && val<=85.000000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.419000) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.053833) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.121994) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.048223) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.160200 && val<=0.652000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.403120) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.115489) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.159000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.790000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.545000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.550000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.832200) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.305400) _g_bev_votes++;
      if(feat=="auctVAExpRate" && val<=-0.148520) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.559800) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.174000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.295200) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.955000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.783400) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.577800) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.422200) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.303000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.299233) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.712000) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.056904 && val<=0.000779) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-0.017082) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.024486) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.010000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.125700 && val<=0.229700) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.660928) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.375000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.783000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.302000 && val<=0.592000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.459000 && val<=0.780000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.766000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.625000 && val<=0.739500) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.201500) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.594500 && val<=1.112000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.544000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.303000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.060000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.962000) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val<=-2.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.625000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.377750 && val<=0.550750) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.436400 && val<=0.508400) _g_bev_votes++;
      if(feat=="atrProxy" && val<=130.200000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.024200) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.049924 && val<=0.128499) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.085017) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.115086 && val<=0.209618) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.041019 && val<=0.043139) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.056000 && val<=0.362000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.173800 && val<=0.495400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.883300 && val<=-0.419120) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.027666 && val<=0.189105) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.339882 && val<=0.211619) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.388227) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.807958 && val<=-0.149083) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.778000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.860000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.625000 && val<=0.716200) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.634000 && val<=0.732000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.293200) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.914000 && val<=1.259400) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.705200) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.951400) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val<=0.000000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.357300) _g_bev_votes++;
      if(feat=="msContext" && val>=0.371250 && val<=0.477850) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.289000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.398360 && val<=0.487000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=118.100000) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.049437 && val<=0.073702) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.015211 && val<=0.131026) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.125278 && val<=-0.020256) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.590640 && val<=0.220000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.770800 && val<=0.884000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.862400 && val<=0.939000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.417600 && val<=0.513520) _g_bev_votes++;
      if(feat=="smContext" && val>=0.396200) _g_bev_votes++;
   }
   if(symbol=="XAGUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.192639 && val<=-0.080935) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.285832 && val<=0.240392) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.301200 && val<=0.595800) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=0.038640) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.778200 && val<=1.204000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.353000 && val<=0.425000) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.170400) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.500000 && val<=0.503000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.497000 && val<=0.500000) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.881000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=120.600000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.291020) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.005590) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.091942) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.075830) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.040500) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.241500 && val<=0.701500) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.193450) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.039255) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.223745) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.134026) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.825000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.152250) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.678500) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.438000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.324000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.170500) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.598000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.290000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.016000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.984000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.999000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.377250) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.296833) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.065200) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAL" && val>=-0.243275 && val<=-0.122263) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.160400) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.116207) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.772000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.255000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-21.250400 && val<=3472.138100) _g_bev_votes++;
      if(feat=="msContext" && val<=0.374250) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.308000) _g_bev_votes++;
      if(feat=="smContext" && val<=0.096200) _g_bev_votes++;
      if(feat=="atrProxy" && val<=11384.300000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.398800) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpVAL" && val>=-0.171990 && val<=-0.072686) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.780200) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.611000 && val<=0.710800) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.633000 && val<=0.745000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.171200) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.465600) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.344600) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.032559 && val<=0.105630) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.103329 && val<=0.193185) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.050795 && val<=0.028726) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.053000 && val<=0.385400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.868660 && val<=-0.390140) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.017090 && val<=0.164845) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.203416 && val<=0.202626) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.778000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val<=0.486600) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=0.650000 && val<=0.900000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.791000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.150000 && val<=0.250000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.647400 && val<=0.746000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.285000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.673800) _g_bev_votes++;
      if(feat=="auctContinuation" && val<=0.147600) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.272000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-23.396720 && val<=2976.376480) _g_bev_votes++;
      if(feat=="msContext" && val<=0.367250) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.295333 && val<=0.320167) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.000000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.895400) _g_bev_votes++;
      if(feat=="smContext" && val>=0.107880 && val<=0.414000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=11172.040000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.406400) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="NAKED_POC")
   {
      if(feat=="vpLTTransitionScore" && val<=0.009000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.991000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.061060 && val<=0.196700) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.212836 && val<=-0.100575) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.047600) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.303993 && val<=0.207214) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.969000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val>=3.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.305000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.763000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-11.975320 && val<=3471.251200) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.575000 && val<=0.803800) _g_bev_votes++;
      if(feat=="msContext" && val<=0.374250) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.583320) _g_bev_votes++;
      if(feat=="atrProxy" && val<=11514.740000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.394300) _g_bev_votes++;
   }
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpVAH" && val>=-0.052576 && val<=0.033420) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.207122 && val<=-0.093460) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.053000 && val<=0.382000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.064800 && val<=0.533930) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.692000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.781000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.548000 && val<=1.163000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.351000 && val<=0.424000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.206000 && val<=0.258000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.764000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.016000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.984000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-17.108970 && val<=3447.384650) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.351533) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.468140 && val<=0.537400) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.907100) _g_bev_votes++;
      if(feat=="smContext" && val<=0.098200) _g_bev_votes++;
      if(feat=="atrProxy" && val<=11163.450000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.406670) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.013052) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.093102) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.086876) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.231100) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.063408) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.210618) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.627403) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.185753) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.650000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.135000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val<=-0.790000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val<=-0.163700) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.611000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.327000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.311000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.628000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.046500) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=-0.008445) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.158550) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.698600 && val<=1.211300) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.955000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.771000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=22.982900 && val<=5219.015840) _g_bev_votes++;
      if(feat=="msContext" && val<=0.374750) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.476340 && val<=0.540460) _g_bev_votes++;
      if(feat=="atrProxy" && val<=6470.560000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.508750) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.083993 && val<=-0.011632) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.037442) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.185604 && val<=-0.083166) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.106460 && val<=0.333620) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.800000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.745700) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.409000 && val<=0.744000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.765000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.628000 && val<=0.746100) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.199000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.760000 && val<=0.884100) _g_bev_votes++;
      if(feat=="atrProxy" && val>=12807.800000 && val<=19562.680000) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="NAKED_POC")
   {
      if(feat=="vpThinnessRatio" && val>=0.700000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val>=2.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.095400) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.890600) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.579800) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.763000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=0.000000 && val<=0.200000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=17.550180 && val<=1740.344100) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.226566 && val<=-0.105430) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.443890 && val<=-0.127117) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.707390 && val<=-0.156004) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.314799 && val<=0.163021) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.699000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.355000 && val<=0.427000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.780000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=19.339500 && val<=5040.362900) _g_bev_votes++;
      if(feat=="atrProxy" && val<=6622.200000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.082500) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.497100) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val<=0.015504) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.076575 && val<=0.128358) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.084106) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.127944 && val<=0.203553) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.008283 && val<=0.055679) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.056000 && val<=0.438600) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.044740 && val<=-0.812120) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.290748) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.007167 && val<=0.193983) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.784600) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.337000 && val<=0.618800) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.860000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.279240) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.633400 && val<=0.723000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.650200 && val<=0.746600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.505000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.367000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.845800) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.948000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.359300) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.288333 && val<=0.313000) _g_bev_votes++;
   }
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpPOC" && val>=-0.145212 && val<=-0.035038) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.222203 && val<=-0.102863) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.047350 && val<=0.575400) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.972000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.694000 && val<=1.179000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.957000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.022000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.978000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=17.655550 && val<=4885.978700) _g_bev_votes++;
      if(feat=="atrProxy" && val<=6128.650000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.537150) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpPOC" && val>=0.012775) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.108212) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.088018) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.223670) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.077322) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.227694) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.155915) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.650000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.344000 && val<=0.601300) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.615000) _g_bev_votes++;
      if(feat=="auctBalance" && val<=0.417900) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.339000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.811000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.375250) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.297467) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.357333) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.607000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.594000) _g_bev_votes++;
      if(feat=="spreadToATR" && val<=0.047560) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAL" && val>=-0.268398 && val<=-0.139759) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.122030) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.098173) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.233000 && val<=0.664700) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=17.088200 && val<=4165.745600) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.294500) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.471120 && val<=0.540600) _g_bev_votes++;
      if(feat=="atrProxy" && val<=5675.150000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.577970) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpVAH" && val>=-0.005863 && val<=0.053748) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.040011) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.119700 && val<=0.350100) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.699662) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.269000 && val<=0.571000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.095450 && val<=0.237100) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.762000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.602000 && val<=0.706000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.628500 && val<=0.752000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.176000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.475500) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.206000 && val<=0.269000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.762000 && val<=0.888500) _g_bev_votes++;
      if(feat=="vpLTTrendExhaustion" && val>=1.000000) _g_bev_votes++;
      if(feat=="msContext" && val>=0.621750) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.345833) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val<=-0.032607) _g_bev_votes++;
      if(feat=="vpPOC" && val>=0.022557 && val<=0.099589) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.043016) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.089523 && val<=0.179726) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.057480 && val<=0.021080) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.050000 && val<=0.389000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.907500 && val<=-0.464070) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.346360) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.033695 && val<=0.157702) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=-0.287347 && val<=0.192647) _g_bev_votes++;
      if(feat=="vpCompVAL" && val>=-0.672748 && val<=-0.128766) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.400000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.795000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.275820) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.815000) _g_bev_votes++;
      if(feat=="auctExpReward" && val>=0.664800 && val<=1.262300) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.686900) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.274000) _g_bev_votes++;
      if(feat=="msCompression" && val>=0.576400 && val<=0.815000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.431940 && val<=0.509860) _g_bev_votes++;
      if(feat=="smContext" && val>=0.514600) _g_bev_votes++;
      if(feat=="atrProxy" && val<=5373.940000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.610330) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="NAKED_POC")
   {
      if(feat=="vpInsideVA" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.114644) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val<=0.335000) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.346000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val<=-954.671200) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.287900) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.477800 && val<=0.539320) _g_bev_votes++;
      if(feat=="smContext" && val>=0.511200) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.238284 && val<=-0.110022) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.054000 && val<=0.392000) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.329862 && val<=0.167135) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.001000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val<=0.311000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.741500 && val<=0.827000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.514900) _g_bev_votes++;
      if(feat=="atrProxy" && val<=5616.300000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.584000) _g_bev_votes++;
   }
   if(symbol=="XAUGBPm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpBestHVNScore" && val>=0.800000) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=0.685000 && val<=0.825000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.944900) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.384000 && val<=0.448000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.306000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val<=0.083200) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.206000 && val<=0.258000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.338000 && val<=0.388000) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.573780) _g_bev_votes++;
      if(feat=="atrProxy" && val<=5204.380000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.630210) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=0.028089) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.110410) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val<=-0.185500) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.012342) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-1.731506) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDevPOCSlope" && val>=0.086660 && val<=0.246440) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.766000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=9.826700 && val<=4786.425260) _g_bev_votes++;
      if(feat=="smContext" && val>=0.413800) _g_bev_votes++;
      if(feat=="smContext" && val>=0.396000 && val<=0.406400) _g_bev_votes++;
      if(feat=="atrProxy" && val<=7496.120000) _g_bev_votes++;
      if(feat=="atrProxy" && val>=30822.380000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.021860) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST")
   {
      if(feat=="vpPOC" && val>=-0.043580 && val<=0.016534) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.006834) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.011051) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.012000) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val>=0.223200 && val<=0.529400) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.116680 && val<=0.257200) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=0.035257) _g_bev_votes++;
      if(feat=="vpCompPOC" && val>=0.269849) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.400000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.600000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.779800) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val<=0.500000) _g_bev_votes++;
      if(feat=="auctAcceptance" && val>=0.974000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.774000) _g_bev_votes++;
      if(feat=="auctFailure" && val>=0.400000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.640000 && val<=0.750000) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.385000 && val<=0.453000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.212400) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.305000) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.815000 && val<=0.913000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val>=0.850600 && val<=0.929000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val<=0.020000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.980000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=7.218660 && val<=4614.186600) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.474800 && val<=0.541480) _g_bev_votes++;
      if(feat=="smZoneQuality" && val<=0.845000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.414800) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=0.052410 && val<=0.127313) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.102713) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.132341 && val<=0.212975) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.026381 && val<=0.053765) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val<=0.013000) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.050000 && val<=0.374900) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.803830 && val<=-0.335590) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val<=-0.285392) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.002774 && val<=0.198598) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=-0.311009) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val>=0.450000 && val<=0.550000) _g_bev_votes++;
      if(feat=="vpProfileShape" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.798600) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.784000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.811000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.301000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.740400) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.265000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val>=2.700000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=-14.094700 && val<=3837.906310) _g_bev_votes++;
      if(feat=="msContext" && val>=0.362750 && val<=0.459725) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.335000 && val<=0.420000) _g_bev_votes++;
      if(feat=="ofContext" && val<=0.271000) _g_bev_votes++;
      if(feat=="ofContext" && val>=0.292167 && val<=0.331317) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=1.076000) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpPOC" && val>=-0.050455 && val<=0.044493) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.016053 && val<=0.116111) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-0.125485 && val<=-0.023096) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.287360 && val<=0.301620) _g_bev_votes++;
      if(feat=="vpCompVAH" && val<=0.054792) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val<=0.000000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.562200) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.062000 && val<=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val>=0.500000 && val<=0.938000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=6527.900000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.024500) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAL" && val>=-0.179582 && val<=-0.062267) _g_bev_votes++;
      if(feat=="vpDailyPOC" && val>=-0.392644 && val<=-0.085702) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=-0.296180 && val<=0.264488) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpDistCompPOC" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.623200) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val>=0.767000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.346000 && val<=0.420000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=16.211060 && val<=4760.535680) _g_bev_votes++;
      if(feat=="msContext" && val<=0.358300) _g_bev_votes++;
      if(feat=="atrProxy" && val<=7294.520000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.022100) _g_bev_votes++;
   }
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctTargetProb" && val<=0.308000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.378600) _g_bev_votes++;
      if(feat=="auctHVNStrength" && val>=0.953000) _g_bev_votes++;
      if(feat=="smContext" && val>=0.415000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=7334.680000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=0.022100) _g_bev_votes++;
   }
   if(symbol=="XPDUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctRegime" && val>=2.000000) _g_bev_votes++;
   }
   if(symbol=="XPDUSDm" && setup=="BREAKOUT")
   {
      if(feat=="vpVAL" && val>=-3.233530 && val<=-2.363957) _g_bev_votes++;
      if(feat=="vpCompVAL" && val<=-11.775455) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationScore" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.575000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.339000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.661000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=549.197400) _g_bev_votes++;
      if(feat=="msContext" && val>=0.654750) _g_bev_votes++;
      if(feat=="atrProxy" && val<=1255.100000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=1.420400) _g_bev_votes++;
   }
   if(symbol=="XPDUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpVAH" && val<=-2.099094) _g_bev_votes++;
      if(feat=="vpDistToHVN" && val>=0.040000 && val<=0.228600) _g_bev_votes++;
      if(feat=="vpDistToLVN" && val<=0.059000) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val<=0.574800) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.813000) _g_bev_votes++;
      if(feat=="auctContinuation" && val>=0.300000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.757600) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.338200) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.661800) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.200000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=570.742120) _g_bev_votes++;
      if(feat=="vpLTPOCMigration" && val>=2.000000) _g_bev_votes++;
      if(feat=="smZoneQuality" && val>=0.767000 && val<=0.854800) _g_bev_votes++;
      if(feat=="atrProxy" && val<=1272.600000) _g_bev_votes++;
   }
   if(symbol=="XPDUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="vpPOC" && val>=-2.157646 && val<=-1.259155) _g_bev_votes++;
      if(feat=="vpVAH" && val<=-2.138411) _g_bev_votes++;
      if(feat=="vpBestHVNScore" && val<=0.684500) _g_bev_votes++;
      if(feat=="auctRegimeConf" && val>=0.808500) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.337500) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.662500) _g_bev_votes++;
      if(feat=="msContext" && val>=0.653750) _g_bev_votes++;
      if(feat=="smContext" && val>=0.430200) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=1.162950) _g_bev_votes++;
   }
   if(symbol=="XPTUSDm" && setup=="ANCHORED_PULLBACK")
   {
      if(feat=="vpDistToHVN" && val>=0.249200 && val<=0.878000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=0.539250 && val<=1.330660) _g_bev_votes++;
      if(feat=="vpDevPOCDir" && val>=1.000000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.573600 && val<=0.697700) _g_bev_votes++;
      if(feat=="auctTargetProb" && val>=0.584000) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.255500 && val<=0.353000) _g_bev_votes++;
      if(feat=="auctLVNStrength" && val<=0.806000) _g_bev_votes++;
      if(feat=="vpLTTransitionScore" && val>=0.500000) _g_bev_votes++;
      if(feat=="vpLTBalanceStability" && val<=0.500000) _g_bev_votes++;
      if(feat=="ofFlowIntensity" && val>=0.364300 && val<=0.429700) _g_bev_votes++;
   }
   if(symbol=="XPTUSDm" && setup=="BREAKOUT")
   {
      if(feat=="vpPOC" && val>=-2.220699 && val<=-1.153775) _g_bev_votes++;
      if(feat=="vpVAL" && val>=-3.173223 && val<=-1.855752) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.100000) _g_bev_votes++;
      if(feat=="msContext" && val<=0.380250) _g_bev_votes++;
      if(feat=="atrProxy" && val<=784.200000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=1.097300) _g_bev_votes++;
   }
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION")
   {
      if(feat=="vpPOC" && val>=-0.079144 && val<=0.695351) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.505495 && val<=1.445206) _g_bev_votes++;
      if(feat=="vpInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.975070 && val<=-0.640230) _g_bev_votes++;
      if(feat=="vpCompVAH" && val>=0.910686 && val<=5.011899) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.425420 && val<=0.504200) _g_bev_votes++;
   }
   if(symbol=="XPTUSDm" && setup=="NAKED_POC")
   {
      if(feat=="vpCompVAL" && val>=-5.558294 && val<=-2.485635) _g_bev_votes++;
      if(feat=="vpCompInsideVA" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val>=0.362600 && val<=0.597400) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.182600) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.512600) _g_bev_votes++;
      if(feat=="auctExhaustion" && val>=0.177000 && val<=0.313200) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.100000) _g_bev_votes++;
   }
   if(symbol=="XPTUSDm" && setup=="PULLBACK")
   {
      if(feat=="vpCompVAL" && val>=-9.392779 && val<=-4.398208) _g_bev_votes++;
      if(feat=="vpVAOverlapRatio" && val<=0.097000) _g_bev_votes++;
      if(feat=="vpMigrationConf" && val>=1.000000) _g_bev_votes++;
      if(feat=="vpLTPOCVelocity" && val>=958.924970) _g_bev_votes++;
      if(feat=="liqContext" && val>=0.577060) _g_bev_votes++;
      if(feat=="atrProxy" && val<=804.590000) _g_bev_votes++;
   }
   if(symbol=="XPTUSDm" && setup=="SWEEP_REVERSAL")
   {
      if(feat=="vpPOC" && val>=0.120760 && val<=0.804147) _g_bev_votes++;
      if(feat=="vpVAH" && val<=0.263321) _g_bev_votes++;
      if(feat=="vpVAH" && val>=0.707392 && val<=1.538506) _g_bev_votes++;
      if(feat=="vpVAL" && val<=-1.111125) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-0.293120) _g_bev_votes++;
      if(feat=="vpPriceVsPOC" && val>=-1.061180 && val<=-0.807540) _g_bev_votes++;
      if(feat=="vpThinnessRatio" && val<=0.350000) _g_bev_votes++;
      if(feat=="auctBalance" && val>=0.782600) _g_bev_votes++;
      if(feat=="auctTradeQuality" && val>=0.504600) _g_bev_votes++;
      if(feat=="auctTradeGrade" && val>=2.000000) _g_bev_votes++;
      if(feat=="auctExpReward" && val<=0.399000) _g_bev_votes++;
      if(feat=="auctExpMoveATR" && val<=0.960000) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val>=0.261000) _g_bev_votes++;
   }
   if(symbol=="XPTUSDm" && setup=="TREND_CONTINUATION")
   {
      if(feat=="auctExpReward" && val<=0.288500) _g_bev_votes++;
      if(feat=="auctReversalRisk" && val<=0.000000) _g_bev_votes++;
      if(feat=="vpLTTrendDuration" && val<=0.100000) _g_bev_votes++;
      if(feat=="atrProxy" && val<=824.700000) _g_bev_votes++;
      if(feat=="spreadToATR" && val>=1.045200) _g_bev_votes++;
   }
   return false;
}

// 9. SHAP-guided tilts -- not available (run run_shap.py --exp <id>)
// double VPGetSHAPTilt(const string sym, const string stp,
//                     const string feat, double val) { return 1.0; }

#endif
