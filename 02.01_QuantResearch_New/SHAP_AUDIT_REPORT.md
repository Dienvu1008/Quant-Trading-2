# SHAP Audit Report
**Project:** 02.01_QuantResearch_New  
**Date:** 2025-01  
**Purpose:** Pre-implementation audit before building the SHAP Analysis Layer

---

## 1. What is the observation unit?

**Answer:** One trade row per `(signalId, trailStyle)` pair in the merged DataFrame.

In the default pipeline mode (`target_mode="production_profit"`), the observation unit is effectively **one trade per signal in the production trailing style** (trailStyle=1 / expansion trailing). All three style rows are present in the raw merged DataFrame but L4/L5 operate on the production-style filtered frame.

In `target_mode="all_styles_win"` mode, the observation unit is **one signal** (deduped by `signalId`, keeping the first row per signal), with the binary target `_all_styles_win`.

**ResearchContract** stores this as `observation_unit: str` — example value: `"1 trade (production_style filtered) per signal"`.

For SHAP purposes:
- **Signal-level view** = deduplicate by `signalId` (N unique signals)
- **Signal×style view** = all three trailStyle rows per signal (3N rows)

---

## 2. How are setup → trades merged?

**Answer:** Three-priority join in `data_loader.merge_funnel_trades()`:

1. **Strategy 1 (preferred):** `signalId + trailStyle` exact join — used when both DataFrames have `signalId`. Produces 3 rows per signal (one per style). Coverage check: if < 10% of trades match, falls back.

2. **Strategy 2:** `ticket` exact join — legacy single-style data.

3. **Strategy 3 (last resort):** `pd.merge_asof` time-based join with tolerance=14,400 sec (4 hours), grouped by `(symbol, setupType)`.

After merge, `_clean()` drops `*_funnel` suffix columns to avoid feature name collisions. The result is sorted by `time`.

Key post-merge columns added:
- `_profit` = copy of `profitUSD` (canonical pipeline profit column)
- `win` = 1 if profitUSD > 0
- `_all_styles_win`, `_all_styles_loss`, `_consensus_profit`, `_style_agree_count` (added by `_build_consensus_targets()`)

VP price levels (vpPOC, vpVAH, vpVAL, etc.) are ATR-normalized by `_normalize_vp_features()`: each level becomes a signed distance from `entryPrice` divided by ATR.

---

## 3. How are 3 execution styles identified?

**Answer:** Via the `trailStyle` column (integer: -1, 0, 1):

| trailStyle | Label | Description |
|---|---|---|
| -1 | `no_trail` | No trailing stop — fixed SL/TP |
| 0 | `conservative` | Narrow trailing stop |
| 1 | `expansion` | Wide trailing (EA default / production style) |

Constants defined in:
- `data_loader.py`: `TRAIL_STYLES = [-1, 0, 1]`, `PRODUCTION_STYLE_DEFAULT = 1`
- `vp_analysis/layers/_constants.py`: `TRAIL_STYLE_LABELS`

`split_by_style(merged, production_style=1)` returns `(production_df, all_styles_df)`.

---

## 4. How is production style determined?

**Answer:** `PRODUCTION_STYLE_DEFAULT = 1` (expansion trailing) in `data_loader.py`.

This is the EA's live trading configuration. In the pipeline:
- L4/L5/L7/L8 use **production style only** (trailStyle==1) for EV, WR, PF metrics
- L10/L10a use **all 3 styles** for canary labeling (MFE max across styles, consensus profit)
- `run_pipeline.py` interactive mode prompts the user to confirm/override this via `_ask_production_style()`

The ResearchContract stores `style_filter: str` (e.g. `"production_style=1"`) as part of the hashed spec.

---

## 5. What is the current target?

**Answer:** Two pre-registered targets in the ResearchContract v3:

| Target | Field | Used by | Description |
|---|---|---|---|
| `edge_discovery_target` | `profitUSD` (production style) | L4, L4b, L5, L7 | Continuous P&L of production-style trade |
| `bad_entry_canary_target` | MFE-based entry quality | L10a | `MFE_max_across_3_styles >= 1.0 ATR` binary |

For SHAP, three targets are supported:
- **Target 1:** `profitUSD` — production style only (trailStyle==1)
- **Target 2:** `_all_styles_win` — binary 1=all 3 styles profitable, dedup by signalId
- **Target 3:** `_consensus_profit` — mean(profitUSD) across 3 styles, dedup by signalId

Internal column `_profit` is the canonical pipeline target (= profitUSD in default mode, = `_all_styles_win` in all_styles_win mode).

---

## 6. Which feature columns are actually allowed?

**Answer:** Features come from `contract.pre_registered` dict (key=category, value=list of feature names). The full registered set from `generate_contract.py` covers:

| Category | Examples | Count |
|---|---|---|
| `vp_levels` | vpPOC, vpVAH, vpVAL, vpDailyPOC, vpCompPOC/VAH/VAL | 7 |
| `vp_structure` | vpInsideVA, vpThinnessRatio, vpMigrationScore, vpUpthrust, vpSpring... | ~17 |
| `auction` | auctAcceptance, auctBalance, auctFailure, auctRegime, auctTradeQuality... | ~19 |
| `vp_longterm` | vpLTTransitionScore, vpLTBalanceStability, vpLTTrendDuration... | ~16 |
| `microstructure` | msCompression, msContext (composite)... | ~5 |
| `orderflow` | ofFlowIntensity, ofContext (composite)... | ~5 |
| `liquidity` | liqSweep, liqContext (composite)... | ~5 |
| `smartmoney` | smZoneQuality, smContext (composite)... | ~4 |
| `structure` | bosQuality, chochQuality, structAlign, trendDirection... | ~5 |
| `market` | spreadToATR, atrProxy, dataQuality... | ~4 |
| `setup` | RR (Risk:Reward ratio) | 1 |
| `interactions` | ix_tq_mig, ix_bos_trend, ix_spread_atr... (10 pre-registered) | 10 |

`L1_boundary.run()` filters these down to `available_features` based on:
- Feature must be present in dev DataFrame
- NA fraction <= 0.30
- std > 1e-9 (no constant columns)
- Not in `_OUTCOME_COLS` (profit/win/signalId/trailStyle/consensus columns)

---

## 7. Which features are excluded due to leakage?

**Answer:** Strictly forbidden outcome columns defined in `L1_boundary._OUTCOME_COLS`:

```python
_OUTCOME_COLS = frozenset({
    "_profit", "profitUSD", "win",         # direct outcome
    "signalId", "trailStyle",              # grouping keys
    "_consensus_profit", "_all_styles_win",
    "_all_styles_loss", "_style_agree_count",  # cross-style outcomes
})
```

Also excluded (post-entry information, never features):
- `exitReason` — used only as bad-entry canary label trigger in L10
- `maeATR` — Maximum Adverse Excursion (post-entry)
- `mfeATR` — Maximum Favorable Excursion (post-entry, used as canary in L10a)
- `exitTime` — post-entry
- `entryTime`, `time` — temporal index, not feature

Additional exclusions for SHAP:
- `SL`, `TP`, `entryPrice` — setup parameters that are partially post-registration (though present pre-entry, they encode optimizer choices, not entry quality signals)
- `spreadPoints`, `avgSpread` — correlated with `spreadToATR` which is already included

**Rule:** SHAP features = `contract.pre_registered` keys, filtered through L1 availability, then minus `_OUTCOME_COLS`.

---

## 8. How is dev/holdout split done?

**Answer:** `DataBoundary.from_merged()` in `vp_analysis/core/data_boundary.py`:

- **Method:** `temporal` (default) — data sorted by `time` column, first `split_ratio` fraction → dev, remainder → holdout
- **Ratio:** `contract.split_ratio` (typically 0.70 = 70% dev / 30% holdout)
- **Leakage guard:** `SealedHoldout` wrapper; only unsealed once per `experiment_id` via `unseal_once(experiment_id, reason, persist_path)`. Access is logged to disk BEFORE data is returned (v3 Fix #4 — crash-safe).
- **Fit-on-dev semantics:** `DataBoundary.apply(transformer)` fits on dev only, transforms both; holdout remains sealed after transform.
- **No random splitting for time-series data** (temporal split preserves temporal order)

---

## 9. How is nested walk-forward implemented?

**Answer:** In `L4_hard_gate_discovery.py`, using `_inner_walk_forward()`:

**Outer walk-forward (5 folds, `outer_folds=5`):**
- Dev data sorted by time
- Each outer fold: `outer_train = dev[:te]`, gap, `outer_test = dev[vs:ve]`
- Gap ratio = 10% of fold size (prevents leakage at fold boundaries)
- Feature rules discovered on outer_train, evaluated on outer_test

**Inner walk-forward (3 folds, `inner_folds=3`) on each outer_train:**
- Purpose: unbiased rule selection (threshold/band search on train, score on val)
- For each inner fold: search threshold on `inner_train`, evaluate on `inner_val`
- Permutation screening on inner_val (100 permutations, p < 0.10)
- Score = `(EV - t_crit * SE) * sqrt(n)` — penalized for small samples
- Best rule per feature = argmax(score) across inner folds

**Outer aggregation:**
- Keep features with >= 2 fold results (`min_folds_results=2`)
- Filter by: mean_EV >= 0.05, fold_consistency >= 0.60, t-test p < 0.05, CI_low > 0, temporal slope not significantly negative

This produces `GateCandidate` objects sent to L6 for FDR correction.

---

## 10. How are permutation tests and FDR implemented?

**Answer:**

### Permutation tests (L4 `_permutation_screen`)
- Inner walk-forward only (not outer)
- 100 permutations (`perm_iterations=100`)
- Early stopping after 30 permutations if running p > 0.30
- Compares observed EV vs shuffled profit EVs → one-tailed p-value
- Acts as a pre-filter (p < 0.10) before outer aggregation

### t-test (L4 outer aggregation)
- One-sided t-test on fold EVs: H0: mean_EV <= 0
- Via `stats_helpers.one_sided_t_test()`
- Bootstrap CI via `stats_helpers.bootstrap_ci()` (1000 iterations)
- Combined with temporal slope test (slope p < 0.15 = evidence of decay)

### FDR correction (L6 `L6_multiple_testing.run()`)
- Method: **Benjamini-Hochberg** (BH) correction
- **4 isolated pools** (from ResearchContract v3):
  1. `hard_gate` — L4 candidates (padded to n_features_searched if conservative_fdr=True)
  2. `soft_gate` — L5 direction candidates
  3. `regime_block` — L4b candidates
  4. `bad_entry` — L10 canary features
- Implemented via `FDRPoolRegistry` in `vp_analysis/core/fdr_registry.py`
- `PoolResult.correct()` returns adjusted p-values and reject/retain decisions
- Post-FDR: economic re-check (min_ev, min_pf, min_wr from ResearchContract.production_criteria)
- For hard gates: additional check `ci_low > 0` (require_ci_low_positive=True)

---

## Summary: Key Constraints for SHAP Layer

| Constraint | Reason |
|---|---|
| Features must come from `contract.pre_registered` filtered by L1 | Prevents undisclosed feature use |
| Targets: profitUSD (prod style), _all_styles_win, _consensus_profit | 3 pre-designed targets |
| NEVER use profitUSD/win/mfeATR/exitReason as SHAP input features | Post-entry information leakage |
| NEVER treat 3 styles as 3 independent signals for entry analysis | 3x count inflation, correlated rows |
| Deduplicate by signalId for signal-level SHAP | Each signal is one entry decision |
| SHAP model trained on dev data only | Holdout sacred |
| SHAP findings → hypothesis_registry.json → L4/L5/L6 validation | SHAP is hypothesis generator, not validator |
| Log experiment_id, hash, seed, params in provenance | Research governance |

---

## Files Audited

| File | Purpose | Key Finding |
|---|---|---|
| `data_loader.py` | Data loading & merge | 3-priority join; signalId+trailStyle keys; ATR normalisation; consensus targets |
| `vp_analysis/pipeline.py` | Orchestrator L0→L11 | _prepare_discovery_df() for target modes; L10 uses raw 3-style df |
| `vp_analysis/pipeline_config.py` | Config dataclass | PipelineConfig with per-layer configs; target_mode field |
| `vp_analysis/layers/L4_hard_gate_discovery.py` | Hard gate discovery | Nested WF; shape priors; permutation screen; GateCandidate output |
| `vp_analysis/layers/L5_soft_gate_discovery.py` | Soft gate discovery | Direction analysis; SoftGateCandidate output |
| `vp_analysis/layers/L6_multiple_testing.py` | FDR correction | BH with 4 pools; economic re-check; FrozenRule output |
| `vp_analysis/layers/L10_bad_entry.py` | Bad entry canary | exitReason-based canary labels; all 3 styles used |
| `vp_analysis/layers/L10a_bad_entry_discovery.py` | MFE canary discovery | MFE threshold (>= 1.0 ATR); per-signal dedup |
| `vp_analysis/core/research_contract.py` | Contract v3 | HASHED_FIELDS; 4 FDR pools; 2 targets; freeze mechanism |
| `vp_analysis/core/data_boundary.py` | Dev/holdout boundary | Temporal split; SealedHoldout; crash-safe persist |
| `run_pipeline.py` | CLI | Interactive + argparse modes; --phase not yet present |
| `generate_contract.py` | Feature registry | Full pre_registered dict with categories and shape priors |
| `vp_analysis/layers/_constants.py` | Shared constants | TRAIL_STYLE_LABELS; DEFAULT_INTERACTION_DEFS (10 pre-registered) |
| `vp_analysis/layers/L1_boundary.py` | Feature availability | _OUTCOME_COLS exclusion; temporal split; availability checks |
