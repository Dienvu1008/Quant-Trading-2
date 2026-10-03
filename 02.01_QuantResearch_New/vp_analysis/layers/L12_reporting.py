"""Layer 12 — Reporting & EA Guard Export.

Consumes all frozen artifacts from L7 (FrozenProductionConfig) plus
optional regime blocks and soft-gate tilts, and produces:

  1. VPEdgeGuardConfig.mqh — MQL5 hardcoded lookup tables with 6 functions:

       VPGetEdgeMultiplier(symbol, setup, feature, value)
           → 0.0 (block) or 1.0 (pass) — from hard gates (L4/L6 FrozenRule)

       VPGetEdgeTiltMultiplier(symbol, setup, feature, value)
           → [0.5, 1.0] — from soft gate tilts (L5/L6 validated_soft_gates)
           [Fix #5] Exported to .mqh, not left as CSV only.

       VPIsBlocked(symbol, setup, regime)
           → true (block) — from regime blocks (L4b FrozenRegimeBlockRule)

       VPGetSLRiskMultiplier(symbol, setup, feature, value)
           → [0.5, 1.0] — from SL risk thresholds (L7c FrozenSLRiskThreshold)

       VPGetLotMultiplier(symbol, setup)
           → [0.5, 1.5] — from sizing configs (L7b FrozenProductionConfig)

       VPIsSymbolBlocked(symbol)
           → reserved / always false if no data (extendable from Phase 01)

  2. vp_edge_guards.json — full config for audit/version tracking

All values come from previously frozen artifacts. This layer performs
NO new analysis — it is a pure code-generation step.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import pandas as pd


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class ReportingConfig:
    # Target EA config directory (copy .mqh here if it exists)
    ea_config_dir: Optional[str] = None

    # Production trailing style label (cosmetic, for .mqh header comment)
    production_style: int = 1   # -1=no-trail, 0=conservative, 1=expansion

    # Max gates emitted per function (keeps file manageable)
    max_hard_gates: int = 200
    max_soft_tilts: int = 100
    max_regime_blocks: int = 100
    max_sl_thresholds: int = 50
    max_lot_multipliers: int = 100

    # Soft tilt multiplier for "unfavourable" side
    # When feature is on the wrong side of its direction, return this multiplier
    default_tilt_multiplier: float = 0.75


# ─── Result type ─────────────────────────────────────────────────

@dataclass(frozen=True)
class LayerTwelveResult:
    mqh_path: Optional[str]
    json_path: Optional[str]
    n_hard_gates: int
    n_soft_tilts: int
    n_regime_blocks: int
    n_sl_thresholds: int
    n_lot_multipliers: int
    warnings: tuple
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "mqh_path": self.mqh_path,
            "n_hard_gates": self.n_hard_gates,
            "n_soft_tilts": self.n_soft_tilts,
            "n_regime_blocks": self.n_regime_blocks,
            "n_sl_thresholds": self.n_sl_thresholds,
            "n_lot_multipliers": self.n_lot_multipliers,
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    production_config,          # FrozenProductionConfig from L7
    experiment_id: str,
    output_dir: Optional[Path] = None,
    config: Optional[ReportingConfig] = None,
    # Optional extra artifacts
    validated_soft_gates=None,  # list/tuple of ValidatedCandidate from L6
    regime_blocks=None,         # list/tuple of FrozenRegimeBlockRule / RegimeBlockCandidate
    sl_risk_thresholds=None,    # list/tuple of FrozenSLRiskThreshold
) -> LayerTwelveResult:
    """Generate VPEdgeGuardConfig.mqh from all frozen artifacts.

    Parameters
    ----------
    production_config : FrozenProductionConfig
        Primary source of frozen rules + sizing configs.
    experiment_id : str
        Unique experiment identifier (embedded in .mqh header).
    output_dir : Path, optional
        Directory to write .mqh and .json files.
    config : ReportingConfig, optional
        Tuning parameters.
    validated_soft_gates : iterable, optional
        ValidatedCandidate objects from L6 soft gate pool.
        Each must have .candidate_dict with keys:
        symbol, setup, feature, direction, ev_lift, perm_pvalue.
    regime_blocks : iterable, optional
        FrozenRegimeBlockRule or RegimeBlockCandidate objects from L4b/L6.
    sl_risk_thresholds : iterable, optional
        FrozenSLRiskThreshold objects from L7c.
    """
    cfg = config or ReportingConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"
    warnings: list[str] = []

    if not experiment_id:
        raise ValueError("L12: experiment_id is required")

    out_dir = Path(output_dir) if output_dir else None
    if out_dir:
        out_dir.mkdir(parents=True, exist_ok=True)

    # ─── Collect all artifacts ───────────────────────────────────
    hard_gates = list(getattr(production_config, "rules", ()))
    sizing_configs = list(getattr(production_config, "sizing_configs", ()))
    sl_tp_selections = list(getattr(production_config, "sl_tp_selections", ()))

    soft_tilts = list(validated_soft_gates or [])
    blocks = list(regime_blocks or [])
    sl_thresholds = list(sl_risk_thresholds or [])

    # Also pull from production_config extras (v3 additions)
    if hasattr(production_config, "regime_blocks"):
        for rb in production_config.regime_blocks:
            if rb not in blocks:
                blocks.append(rb)
    if hasattr(production_config, "soft_gate_tilts"):
        for tilt in production_config.soft_gate_tilts:
            if tilt not in soft_tilts:
                soft_tilts.append(tilt)
    if hasattr(production_config, "sl_risk_thresholds"):
        for t in production_config.sl_risk_thresholds:
            if t not in sl_thresholds:
                sl_thresholds.append(t)

    # ─── Build guard data structures ────────────────────────────
    hard_gate_rows = _build_hard_gate_rows(hard_gates, sl_tp_selections)
    soft_tilt_rows = _build_soft_tilt_rows(soft_tilts, cfg)
    regime_block_rows = _build_regime_block_rows(blocks)
    sl_risk_rows = _build_sl_risk_rows(sl_thresholds)
    lot_mult_rows = _build_lot_mult_rows(sizing_configs, hard_gates)

    # ─── Generate JSON guard config ──────────────────────────────
    guard_config = {
        "version": "3.0",
        "generated_at": ran_at,
        "experiment_id": experiment_id,
        "research_contract_hash": getattr(
            production_config, "research_contract_hash", ""
        ),
        "production_style": cfg.production_style,
        "hard_gates": hard_gate_rows,
        "soft_tilts": soft_tilt_rows,
        "regime_blocks": regime_block_rows,
        "sl_risk_thresholds": sl_risk_rows,
        "lot_multipliers": lot_mult_rows,
    }

    json_path_str = None
    mqh_path_str = None

    if out_dir:
        json_path = out_dir / "vp_edge_guards.json"
        with json_path.open("w", encoding="utf-8") as fh:
            json.dump(guard_config, fh, indent=2, default=str)
        json_path_str = str(json_path)

        # ─── Generate MQL5 .mqh ──────────────────────────────────
        mqh_content = _generate_mqh(
            guard_config=guard_config,
            experiment_id=experiment_id,
            cfg=cfg,
        )
        mqh_path = out_dir / "VPEdgeGuardConfig.mqh"
        mqh_path.write_text(mqh_content, encoding="utf-8")
        mqh_path_str = str(mqh_path)

        # Optionally copy to EA config dir
        if cfg.ea_config_dir:
            ea_dir = Path(cfg.ea_config_dir)
            if ea_dir.exists():
                (ea_dir / "VPEdgeGuardConfig.mqh").write_text(
                    mqh_content, encoding="utf-8"
                )
            else:
                warnings.append(
                    f"ea_config_dir does not exist: {cfg.ea_config_dir}"
                )

        # Summary JSON
        result_obj = LayerTwelveResult(
            mqh_path=mqh_path_str,
            json_path=json_path_str,
            n_hard_gates=len(hard_gate_rows),
            n_soft_tilts=len(soft_tilt_rows),
            n_regime_blocks=len(regime_block_rows),
            n_sl_thresholds=len(sl_risk_rows),
            n_lot_multipliers=len(lot_mult_rows),
            warnings=tuple(warnings),
            ran_at=ran_at,
        )
        with (out_dir / "L12_summary.json").open("w", encoding="utf-8") as fh:
            json.dump(result_obj.summary_dict(), fh, indent=2, default=str)
    else:
        result_obj = LayerTwelveResult(
            mqh_path=None, json_path=None,
            n_hard_gates=len(hard_gate_rows),
            n_soft_tilts=len(soft_tilt_rows),
            n_regime_blocks=len(regime_block_rows),
            n_sl_thresholds=len(sl_risk_rows),
            n_lot_multipliers=len(lot_mult_rows),
            warnings=tuple(warnings),
            ran_at=ran_at,
        )

    return result_obj


# ─── Data builders ───────────────────────────────────────────────

def _build_hard_gate_rows(rules, sl_tp_selections) -> list[dict]:
    """Extract hard gate rows from FrozenRule list + SL/TP selections."""
    sl_tp_map = {s["rule_id"]: s for s in sl_tp_selections
                 if isinstance(s, dict) and "rule_id" in s}
    rows = []
    for rule in rules:
        sl_tp = sl_tp_map.get(rule.rule_id, {})
        rows.append({
            "rule_id": rule.rule_id,
            "symbol": rule.symbol,
            "setup": rule.setup,
            "feature": rule.features[0] if rule.features else "",
            "gate_type": rule.gate_type,
            "direction": rule.direction,
            "lower_bound": rule.lower_bound,
            "upper_bound": rule.upper_bound,
            "ev": float(rule.test_ev_mean),
            "wr": float(rule.test_wr_mean),
            "pf": float(rule.test_pf_mean),
            "n": int(rule.test_n_avg),
            "fold_consistency": float(rule.fold_consistency),
            "pvalue_fdr": float(rule.pvalue_fdr) if rule.pvalue_fdr is not None else None,
            "sl": float(sl_tp["sl"]) if "sl" in sl_tp else None,
            "tp": float(sl_tp["tp"]) if "tp" in sl_tp else None,
        })
    return rows


def _build_soft_tilt_rows(soft_tilts, cfg: ReportingConfig) -> list[dict]:
    """Extract soft tilt rows from ValidatedCandidate or FrozenSoftGateTilt."""
    rows = []
    for item in soft_tilts:
        # Handle ValidatedCandidate (from L6 filter_soft_gates)
        if hasattr(item, "candidate_dict"):
            cd = item.candidate_dict
            rows.append({
                "symbol": cd.get("symbol", ""),
                "setup": cd.get("setup", ""),
                "feature": cd.get("feature", ""),
                "direction": int(cd.get("direction", 1)),
                "ev_lift": float(cd.get("ev_lift", 0.0)),
                "perm_pvalue": float(cd.get("perm_pvalue", 1.0)),
                "p_adjusted": float(item.p_adjusted),
                "tilt_multiplier": cfg.default_tilt_multiplier,
            })
        # Handle FrozenSoftGateTilt (from production_config.soft_gate_tilts)
        elif hasattr(item, "tilt_below"):
            rows.append({
                "symbol": item.symbol,
                "setup": item.setup,
                "feature": item.feature,
                "direction": int(item.direction),
                "ev_lift": float(item.dev_lift),
                "perm_pvalue": float(item.perm_pvalue) if item.perm_pvalue else 1.0,
                "p_adjusted": float(item.pvalue_fdr) if item.pvalue_fdr else 1.0,
                "tilt_below": float(item.tilt_below),
                "tilt_above": float(item.tilt_above),
                "threshold": float(item.threshold) if item.threshold is not None else None,
                "tilt_multiplier": float(item.tilt_below),
            })
    return rows


def _build_regime_block_rows(blocks) -> list[dict]:
    """Extract regime block rows from FrozenRegimeBlockRule or RegimeBlockCandidate."""
    rows = []
    for item in blocks:
        if hasattr(item, "rule_type"):
            # FrozenRegimeBlockRule
            rows.append({
                "symbol": item.symbol,
                "setup": item.setup,
                "rule_type": item.rule_type,
                "condition": item.condition,
                "ev": float(getattr(item, "blocked_ev", 0.0)),
                "combined_p": float(getattr(item, "combined_p", 1.0))
                              if hasattr(item, "combined_p") else None,
            })
        else:
            # RegimeBlockCandidate (from L4b)
            rows.append({
                "symbol": getattr(item, "symbol", ""),
                "setup": getattr(item, "setup", ""),
                "rule_type": getattr(item, "rule_type", ""),
                "condition": getattr(item, "condition", ""),
                "ev": float(getattr(item, "mean_blocked_ev", 0.0)),
                "combined_p": float(getattr(item, "combined_p", 1.0)),
            })
    return rows


def _build_sl_risk_rows(thresholds) -> list[dict]:
    rows = []
    for t in thresholds:
        rows.append({
            "symbol": getattr(t, "symbol", ""),
            "setup": getattr(t, "setup", ""),
            "feature": getattr(t, "feature", ""),
            "direction": getattr(t, "direction", "above"),
            "threshold_value": float(getattr(t, "threshold_value", 0.0)),
            "sl_risk_multiplier": float(getattr(t, "sl_risk_multiplier", 0.5)),
            "dev_sl_lift": float(getattr(t, "dev_sl_lift", 0.0)),
        })
    return rows


def _build_lot_mult_rows(sizing_configs, rules) -> list[dict]:
    """Build lot multiplier rows indexed by rule_id → (symbol, setup)."""
    rule_map = {r.rule_id: r for r in rules}
    rows = []
    for s in sizing_configs:
        if not isinstance(s, dict):
            continue
        rule_id = s.get("rule_id", "")
        rule = rule_map.get(rule_id)
        symbol = rule.symbol if rule else ""
        setup = rule.setup if rule else ""
        rows.append({
            "rule_id": rule_id,
            "symbol": symbol,
            "setup": setup,
            "lot_mult": float(s.get("lot_mult", 1.0)),
        })
    return rows


# ─── MQL5 code generation ─────────────────────────────────────────

STYLE_LABEL = {-1: "no-trailing", 0: "conservative", 1: "expansion"}
REGIME_INT = {
    "BALANCED_ROTATION": 0, "COMPRESSION": 1, "TREND_INITIATION": 2,
    "TREND_CONTINUATION": 3, "RE_ACCUMULATION": 4, "EXHAUSTION": 5,
    "FAILED_AUCTION": 6, "EXCESS": 7, "CHAOTIC": 8,
}


def _generate_mqh(
    guard_config: dict,
    experiment_id: str,
    cfg: ReportingConfig,
) -> str:
    lines: list[str] = []
    ts = guard_config["generated_at"]
    ps = guard_config["production_style"]
    ps_label = STYLE_LABEL.get(ps, "?")
    contract_hash = guard_config.get("research_contract_hash", "")

    # ─── Header ───────────────────────────────────────────────────
    lines += [
        "#ifndef __VP_EA_EDGEGUARD_CONFIG_MQH__",
        "#define __VP_EA_EDGEGUARD_CONFIG_MQH__",
        "",
        "// ============================================================",
        f"// VP EdgeGuard Config v3 — Generated {ts[:19]}",
        f"// Experiment : {experiment_id}",
        f"// Contract   : {contract_hash[:24]}..." if contract_hash else "// Contract   : (none)",
        f"// Prod style : {ps} ({ps_label})",
        "// DO NOT EDIT MANUALLY — regenerate with vp_analysis L12",
        "// ============================================================",
        "",
    ]

    hard_gates = guard_config.get("hard_gates", [])
    soft_tilts = guard_config.get("soft_tilts", [])
    regime_blocks = guard_config.get("regime_blocks", [])
    sl_risks = guard_config.get("sl_risk_thresholds", [])
    lot_mults = guard_config.get("lot_multipliers", [])

    # ─── 1. VPGetEdgeMultiplier (hard gate blocking) ──────────────
    lines += _gen_hard_gate_fn(hard_gates, cfg)

    # ─── 2. VPGetEdgeTiltMultiplier (soft gate tilt) [Fix #5] ─────
    lines += _gen_soft_tilt_fn(soft_tilts, cfg)

    # ─── 3. VPIsBlocked (regime blocking) ─────────────────────────
    lines += _gen_regime_block_fn(regime_blocks, cfg)

    # ─── 4. VPGetSLRiskMultiplier (SL risk thresholds) ────────────
    lines += _gen_sl_risk_fn(sl_risks, cfg)

    # ─── 5. VPIsSymbolBlocked (reserved / extendable) ─────────────
    lines += [
        "// 5. Symbol blocking — extendable from Phase 01 behavior profiling",
        "bool VPIsSymbolBlocked(const string symbol)",
        "{",
        "   // No AVOID symbols in this experiment",
        "   return false;",
        "}",
        "",
    ]

    # ─── 6. VPGetLotMultiplier (sizing calibration) ───────────────
    lines += _gen_lot_mult_fn(lot_mults, cfg)

    lines.append("#endif // __VP_EA_EDGEGUARD_CONFIG_MQH__")
    lines.append("")

    return "\n".join(lines)


def _gen_hard_gate_fn(hard_gates: list[dict], cfg: ReportingConfig) -> list[str]:
    lines: list[str] = []
    limited = hard_gates[:cfg.max_hard_gates]
    # Sort by absolute EV descending (most impactful first)
    limited = sorted(limited, key=lambda r: abs(r.get("ev", 0.0)), reverse=True)

    lines.append(f"// 1. Hard gate blocking — {len(limited)} rules (from L4/L6 FrozenRule)")
    lines.append("// Returns 0.0 if trade is BLOCKED, 1.0 if allowed.")
    lines.append("double VPGetEdgeMultiplier(const string symbol, const string setup,")
    lines.append("                            const string feature, double value)")
    lines.append("{")

    for r in limited:
        sym = r["symbol"]
        setup = r["setup"]
        feat = r["feature"]
        gt = r["gate_type"]
        direction = r["direction"]
        lo = r.get("lower_bound")
        hi = r.get("upper_bound")
        ev = r.get("ev", 0.0)
        fc = r.get("fold_consistency", 0.0)
        comment = f"// EV={ev:+.3f} fc={fc:.2f}"

        if gt == "threshold" and direction == 1 and lo is not None:
            cond = f'value < {lo:.6f}'
        elif gt == "threshold" and direction == -1 and hi is not None:
            cond = f'value > {hi:.6f}'
        elif gt == "band" and lo is not None and hi is not None:
            cond = f'(value < {lo:.6f} || value > {hi:.6f})'
        else:
            continue

        lines.append(
            f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}" '
            f'&& {cond}) return 0.0; {comment}'
        )

    lines += ["   return 1.0;", "}", ""]
    return lines


def _gen_soft_tilt_fn(soft_tilts: list[dict], cfg: ReportingConfig) -> list[str]:
    """[Fix #5] Export soft gate tilts — NOT left as CSV only."""
    lines: list[str] = []
    limited = soft_tilts[:cfg.max_soft_tilts]

    lines.append(f"// 2. Soft gate tilt — {len(limited)} tilts (from L5/L6 validated_soft_gates)")
    lines.append("// Returns multiplier in [0.5, 1.0]. Does NOT block (never returns 0.0).")
    lines.append("// Apply as: effective_lots = base_lots * VPGetEdgeTiltMultiplier(...)")
    lines.append("double VPGetEdgeTiltMultiplier(const string symbol, const string setup,")
    lines.append("                               const string feature, double value)")
    lines.append("{")

    for t in limited:
        sym = t["symbol"]
        setup = t["setup"]
        feat = t["feature"]
        direction = int(t.get("direction", 1))
        ev_lift = t.get("ev_lift", 0.0)
        mult = t.get("tilt_multiplier", cfg.default_tilt_multiplier)
        comment = f"// dir={direction:+d} lift={ev_lift:+.3f}"

        # If threshold is available (FrozenSoftGateTilt path)
        threshold = t.get("threshold")
        if threshold is not None:
            tilt_below = t.get("tilt_below", mult)
            tilt_above = t.get("tilt_above", 1.0)
            lines.append(
                f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}") '
                f'return value < {threshold:.6f} ? {tilt_below:.4f} : {tilt_above:.4f}; {comment}'
            )
        else:
            # ValidatedCandidate path — direction-based tilt
            # If direction=+1: high feature value is good → tilt DOWN when value is LOW
            # If direction=-1: low feature value is good → tilt DOWN when value is HIGH
            # Use median-based heuristic: we don't have the exact threshold here,
            # so we export direction only and let the EA use dev_spearman_rho sign.
            lines.append(
                f'   // [{sym}/{setup}/{feat}] dir={direction:+d} — '
                f'use dev median for threshold; tilt={mult:.2f} {comment}'
            )

    lines += ["   return 1.0;", "}", ""]
    return lines


def _gen_regime_block_fn(regime_blocks: list[dict], cfg: ReportingConfig) -> list[str]:
    lines: list[str] = []
    limited = regime_blocks[:cfg.max_regime_blocks]
    limited = sorted(limited, key=lambda r: r.get("ev", 0.0))  # most negative first

    lines.append(f"// 3. Regime blocking — {len(limited)} rules (from L4b FrozenRegimeBlockRule)")
    lines.append("// Returns true if trade should be BLOCKED for this (symbol, setup, regime).")
    lines.append("bool VPIsBlocked(const string symbol, const string setup, int regime)")
    lines.append("{")

    for r in limited:
        sym = r["symbol"]
        setup = r["setup"]
        rule_type = r.get("rule_type", "")
        condition = r.get("condition", "")
        ev = r.get("ev", 0.0)
        comment = f"// EV={ev:+.2f}"

        if rule_type == "auction_regime":
            regime_int = REGIME_INT.get(condition, -1)
            if regime_int >= 0:
                lines.append(
                    f'   if(symbol=="{sym}" && setup=="{setup}" && regime=={regime_int}) '
                    f'return true; {comment} {condition}'
                )
        elif rule_type == "auction_failure":
            # auctFailure is a float feature, not the integer regime param —
            # emit as comment for EA developer to handle separately
            lines.append(
                f'   // [auction_failure] {sym}/{setup} {comment} — '
                f'check auctFailure > 0.5 separately in EA'
            )

    lines += ["   return false;", "}", ""]
    return lines


def _gen_sl_risk_fn(sl_risks: list[dict], cfg: ReportingConfig) -> list[str]:
    lines: list[str] = []
    limited = sl_risks[:cfg.max_sl_thresholds]
    limited = sorted(limited, key=lambda t: t.get("dev_sl_lift", 0.0), reverse=True)

    lines.append(f"// 4. SL risk multiplier — {len(limited)} thresholds (from L7c)")
    lines.append("// Returns [0.5, 1.0]. When elevated SL risk, reduce lot size.")
    lines.append("double VPGetSLRiskMultiplier(const string symbol, const string setup,")
    lines.append("                              const string feature, double value)")
    lines.append("{")

    for t in limited:
        sym = t["symbol"]
        setup = t["setup"]
        feat = t["feature"]
        direction = t.get("direction", "above")
        threshold = float(t.get("threshold_value", 0.0))
        mult = float(t.get("sl_risk_multiplier", 0.5))
        sl_lift = float(t.get("dev_sl_lift", 0.0))
        comment = f"// SL_lift=+{sl_lift:.0%}"

        if direction == "above":
            cond = f'value > {threshold:.6f}'
        else:
            cond = f'value < {threshold:.6f}'

        lines.append(
            f'   if(symbol=="{sym}" && setup=="{setup}" && feature=="{feat}" '
            f'&& {cond}) return {mult:.4f}; {comment}'
        )

    lines += ["   return 1.0;", "}", ""]
    return lines


def _gen_lot_mult_fn(lot_mults: list[dict], cfg: ReportingConfig) -> list[str]:
    lines: list[str] = []
    limited = lot_mults[:cfg.max_lot_multipliers]

    lines.append(f"// 6. Lot multiplier — {len(limited)} configs (from L7b sizing)")
    lines.append("// Returns multiplier in [0.50, 1.50] applied to base lot size.")
    lines.append("double VPGetLotMultiplier(const string symbol, const string setup)")
    lines.append("{")

    for m in sorted(limited, key=lambda x: abs(x.get("lot_mult", 1.0) - 1.0), reverse=True):
        sym = m.get("symbol", "")
        setup = m.get("setup", "")
        mult = float(m.get("lot_mult", 1.0))
        rule_id = m.get("rule_id", "")
        if sym and setup:
            lines.append(
                f'   if(symbol=="{sym}" && setup=="{setup}") return {mult:.4f}; '
                f'// {rule_id}'
            )

    lines += ["   return 1.0; // no calibration data", "}", ""]
    return lines
