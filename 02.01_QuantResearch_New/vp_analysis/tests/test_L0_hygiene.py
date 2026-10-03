"""Tests for Layer 0 — Data Hygiene.

Group 1: clean data → PASS, no false positives.
Group 2: injected bugs → correct detection and severity.
Group 3: halt policy, config overrides.
Group 4: output file generation.
Group 5: serialization.
"""
from __future__ import annotations

import dataclasses
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
    assert ms.n_mae_exceeds_cap == 0


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
    result = run(None)  # type: ignore[arg-type]
    assert result.should_halt


# ═══════════════════════════════════════════════════════════════════
# GROUP 2a — Entry consistency violations
# ═══════════════════════════════════════════════════════════════════

def test_entry_time_mismatch_detected():
    df = _make_clean_df()
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
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"].values[0] + 5.0

    result = run(df)
    ec = result.entry_consistency
    assert ec.severity == Severity.FAIL.value
    assert ec.n_entry_price_mismatch == 1
    assert result.should_halt


def test_entry_price_tiny_difference_within_tolerance():
    df = _make_clean_df()
    mask = (df["signalId"] == "SIG-00002") & (df["trailStyle"] == 1)
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"].values[0] + 1e-9
    result = run(df)
    # 1e-9 is below default tolerance 1e-6 → no mismatch
    assert result.entry_consistency.n_entry_price_mismatch == 0
    assert result.entry_consistency.severity == Severity.PASS.value


def test_missing_styles_warn_when_above_threshold():
    df = _make_clean_df()
    # Remove style=1 for 6 signals (>10% of 50) → WARN
    drop_sigs = [f"SIG-{i:05d}" for i in range(6)]
    df_filtered = df[~(
        df["signalId"].isin(drop_sigs) & (df["trailStyle"] == 1)
    )].reset_index(drop=True)

    result = run(df_filtered)
    ec = result.entry_consistency
    assert ec.n_signals_missing_styles == 6
    assert ec.severity == Severity.WARN.value
    assert not result.should_halt   # WARN does not halt


def test_missing_styles_pass_when_below_threshold():
    df = _make_clean_df()
    # Remove style=1 for only 4 signals (8% < 10%) → PASS
    drop_sigs = [f"SIG-{i:05d}" for i in range(4)]
    df_filtered = df[~(
        df["signalId"].isin(drop_sigs) & (df["trailStyle"] == 1)
    )].reset_index(drop=True)

    result = run(df_filtered)
    ec = result.entry_consistency
    assert ec.n_signals_missing_styles == 4
    assert ec.severity == Severity.PASS.value


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


# ═══════════════════════════════════════════════════════════════════
# GROUP 2b — MAE/MFE violations
# ═══════════════════════════════════════════════════════════════════

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
    ms = result.mae_mfe_sanity
    assert ms.severity == Severity.FAIL.value
    assert ms.n_negative_mfe == 1
    assert result.should_halt


def test_mae_exceeds_cap_detected():
    df = _make_clean_df()
    df.loc[15, "maeATR"] = 50.0   # >> default cap 10
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.n_mae_exceeds_cap == 1
    assert ms.severity == Severity.FAIL.value


def test_mfe_exceeds_cap_detected():
    df = _make_clean_df()
    df.loc[25, "mfeATR"] = 100.0
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.n_mfe_exceeds_cap == 1
    assert ms.severity == Severity.FAIL.value


def test_custom_cap_respected():
    df = _make_clean_df()
    df.loc[5, "mfeATR"] = 8.0   # above custom cap 5, below default cap 10
    cfg = HygieneConfig(mae_mfe_cap_atr=5.0)
    result = run(df, config=cfg)
    assert result.mae_mfe_sanity.n_mfe_exceeds_cap == 1


def test_dead_trades_detected_as_warn():
    df = _make_clean_df()
    # 3 dead trades / 150 rows = 2% > default 1% threshold
    df.loc[[0, 1, 2], "maeATR"] = 0.0
    df.loc[[0, 1, 2], "mfeATR"] = 0.0
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.n_dead_trades == 3
    assert ms.severity == Severity.WARN.value
    assert not result.should_halt


def test_missing_mae_mfe_columns_skips():
    df = _make_clean_df().drop(columns=["maeATR", "mfeATR"])
    result = run(df)
    ms = result.mae_mfe_sanity
    assert ms.skipped
    assert "maeATR" in ms.skip_reason or "mfeATR" in ms.skip_reason


# ═══════════════════════════════════════════════════════════════════
# GROUP 2c — Time integrity violations
# ═══════════════════════════════════════════════════════════════════

def test_entry_after_exit_detected():
    df = _make_clean_df()
    # Set exit before entry for all 3 rows of one signal
    mask = df["signalId"] == "SIG-00003"
    df.loc[mask, "exitTime"] = pd.Timestamp("2020-01-01")

    result = run(df)
    ti = result.time_integrity
    assert ti.n_entry_after_exit == 3   # 3 rows share that signal
    assert ti.severity == Severity.FAIL.value
    assert result.should_halt
    assert "time integrity" in result.reason_for_halt


def test_missing_entry_time_warns():
    df = _make_clean_df()
    # 5 missing out of 150 = 3.3% > 1% threshold
    df.loc[list(range(5)), "entryTime"] = pd.NaT
    result = run(df)
    ti = result.time_integrity
    assert ti.n_missing_entry_time == 5
    assert ti.severity == Severity.WARN.value
    assert not result.should_halt


def test_missing_both_time_columns_skips():
    df = _make_clean_df().drop(columns=["entryTime", "time"])
    result = run(df)
    assert result.time_integrity.skipped


def test_time_range_recorded():
    df = _make_clean_df()
    result = run(df)
    ti = result.time_integrity
    assert ti.time_range_start is not None
    assert ti.time_range_end is not None
    assert ti.time_range_start < ti.time_range_end


def test_median_duration_computed():
    df = _make_clean_df()   # all 30-min durations
    result = run(df)
    ti = result.time_integrity
    assert ti.median_duration_sec == pytest.approx(1800.0, abs=1.0)


# ═══════════════════════════════════════════════════════════════════
# GROUP 3 — Halt policy and config overrides
# ═══════════════════════════════════════════════════════════════════

def test_halt_disabled_for_entry_consistency():
    """When halt_on_entry_inconsistency=False, a FAIL in entry check must
    not halt the pipeline even if entry_consistency.severity == FAIL.
    We also disable time_integrity halt to keep the test focused."""
    df = _make_clean_df()
    # Corrupt entry price only (no time ordering impact)
    mask = (df["signalId"] == "SIG-00000") & (df["trailStyle"] == 1)
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"].values[0] + 5.0

    cfg = HygieneConfig(
        halt_on_entry_inconsistency=False,
        halt_on_time_integrity=False,  # isolate the check under test
    )
    result = run(df, config=cfg)
    assert result.entry_consistency.severity == Severity.FAIL.value
    assert not result.should_halt


def test_halt_disabled_for_mae_mfe():
    df = _make_clean_df()
    df.loc[10, "maeATR"] = -1.0

    cfg = HygieneConfig(halt_on_mae_mfe_violation=False)
    result = run(df, config=cfg)
    assert result.mae_mfe_sanity.severity == Severity.FAIL.value
    assert not result.should_halt


def test_halt_disabled_for_time_integrity():
    df = _make_clean_df()
    mask = df["signalId"] == "SIG-00003"
    df.loc[mask, "exitTime"] = pd.Timestamp("2020-01-01")

    cfg = HygieneConfig(halt_on_time_integrity=False)
    result = run(df, config=cfg)
    assert result.time_integrity.severity == Severity.FAIL.value
    assert not result.should_halt


def test_all_halt_flags_disabled_no_halt():
    df = _make_clean_df()
    df.loc[10, "maeATR"] = -1.0
    df.loc[20, "entryTime"] = pd.Timestamp("2020-01-01")   # mismatched time

    cfg = HygieneConfig(
        halt_on_entry_inconsistency=False,
        halt_on_mae_mfe_violation=False,
        halt_on_time_integrity=False,
    )
    result = run(df, config=cfg)
    assert not result.should_halt
    assert result.overall_severity == Severity.FAIL.value


# ═══════════════════════════════════════════════════════════════════
# GROUP 4 — Output files
# ═══════════════════════════════════════════════════════════════════

def test_summary_json_written(tmp_path):
    df = _make_clean_df()
    run(df, output_dir=tmp_path)
    assert (tmp_path / "layer_zero_summary.json").exists()


def test_summary_json_correct_content(tmp_path):
    df = _make_clean_df()
    mask = (df["signalId"] == "SIG-00000") & (df["trailStyle"] == 1)
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"].values[0] + 5.0

    run(df, output_dir=tmp_path)
    with (tmp_path / "layer_zero_summary.json").open() as f:
        payload = json.load(f)
    assert payload["overall_severity"] == Severity.FAIL.value
    assert payload["entry_consistency"]["n_entry_price_mismatch"] == 1
    assert payload["should_halt"] is True


def test_entry_violation_csv_written_on_fail(tmp_path):
    df = _make_clean_df()
    mask = (df["signalId"] == "SIG-00000") & (df["trailStyle"] == 1)
    df.loc[mask, "entryPrice"] = df.loc[mask, "entryPrice"].values[0] + 5.0
    run(df, output_dir=tmp_path)
    assert (tmp_path / "entry_consistency_violations.csv").exists()


def test_mae_mfe_violation_csv_written_on_fail(tmp_path):
    df = _make_clean_df()
    df.loc[10, "maeATR"] = -1.0
    run(df, output_dir=tmp_path)
    assert (tmp_path / "mae_mfe_violations.csv").exists()


def test_no_violation_csv_when_clean(tmp_path):
    df = _make_clean_df()
    run(df, output_dir=tmp_path)
    assert not (tmp_path / "entry_consistency_violations.csv").exists()
    assert not (tmp_path / "mae_mfe_violations.csv").exists()
    assert not (tmp_path / "time_integrity_violations.csv").exists()


def test_summary_json_clean_data_content(tmp_path):
    df = _make_clean_df()
    run(df, output_dir=tmp_path)
    with (tmp_path / "layer_zero_summary.json").open() as f:
        payload = json.load(f)
    assert payload["overall_severity"] == Severity.PASS.value
    assert payload["should_halt"] is False
    assert payload["n_input_rows"] == 150   # 50 signals × 3 styles


# ═══════════════════════════════════════════════════════════════════
# GROUP 5 — Serialization and immutability
# ═══════════════════════════════════════════════════════════════════

def test_result_to_dict_serializable():
    df = _make_clean_df()
    result = run(df)
    d = result.to_dict()
    serialized = json.dumps(d, default=str)
    parsed = json.loads(serialized)
    assert parsed["overall_severity"] == "PASS"
    assert parsed["should_halt"] is False
    assert parsed["n_input_rows"] == 150


def test_result_immutable():
    df = _make_clean_df()
    result = run(df)
    with pytest.raises(dataclasses.FrozenInstanceError):
        result.overall_severity = "FAIL"  # type: ignore[misc]


def test_sub_report_immutable():
    df = _make_clean_df()
    result = run(df)
    with pytest.raises(dataclasses.FrozenInstanceError):
        result.entry_consistency.n_signals = 999  # type: ignore[misc]
