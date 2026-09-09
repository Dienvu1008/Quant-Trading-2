#ifndef __VP_EA_EDGEGUARD_CONFIG_MQH__
#define __VP_EA_EDGEGUARD_CONFIG_MQH__

// =============================================================
// VP EdgeGuard Config -- Generated 2026-08-30 09:18
// DO NOT EDIT MANUALLY -- regenerate with vp_99_generate_guards.py
// =============================================================

// 27 block rules
bool VPIsBlocked(const string symbol, const string setup, int regime)
{
   if(symbol=="AAPLm" && setup=="BREAKOUT" && regime==0) return true; // EV=-16.80 n=230
   if(symbol=="EBAYm" && setup=="NAKED_POC" && regime==0) return true; // EV=-19.59 n=58
   if(symbol=="ETHUSDm" && setup=="ANCHORED_PULLBACK" && regime==2) return true; // EV=-3.15 n=75
   if(symbol=="ETHUSDm" && setup=="BREAKOUT" && regime==0) return true; // EV=-1.17 n=863
   if(symbol=="EURAUDm" && setup=="BREAKOUT" && regime==0) return true; // EV=-24.02 n=1231
   if(symbol=="EURAUDm" && setup=="ANCHORED_PULLBACK" && regime==0) return true; // EV=-18.00 n=558
   if(symbol=="EURJPYm" && setup=="BREAKOUT" && regime==0) return true; // EV=-14.83 n=609
   if(symbol=="GBPCADm" && setup=="BREAKOUT" && regime==0) return true; // EV=-36.06 n=934
   if(symbol=="GBPJPYm" && setup=="BREAKOUT" && regime==0) return true; // EV=-17.80 n=890
   if(symbol=="GBPUSDm" && setup=="BREAKOUT" && regime==0) return true; // EV=-13.41 n=1125
   if(symbol=="NVDAm" && setup=="BREAKOUT" && regime==0) return true; // EV=-42.58 n=324
   if(symbol=="US500m" && setup=="TREND_CONTINUATION" && regime==0) return true; // EV=-0.76 n=627
   if(symbol=="USDCADm" && setup=="BREAKOUT" && regime==0) return true; // EV=-11.87 n=937
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK" && regime==0) return true; // EV=-453.18 n=229
   if(symbol=="XAGGBPm" && setup=="BREAKOUT" && regime==0) return true; // EV=-240.71 n=764
   if(symbol=="XAGJPYm" && setup=="ANCHORED_PULLBACK" && regime==0) return true; // EV=-386.05 n=163
   if(symbol=="_GLOBAL" && setup=="ANCHORED_PULLBACK" && regime==5) return true; // EV=-124.24 n=140
   return false;
}

// 521 feature gates (0 strict + 521 soft)
// Feature gates applied per (symbol, setup) — block if feature below threshold
double VPGetEdgeMultiplier(const string symbol, const string setup, const string feature, double value)
{
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="msContext" && (value<0.1362 || value>0.2769)) return 0.0; // [soft] band EV=139.089
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpDevPOCSlope" && value>0.0124) return 0.0; // [soft] EV=131.989
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="ix_spread_atr" && (value<0.0000 || value>0.0000)) return 0.0; // [soft] band EV=128.721
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && (value<0.1666 || value>0.3392)) return 0.0; // [soft] band EV=126.435
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="smZoneQuality" && value<0.9717) return 0.0; // [soft] EV=120.039
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="spreadToATR" && (value<0.0261 || value>0.0846)) return 0.0; // [soft] band EV=117.040
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="trendDirection" && value<0.0000) return 0.0; // [soft] EV=109.767
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctTradeQuality" && value<0.3771) return 0.0; // [soft] EV=109.233
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpDevPOCDir" && value<0.6425) return 0.0; // [soft] EV=109.103
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="ix_target_rr" && value<0.0019) return 0.0; // [soft] EV=104.345
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpLTTransitionScore" && (value<0.0240 || value>0.0502)) return 0.0; // [soft] band EV=99.632
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpLTBalanceStability" && (value<0.9498 || value>0.9760)) return 0.0; // [soft] band EV=99.632
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ix_tq_mig" && (value<0.2020 || value>0.4266)) return 0.0; // [soft] band EV=85.754
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="ix_tq_mig" && value<0.2201) return 0.0; // [soft] EV=76.951
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="vpLTPOCMigration" && (value<-1.6000 || value>0.0000)) return 0.0; // [soft] band EV=76.938
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="ix_target_rr" && (value<0.0011 || value>0.0046)) return 0.0; // [soft] band EV=75.122
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="ix_tq_mig" && (value<0.3070 || value>0.3734)) return 0.0; // [soft] band EV=74.472
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpLTNearestZoneStrength" && value<0.0000) return 0.0; // [soft] EV=73.042
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExpReward" && value<0.7163) return 0.0; // [soft] EV=69.980
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="smZoneQuality" && (value<0.8292 || value>1.0500)) return 0.0; // [soft] band EV=68.919
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="auctTradeQuality" && (value<0.3914 || value>0.4668)) return 0.0; // [soft] band EV=68.917
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="spreadToATR" && (value<0.0237 || value>0.0785)) return 0.0; // [soft] band EV=68.474
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ix_devpoc_ltpoc" && value<0.4472) return 0.0; // [soft] EV=67.616
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="auctFailure" && value>0.1500) return 0.0; // [soft] EV=64.699
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="vpLTAcceptanceAtPrice" && (value<0.0830 || value>0.4480)) return 0.0; // [soft] band EV=64.531
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION" && feature=="ix_exhaust_lt" && value>0.0000) return 0.0; // [soft] EV=62.027
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="smContext" && (value<0.3530 || value>0.3743)) return 0.0; // [soft] band EV=60.704
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<0.6038) return 0.0; // [soft] EV=60.138
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctFailure" && value>0.2000) return 0.0; // [soft] EV=59.118
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="auctHVNStrength" && (value<0.8455 || value>0.8982)) return 0.0; // [soft] band EV=57.725
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="spreadToATR" && value>0.0530) return 0.0; // [soft] EV=55.437
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="auctHVNStrength" && (value<0.7812 || value>0.9254)) return 0.0; // [soft] band EV=54.935
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="vpLTTransitionScore" && (value<0.0287 || value>0.2627)) return 0.0; // [soft] band EV=54.887
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="ix_fail_reversal" && (value<0.0000 || value>0.0380)) return 0.0; // [soft] band EV=54.406
   if(symbol=="XAUUSDm" && setup=="PULLBACK" && feature=="ix_tq_mig" && (value<0.2248 || value>0.3454)) return 0.0; // [soft] band EV=54.341
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && (value<0.6395 || value>0.9575)) return 0.0; // [soft] band EV=53.886
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpLTTransitionScore" && (value<0.0095 || value>0.1681)) return 0.0; // [soft] band EV=53.275
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpLTBalanceStability" && (value<0.8319 || value>0.9905)) return 0.0; // [soft] band EV=53.275
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="smContext" && value>0.3814) return 0.0; // [soft] EV=53.024
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="msCompression" && value>0.6684) return 0.0; // [soft] EV=52.814
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="vpLTAcceptanceAtPrice" && (value<0.1440 || value>0.4338)) return 0.0; // [soft] band EV=52.704
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK" && feature=="ofContext" && value<0.3166) return 0.0; // [soft] EV=52.183
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctHVNStrength" && value<0.7931) return 0.0; // [soft] EV=52.052
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="vpBestHVNScore" && value<0.7165) return 0.0; // [soft] EV=51.930
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="trendDirection" && value<1.0000) return 0.0; // [soft] EV=51.634
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST" && feature=="auctFailure" && value>0.1500) return 0.0; // [soft] EV=50.561
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION" && feature=="msContext" && value<0.1967) return 0.0; // [soft] EV=50.385
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL" && feature=="vpLTPOCMigration" && (value<-1.0000 || value>1.5000)) return 0.0; // [soft] band EV=50.353
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="vpDevPOCSlope" && value>0.0980) return 0.0; // [soft] EV=49.775
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL" && feature=="ix_fail_reversal" && value>0.0347) return 0.0; // [soft] EV=49.766
   return 1.0; // no gate matched
}

// 30 AVOID symbols
bool VPIsSymbolBlocked(const string symbol)
{
   if(symbol=="EURGBPm") return true;
   if(symbol=="GBPAUDm") return true;
   if(symbol=="EURCHFm") return true;
   if(symbol=="GBPCHFm") return true;
   if(symbol=="XAGUSDm") return true;
   if(symbol=="EURJPYm") return true;
   if(symbol=="GBPJPYm") return true;
   if(symbol=="XPDUSDm") return true;
   if(symbol=="XAGGBPm") return true;
   if(symbol=="XAGEURm") return true;
   if(symbol=="XAUEURm") return true;
   if(symbol=="XAUAUDm") return true;
   if(symbol=="XAUGBPm") return true;
   if(symbol=="EURAUDm") return true;
   if(symbol=="XPTUSDm") return true;
   if(symbol=="USDCADm") return true;
   if(symbol=="GBPCADm") return true;
   if(symbol=="GBPUSDm") return true;
   if(symbol=="STOXX50m") return true;
   if(symbol=="XAGJPYm") return true;
   if(symbol=="FR40m") return true;
   if(symbol=="MSFTm") return true;
   if(symbol=="NVDAm") return true;
   if(symbol=="AAPLm") return true;
   if(symbol=="METAm") return true;
   if(symbol=="NFLXm") return true;
   if(symbol=="EBAYm") return true;
   if(symbol=="JPMm") return true;
   if(symbol=="LMTm") return true;
   if(symbol=="GOOGLm") return true;
   return false;
}

bool VPIsTriggerEnabled(const string symbol, int setupType)
{
   if(symbol=="AUDUSDm" && setupType==0) return false;
   if(symbol=="AUDUSDm" && setupType==1) return false;
   if(symbol=="AUDUSDm" && setupType==2) return false;
   if(symbol=="AUDUSDm" && setupType==3) return false;
   if(symbol=="AUDUSDm" && setupType==4) return false;
   if(symbol=="AUDUSDm" && setupType==5) return false;
   if(symbol=="ETHUSDm" && setupType==0) return false;
   if(symbol=="ETHUSDm" && setupType==1) return false;
   if(symbol=="ETHUSDm" && setupType==2) return false;
   if(symbol=="ETHUSDm" && setupType==3) return false;
   if(symbol=="EURGBPm" && setupType==0) return false;
   if(symbol=="EURGBPm" && setupType==1) return false;
   if(symbol=="EURGBPm" && setupType==2) return false;
   if(symbol=="EURGBPm" && setupType==3) return false;
   if(symbol=="EURGBPm" && setupType==4) return false;
   if(symbol=="EURGBPm" && setupType==5) return false;
   if(symbol=="BTCUSDm" && setupType==0) return false;
   if(symbol=="BTCUSDm" && setupType==1) return false;
   if(symbol=="BTCUSDm" && setupType==2) return false;
   if(symbol=="BTCUSDm" && setupType==3) return false;
   if(symbol=="EURUSDm" && setupType==0) return false;
   if(symbol=="EURUSDm" && setupType==1) return false;
   if(symbol=="EURUSDm" && setupType==2) return false;
   if(symbol=="EURUSDm" && setupType==3) return false;
   if(symbol=="EURUSDm" && setupType==5) return false;
   if(symbol=="GBPAUDm" && setupType==0) return false;
   if(symbol=="GBPAUDm" && setupType==1) return false;
   if(symbol=="GBPAUDm" && setupType==2) return false;
   if(symbol=="GBPAUDm" && setupType==3) return false;
   if(symbol=="GBPAUDm" && setupType==4) return false;
   if(symbol=="GBPAUDm" && setupType==5) return false;
   if(symbol=="JP225m" && setupType==0) return false;
   if(symbol=="JP225m" && setupType==1) return false;
   if(symbol=="JP225m" && setupType==2) return false;
   if(symbol=="JP225m" && setupType==3) return false;
   if(symbol=="EURCHFm" && setupType==0) return false;
   if(symbol=="EURCHFm" && setupType==1) return false;
   if(symbol=="EURCHFm" && setupType==2) return false;
   if(symbol=="EURCHFm" && setupType==3) return false;
   if(symbol=="EURCHFm" && setupType==4) return false;
   if(symbol=="EURCHFm" && setupType==5) return false;
   if(symbol=="GBPCHFm" && setupType==0) return false;
   if(symbol=="GBPCHFm" && setupType==1) return false;
   if(symbol=="GBPCHFm" && setupType==2) return false;
   if(symbol=="GBPCHFm" && setupType==3) return false;
   if(symbol=="GBPCHFm" && setupType==4) return false;
   if(symbol=="GBPCHFm" && setupType==5) return false;
   if(symbol=="USDCHFm" && setupType==0) return false;
   if(symbol=="USDCHFm" && setupType==1) return false;
   if(symbol=="USDCHFm" && setupType==2) return false;
   if(symbol=="USDCHFm" && setupType==3) return false;
   if(symbol=="USDCHFm" && setupType==4) return false;
   if(symbol=="USDCHFm" && setupType==5) return false;
   if(symbol=="XAGUSDm" && setupType==0) return false;
   if(symbol=="XAGUSDm" && setupType==1) return false;
   if(symbol=="XAGUSDm" && setupType==2) return false;
   if(symbol=="XAGUSDm" && setupType==3) return false;
   if(symbol=="XAGUSDm" && setupType==4) return false;
   if(symbol=="XAGUSDm" && setupType==5) return false;
   if(symbol=="EURJPYm" && setupType==0) return false;
   if(symbol=="EURJPYm" && setupType==1) return false;
   if(symbol=="EURJPYm" && setupType==2) return false;
   if(symbol=="EURJPYm" && setupType==3) return false;
   if(symbol=="EURJPYm" && setupType==4) return false;
   if(symbol=="EURJPYm" && setupType==5) return false;
   if(symbol=="DE30m" && setupType==0) return false;
   if(symbol=="DE30m" && setupType==1) return false;
   if(symbol=="DE30m" && setupType==2) return false;
   if(symbol=="DE30m" && setupType==3) return false;
   if(symbol=="DE30m" && setupType==4) return false;
   if(symbol=="DE30m" && setupType==5) return false;
   if(symbol=="USDJPYm" && setupType==0) return false;
   if(symbol=="USDJPYm" && setupType==1) return false;
   if(symbol=="USDJPYm" && setupType==2) return false;
   if(symbol=="USDJPYm" && setupType==3) return false;
   if(symbol=="USDJPYm" && setupType==5) return false;
   if(symbol=="GBPJPYm" && setupType==0) return false;
   if(symbol=="GBPJPYm" && setupType==1) return false;
   if(symbol=="GBPJPYm" && setupType==2) return false;
   if(symbol=="GBPJPYm" && setupType==3) return false;
   if(symbol=="GBPJPYm" && setupType==4) return false;
   if(symbol=="GBPJPYm" && setupType==5) return false;
   if(symbol=="XPDUSDm" && setupType==0) return false;
   if(symbol=="XPDUSDm" && setupType==1) return false;
   if(symbol=="XPDUSDm" && setupType==2) return false;
   if(symbol=="XPDUSDm" && setupType==3) return false;
   if(symbol=="XPDUSDm" && setupType==4) return false;
   if(symbol=="XPDUSDm" && setupType==5) return false;
   if(symbol=="XAGGBPm" && setupType==0) return false;
   if(symbol=="XAGGBPm" && setupType==1) return false;
   if(symbol=="XAGGBPm" && setupType==2) return false;
   if(symbol=="XAGGBPm" && setupType==3) return false;
   if(symbol=="XAGGBPm" && setupType==4) return false;
   if(symbol=="XAGGBPm" && setupType==5) return false;
   if(symbol=="XAGEURm" && setupType==0) return false;
   if(symbol=="XAGEURm" && setupType==1) return false;
   if(symbol=="XAGEURm" && setupType==2) return false;
   if(symbol=="XAGEURm" && setupType==3) return false;
   if(symbol=="XAGEURm" && setupType==4) return false;
   if(symbol=="XAGEURm" && setupType==5) return false;
   if(symbol=="XAUEURm" && setupType==0) return false;
   if(symbol=="XAUEURm" && setupType==1) return false;
   if(symbol=="XAUEURm" && setupType==2) return false;
   if(symbol=="XAUEURm" && setupType==3) return false;
   if(symbol=="XAUEURm" && setupType==4) return false;
   if(symbol=="XAUEURm" && setupType==5) return false;
   if(symbol=="XAUAUDm" && setupType==0) return false;
   if(symbol=="XAUAUDm" && setupType==1) return false;
   if(symbol=="XAUAUDm" && setupType==2) return false;
   if(symbol=="XAUAUDm" && setupType==3) return false;
   if(symbol=="XAUAUDm" && setupType==4) return false;
   if(symbol=="XAUAUDm" && setupType==5) return false;
   if(symbol=="XAUGBPm" && setupType==0) return false;
   if(symbol=="XAUGBPm" && setupType==1) return false;
   if(symbol=="XAUGBPm" && setupType==2) return false;
   if(symbol=="XAUGBPm" && setupType==3) return false;
   if(symbol=="XAUGBPm" && setupType==4) return false;
   if(symbol=="XAUGBPm" && setupType==5) return false;
   if(symbol=="EURAUDm" && setupType==0) return false;
   if(symbol=="EURAUDm" && setupType==1) return false;
   if(symbol=="EURAUDm" && setupType==2) return false;
   if(symbol=="EURAUDm" && setupType==3) return false;
   if(symbol=="EURAUDm" && setupType==4) return false;
   if(symbol=="EURAUDm" && setupType==5) return false;
   if(symbol=="XPTUSDm" && setupType==0) return false;
   if(symbol=="XPTUSDm" && setupType==1) return false;
   if(symbol=="XPTUSDm" && setupType==2) return false;
   if(symbol=="XPTUSDm" && setupType==3) return false;
   if(symbol=="XPTUSDm" && setupType==4) return false;
   if(symbol=="XPTUSDm" && setupType==5) return false;
   if(symbol=="USDCADm" && setupType==0) return false;
   if(symbol=="USDCADm" && setupType==1) return false;
   if(symbol=="USDCADm" && setupType==2) return false;
   if(symbol=="USDCADm" && setupType==3) return false;
   if(symbol=="USDCADm" && setupType==4) return false;
   if(symbol=="USDCADm" && setupType==5) return false;
   if(symbol=="GBPCADm" && setupType==0) return false;
   if(symbol=="GBPCADm" && setupType==1) return false;
   if(symbol=="GBPCADm" && setupType==2) return false;
   if(symbol=="GBPCADm" && setupType==3) return false;
   if(symbol=="GBPCADm" && setupType==4) return false;
   if(symbol=="GBPCADm" && setupType==5) return false;
   if(symbol=="GBPUSDm" && setupType==0) return false;
   if(symbol=="GBPUSDm" && setupType==1) return false;
   if(symbol=="GBPUSDm" && setupType==2) return false;
   if(symbol=="GBPUSDm" && setupType==3) return false;
   if(symbol=="GBPUSDm" && setupType==4) return false;
   if(symbol=="GBPUSDm" && setupType==5) return false;
   if(symbol=="US30m" && setupType==2) return false;
   if(symbol=="STOXX50m" && setupType==0) return false;
   if(symbol=="STOXX50m" && setupType==1) return false;
   if(symbol=="STOXX50m" && setupType==2) return false;
   if(symbol=="STOXX50m" && setupType==3) return false;
   if(symbol=="STOXX50m" && setupType==4) return false;
   if(symbol=="STOXX50m" && setupType==5) return false;
   if(symbol=="USTECm" && setupType==2) return false;
   if(symbol=="US500m" && setupType==0) return false;
   if(symbol=="US500m" && setupType==1) return false;
   if(symbol=="US500m" && setupType==2) return false;
   if(symbol=="US500m" && setupType==3) return false;
   if(symbol=="XAGJPYm" && setupType==0) return false;
   if(symbol=="XAGJPYm" && setupType==1) return false;
   if(symbol=="XAGJPYm" && setupType==2) return false;
   if(symbol=="XAGJPYm" && setupType==3) return false;
   if(symbol=="XAGJPYm" && setupType==4) return false;
   if(symbol=="XAGJPYm" && setupType==5) return false;
   if(symbol=="USOILm" && setupType==1) return false;
   if(symbol=="USOILm" && setupType==2) return false;
   if(symbol=="USOILm" && setupType==3) return false;
   if(symbol=="FR40m" && setupType==0) return false;
   if(symbol=="FR40m" && setupType==1) return false;
   if(symbol=="FR40m" && setupType==2) return false;
   if(symbol=="FR40m" && setupType==3) return false;
   if(symbol=="FR40m" && setupType==4) return false;
   if(symbol=="FR40m" && setupType==5) return false;
   if(symbol=="USDKRWm" && setupType==0) return false;
   if(symbol=="USDKRWm" && setupType==1) return false;
   if(symbol=="USDKRWm" && setupType==2) return false;
   if(symbol=="USDKRWm" && setupType==3) return false;
   if(symbol=="MSFTm" && setupType==0) return false;
   if(symbol=="MSFTm" && setupType==1) return false;
   if(symbol=="MSFTm" && setupType==2) return false;
   if(symbol=="MSFTm" && setupType==3) return false;
   if(symbol=="MSFTm" && setupType==4) return false;
   if(symbol=="MSFTm" && setupType==5) return false;
   if(symbol=="NVDAm" && setupType==0) return false;
   if(symbol=="NVDAm" && setupType==1) return false;
   if(symbol=="NVDAm" && setupType==2) return false;
   if(symbol=="NVDAm" && setupType==3) return false;
   if(symbol=="NVDAm" && setupType==4) return false;
   if(symbol=="NVDAm" && setupType==5) return false;
   if(symbol=="AAPLm" && setupType==0) return false;
   if(symbol=="AAPLm" && setupType==1) return false;
   if(symbol=="AAPLm" && setupType==2) return false;
   if(symbol=="AAPLm" && setupType==3) return false;
   if(symbol=="AAPLm" && setupType==4) return false;
   if(symbol=="AAPLm" && setupType==5) return false;
   if(symbol=="METAm" && setupType==0) return false;
   if(symbol=="METAm" && setupType==1) return false;
   if(symbol=="METAm" && setupType==2) return false;
   if(symbol=="METAm" && setupType==3) return false;
   if(symbol=="METAm" && setupType==4) return false;
   if(symbol=="METAm" && setupType==5) return false;
   if(symbol=="NFLXm" && setupType==0) return false;
   if(symbol=="NFLXm" && setupType==1) return false;
   if(symbol=="NFLXm" && setupType==2) return false;
   if(symbol=="NFLXm" && setupType==3) return false;
   if(symbol=="NFLXm" && setupType==4) return false;
   if(symbol=="NFLXm" && setupType==5) return false;
   if(symbol=="EBAYm" && setupType==0) return false;
   if(symbol=="EBAYm" && setupType==1) return false;
   if(symbol=="EBAYm" && setupType==2) return false;
   if(symbol=="EBAYm" && setupType==3) return false;
   if(symbol=="EBAYm" && setupType==4) return false;
   if(symbol=="EBAYm" && setupType==5) return false;
   if(symbol=="JPMm" && setupType==0) return false;
   if(symbol=="JPMm" && setupType==1) return false;
   if(symbol=="JPMm" && setupType==2) return false;
   if(symbol=="JPMm" && setupType==3) return false;
   if(symbol=="JPMm" && setupType==4) return false;
   if(symbol=="JPMm" && setupType==5) return false;
   if(symbol=="LMTm" && setupType==0) return false;
   if(symbol=="LMTm" && setupType==1) return false;
   if(symbol=="LMTm" && setupType==2) return false;
   if(symbol=="LMTm" && setupType==3) return false;
   if(symbol=="LMTm" && setupType==4) return false;
   if(symbol=="LMTm" && setupType==5) return false;
   if(symbol=="GOOGLm" && setupType==0) return false;
   if(symbol=="GOOGLm" && setupType==1) return false;
   if(symbol=="GOOGLm" && setupType==2) return false;
   if(symbol=="GOOGLm" && setupType==3) return false;
   if(symbol=="GOOGLm" && setupType==4) return false;
   if(symbol=="GOOGLm" && setupType==5) return false;
   return true;
}

// 102 SL risk thresholds
// When feature crosses threshold, SL hit probability increases significantly
// Use to tighten SL or reduce lot size
double VPGetSLRiskMultiplier(const string symbol, const string setup, const string feature, double value)
{
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="auctBalance" && value>0.7351) return 0.5; // SL_rate=81% lift=+23%
   if(symbol=="USDCHFm" && setup=="NAKED_POC" && feature=="auctExpReward" && value<0.4681) return 0.5; // SL_rate=85% lift=+18%
   if(symbol=="AAPLm" && setup=="ANCHORED_PULLBACK" && feature=="bosScore" && value<0.6060) return 0.5; // SL_rate=98% lift=+17%
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="bosScore" && value<0.6620) return 0.5; // SL_rate=96% lift=+16%
   if(symbol=="XAUUSDm" && setup=="NAKED_POC" && feature=="trendDirection" && value<0.0000) return 0.5; // SL_rate=68% lift=+16%
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK" && feature=="auctFailure" && value>0.2500) return 0.5; // SL_rate=89% lift=+15%
   if(symbol=="XAUUSDm" && setup=="NAKED_POC" && feature=="auctExhaustion" && value<0.2386) return 0.5; // SL_rate=61% lift=+14%
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapBias" && value>0.0000) return 0.5; // SL_rate=86% lift=+14%
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="auctExhaustion" && value<0.1568) return 0.5; // SL_rate=82% lift=+14%
   if(symbol=="AAPLm" && setup=="ANCHORED_PULLBACK" && feature=="vpThinnessRatio" && value>0.5750) return 0.5; // SL_rate=94% lift=+13%
   if(symbol=="BTCUSDm" && setup=="PULLBACK" && feature=="trendDirection" && value<-0.1500) return 0.5; // SL_rate=77% lift=+13%
   if(symbol=="GBPAUDm" && setup=="BREAKOUT" && feature=="vpVAOverlapBias" && value>0.0000) return 0.5; // SL_rate=86% lift=+13%
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapBias" && value>0.0000) return 0.5; // SL_rate=97% lift=+12%
   if(symbol=="GOOGLm" && setup=="BREAKOUT" && feature=="structDistATR" && value<31.8777) return 0.5; // SL_rate=100% lift=+12%
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL" && feature=="auctBalance" && value<0.5759) return 0.5; // SL_rate=81% lift=+12%
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL" && feature=="auctExhaustion" && value<0.3230) return 0.5; // SL_rate=76% lift=+12%
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL" && feature=="auctExpReward" && value<1.1364) return 0.5; // SL_rate=45% lift=+12%
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK" && feature=="vpVAOverlapBias" && value>0.0000) return 0.5; // SL_rate=95% lift=+12%
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<0.2517) return 0.5; // SL_rate=95% lift=+12%
   if(symbol=="METAm" && setup=="MEAN_REVERSION" && feature=="chochScore" && value<0.4990) return 0.5; // SL_rate=93% lift=+11%
   if(symbol=="USOILm" && setup=="NAKED_POC" && feature=="chochScore" && value>0.7867) return 0.5; // SL_rate=78% lift=+11%
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL" && feature=="auctContinuation" && value>0.2470) return 0.5; // SL_rate=80% lift=+11%
   if(symbol=="AUDUSDm" && setup=="NAKED_POC" && feature=="chochScore" && value<0.4670) return 0.5; // SL_rate=75% lift=+11%
   if(symbol=="US30m" && setup=="MEAN_REVERSION" && feature=="vpVAOverlapBias" && value>0.0000) return 0.5; // SL_rate=61% lift=+11%
   if(symbol=="BTCUSDm" && setup=="TREND_CONTINUATION" && feature=="auctExhaustion" && value<0.1393) return 0.5; // SL_rate=83% lift=+11%
   if(symbol=="GBPCHFm" && setup=="NAKED_POC" && feature=="trendDirection" && value<0.0000) return 0.5; // SL_rate=74% lift=+11%
   if(symbol=="GOOGLm" && setup=="PULLBACK" && feature=="trendDirection" && value<-0.1875) return 0.5; // SL_rate=87% lift=+11%
   if(symbol=="EURGBPm" && setup=="NAKED_POC" && feature=="vpMigrationConf" && value<0.7083) return 0.5; // SL_rate=80% lift=+11%
   if(symbol=="EBAYm" && setup=="SWEEP_REVERSAL" && feature=="auctExpReward" && value<0.7713) return 0.5; // SL_rate=74% lift=+11%
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION" && feature=="bosQuality" && value>0.0000) return 0.5; // SL_rate=76% lift=+10%
   return 1.0;
}

// 299 lot multipliers (291 symbol-specific + 8 global)
// Returns multiplier in [0.50, 1.50] applied to maxLot
// 1.0 = neutral (no calibration data), <1.0 = scale down, >1.0 = scale up
double VPGetLotMultiplier(const string symbol, const string setup)
{
   if(symbol=="XAUUSDm" && setup=="SWEEP_REVERSAL") return 1.2137; // EV=$+180.42 WR=70% n=2529
   if(symbol=="USOILm" && setup=="SWEEP_REVERSAL") return 1.2105; // EV=$+77.92 WR=68% n=3087
   if(symbol=="BTCUSDm" && setup=="SWEEP_REVERSAL") return 1.2085; // EV=$+36.63 WR=68% n=629
   if(symbol=="US30m" && setup=="SWEEP_REVERSAL") return 1.1636; // EV=$+6.63 WR=63% n=2363
   if(symbol=="XAUUSDm" && setup=="MEAN_REVERSION") return 1.1546; // EV=$+114.76 WR=61% n=3136
   if(symbol=="JP225m" && setup=="SWEEP_REVERSAL") return 1.1528; // EV=$+0.35 WR=64% n=4119
   if(symbol=="USTECm" && setup=="SWEEP_REVERSAL") return 1.1480; // EV=$+4.80 WR=62% n=4034
   if(symbol=="ETHUSDm" && setup=="SWEEP_REVERSAL") return 1.1280; // EV=$+1.30 WR=60% n=4734
   if(symbol=="BTCUSDm" && setup=="MEAN_REVERSION") return 1.1185; // EV=$+16.83 WR=55% n=833
   if(symbol=="JP225m" && setup=="MEAN_REVERSION") return 1.1054; // EV=$+0.19 WR=58% n=5071
   if(symbol=="XAUUSDm" && setup=="BREAKOUT_RETEST") return 1.0866; // EV=$+47.91 WR=52% n=3471
   if(symbol=="XAUUSDm" && setup=="NAKED_POC") return 1.0695; // EV=$+56.37 WR=44% n=360
   if(symbol=="US30m" && setup=="MEAN_REVERSION") return 1.0675; // EV=$+2.42 WR=55% n=2601
   if(symbol=="USTECm" && setup=="BREAKOUT") return 1.0673; // EV=$+1.99 WR=45% n=5945
   if(symbol=="XAUUSDm" && setup=="ANCHORED_PULLBACK") return 1.0666; // EV=$+46.76 WR=50% n=2189
   if(symbol=="XAUUSDm" && setup=="TREND_CONTINUATION") return 1.0619; // EV=$+40.80 WR=49% n=3320
   if(symbol=="US30m" && setup=="BREAKOUT") return 1.0584; // EV=$+1.96 WR=45% n=2839
   if(symbol=="XAUUSDm" && setup=="BREAKOUT") return 1.0579; // EV=$+39.07 WR=48% n=3547
   if(symbol=="USTECm" && setup=="NAKED_POC") return 1.0547; // EV=$+1.36 WR=47% n=1608
   if(symbol=="DE30m" && setup=="MEAN_REVERSION") return 1.0531; // EV=$+1.50 WR=53% n=4953
   if(symbol=="US500m" && setup=="MEAN_REVERSION") return 1.0499; // EV=$+0.30 WR=47% n=3798
   if(symbol=="US500m" && setup=="SWEEP_REVERSAL") return 1.0481; // EV=$+0.28 WR=52% n=3573
   if(symbol=="US30m" && setup=="BREAKOUT_RETEST") return 1.0466; // EV=$+1.53 WR=44% n=2748
   if(symbol=="JP225m" && setup=="ANCHORED_PULLBACK") return 1.0456; // EV=$+0.12 WR=45% n=3313
   if(symbol=="XAUUSDm" && setup=="PULLBACK") return 1.0442; // EV=$+30.07 WR=48% n=3290
   if(symbol=="USDJPYm" && setup=="SWEEP_REVERSAL") return 1.0419; // EV=$+2.13 WR=54% n=4766
   if(symbol=="USTECm" && setup=="MEAN_REVERSION") return 1.0381; // EV=$+1.01 WR=50% n=4616
   if(symbol=="US30m" && setup=="ANCHORED_PULLBACK") return 1.0341; // EV=$+1.21 WR=47% n=1490
   if(symbol=="US30m" && setup=="NAKED_POC") return 1.0341; // EV=$+1.45 WR=46% n=2861
   if(symbol=="DE30m" && setup=="ANCHORED_PULLBACK") return 1.0240; // EV=$+1.01 WR=44% n=2855
   if(symbol=="XAGEURm" && setup=="PULLBACK") return 0.9748; // EV=$-43.17 WR=28% n=2446
   if(symbol=="XAGUSDm" && setup=="BREAKOUT") return 0.9712; // EV=$-34.98 WR=32% n=6029
   if(symbol=="XAGUSDm" && setup=="PULLBACK") return 0.9665; // EV=$-45.40 WR=36% n=5625
   if(symbol=="XAGEURm" && setup=="TREND_CONTINUATION") return 0.9647; // EV=$-68.28 WR=28% n=2665
   if(symbol=="XAGEURm" && setup=="BREAKOUT_RETEST") return 0.9621; // EV=$-60.55 WR=32% n=1573
   if(symbol=="XAGGBPm" && setup=="TREND_CONTINUATION") return 0.9530; // EV=$-76.73 WR=33% n=3199
   if(symbol=="DE30m" && setup=="TREND_CONTINUATION") return 0.9527; // EV=$-1.05 WR=39% n=5154
   if(symbol=="DE30m" && setup=="BREAKOUT_RETEST") return 0.9482; // EV=$-0.95 WR=41% n=5462
   if(symbol=="XAGUSDm" && setup=="BREAKOUT_RETEST") return 0.9475; // EV=$-64.70 WR=40% n=5001
   if(symbol=="EURAUDm" && setup=="NAKED_POC") return 0.9462; // EV=$-3.93 WR=25% n=725
   if(symbol=="USDJPYm" && setup=="BREAKOUT_RETEST") return 0.9440; // EV=$-2.05 WR=28% n=5970
   if(symbol=="US500m" && setup=="BREAKOUT") return 0.9434; // EV=$-0.24 WR=34% n=4921
   if(symbol=="EURUSDm" && setup=="SWEEP_REVERSAL") return 0.9410; // EV=$-2.33 WR=45% n=4701
   if(symbol=="DE30m" && setup=="BREAKOUT") return 0.9405; // EV=$-1.13 WR=39% n=5442
   if(symbol=="DE30m" && setup=="PULLBACK") return 0.9402; // EV=$-1.36 WR=37% n=4779
   if(symbol=="XAGGBPm" && setup=="BREAKOUT_RETEST") return 0.9399; // EV=$-100.75 WR=31% n=2124
   if(symbol=="XAGGBPm" && setup=="BREAKOUT") return 0.9345; // EV=$-131.28 WR=28% n=3278
   if(symbol=="XAUGBPm" && setup=="NAKED_POC") return 0.9310; // EV=$-86.40 WR=26% n=521
   if(symbol=="BTCUSDm" && setup=="BREAKOUT") return 0.9279; // EV=$-8.74 WR=34% n=764
   if(symbol=="XAGJPYm" && setup=="BREAKOUT_RETEST") return 0.9240; // EV=$-108.52 WR=29% n=1318
   if(symbol=="XAGEURm" && setup=="BREAKOUT") return 0.9211; // EV=$-137.20 WR=23% n=2681
   if(symbol=="US500m" && setup=="NAKED_POC") return 0.9203; // EV=$-0.40 WR=30% n=1702
   if(symbol=="US500m" && setup=="PULLBACK") return 0.9165; // EV=$-0.40 WR=33% n=4087
   if(symbol=="ETHUSDm" && setup=="ANCHORED_PULLBACK") return 0.9164; // EV=$-0.60 WR=32% n=3231
   if(symbol=="XAGGBPm" && setup=="ANCHORED_PULLBACK") return 0.9161; // EV=$-107.50 WR=37% n=1623
   if(symbol=="USDJPYm" && setup=="ANCHORED_PULLBACK") return 0.9120; // EV=$-3.50 WR=26% n=3588
   if(symbol=="USDJPYm" && setup=="MEAN_REVERSION") return 0.9112; // EV=$-3.05 WR=37% n=5704
   if(symbol=="XAGUSDm" && setup=="ANCHORED_PULLBACK") return 0.9085; // EV=$-90.55 WR=42% n=3051
   if(symbol=="GBPUSDm" && setup=="ANCHORED_PULLBACK") return 0.9075; // EV=$-4.44 WR=33% n=3377
   if(symbol=="ETHUSDm" && setup=="PULLBACK") return 0.9047; // EV=$-0.82 WR=29% n=5377
   if(symbol=="XAUEURm" && setup=="SWEEP_REVERSAL") return 0.9042; // EV=$-80.60 WR=50% n=2570
   if(symbol=="AAPLm" && setup=="NAKED_POC") return 0.9039; // EV=$-9.47 WR=12% n=481
   if(symbol=="JP225m" && setup=="PULLBACK") return 0.9032; // EV=$-0.13 WR=42% n=5085
   if(symbol=="GBPUSDm" && setup=="BREAKOUT_RETEST") return 0.9019; // EV=$-4.88 WR=32% n=5378
   if(symbol=="EURUSDm" && setup=="BREAKOUT_RETEST") return 0.9018; // EV=$-4.93 WR=29% n=5193
   if(symbol=="XAUAUDm" && setup=="SWEEP_REVERSAL") return 0.8997; // EV=$-69.16 WR=44% n=1787
   if(symbol=="AUDUSDm" && setup=="MEAN_REVERSION") return 0.8986; // EV=$-4.89 WR=41% n=5446
   if(symbol=="AAPLm" && setup=="PULLBACK") return 0.8956; // EV=$-8.81 WR=19% n=1201
   if(symbol=="GBPAUDm" && setup=="SWEEP_REVERSAL") return 0.8927; // EV=$-7.60 WR=43% n=3681
   if(symbol=="XAUEURm" && setup=="MEAN_REVERSION") return 0.8927; // EV=$-76.84 WR=41% n=3036
   if(symbol=="GBPUSDm" && setup=="SWEEP_REVERSAL") return 0.8859; // EV=$-5.43 WR=39% n=4703
   if(symbol=="GBPUSDm" && setup=="MEAN_REVERSION") return 0.8823; // EV=$-5.63 WR=37% n=6096
   if(symbol=="AUDUSDm" && setup=="ANCHORED_PULLBACK") return 0.8817; // EV=$-6.51 WR=25% n=3610
   if(symbol=="US500m" && setup=="TREND_CONTINUATION") return 0.8793; // EV=$-0.55 WR=35% n=4392
   if(symbol=="USDCHFm" && setup=="ANCHORED_PULLBACK") return 0.8773; // EV=$-14.69 WR=24% n=3162
   if(symbol=="EURUSDm" && setup=="TREND_CONTINUATION") return 0.8740; // EV=$-6.69 WR=34% n=5354
   if(symbol=="AUDUSDm" && setup=="SWEEP_REVERSAL") return 0.8739; // EV=$-5.75 WR=47% n=4231
   if(symbol=="USDJPYm" && setup=="NAKED_POC") return 0.8734; // EV=$-3.87 WR=34% n=1328
   if(symbol=="USDJPYm" && setup=="TREND_CONTINUATION") return 0.8716; // EV=$-4.28 WR=29% n=5903
   if(symbol=="USDCHFm" && setup=="SWEEP_REVERSAL") return 0.8709; // EV=$-12.85 WR=56% n=3919
   if(symbol=="AAPLm" && setup=="ANCHORED_PULLBACK") return 0.8679; // EV=$-7.35 WR=23% n=674
   if(symbol=="EURAUDm" && setup=="BREAKOUT") return 0.8652; // EV=$-10.22 WR=20% n=5299
   if(symbol=="AUDUSDm" && setup=="BREAKOUT") return 0.8649; // EV=$-8.61 WR=31% n=5961
   if(symbol=="USDJPYm" && setup=="PULLBACK") return 0.8647; // EV=$-6.09 WR=24% n=5584
   if(symbol=="ETHUSDm" && setup=="BREAKOUT_RETEST") return 0.8642; // EV=$-0.87 WR=27% n=6114
   if(symbol=="USDCHFm" && setup=="MEAN_REVERSION") return 0.8623; // EV=$-14.48 WR=48% n=5066
   if(symbol=="JPMm" && setup=="BREAKOUT") return 0.8607; // EV=$-24.46 WR=15% n=1135
   if(symbol=="EURUSDm" && setup=="MEAN_REVERSION") return 0.8594; // EV=$-5.50 WR=37% n=6034
   if(symbol=="EURUSDm" && setup=="NAKED_POC") return 0.8578; // EV=$-6.98 WR=26% n=1008
   if(symbol=="XAUEURm" && setup=="PULLBACK") return 0.8576; // EV=$-152.91 WR=25% n=3012
   if(symbol=="GBPAUDm" && setup=="PULLBACK") return 0.8565; // EV=$-15.68 WR=29% n=3667
   if(symbol=="XAGEURm" && setup=="ANCHORED_PULLBACK") return 0.8564; // EV=$-205.99 WR=30% n=1237
   if(symbol=="XAGJPYm" && setup=="NAKED_POC") return 0.8543; // EV=$-327.92 WR=24% n=735
   if(symbol=="ETHUSDm" && setup=="BREAKOUT") return 0.8535; // EV=$-0.95 WR=28% n=5795
   if(symbol=="GBPUSDm" && setup=="PULLBACK") return 0.8530; // EV=$-9.03 WR=25% n=5131
   if(symbol=="ETHUSDm" && setup=="NAKED_POC") return 0.8525; // EV=$-1.28 WR=26% n=1586
   if(symbol=="EURUSDm" && setup=="BREAKOUT") return 0.8494; // EV=$-8.21 WR=32% n=5939
   if(symbol=="GOOGLm" && setup=="MEAN_REVERSION") return 0.8494; // EV=$-13.89 WR=30% n=638
   if(symbol=="GBPJPYm" && setup=="SWEEP_REVERSAL") return 0.8493; // EV=$-9.11 WR=38% n=4597
   if(symbol=="XAUEURm" && setup=="ANCHORED_PULLBACK") return 0.8492; // EV=$-104.33 WR=31% n=1704
   if(symbol=="GBPAUDm" && setup=="ANCHORED_PULLBACK") return 0.8490; // EV=$-14.03 WR=23% n=2581
   if(symbol=="LMTm" && setup=="SWEEP_REVERSAL") return 0.8474; // EV=$-48.69 WR=24% n=349
   if(symbol=="GBPAUDm" && setup=="MEAN_REVERSION") return 0.8452; // EV=$-11.25 WR=33% n=4687
   if(symbol=="AUDUSDm" && setup=="BREAKOUT_RETEST") return 0.8449; // EV=$-7.27 WR=26% n=4551
   if(symbol=="XAUGBPm" && setup=="SWEEP_REVERSAL") return 0.8426; // EV=$-124.11 WR=42% n=2593
   if(symbol=="XAUAUDm" && setup=="BREAKOUT_RETEST") return 0.8415; // EV=$-108.86 WR=28% n=1543
   if(symbol=="USDJPYm" && setup=="BREAKOUT") return 0.8393; // EV=$-4.85 WR=27% n=5999
   if(symbol=="GOOGLm" && setup=="TREND_CONTINUATION") return 0.8368; // EV=$-20.30 WR=21% n=733
   if(symbol=="EURUSDm" && setup=="PULLBACK") return 0.8367; // EV=$-8.86 WR=31% n=5173
   if(symbol=="GBPCHFm" && setup=="MEAN_REVERSION") return 0.8366; // EV=$-16.31 WR=46% n=4644
   if(symbol=="GBPAUDm" && setup=="BREAKOUT") return 0.8363; // EV=$-19.05 WR=27% n=4065
   if(symbol=="USDCADm" && setup=="NAKED_POC") return 0.8351; // EV=$-6.99 WR=21% n=912
   if(symbol=="ETHUSDm" && setup=="TREND_CONTINUATION") return 0.8350; // EV=$-1.05 WR=31% n=5484
   if(symbol=="EURAUDm" && setup=="ANCHORED_PULLBACK") return 0.8340; // EV=$-10.18 WR=20% n=3537
   if(symbol=="EURAUDm" && setup=="PULLBACK") return 0.8331; // EV=$-12.12 WR=18% n=5112
   if(symbol=="XAUGBPm" && setup=="BREAKOUT_RETEST") return 0.8331; // EV=$-83.35 WR=32% n=1640
   if(symbol=="XAUEURm" && setup=="BREAKOUT_RETEST") return 0.8326; // EV=$-97.01 WR=33% n=1933
   if(symbol=="LMTm" && setup=="BREAKOUT") return 0.8314; // EV=$-49.88 WR=23% n=415
   if(symbol=="GBPCHFm" && setup=="ANCHORED_PULLBACK") return 0.8301; // EV=$-21.45 WR=21% n=2261
   if(symbol=="METAm" && setup=="SWEEP_REVERSAL") return 0.8284; // EV=$-38.32 WR=26% n=1163
   if(symbol=="EURUSDm" && setup=="ANCHORED_PULLBACK") return 0.8271; // EV=$-6.71 WR=30% n=3611
   if(symbol=="AUDUSDm" && setup=="PULLBACK") return 0.8245; // EV=$-9.94 WR=31% n=5058
   if(symbol=="GBPUSDm" && setup=="BREAKOUT") return 0.8228; // EV=$-9.47 WR=27% n=5469
   if(symbol=="EURJPYm" && setup=="ANCHORED_PULLBACK") return 0.8208; // EV=$-7.28 WR=22% n=2998
   if(symbol=="XAUGBPm" && setup=="ANCHORED_PULLBACK") return 0.8172; // EV=$-118.46 WR=35% n=1553
   if(symbol=="GBPCHFm" && setup=="PULLBACK") return 0.8164; // EV=$-19.39 WR=40% n=4332
   if(symbol=="JPMm" && setup=="MEAN_REVERSION") return 0.8164; // EV=$-21.20 WR=20% n=944
   if(symbol=="JPMm" && setup=="NAKED_POC") return 0.8148; // EV=$-31.75 WR=9% n=528
   if(symbol=="EURAUDm" && setup=="SWEEP_REVERSAL") return 0.8139; // EV=$-9.07 WR=30% n=4959
   if(symbol=="AUDUSDm" && setup=="NAKED_POC") return 0.8133; // EV=$-11.04 WR=33% n=717
   if(symbol=="NVDAm" && setup=="BREAKOUT_RETEST") return 0.8128; // EV=$-18.85 WR=13% n=960
   if(symbol=="USDCHFm" && setup=="BREAKOUT_RETEST") return 0.8121; // EV=$-19.99 WR=26% n=3963
   if(symbol=="XAUEURm" && setup=="NAKED_POC") return 0.8113; // EV=$-159.45 WR=28% n=537
   if(symbol=="AUDUSDm" && setup=="TREND_CONTINUATION") return 0.8103; // EV=$-10.24 WR=35% n=5297
   if(symbol=="STOXX50m" && setup=="BREAKOUT_RETEST") return 0.8097; // EV=$-1.92 WR=18% n=1616
   if(symbol=="STOXX50m" && setup=="BREAKOUT") return 0.8096; // EV=$-2.67 WR=21% n=2188
   if(symbol=="MSFTm" && setup=="PULLBACK") return 0.8070; // EV=$-39.97 WR=17% n=1028
   if(symbol=="GBPCHFm" && setup=="BREAKOUT_RETEST") return 0.8065; // EV=$-18.06 WR=24% n=3490
   if(symbol=="EURAUDm" && setup=="MEAN_REVERSION") return 0.8023; // EV=$-8.42 WR=27% n=6739
   if(symbol=="EURGBPm" && setup=="SWEEP_REVERSAL") return 0.7955; // EV=$-10.99 WR=26% n=4444
   if(symbol=="GBPCHFm" && setup=="SWEEP_REVERSAL") return 0.7944; // EV=$-20.30 WR=52% n=3283
   if(symbol=="GBPJPYm" && setup=="MEAN_REVERSION") return 0.7940; // EV=$-10.00 WR=31% n=5733
   if(symbol=="XAUAUDm" && setup=="MEAN_REVERSION") return 0.7938; // EV=$-125.81 WR=34% n=2208
   if(symbol=="EURCHFm" && setup=="MEAN_REVERSION") return 0.7925; // EV=$-18.91 WR=36% n=4285
   if(symbol=="XAUEURm" && setup=="BREAKOUT") return 0.7922; // EV=$-175.05 WR=23% n=3341
   if(symbol=="GBPAUDm" && setup=="TREND_CONTINUATION") return 0.7910; // EV=$-22.19 WR=28% n=3949
   if(symbol=="GBPJPYm" && setup=="NAKED_POC") return 0.7876; // EV=$-15.38 WR=25% n=1009
   if(symbol=="EURJPYm" && setup=="SWEEP_REVERSAL") return 0.7868; // EV=$-7.91 WR=36% n=3742
   if(symbol=="FR40m" && setup=="BREAKOUT_RETEST") return 0.7863; // EV=$-1.85 WR=31% n=2336
   if(symbol=="GOOGLm" && setup=="ANCHORED_PULLBACK") return 0.7862; // EV=$-21.71 WR=26% n=458
   if(symbol=="GBPUSDm" && setup=="TREND_CONTINUATION") return 0.7861; // EV=$-10.07 WR=29% n=5247
   if(symbol=="EURGBPm" && setup=="ANCHORED_PULLBACK") return 0.7840; // EV=$-14.91 WR=13% n=2673
   if(symbol=="GBPJPYm" && setup=="BREAKOUT_RETEST") return 0.7835; // EV=$-10.41 WR=22% n=5509
   if(symbol=="XAUGBPm" && setup=="BREAKOUT") return 0.7834; // EV=$-212.79 WR=21% n=3255
   if(symbol=="AAPLm" && setup=="SWEEP_REVERSAL") return 0.7826; // EV=$-12.14 WR=26% n=1278
   if(symbol=="EURCHFm" && setup=="ANCHORED_PULLBACK") return 0.7811; // EV=$-22.52 WR=16% n=1695
   if(symbol=="EBAYm" && setup=="PULLBACK") return 0.7808; // EV=$-8.57 WR=22% n=393
   if(symbol=="EURCHFm" && setup=="SWEEP_REVERSAL") return 0.7791; // EV=$-20.46 WR=45% n=3169
   if(symbol=="MSFTm" && setup=="NAKED_POC") return 0.7789; // EV=$-57.24 WR=10% n=879
   if(symbol=="LMTm" && setup=="MEAN_REVERSION") return 0.7785; // EV=$-69.20 WR=15% n=399
   if(symbol=="GBPCHFm" && setup=="TREND_CONTINUATION") return 0.7760; // EV=$-21.75 WR=49% n=4571
   if(symbol=="MSFTm" && setup=="BREAKOUT") return 0.7758; // EV=$-44.66 WR=14% n=1186
   if(symbol=="EURAUDm" && setup=="TREND_CONTINUATION") return 0.7746; // EV=$-12.00 WR=23% n=5337
   if(symbol=="USDCADm" && setup=="MEAN_REVERSION") return 0.7715; // EV=$-6.78 WR=25% n=5942
   if(symbol=="XAUGBPm" && setup=="MEAN_REVERSION") return 0.7696; // EV=$-125.02 WR=35% n=3029
   if(symbol=="GBPAUDm" && setup=="NAKED_POC") return 0.7691; // EV=$-20.22 WR=26% n=390
   if(symbol=="GBPCHFm" && setup=="BREAKOUT") return 0.7659; // EV=$-25.50 WR=37% n=6030
   if(symbol=="USDCHFm" && setup=="BREAKOUT") return 0.7596; // EV=$-26.68 WR=42% n=6191
   if(symbol=="GOOGLm" && setup=="BREAKOUT") return 0.7588; // EV=$-23.52 WR=19% n=777
   if(symbol=="XAUEURm" && setup=="TREND_CONTINUATION") return 0.7571; // EV=$-198.80 WR=23% n=3403
   if(symbol=="EURCHFm" && setup=="BREAKOUT_RETEST") return 0.7566; // EV=$-18.23 WR=18% n=2186
   if(symbol=="AAPLm" && setup=="BREAKOUT_RETEST") return 0.7528; // EV=$-12.59 WR=17% n=1285
   if(symbol=="STOXX50m" && setup=="MEAN_REVERSION") return 0.7524; // EV=$-2.82 WR=24% n=1957
   if(symbol=="XAUAUDm" && setup=="BREAKOUT") return 0.7524; // EV=$-182.71 WR=20% n=2384
   if(symbol=="LMTm" && setup=="NAKED_POC") return 0.7521; // EV=$-73.29 WR=22% n=210
   if(symbol=="EURJPYm" && setup=="MEAN_REVERSION") return 0.7520; // EV=$-9.65 WR=27% n=4701
   if(symbol=="MSFTm" && setup=="ANCHORED_PULLBACK") return 0.7515; // EV=$-33.94 WR=27% n=695
   if(symbol=="FR40m" && setup=="ANCHORED_PULLBACK") return 0.7506; // EV=$-3.11 WR=26% n=1559
   if(symbol=="STOXX50m" && setup=="ANCHORED_PULLBACK") return 0.7500; // EV=$-2.28 WR=21% n=996
   if(symbol=="METAm" && setup=="PULLBACK") return 0.7451; // EV=$-62.68 WR=14% n=948
   if(symbol=="GBPAUDm" && setup=="BREAKOUT_RETEST") return 0.7411; // EV=$-15.80 WR=22% n=3739
   if(symbol=="XAUAUDm" && setup=="ANCHORED_PULLBACK") return 0.7402; // EV=$-159.15 WR=24% n=1254
   if(symbol=="METAm" && setup=="BREAKOUT") return 0.7364; // EV=$-69.11 WR=11% n=1158
   if(symbol=="MSFTm" && setup=="TREND_CONTINUATION") return 0.7354; // EV=$-44.12 WR=17% n=1202
   if(symbol=="JPMm" && setup=="ANCHORED_PULLBACK") return 0.7353; // EV=$-21.61 WR=18% n=644
   if(symbol=="EURCHFm" && setup=="NAKED_POC") return 0.7344; // EV=$-18.54 WR=33% n=1212
   if(symbol=="GBPCADm" && setup=="MEAN_REVERSION") return 0.7315; // EV=$-13.89 WR=24% n=5721
   if(symbol=="USDCADm" && setup=="SWEEP_REVERSAL") return 0.7301; // EV=$-7.75 WR=31% n=4503
   if(symbol=="METAm" && setup=="BREAKOUT_RETEST") return 0.7258; // EV=$-61.40 WR=10% n=1041
   if(symbol=="METAm" && setup=="TREND_CONTINUATION") return 0.7252; // EV=$-64.23 WR=13% n=1092
   if(symbol=="EURJPYm" && setup=="TREND_CONTINUATION") return 0.7169; // EV=$-12.46 WR=17% n=5188
   if(symbol=="USDCHFm" && setup=="TREND_CONTINUATION") return 0.7154; // EV=$-31.02 WR=45% n=4703
   if(symbol=="USDCADm" && setup=="ANCHORED_PULLBACK") return 0.7149; // EV=$-7.66 WR=19% n=3202
   if(symbol=="XAUGBPm" && setup=="PULLBACK") return 0.7139; // EV=$-235.89 WR=21% n=2882
   if(symbol=="EURAUDm" && setup=="BREAKOUT_RETEST") return 0.7116; // EV=$-12.00 WR=19% n=5426
   if(symbol=="EURJPYm" && setup=="BREAKOUT") return 0.7104; // EV=$-11.06 WR=13% n=5253
   if(symbol=="GOOGLm" && setup=="BREAKOUT_RETEST") return 0.7076; // EV=$-22.14 WR=17% n=691
   if(symbol=="GBPCADm" && setup=="TREND_CONTINUATION") return 0.7055; // EV=$-19.66 WR=18% n=6088
   if(symbol=="GBPCADm" && setup=="BREAKOUT_RETEST") return 0.7051; // EV=$-14.80 WR=18% n=4777
   if(symbol=="EURGBPm" && setup=="BREAKOUT") return 0.7048; // EV=$-18.25 WR=16% n=6502
   if(symbol=="EURGBPm" && setup=="MEAN_REVERSION") return 0.7043; // EV=$-14.73 WR=16% n=5876
   if(symbol=="GBPUSDm" && setup=="NAKED_POC") return 0.7039; // EV=$-18.54 WR=28% n=689
   if(symbol=="AAPLm" && setup=="TREND_CONTINUATION") return 0.7018; // EV=$-14.97 WR=17% n=1292
   if(symbol=="GBPCADm" && setup=="BREAKOUT") return 0.6962; // EV=$-19.08 WR=16% n=5966
   if(symbol=="XAUGBPm" && setup=="TREND_CONTINUATION") return 0.6962; // EV=$-233.77 WR=22% n=3499
   if(symbol=="EURJPYm" && setup=="BREAKOUT_RETEST") return 0.6961; // EV=$-8.92 WR=20% n=5051
   if(symbol=="EURCHFm" && setup=="BREAKOUT") return 0.6959; // EV=$-24.14 WR=38% n=5382
   if(symbol=="XAUAUDm" && setup=="TREND_CONTINUATION") return 0.6955; // EV=$-193.73 WR=22% n=2383
   if(symbol=="EURCHFm" && setup=="PULLBACK") return 0.6933; // EV=$-25.21 WR=37% n=3961
   if(symbol=="USDCADm" && setup=="TREND_CONTINUATION") return 0.6878; // EV=$-9.15 WR=18% n=5413
   if(symbol=="USDCADm" && setup=="PULLBACK") return 0.6858; // EV=$-10.15 WR=16% n=5417
   if(symbol=="AAPLm" && setup=="BREAKOUT") return 0.6849; // EV=$-14.65 WR=15% n=1390
   if(symbol=="EBAYm" && setup=="BREAKOUT_RETEST") return 0.6840; // EV=$-9.69 WR=18% n=353
   if(symbol=="USDCHFm" && setup=="PULLBACK") return 0.6833; // EV=$-34.53 WR=38% n=4553
   if(symbol=="GBPJPYm" && setup=="PULLBACK") return 0.6802; // EV=$-17.95 WR=19% n=5735
   if(symbol=="GBPJPYm" && setup=="ANCHORED_PULLBACK") return 0.6791; // EV=$-11.63 WR=23% n=3649
   if(symbol=="GBPJPYm" && setup=="TREND_CONTINUATION") return 0.6768; // EV=$-18.21 WR=19% n=5818
   if(symbol=="GBPCADm" && setup=="ANCHORED_PULLBACK") return 0.6682; // EV=$-16.88 WR=17% n=2752
   if(symbol=="XAUAUDm" && setup=="PULLBACK") return 0.6669; // EV=$-217.26 WR=20% n=2250
   if(symbol=="LMTm" && setup=="TREND_CONTINUATION") return 0.6646; // EV=$-67.42 WR=19% n=429
   if(symbol=="STOXX50m" && setup=="TREND_CONTINUATION") return 0.6616; // EV=$-3.43 WR=17% n=2171
   if(symbol=="XAUAUDm" && setup=="NAKED_POC") return 0.6612; // EV=$-188.23 WR=23% n=308
   if(symbol=="MSFTm" && setup=="BREAKOUT_RETEST") return 0.6487; // EV=$-33.37 WR=15% n=864
   if(symbol=="JPMm" && setup=="TREND_CONTINUATION") return 0.6467; // EV=$-32.72 WR=15% n=1042
   if(symbol=="USDCADm" && setup=="BREAKOUT_RETEST") return 0.6448; // EV=$-9.00 WR=18% n=5617
   if(symbol=="AAPLm" && setup=="MEAN_REVERSION") return 0.6376; // EV=$-14.22 WR=21% n=1432
   if(symbol=="EURGBPm" && setup=="PULLBACK") return 0.6346; // EV=$-18.60 WR=15% n=5493
   if(symbol=="GOOGLm" && setup=="PULLBACK") return 0.6333; // EV=$-28.14 WR=25% n=675
   if(symbol=="EURGBPm" && setup=="BREAKOUT_RETEST") return 0.6326; // EV=$-16.54 WR=9% n=4554
   if(symbol=="METAm" && setup=="MEAN_REVERSION") return 0.6280; // EV=$-58.33 WR=17% n=1292
   if(symbol=="GBPCHFm" && setup=="NAKED_POC") return 0.6260; // EV=$-34.07 WR=17% n=944
   if(symbol=="GBPCADm" && setup=="PULLBACK") return 0.6228; // EV=$-20.20 WR=16% n=5640
   if(symbol=="FR40m" && setup=="TREND_CONTINUATION") return 0.6171; // EV=$-4.99 WR=31% n=3077
   if(symbol=="EURJPYm" && setup=="PULLBACK") return 0.6142; // EV=$-12.39 WR=19% n=5051
   if(symbol=="STOXX50m" && setup=="SWEEP_REVERSAL") return 0.6129; // EV=$-2.99 WR=30% n=1767
   if(symbol=="EURCHFm" && setup=="TREND_CONTINUATION") return 0.6041; // EV=$-28.48 WR=44% n=4277
   if(symbol=="GBPCADm" && setup=="SWEEP_REVERSAL") return 0.5982; // EV=$-19.24 WR=27% n=4458
   if(symbol=="JPMm" && setup=="SWEEP_REVERSAL") return 0.5936; // EV=$-33.47 WR=16% n=839
   if(symbol=="XPDUSDm" && setup=="PULLBACK") return 0.5887; // EV=$-1064.45 WR=19% n=131
   if(symbol=="XPDUSDm" && setup=="SWEEP_REVERSAL") return 0.5878; // EV=$-823.40 WR=16% n=80
   if(symbol=="NVDAm" && setup=="MEAN_REVERSION") return 0.5857; // EV=$-29.46 WR=22% n=1241
   if(symbol=="STOXX50m" && setup=="PULLBACK") return 0.5818; // EV=$-3.23 WR=19% n=1967
   if(symbol=="GBPJPYm" && setup=="BREAKOUT") return 0.5788; // EV=$-17.13 WR=18% n=5825
   if(symbol=="EURGBPm" && setup=="NAKED_POC") return 0.5764; // EV=$-26.30 WR=20% n=902
   if(symbol=="NVDAm" && setup=="SWEEP_REVERSAL") return 0.5747; // EV=$-29.70 WR=31% n=1244
   if(symbol=="LMTm" && setup=="PULLBACK") return 0.5735; // EV=$-55.70 WR=21% n=380
   if(symbol=="XPTUSDm" && setup=="ANCHORED_PULLBACK") return 0.5558; // EV=$-573.30 WR=5% n=712
   if(symbol=="JPMm" && setup=="BREAKOUT_RETEST") return 0.5467; // EV=$-26.29 WR=10% n=897
   if(symbol=="MSFTm" && setup=="MEAN_REVERSION") return 0.5422; // EV=$-42.90 WR=20% n=1372
   if(symbol=="LMTm" && setup=="ANCHORED_PULLBACK") return 0.5409; // EV=$-56.03 WR=17% n=228
   if(symbol=="JPMm" && setup=="PULLBACK") return 0.5356; // EV=$-39.53 WR=13% n=987
   if(symbol=="XPTUSDm" && setup=="PULLBACK") return 0.5351; // EV=$-598.46 WR=7% n=1659
   if(symbol=="NVDAm" && setup=="TREND_CONTINUATION") return 0.5331; // EV=$-41.79 WR=13% n=1358
   if(symbol=="EURGBPm" && setup=="TREND_CONTINUATION") return 0.5322; // EV=$-20.30 WR=18% n=6033
   if(symbol=="USDCADm" && setup=="BREAKOUT") return 0.5212; // EV=$-11.38 WR=16% n=5870
   if(symbol=="FR40m" && setup=="SWEEP_REVERSAL") return 0.5164; // EV=$-5.42 WR=32% n=2889
   if(symbol=="LMTm" && setup=="BREAKOUT_RETEST") return 0.5164; // EV=$-62.75 WR=6% n=297
   if(symbol=="FR40m" && setup=="BREAKOUT") return 0.5051; // EV=$-5.17 WR=24% n=3057
   if(symbol=="EBAYm" && setup=="ANCHORED_PULLBACK") return 0.5000; // EV=$-8.94 WR=23% n=256
   if(symbol=="EBAYm" && setup=="NAKED_POC") return 0.5000; // EV=$-20.19 WR=16% n=277
   if(symbol=="EURJPYm" && setup=="NAKED_POC") return 0.5000; // EV=$-17.50 WR=19% n=652
   if(symbol=="FR40m" && setup=="MEAN_REVERSION") return 0.5000; // EV=$-5.48 WR=28% n=2818
   if(symbol=="FR40m" && setup=="NAKED_POC") return 0.5000; // EV=$-10.16 WR=16% n=1155
   if(symbol=="FR40m" && setup=="PULLBACK") return 0.5000; // EV=$-5.10 WR=28% n=2628
   if(symbol=="GBPCADm" && setup=="NAKED_POC") return 0.5000; // EV=$-35.82 WR=7% n=756
   if(symbol=="METAm" && setup=="ANCHORED_PULLBACK") return 0.5000; // EV=$-76.60 WR=15% n=614
   if(symbol=="METAm" && setup=="NAKED_POC") return 0.5000; // EV=$-88.52 WR=8% n=681
   if(symbol=="MSFTm" && setup=="SWEEP_REVERSAL") return 0.5000; // EV=$-51.69 WR=23% n=1268
   if(symbol=="NFLXm" && setup=="ANCHORED_PULLBACK") return 0.5000; // EV=$-35.42 WR=11% n=481
   if(symbol=="NFLXm" && setup=="BREAKOUT") return 0.5000; // EV=$-38.13 WR=5% n=1173
   if(symbol=="NFLXm" && setup=="BREAKOUT_RETEST") return 0.5000; // EV=$-19.75 WR=7% n=657
   if(symbol=="NFLXm" && setup=="MEAN_REVERSION") return 0.5000; // EV=$-32.49 WR=6% n=1091
   if(symbol=="NFLXm" && setup=="NAKED_POC") return 0.5000; // EV=$-46.58 WR=6% n=555
   if(symbol=="NFLXm" && setup=="PULLBACK") return 0.5000; // EV=$-38.07 WR=4% n=919
   if(symbol=="NFLXm" && setup=="SWEEP_REVERSAL") return 0.5000; // EV=$-38.63 WR=5% n=910
   if(symbol=="NFLXm" && setup=="TREND_CONTINUATION") return 0.5000; // EV=$-39.12 WR=2% n=1097
   if(symbol=="NVDAm" && setup=="ANCHORED_PULLBACK") return 0.5000; // EV=$-32.28 WR=22% n=630
   if(symbol=="NVDAm" && setup=="BREAKOUT") return 0.5000; // EV=$-41.93 WR=14% n=1481
   if(symbol=="NVDAm" && setup=="NAKED_POC") return 0.5000; // EV=$-42.80 WR=13% n=645
   if(symbol=="NVDAm" && setup=="PULLBACK") return 0.5000; // EV=$-30.59 WR=15% n=1099
   if(symbol=="STOXX50m" && setup=="NAKED_POC") return 0.5000; // EV=$-3.98 WR=22% n=762
   if(symbol=="USDCHFm" && setup=="NAKED_POC") return 0.5000; // EV=$-28.91 WR=23% n=910
   if(symbol=="XPDUSDm" && setup=="BREAKOUT") return 0.5000; // EV=$-1270.64 WR=13% n=182
   if(symbol=="XPDUSDm" && setup=="MEAN_REVERSION") return 0.5000; // EV=$-886.63 WR=8% n=60
   if(symbol=="XPDUSDm" && setup=="TREND_CONTINUATION") return 0.5000; // EV=$-1098.29 WR=14% n=170
   if(symbol=="XPTUSDm" && setup=="BREAKOUT") return 0.5000; // EV=$-662.97 WR=2% n=2072
   if(symbol=="XPTUSDm" && setup=="BREAKOUT_RETEST") return 0.5000; // EV=$-529.92 WR=2% n=413
   if(symbol=="XPTUSDm" && setup=="MEAN_REVERSION") return 0.5000; // EV=$-535.27 WR=7% n=1548
   if(symbol=="XPTUSDm" && setup=="NAKED_POC") return 0.5000; // EV=$-751.80 WR=2% n=523
   if(symbol=="XPTUSDm" && setup=="SWEEP_REVERSAL") return 0.5000; // EV=$-578.65 WR=11% n=1771
   if(symbol=="XPTUSDm" && setup=="TREND_CONTINUATION") return 0.5000; // EV=$-779.83 WR=4% n=2458
   if(setup=="MEAN_REVERSION") return 0.9429; // [global] EV=$-18.06 WR=36% n=147974
   if(setup=="SWEEP_REVERSAL") return 0.9373; // [global] EV=$-18.52 WR=44% n=120661
   if(setup=="BREAKOUT_RETEST") return 0.8898; // [global] EV=$-26.97 WR=27% n=128840
   if(setup=="ANCHORED_PULLBACK") return 0.8730; // [global] EV=$-33.20 WR=28% n=82722
   if(setup=="TREND_CONTINUATION") return 0.8647; // [global] EV=$-42.14 WR=30% n=148965
   if(setup=="PULLBACK") return 0.8548; // [global] EV=$-42.40 WR=27% n=139265
   if(setup=="BREAKOUT") return 0.8524; // [global] EV=$-41.68 WR=28% n=157925
   if(setup=="NAKED_POC") return 0.8082; // [global] EV=$-42.14 WR=30% n=42024
   return 1.0; // no calibration data
}

#endif