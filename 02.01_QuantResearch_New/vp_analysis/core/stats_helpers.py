"""Statistical helpers for the analysis pipeline.

Pure functions, no state. No dependency on governance types.
"""
from __future__ import annotations

import numpy as np
from scipy import stats


# ─── Multiple testing ───────────────────────────────────────────

def benjamini_hochberg(
    p_values: list[float],
    alpha: float = 0.05,
) -> tuple[np.ndarray, np.ndarray]:
    """Benjamini-Hochberg step-up FDR correction.

    Returns (reject_mask, p_adjusted).
    reject_mask[i] == True  iff  hypothesis i is rejected at level alpha.

    Implements the standard BH procedure consistent with R's p.adjust(method="BH"):
    p_adjusted[k] = min(1, min over j >= k of (n * p_sorted[j] / j))
    where j and k are 1-indexed ranks.
    """
    p = np.asarray(p_values, dtype=float)
    n = len(p)
    if n == 0:
        return np.zeros(0, dtype=bool), np.zeros(0, dtype=float)

    sorted_idx = np.argsort(p)
    sorted_p = p[sorted_idx]

    # p_adj_sorted[i] = min(1, min_{j >= i} (n * sorted_p[j] / (j+1)))
    # where j is 0-indexed (rank is j+1)
    ranks = np.arange(1, n + 1)
    scaled = sorted_p * n / ranks          # n * p_(k) / k  (1-indexed k = rank)

    # cummin from the right: for each position, take the min of scaled[i:]
    p_adj_sorted = np.minimum.accumulate(scaled[::-1])[::-1]
    p_adj_sorted = np.clip(p_adj_sorted, 0.0, 1.0)

    p_adj = np.empty(n, dtype=float)
    p_adj[sorted_idx] = p_adj_sorted

    reject = p_adj <= alpha
    return reject, p_adj


def benjamini_yekutieli(
    p_values: list[float],
    alpha: float = 0.05,
) -> tuple[np.ndarray, np.ndarray]:
    """Benjamini-Yekutieli FDR correction (valid under arbitrary dependence).

    More conservative than BH; use when hypotheses are strongly correlated.
    Equivalent to BH applied with alpha / c_n where c_n = sum(1/k, k=1..n).
    """
    p = np.asarray(p_values, dtype=float)
    n = len(p)
    if n == 0:
        return np.zeros(0, dtype=bool), np.zeros(0, dtype=float)

    c_n = float(np.sum(1.0 / np.arange(1, n + 1)))
    adjusted_alpha = alpha / c_n
    return benjamini_hochberg(p_values, alpha=adjusted_alpha)


def correct_multiple_testing(
    p_values: list[float],
    alpha: float,
    method: str = "benjamini-hochberg",
) -> tuple[np.ndarray, np.ndarray]:
    """Dispatch to the configured correction method."""
    m = method.lower().replace("-", "").replace("_", "")
    if m in ("benjaminihochberg", "bh", "fdrbh"):
        return benjamini_hochberg(p_values, alpha)
    if m in ("benjaminiyekutieli", "by", "fdrby"):
        return benjamini_yekutieli(p_values, alpha)
    raise ValueError(f"Unknown multiple testing method: {method!r}")


# ─── One-sample tests ───────────────────────────────────────────

def one_sided_t_test(
    values: list[float],
    null_mean: float = 0.0,
) -> tuple[float, float]:
    """One-sided t-test  H0: mean <= null_mean,  H1: mean > null_mean.

    Returns (t_stat, p_value).
    Returns (0.0, 1.0) if fewer than 2 observations or zero variance.
    """
    a = np.asarray(values, dtype=float)
    if len(a) < 2:
        return 0.0, 1.0
    se = a.std(ddof=1) / np.sqrt(len(a))
    if se <= 0:
        return 0.0, 1.0
    t = (a.mean() - null_mean) / se
    p = float(stats.t.sf(t, df=len(a) - 1))
    return float(t), p


# ─── Bootstrap ──────────────────────────────────────────────────

def bootstrap_ci(
    values: list[float],
    alpha: float = 0.10,
    n_boot: int = 500,
    seed: int = 42,
) -> tuple[float, float]:
    """Percentile bootstrap CI for the mean.

    alpha=0.10 → 90% CI.
    Falls back to (min, max) for fewer than 3 observations.
    """
    a = np.asarray(values, dtype=float)
    if len(a) < 3:
        return float(a.min()), float(a.max())
    rng = np.random.default_rng(seed)
    means = np.empty(n_boot)
    for i in range(n_boot):
        sample = rng.choice(a, size=len(a), replace=True)
        means[i] = sample.mean()
    lo = float(np.percentile(means, 100 * alpha / 2))
    hi = float(np.percentile(means, 100 * (1 - alpha / 2)))
    return lo, hi
