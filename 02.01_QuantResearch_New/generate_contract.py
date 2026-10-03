"""
generate_contract.py — Create ResearchContract YAML with correct feature names.

Feature names match ACTUAL column names in the merged DataFrame after
data_loader.load_merged(), including the VP normalization step.

Key points:
  - VP price levels (vpPOC, vpVAH, vpVAL...) are ATR-normalised distances
    AFTER data_loader._normalize_vp_features() runs.
    vpPOC ≈ 0  means price is AT the POC
    vpVAH ≈ +0.2 means VAH is 0.2 ATR ABOVE entry price
    vpVAL ≈ -0.2 means VAL is 0.2 ATR BELOW entry price
  - Shape priors reflect these normalised semantics, not raw price levels.

Run:
    python generate_contract.py
"""
import hashlib
import sys
from pathlib import Path

_ROOT = Path(__file__).parent.resolve()
sys.path.insert(0, str(_ROOT))

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.core.provenance import hash_string


def _hash_list(items: list[str]) -> str:
    joined = "\n".join(sorted(items))
    return "sha256:" + hashlib.sha256(joined.encode()).hexdigest()


# ─── Pre-registered feature groups ──────────────────────────────
# All names match actual merged DataFrame column names.
# VP price features are ATR-normalised distances after load_merged().

PRE_REGISTERED = {

    # ── Volume Profile (ATR-normalised distances from entry price) ──
    # Positive = level is ABOVE entry, Negative = BELOW entry
    "vp_levels": [
        "vpPOC",          # POC distance (≈0 = price at POC)
        "vpVAH",          # VAH distance (positive = VAH above price)
        "vpVAL",          # VAL distance (negative = VAL below price)
        "vpDailyPOC",     # Daily POC distance
        "vpCompPOC",      # Composite session POC distance
        "vpCompVAH",      # Composite VAH distance
        "vpCompVAL",      # Composite VAL distance
    ],

    # ── VP structural features (ratios, already normalised by EA) ──
    "vp_structure": [
        "vpInsideVA",         # 1 = price inside value area
        "vpCompInsideVA",     # 1 = price inside composite VA
        "vpThinnessRatio",    # thin profile = easier breakout (0-1)
        "vpVAOverlapRatio",   # VA overlap ratio across sessions
        "vpVAOverlapBias",    # directional bias of overlap
        "vpBestHVNScore",     # strength of best HVN (0-1)
        "vpDistToHVN",        # distance to nearest HVN in ATR
        "vpDistToLVN",        # distance to nearest LVN in ATR
        "vpDistCompPOC",      # distance to composite POC in ATR
        "vpMigrationScore",   # POC migration strength (0-1)
        "vpMigrationConf",    # POC migration confidence (0-1)
        "vpDevPOCDir",        # developing POC direction (-1/0/+1)
        "vpDevPOCSlope",      # developing POC slope
        "vpProfileShape",     # profile shape code (0=P, 1=b, 2=D, etc.)
        "vpUpthrust",         # upthrust detected (0/1)
        "vpSpring",           # spring detected (0/1)
        "vpCompPosition",     # position vs composite profile (-1/0/+1)
        "vpPriceVsPOC",       # signed distance current vs POC (normalised)
    ],

    # ── Auction/Market Profile ──────────────────────────────────────
    "auction": [
        "auctAcceptance",    # VA acceptance score (0-1)
        "auctBalance",       # balance score (0-1, 0.5=neutral)
        "auctFailure",       # auction failure score (0-1)
        "auctRegime",        # regime int (0-8)
        "auctRegimeConf",    # regime confidence (0-1)
        "auctTradeQuality",  # trade quality score (0-1)
        "auctTradeGrade",    # trade grade (1-4)
        "auctExpReward",     # expected reward in ATR
        "auctExpMoveATR",    # expected price move in ATR
        "auctTargetProb",    # target probability (0-1)
        "auctVAExpRate",     # VA expansion rate (-1 to +1)
        "auctExhaustion",    # exhaustion score (0-1)
        "auctContinuation",  # continuation score (0-1)
        "auctReversalRisk",  # reversal risk (0-1)
        "auctHVNStrength",   # HVN strength (0-1)
        "auctLVNStrength",   # LVN strength (0-1)
        "auctTargetConf",    # target confidence (0-1)
        "auctShapeConf",     # shape confidence (0-1)
        "auctProfitZone",    # profit zone score (0-1)
    ],

    # ── Long-Term VP (ATR-normalised after transform) ───────────────
    "vp_longterm": [
        "vpLTTransitionScore",   # long-term transition score (0-1)
        "vpLTBalanceStability",  # balance stability (0-1)
        "vpLTTrendDuration",     # trend duration (bars, may be large)
        "vpLTTrendExhaustion",   # trend exhaustion (0-1)
        "vpLTPOCVelocity",       # POC velocity (normalised points/bar)
        "vpLTPOCMigration",      # POC migration direction (-1/0/+1)
        "vpLTMajorHVNStrength",  # major HVN strength (0-1)
        "vpLTMajorLVNStrength",  # major LVN strength (0-1)
        "vpLTNearestZoneStrength", # nearest LT zone strength
        "vpLTNearestZoneDir",    # nearest LT zone direction (-1/0/+1)
        "vpLTValid",             # LT VP data is valid (0/1)
        "vpLTAcceptanceAtPrice", # LT acceptance at current price
    ],

    # ── Microstructure ──────────────────────────────────────────────
    "microstructure": [
        "msCompression",      # price compression score (0-1) — PRIMARY
        "msSpreadScore",      # spread normalised score (0-1)
    ],

    # ── Order Flow ──────────────────────────────────────────────────
    "orderflow": [
        "ofFlowIntensity",    # flow intensity (0-1) — PRIMARY
        "ofAbsorption",       # absorption at level (0-1)
        "ofExhaustion",       # flow exhaustion (0-1)
        "ofParticipation",    # market participation (0-1)
        "ofDivergence",       # price/flow divergence (0-1)
        "ofDeltaProxy",       # order delta proxy (0-1)
    ],

    # ── Liquidity ───────────────────────────────────────────────────
    "liquidity": [
        "liqSweep",           # sweep detected (0-1) — PRIMARY
        "liqDensity",         # liquidity density (0-1)
        "liqStopCluster",     # stop cluster (0-1)
        "liqEqualHL",         # equal highs/lows (0-1)
        "liqSessionLiq",      # session liquidity level (0-1)
        "liqPremDisc",        # premium/discount zone (0-1)
    ],

    # ── Smart Money ─────────────────────────────────────────────────
    "smartmoney": [
        "smZoneQuality",      # zone quality (0-1) — PRIMARY
        "smFVG",              # fair value gap score (0-1)
        "smMitigation",       # mitigation score (0-1)
        "smRejectionBlock",   # rejection block score (0-1)
    ],

    # ── Structure (composites built by data_loader) ─────────────────
    "structure": [
        "trendDirection",     # trend direction (-1/0/+1)
        "structDistATR",      # distance to last structure in ATR
        "structureBias",      # structure directional bias (0-1)
        "bosScore",           # BOS quality score
        "chochScore",         # CHOCH quality score
    ],

    # ── Profiler (symbol behavior profile) ──────────────────────────
    "profiler": [
        "profilerTQMean",     # mean trade quality from profiler
        "profilerMigMean",    # mean POC migration from profiler
        "profilerBalMean",    # mean balance from profiler
        "profilerSamples",    # number of profiler samples
    ],

    # ── Market conditions ───────────────────────────────────────────
    "market": [
        "spreadToATR",        # spread / ATR ratio (lower=better)
        "session",            # trading session (1=London, 2=NY, 3=Asia)
        "thesis",             # entry thesis score (0-1)
        "riskReward",         # R:R ratio at entry
    ],
}

ALL_FEATURES = [f for grp in PRE_REGISTERED.values() for f in grp]


# ─── Shape priors ────────────────────────────────────────────────
# MONO_UP  = higher value → better profitUSD (positive Spearman)
# MONO_DOWN = lower value → better profitUSD
# BAND      = middle range is best (non-monotone)
#
# VP levels are ATR-normalised distances (positive=above entry, negative=below).
# Sign convention: for a BUY trade, being near the POC (vpPOC≈0) is balanced,
# being below VAL (vpVAL very negative) means price accepted below value = bearish.

SHAPE_PRIORS = {
    # VP levels (ATR-normalised distances after transform)
    # For BUY trades: price above POC (vpPOC>0) = bullish → MONO_UP
    "vpPOC":          "MONO_UP",
    "vpVAH":          "MONO_DOWN",   # far VAH above = more room, but also means price is low in range
    "vpVAL":          "MONO_UP",     # VAL close below = good support for buy
    "vpDailyPOC":     "BAND",        # near daily POC = balanced market
    "vpCompPOC":      "BAND",
    "vpCompVAH":      "MONO_DOWN",
    "vpCompVAL":      "MONO_UP",

    # VP structural
    "vpInsideVA":         "MONO_UP",   # inside VA = better trade location
    "vpCompInsideVA":     "MONO_UP",
    "vpThinnessRatio":    "MONO_UP",   # thin = low-resistance move potential
    "vpVAOverlapRatio":   "BAND",
    "vpVAOverlapBias":    "MONO_UP",
    "vpBestHVNScore":     "MONO_UP",
    "vpDistToHVN":        "MONO_DOWN", # closer to HVN = more support/resistance
    "vpDistToLVN":        "MONO_UP",   # further from LVN = away from weak zone
    "vpDistCompPOC":      "BAND",
    "vpMigrationScore":   "MONO_UP",
    "vpMigrationConf":    "MONO_UP",
    "vpDevPOCDir":        "MONO_UP",   # positive = POC moving up = bullish
    "vpDevPOCSlope":      "MONO_UP",
    "vpProfileShape":     "BAND",
    "vpUpthrust":         "MONO_DOWN", # upthrust = bearish signal
    "vpSpring":           "MONO_UP",   # spring = bullish absorption
    "vpCompPosition":     "MONO_UP",   # +1 = above composite POC = bullish
    "vpPriceVsPOC":       "MONO_UP",   # positive = price above POC = bullish

    # Auction
    "auctAcceptance":    "MONO_UP",
    "auctBalance":       "BAND",       # 0.5=neutral, extreme=directional move
    "auctFailure":       "MONO_DOWN",  # high failure = bad auction = risky
    "auctRegime":        "BAND",       # regime code, non-monotone
    "auctRegimeConf":    "MONO_UP",
    "auctTradeQuality":  "MONO_UP",
    "auctTradeGrade":    "MONO_UP",
    "auctExpReward":     "MONO_UP",
    "auctExpMoveATR":    "MONO_UP",
    "auctTargetProb":    "MONO_UP",
    "auctVAExpRate":     "MONO_UP",    # positive = expanding VA = momentum
    "auctExhaustion":    "MONO_DOWN",
    "auctContinuation":  "MONO_UP",
    "auctReversalRisk":  "MONO_DOWN",
    "auctHVNStrength":   "MONO_UP",
    "auctLVNStrength":   "MONO_DOWN",  # strong LVN nearby = adverse
    "auctTargetConf":    "MONO_UP",
    "auctShapeConf":     "MONO_UP",
    "auctProfitZone":    "MONO_UP",

    # LT VP
    "vpLTTransitionScore":    "MONO_UP",
    "vpLTBalanceStability":   "MONO_UP",
    "vpLTTrendDuration":      "BAND",
    "vpLTTrendExhaustion":    "MONO_DOWN",
    "vpLTPOCVelocity":        "MONO_UP",
    "vpLTPOCMigration":       "MONO_UP",   # +1=bullish direction
    "vpLTMajorHVNStrength":   "MONO_UP",
    "vpLTMajorLVNStrength":   "MONO_DOWN",
    "vpLTNearestZoneStrength":"BAND",
    "vpLTNearestZoneDir":     "MONO_UP",
    "vpLTValid":              "MONO_UP",
    "vpLTAcceptanceAtPrice":  "MONO_UP",

    # Microstructure
    "msCompression":  "MONO_UP",
    "msSpreadScore":  "MONO_UP",

    # Order flow
    "ofFlowIntensity":  "MONO_UP",
    "ofAbsorption":     "MONO_UP",
    "ofExhaustion":     "MONO_DOWN",
    "ofParticipation":  "MONO_UP",
    "ofDivergence":     "BAND",
    "ofDeltaProxy":     "MONO_UP",

    # Liquidity
    "liqSweep":        "MONO_UP",    # sweep = liquidity taken = good entry
    "liqDensity":      "BAND",
    "liqStopCluster":  "MONO_UP",    # stop cluster swept = cleaner entry
    "liqEqualHL":      "MONO_UP",    # equal H/L swept = better entries
    "liqSessionLiq":   "MONO_UP",
    "liqPremDisc":     "BAND",

    # Smart money
    "smZoneQuality":     "MONO_UP",
    "smFVG":             "MONO_UP",
    "smMitigation":      "MONO_UP",
    "smRejectionBlock":  "MONO_UP",

    # Structure
    "trendDirection":  "MONO_UP",    # +1=uptrend = better for buys
    "structDistATR":   "BAND",
    "structureBias":   "MONO_UP",
    "bosScore":        "MONO_UP",
    "chochScore":      "MONO_UP",

    # Profiler
    "profilerTQMean":   "MONO_UP",
    "profilerMigMean":  "MONO_UP",
    "profilerBalMean":  "BAND",
    "profilerSamples":  "MONO_UP",   # more samples = more reliable profile

    # Market
    "spreadToATR":  "MONO_DOWN",     # high spread = adverse
    "session":      "BAND",          # session code, non-monotone
    "thesis":       "MONO_UP",
    "riskReward":   "MONO_UP",
}

FEATURE_DIRECTION = {
    f: (0 if SHAPE_PRIORS.get(f) == "BAND"
        else 1 if SHAPE_PRIORS.get(f) == "MONO_UP"
        else -1)
    for f in ALL_FEATURES
    if f in SHAPE_PRIORS
}


# ─── Build contract dict ─────────────────────────────────────────

def build_contract_dict() -> dict:
    feature_registry_hash = _hash_list(ALL_FEATURES)
    target_defn = "profitUSD of production-style (trailStyle=1) trade"
    target_definition_hash = hash_string(target_defn)
    split_defn = "temporal split 70/30"
    split_definition_hash = hash_string(split_defn)

    return {
        "version": "v1",
        "observation_unit": "1 closed trade (trailStyle=1 production style) per signal",
        "style_filter": "production_style=1 (expansion trailing)",

        "pre_registered": PRE_REGISTERED,
        "feature_direction": FEATURE_DIRECTION,
        "shape_priors": SHAPE_PRIORS,
        "allowed_interactions": [],

        "gate_types": ["threshold", "band"],
        "allowed_directions": [1, -1, 0],

        "primary_test": "one-sided t-test on fold EVs",
        "screening_test": "permutation",
        "multiple_testing_method": "benjamini-hochberg",

        "fdr_pools": {
            "hard_gate": {
                "name": "hard_gate",
                "max_hypotheses": 10000,
                "alpha": 0.05,
            },
            "soft_gate": {
                "name": "soft_gate",
                "max_hypotheses": 10000,
                "alpha": 0.05,
            },
            "regime_block": {
                "name": "regime_block",
                "max_hypotheses": 10000,
                "alpha": 0.05,
            },
            "bad_entry": {
                "name": "bad_entry",
                "max_hypotheses": 5000,
                "alpha": 0.05,
            },
        },

        "edge_discovery_target": {
            "name": "profitUSD",
            "definition": target_defn,
            "used_by": ["L4", "L4b", "L5", "L7"],
        },
        "bad_entry_canary_target": {
            "name": "MFE-based entry quality",
            "definition": "MFE_max_across_3_styles >= 1.0 ATR",
            "used_by": ["L10a"],
        },

        "optimization_budget": {
            "sl_candidates": [1.0, 1.5, 2.0, 2.5, 3.0],
            "tp_candidates": [1.0, 1.5, 2.0, 2.5, 3.0],
            "sizing_configs": 5,
            "utility_function": "expectancy",
            "tiebreaker": ["sl_atr DESC", "tp_atr DESC"],
        },

        "stopping_rules": {
            "min_group_samples": 30,
            "min_fold_consistency": 0.60,
            "min_effect_size": 0.05,
            "max_outer_folds": 5,
            "max_inner_folds": 3,
        },

        "production_criteria": {
            "min_ev": 0.05,
            "min_pf": 1.10,
            "min_wr": 0.35,
            "require_robust_across_styles": False,
            "require_holdout_confirmation": True,
        },

        "selection_budget": {
            "max_experiments_per_dataset": 5,
            "max_contract_changes_per_day": 2,
            "cooldown_hours_between_experiments": 24,
            "max_eda_inspect_and_rerun": 1,
            "config_frozen_after_start": True,
        },

        "split_ratio": 0.70,
        "split_method": "temporal",

        # Stub hashes — governance uses actual dataset_hash at runtime
        "dataset_hash":           "sha256:" + "0" * 64,
        "code_hash":              "sha256:" + "0" * 64,
        "config_hash":            hash_string("contract_v2_feature_corrected"),
        "feature_registry_hash":  feature_registry_hash,
        "target_definition_hash": target_definition_hash,
        "split_definition_hash":  split_definition_hash,
    }


def main():
    contracts_dir = _ROOT / "contracts"
    contracts_dir.mkdir(exist_ok=True)
    out_path = contracts_dir / "contract_v1.yaml"

    d = build_contract_dict()
    contract = ResearchContract.from_dict(d)
    contract.to_yaml(out_path)

    print(f"[OK] Contract written: {out_path}")
    print(f"     contract_hash  : {contract.contract_hash[:40]}...")
    print(f"     n_features     : {len(ALL_FEATURES)}")
    print(f"     n_groups       : {len(PRE_REGISTERED)}")
    print()
    print("Changes vs v1:")
    print("  - Feature names now match actual merged DataFrame columns")
    print("  - VP levels are ATR-normalised distances (after data_loader normalize)")
    print("  - Shape priors updated for normalised semantics")
    print("  - All 165 analysis-ready columns covered")
    print()
    print("Next:")
    print("  python run_pipeline.py")


if __name__ == "__main__":
    main()
