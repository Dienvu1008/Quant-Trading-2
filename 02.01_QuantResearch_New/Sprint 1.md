# Sprint 1 — Layer 0: Data Hygiene

> **v3 changes (từ SPECIFICATION.md v3):**
> - L0 bổ sung: `merged_all` phải bao gồm cả 3 trailing styles (không chỉ production style), vì L10a cần cross-style triplet consistency check. [Fix #1 — L10a cần 3-style input]
> - L1 bổ sung: sau feature availability check, tính và log **`n_total_hypotheses`** vào `run_meta.json` cho cả 3 pools (hard_gate, soft_gate, regime_block). `n_total_bad` sẽ được L10a tính riêng. Giá trị này **frozen** — không được thay đổi sau khi L4 bắt đầu. [Fix #3]
>   ```python
>   n_groups = count_groups(dev, by=["symbol", "setupType"])
>   n_features = len(available_features)
>   run_meta["n_total_hypotheses"] = {
>       "hard_gate": n_features * n_groups,
>       "soft_gate": n_features * n_groups,
>       "regime_block": len(unique_regimes) * n_groups,
>       # bad_entry: tính trong L10a, logged lại vào run_meta
>   }
>   ```
> - L1 bổ sung: split cả `dev_all_styles` (3-style subset) tại cùng `split_time` để L10a có input đúng. [Fix #2 — L10a cần 3-style]
> - L2 bổ sung: `InteractionTransformer.fit_transform()` phải transform cả `dev_all_styles` (không chỉ `dev`) để L10a nhận được interaction features. [Fix #2]

Deliverables:
- `layers/L0_hygiene.py` — 3 checks + report types
- `tests/test_L0_hygiene.py` — ~24 tests với synthetic bugs injected
- Output: structured CSV + JSON reports

Nguyên tắc:
- Chạy **trước** dev/holdout split (trên `merged_all` — 3 styles)
- Mỗi check ra một `Report` immutable
- `FAIL` → halt pipeline; `WARN` → informational
- Column-agnostic: missing columns → skip gracefully

---

## `vp_analysis/layers/__init__.py`

```python
"""Analysis layers. Each module implements one layer of the pipeline."""
```

## `vp_analysis/layers/L0_hygiene.py`

```python
"""Layer 0 — Data Hygiene.

Runs BEFORE the dev/holdout split. Purpose:
  - Detect data-collection bugs that would silently corrupt every
    downstream analysis.
  - Verify the 3-orders-per-signal design held (same entry_time and
    entry_price across trail styles for each signal).
  - Verify MAE/MFE values are in a plausible range.
  - Verify temporal integrity (entry ≤ exit, no NaT).

Design:
  - Every check returns an immutable Report dataclass.
  - Severity: PASS | WARN | FAIL.
  - FAIL halts the pipeline (caller checks `should_halt`).
  - WARN is informational, does not halt.
  - Missing columns → check is skipped, not failed.
  - This layer is deliberately broad — it does not try to detect
    subtle bugs, only structural integrity.

Reports are exported to CSV (violations sample) and JSON (summary).
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
    """Column names and thresholds. All optional — defaults match the
    columns produced by the EA's data collector."""

    # Column names
    signal_id_col: str = "signalId"
    style_col: str = "trailStyle"
    entry_time_col: str = "entryTime"
    entry_price_col: str = "entryPrice"
    exit_time_col: str = "exitTime"
    mae_col: str = "maeATR"
    mfe_col: str = "mfeATR"
    time_col: str = "time"           # signal/funnel time

    # Expected trail styles (same entry, different exit policy)
    expected_styles: tuple = (-1, 0, 1)

    # Tolerances
    entry_price_tolerance: float = 1e-6     # absolute price units
    mae_mfe_cap_atr: float = 10.0            # MAE/MFE in ATR — cap
    dead_trade_tolerance: float = 1e-9       # both MAE and MFE ~ 0

    # Halt policy
    halt_on_entry_inconsistency: bool = True
    halt_on_mae_mfe_violation: bool = True
    halt_on_time_integrity: bool = True

    # Output
    max_samples_in_csv: int = 1000
    max_violating_ids_in_report: int = 50


# ─── Reports ─────────────────────────────────────────────────────

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
    missing_styles_breakdown: dict       # str(styles_tuple) -> count
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
            "violating_signal_ids_sample": list(self.violating_signal_ids_sample),
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
    merged_df: pd.DataFrame,
    config: Optional[HygieneConfig] = None,
    output_dir: Optional[Path] = None,
) -> LayerZeroResult:
    """Run all Layer 0 checks.

    Returns a LayerZeroResult. Caller must check `.should_halt` and stop
    the pipeline if True.
    """
    cfg = config or HygieneConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if merged_df is None or len(merged_df) == 0:
        return LayerZeroResult(
            entry_consistency=None, mae_mfe_sanity=None,
            time_integrity=None,
            overall_severity=Severity.FAIL.value,
            should_halt=True,
            reason_for_halt="merged_df is empty or None",
            ran_at=ran_at, n_input_rows=0,
        )

    entry_report = _check_entry_consistency(merged_df, cfg)
    mae_report = _check_mae_mfe_sanity(merged_df, cfg)
    time_report = _check_time_integrity(merged_df, cfg)

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
        n_input_rows=len(merged_df),
    )

    if output_dir is not None:
        _write_outputs(result, merged_df, Path(output_dir), cfg)

    return result


# ─── Check 0.1: Entry consistency ────────────────────────────────

def _check_entry_consistency(
    df: pd.DataFrame, cfg: HygieneConfig,
) -> EntryConsistencyReport:
    """Group rows by signalId. For each signal, verify:
      - all expected trail styles are present
      - entry_time is identical across styles
      - entry_price is identical (within tolerance) across styles
    """
    if cfg.signal_id_col not in df.columns:
        return EntryConsistencyReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason=f"column {cfg.signal_id_col!r} not present",
            n_signals=0, n_signals_with_all_styles=0,
            n_signals_missing_styles=0,
            n_entry_time_mismatch=0, n_entry_price_mismatch=0,
            missing_styles_breakdown={}, violating_signal_ids_sample=(),
        )

    valid = df[df[cfg.signal_id_col].notna()]
    if valid.empty:
        return EntryConsistencyReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason="all signalIds are NaN",
            n_signals=0, n_signals_with_all_styles=0,
            n_signals_missing_styles=0,
            n_entry_time_mismatch=0, n_entry_price_mismatch=0,
            missing_styles_breakdown={}, violating_signal_ids_sample=(),
        )

    has_time = cfg.entry_time_col in valid.columns
    has_price = cfg.entry_price_col in valid.columns
    has_style = cfg.style_col in valid.columns

    n_signals = 0
    n_complete = 0
    n_missing = 0
    n_time_mismatch = 0
    n_price_mismatch = 0
    missing_breakdown: dict[str, int] = {}
    violating_ids: list = []

    for sig_id, group in valid.groupby(cfg.signal_id_col, sort=False):
        n_signals += 1

        # Style presence
        if has_style:
            styles_present = set(
                group[cfg.style_col].dropna().unique()
            )
        else:
            styles_present = set(cfg.expected_styles)
        expected = set(cfg.expected_styles)
        if expected.issubset(styles_present):
            n_complete += 1
        else:
            n_missing += 1
            missing = tuple(sorted(expected - styles_present))
            key = ",".join(str(s) for s in missing)
            missing_breakdown[key] = missing_breakdown.get(key, 0) + 1

        # Entry time consistency
        if has_time:
            times = group[cfg.entry_time_col].dropna().unique()
            if len(times) > 1:
                n_time_mismatch += 1
                if len(violating_ids) < cfg.max_violating_ids_in_report:
                    violating_ids.append(sig_id)

        # Entry price consistency
        if has_price:
            prices = group[cfg.entry_price_col].dropna().values.astype(float)
            if len(prices) > 1:
                price_range = float(np.ptp(prices))
                if price_range > cfg.entry_price_tolerance:
                    n_price_mismatch += 1
                    if len(violating_ids) < cfg.max_violating_ids_in_report:
                        violating_ids.append(sig_id)

    total_hard = n_time_mismatch + n_price_mismatch
    if total_hard > 0:
        severity = Severity.FAIL
    elif n_signals > 0 and n_missing > n_signals * 0.10:
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
    df: pd.DataFrame, cfg: HygieneConfig,
) -> MaeMfeSanityReport:
    """Check MAE/MFE values are structurally valid.

    Rules:
      - MAE >= 0, MFE >= 0 (excursions are magnitudes)
      - MAE <= cap, MFE <= cap (cap in ATR units)
      - not both MAE ~ 0 AND MFE ~ 0 (dead trade)
    """
    has_mae = cfg.mae_col in df.columns
    has_mfe = cfg.mfe_col in df.columns

    if not has_mae and not has_mfe:
        return MaeMfeSanityReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason=f"neither {cfg.mae_col!r} nor {cfg.mfe_col!r} present",
            n_total=len(df), n_negative_mae=0, n_negative_mfe=0,
            n_mae_exceeds_cap=0, n_mfe_exceeds_cap=0, n_dead_trades=0,
            n_missing_mae=0, n_missing_mfe=0,
            violating_indices_sample=(),
        )

    n_total = len(df)
    mae = (
        pd.to_numeric(df[cfg.mae_col], errors="coerce")
        if has_mae else pd.Series([np.nan] * n_total, index=df.index)
    )
    mfe = (
        pd.to_numeric(df[cfg.mfe_col], errors="coerce")
        if has_mfe else pd.Series([np.nan] * n_total, index=df.index)
    )

    n_missing_mae = int(mae.isna().sum()) if has_mae else n_total
    n_missing_mfe = int(mfe.isna().sum()) if has_mfe else n_total

    mae_valid = mae.dropna()
    mfe_valid = mfe.dropna()

    n_negative_mae = int((mae_valid < 0).sum())
    n_negative_mfe = int((mfe_valid < 0).sum())
    n_mae_exceeds_cap = int((mae_valid > cfg.mae_mfe_cap_atr).sum())
    n_mfe_exceeds_cap = int((mfe_valid > cfg.mfe_mfe_cap_atr).sum() if False else (mfe_valid > cfg.mae_mfe_cap_atr).sum())

    # Dead trades: both MAE and MFE near zero (only when both present)
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

    # Collect sample of violating indices
    violating_mask = pd.Series([False] * n_total, index=df.index)
    if has_mae:
        violating_mask |= (mae < 0)
        violating_mask |= (mae > cfg.mae_mfe_cap_atr)
    if has_mfe:
        violating_mask |= (mfe < 0)
        violating_mask |= (mfe > cfg.mae_mfe_cap_atr)
    if has_mae and has_mfe:
        violating_mask |= (
            (mae.abs() <= cfg.dead_trade_tolerance)
            & (mfe.abs() <= cfg.dead_trade_tolerance)
        )
    violating_indices = violating_mask[violating_mask].index.tolist()
    sample = tuple(violating_indices[:cfg.max_violating_ids_in_report])

    # Severity
    total_hard = (
        n_negative_mae + n_negative_mfe
        + n_mae_exceeds_cap + n_mfe_exceeds_cap
    )
    if total_hard > 0:
        severity = Severity.FAIL
    elif n_dead > n_total * 0.01:
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
    df: pd.DataFrame, cfg: HygieneConfig,
) -> TimeIntegrityReport:
    """Check temporal ordering and completeness.

    Rules:
      - entry_time must be present (non-NaT)
      - entry_time <= exit_time where both present
      - report duration stats
    """
    has_entry = cfg.entry_time_col in df.columns
    has_exit = cfg.exit_time_col in df.columns
    has_signal_time = cfg.time_col in df.columns

    if not has_entry and not has_signal_time:
        return TimeIntegrityReport(
            severity=Severity.WARN.value, skipped=True,
            skip_reason=(
                f"neither {cfg.entry_time_col!r} nor {cfg.time_col!r} "
                f"present"
            ),
            n_total=len(df), n_missing_entry_time=0,
            n_missing_exit_time=0, n_entry_after_exit=0,
            time_range_start=None, time_range_end=None,
            median_duration_sec=None, violating_indices_sample=(),
        )

    n_total = len(df)

    # Prefer entry_time, fall back to signal time
    entry_series = None
    if has_entry:
        entry_series = pd.to_datetime(
            df[cfg.entry_time_col], errors="coerce",
        )
    elif has_signal_time:
        entry_series = pd.to_datetime(
            df[cfg.time_col], errors="coerce",
        )

    n_missing_entry = int(entry_series.isna().sum())

    n_missing_exit = 0
    n_entry_after_exit = 0
    durations = None
    sample: list = []

    if has_exit:
        exit_series = pd.to_datetime(
            df[cfg.exit_time_col], errors="coerce",
        )
        n_missing_exit = int(exit_series.isna().sum())

        both = pd.DataFrame({
            "e": entry_series, "x": exit_series,
        }).dropna()
        if not both.empty:
            durations = (both["x"] - both["e"]).dt.total_seconds()
            bad = durations < 0
            n_entry_after_exit = int(bad.sum())
            if n_entry_after_exit > 0:
                sample = tuple(
                    durations[bad].index[:cfg.max_violating_ids_in_report]
                    .tolist()
                )

    # Time range
    valid_entry = entry_series.dropna()
    time_range_start = (
        str(valid_entry.min()) if not valid_entry.empty else None
    )
    time_range_end = (
        str(valid_entry.max()) if not valid_entry.empty else None
    )

    median_duration = (
        float(durations.median())
        if durations is not None and not durations.empty else None
    )

    # Severity
    if n_entry_after_exit > 0:
        severity = Severity.FAIL
    elif n_missing_entry > n_total * 0.01:
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
        violating_indices_sample=sample,
    )


# ─── Aggregation ─────────────────────────────────────────────────

def _aggregate_severity(
    entry: Optional[EntryConsistencyReport],
    mae: Optional[MaeMfeSanityReport],
    time: Optional[TimeIntegrityReport],
    cfg: HygieneConfig,
) -> tuple[str, bool, Optional[str]]:
    """Combine per-check severities into overall severity and halt decision."""
    severities = []
    if entry is not None:
        severities.append(entry.severity)
    if mae is not None:
        severities.append(mae.severity)
    if time is not None:
        severities.append(time.severity)

    if Severity.FAIL.value in severities:
        overall = Severity.FAIL.value
    elif Severity.WARN.value in severities:
        overall = Severity.WARN.value
    else:
        overall = Severity.PASS.value

    # Halt decision
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


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(
    result: LayerZeroResult,
    df: pd.DataFrame,
    output_dir: Path,
    cfg: HygieneConfig,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    # Summary JSON
    with (output_dir / "layer_zero_summary.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.to_dict(), f, indent=2, default=str)

    # Entry consistency violation sample
    if result.entry_consistency and not result.entry_consistency.skipped:
        _write_entry_violations(
            df, result.entry_consistency, output_dir, cfg,
        )

    # MAE/MFE violation sample
    if result.mae_mfe_sanity and not result.mae_mfe_sanity.skipped:
        _write_mae_mfe_violations(
            df, result.mae_mfe_sanity, output_dir, cfg,
        )

    # Time integrity violation sample
    if result.time_integrity and not result.time_integrity.skipped:
        _write_time_violations(
            df, result.time_integrity, output_dir, cfg,
        )


def _write_entry_violations(
    df: pd.DataFrame,
    report: EntryConsistencyReport,
    output_dir: Path,
    cfg: HygieneConfig,
) -> None:
    if report.n_entry_time_mismatch + report.n_entry_price_mismatch == 0:
        return

    # Re-derive violating signals (report only keeps a sample)
    valid = df[df[cfg.signal_id_col].notna()]
    rows = []
    for sig_id, group in valid.groupby(cfg.signal_id_col, sort=False):
        if len(rows) >= cfg.max_samples_in_csv:
            break
        has_time = cfg.entry_time_col in group.columns
        has_price = cfg.entry_price_col in group.columns
        time_mismatch = False
        price_mismatch = False
        if has_time:
            time_mismatch = group[cfg.entry_time_col].dropna().nunique() > 1
        if has_price:
            prices = group[cfg.entry_price_col].dropna().values.astype(float)
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
                "entry_times": (
                    group[cfg.entry_time_col].dropna().unique().tolist()
                    if has_time else []
                ),
                "entry_prices": (
                    group[cfg.entry_price_col].dropna().unique().tolist()
                    if has_price else []
                ),
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
        if has_mae else pd.Series([np.nan] * len(df), index=df.index)
    )
    mfe = (
        pd.to_numeric(df[cfg.mfe_col], errors="coerce")
        if has_mfe else pd.Series([np.nan] * len(df), index=df.index)
    )

    violation_types = pd.Series(["ok"] * len(df), index=df.index)
    if has_mae:
        violation_types = violation_types.mask(
            mae < 0, "negative_mae"
        ).mask(
            mae > cfg.mae_mfe_cap_atr,
            "mae_exceeds_cap",
            errors="ignore",
        )
    if has_mfe:
        violation_types = violation_types.mask(
            mfe < 0, "negative_mfe"
        ).mask(
            mfe > cfg.mae_mfe_cap_atr,
            "mfe_exceeds_cap",
            errors="ignore",
        )
    if has_mae and has_mfe:
        dead = (
            (mae.abs() <= cfg.dead_trade_tolerance)
            & (mfe.abs() <= cfg.dead_trade_tolerance)
        )
        violation_types = violation_types.mask(dead, "dead_trade")

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
    bad = (exit_series < entry_series) & exit_series.notna() & entry_series.notna()
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
```

---

## Tests

## `vp_analysis/tests/test_L0_hygiene.py`

```python
"""Tests for Layer 0 — Data Hygiene.

Tests are split into two groups:
  1. Clean data → PASS (no false positives)
  2. Injected bugs → correct detection + severity
"""
from __future__ import annotations

import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.layers.L0_hygiene import (
    HygieneConfig,
    LayerZeroResult,
    Severity,
    run,
)


# ─── Fixtures ────────────────────────────────────────────────────

def _make_clean_df(n_signals: int = 50, seed: int = 42) -> pd.DataFrame:
    """Build a clean 3-orders-per-signal dataset."""
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(n_signals):
        sig_id = f"SIG-{i:05d}"
        entry_time = pd.Timestamp("2024-01-01") + pd.Timedelta(hours=i)
        exit_time = entry_time + pd.Timedelta(minutes=30)
        entry_price = 2000.0 + rng.normal(0, 10)
        for style in (-1, 0, 1):
            rows.append({
                "signalId": sig_id,
                "trailStyle": style,
                "entryTime": entry_time,
                "exitTime": exit_time,
                "entryPrice": entry_price,
                "maeATR": float(abs(rng.normal(0.8, 0.3))),
                "mfeATR": float(abs(rng.normal(1.5, 0.5))),
                "time": entry_time,
                "profitUSD": float(rng.normal(0.1, 1.0)),
                "symbol": "XAUUSD",
                "setupType": "BOS",
            })
    return pd.DataFrame(rows)


# ═══════════════════════════════════════════════════════════════════
# GROUP 1 — Clean data
# ═══════════════════════════════════════════════════════════════════

def test_clean_data_overall_pass():
    df = _make_clean_df()
    result = run(df)
    assert result.overall_severity == Severity.PASS.value
    assert not result.should_halt


def test_clean_data_entry_consistency_pass():
    df = _make_clean_df()
    result = run(df)
    ec = result.entry_consistency
    assert ec.severity == Severity.PASS.value
    assert ec.n_entry_time_mismatch == 0
    assert ec.n_entry_price_mismatch == 0
    assert ec.n_signals_with_all_styles == 50


def test_clean_data_mae_mfe_pass():
    df = _make_clean_df()
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.severity == Severity.PASS.value
    assert ms.n_negative_mae == 0
    assert ms.n_negative_mfe == 0


def test_clean_data_time_integrity_pass():
    df = _make_clean_df()
    result = run(df)
    ti = result.time_integrity
    assert ti.severity == Severity.PASS.value
    assert ti.n_entry_after_exit == 0
    assert ti.n_missing_entry_time == 0


def test_empty_dataframe_halts():
    result = run(pd.DataFrame())
    assert result.should_halt
    assert "empty" in result.reason_for_halt.lower()


def test_none_input_halts():
    result = run(None)  # type: ignore
    assert result.should_halt


# ═══════════════════════════════════════════════════════════════════
# GROUP 2 — Injected bugs
# ═══════════════════════════════════════════════════════════════════

# ─── Entry consistency violations ────────────────────────────────

def test_entry_time_mismatch_detected():
    df = _make_clean_df()
    # Corrupt one signal's entryTime for a single style
    mask = (df["signalId"] == "SIG-00000") & (df["trailStyle"] == 1)
    df.loc[mask, "entryTime"] = pd.Timestamp("2024-01-02")

    result = run(df)
    ec = result.entry_consistency
    assert ec.severity == Severity.FAIL.value
    assert ec.n_entry_time_mismatch == 1
    assert result.should_halt
    assert "entry inconsistency" in result.reason_for_halt.lower()


def test_entry_price_mismatch_detected():
    df = _make_clean_df()
    mask = (df["signalId"] == "SIG-00001") & (df["trailStyle"] == 0)
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"] + 5.0

    result = run(df)
    ec = result.entry_consistency
    assert ec.severity == Severity.FAIL.value
    assert ec.n_entry_price_mismatch == 1
    assert result.should_halt


def test_entry_price_tiny_difference_within_tolerance():
    df = _make_clean_df()
    # Change by 1e-9, below default tolerance of 1e-6
    mask = (df["signalId"] == "SIG-00002") & (df["trailStyle"] == 1)
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"] + 1e-9
    result = run(df)
    assert result.entry_consistency.severity == Severity.PASS.value


def test_missing_styles_warn():
    df = _make_clean_df()
    # Remove 10 signals' worth of style=1 rows (>10% → WARN)
    drop_sigs = [f"SIG-{i:05d}" for i in range(10)]
    df_filtered = df[~(
        (df["signalId"].isin(drop_sigs)) & (df["trailStyle"] == 1)
    )].reset_index(drop=True)

    result = run(df_filtered)
    ec = result.entry_consistency
    assert ec.n_signals_missing_styles == 10
    assert ec.severity == Severity.WARN.value
    # WARN does not halt
    assert not result.should_halt


def test_missing_signal_id_column_skips():
    df = _make_clean_df().drop(columns=["signalId"])
    result = run(df)
    ec = result.entry_consistency
    assert ec.skipped
    assert "signalId" in ec.skip_reason


def test_all_nan_signal_id_skips():
    df = _make_clean_df()
    df["signalId"] = np.nan
    result = run(df)
    ec = result.entry_consistency
    assert ec.skipped
    assert "NaN" in ec.skip_reason


# ─── MAE/MFE violations ──────────────────────────────────────────

def test_negative_mae_detected():
    df = _make_clean_df()
    df.loc[10, "maeATR"] = -0.5
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.severity == Severity.FAIL.value
    assert ms.n_negative_mae == 1
    assert result.should_halt
    assert "MAE/MFE" in result.reason_for_halt


def test_negative_mfe_detected():
    df = _make_clean_df()
    df.loc[20, "mfeATR"] = -1.0
    result = run(df)
    assert result.mae_mfe_sanity.n_negative_mfe == 1
    assert result.should_halt


def test_mae_exceeds_cap_detected():
    df = _make_clean_df()
    df.loc[15, "maeATR"] = 50.0  # >> cap=10
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.n_mae_exceeds_cap == 1
    assert ms.severity == Severity.FAIL.value


def test_mfe_exceeds_cap_detected():
    df = _make_clean_df()
    df.loc[25, "mfeATR"] = 100.0
    result = run(df)
    assert result.mae_mfe_sanity.n_mfe_exceeds_cap == 1


def test_custom_cap_respected():
    df = _make_clean_df()
    # Set one MFE to 8.0 — under default cap 10, but over custom cap 5
    df.loc[5, "mfeATR"] = 8.0
    cfg = HygieneConfig(mae_mfe_cap_atr=5.0)
    result = run(df, config=cfg)
    assert result.mae_mfe_sanity.n_mfe_exceeds_cap == 1


def test_dead_trades_detected_as_warn():
    df = _make_clean_df()
    # Make 3 trades have both MAE and MFE = 0 (out of 150 rows = 2% > 1%)
    df.loc[[0, 1, 2], "maeATR"] = 0.0
    df.loc[[0, 1, 2], "mfeATR"] = 0.0
    result = run(df)
    assert result.mae_mfe_sanity.n_dead_trades == 3
    assert result.mae_mfe_sanity.severity == Severity.WARN.value


def test_missing_mae_mfe_columns_skips():
    df = _make_clean_df().drop(columns=["maeATR", "mfeATR"])
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.skipped
    assert "maeATR" in ms.skip_reason


# ─── Time integrity violations ───────────────────────────────────

def test_entry_after_exit_detected():
    df = _make_clean_df()
    # Set exit before entry for one row
    mask = df["signalId"] == "SIG-00003"
    df.loc[mask, "exitTime"] = pd.Timestamp("2020-01-01")

    result = run(df)
    ti = result.time_integrity
    # 3 rows share the same signal — all 3 will have entry > exit
    assert ti.n_entry_after_exit == 3
    assert ti.severity == Severity.FAIL.value
    assert result.should_halt
    assert "time integrity" in result.reason_for_halt


def test_missing_entry_time_warns():
    df = _make_clean_df()
    # Remove 5 entry_times (out of 150 = 3.3% > 1%)
    df.loc[0:4, "entryTime"] = pd.NaT
    result = run(df)
    ti = result.time_integrity
    assert ti.n_missing_entry_time == 5
    assert ti.severity == Severity.WARN.value
    # WARN does not halt
    assert not result.should_halt


def test_missing_both_time_columns_skips():
    df = _make_clean_df().drop(columns=["entryTime", "time"])
    result = run(df)
    ti = result.time_integrity
    assert ti.skipped


def test_time_range_recorded():
    df = _make_clean_df()
    result = run(df)
    ti = result.time_integrity
    assert ti.time_range_start is not None
    assert ti.time_range_end is not None
    assert ti.time_range_start < ti.time_range_end


def test_median_duration_computed():
    df = _make_clean_df()  # 30-min duration for all
    result = run(df)
    assert result.time_integrity.median_duration_sec == pytest.approx(1800.0)


# ─── Halt behavior ───────────────────────────────────────────────

def test_halt_disabled_for_entry_consistency():
    df = _make_clean_df()
    mask = (df["signalId"] == "SIG-00000") & (df["trailStyle"] == 1)
    df.loc[mask, "entryTime"] = pd.Timestamp("2024-01-02")

    cfg = HygieneConfig(halt_on_entry_inconsistency=False)
    result = run(df, config=cfg)
    assert result.overall_severity == Severity.FAIL.value
    assert not result.should_halt


def test_halt_disabled_for_mae_mfe():
    df = _make_clean_df()
    df.loc[10, "maeATR"] = -1.0

    cfg = HygieneConfig(halt_on_mae_mfe_violation=False)
    result = run(df, config=cfg)
    assert not result.should_halt


# ─── Output files ────────────────────────────────────────────────

def test_output_files_written(tmp_path):
    df = _make_clean_df()
    mask = (df["signalId"] == "SIG-00000") & (df["trailStyle"] == 1)
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"] + 5.0

    result = run(df, output_dir=tmp_path)

    assert (tmp_path / "layer_zero_summary.json").exists()
    assert (tmp_path / "entry_consistency_violations.csv").exists()

    with (tmp_path / "layer_zero_summary.json").open() as f:
        payload = json.load(f)
    assert payload["overall_severity"] == Severity.FAIL.value
    assert payload["entry_consistency"]["n_entry_price_mismatch"] == 1


def test_output_summary_clean_data(tmp_path):
    df = _make_clean_df()
    run(df, output_dir=tmp_path)
    with (tmp_path / "layer_zero_summary.json").open() as f:
        payload = json.load(f)
    assert payload["overall_severity"] == Severity.PASS.value
    assert payload["should_halt"] is False
    assert payload["n_input_rows"] == 150


def test_no_violation_csv_when_clean(tmp_path):
    df = _make_clean_df()
    run(df, output_dir=tmp_path)
    # No violation files should exist for clean data
    assert not (tmp_path / "entry_consistency_violations.csv").exists()
    assert not (tmp_path / "mae_mfe_violations.csv").exists()
    assert not (tmp_path / "time_integrity_violations.csv").exists()


def test_mae_mfe_violations_csv_written(tmp_path):
    df = _make_clean_df()
    df.loc[10, "maeATR"] = -1.0
    run(df, output_dir=tmp_path)
    assert (tmp_path / "mae_mfe_violations.csv").exists()


# ─── Serialization ───────────────────────────────────────────────

def test_result_to_dict_roundtrippable():
    df = _make_clean_df()
    result = run(df)
    d = result.to_dict()
    serialized = json.dumps(d, default=str)
    assert "overall_severity" in serialized
    assert d["overall_severity"] == "PASS"


def test_result_immutable():
    import dataclasses
    df = _make_clean_df()
    result = run(df)
    with pytest.raises(dataclasses.FrozenInstanceError):
        result.overall_severity = "FAIL"
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L0_hygiene.py -v
```

Expected output (khoảng):

```text
test_L0_hygiene.py
  Group 1 — Clean data                   6 passed
  Group 2 — Entry consistency            7 passed
  Group 2 — MAE/MFE                      6 passed
  Group 2 — Time integrity               5 passed
  Group 2 — Halt behavior                2 passed
  Group 2 — Output files                 4 passed
  Group 2 — Serialization                2 passed
  ────────────────────────────────────────────────
  Total                                 32 passed
```

Toàn bộ kernel + Layer 0:
```bash
pytest vp_analysis/tests/ -v
# → 141 + 32 = 173 passed
```

---

## Preview tích hợp vào pipeline

Đây là cách Layer 0 sẽ được gọi trong orchestrator (Sprint 7):

```python
from vp_analysis.layers import L0_hygiene

def run_pipeline(contract, funnel_df, trade_df, output_dir):
    # 1. Merge
    merged_all = merge_funnel_trades(
        funnel_df, trade_df, tolerance_sec=14400, min_records=15,
    )

    # 2. LAYER 0 — HALT on structural integrity failure
    l0_result = L0_hygiene.run(
        merged_all,
        config=HygieneConfig(),
        output_dir=output_dir / "L0_hygiene",
    )
    if l0_result.should_halt:
        raise RuntimeError(
            f"Layer 0 halted: {l0_result.reason_for_halt}"
        )

    # 3. Continue to Layer 1 (boundary split) ...
```

Điểm mấu chốt:
- Layer 0 chạy **trên `merged_all`**, không phải dev hay holdout. Nó là tiền đề cho cả hai.
- Nếu Layer 0 phát hiện bug, **không có gì downstream được chạy**. Tránh lãng phí compute và tránh sinh ra artifacts từ data bẩn.
- Mọi violation được **sample xuống CSV** để debug — không flood đĩa nếu data bị hỏng toàn bộ.

---

## Sprint 1 hoàn tất

**Deliverables:**
- `L0_hygiene.py` (~450 dòng) — 3 checks, report types, JSON/CSV outputs
- `test_L0_hygiene.py` (~350 dòng) — 32 tests bao phủ clean data, injected bugs, halt policy, output files
- Structured reports với severity PASS/WARN/FAIL

**Kernel + Layer 0 hiện có:**
```text
┌─────────────────────────────────────────────────────────┐
│  Sprint 0A/B/C — Governance kernel        141 tests     │
│  Sprint 1 — Layer 0 Data Hygiene            32 tests     │
│  ─────────────────────────────────────────────────────  │
│  Total                                     173 tests     │
└─────────────────────────────────────────────────────────┘
```

**Sprint 2 tiếp theo — Layer 1 + Layer 2:**
- `L1_boundary.py`: `DataBoundary.from_merged()` wrapper, feature availability, config snapshot
- `L2_feature_engineering.py`: `InteractionTransformer` (fit-on-dev), scaler provenance logging
- Output: `run_meta.json`, `feature_availability.csv`, `interaction_stats.json`
- ~20 tests
