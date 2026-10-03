"""Pre-registered constants shared across layers.

Interaction definitions are theory-driven and pre-registered. Changing
this list requires a new ResearchContract (new experiment).
"""
from __future__ import annotations

# ─── Interaction definitions ──────────────────────────────────────
# Each tuple: (interaction_name, feature_a, feature_b)
# Interaction value = product of min-max normalised (a, b), clipped to [0, 1].

DEFAULT_INTERACTION_DEFS: tuple[tuple[str, str, str], ...] = (
    ("ix_tq_mig",       "auctTradeQuality", "vpMigrationConf"),
    ("ix_bos_trend",    "bosQuality",        "structAlign"),
    ("ix_spread_atr",   "spreadToATR",       "atrProxy"),
    ("ix_cont_mig",     "auctContinuation",  "vpMigrationConf"),
    ("ix_fail_reversal","auctFailure",       "auctReversalRisk"),
    ("ix_struct_bos",   "chochQuality",      "structAlign"),
    ("ix_devpoc_ltpoc", "vpDevPOCDir",       "vpLTPOCVelocity"),
    ("ix_exhaust_lt",   "auctExhaustion",    "vpLTTrendExhaustion"),
    ("ix_acceptance",   "vpInsideVA",        "auctAcceptance"),
    ("ix_target_rr",    "auctTargetProb",    "RR"),
)

# ─── Regime names (mirrors EA REGIME_NAMES) ───────────────────────
REGIME_NAMES: dict[int, str] = {
    0: "BALANCED_ROTATION",
    1: "COMPRESSION",
    2: "TREND_INITIATION",
    3: "TREND_CONTINUATION",
    4: "RE_ACCUMULATION",
    5: "EXHAUSTION",
    6: "FAILED_AUCTION",
    7: "EXCESS",
    8: "CHAOTIC",
}

# ─── Trail style labels ───────────────────────────────────────────
TRAIL_STYLE_LABELS: dict[int, str] = {
    -1: "no_trail",
    0:  "conservative",
    1:  "expansion",
}
