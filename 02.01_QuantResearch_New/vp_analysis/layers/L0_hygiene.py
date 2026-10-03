"""Layer 0 — Data Hygiene.

Runs BEFORE the dev/holdout split on merged_all (all 3 trailing styles).

Responsibilities:
  1. Entry consistency: same entry_time and entry_price across all 3
     trailing styles for each signal (verifies DataCollect 3-fan-out
     fired correctly).
  2. MAE/MFE sanity: values are non-negative, below cap, not all-zero.
  3. Time integrity: entry_time <= exit_time, no NaT entry times.

Design:
  - Every check returns a frozen Report dataclass.
  - Severity: PASS | WARN | FAIL.
  - FAIL halts the pipeline (caller checks `.should_halt`).
  - WARN is informational — does not halt.
  - Missing columns → check is skipped with WARN, not FAIL.
  - Reports are exported to JSON (summary) + CSV (violation samples).
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd


# ─── Severity ────────────────────────────────────────────────────

class Severity(str, Enum):
    PASS = "PASS"
    WARN = "WARN"
    FAIL = "FAIL"


# ─── Configuration ───────────────────────────────────────────────

@dataclass
class HygieneConfig:
    """Column names and thresholds.

    Defaults match the columns produced by the EA data collector.
    """
    # Column names
    signal_id_col: str = "signalId"
    style_col: str = "trailStyle"
    entry_time_col: str = "entryTime"
    entry_price_col: str = "entryPrice"
    exit_time_col: str = "exitTime"
    mae_col: str = "maeATR"
    mfe_col: str = "mfeATR"
    time_col: str = "time"          # fallback / funnel time column

    # Expected trail styles in DataCollect mode
    expected_styles: tuple = (-1, 0, 1)

    # Tolerances
    entry_price_tolerance: float = 1e-6    # absolute price units
    mae_mfe_cap_atr: float = 10.0          # MAE/MFE in ATR — hard cap
    dead_trade_tolerance: float = 1e-9     # both MAE and MFE ~ 0

    # Halt flags — individual checks can be non-halting for debug runs
    halt_on_entry_inconsistency: bool = True
    halt_on_mae_mfe_violation: bool = True
    halt_on_time_integrity: bool = True

    # Output caps
    max_samples_in_csv: int = 1000
    max_violating_ids_in_report: int = 50

    # Warn threshold: fraction of signals with missing styles → WARN
    missing_styles_warn_fraction: float = 0.10
    # Warn threshold: fraction of rows with dead trades → WARN
    dead_trade_warn_fraction: float = 0.01
    # Warn threshold: fraction of rows with missing entry_time → WARN
    missing_entry_time_warn_fraction: float = 0.01


# ─── Report types (frozen) ───────────────────────────────────────

@dataclass(frozen=True)
class EntryConsistencyReport:
    severity: str
    skipped: bool
    skip_reason: Optional[str]
    n_signals: int
    n_signals_with_all_styles: int
    n_signals_missing_styles: int
    n_entry_time_mismatch: int
    n_entry_price_mismatch: int
    missing_styles_breakdown: dict
    violating_signal_ids_sample: tuple

    def to_dict(self) -> dict:
        return {
            "severity": self.severity,
            "skipped": self.skipped,
            "skip_reason": self.skip_reason,
            "n_signals": self.n_signals,
            "n_signals_with_all_styles": self.n_signals_with_all_styles,
            "n_signals_missing_styles": self.n_signals_missing_styles,
            "n_entry_time_mismatch": self.n_entry_time_mismatch,
            "n_entry_price_mismatch": self.n_entry_price_mismatch,
            "missing_styles_breakdown": dict(self.missing_styles_breakdown),
            "violating_signal_ids_sample": list(
                self.violating_signal_ids_sample
            ),
        }


@dataclass(frozen=True)
class MaeMfeSanityReport:
    severity: str
    skipped: bool
    skip_reason: Optional[str]
    n_total: int
    n_negative_mae: int
    n_negative_mfe: int
    n_mae_exceeds_cap: int
    n_mfe_exceeds_cap: int
    n_dead_trades: int
    n_missing_mae: int
    n_missing_mfe: int
    violating_indices_sample: tuple

    def to_dict(self) -> dict:
        return {
            "severity": self.severity,
            "skipped": self.skipped,
            "skip_reason": self.skip_reason,
            "n_total": self.n_total,
            "n_negative_mae": self.n_negative_mae,
            "n_negative_mfe": self.n_negative_mfe,
            "n_mae_exceeds_cap": self.n_mae_exceeds_cap,
            "n_mfe_exceeds_cap": self.n_mfe_exceeds_cap,
            "n_dead_trades": self.n_dead_trades,
            "n_missing_mae": self.n_missing_mae,
            "n_missing_mfe": self.n_missing_mfe,
            "violating_indices_sample": list(self.violating_indices_sample),
        }


@dataclass(frozen=True)
class TimeIntegrityReport:
    severity: str
    skipped: bool
    skip_reason: Optional[str]
    n_total: int
    n_missing_entry_time: int
    n_missing_exit_time: int
    n_entry_after_exit: int
    time_range_start: Optional[str]
    time_range_end: Optional[str]
    median_duration_sec: Optional[float]
    violating_indices_sample: tuple

    def to_dict(self) -> dict:
        return {
            "severity": self.severity,
            "skipped": self.skipped,
            "skip_reason": self.skip_reason,
            "n_total": self.n_total,
            "n_missing_entry_time": self.n_missing_entry_time,
            "n_missing_exit_time": self.n_missing_exit_time,
            "n_entry_after_exit": self.n_entry_after_exit,
            "time_range_start": self.time_range_start,
            "time_range_end": self.time_range_end,
            "median_duration_sec": self.median_duration_sec,
            "violating_indices_sample": list(self.violating_indices_sample),
        }


@dataclass(frozen=True)
class LayerZeroResult:
    entry_consistency: Optional[EntryConsistencyReport]
    mae_mfe_sanity: Optional[MaeMfeSanityReport]
    time_integrity: Optional[TimeIntegrityReport]
    overall_severity: str
    should_halt: bool
    reason_for_halt: Optional[str]
    ran_at: str
    n_input_rows: int

    def to_dict(self) -> dict:
        return {
            "entry_consistency": (
                self.entry_consistency.to_dict()
                if self.entry_consistency else None
            ),
            "mae_mfe_sanity": (
                self.mae_mfe_sanity.to_dict()
                if self.mae_mfe_sanity else None
            ),
            "time_integrity": (
                self.time_integrity.to_dict()
                if self.time_integrity else None
            ),
            "overall_severity": self.overall_severity,
            "should_halt": self.should_halt,
            "reason_for_halt": self.reason_for_halt,
            "ran_at": self.ran_at,
            "n_input_rows": self.n_input_rows,
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    merged_df,
    config: Optional[HygieneConfig] = None,
    output_dir: Optional[Path] = None,
) -> LayerZeroResult:
    """Run all Layer 0 checks on merged_all (all trailing styles).

    Returns a LayerZeroResult. Caller must check `.should_halt`.
    """
    cfg = config or HygieneConfig()
    ran_at = dt.datetime.now(dt.timezone.utc).isoformat()

    if merged_df is None or (
        hasattr(merged_df, "__len__") and len(merged_df) == 0
    ):
        return LayerZeroResult(
            entry_consistency=None,
            mae_mfe_sanity=None,
            time_integrity=None,
            overall_severity=Severity.FAIL.value,
            should_halt=True,
            reason_for_halt="merged_df is empty or None",
            ran_at=ran_at,
            n_input_rows=0,
        )

    df = merged_df if isinstance(merged_df, pd.DataFrame) else pd.DataFrame(merged_df)

    entry_report = _check_entry_consistency(df, cfg)
    mae_report = _check_mae_mfe_sanity(df, cfg)
    time_report = _check_time_integrity(df, cfg)

    overall, halt, reason = _aggregate_severity(
        entry_report, mae_report, time_report, cfg,
    )

    result = LayerZeroResult(
        entry_consistency=entry_report,
        mae_mfe_sanity=mae_report,
        time_integrity=time_report,
        overall_severity=overall,
        should_halt=halt,
        reason_for_halt=reason,
        ran_at=ran_at,
        n_input_rows=len(df),
    )

    if output_dir is not None:
        _write_outputs(result, df, Path(output_dir), cfg)

    return result


# ─── Check 0.1: Entry consistency ────────────────────────────────

def _check_entry_consistency(
    df: pd.DataFrame,
    cfg: HygieneConfig,
) -> EntryConsistencyReport:
    """Verify 3-orders-per-signal design:
      - all expected trailing styles present for each signal
      - entry_time identical across styles
      - entry_price identical (within tolerance) across styles
    """
    if cfg.signal_id_col not in df.columns:
        return EntryConsistencyReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason=f"column {cfg.signal_id_col!r} not present",
            n_signals=0, n_signals_with_all_styles=0,
            n_signals_missing_styles=0,
            n_entry_time_mismatch=0, n_entry_price_mismatch=0,
            missing_styles_breakdown={},
            violating_signal_ids_sample=(),
        )

    valid = df[df[cfg.signal_id_col].notna()].copy()
    # Exclude sentinel "nan" strings
    valid = valid[valid[cfg.signal_id_col].astype(str) != "nan"]

    if valid.empty:
        return EntryConsistencyReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason="all signalIds are NaN",
            n_signals=0, n_signals_with_all_styles=0,
            n_signals_missing_styles=0,
            n_entry_time_mismatch=0, n_entry_price_mismatch=0,
            missing_styles_breakdown={},
            violating_signal_ids_sample=(),
        )

    has_time = cfg.entry_time_col in valid.columns
    has_price = cfg.entry_price_col in valid.columns
    has_style = cfg.style_col in valid.columns
    expected = set(cfg.expected_styles)

    n_signals = 0
    n_complete = 0
    n_missing = 0
    n_time_mismatch = 0
    n_price_mismatch = 0
    missing_breakdown: dict[str, int] = {}
    violating_ids: list = []

    for sig_id, group in valid.groupby(cfg.signal_id_col, sort=False):
        n_signals += 1

        # Style presence check
        if has_style:
            styles_present = set(
                pd.to_numeric(group[cfg.style_col], errors="coerce")
                .dropna().astype(int).tolist()
            )
        else:
            styles_present = set(cfg.expected_styles)

        if expected.issubset(styles_present):
            n_complete += 1
        else:
            n_missing += 1
            missing = tuple(sorted(expected - styles_present))
            key = ",".join(str(s) for s in missing)
            missing_breakdown[key] = missing_breakdown.get(key, 0) + 1

        # Entry time consistency
        if has_time:
            times = pd.to_datetime(
                group[cfg.entry_time_col], errors="coerce"
            ).dropna().unique()
            if len(times) > 1:
                n_time_mismatch += 1
                if len(violating_ids) < cfg.max_violating_ids_in_report:
                    violating_ids.append(str(sig_id))

        # Entry price consistency
        if has_price:
            prices = (
                pd.to_numeric(group[cfg.entry_price_col], errors="coerce")
                .dropna()
                .values.astype(float)
            )
            if len(prices) > 1:
                price_range = float(np.ptp(prices))
                if price_range > cfg.entry_price_tolerance:
                    n_price_mismatch += 1
                    if len(violating_ids) < cfg.max_violating_ids_in_report:
                        violating_ids.append(str(sig_id))

    # Severity
    total_hard = n_time_mismatch + n_price_mismatch
    if total_hard > 0:
        severity = Severity.FAIL
    elif (
        n_signals > 0
        and n_missing / n_signals > cfg.missing_styles_warn_fraction
    ):
        severity = Severity.WARN
    else:
        severity = Severity.PASS

    return EntryConsistencyReport(
        severity=severity.value, skipped=False, skip_reason=None,
        n_signals=n_signals,
        n_signals_with_all_styles=n_complete,
        n_signals_missing_styles=n_missing,
        n_entry_time_mismatch=n_time_mismatch,
        n_entry_price_mismatch=n_price_mismatch,
        missing_styles_breakdown=missing_breakdown,
        violating_signal_ids_sample=tuple(violating_ids),
    )


# ─── Check 0.2: MAE/MFE sanity ───────────────────────────────────

def _check_mae_mfe_sanity(
    df: pd.DataFrame,
    cfg: HygieneConfig,
) -> MaeMfeSanityReport:
    """Check MAE/MFE values are structurally valid."""
    has_mae = cfg.mae_col in df.columns
    has_mfe = cfg.mfe_col in df.columns

    if not has_mae and not has_mfe:
        return MaeMfeSanityReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason=(
                f"neither {cfg.mae_col!r} nor {cfg.mfe_col!r} present"
            ),
            n_total=len(df), n_negative_mae=0, n_negative_mfe=0,
            n_mae_exceeds_cap=0, n_mfe_exceeds_cap=0, n_dead_trades=0,
            n_missing_mae=0, n_missing_mfe=0,
            violating_indices_sample=(),
        )

    n_total = len(df)
    _nan_series = pd.Series(
        [np.nan] * n_total, index=df.index, dtype=float
    )

    mae = (
        pd.to_numeric(df[cfg.mae_col], errors="coerce")
        if has_mae else _nan_series.copy()
    )
    mfe = (
        pd.to_numeric(df[cfg.mfe_col], errors="coerce")
        if has_mfe else _nan_series.copy()
    )

    n_missing_mae = int(mae.isna().sum()) if has_mae else n_total
    n_missing_mfe = int(mfe.isna().sum()) if has_mfe else n_total

    mae_valid = mae.dropna()
    mfe_valid = mfe.dropna()
    cap = cfg.mae_mfe_cap_atr

    n_negative_mae = int((mae_valid < 0).sum())
    n_negative_mfe = int((mfe_valid < 0).sum())
    n_mae_exceeds_cap = int((mae_valid > cap).sum())
    n_mfe_exceeds_cap = int((mfe_valid > cap).sum())

    # Dead trades: both MAE and MFE ~ 0
    if has_mae and has_mfe:
        both = pd.DataFrame({"mae": mae, "mfe": mfe}).dropna()
        n_dead = int(
            (
                (both["mae"].abs() <= cfg.dead_trade_tolerance)
                & (both["mfe"].abs() <= cfg.dead_trade_tolerance)
            ).sum()
        )
    else:
        n_dead = 0

    # Build violation mask for CSV sample
    violating_mask = pd.Series(False, index=df.index)
    if has_mae:
        violating_mask |= (mae < 0).fillna(False)
        violating_mask |= (mae > cap).fillna(False)
    if has_mfe:
        violating_mask |= (mfe < 0).fillna(False)
        violating_mask |= (mfe > cap).fillna(False)
    if has_mae and has_mfe:
        violating_mask |= (
            (mae.abs() <= cfg.dead_trade_tolerance)
            & (mfe.abs() <= cfg.dead_trade_tolerance)
        ).fillna(False)

    sample = tuple(
        violating_mask[violating_mask].index.tolist()[
            : cfg.max_violating_ids_in_report
        ]
    )

    # Severity
    total_hard = (
        n_negative_mae + n_negative_mfe
        + n_mae_exceeds_cap + n_mfe_exceeds_cap
    )
    if total_hard > 0:
        severity = Severity.FAIL
    elif (
        n_total > 0
        and n_dead / n_total > cfg.dead_trade_warn_fraction
    ):
        severity = Severity.WARN
    else:
        severity = Severity.PASS

    return MaeMfeSanityReport(
        severity=severity.value, skipped=False, skip_reason=None,
        n_total=n_total,
        n_negative_mae=n_negative_mae,
        n_negative_mfe=n_negative_mfe,
        n_mae_exceeds_cap=n_mae_exceeds_cap,
        n_mfe_exceeds_cap=n_mfe_exceeds_cap,
        n_dead_trades=n_dead,
        n_missing_mae=n_missing_mae,
        n_missing_mfe=n_missing_mfe,
        violating_indices_sample=sample,
    )


# ─── Check 0.3: Time integrity ───────────────────────────────────

def _check_time_integrity(
    df: pd.DataFrame,
    cfg: HygieneConfig,
) -> TimeIntegrityReport:
    """Check temporal ordering and completeness."""
    has_entry = cfg.entry_time_col in df.columns
    has_exit = cfg.exit_time_col in df.columns
    has_signal_time = cfg.time_col in df.columns

    if not has_entry and not has_signal_time:
        return TimeIntegrityReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason=(
                f"neither {cfg.entry_time_col!r} nor "
                f"{cfg.time_col!r} present"
            ),
            n_total=len(df), n_missing_entry_time=0,
            n_missing_exit_time=0, n_entry_after_exit=0,
            time_range_start=None, time_range_end=None,
            median_duration_sec=None, violating_indices_sample=(),
        )

    n_total = len(df)

    # Prefer entry_time, fall back to signal time column
    if has_entry:
        entry_series = pd.to_datetime(
            df[cfg.entry_time_col], errors="coerce",
        )
    else:
        entry_series = pd.to_datetime(
            df[cfg.time_col], errors="coerce",
        )

    n_missing_entry = int(entry_series.isna().sum())

    n_missing_exit = 0
    n_entry_after_exit = 0
    durations: Optional[pd.Series] = None
    sample: list = []

    if has_exit:
        exit_series = pd.to_datetime(
            df[cfg.exit_time_col], errors="coerce",
        )
        n_missing_exit = int(exit_series.isna().sum())

        both = pd.DataFrame(
            {"e": entry_series, "x": exit_series},
        ).dropna()
        if not both.empty:
            dur = (both["x"] - both["e"]).dt.total_seconds()
            bad = dur < 0
            n_entry_after_exit = int(bad.sum())
            if n_entry_after_exit > 0:
                sample = both[bad].index.tolist()[
                    : cfg.max_violating_ids_in_report
                ]
            durations = dur

    # Time range from valid entry times
    valid_entry = entry_series.dropna()
    time_range_start = str(valid_entry.min()) if not valid_entry.empty else None
    time_range_end = str(valid_entry.max()) if not valid_entry.empty else None

    median_duration = (
        float(durations.median())
        if durations is not None and not durations.empty
        else None
    )

    # Severity
    if n_entry_after_exit > 0:
        severity = Severity.FAIL
    elif (
        n_total > 0
        and n_missing_entry / n_total > cfg.missing_entry_time_warn_fraction
    ):
        severity = Severity.WARN
    else:
        severity = Severity.PASS

    return TimeIntegrityReport(
        severity=severity.value, skipped=False, skip_reason=None,
        n_total=n_total,
        n_missing_entry_time=n_missing_entry,
        n_missing_exit_time=n_missing_exit,
        n_entry_after_exit=n_entry_after_exit,
        time_range_start=time_range_start,
        time_range_end=time_range_end,
        median_duration_sec=median_duration,
        violating_indices_sample=tuple(sample),
    )


# ─── Aggregation ─────────────────────────────────────────────────

def _aggregate_severity(
    entry: Optional[EntryConsistencyReport],
    mae: Optional[MaeMfeSanityReport],
    time: Optional[TimeIntegrityReport],
    cfg: HygieneConfig,
) -> tuple[str, bool, Optional[str]]:
    severities = [r.severity for r in (entry, mae, time) if r is not None]

    if Severity.FAIL.value in severities:
        overall = Severity.FAIL.value
    elif Severity.WARN.value in severities:
        overall = Severity.WARN.value
    else:
        overall = Severity.PASS.value

    halt = False
    reason = None

    if (
        cfg.halt_on_entry_inconsistency
        and entry is not None
        and entry.severity == Severity.FAIL.value
    ):
        halt = True
        reason = (
            f"entry inconsistency: "
            f"{entry.n_entry_time_mismatch} time mismatches, "
            f"{entry.n_entry_price_mismatch} price mismatches"
        )
    elif (
        cfg.halt_on_mae_mfe_violation
        and mae is not None
        and mae.severity == Severity.FAIL.value
    ):
        halt = True
        reason = (
            f"MAE/MFE violations: "
            f"{mae.n_negative_mae} neg MAE, "
            f"{mae.n_negative_mfe} neg MFE, "
            f"{mae.n_mae_exceeds_cap} MAE>cap, "
            f"{mae.n_mfe_exceeds_cap} MFE>cap"
        )
    elif (
        cfg.halt_on_time_integrity
        and time is not None
        and time.severity == Severity.FAIL.value
    ):
        halt = True
        reason = (
            f"time integrity: {time.n_entry_after_exit} trades "
            f"with entry_time > exit_time"
        )

    return overall, halt, reason


# ─── Output helpers ──────────────────────────────────────────────

def _write_outputs(
    result: LayerZeroResult,
    df: pd.DataFrame,
    output_dir: Path,
    cfg: HygieneConfig,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with (output_dir / "layer_zero_summary.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.to_dict(), f, indent=2, default=str)

    if result.entry_consistency and not result.entry_consistency.skipped:
        _write_entry_violations(df, result.entry_consistency, output_dir, cfg)

    if result.mae_mfe_sanity and not result.mae_mfe_sanity.skipped:
        _write_mae_mfe_violations(df, result.mae_mfe_sanity, output_dir, cfg)

    if result.time_integrity and not result.time_integrity.skipped:
        _write_time_violations(df, result.time_integrity, output_dir, cfg)


def _write_entry_violations(
    df: pd.DataFrame,
    report: EntryConsistencyReport,
    output_dir: Path,
    cfg: HygieneConfig,
) -> None:
    if report.n_entry_time_mismatch + report.n_entry_price_mismatch == 0:
        return

    valid = df[df[cfg.signal_id_col].notna()]
    rows = []
    for sig_id, group in valid.groupby(cfg.signal_id_col, sort=False):
        if len(rows) >= cfg.max_samples_in_csv:
            break
        has_t = cfg.entry_time_col in group.columns
        has_p = cfg.entry_price_col in group.columns
        time_mismatch = (
            pd.to_datetime(group[cfg.entry_time_col], errors="coerce")
            .dropna().nunique() > 1
            if has_t else False
        )
        price_mismatch = False
        if has_p:
            prices = (
                pd.to_numeric(group[cfg.entry_price_col], errors="coerce")
                .dropna().values.astype(float)
            )
            price_mismatch = (
                len(prices) > 1
                and float(np.ptp(prices)) > cfg.entry_price_tolerance
            )
        if time_mismatch or price_mismatch:
            rows.append({
                "signal_id": sig_id,
                "n_trades": len(group),
                "time_mismatch": time_mismatch,
                "price_mismatch": price_mismatch,
            })
    if rows:
        pd.DataFrame(rows).to_csv(
            output_dir / "entry_consistency_violations.csv", index=False,
        )


def _write_mae_mfe_violations(
    df: pd.DataFrame,
    report: MaeMfeSanityReport,
    output_dir: Path,
    cfg: HygieneConfig,
) -> None:
    has_mae = cfg.mae_col in df.columns
    has_mfe = cfg.mfe_col in df.columns
    if not (has_mae or has_mfe):
        return

    mae = (
        pd.to_numeric(df[cfg.mae_col], errors="coerce")
        if has_mae
        else pd.Series([np.nan] * len(df), index=df.index, dtype=float)
    )
    mfe = (
        pd.to_numeric(df[cfg.mfe_col], errors="coerce")
        if has_mfe
        else pd.Series([np.nan] * len(df), index=df.index, dtype=float)
    )
    cap = cfg.mae_mfe_cap_atr

    violation_types = pd.Series("ok", index=df.index)
    if has_mae:
        violation_types = violation_types.where(~(mae < 0).fillna(False), "negative_mae")
        violation_types = violation_types.where(~(mae > cap).fillna(False), "mae_exceeds_cap")
    if has_mfe:
        violation_types = violation_types.where(~(mfe < 0).fillna(False), "negative_mfe")
        violation_types = violation_types.where(~(mfe > cap).fillna(False), "mfe_exceeds_cap")
    if has_mae and has_mfe:
        dead = (
            (mae.abs() <= cfg.dead_trade_tolerance)
            & (mfe.abs() <= cfg.dead_trade_tolerance)
        ).fillna(False)
        violation_types = violation_types.where(~dead, "dead_trade")

    bad = violation_types != "ok"
    if not bad.any():
        return

    sample = df[bad].copy()
    sample["_violation"] = violation_types[bad].values
    if has_mae:
        sample["_mae"] = mae[bad].values
    if has_mfe:
        sample["_mfe"] = mfe[bad].values
    sample.head(cfg.max_samples_in_csv).to_csv(
        output_dir / "mae_mfe_violations.csv", index=False,
    )


def _write_time_violations(
    df: pd.DataFrame,
    report: TimeIntegrityReport,
    output_dir: Path,
    cfg: HygieneConfig,
) -> None:
    if report.n_entry_after_exit == 0:
        return
    has_exit = cfg.exit_time_col in df.columns
    if not has_exit:
        return

    entry_series = None
    if cfg.entry_time_col in df.columns:
        entry_series = pd.to_datetime(df[cfg.entry_time_col], errors="coerce")
    elif cfg.time_col in df.columns:
        entry_series = pd.to_datetime(df[cfg.time_col], errors="coerce")
    if entry_series is None:
        return

    exit_series = pd.to_datetime(df[cfg.exit_time_col], errors="coerce")
    bad = (
        (exit_series < entry_series)
        & exit_series.notna()
        & entry_series.notna()
    )
    if not bad.any():
        return

    sample = df[bad].copy()
    sample["_entry_time"] = entry_series[bad].values
    sample["_exit_time"] = exit_series[bad].values
    sample["_duration_sec"] = (
        exit_series[bad] - entry_series[bad]
    ).dt.total_seconds().values
    sample.head(cfg.max_samples_in_csv).to_csv(
        output_dir / "time_integrity_violations.csv", index=False,
    )
