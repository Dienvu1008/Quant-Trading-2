"""Immutable artifacts for the post-freeze phase.

v3 additions:
  - FrozenRegimeBlockRule: immutable block rule for (setup, regime) combos.
    Freezes output from L4b (Regime Block Discovery). Used by L8.3 and L12
    to generate VPIsBlocked() in VPEdgeGuardConfig.mqh.
  - FrozenBadEntryFilter: immutable composite bad-entry filter.
    Freezes output from L10a. Used by L8.4 (= L10b evaluation) and L12.
  - FrozenSoftGateTilt: immutable validated soft-gate result.
    Used by L12 to generate VPGetEdgeTiltMultiplier().
  - FrozenSLRiskThreshold: immutable SL-risk threshold record.
    Freezes output from L7c. Used by L8.7 and L12 (VPGetSLRiskMultiplier()).
  - FrozenProductionConfig: extended to include all v3 frozen artifacts.

All frozen types use dataclass(frozen=True) plus explicit tuple conversion
in __post_init__ so nested containers cannot be mutated.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import asdict, dataclass, field
from typing import Optional


def _utcnow() -> str:
    return dt.datetime.utcnow().isoformat() + "Z"


# ─── FrozenRule (hard gate, from L4) ────────────────────────────

@dataclass(frozen=True)
class FrozenRule:
    # Identity
    rule_id: str
    experiment_id: str
    research_contract_hash: str

    # Scope
    symbol: str
    setup: str

    # Gate specification
    gate_type: str          # "threshold" | "band" | "model"
    direction: int          # -1, 0, 1
    features: tuple         # normalised to tuple in __post_init__
    lower_bound: Optional[float] = None
    upper_bound: Optional[float] = None
    model_weights: Optional[tuple] = None
    model_bias: Optional[float] = None
    score_threshold: Optional[float] = None

    # Evidence from development (profitUSD target)
    test_ev_mean: float = 0.0
    test_wr_mean: float = 0.0
    test_pf_mean: float = 0.0
    test_n_avg: int = 0
    pvalue: Optional[float] = None
    pvalue_fdr: Optional[float] = None
    fdr_significant: bool = False
    fold_consistency: float = 0.0
    n_folds: int = 0

    # Robustness across trailing styles (diagnostic flag, not a gate)
    robust_across_styles: bool = False
    ev_by_style: Optional[tuple] = None   # tuple of (style_int, ev_float) pairs

    frozen_at: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        object.__setattr__(self, "features", tuple(self.features))
        if self.model_weights is not None:
            object.__setattr__(self, "model_weights", tuple(self.model_weights))
        if self.ev_by_style is not None:
            object.__setattr__(self, "ev_by_style", tuple(self.ev_by_style))

        if not self.rule_id:
            raise ValueError("rule_id is required")
        if not self.experiment_id:
            raise ValueError("experiment_id is required")
        if self.gate_type not in ("threshold", "band", "model"):
            raise ValueError(
                f"gate_type must be 'threshold'|'band'|'model', got {self.gate_type!r}"
            )
        if self.direction not in (-1, 0, 1):
            raise ValueError(f"direction must be -1|0|1, got {self.direction}")
        if not self.features:
            raise ValueError("features cannot be empty")

        if self.gate_type == "threshold":
            if self.direction == 1 and self.lower_bound is None:
                raise ValueError("threshold direction=1 requires lower_bound")
            if self.direction == -1 and self.upper_bound is None:
                raise ValueError("threshold direction=-1 requires upper_bound")
        elif self.gate_type == "band":
            if self.lower_bound is None or self.upper_bound is None:
                raise ValueError("band gate requires both lower_bound and upper_bound")
            if self.lower_bound >= self.upper_bound:
                raise ValueError("band gate requires lower_bound < upper_bound")
        elif self.gate_type == "model":
            if self.model_weights is None:
                raise ValueError("model gate requires model_weights")
            if self.score_threshold is None:
                raise ValueError("model gate requires score_threshold")

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "FrozenRule":
        return cls(**d)


# ─── FrozenRegimeBlockRule (from L4b) ───────────────────────────

@dataclass(frozen=True)
class FrozenRegimeBlockRule:
    """Immutable regime block rule, discovered by L4b, evaluated by L8.3.

    A block rule says: "when this (setup, regime_type, condition) is met,
    the trade has significantly negative EV → block it."
    Used by L12 to generate VPIsBlocked() in VPEdgeGuardConfig.mqh.

    robust_across_styles=True means the block EV was negative under all
    three trailing styles — the regime is genuinely bad, not an artifact
    of the exit policy.
    """
    rule_id: str
    experiment_id: str
    research_contract_hash: str

    symbol: str
    setup: str
    rule_type: str     # "auction_regime" | "auction_failure" | "regime_session" | "regime_lt_transition"
    condition: str     # regime name, "auctFailure>0.5", "regime+session", etc.

    # Evidence (profitUSD target, dev data)
    mean_blocked_ev: float
    mean_pass_ev: float
    mean_lift: float           # pass_ev - blocked_ev (positive = block is useful)
    mean_wr_blocked: float
    mean_n_blocked: int
    n_folds: int
    fold_consistency: float
    combined_p: float          # Fisher's combined p from per-fold perm tests
    pvalue_fdr: Optional[float] = None
    fdr_significant: bool = False

    # Holdout evaluation (populated by L8.3, not during freeze)
    holdout_blocked_ev: Optional[float] = None
    holdout_confirmed: bool = False

    # Robustness
    robust_across_styles: bool = False
    blocked_ev_by_style: Optional[tuple] = None  # tuple of (style_int, ev) pairs

    frozen_at: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        if not self.rule_id:
            raise ValueError("rule_id is required")
        if not self.experiment_id:
            raise ValueError("experiment_id is required")
        valid_types = {
            "auction_regime", "auction_failure",
            "regime_session", "regime_lt_transition",
        }
        if self.rule_type not in valid_types:
            raise ValueError(
                f"rule_type must be one of {sorted(valid_types)}, "
                f"got {self.rule_type!r}"
            )
        if not self.condition:
            raise ValueError("condition cannot be empty")
        if self.blocked_ev_by_style is not None:
            object.__setattr__(
                self, "blocked_ev_by_style", tuple(self.blocked_ev_by_style)
            )

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "FrozenRegimeBlockRule":
        return cls(**d)


# ─── FrozenBadEntryFilter (from L10a) ───────────────────────────

@dataclass(frozen=True)
class FrozenBadEntryFilter:
    """Immutable composite bad-entry filter, discovered by L10a.

    Identifies entry conditions associated with bad outcomes across all
    three trailing styles (MFE-based canary label). Applied by L10b
    (= L8.4 evaluation) and exported by L12.

    The filter is a composite of individual feature rules: if a trade
    matches N_required or more of the bad_entry_rules, it is flagged as
    a potential bad entry (but NOT hard-blocked — this is a softer signal
    than FrozenRule).
    """
    filter_id: str
    experiment_id: str
    research_contract_hash: str

    symbol: str
    setup: str

    # Individual component rules (each is a dict describing the condition)
    bad_entry_rules: tuple   # tuple of dicts

    # How many rules must fire to flag an entry as bad
    n_required: int = 1

    # Evidence from dev (MFE canary target)
    dev_bad_rate_baseline: float = 0.0
    dev_bad_rate_filtered: float = 0.0
    dev_lift: float = 0.0
    pvalue_fdr: Optional[float] = None
    fdr_significant: bool = False

    # Holdout evaluation (populated by L10b/L8.4)
    holdout_lift: Optional[float] = None
    holdout_confirmed: bool = False

    frozen_at: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        if not self.filter_id:
            raise ValueError("filter_id is required")
        if not self.experiment_id:
            raise ValueError("experiment_id is required")
        if not self.bad_entry_rules:
            raise ValueError("bad_entry_rules cannot be empty")
        object.__setattr__(self, "bad_entry_rules", tuple(
            dict(r) if not isinstance(r, dict) else r
            for r in self.bad_entry_rules
        ))
        if self.n_required < 1:
            raise ValueError("n_required must be >= 1")

    def to_dict(self) -> dict:
        d = asdict(self)
        d["bad_entry_rules"] = list(self.bad_entry_rules)
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "FrozenBadEntryFilter":
        return cls(**d)


# ─── FrozenSoftGateTilt (from L5/L6, exported by L12) ───────────

@dataclass(frozen=True)
class FrozenSoftGateTilt:
    """Validated soft-gate tilt, discovered by L5, frozen by L6.

    A soft gate does NOT block trades — it tilts the lot size up or down
    via VPGetEdgeTiltMultiplier() (range: 0.5–1.0). Unlike hard gates
    which return 0.0 (block), soft gates return a multiplier < 1.0 to
    reduce exposure when the signal is unfavourable.
    """
    tilt_id: str
    experiment_id: str
    research_contract_hash: str

    symbol: str
    setup: str
    feature: str
    direction: int           # sign of Spearman correlation on dev

    # Threshold/tilt specification
    threshold: Optional[float] = None
    tilt_below: float = 0.75   # multiplier when feature is below threshold
    tilt_above: float = 1.00   # multiplier when feature is above threshold

    # Evidence from dev
    dev_lift: float = 0.0
    perm_pvalue: Optional[float] = None
    pvalue_fdr: Optional[float] = None
    fdr_significant: bool = False

    frozen_at: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        if not self.tilt_id:
            raise ValueError("tilt_id is required")
        if not self.feature:
            raise ValueError("feature is required")
        if not (0.0 < self.tilt_below <= 1.0):
            raise ValueError("tilt_below must be in (0, 1]")
        if not (0.0 < self.tilt_above <= 1.0):
            raise ValueError("tilt_above must be in (0, 1]")

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "FrozenSoftGateTilt":
        return cls(**d)


# ─── FrozenSLRiskThreshold (from L7c) ───────────────────────────

@dataclass(frozen=True)
class FrozenSLRiskThreshold:
    """Immutable SL-risk threshold, discovered by L7c.

    When feature crosses the threshold in the given direction, the SL-hit
    rate is elevated — lot size should be reduced via
    VPGetSLRiskMultiplier() in VPEdgeGuardConfig.mqh.

    This is an OPTIMIZATION result (L7c), not a hypothesis test result —
    it does NOT go through FDR correction.
    """
    threshold_id: str
    experiment_id: str
    research_contract_hash: str

    symbol: str
    setup: str
    feature: str
    direction: str           # "above" | "below"
    threshold_value: float

    # Evidence from dev
    dev_sl_rate_baseline: float = 0.0
    dev_sl_rate_elevated: float = 0.0
    dev_sl_lift: float = 0.0         # elevated_rate - baseline_rate
    sl_risk_multiplier: float = 0.5  # multiplier applied when threshold triggered

    # Holdout evaluation (populated by L8.7)
    holdout_sl_lift: Optional[float] = None
    holdout_confirmed: bool = False

    frozen_at: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        if not self.threshold_id:
            raise ValueError("threshold_id is required")
        if not self.feature:
            raise ValueError("feature is required")
        if self.direction not in ("above", "below"):
            raise ValueError(
                f"direction must be 'above' or 'below', got {self.direction!r}"
            )
        if not (0.0 < self.sl_risk_multiplier <= 1.0):
            raise ValueError(
                f"sl_risk_multiplier must be in (0, 1], got {self.sl_risk_multiplier}"
            )

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "FrozenSLRiskThreshold":
        return cls(**d)


# ─── FrozenProductionConfig (extended v3) ───────────────────────

@dataclass(frozen=True)
class FrozenProductionConfig:
    """Bundle of all frozen artifacts, locked together at production freeze.

    v3 additions over v2:
      - regime_blocks: tuple of FrozenRegimeBlockRule (from L4b)
      - bad_entry_filter: Optional FrozenBadEntryFilter (from L10a)
      - sl_risk_thresholds: tuple of FrozenSLRiskThreshold (from L7c)
      - soft_gate_tilts: tuple of FrozenSoftGateTilt (from L5/L6) [Fix #5]

    Fields:
      sl_tp_selections: tuple of dicts, each
          {"rule_id": str, "sl": float, "tp": float}
      sizing_configs: tuple of dicts, each
          {"symbol": str, "setup": str, "lot_mult": float}
    """
    experiment_id: str
    research_contract_hash: str

    # Hard gate rules (from L4/L6)
    rules: tuple

    # v3: additional frozen artifacts
    regime_blocks: tuple = field(default_factory=tuple)
    bad_entry_filter: Optional[FrozenBadEntryFilter] = None
    sl_risk_thresholds: tuple = field(default_factory=tuple)
    soft_gate_tilts: tuple = field(default_factory=tuple)

    # Optimization outputs
    sl_tp_selections: tuple = field(default_factory=tuple)
    sizing_configs: tuple = field(default_factory=tuple)

    freeze_timestamp: str = field(default_factory=_utcnow)

    def __post_init__(self) -> None:
        # Normalise all containers to tuples
        object.__setattr__(self, "rules", tuple(self.rules))
        object.__setattr__(self, "regime_blocks", tuple(self.regime_blocks))
        object.__setattr__(self, "sl_risk_thresholds", tuple(self.sl_risk_thresholds))
        object.__setattr__(self, "soft_gate_tilts", tuple(self.soft_gate_tilts))
        object.__setattr__(self, "sl_tp_selections", tuple(self.sl_tp_selections))
        object.__setattr__(self, "sizing_configs", tuple(self.sizing_configs))

        if not self.rules:
            raise ValueError(
                "FrozenProductionConfig requires at least one hard-gate rule"
            )

        # Uniqueness of rule_ids
        rule_ids = [r.rule_id for r in self.rules]
        if len(rule_ids) != len(set(rule_ids)):
            raise ValueError("Duplicate rule_ids in FrozenProductionConfig")

        # Cross-check: every sl_tp_selection references a known rule
        rule_id_set = set(rule_ids)
        for sel in self.sl_tp_selections:
            if not isinstance(sel, dict):
                continue
            rid = sel.get("rule_id")
            if rid is not None and rid not in rule_id_set:
                raise ValueError(
                    f"sl_tp_selection references unknown rule_id {rid!r}"
                )

    def to_dict(self) -> dict:
        def _freeze(obj):
            if hasattr(obj, "to_dict"):
                return obj.to_dict()
            if isinstance(obj, dict):
                return obj
            return str(obj)

        return {
            "experiment_id": self.experiment_id,
            "research_contract_hash": self.research_contract_hash,
            "rules": [r.to_dict() for r in self.rules],
            "regime_blocks": [r.to_dict() for r in self.regime_blocks],
            "bad_entry_filter": (
                self.bad_entry_filter.to_dict()
                if self.bad_entry_filter is not None else None
            ),
            "sl_risk_thresholds": [t.to_dict() for t in self.sl_risk_thresholds],
            "soft_gate_tilts": [t.to_dict() for t in self.soft_gate_tilts],
            "sl_tp_selections": [dict(s) for s in self.sl_tp_selections],
            "sizing_configs": [dict(s) for s in self.sizing_configs],
            "freeze_timestamp": self.freeze_timestamp,
        }
