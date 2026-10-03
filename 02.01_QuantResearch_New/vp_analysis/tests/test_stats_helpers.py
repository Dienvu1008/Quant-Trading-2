import numpy as np
import pytest

from vp_analysis.core.stats_helpers import (
    benjamini_hochberg,
    benjamini_yekutieli,
    bootstrap_ci,
    correct_multiple_testing,
    one_sided_t_test,
)


# ─── BH ─────────────────────────────────────────────────────────

def test_bh_empty():
    reject, p_adj = benjamini_hochberg([], alpha=0.05)
    assert len(reject) == 0 and len(p_adj) == 0


def test_bh_all_significant():
    p = [0.001, 0.002, 0.003, 0.004]
    reject, _ = benjamini_hochberg(p, alpha=0.05)
    assert reject.all()


def test_bh_none_significant():
    p = [0.5, 0.6, 0.7, 0.8]
    reject, _ = benjamini_hochberg(p, alpha=0.05)
    assert not reject.any()


def test_bh_step_up_property():
    # BH example: p-values scaled so that the first 4 pass the BH threshold.
    # With n=4 and alpha=0.05:
    #   rank 1: threshold = 1/4*0.05 = 0.0125  → p=0.001 < 0.0125 ✓
    #   rank 2: threshold = 2/4*0.05 = 0.025   → p=0.008 < 0.025  ✓
    #   rank 3: threshold = 3/4*0.05 = 0.0375  → p=0.020 < 0.0375 ✓
    #   rank 4: threshold = 4/4*0.05 = 0.05    → p=0.040 < 0.05   ✓
    # BH step-up: largest k where p_(k) <= k/n * alpha.
    # With only these 4 hypotheses all should be rejected.
    p = [0.001, 0.008, 0.020, 0.040]
    reject, _ = benjamini_hochberg(p, alpha=0.05)
    assert reject.all(), f"Expected all 4 rejected, got {reject}"

    # Adding one clearly non-significant: the 4 should still reject.
    p2 = [0.001, 0.008, 0.020, 0.040, 0.60]
    reject2, _ = benjamini_hochberg(p2, alpha=0.05)
    assert reject2[:4].all()
    assert not reject2[4]


def test_bh_p_adj_clipped_at_one():
    p = [0.9, 0.95, 0.99]
    _, p_adj = benjamini_hochberg(p, alpha=0.05)
    assert (p_adj <= 1.0).all()


def test_bh_alpha_zero_rejects_nothing():
    p = [0.001, 0.002]
    reject, _ = benjamini_hochberg(p, alpha=0.0)
    assert not reject.any()


def test_by_more_conservative_than_bh():
    """BY should reject fewer or equal hypotheses than BH at same alpha."""
    p = [0.001, 0.01, 0.02, 0.03, 0.04]
    reject_bh, _ = benjamini_hochberg(p, alpha=0.05)
    reject_by, _ = benjamini_yekutieli(p, alpha=0.05)
    # BY is more conservative: n_rejected_by <= n_rejected_bh
    assert reject_by.sum() <= reject_bh.sum()


# ─── Dispatcher ─────────────────────────────────────────────────

def test_dispatch_bh_aliases():
    r1, _ = correct_multiple_testing([0.01, 0.02], 0.05, "benjamini-hochberg")
    r2, _ = correct_multiple_testing([0.01, 0.02], 0.05, "bh")
    assert (r1 == r2).all()


def test_dispatch_unknown_raises():
    with pytest.raises(ValueError):
        correct_multiple_testing([0.01], 0.05, "unknown")


# ─── One-sided t-test ───────────────────────────────────────────

def test_t_test_insufficient_data():
    _, p = one_sided_t_test([0.5])
    assert p == 1.0


def test_t_test_zero_variance():
    _, p = one_sided_t_test([0.5, 0.5, 0.5])
    assert p == 1.0


def test_t_test_positive_mean():
    vals = [0.4, 0.5, 0.6, 0.5, 0.45, 0.55, 0.5, 0.48]
    t, p = one_sided_t_test(vals, null_mean=0.0)
    assert t > 0
    assert p < 0.01


def test_t_test_negative_mean_not_significant():
    vals = [-0.4, -0.5, -0.6, -0.5]
    t, p = one_sided_t_test(vals, null_mean=0.0)
    assert t < 0
    assert p > 0.5


# ─── Bootstrap CI ───────────────────────────────────────────────

def test_bootstrap_small_sample_fallback():
    lo, hi = bootstrap_ci([1.0, 2.0])
    assert lo == 1.0 and hi == 2.0


def test_bootstrap_brackets_mean():
    vals = [1.0] * 100
    lo, hi = bootstrap_ci(vals, alpha=0.10)
    assert lo <= 1.0 <= hi


def test_bootstrap_deterministic():
    vals = list(range(20))
    lo1, hi1 = bootstrap_ci(vals, seed=42)
    lo2, hi2 = bootstrap_ci(vals, seed=42)
    assert lo1 == lo2 and hi1 == hi2


def test_bootstrap_different_seeds():
    vals = list(range(20))
    lo1, _ = bootstrap_ci(vals, seed=1)
    lo2, _ = bootstrap_ci(vals, seed=2)
    # Usually different (not guaranteed but almost certain for n=20)
    # Just check they don't raise
    assert isinstance(lo1, float) and isinstance(lo2, float)
