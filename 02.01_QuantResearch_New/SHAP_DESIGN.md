# SHAP Analysis Layer — Design Document
**Project:** 02.01_QuantResearch_New  
**Layer:** L_SHAP (post-L6 hypothesis generator)  
**Date:** 2025-01  

---

## 1. Purpose

The SHAP Analysis Layer uses SHAP (SHapley Additive exPlanations) values to decompose model predictions into per-feature contributions. It generates **hypotheses** that are then validated through the existing L4 → L5 → L6 FDR pipeline — never bypassing it.

SHAP is a **hypothesis generator**, not a validator. Every SHAP finding must be treated as a new pre-registered hypothesis before acting on it.

---

## 2. Architecture Overview

```
Existing Pipeline:
  L0 → L1 → L2 → L3 → L4 → L5 → L6 → L7 → L8 → L9 → L10 → L10a → L11

SHAP Layer (optional, parallel track):
  data_loader.load_merged()
      ↓
  SHAPDatasetBuilder                 (dev data only, governed by contract)
      ↓
  SHAPModel (LightGBM/XGBoost)       (trained on dev, deterministic seed)
      ↓
  SHAPExplainer                      (TreeExplainer)
      ↓
  ┌─────────────────────────────────────────────────────────┐
  │  SHAP-A: Global importance (mean |SHAP|)               │
  │  SHAP-B: Dependence plots (per-feature)                 │
  │  SHAP-C: Interaction analysis (cross-engine)            │
  │  SHAP-D: Trigger-conditional SHAP (8 triggers)          │
  │  SHAP-E: Regime/context conditional SHAP                │
  │  SHAP-F: Local explanations (winning/losing signals)    │
  │  SHAP-G: Entry edge vs exit policy (3-style)            │
  │  SHAP-H: Feature stability (time/symbol/trigger/fold)   │
  └─────────────────────────────────────────────────────────┘
      ↓
  HypothesisRegistry (hypotheses.json / hypotheses.csv)
      ↓
  → Feed back into L4/L5/L6 as new experiment (separate contract)
```

---

## 3. Data Contract

### 3.1 Input Sources

| Source | Description |
|---|---|
| `merged_df` | Full merged funnel+trades DataFrame (output of `data_loader.load_merged()`) |
| `contract` | Frozen `ResearchContract` — defines allowed features and targets |
| `available_features` | From `L1_boundary.run().available_features()` |
| `boundary` | `DataBoundary` from L2 — provides `dev.data` |

### 3.2 Allowed Columns

**Features (inputs to SHAP model):**
- All columns in `contract.pre_registered` that pass L1 availability check
- Composite features: `bosQuality`, `chochQuality`, `structAlign`, `msContext`, `ofContext`, `liqContext`, `smContext`
- Pre-registered interactions: `ix_tq_mig`, `ix_bos_trend`, etc.

**Forbidden columns (NEVER use as SHAP features):**
```python
SHAP_FORBIDDEN_FEATURES = frozenset({
    # Post-entry outcomes
    "profitUSD", "_profit", "win",
    "mfeATR", "maeATR", "exitReason", "exitTime",
    # Consensus outcomes (cross-style)
    "_all_styles_win", "_all_styles_loss",
    "_consensus_profit", "_style_agree_count",
    # Keys / metadata
    "signalId", "trailStyle", "time", "entryTime",
    "ticket", "symbol", "setupType",
})
```

**Allowed targets (SHAP model output):**
- `profitUSD` (continuous, production style only)
- `_all_styles_win` (binary, dedup by signalId)
- `_consensus_profit` (continuous, dedup by signalId)

### 3.3 Dataset Views

**Signal-level view** (for SHAP-A through SHAP-E, SHAP-H):
- Deduplicate by `signalId`, keep first row
- Features are identical across 3 styles — no information loss
- Target: depends on `target_mode` setting

**Signal×style view** (for SHAP-G only):
- All 3 rows per signal
- Additional column: `trailStyle` as a grouping variable
- Purpose: compare feature contributions across trailing styles

### 3.4 Leakage Prevention

1. **SHAP model trained on dev data only** — holdout is never touched
2. **Feature set bounded by `contract.pre_registered`** — no ad-hoc features
3. **All runs log experiment_id, seed, param hash** via `SHAPProvenance`
4. **Hypotheses are write-once** — once logged, results cannot be silently mutated
5. **No auto-conversion of SHAP findings to EA rules** — outputs are hypotheses only

---

## 4. New Files to Create

```
vp_analysis/shap/
    __init__.py
    shap_config.py          # SHAPConfig dataclass
    shap_dataset.py         # SHAPDatasetBuilder
    shap_model.py           # LightGBM/XGBoost deterministic model
    shap_explainer.py       # SHAP values via TreeExplainer
    shap_global.py          # SHAP-A: global importance
    shap_dependence.py      # SHAP-B: dependence plots
    shap_interaction.py     # SHAP-C: interaction analysis
    shap_conditional.py     # SHAP-D trigger + SHAP-E regime conditional
    shap_local.py           # SHAP-F: local explanations
    shap_execution.py       # SHAP-G: entry edge vs exit policy
    shap_stability.py       # SHAP-H: stability analysis
    hypothesis_registry.py  # Hypothesis accumulator + JSON/CSV output
    shap_report.py          # HTML + markdown summary report
    shap_provenance.py      # Experiment ID, hashes, seed tracking

vp_analysis/layers/
    L_shap.py               # Pipeline integration layer

vp_analysis/tests/
    test_shap_dataset.py
    test_shap_governance.py
    test_shap_leakage.py

run_shap.py                 # Standalone CLI
```

---

## 5. Files to Modify (Minimally)

| File | Change |
|---|---|
| `vp_analysis/pipeline_config.py` | Add `shap: Optional[SHAPConfig] = None` field and import |
| `vp_analysis/pipeline.py` | Add optional SHAP step after L11 |
| `run_pipeline.py` | Add `--phase shap` to argparse in `cli_main()` |

---

## 6. Module Specifications

### 6.1 `shap_config.py` — SHAPConfig

```python
@dataclass
class SHAPConfig:
    target_mode: str = "production_profit"  # "production_profit" | "all_styles_win" | "consensus_profit"
    model_type: str = "lightgbm"            # "lightgbm" | "xgboost"
    n_estimators: int = 200
    max_depth: int = 4
    learning_rate: float = 0.05
    min_child_samples: int = 20             # LGB: prevents overfitting on small data
    subsample: float = 0.8
    colsample_bytree: float = 0.8
    seed: int = 42
    shap_max_samples: int = 1000            # TreeExplainer background sample size
    run_shap_a: bool = True
    run_shap_b: bool = True
    run_shap_c: bool = False                # interaction values are expensive
    run_shap_d: bool = True
    run_shap_e: bool = True
    run_shap_f: bool = True
    run_shap_g: bool = True
    run_shap_h: bool = True
    n_local_top: int = 20                   # top N winning/losing for local explanations
    stability_n_folds: int = 4              # temporal folds for SHAP-H
    min_trigger_samples: int = 30           # minimum per trigger for SHAP-D
    min_regime_samples: int = 30            # minimum per regime for SHAP-E
    output_plots: bool = True              # generate matplotlib figures
    n_dependence_top: int = 15             # top-N features for dependence plots
```

### 6.2 `shap_dataset.py` — SHAPDatasetBuilder

**Responsibilities:**
- Accept dev DataFrame + contract + available_features
- Strip forbidden columns
- Build signal-level view (dedup by signalId)
- Build signal×style view (for SHAP-G)
- Compute target column based on target_mode
- Return typed `SHAPDataset` with feature matrix and target vector

**Key function:**
```python
def build_shap_dataset(
    dev_df: pd.DataFrame,
    contract: ResearchContract,
    available_features: list[str],
    target_mode: str = "production_profit",
    production_style: int = 1,
) -> SHAPDataset:
    ...
```

**SHAPDataset dataclass:**
```python
@dataclass
class SHAPDataset:
    X: pd.DataFrame          # feature matrix (signal-level, no leakage)
    y: pd.Series             # target vector
    feature_names: list[str]
    target_name: str
    n_signals: int
    n_features: int
    target_mode: str
    style_df: Optional[pd.DataFrame]  # for SHAP-G: signal×style view
    meta: dict               # provenance metadata
```

### 6.3 `shap_model.py` — SHAPModel

**Responsibilities:**
- Fit LightGBM or XGBoost with fully deterministic configuration
- Store feature importances (gain-based)
- Persist model to disk (joblib)
- Load model from disk

**Configuration:**
- `random_state=seed` for all randomized components
- `n_jobs=1` for determinism
- Fixed hyperparameters from SHAPConfig
- No cross-validation or hyperparameter search (SHAP is hypothesis generation, not optimization)

**Note:** Model purpose is feature attribution, not prediction — slight underfitting is acceptable.

### 6.4 `shap_explainer.py` — SHAPExplainer

**Responsibilities:**
- Compute SHAP values via `shap.TreeExplainer`
- Background dataset = min(shap_max_samples, len(X)) random rows from dev X
- Return `SHAPExplanation` with raw values and expected value

```python
@dataclass
class SHAPExplanation:
    shap_values: np.ndarray      # shape (n_samples, n_features)
    expected_value: float
    feature_names: list[str]
    interaction_values: Optional[np.ndarray]  # shape (n, n, n_features) or None
```

### 6.5 `shap_global.py` — SHAP-A: Global Importance

**Output:** `global_importance.csv`

Columns: `feature, category, mean_abs_shap, rank, mean_shap (signed)`

Sorted by `mean_abs_shap` descending. Includes feature category from `contract.pre_registered`.

Also outputs `global_importance.png` (horizontal bar chart, top-20 features).

**Hypothesis generation:** For features in top-K by mean |SHAP|, generate:
```json
{
  "type": "global_importance",
  "feature": "...",
  "rank": 1,
  "mean_abs_shap": 0.123,
  "hypothesis": "Feature X is a strong predictor → validate gate via L4/L5"
}
```

### 6.6 `shap_dependence.py` — SHAP-B: Dependence Analysis

**Per-feature analysis identifying:**
- **Monotonic up/down:** SHAP increases/decreases with feature value
- **Band:** SHAP peaks in a middle range (band gate candidate)
- **Saturation:** SHAP plateaus above/below threshold
- **Nonlinear/inverted-U/V:** Complex relationship
- **Flat/noise:** No discernible pattern

**Output per feature:** `dependence/{feature}_dependence.csv`, `dependence/{feature}_dependence.png`

**Summary:** `dependence_summary.csv` with columns: `feature, shape_detected, correlation, p_value, shap_range, n`

**Hypothesis generation:** `shape_detected` translates to a `shape_prior` suggestion for L4 gate search.

### 6.7 `shap_interaction.py` — SHAP-C: Interaction Analysis

**Requires:** `shap.TreeExplainer(model).shap_interaction_values(X)`

**Output:** `interactions.csv` with columns: `feature_a, feature_b, mean_abs_interaction, rank`

**Filters:** Top-20 interactions by mean absolute interaction value.

**Cross-engine focus:** Flags interactions between features from different engine categories (VP × auction, auction × structure, etc.).

**Hypothesis generation:** Cross-engine interactions suggest new interaction features to pre-register.

### 6.8 `shap_conditional.py` — SHAP-D and SHAP-E

**SHAP-D: Trigger-conditional SHAP**

Slice the dataset by `setupType` column (8 triggers in the EA):
- For each trigger with >= `min_trigger_samples` rows, compute subset SHAP
- Compare global importance vs trigger-specific importance
- Identify features that are important only for specific triggers

**Output:** `trigger_conditional/{trigger}_importance.csv`, `trigger_conditional/trigger_comparison.csv`

**SHAP-E: Regime-conditional SHAP**

Slice by `auctRegime` (0–8):
- For each regime with >= `min_regime_samples` rows, compute subset SHAP
- Identify regime-specific feature importance
- Flag features that switch sign across regimes (regime interaction effect)

**Output:** `regime_conditional/{regime}_importance.csv`, `regime_conditional/regime_comparison.csv`

### 6.9 `shap_local.py` — SHAP-F: Local Explanations

**For top-N winning and bottom-N losing signals:**
- Compute per-row SHAP waterfall
- Identify features driving the win/loss
- Aggregate: what features are consistently in top-3 for winning signals?

**Output:** `local/winning_top{N}.csv`, `local/losing_top{N}.csv`, `local/local_summary.csv`

Columns: `signalId, target, feature_rank_1..5, shap_rank_1..5, time, symbol, setupType`

### 6.10 `shap_execution.py` — SHAP-G: Entry Edge vs Exit Policy

**Purpose:** Separate entry quality from trailing style effect.

**Method:**
1. Train 3 separate SHAP models, one per trailStyle (-1, 0, 1)
2. Compare feature importances across styles
3. Features with consistent importance across all 3 styles = entry quality signals
4. Features with style-dependent importance = exit policy confounds

**Output:** `execution_policy/style_comparison.csv`, `execution_policy/entry_quality_features.csv`

Columns: `feature, shap_no_trail, shap_conservative, shap_expansion, cv_across_styles, consistent_entry_feature`

**cv_across_styles = coefficient of variation of mean|SHAP| across 3 styles**

Low CV → consistent entry quality feature (good hypothesis for L4)
High CV → style-dependent (exit policy confound, not good for entry gate)

### 6.11 `shap_stability.py` — SHAP-H: Stability Analysis

**Purpose:** Check if SHAP rankings are stable or noisy (temporal drift, symbol variation, fold sensitivity).

**4 stability dimensions:**

1. **Temporal stability:** Split dev into `stability_n_folds` temporal folds, compute SHAP per fold, measure rank correlation (Spearman) across folds
2. **Symbol stability:** If multiple symbols, compute SHAP per symbol, measure rank correlation
3. **Trigger stability:** SHAP per setupType, measure consistency
4. **Fold stability:** Random subsamples (5 × 80% of data), measure rank stability

**Output:** `stability/temporal_stability.csv`, `stability/symbol_stability.csv`, `stability/trigger_stability.csv`, `stability/fold_stability.csv`, `stability/stability_summary.csv`

**Stability score per feature:** mean Spearman rank correlation across stability dimensions.

Low stability → feature SHAP importance is unreliable (caution hypothesis).

### 6.12 `hypothesis_registry.py` — Hypothesis Registry

**Purpose:** Accumulate all SHAP-derived hypotheses into a structured registry for downstream L4/L5/L6 validation.

```python
@dataclass
class SHAPHypothesis:
    hypothesis_id: str       # sha256 of (feature, type, direction, threshold)
    source: str              # "SHAP-A" | "SHAP-B" | ... | "SHAP-H"
    feature: str
    category: str
    hypothesis_type: str     # "global_importance" | "dependence_shape" | "interaction" | ...
    suggested_direction: int # +1 / -1 / 0
    suggested_shape: str     # "MONO_UP" | "MONO_DOWN" | "BAND" | ...
    evidence_strength: float # mean |SHAP| or stability score
    n_samples: int
    description: str
    metadata: dict
    generated_at: str
    experiment_id: str
```

**Output:** `hypotheses.json` (all hypotheses), `hypotheses.csv` (tabular summary)

### 6.13 `shap_report.py` — Reporting

**Generates:**
1. `shap_report.html` — Interactive HTML with embedded plots and summary tables
2. `shap_summary.md` — Markdown summary for quick review

**Content:**
- Run metadata (experiment_id, timestamp, n_signals, n_features, model performance)
- SHAP-A: Top-20 features by global importance (table + plot)
- SHAP-B: Dependence shape summary per feature
- SHAP-C: Top interaction pairs (if computed)
- SHAP-D: Trigger-conditional importance differences
- SHAP-E: Regime-conditional importance differences  
- SHAP-F: Common drivers of winning vs losing signals
- SHAP-G: Entry quality vs exit policy features
- SHAP-H: Stability scores heatmap
- Hypotheses: count and top-10 by evidence strength
- **Null result section:** If no features show consistent signal → "null result logged"

### 6.14 `shap_provenance.py` — Provenance Tracking

```python
@dataclass
class SHAPRunMeta:
    experiment_id: str       # UUID or hash
    parent_pipeline_id: Optional[str]
    shap_config_hash: str
    dataset_hash: str        # hash of X matrix
    model_hash: str          # hash of fitted model weights
    code_hash: str           # hash of shap/ module files
    feature_names_hash: str
    target_name: str
    n_dev_rows: int
    n_signals: int
    n_features: int
    seed: int
    model_type: str
    ran_at: str
    elapsed_sec: float
    warnings: list[str]
```

Saved as `run_meta.json` in each output directory.

---

## 7. Integration Points

### 7.1 Pipeline Integration (L_shap.py)

Called optionally after L11 in `pipeline.py`:

```python
if cfg.shap is not None:
    l_shap = _safe_step("L_shap", lambda: L_shap.run(
        dev_df=dev_df,
        contract=contract,
        available_features=list(l1.available_features()),
        experiment_id=eid,
        output_dir=exp_dir / "L_shap",
        config=cfg.shap,
    ), result, exp_dir)
```

### 7.2 CLI Extension (run_pipeline.py)

Add to argparse in `cli_main()`:
```
--phase shap   Run only the SHAP layer for an existing experiment
```

### 7.3 Standalone CLI (run_shap.py)

Independent entry point for SHAP analysis without running the full pipeline:
```
python run_shap.py \
    --symbols XAUUSDm \
    --start 01.2025 --end 12.2025 \
    --contract contracts/my_contract.yaml \
    --target production_profit \
    --output output/shap
```

---

## 8. Output Structure

```
output/shap/<experiment_id>/
    run_meta.json                    # SHAPRunMeta
    model/
        model.joblib                 # fitted model
        model_params.json            # hyperparameters
    global_importance.csv            # SHAP-A
    global_importance.png
    dependence/
        <feature>_dependence.csv     # SHAP-B, per feature
        <feature>_dependence.png
        dependence_summary.csv
    interactions.csv                 # SHAP-C
    trigger_conditional/             # SHAP-D
        <trigger>_importance.csv
        trigger_comparison.csv
    regime_conditional/              # SHAP-E
        <regime>_importance.csv
        regime_comparison.csv
    local/                           # SHAP-F
        winning_top20.csv
        losing_top20.csv
        local_summary.csv
    execution_policy/                # SHAP-G
        style_comparison.csv
        entry_quality_features.csv
    stability/                       # SHAP-H
        temporal_stability.csv
        symbol_stability.csv
        trigger_stability.csv
        fold_stability.csv
        stability_summary.csv
    hypotheses.json                  # HypothesisRegistry
    hypotheses.csv
    shap_report.html
    shap_summary.md
```

---

## 9. Leakage Prevention Strategy

| Risk | Mitigation |
|---|---|
| Post-entry features in model | `SHAP_FORBIDDEN_FEATURES` filter in `SHAPDatasetBuilder`; assertion check in governance tests |
| 3-style inflation for entry analysis | Signal-level dedup by `signalId` in `build_shap_dataset()` |
| Using holdout for SHAP model fitting | `SHAPDatasetBuilder` only accepts `boundary.dev.data`; never calls `holdout.unseal_once()` |
| Model selection / hyperparameter tuning on dev | Fixed hyperparameters from `SHAPConfig` — no search |
| SHAP findings directly converted to rules | `HypothesisRegistry` outputs are labeled as "hypotheses, not validated"; `shap_report` includes disclaimer |
| Silent experiment identity change | `SHAPRunMeta.shap_config_hash` hashes config; any change = new experiment_id |

---

## 10. 3-Style Handling Strategy

| Analysis | Style handling | Reason |
|---|---|---|
| SHAP-A, B, C, D, E, F, H | Signal-level dedup (trailStyle=first) | Entry features are identical across styles; dedup prevents 3x weight inflation |
| SHAP-G | All 3 rows, grouped by trailStyle | Purpose is to compare feature contributions BY style |
| SHAP model training | Signal-level (production style target) OR dedup+consensus | Depends on `target_mode` |

---

## 11. FDR Integration Plan

SHAP hypotheses flow into the existing FDR pipeline as follows:

1. `hypotheses.json` lists all SHAP-derived candidate features with suggested `shape_prior` and `direction`
2. User reviews `hypotheses.json` and selects features to formally test
3. Selected features are added to a **new ResearchContract** `pre_registered` dict
4. A new experiment runs with these features through L4 → L5 → L6 (BH FDR correction)
5. Only L6-validated features become FrozenRules → L7/L8 → holdout apply

**SHAP does NOT bypass FDR.** It only provides a prioritized list of what to test next.

---

## 12. Null Result Support

If no features show consistent signal:
- `HypothesisRegistry` may be empty or contain only low-evidence hypotheses
- `shap_report.html` explicitly states "Null result: no actionable hypotheses identified"
- `shap_summary.md` includes null result section
- `run_meta.json` includes `null_result: true` flag

This is a valid and expected outcome. The pipeline does not treat null results as failures.

---

## 13. Dependencies

| Package | Purpose | Notes |
|---|---|---|
| `shap` | SHAP values | `pip install shap` |
| `lightgbm` | LightGBM model | `pip install lightgbm` |
| `xgboost` | XGBoost model (optional) | `pip install xgboost` |
| `joblib` | Model persistence | Usually bundled with scikit-learn |
| `matplotlib` | Plot generation | Already available |
| `pandas`, `numpy` | Data manipulation | Already available |
| `scipy` | Spearman correlation | Already available |

All packages must be pinned in requirements when deploying.
