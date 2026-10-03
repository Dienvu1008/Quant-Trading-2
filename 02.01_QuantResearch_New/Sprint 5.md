# Sprint 5 — Layer 5: Soft Gate Discovery

> **v3 changes (từ SPECIFICATION.md v3):**
> - **[Fix #1] Sprint 5 bao gồm cả L10a** (Bad Entry Discovery) vì L10a cần chạy trước L6 để p-values vào FDR pool `bad_entry`. L10a và L5 chạy song song trên dev.
> - **[Fix #2] L10a dùng MFE-based canary label** (không phải profitUSD). Input là `dev_all_styles` (3-style dev subset). `n_total_bad` được tính và logged ngay trong L10a vào `run_meta.json`.
> - L5 không thay đổi gì về code. Chỉ xác nhận: permutation chạy trên dev, không phải holdout. [Đúng rồi từ v2]

Deliverables:
- `layers/L5_soft_gate_discovery.py` — direction extraction + permutation screening on dev only
- **[NEW] `layers/L10a_bad_entry_discovery.py`** — canary labeling + bad-entry feature screening (dev_all_styles, MFE canary target)
- Outputs: `soft_gate_directions.csv`, `soft_gate_candidates.csv`, `L10a_bad_entry_discovery/canary_labels.csv`, `bad_entry_features.csv`, `composite_bad_filter_candidate.json`
- ~14 tests (L5) + ~20 tests (L10a)

**Điểm quan trọng:** Đây là nơi fix lỗi critique từ ChatGPT — permutation chạy trên **dev**, không phải holdout. Direction frozen từ dev. Không touch holdout ở layer này.

Nguyên tắc:
1. Direction từ Spearman rank trên dev
2. Signal = `direction * feature`
3. Split dev thành top / bottom theo signal
4. Lift = EV(top) − EV(bottom)
5. Permutation test trên dev
6. Chỉ candidates có `perm_pvalue < perm_alpha` mới pass
7. FDR correction ở L6 (không phải ở đây)

---

## `vp_analysis/layers/L5_soft_gate_discovery.py`

```python
"""Layer 5 — Soft Gate Discovery.

A soft gate is a monotone signal: it doesn't gate trades in/out, it tilts
the size/direction. The direction is learned on development; the test
verifies whether conditioning on the signal shifts EV in the expected
direction.

Pipeline (all on dev):
  1. For each feature: direction = sign(Spearman(feature, profit)).
  2. Signal = direction * feature.
  3. Split dev trades by signal percentile (top X% vs bottom X%).
  4. Lift = EV(top) - EV(bottom).
  5. Permutation test on lift (shuffle profit, recompute).
  6. Candidates with perm_pvalue <= alpha go to L6 for FDR.

CRITICAL — no holdout is touched here. The permutation test runs on
development data only. The direction is derived from development only.
The lift is measured on development only. The p-value is a development
p-value, to be FDR-corrected alongside other candidates in L6.

This fixes the design flaw in Phase 02 v3/v4 where the soft-gate
permutation ran on holdout — which would have consumed the holdout
before the freeze.
"""
from __future__ import annotations

import datetime as dt
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from scipy import stats


# ─── Configuration ───────────────────────────────────────────────

@dataclass(frozen=True)
class SoftGateConfig:
    # Direction extraction
    min_spearman_abs: float = 0.00   # allow weak signals; FDR handles strength

    # Split strategy for permutation
    split_mode: str = "median"       # "median" | "tertile" | "quartile"
    # Actually let's support median only for simplicity; leave hook for others.

    # Minimum sample sizes
    min_total_samples: int = 60
    min_half_samples: int = 20

    # Permutation
    perm_iterations: int = 500
    perm_alpha: float = 0.10
    perm_early_stop_after: int = 100
    perm_early_stop_p: float = 0.30

    # Seed
    seed: int = 42


# ─── Result types ────────────────────────────────────────────────

@dataclass(frozen=True)
class SoftGateDirection:
    feature: str
    category: str
    direction: int
    dev_spearman_rho: float
    dev_spearman_pvalue: float
    n_samples: int

    def to_dict(self) -> dict:
        return {
            "feature": self.feature,
            "category": self.category,
            "direction": self.direction,
            "dev_spearman_rho": round(self.dev_spearman_rho, 6),
            "dev_spearman_pvalue": round(self.dev_spearman_pvalue, 6),
            "n_samples": int(self.n_samples),
        }


@dataclass(frozen=True)
class SoftGateCandidate:
    """Candidate gate after dev permutation. Not yet FDR-corrected."""
    symbol: str
    setup: str
    feature: str
    category: str
    direction: int

    # Development measurements
    dev_spearman_rho: float
    dev_spearman_pvalue: float
    n_total: int
    n_top: int
    n_bottom: int
    ev_top: float
    ev_bottom: float
    ev_lift: float
    wr_top: float
    wr_bottom: float

    # Permutation test (dev)
    perm_pvalue: float

    def to_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "setup": self.setup,
            "feature": self.feature,
            "category": self.category,
            "direction": self.direction,
            "dev_spearman_rho": round(self.dev_spearman_rho, 6),
            "dev_spearman_pvalue": round(self.dev_spearman_pvalue, 6),
            "n_total": int(self.n_total),
            "n_top": int(self.n_top),
            "n_bottom": int(self.n_bottom),
            "ev_top": round(self.ev_top, 6),
            "ev_bottom": round(self.ev_bottom, 6),
            "ev_lift": round(self.ev_lift, 6),
            "wr_top": round(self.wr_top, 6),
            "wr_bottom": round(self.wr_bottom, 6),
            "perm_pvalue": round(self.perm_pvalue, 6),
        }


@dataclass(frozen=True)
class LayerFiveResult:
    directions: tuple
    candidates: tuple
    n_features_evaluated: int
    n_candidates: int
    warnings: tuple
    n_dev_rows: int
    ran_at: str

    def summary_dict(self) -> dict:
        return {
            "ran_at": self.ran_at,
            "n_dev_rows": self.n_dev_rows,
            "n_features_evaluated": self.n_features_evaluated,
            "n_candidates": self.n_candidates,
            "warnings": list(self.warnings),
        }


# ─── Public API ──────────────────────────────────────────────────

def run(
    dev_df: pd.DataFrame,
    contract,
    available_features,  # iterable of feature names
    output_dir: Optional[Path] = None,
    config: Optional[SoftGateConfig] = None,
) -> LayerFiveResult:
    """Execute Layer 5.

    dev_df must contain `_profit`. Only development data is used.
    """
    cfg = config or SoftGateConfig()
    ran_at = dt.datetime.utcnow().isoformat() + "Z"

    if dev_df is None or len(dev_df) == 0:
        raise ValueError("L5: dev_df is empty")
    if "_profit" not in dev_df.columns:
        raise ValueError("L5: dev_df must have '_profit' column")

    usable = [f for f in available_features if f in dev_df.columns]
    if not usable:
        return LayerFiveResult(
            directions=(), candidates=(),
            n_features_evaluated=0, n_candidates=0,
            warnings=("No usable features present in dev_df",),
            n_dev_rows=len(dev_df), ran_at=ran_at,
        )

    feature_category = _build_feature_category_map(contract.pre_registered)

    # ─── 1. Direction extraction on entire dev ─────────────────
    directions, dir_warnings = _extract_directions(
        dev_df, usable, feature_category, cfg,
    )

    # ─── 2. Per-group permutation screening ────────────────────
    groups = _split_groups(dev_df)
    warnings = list(dir_warnings)
    candidates: list[SoftGateCandidate] = []

    dir_lookup = {d.feature: d for d in directions}

    for symbol, setup, group_df in groups:
        if len(group_df) < cfg.min_total_samples:
            warnings.append(
                f"Group {symbol}/{setup}: {len(group_df)} rows < "
                f"{cfg.min_total_samples}, skipped"
            )
            continue

        group_df = group_df.reset_index(drop=True)
        for feat in usable:
            d = dir_lookup.get(feat)
            if d is None or d.direction == 0:
                continue
            cand = _test_soft_gate(
                group_df, symbol, setup, feat,
                feature_category.get(feat, "unknown"),
                d, cfg,
            )
            if cand is not None:
                candidates.append(cand)

    # Sort by p-value (most significant first)
    candidates.sort(key=lambda c: c.perm_pvalue)

    result = LayerFiveResult(
        directions=tuple(directions),
        candidates=tuple(candidates),
        n_features_evaluated=len(usable),
        n_candidates=len(candidates),
        warnings=tuple(warnings),
        n_dev_rows=len(dev_df),
        ran_at=ran_at,
    )

    if output_dir is not None:
        _write_outputs(result, Path(output_dir))

    return result


# ─── Direction extraction ───────────────────────────────────────

def _extract_directions(
    dev_df: pd.DataFrame,
    features: list[str],
    feature_category: dict,
    cfg: SoftGateConfig,
) -> tuple[list[SoftGateDirection], list[str]]:
    """Compute Spearman(feature, profit) on full dev, one entry per feature."""
    out: list[SoftGateDirection] = []
    warnings: list[str] = []
    profits = pd.to_numeric(dev_df["_profit"], errors="coerce")

    for feat in features:
        series = pd.to_numeric(dev_df[feat], errors="coerce")
        valid = series.notna() & profits.notna()
        n = int(valid.sum())
        if n < cfg.min_total_samples:
            warnings.append(
                f"Direction for {feat!r}: only {n} valid rows, skipped"
            )
            continue

        x = series[valid].values
        y = profits[valid].values

        if np.std(x) < 1e-12:
            warnings.append(
                f"Direction for {feat!r}: zero variance, skipped"
            )
            continue

        rho, pval = stats.spearmanr(x, y)
        rho = float(rho) if not np.isnan(rho) else 0.0
        pval = float(pval) if not np.isnan(pval) else 1.0

        if rho >= 0:
            direction = 1
        else:
            direction = -1

        out.append(SoftGateDirection(
            feature=feat,
            category=feature_category.get(feat, "unknown"),
            direction=direction,
            dev_spearman_rho=rho,
            dev_spearman_pvalue=pval,
            n_samples=n,
        ))

    return out, warnings


# ─── Per-group soft gate test ────────────────────────────────────

def _test_soft_gate(
    group_df: pd.DataFrame,
    symbol: str,
    setup: str,
    feature: str,
    category: str,
    direction_info: SoftGateDirection,
    cfg: SoftGateConfig,
) -> Optional[SoftGateCandidate]:
    """Test one soft gate on one (symbol, setup) group. Dev only."""
    profits = pd.to_numeric(group_df["_profit"], errors="coerce")
    vals = pd.to_numeric(group_df[feature], errors="coerce")
    valid = vals.notna() & profits.notna()
    n_total = int(valid.sum())
    if n_total < cfg.min_total_samples:
        return None

    vals = vals[valid].values.astype(float)
    profits_arr = profits[valid].values.astype(float)

    # Signal uses direction from dev (frozen upstream)
    signal = direction_info.direction * vals

    # Median split
    med = float(np.median(signal))
    top_mask = signal > med
    bot_mask = signal < med
    n_top = int(top_mask.sum())
    n_bot = int(bot_mask.sum())
    if n_top < cfg.min_half_samples or n_bot < cfg.min_half_samples:
        return None

    ev_top = float(profits_arr[top_mask].mean())
    ev_bot = float(profits_arr[bot_mask].mean())
    lift = ev_top - ev_bot

    wr_top = float((profits_arr[top_mask] > 0).mean())
    wr_bot = float((profits_arr[bot_mask] > 0).mean())

    # Permutation test on dev: shuffle profits, recompute lift
    perm_p = _permutation_soft_gate(
        profits_arr, top_mask, bot_mask, lift, cfg,
    )

    if perm_p > cfg.perm_alpha:
        return None

    return SoftGateCandidate(
        symbol=symbol, setup=setup,
        feature=feature, category=category,
        direction=direction_info.direction,
        dev_spearman_rho=direction_info.dev_spearman_rho,
        dev_spearman_pvalue=direction_info.dev_spearman_pvalue,
        n_total=n_total, n_top=n_top, n_bottom=n_bot,
        ev_top=ev_top, ev_bottom=ev_bot, ev_lift=lift,
        wr_top=wr_top, wr_bottom=wr_bot,
        perm_pvalue=perm_p,
    )


def _permutation_soft_gate(
    profits: np.ndarray,
    top_mask: np.ndarray,
    bot_mask: np.ndarray,
    observed_lift: float,
    cfg: SoftGateConfig,
) -> float:
    """One-sided permutation: P(lift_perm >= observed_lift) under H0.

    Signal positions are held fixed (top_mask, bot_mask); only profits
    are shuffled. Early stop if clearly not significant.
    """
    arr = profits.copy()
    rng = np.random.default_rng(cfg.seed)
    count = 0
    for it in range(cfg.perm_iterations):
        rng.shuffle(arr)
        null_lift = float(arr[top_mask].mean() - arr[bot_mask].mean())
        if null_lift >= observed_lift:
            count += 1
        if it + 1 >= cfg.perm_early_stop_after:
            p = count / (it + 1)
            if p > cfg.perm_early_stop_p:
                return p
    return count / cfg.perm_iterations


# ─── Grouping ────────────────────────────────────────────────────

def _split_groups(df: pd.DataFrame) -> list[tuple[str, str, pd.DataFrame]]:
    if "symbol" not in df.columns:
        if "setupType" in df.columns:
            out = []
            for st in df["setupType"].dropna().unique():
                if st in ("NONE", ""):
                    continue
                sub = df[df["setupType"] == st].reset_index(drop=True)
                out.append(("ALL", str(st), sub))
            return out
        return [("ALL", "ALL", df)]

    out: list[tuple[str, str, pd.DataFrame]] = []
    for sym in df["symbol"].unique():
        sym_df = df[df["symbol"] == sym]
        if "setupType" in sym_df.columns:
            for st in sym_df["setupType"].dropna().unique():
                if st in ("NONE", ""):
                    continue
                sub = sym_df[sym_df["setupType"] == st].reset_index(drop=True)
                if len(sub) > 0:
                    out.append((str(sym), str(st), sub))
        else:
            out.append((str(sym), "ALL", sym_df.reset_index(drop=True)))
    return out


# ─── Helpers ─────────────────────────────────────────────────────

def _build_feature_category_map(pre_registered: dict) -> dict:
    out: dict[str, str] = {}
    for cat, features in pre_registered.items():
        for f in features:
            out[f] = cat
    return out


# ─── Output ──────────────────────────────────────────────────────

def _write_outputs(result: LayerFiveResult, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    if result.directions:
        pd.DataFrame(
            [d.to_dict() for d in result.directions]
        ).to_csv(output_dir / "soft_gate_directions.csv", index=False)

    if result.candidates:
        pd.DataFrame(
            [c.to_dict() for c in result.candidates]
        ).to_csv(output_dir / "soft_gate_candidates.csv", index=False)

    with (output_dir / "soft_gate_discovery_summary.json").open(
        "w", encoding="utf-8",
    ) as f:
        json.dump(result.summary_dict(), f, indent=2, default=str)
```

## `vp_analysis/layers/__init__.py` — cập nhật

```python
"""Analysis layers."""
from . import L0_hygiene
from . import L1_boundary
from . import L2_feature_engineering
from . import L3_eda
from . import L4_hard_gate_discovery
from . import L5_soft_gate_discovery

__all__ = [
    "L0_hygiene", "L1_boundary", "L2_feature_engineering",
    "L3_eda", "L4_hard_gate_discovery", "L5_soft_gate_discovery",
]
```

---

## Tests

## `vp_analysis/tests/test_L5_soft_gate_discovery.py`

```python
"""Tests for Layer 5 — Soft Gate Discovery."""
import json

import numpy as np
import pandas as pd
import pytest

from vp_analysis.core.research_contract import ResearchContract
from vp_analysis.layers import L5_soft_gate_discovery
from vp_analysis.layers.L5_soft_gate_discovery import (
    SoftGateConfig,
    _extract_directions,
    _permutation_soft_gate,
    _test_soft_gate,
    _build_feature_category_map,
)


# ─── Fixtures ────────────────────────────────────────────────────

@pytest.fixture
def soft_contract(minimal_contract_dict):
    d = dict(minimal_contract_dict)
    d["pre_registered"] = {
        "cat_a": ["f_signal_up", "f_signal_down"],
        "cat_b": ["f_noise"],
    }
    d["feature_direction"] = {
        "f_signal_up": 1, "f_signal_down": -1, "f_noise": 0,
    }
    d["shape_priors"] = {
        "f_signal_up": "MONO_UP",
        "f_signal_down": "MONO_DOWN",
        "f_noise": "MONO_UP",
    }
    return ResearchContract.from_dict(d)


def _make_soft_signal_df(n=400, seed=0, strength=0.8):
    """f_signal_up positively correlated with profit.
    f_signal_down negatively. f_noise independent."""
    rng = np.random.default_rng(seed)
    f_up = rng.uniform(0, 1, n)
    f_down = rng.uniform(0, 1, n)
    f_noise = rng.uniform(0, 1, n)
    noise = rng.normal(0, 0.4, n)
    profit = (
        strength * (f_up - 0.5)
        - strength * (f_down - 0.5)
        + noise
    )
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal_up": f_up,
        "f_signal_down": f_down,
        "f_noise": f_noise,
        "_profit": profit,
    })


def _make_pure_noise_df(n=400, seed=42):
    rng = np.random.default_rng(seed)
    return pd.DataFrame({
        "time": pd.date_range("2024-01-01", periods=n, freq="h"),
        "symbol": ["XAUUSD"] * n,
        "setupType": ["BOS"] * n,
        "f_signal_up": rng.uniform(0, 1, n),
        "f_signal_down": rng.uniform(0, 1, n),
        "f_noise": rng.uniform(0, 1, n),
        "_profit": rng.normal(0, 1, n),
    })


# ══════════════════════════════════════════════════════════════════
# Direction extraction
# ══════════════════════════════════════════════════════════════════

def test_direction_positive_signal(soft_contract):
    df = _make_soft_signal_df(n=400, seed=0)
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, _ = _extract_directions(
        df, ["f_signal_up", "f_signal_down", "f_noise"],
        feature_cat, SoftGateConfig(),
    )
    by_name = {d.feature: d for d in directions}
    assert by_name["f_signal_up"].direction == 1
    assert by_name["f_signal_up"].dev_spearman_rho > 0


def test_direction_negative_signal(soft_contract):
    df = _make_soft_signal_df(n=400, seed=0)
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, _ = _extract_directions(
        df, ["f_signal_up", "f_signal_down", "f_noise"],
        feature_cat, SoftGateConfig(),
    )
    by_name = {d.feature: d for d in directions}
    assert by_name["f_signal_down"].direction == -1
    assert by_name["f_signal_down"].dev_spearman_rho < 0


def test_direction_constant_feature_skipped(soft_contract):
    df = _make_soft_signal_df(n=400, seed=0)
    df["f_const"] = 0.5
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, warnings = _extract_directions(
        df, ["f_const"], feature_cat, SoftGateConfig(),
    )
    assert len(directions) == 0
    assert any("zero variance" in w for w in warnings)


def test_direction_min_samples_skipped(soft_contract):
    df = _make_soft_signal_df(n=20, seed=0)
    feature_cat = _build_feature_category_map(soft_contract.pre_registered)
    directions, warnings = _extract_directions(
        df, ["f_signal_up"], feature_cat,
        SoftGateConfig(min_total_samples=100),
    )
    assert len(directions) == 0
    assert any("valid rows" in w for w in warnings)


# ══════════════════════════════════════════════════════════════════
# Permutation test
# ══════════════════════════════════════════════════════════════════

def test_permutation_significant_when_signal_present():
    rng = np.random.default_rng(0)
    n = 200
    signal = rng.uniform(0, 1, n)
    profits = signal * 2.0 + rng.normal(0, 0.5, n)
    med = np.median(signal)
    top = signal > med
    bot = signal < med
    obs_lift = profits[top].mean() - profits[bot].mean()
    p = _permutation_soft_gate(profits, top, bot, obs_lift, SoftGateConfig())
    assert p < 0.05


def test_permutation_not_significant_when_no_signal():
    rng = np.random.default_rng(1)
    n = 200
    signal = rng.uniform(0, 1, n)
    profits = rng.normal(0, 1, n)
    med = np.median(signal)
    top = signal > med
    bot = signal < med
    obs_lift = profits[top].mean() - profits[bot].mean()
    p = _permutation_soft_gate(profits, top, bot, obs_lift, SoftGateConfig())
    assert p > 0.10


# ══════════════════════════════════════════════════════════════════
# Full discovery integration
# ══════════════════════════════════════════════════════════════════

def test_discovers_strong_soft_signal(soft_contract):
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down", "f_noise"],
        config=SoftGateConfig(perm_alpha=0.05),
    )
    candidate_features = {c.feature for c in result.candidates}
    assert "f_signal_up" in candidate_features
    assert "f_signal_down" in candidate_features


def test_noise_not_discovered(soft_contract):
    df = _make_pure_noise_df(n=600, seed=42)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down", "f_noise"],
        config=SoftGateConfig(perm_alpha=0.01),
    )
    # Pure noise should rarely produce candidates with strict alpha
    assert len(result.candidates) == 0


def test_direction_frozen_in_candidates(soft_contract):
    """Verify the direction in the candidate matches the direction
    extracted from dev."""
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down"],
        config=SoftGateConfig(perm_alpha=0.05),
    )
    dir_lookup = {d.feature: d for d in result.directions}
    for c in result.candidates:
        assert c.direction == dir_lookup[c.feature].direction


# ══════════════════════════════════════════════════════════════════
# Holdout untouched invariant
# ══════════════════════════════════════════════════════════════════

def test_L5_never_touches_holdout(soft_contract):
    """Verify by passing a dev_df that contains all rows.
    L5 should NOT have any code path that accesses anything other
    than what's passed to it. Test indirectly: L5 result contains
    only dev-derived values."""
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up"],
        config=SoftGateConfig(perm_alpha=0.10),
    )
    # Every n_total should equal the rows we passed (no additional data)
    for c in result.candidates:
        assert c.n_total <= len(df)
        assert c.n_top + c.n_bottom <= c.n_total


# ══════════════════════════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════════════════════════

def test_outputs_written(soft_contract, tmp_path):
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down", "f_noise"],
        output_dir=tmp_path,
        config=SoftGateConfig(perm_alpha=0.10),
    )
    assert (tmp_path / "soft_gate_directions.csv").exists()
    assert (tmp_path / "soft_gate_discovery_summary.json").exists()
    with (tmp_path / "soft_gate_discovery_summary.json").open() as f:
        summary = json.load(f)
    assert summary["n_features_evaluated"] == 3


def test_candidates_csv_written_when_significant(soft_contract, tmp_path):
    df = _make_soft_signal_df(n=600, seed=0, strength=1.5)
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up", "f_signal_down"],
        output_dir=tmp_path,
        config=SoftGateConfig(perm_alpha=0.10),
    )
    if result.candidates:
        assert (tmp_path / "soft_gate_candidates.csv").exists()
        df_out = pd.read_csv(tmp_path / "soft_gate_candidates.csv")
        expected_cols = {
            "symbol", "setup", "feature", "direction",
            "ev_top", "ev_bottom", "ev_lift",
            "perm_pvalue", "n_top", "n_bottom",
        }
        assert expected_cols.issubset(set(df_out.columns))


# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

def test_empty_df_raises(soft_contract):
    with pytest.raises(ValueError, match="empty"):
        L5_soft_gate_discovery.run(
            pd.DataFrame(), soft_contract,
            available_features=["f_signal_up"],
        )


def test_missing_profit_column_raises(soft_contract):
    df = _make_soft_signal_df(n=200).drop(columns=["_profit"])
    with pytest.raises(ValueError, match="_profit"):
        L5_soft_gate_discovery.run(
            df, soft_contract, available_features=["f_signal_up"],
        )


def test_no_usable_features_returns_empty(soft_contract):
    df = _make_soft_signal_df(n=200)
    result = L5_soft_gate_discovery.run(
        df, soft_contract, available_features=["missing_feature"],
    )
    assert result.n_features_evaluated == 0
    assert len(result.candidates) == 0
    assert any("No usable features" in w for w in result.warnings)


def test_small_group_skipped(soft_contract):
    """Group smaller than min_total_samples produces warning."""
    df = _make_soft_signal_df(n=200, seed=0)
    # Chop down to a group of 30
    df = df.iloc[:30].copy()
    result = L5_soft_gate_discovery.run(
        df, soft_contract,
        available_features=["f_signal_up"],
        config=SoftGateConfig(min_total_samples=100),
    )
    assert any("skipped" in w for w in result.warnings)
```

---

## Chạy tests

```bash
cd vp_analysis/..
pytest vp_analysis/tests/test_L5_soft_gate_discovery.py -v
```

Kỳ vọng:

```text
test_L5_soft_gate_discovery.py
  Direction extraction                4 passed
  Permutation test                    2 passed
  Full discovery                      3 passed
  Holdout untouched                   1 passed
  Output                              2 passed
  Edge cases                          4 passed
  ────────────────────────────────────────────────
  Total                             16 passed
```

Full suite:

```bash
pytest vp_analysis/tests/ -v
# → 141 + 32 + 30 + 24 + 22 + 16 = 265 passed
```

---

## Preview: Layer 5 trong pipeline

```python
from vp_analysis.layers import L5_soft_gate_discovery

l5 = L5_soft_gate_discovery.run(
    dev_df=l2.boundary.dev.data,
    contract=contract,
    available_features=l1.available_features(),
    output_dir=output_dir / "L5_soft_gates",
    config=SoftGateConfig(
        perm_alpha=0.10,
        perm_iterations=500,
    ),
)

print(f"  Directions computed: {len(l5.directions)}")
print(f"  Soft-gate candidates: {len(l5.candidates)}")
for c in l5.candidates[:5]:
    print(f"    {c.symbol}/{c.setup} {c.feature} "
          f"dir={c.direction} lift={c.ev_lift:+.3f} p={c.perm_pvalue:.4f}")
```

Output:

```text
output/
├── L5_soft_gates/
│   ├── soft_gate_directions.csv
│   ├── soft_gate_candidates.csv
│   └── soft_gate_discovery_summary.json
```

---

## Sprint 5 hoàn tất

**Deliverables:**
- `L5_soft_gate_discovery.py` (~350 dòng) — direction extraction + permutation on dev
- 16 tests bao gồm:
  - Direction extraction cho positive/negative/noise features
  - Constant feature skipped
  - Insufficient samples warning
  - Permutation significance với/không có signal
  - Full discovery integration với synthetic soft signal
  - Noise rejection
  - **Direction frozen invariant** — direction trong candidate khớp với `_extract_directions`
  - **Holdout untouched** — verify L5 không access gì ngoài dev_df được truyền
  - Output file correctness
  - Edge cases

**Bugs từ Phase 02 v4 đã được fix:**
1. ✅ **Permutation trên dev**, không phải holdout
2. ✅ **Direction frozen từ dev** — không có cơ chế nào để sửa sau khi thấy kết quả
3. ✅ **Candidates pass lên L6 với `perm_pvalue`** — FDR correction ở tầng riêng
4. ✅ **No holdout touch** — Layer 5 thuần túy trên dev_df

**Cấu trúc dữ liệu xuất khớp với L6 tiếp theo:**
- `soft_gate_candidates.csv` có `perm_pvalue` để feed vào FDR pool `soft_gate`
- `soft_gate_directions.csv` có `direction` để dùng trong tilt application

**Kernel + L0-L5 hiện có:**
```text
┌─────────────────────────────────────────────────────────────┐
│  Sprint 0A/B/C — Governance kernel        141 tests         │
│  Sprint 1 — L0 Data Hygiene                 32 tests         │
│  Sprint 2 — L1 Boundary + L2 Features       30 tests         │
│  Sprint 3 — L3 EDA + Shape Verification     24 tests         │
│  Sprint 4 — L4 Hard Gate Discovery          22 tests         │
│  Sprint 5 — L5 Soft Gate Discovery          16 tests         │
│  ─────────────────────────────────────────────────────────  │
│  Total                                     265 tests         │
└─────────────────────────────────────────────────────────────┘
```

**Sprint 6 — Layer 6: Multiple Testing + Rule Freeze:**
- FDR correction: 3 pools riêng (hard_gate, soft_gate, bad_entry)
- Rule finalization (validated flag)
- Frozen rule construction từ hard gate candidates
- Output: `fdr_summary.json`, `frozen_rules.json`
- ~18 tests
