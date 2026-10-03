# SPECIFICATION v4 — Analysis Pipeline với Governance Kernel

> **Changelog v4 (so với v3):**
> - **[v4-1] Target mode có thể cấu hình:** Pipeline hỗ trợ hai chế độ discovery target — `production_profit` (profitUSD của production trailing style, như cũ) và `all_styles_win` (binary: 1 nếu ALL 3 trailing styles có lãi — đo chất lượng entry thuần túy). Khi dùng `all_styles_win`, dev data được dedup theo `signalId` (1 row/signal) trước L4/L5 để tránh inflate 3x.
> - **[v4-2] L10 (exit-reason canary) là per-(symbol, setup):** Thay vì global threshold, L10 chạy riêng cho từng nhóm `(symbol, setupType)` (tối thiểu 30 signal có label). Output chuyển sang định dạng grouped JSON với `global_fallback`.
> - **[v4-3] L10a (MFE-based canary) cũng là per-(symbol, setup):** Cùng cơ chế như L10. Groups từ L10 và L10a được merge trong `generate_guards_direct.py`.
> - **[v4-4] Bad-entry SL threshold có thể cấu hình:** Tham số `bad_sl_threshold` trong `BadEntryConfig` — `1` (strict, ~85% flagged) hoặc `2` (balanced, ~79% flagged, default). Được hỏi interactive khi chạy pipeline.
> - **[v4-5] VPBadEntryVote thay thế VPIsBadEntry:** EA dùng pattern vote accumulator với globals `_g_bev_votes`, `_g_bev_sym`, `_g_bev_stp` và 3 lệnh: `__reset__`, `__vote__`, `__check__`.
> - **[v4-6] EA EdgeGuard pipeline có 9 bước:** Step 9 mới — bad-entry filter (VPBadEntryVote) dùng kết quả L10/L10a canary.
> - **[v4-7] Soft tilt áp vào winProbability:** Output của `VPGetEdgeTiltMultiplier` được nhân vào `m_state.winProbability`. EA input mới `InpMinTiltThreshold` block trade khi cumulative tilt < threshold.
> - **[v4-8] Feature consensus targets:** `_build_consensus_targets()` trong `data_loader.py` tính 4 cột per-signal (`_all_styles_win`, `_all_styles_loss`, `_consensus_profit`, `_style_agree_count`). Được loại khỏi feature discovery nhưng dùng trong `--cross-style-filter`.
> - **[v4-9] `generate_guards_direct.py` cập nhật lớn:** `--max-soft` mặc định tăng lên 5000, auto-detect tilt scale, load cả L10 và L10a rồi merge groups, thêm `--cross-style-filter`.
> - **[v4-10] FDR pool sizes tăng lên 10000:** `hard_gate`, `soft_gate`, `regime_block` → 10,000; `bad_entry` → 5,000.
> - **[v4-11] Pipeline interactive prompts:** 2 prompt mới: chọn gate discovery target và SL threshold cho L10 canary.
> - **[v4-12] L10 và L10a đều chạy trên `dev_df_3style`:** Cả hai dùng data 3-style gốc (trước `_prepare_discovery_df`), được lưu trong `pipeline.py` dưới tên `dev_df_3style`.

---

# PHẦN 1 — NGUYÊN TẮC GỐC

## 1.1. Information Boundary (P1 - hardened)

```text
P1 — INFORMATION BOUNDARY

Holdout KHÔNG ĐƯỢC ảnh hưởng tới bất kỳ:
  - feature engineering
  - feature availability check
  - feature selection
  - shape classification / verification
  - hyperparameter tuning
  - threshold / band search
  - model training
  - target definition
  - FDR correction
  - rule selection
  - rule validation
  - SL/TP optimization
  - sizing calibration
  - SL risk threshold discovery
  - regime block discovery
  - bad-entry canary labeling
  - production decision

Holdout CHỈ ĐƯỢC:
  - APPLY (áp dụng frozen artifacts)
  - MEASURE (đo kết quả)
  - REPORT (ghi báo cáo)
  - ATTRIBUTE (phân tích attribution — không mutate artifacts)
```

## 1.2. Separation of Concerns (P2)

```text
DISCOVERY ≠ VALIDATION ≠ OPTIMIZATION ≠ EVALUATION ≠ ATTRIBUTION

DISCOVERY:     tìm candidate từ dev  (L4, L4b, L5, L10a, L10)
VALIDATION:    test statistical significance, FDR  (L6)
OPTIMIZATION:  tune parameters trong không gian pre-registered  (L7a, L7b, L7c)
EVALUATION:    đo performance trên holdout  (L8, L10b)
ATTRIBUTION:   giải thích kết quả  (L9)
```

## 1.3. Immutable Freeze (P3)

```text
Sau khi một artifact được freeze:
  - Không mutate
  - Không replace
  - Không patch
  - Chỉ tạo version mới nếu cần thay đổi

Artifacts cần freeze:
  - Research Contract
  - SHAPE_PRIORS
  - Split definition
  - FDR pools (kể cả n_total_hypotheses — cố định trước L4)
  - Rules (FrozenRule — sau L6)
  - Regime block rules (sau L6)
  - SL/TP selection (sau L7a)
  - SL risk thresholds (sau L7c)
  - Sizing parameters (sau L7b)
  - Bad-entry canary groups (sau L10/L10a — per-group format)   [v4-2, v4-3]
```

## 1.4. Null Result Protocol (P4)

```text
NULL RESULT là kết quả hợp lệ.

Pipeline PHẢI cho phép:
  - 0 rules discovered
  - 0 rules FDR-pass
  - 0 rules holdout-confirmed

KHÔNG ĐƯỢC:
  - Rerun với config modified sau khi thấy null
  - Đổi SHAPE_PRIORS sau khi thấy EDA mismatch
  - Đổi threshold logic sau khi thấy kết quả
  - Coi null result là "pipeline failure"

Nếu null: thu thập thêm data → new experiment
Nếu null: đợi regime mới → new experiment
KHÔNG: tune cho đến khi có kết quả
```

---

# PHẦN 2 — RESEARCH CONTRACT (Layer −1)

## 2.1. Cấu trúc

```yaml
research_contract:
  version: "v1"
  created_at: "2026-09-18T..."

  # Identity hashes (immutable sau khi start)
  dataset:
    dataset_hash: "sha256:..."
    observation_unit: "1 trade (production_style filtered) per signal"
    time_range: ["2024-01-01", "2026-08-31"]
    style_filter: "production_style=1"

  code:
    code_hash: "sha256:..."
    hashed_paths:
      - "vp_analysis/core/*.py"
      - "vp_analysis/layers/*.py"
    excluded_paths:
      - "**/test_*.py"
      - "**/*.md"
      - "**/notebooks/*"

  config:
    config_hash: "sha256:..."

  feature_registry:
    feature_registry_hash: "sha256:..."
    pre_registered: [...]
    feature_direction: {...}
    shape_priors: {...}

  # [v4-1] Target mode được chọn interactive khi chạy pipeline.
  # Hai modes:
  #   production_profit: profitUSD của production trailing style (như v3)
  #   all_styles_win:    binary 1/0 — 1 nếu ALL 3 trailing styles profitable
  #                      Dev data dedup theo signalId trước L4/L5 khi dùng mode này.
  targets:
    edge_discovery_target:
      name: "profitUSD"
      mode: "production_profit | all_styles_win"   # chọn runtime
      definition_production_profit: "profitUSD of production-style trade"
      definition_all_styles_win: "1 if all 3 trailing styles profitable else 0"
      # Dùng bởi: L4 (hard gate discovery), L5 (soft gate), L4b (regime blocks), L7
      used_by: ["L4", "L4b", "L5", "L7"]

    bad_entry_canary_target:
      name: "MFE-based entry quality"
      definition: "MFE_max_across_3_styles >= 1.0 ATR"
      # Dùng bởi: L10a (bad-entry canary labeling) — cần merged_all triplets
      used_by: ["L10a", "L10"]

    # [v4-8] Consensus targets (computed, not discovery features)
    consensus_targets:
      _all_styles_win:   "1.0 if all 3 styles profitable"
      _all_styles_loss:  "1.0 if all 3 styles lose"
      _consensus_profit: "mean profit across 3 styles"
      _style_agree_count: "number of profitable styles (0-3)"
      # Loại trừ khỏi feature discovery (outcome columns)
      # Chỉ dùng bởi generate_guards_direct.py --cross-style-filter
      exclude_from_features: true

    target_definition_hash: "sha256:..."

  split:
    split_method: "temporal"
    split_ratio: 0.70
    split_time: null                     # computed at runtime
    split_definition_hash: "sha256:..."

  # Hypothesis families (pre-registered)
  hypothesis_families:
    gate_types: ["threshold", "band", "monotone"]
    allowed_directions: [1, -1, 0]
    allowed_interactions: [...]
    shape_prior_policy: "immutable_verify_only"
    regime_block_families:
      - type: "auction_regime"
      - type: "auction_failure"
      - type: "regime_session"
      - type: "regime_lt_transition"

  # Statistical tests (pre-registered)
  statistical_tests:
    primary: "one-sided t-test on fold EVs"
    screening: "permutation, 100 iter, early stop p>0.30"
    multiple_testing: "Benjamini-Hochberg, alpha=0.05"
    effect_size: ["EV_lift", "Cohen_d", "PF"]

  # [v4-10] FDR pools — pool sizes tăng lên 10,000.
  # n_total_hypotheses là số hypotheses ATTEMPTED ở L4/L4b/L5/L10a,
  # được tính và frozen tại đầu mỗi layer trước khi search bắt đầu.
  fdr_pools:
    hard_gate:
      alpha: 0.05
      pool_size: 10000      # [v4-10] tăng từ (dynamic) lên 10,000
      description: "L4 nested WF candidates — t-test p on fold EVs"
    soft_gate:
      alpha: 0.05
      pool_size: 10000      # [v4-10] tăng lên 10,000
      description: "L5 soft gate candidates — permutation p on dev"
    regime_block:
      alpha: 0.05
      pool_size: 10000      # [v4-10] tăng lên 10,000
      description: "L4b regime block candidates — permutation p on dev"
    bad_entry:
      alpha: 0.05
      pool_size: 5000       # [v4-10] tăng lên 5,000
      description: "L10/L10a bad-entry features — binomial p on dev"

  # [v4-4] Bad-entry config
  bad_entry_config:
    bad_sl_threshold: 2     # 1=strict (~85% flagged), 2=balanced (~79%, default)
    # Được override bởi _ask_sl_threshold() trong run_pipeline.py

  # Optimization budget — pre-registered, NOT hypothesis testing
  optimization_budget:
    sl_candidates: [1.0, 1.5, 2.0]
    tp_candidates: [1.0, 1.5, 2.0]
    sizing_configs: 5
    utility_function: "expectancy"
    tiebreaker: ["sl_atr DESC", "tp_atr DESC"]

  selection_budget:
    max_experiments_per_dataset: 5
    max_contract_changes_per_day: 3
    cooldown_hours_between_experiments: 24
    max_eda_inspect_and_rerun: 1
    config_frozen_after_start: true

  stopping_rules:
    min_group_samples: 30
    min_fold_consistency: 0.60
    min_effect_size: 0.05
    max_outer_folds: 5
    max_inner_folds: 3

  production_criteria:
    min_ev: 0.05
    min_pf: 1.10
    min_wr: 0.35
    require_robust_across_styles: false
    require_holdout_confirmation: true

  research_contract_hash: "sha256:..."
```

## 2.2. Enforcement rules

```text
Rule 1: Contract phải tồn tại TRƯỚC khi pipeline chạy.
Rule 2: Bất kỳ thay đổi nào trong các hashes → experiment_id mới.
Rule 3: Contract v1 không được overwrite. Tạo v2.
Rule 4: Mọi layer phải validate contract trước khi chạy.
Rule 5: Selection budget được kiểm tra runtime.
Rule 6: n_total_hypotheses phải được log vào run_meta.json ngay khi computed.
Rule 7: Hai targets (edge_discovery, bad_entry_canary) phải được dùng đúng layer.
Rule 8: [v4-1] target_mode được log vào run_meta.json và không được thay đổi sau
        khi pipeline bắt đầu chạy.
Rule 9: [v4-2/3] Bad-entry canary output dùng grouped format; global_fallback bắt
        buộc phải có nếu có bất kỳ group nào.
```

---

# PHẦN 3 — DANH SÁCH PHÂN TÍCH CHI TIẾT

Chia thành 15 layer. Mỗi layer ghi rõ: input là `dev` hay `holdout`, và target nào được dùng.

## LAYER −1 — Research Contract

### −1.1. Contract construction
**Input:** config yaml + feature registry + target definitions (2 targets + consensus)
**Output:** `research_contract.json`, `research_contract_hash`

### −1.2. Contract validation
**Input:** contract hash
**Output:** `validation_report.json`
**Fail action:** Halt pipeline

---

## LAYER 0 — Data Hygiene

**Input:** `merged_all` (TẤT CẢ 3 styles, trước split)
**Note:** L0 cần `merged_all` đầy đủ vì L10/L10a cần triplet consistency check.

### 0.1. Cross-style entry consistency
```python
for signal_id in unique_signals:
    trades = df[df.signalId == signal_id]
    assert trades.entry_time.nunique() == 1
    assert abs(trades.MAE.max() - trades.MAE.min()) < tol
    assert abs(trades.MFE.max() - trades.MFE.min()) < tol
```
**Fail action:** Halt — data collection bug
**Note thực tế:** EA mở 3 lệnh per signal tại các tick khác nhau, nên entryPrice và
entryTime hợp lệ khác nhau. Cấu hình `HygieneConfig(halt_on_entry_inconsistency=False)`
để phù hợp với thiết kế 3-style.

### 0.2. MAE/MFE sanity
- MAE ≥ 0, MFE ≥ 0
- MAE, MFE ≤ 10 × ATR
- `-MAE ≤ profit ≤ MFE`
**Note:** EA chưa log maeATR/mfeATR — cấu hình `halt_on_mae_mfe_violation=False`.

### 0.3. Time alignment
Verify entry ≤ exit, no NaT.

**Output:** `L0_hygiene/` reports

---

## LAYER 1 — Boundary & Split

### 1.1. Dev/Holdout split
```python
# Split trên production-style subset (cho L4/L5/L4b)
prod_df = split_by_style(merged_all, production_style)
split_idx = int(len(prod_df) * (1 - OOS_RATIO))
split_time = prod_df["time"].iloc[split_idx]
dev = DevelopmentData(prod_df.iloc[:split_idx])
holdout = SealedHoldout(prod_df.iloc[split_idx:])

# merged_all (3-style) cũng được split tại cùng split_time cho L10/L10a
dev_all_styles = merged_all[merged_all["time"] < split_time]
# [v4-12] dev_df_3style = dev_all_styles — lưu riêng trong pipeline.py,
# dùng cho cả L10 và L10a (trước _prepare_discovery_df transform)
```

### 1.2. Feature availability
**Input:** `dev` ONLY

### 1.3. Consensus targets construction
**[v4-8]** `_build_consensus_targets()` được gọi tại L1 trên `dev_all_styles`:
```python
def _build_consensus_targets(df_3style):
    """
    Tính 4 cột per-signal từ 3-style data.
    Kết quả được join vào dev_df_3style nhưng loại trừ khỏi feature discovery.
    """
    pivot = df_3style.groupby("signalId").agg(
        n_profit = ("profitUSD", lambda x: (x > 0).sum()),
        mean_profit = ("profitUSD", "mean"),
    )
    pivot["_all_styles_win"]    = (pivot["n_profit"] == 3).astype(float)
    pivot["_all_styles_loss"]   = (pivot["n_profit"] == 0).astype(float)
    pivot["_consensus_profit"]  = pivot["mean_profit"]
    pivot["_style_agree_count"] = pivot["n_profit"]
    return pivot[["_all_styles_win","_all_styles_loss",
                  "_consensus_profit","_style_agree_count"]]
```
Các cột này được đánh dấu là outcome columns và **loại trừ khỏi avail_features**.

### 1.4. Config snapshot + n_total_hypotheses pre-computation
```python
# Tính và log n_total_hypotheses ngay tại L1, trước khi search bắt đầu.
n_groups = count_groups(dev, by=["symbol", "setupType"])
n_features = len(available_features)  # từ L1.2

# [v4-1] Khi target_mode == "all_styles_win", dev data dedup theo signalId
# trước khi tính n_total để đảm bảo tính nhất quán
if target_mode == "all_styles_win":
    n_discovery_rows = dev_all_styles.drop_duplicates("signalId").__len__()
else:
    n_discovery_rows = len(dev)

n_total_hard_gate  = n_features * n_groups
n_regime_combos    = len(unique_regimes) * n_groups
n_total_regime_block = n_regime_combos

run_meta["n_total_hypotheses"] = {
    "hard_gate":    n_total_hard_gate,
    "soft_gate":    n_features * n_groups,
    "regime_block": n_total_regime_block,
    # bad_entry: tính riêng trong L10/L10a
}
run_meta["target_mode"] = target_mode      # [v4-1] log target mode
run_meta["bad_sl_threshold"] = bad_sl_threshold  # [v4-4] log SL threshold
# Freeze ngay — không được thay đổi sau khi L4 bắt đầu.
```

**Output:** `run_meta.json`, `feature_availability.csv`

---

## LAYER 2 — Feature Engineering (Fit on Dev)

### 2.1. Fit interaction scaler
**Input:** `dev` ONLY
**Method:**
```python
stats = fit_interaction_scaler(dev)
dev_fe = apply_interactions(dev, stats)
holdout_fe = apply_interactions(holdout, stats)   # transform, không fit
dev_all_fe = apply_interactions(dev_all_styles, stats)  # cho L10/L10a
# [v4-12] dev_df_3style được transform nhưng consensus targets được giữ nguyên
```
**Output:** `interaction_stats.json`

### 2.2. Verify scaler provenance
Log `fit_source = "development"`.

---

## LAYER 3 — EDA & Shape Verification

**Input:** `dev` ONLY  **Target:** không dùng target — chỉ đo EV-by-bin.

### 3.1. EV-by-bin histogram (10 bins)
### 3.2. SHAPE_PRIOR verification
```text
Nếu observed_shape != prior_shape:
  FLAG for review
  KHÔNG override SHAPE_PRIOR
  KHÔNG rerun cùng experiment với shape mới
  Options:
    a) Keep prior, note mismatch, proceed
    b) Invalidate experiment, new contract với shape mới
```
### 3.3. Feature correlation matrix
### 3.4. Temporal stability (5 blocks)
### 3.5. Baseline statistics

**Output:** `L3_eda/` reports

---

## LAYER 4 — Hard Gate Discovery (Nested WF)

**Input:** `dev` ONLY
**Target:** `profitUSD` (production_profit mode) **hoặc** `_all_styles_win` (all_styles_win mode)
**[v4-1]** Khi `target_mode == "all_styles_win"`, `_prepare_discovery_df()` dedup
dev data theo `signalId` (1 row/signal) trước khi search bắt đầu — tránh inflate 3x.

### 4.1. Target preparation
```python
def _prepare_discovery_df(dev_df, target_mode, dev_df_3style):
    """
    Trả về df đúng với target được chọn.
    - production_profit: trả về dev_df (production-style, 1 row/signal)
    - all_styles_win:    join consensus targets vào dev_df_3style
                         rồi dedup theo signalId → 1 row/signal
    """
    if target_mode == "all_styles_win":
        consensus = _build_consensus_targets(dev_df_3style)
        df = dev_df_3style.merge(consensus, on="signalId", how="left")
        df = df.drop_duplicates("signalId")
        df["_target"] = df["_all_styles_win"]
    else:
        df = dev_df.copy()
        df["_target"] = df["profitUSD"]
    return df
```

### 4.2. Shape-aware search initialization
```python
# Dùng SHAPE_PRIORS từ contract — không dùng observed_shape từ L3.
for feature in avail_features:
    shape = SHAPE_PRIORS[feature]
    search_config = {"MONO_UP": {"type":"threshold","direction":+1},
                     "MONO_DOWN": {"type":"threshold","direction":-1},
                     "BAND": {"type":"band"}}[shape]
```

### 4.3. Nested walk-forward
```text
OUTER WF (5 folds, gap 10%):
  outer_train = dev.iloc[:te]
  outer_test  = dev.iloc[vs:ve]

  INNER WF (3 folds, gap 10%) trên outer_train:
    inner_train → threshold/band search  (NO inner_val)
    inner_val   → evaluate candidate (rule fixed, no mutation)
    → permutation screening (100 iter, early stop)
    → score = (EV - t·SE)·√n

  Apply best inner rule → outer_test  (no mutation)
  Record: ev, wr, pf, n
```

### 4.4. Fold aggregation
### 4.5. Pre-FDR collection

**n_total** = `n_total_hard_gate` từ `run_meta.json` (frozen).
FDR pad với p=1.0 cho hypotheses không có candidate output.

**Output:** `L4_hard_gates/hard_gate_candidates.csv` (chưa FDR)

---

## LAYER 4b — Regime Block Discovery

**Input:** `dev` ONLY  **Target:** `profitUSD` (hoặc `_all_styles_win` nếu target_mode = all_styles_win)
**FDR pool:** `regime_block`

**Mục đích:** Tìm `(setup, regime)` combinations mà EV âm ngay cả sau khi trade
đã pass hard/soft gate. Output feed `VPIsBlocked()` trong EA.

### 4b.1. Walk-forward block discovery
```python
for outer_fold in outer_folds:
    outer_train → discover candidate block rules (regime × setup combinations
                   có mean EV < 0 với fold_consistency >= 0.70 và n đủ lớn)
    outer_test  → validate: mean EV blocked < 0, lift >= MIN_EV_IMPROVEMENT

# Rule types (pre-registered):
#   "auction_regime"       — blocked EV by (setup, regime_name)
#   "auction_failure"      — blocked EV when auctFailure > 0.5
#   "regime_session"       — blocked EV by (setup, regime, session)
#   "regime_lt_transition" — blocked EV by (setup, regime, lt_bin)
```

### 4b.2. Pre-FDR candidate collection
```python
# Fisher's combined p từ permutation tests per fold
# n_total_regime_block = n_total từ run_meta.json
```

**Output:** `L4b_regime_blocks/regime_block_candidates.csv` (chưa FDR)

---

## LAYER 5 — Soft Gate Discovery

**Input:** `dev` ONLY  **Target:** `profitUSD` (hoặc `_all_styles_win`)
**FDR pool:** `soft_gate`
**[v4-1]** Khi `target_mode == "all_styles_win"`, dùng dedup df từ `_prepare_discovery_df`.

### 5.1. Direction extraction (Spearman trên dev)
### 5.2. Soft gate permutation (trên dev — không phải holdout)
```python
signal = direction * dev[feature]
split dev → top 50% / bottom 50%
lift = EV(top) - EV(bottom)
permutation test (500 iter) on DEV
```

### 5.3. Pre-FDR candidates

**Output:** `L5_soft_gates/soft_gate_candidates.csv`

---

## LAYER 10 — Exit-Reason Canary (per-group, Dev-first)

**[v4-2] L10 chạy per (symbol, setupType) group. Minimum 30 labeled signals per group.**

**Input:** `dev_df_3style` (3-style dev data gốc, trước `_prepare_discovery_df`)
**Target:** Exit-reason based — dùng tỉ lệ SL hit để phân loại bad entry
**FDR pool:** `bad_entry` (chung với L10a)

### 10.1. Bad-entry labeling
```python
# [v4-4] bad_sl_threshold được cấu hình qua BadEntryConfig
# bad_sl_threshold = 1: bất kỳ SL hit nào → bad entry (~85% flagged)
# bad_sl_threshold = 2: majority SL required → bad entry (~79% flagged)
from vp_analysis.layers.L10_bad_entry import BadEntryConfig

def label_bad_entry(trades_3style, bad_sl_threshold: int = 2) -> pd.Series:
    pivot = trades_3style.groupby("signalId")["exitReason"].apply(
        lambda x: (x == "SL_HIT").sum()
    )
    return (pivot >= bad_sl_threshold).astype(int)
```

### 10.2. Per-group feature screening
```python
# [v4-2] Chạy riêng cho mỗi (symbol, setupType) group
groups = dev_df_3style.groupby(["symbol", "setupType"])
group_results = {}
global_candidates = []

for (sym, stp), grp in groups:
    labeled = label_bad_entry(grp, bad_sl_threshold)
    if labeled.sum() < MIN_GROUP_SAMPLES:   # min 30
        continue
    candidates = screen_features(grp, labeled, avail_features)
    if candidates:
        group_results[f"{sym}|{stp}"] = candidates
    global_candidates.extend(candidates)
```

### 10.3. Output format (grouped JSON)
```json
{
  "groups": {
    "XAUUSDm|SWEEP_REVERSAL": {
      "features": [
        {"name": "feat_A", "threshold": 0.5, "direction": "above", "lift": 0.15}
      ],
      "min_votes": 2
    },
    "BTCUSDm|LIQUIDITY_SWEEP": {
      "features": [...],
      "min_votes": 2
    }
  },
  "global_fallback": {
    "features": [...],
    "min_votes": 2
  },
  "min_votes": 2
}
```
**Khi EA lookup:** tìm group key `{symbol}|{setup}` trước; nếu không có → dùng `global_fallback`.

**Output:** `L10_exit_canary/exit_canary_groups.json`

---

## LAYER 10a — MFE-Based Bad Entry Discovery (per-group, Dev-first)

**[v4-3] L10a cũng chạy per (symbol, setupType) group. Output cùng format với L10.**

**Input:** `dev_df_3style`  **Target:** MFE-based canary (MFE_max >= 1.0 ATR)
**FDR pool:** `bad_entry` (chung với L10)

### 10a.1. Canary composite labeling
```python
pivot = signalId × trailStyle → exitReason
label = classify_7_level(pivot):
  # catastrophic / bad / mixed_bad / neutral / mixed_good / good / excellent
  # Dựa trên: max MFE across styles ≥ 1.0 ATR → good entry
  #           min profit across styles < 0 → bad entry
```

### 10a.2. Per-group feature screening
```python
# [v4-3] Cùng cơ chế per-group như L10
groups = dev_df_3style.groupby(["symbol", "setupType"])
group_results_mfe = {}

for (sym, stp), grp in groups:
    y_bad = (mfe_label(grp) ∈ {catastrophic, bad})
    if y_bad.sum() < MIN_GROUP_SAMPLES:
        continue
    for feat in avail_features:
        for rule_type in ["low_extreme", "high_extreme", "mid_band"]:
            bad_rate = y_bad[mask].mean()
            p = binomtest(...)
    group_results_mfe[f"{sym}|{stp}"] = passing_features
```

### 10a.3. Output format (grouped JSON — cùng schema với L10)
```json
{
  "groups": {
    "XAUUSDm|SWEEP_REVERSAL": {"features": [...], "min_votes": 2},
    ...
  },
  "global_fallback": {"features": [...], "min_votes": 2},
  "min_votes": 2
}
```

**Output:** `L10a_bad_entry_discovery/mfe_canary_groups.json`

### 10a.4. Group merging (generate_guards_direct.py)
**[v4-9]** `generate_guards_direct.py` load cả L10 và L10a output, merge groups:
```python
# Với mỗi group key (sym|stp):
#   - lấy features từ cả hai outputs
#   - min_votes = max(l10_min_votes, l10a_min_votes)
merged_groups = merge_canary_groups(l10_output, l10a_output)
```

---

## LAYER 6 — Multiple Testing (FDR)

**Input:** Candidates từ L4, L4b, L5, L10, L10a  **NO holdout access**

### 6.1. FDR hard gate pool
**Input:** `hard_gate_candidates.csv`
**n_total:** từ `run_meta["n_total_hypotheses"]["hard_gate"]`
**Pool size:** 10,000 [v4-10]
```python
# Conservative padding:
padded_p_values = list(candidate_p_values) + [1.0] * (n_total - len(candidates))
fdr_result = benjamini_hochberg(padded_p_values, alpha=0.05)
```

### 6.2. FDR soft gate pool (isolated)
**n_total:** từ `run_meta["n_total_hypotheses"]["soft_gate"]`
**Pool size:** 10,000 [v4-10]

### 6.3. FDR regime block pool (isolated)
**n_total:** từ `run_meta["n_total_hypotheses"]["regime_block"]`
**Pool size:** 10,000 [v4-10]

### 6.4. FDR bad entry pool (isolated, chung L10 + L10a)
**[v4-2, v4-3]** Candidates từ cả L10 và L10a đều vào cùng pool này.
**n_total:** computed trong L10/L10a
**Pool size:** 5,000 [v4-10]

### 6.5. Pool isolation check
```python
FDRPoolRegistry.correct("hard_gate",    p_values, n_total=n_hard)
FDRPoolRegistry.correct("soft_gate",    p_values, n_total=n_soft)
FDRPoolRegistry.correct("regime_block", p_values, n_total=n_regime)
FDRPoolRegistry.correct("bad_entry",    p_values, n_total=n_bad)
# Không cross-contamination giữa pools
```

### 6.6. Rule finalization
```python
validated = (
    fdr_significant
    AND mean_ev >= contract.production_criteria.min_ev
    AND ci_low > 0
    AND temporal_slope_p > 0.15
    AND wr >= contract.production_criteria.min_wr
    AND pf >= contract.production_criteria.min_pf
)
```

### 6.7. Rule Freeze (immutable)
```python
for rule in validated_hard_gates:
    frozen = FrozenRule(rule)
for rule in validated_regime_blocks:
    frozen = FrozenRegimeBlockRule(rule)
# Soft gates: validated candidates → export only
# Bad entry canary (L10 + L10a): per-group format → FrozenBadEntryCanaryGroups [v4-2/3]
```

**Output:** `frozen_rules.json`, `frozen_regime_blocks.json`,
`exit_canary_groups_frozen.json`, `mfe_canary_groups_frozen.json`

---

## LAYER 7 — Dev Optimization (Optimization, not Statistics)

**Input:** `dev` ONLY, frozen artifacts từ L6  **NO FDR**

### Layer 7a — SL/TP Optimization

**Input:** `dev`, `frozen_rules` (hard gate rules)
```python
for rule in frozen_rules:
    trades = dev[apply_gate(rule)]
    results = []
    for sl in contract.optimization_budget.sl_candidates:
        for tp in contract.optimization_budget.tp_candidates:
            simulated = simulate_sl_tp(trades, sl, tp,
                                       using_mae_mfe_of_all_trades=True)
            utility = compute_utility(simulated, metric="expectancy")
            results.append((sl, tp, utility))
    # Tiebreaker: khi utility bằng nhau, ưu tiên sl↑ rồi tp↑
    results.sort(key=lambda x: (-x[2], -x[0], -x[1]))
    best = results[0]
    rule.sl_tp_selection = best
```

### Layer 7b — Sizing Calibration

**Input:** `dev`, `frozen_rules`
- Fractional Kelly trên dev
- Fold consistency check (walk-forward, non-overlapping)
- One-sided t-test trên dev profits
- Map Kelly → lot_multiplier ∈ [min_mult, max_mult]
- If unstable → neutral_mult = 1.0

### Layer 7c — SL Risk Threshold Discovery

**Input:** `dev`, available features
**Target:** SL hit rate (`exitReason == "SL_HIT"`)
```python
for rule in frozen_rules:
    gated_trades = dev[apply_gate(rule)]
    sl_vals = (gated_trades["exitReason"] == "SL_HIT").astype(int).values
    baseline_sl_rate = sl_vals.mean()

    for feat in avail_features:
        for pct in [25, 40, 50, 60, 75]:
            threshold = np.percentile(gated_trades[feat], pct)
            for direction in ["above", "below"]:
                mask = (gated_trades[feat] > threshold if direction == "above"
                        else gated_trades[feat] < threshold)
                if mask.sum() < MIN_SL_GROUP:
                    continue
                sl_rate_masked = sl_vals[mask].mean()
                lift = sl_rate_masked - baseline_sl_rate
                if lift < MIN_SL_LIFT:
                    continue
                # Permutation test (200 iter) + fold consistency
```
**[NOT FDR]** Đây là optimization, không phải hypothesis testing về edge.
**Output:** `sl_risk_thresholds.json`

### Layer 7.5 — Production Freeze

```python
production_config = FrozenProductionConfig(
    rules              = frozen_rules,
    regime_blocks      = frozen_regime_blocks,
    bad_entry_canary   = frozen_bad_entry_canary_groups,  # [v4-2/3] grouped format
    sl_tp              = sl_tp_selections,
    sizing             = sizing_configs,
    sl_risk_thresholds = sl_risk_thresholds,
    soft_gate_tilts    = validated_soft_gates,
    freeze_timestamp   = now(),
)
```

---

## LAYER 8 — Holdout Apply (Report Only)

### 8.1. Holdout unseal (one-time)

```python
def unseal_once(self, experiment_id, reason):
    access_log_path = output_dir / "holdout_access.json"
    if access_log_path.exists():
        existing = json.loads(access_log_path.read_text())
        if existing.get("experiment_id") == experiment_id:
            raise HoldoutAlreadyUnsealed(...)
    access_log_path.write_text(json.dumps({
        "experiment_id": experiment_id,
        "unsealed_at": datetime.utcnow().isoformat() + "Z",
        "reason": reason,
    }))
    return self._data
```

### 8.2. Hard gate evaluation
Apply `frozen_rules` → measure EV/WR/PF/n trên holdout.

### 8.3. Regime block evaluation
Apply `frozen_regime_blocks` → confirm blocked EV < 0 trên holdout.

### 8.4. Bad entry canary evaluation (= L10b)
**[v4-2/3]** Apply `frozen_bad_entry_canary_groups` (per-group) → report lift trên holdout.
Tìm group key cho mỗi trade; nếu không có → dùng global_fallback.

### 8.5. SL/TP confirmation
### 8.6. Sizing confirmation
### 8.7. SL risk confirmation
### 8.8. Holdout degradation analysis

**Output:** `L8_holdout/` reports

---

## LAYER 10b — Bad Entry Holdout Evaluation

Chỉ apply frozen per-group canary filter và report performance — không discovery.
Được gọi từ L8.4 (cần holdout đã unsealed).

**Output:** `L10a_bad_entry_discovery/bad_filter_holdout_report.csv`

---

## LAYER 9 — Attribution (Post-Freeze, on Holdout)

### 9.1. Entry vs Exit attribution
```python
rule.entry_quality = (
    "strong" if mfe_avg > 2 * mae_avg else
    "moderate" if mfe_avg > 1.2 * mae_avg else "weak"
)
rule.exit_capture = profit_avg / mfe_avg
```

### 9.2. Exit policy decomposition (3-style)
```text
EV_A = EV no-trail
EV_B = EV conservative trail
EV_C = EV expansion trail

ΔB_A = EV_B - EV_A
ΔC_A = EV_C - EV_A

flag "trail_rescues_negative_entry" nếu EV_A < 0 and (EV_B > 0 or EV_C > 0)
```

### 9.3. Cross-style MAE/MFE consistency

**Output:** `L9_attribution/` reports

---

## LAYER 11 — Null Result Protocol

### 11.1. Case detection
```python
if len(validated_rules) == 0:
    case = "dev_null"
elif len(holdout_confirmed) == 0:
    case = "holdout_null"
else:
    case = "success"
```

### 11.2. Protocol
```text
"dev_null":     → Không unseal holdout → NULL_RESULT
"holdout_null": → NULL_RESULT, holdout giữ nguyên
"success":      → PRODUCTION_CANDIDATES
```

---

## LAYER 12 — Reporting & EA Guard Export

### 12.1. Immutable research report (per experiment)
### 12.2. Rule provenance (mỗi rule có experiment_id, hashes, timestamps)
### 12.3. Experiment lineage

### 12.4. EA Guard Export — `VPEdgeGuardConfig.mqh`

Guard file sinh ra 7 hàm MQL5 (tăng từ 6 do thêm VPBadEntryVote [v4-5]):

```cpp
// 1. Hard gate blocking (từ FrozenRule — L4/L6)
double VPGetEdgeMultiplier(symbol, setup, feature, value) → 0.0 nếu blocked

// 2. Soft gate tilt (từ validated_soft_gates — L5/L6)
// Trả về multiplier ∈ (0, 1] để scale lot size theo tilt direction.
// [v4-7] Output được nhân vào m_state.winProbability trong EA.
// Không block hoàn toàn (khác với hard gate → 0.0).
double VPGetEdgeTiltMultiplier(symbol, setup, feature, value) → [0.5, 1.0]

// 3. Regime blocking (từ FrozenRegimeBlockRule — L4b/L6)
bool VPIsBlocked(symbol, setup, regime) → true nếu bị block

// 4. SL risk multiplier (từ sl_risk_thresholds — L7c)
double VPGetSLRiskMultiplier(symbol, setup, feature, value) → [0.5, 1.0]

// 5. Symbol/trigger blocking (từ Phase 01 behavior profiling)
bool VPIsSymbolBlocked(symbol) → true nếu AVOID
bool VPIsTriggerEnabled(symbol, setupType) → false nếu disabled

// 6. Lot multiplier (từ FrozenProductionConfig sizing — L7b)
double VPGetLotMultiplier(symbol, setup) → [0.5, 1.5]

// 7. [v4-5] Bad-entry vote accumulator (từ frozen_bad_entry_canary_groups — L10/L10a)
// Thay thế VPIsBadEntry() từ v3.
// Pattern: reset → vote × N → check
// File-scope globals: _g_bev_votes, _g_bev_sym, _g_bev_stp
//
// cmd = "__reset__": đặt lại counter về 0, ghi sym+stp
// cmd = "__vote__":  kiểm tra feature theo per-group rules, tăng counter nếu match
// cmd = "__check__": return (_g_bev_votes >= min_votes)
//
// Per-group lookup: tìm key "{symbol}|{setup}" trước,
// nếu không có → dùng global_fallback
int VPBadEntryVote(cmd, symbol, setup, feat, val) → votes hoặc 0/1
```

**Metadata trong header:**
```cpp
// Production style: 1 (expansion) — guard metrics derived from this style
// Experiment ID: EXP-2026-09-18-001
// Contract hash: sha256:...
// Target mode: production_profit | all_styles_win   [v4-1]
// Bad-entry format: per-group (grouped canary)       [v4-2/3]
// [ROBUST] tag = rule held across all 3 trailing styles
```

### 12.5. generate_guards_direct.py

**[v4-9]** Cập nhật lớn:
```text
--max-soft      default tăng từ 50 lên 5000
--cross-style-filter  flag mới: post-filter candidates dùng _all_styles_win signal
                      (loại candidate không consistent qua styles)

Tilt scale auto-detection:
  Nếu tất cả lift values < 2.0 (binary range) → rescale thresholds proportionally
  Tránh tilt multipliers quá nhỏ khi target là binary (all_styles_win)

Load và merge L10 + L10a:
  l10_out  = load_json("L10_exit_canary/exit_canary_groups.json")
  l10a_out = load_json("L10a_bad_entry_discovery/mfe_canary_groups.json")
  merged   = merge_canary_groups(l10_out, l10a_out)
  → dùng để xuất VPBadEntryVote trong guard file
```

---

# PHẦN 4 — FLOWCHARTS

## 4.1. Master flowchart

```text
┌───────────────────────────────────────────────────────────────┐
│                    RESEARCH CONTRACT (Layer −1)               │
│  - 6 hashes    - 2 targets + consensus targets  [v4-8]       │
│  - SHAPE_PRIORS (immutable)    - FDR pools (4, 10K/5K) [v4-10]│
│  - Optimization budget (tiebreaker: sl↑, tp↑)                │
│  - Selection budget            - Production criteria          │
│  - bad_sl_threshold (configurable)              [v4-4]        │
└─────────────────────────┬─────────────────────────────────────┘
                          ▼
              [Interactive prompts — run_pipeline.py]
              1. Sync MT5 data?
              2. Symbols + date range
              3. Production trailing style
              4. Gate discovery target [v4-11]
                 (production_profit / all_styles_win)
              5. SL threshold for canary [v4-11]
                 (1=strict / 2=balanced)
                          ▼
┌───────────────────────────────────────────────────────────────┐
│  LAYER 0: DATA HYGIENE  (merged_all — 3 styles)              │
│  - Entry consistency (halt=False for 3-style design)         │
│  - MAE/MFE sanity (halt=False — EA chưa log)                 │
│  → Halt nếu critical fail                                    │
└─────────────────────────┬─────────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────────┐
│  LAYER 1: HARD BOUNDARY + n_total_hyp + consensus targets     │
│  split prod_df 70/30 @ time                                   │
│  _build_consensus_targets() → 4 outcome cols [v4-8]          │
│  dev_df_3style stored in pipeline.py [v4-12]                 │
│  log n_total, target_mode, bad_sl_threshold                  │
└────────┬──────────────────────────────────┬───────────────────┘
         │                                  │
    DEVELOPMENT (prod)               HOLDOUT (prod)
    + dev_df_3style (3-style)        🔒 SEALED
         │                                  │
         ▼
┌──────────────────────────────────┐
│  LAYER 2: FEATURE ENGINEERING   │
│  fit scaler on dev               │
│  transform dev + holdout +       │
│  dev_df_3style                   │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  LAYER 3: EDA (dev)              │
│  EV-by-bin, SHAPE_PRIOR verify  │
└──────────┬───────────────────────┘
           │
    ┌──────┴─────────────────────────────────┐
    │               │           │            │
    ▼               ▼           ▼            ▼
┌──────────┐  ┌──────────┐ ┌──────────┐ ┌──────────────────┐
│ LAYER 4  │  │ LAYER 4b │ │LAYER 10  │ │ LAYER 5          │
│ Hard Gate│  │ Regime   │ │Exit-Rsn  │ │ Soft Gate        │
│ Discovery│  │ Block    │ │Canary    │ │ Direction+perm   │
│ target:  │  │ Discovery│ │per-group │ │ target: profitUSD│
│profitUSD │  │ dev only │ │dev_3style│ │ or all_styles_win│
│or all_win│  └─────┬────┘ │[v4-2]   │ └────────┬─────────┘
│[v4-1]   │        │      └────┬─────┘          │
│dev only │        │           │                 │
└────┬─────┘        │           │                 │
     │              │     ┌─────┘                 │
     │              │     ▼                        │
     │              │  ┌──────────────────┐        │
     │              │  │ LAYER 10a        │        │
     │              │  │ MFE Canary       │        │
     │              │  │ per-group        │        │
     │              │  │ dev_3style [v4-3]│        │
     │              │  └────┬─────────────┘        │
     │              │       │                      │
     └──────┬────────┘───────┘──────────────────────┘
            │
            ▼
┌───────────────────────────────────────┐
│  LAYER 6: MULTIPLE TESTING (FDR)      │
│  4 isolated pools (10K/10K/10K/5K)   │
│    hard_gate (10,000)           [v4-10]│
│    soft_gate (10,000)           [v4-10]│
│    regime_block (10,000)        [v4-10]│
│    bad_entry (5,000, L10+L10a)  [v4-10]│
│  → frozen_rules.json                  │
│  → frozen_regime_blocks.json          │
│  → exit_canary_groups_frozen.json [v4-2]│
│  → mfe_canary_groups_frozen.json  [v4-3]│
│  → soft_gate_validated.csv            │
└────────────────┬──────────────────────┘
                 │
                 ▼
┌───────────────────────────────────────┐
│  LAYER 7: DEV OPTIMIZATION            │
│  7a: SL/TP grid (tiebreaker sl↑ tp↑) │
│  7b: Sizing Kelly (dev)               │
│  7c: SL Risk Thresholds (dev)         │
│  7.5: Production Freeze               │
└────────────────┬──────────────────────┘
                 │
                 ▼
┌───────────────────────────────────────┐
│  LAYER 8: HOLDOUT APPLY               │
│  8.1: Unseal (1x, persist log)        │
│  8.2: Hard gate eval                  │
│  8.3: Regime block eval               │
│  8.4: Per-group canary eval [v4-2/3]  │
│  8.5: SL/TP confirm                   │
│  8.6: Sizing confirm                  │
│  8.7: SL risk confirm                 │
│  8.8: Degradation analysis            │
└────────────────┬──────────────────────┘
                 ▼
┌───────────────────────────────────────┐
│  LAYER 9: ATTRIBUTION (holdout)       │
│  Entry vs Exit, 3-style decomposition │
└────────────────┬──────────────────────┘
                 ▼
┌───────────────────────────────────────┐
│  LAYER 11: NULL PROTOCOL              │
└────────────────┬──────────────────────┘
                 ▼
┌───────────────────────────────────────┐
│  LAYER 12: REPORTING + EA GUARD       │
│  7 MQL5 functions:                    │
│    VPGetEdgeMultiplier (hard gates)   │
│    VPGetEdgeTiltMultiplier → winProb  │
│                         [v4-7]        │
│    VPIsBlocked (regime blocks)        │
│    VPGetSLRiskMultiplier              │
│    VPIsSymbolBlocked/TriggerEnabled   │
│    VPGetLotMultiplier                 │
│    VPBadEntryVote (vote accumulator)  │
│                    [v4-5]             │
│  generate_guards_direct.py [v4-9]    │
│    --max-soft 5000                    │
│    --cross-style-filter               │
│    merge L10 + L10a groups            │
└───────────────────────────────────────┘
```

## 4.2. EA EdgeGuard Pipeline trong VPTradingPipeline.mqh

**[v4-6] Pipeline có 9 bước (tăng từ 8 lên 9):**

```text
Step 1: Symbol/trigger enable check (VPIsSymbolBlocked, VPIsTriggerEnabled)
Step 2: Regime blocking (VPIsBlocked)
Step 3: Hard gate check (VPGetEdgeMultiplier)
Step 4: Soft gate tilt (VPGetEdgeTiltMultiplier)
         → áp vào m_state.winProbability   [v4-7]
Step 5: SL risk check (VPGetSLRiskMultiplier)
Step 6: Lot sizing (VPGetLotMultiplier)
Step 7: Min tilt threshold check (InpMinTiltThreshold)  [v4-7]
         → block nếu cumulative tilt < threshold
Step 8: Final production criteria check
Step 9: Bad-entry filter (VPBadEntryVote)          [v4-6]
         reset → vote features → check
         → block nếu votes >= min_votes
```

**Cơ chế VPBadEntryVote [v4-5]:**
```cpp
// File-scope globals
int    _g_bev_votes = 0;
string _g_bev_sym   = "";
string _g_bev_stp   = "";

int VPBadEntryVote(string cmd,
                   string symbol, string setup,
                   string feat,   double val) {
    if (cmd == "__reset__") {
        _g_bev_votes = 0;
        _g_bev_sym   = symbol;
        _g_bev_stp   = setup;
        return 0;
    }
    if (cmd == "__vote__") {
        // Lookup per-group rules: "{symbol}|{setup}"
        // Nếu không có group → dùng global_fallback
        if (_match_canary_rule(symbol, setup, feat, val))
            _g_bev_votes++;
        return _g_bev_votes;
    }
    if (cmd == "__check__") {
        int min_v = _get_min_votes(symbol, setup);
        return (_g_bev_votes >= min_v) ? 1 : 0;
    }
    return 0;
}
```

## 4.3. Information flow boundary

```text
        DEV                                         HOLDOUT
        ═══                                         ═══════
        │                                            │
        │  ┌──────────────────────────────────┐     │
        │  │ DISCOVERY & OPTIMIZATION         │     │
        │  │ (target: profitUSD hoặc          │     │
        │  │          all_styles_win) [v4-1]  │     │
        │  │  - L4 Hard gate (threshold WF)   │     │
        │  │  - L4b Regime block discovery    │     │
        │  │  - L5 Soft gate (direction+perm) │     │
        │  │  - L7a SL/TP grid                │     │
        │  │  - L7b Sizing calibration        │     │
        │  │  - L7c SL risk thresholds        │     │
        │  │ (target: MFE canary + exit-rsn)  │     │
        │  │  - L10  Exit-reason canary [v4-2]│     │
        │  │  - L10a MFE canary       [v4-3]  │     │
        │  └──────────────────────────────────┘     │
        │              │                              │
        │              ▼                              │
        │         [FROZEN ARTIFACTS]                 │
        │  frozen_rules, frozen_regime_blocks,       │
        │  exit_canary_groups (per-group) [v4-2],   │
        │  mfe_canary_groups (per-group)  [v4-3],   │
        │  sl_tp, sizing, sl_risk_thresholds,       │
        │  soft_tilt_validated                       │
        │              │                              │
        │              └──────────────┬───────────────┘
        │                             │
        │                             ▼
        │              ┌──────────────────────────────┐
        │              │ HOLDOUT APPLY (L8, L9, L11)  │
        │              │ - apply frozen artifacts      │
        │              │ - measure (read-only)         │
        │              │ - access log persisted        │
        │              └──────────────────────────────┘
        │
        └─── KHÔNG có arrow ngược từ HOLDOUT về DISCOVERY ────
```

## 4.4. FDR Pool isolation với conservative padding

```text
L4 Hard Gate Search
  n_features × n_groups = N_TOTAL_HARD (logged to run_meta at L1)
  [v4-1] Nếu all_styles_win mode: dedup trước khi count n_groups
           │
           ▼ (only surviving candidates have p < 1.0)
  FDRPool: hard_gate  [pool_size = 10,000 — v4-10]
    input: [p₁, p₂, ..., pₖ] + [1.0] × (N_TOTAL_HARD - k)
    BH correction, alpha=0.05
    → fdr_significant per candidate

L4b Regime Block Search
  n_regime_combos = N_TOTAL_REGIME (logged at L1)
  FDRPool: regime_block  [pool_size = 10,000 — v4-10]

L5 Soft Gate Search
  n_features × n_groups = N_TOTAL_SOFT (logged at L1)
  FDRPool: soft_gate  [pool_size = 10,000 — v4-10]

L10 + L10a Bad Entry Search  [v4-2/3]
  Cả hai chạy trên dev_df_3style, per (symbol, setupType) group
  n_features × n_rule_types × n_groups = N_TOTAL_BAD
  FDRPool: bad_entry  [pool_size = 5,000 — v4-10]
  Isolated từ tất cả các pools khác.

[NOTE] SL Risk Thresholds (L7c): KHÔNG dùng FDR.
  Đây là optimization (chọn threshold tốt nhất), không hypothesis testing.
```

---

# PHẦN 5 — ROADMAP

## 5.1. Directory structure

```text
vp_analysis/
├── core/
│   ├── __init__.py
│   ├── research_contract.py        # Layer −1
│   ├── experiment_manifest.py      # Lineage, versioning
│   ├── data_boundary.py            # DevelopmentData, SealedHoldout
│   ├── frozen_types.py             # FrozenRule, FrozenRegimeBlockRule,
│   │                               # FrozenBadEntryCanaryGroups [v4-2/3],
│   │                               # FrozenProductionConfig
│   ├── fdr_registry.py             # FDRPoolRegistry (4 isolated pools)
│   ├── optimization_registry.py    # SL/TP, sizing (không FDR)
│   ├── governance.py               # Selection budget, cooldown
│   ├── stats_helpers.py            # t-test, bootstrap, permutation
│   └── provenance.py               # Hashing, snapshots
│
├── layers/
│   ├── __init__.py
│   ├── _constants.py               # Interaction defs, feature lists
│   │                               # CONSENSUS_TARGET_COLS [v4-8]
│   ├── L0_hygiene.py               # HygieneConfig (halt flags configurable)
│   ├── L1_boundary.py              # + consensus targets [v4-8]
│   │                               # + target_mode logging [v4-1]
│   ├── L2_feature_engineering.py
│   ├── L3_eda.py
│   ├── L4_hard_gate_discovery.py   # + _prepare_discovery_df() [v4-1]
│   ├── L4b_regime_block_discovery.py
│   ├── L5_soft_gate_discovery.py
│   ├── L6_multiple_testing.py      # 4 pools, 10K/10K/10K/5K [v4-10]
│   ├── L7a_sl_tp_optimization.py
│   ├── L7b_sizing_calibration.py
│   ├── L7c_sl_risk_thresholds.py
│   ├── L7_5_production_freeze.py
│   ├── L8_holdout_apply.py         # + per-group canary eval [v4-2/3]
│   ├── L9_attribution.py
│   ├── L10_bad_entry.py            # Exit-reason canary, per-group [v4-2]
│   │                               # BadEntryConfig(bad_sl_threshold) [v4-4]
│   ├── L10a_bad_entry_discovery.py # MFE canary, per-group [v4-3]
│   ├── L10b_bad_entry_evaluation.py# Gọi từ L8.4
│   ├── L11_null_protocol.py
│   └── L12_reporting.py            # VPBadEntryVote export [v4-5]
│                                   # generate_guards_direct.py [v4-9]
│
├── pipeline.py                     # Orchestrator
│                                   # dev_df_3style stored here [v4-12]
├── pipeline_config.py              # PipelineConfig, BadEntryConfig
├── contracts/
│   └── contract_v1.yaml
├── generate_contract.py            # FDR pool sizes: 10K/10K/10K/5K [v4-10]
├── generate_guards_direct.py       # --max-soft 5000, --cross-style-filter [v4-9]
├── data_loader.py                  # _build_consensus_targets() [v4-8]
├── tests/
│   ├── conftest.py
│   ├── test_provenance.py
│   ├── test_research_contract.py
│   ├── test_experiment_manifest.py
│   ├── test_governance.py
│   ├── test_data_boundary.py
│   ├── test_fdr_registry.py
│   ├── test_L0_hygiene.py
│   ├── test_L1_boundary.py
│   ├── test_L2_feature_engineering.py
│   ├── test_L3_eda.py
│   ├── test_L4_hard_gate_discovery.py
│   ├── test_L4b_regime_block_discovery.py
│   ├── test_L5_soft_gate_discovery.py
│   ├── test_L6_multiple_testing.py
│   ├── test_L7a_sl_tp_optimization.py
│   ├── test_L7b_sizing_calibration.py
│   ├── test_L7c_sl_risk_thresholds.py
│   ├── test_L8_holdout_apply.py
│   ├── test_L9_attribution.py
│   ├── test_L10_bad_entry.py           # [v4-2] per-group exit canary
│   ├── test_L10a_bad_entry_discovery.py# [v4-3] per-group MFE canary
│   ├── test_consensus_targets.py       # [v4-8]
│   ├── test_pipeline_e2e.py
│   └── test_leak_detection.py
│
└── output/
    └── experiments/
        └── EXP-YYYY-MM-DD-NNN/
```

## 5.2. Sprint plan (v4)

### Sprint 0A — Governance Kernel (2 ngày)
`ResearchContract` với 2 targets + consensus targets [v4-8], `ExperimentManifest`,
`Governance`, hash utilities.
- Contract validate 2 discovery targets và consensus targets đều có mặt.
- [v4-1] Contract hỗ trợ `target_mode` field.
- Tests: ~27

### Sprint 0B — Information Boundary (2 ngày)
`DevelopmentData`, `SealedHoldout`, `FrozenRule`, `FrozenRegimeBlockRule`,
`FrozenBadEntryCanaryGroups` [v4-2/3 — grouped format], `FrozenProductionConfig`.
- `SealedHoldout.unseal_once()` persist access log ra disk.
- Tests: ~26

### Sprint 0C — FDR Registry & Optimization (1 ngày)
`FDRPoolRegistry` (4 pools với pool sizes mới: 10K/10K/10K/5K [v4-10]),
`OptimizationRegistry`.
- Tests: ~18

### Sprint 1 — Data Hygiene + Boundary (1 ngày)
L0 + L1.
- [v4-8] L1 gọi `_build_consensus_targets()`, exclude khỏi avail_features.
- [v4-1] L1 log `target_mode` và `bad_sl_threshold` vào `run_meta.json`.
- L1 pre-compute `n_total_hypotheses` cho 3 pools.
- `dev_df_3style` stored và passed qua pipeline [v4-12].

### Sprint 2 — Feature Engineering + EDA (1 ngày)
L2 + L3.
- L2 transform `dev_df_3style` (giữ consensus target cols separate).

### Sprint 3 — Hard Gate Discovery (2 ngày)
L4.
- [v4-1] `_prepare_discovery_df()` cho cả hai target modes.
- Khi `all_styles_win`: dedup theo `signalId` trước search.

### Sprint 4 — Regime Block Discovery (1-2 ngày)
L4b. FDR pool riêng (10,000) [v4-10].

### Sprint 5 — Soft Gate + L10 + L10a Discovery (2 ngày)
L5 + L10 + L10a.
- [v4-2] L10 per-group, exit-reason canary, `BadEntryConfig.bad_sl_threshold` [v4-4].
- [v4-3] L10a per-group, MFE canary, cùng grouped output format.
- [v4-12] Cả L10 và L10a dùng `dev_df_3style` (trước `_prepare_discovery_df`).
- `n_total_bad` tính và logged trong L10/L10a.

### Sprint 6 — Multiple Testing (1 ngày)
L6. 4 isolated pools với pool sizes 10K/10K/10K/5K [v4-10].
`n_total` cho mỗi pool lấy từ `run_meta.json`.

### Sprint 7 — Dev Optimization (2 ngày)
L7a, L7b, L7c, L7.5.

### Sprint 8 — Holdout Apply + Attribution (2 ngày)
L8, L9.
- [v4-2/3] L8.4 áp per-group canary (lookup group key, fallback to global).
- L10b gọi từ L8.4.

### Sprint 9 — Null Protocol + Reporting + EA Guard (2 ngày)
L11, L12.
- [v4-5] Export `VPBadEntryVote` với vote accumulator pattern.
- [v4-7] `VPGetEdgeTiltMultiplier` → `winProbability`, `InpMinTiltThreshold`.
- [v4-9] `generate_guards_direct.py`: `--max-soft 5000`, `--cross-style-filter`,
  merge L10 + L10a groups.

### Sprint 10 — End-to-End Validation (2 ngày)
`pipeline.py`, `cli.py`, e2e tests với synthetic data,
leak detection tests, migration docs.
- Test `target_mode` switching [v4-1].
- Test per-group canary lookup + global_fallback [v4-2/3].
- Test `VPBadEntryVote` accumulator pattern [v4-5].

**Tổng: ~19 ngày** (giữ nguyên so với v3 — các thay đổi v4 phân bổ vào sprints hiện có).

## 5.3. Dependency graph (v4)

```text
Sprint 0A ──► Sprint 0B ──► Sprint 0C
                                │
                                ▼
                    Sprint 1 (Hygiene + Boundary + consensus targets + target_mode)
                                │
                                ▼
                          Sprint 2 (EDA + FE)
                                │
                    ┌───────────┼────────────────┐
                    ▼           ▼                 ▼
               Sprint 3    Sprint 4    Sprint 5 (L5 + L10 + L10a)
               (L4 Hard)  (L4b Regime)  [v4-1]         [v4-2/3]
                    │           │                 │
                    └───────────┼─────────────────┘
                                ▼
                          Sprint 6 (FDR — 10K pools [v4-10])
                                │
                                ▼
                          Sprint 7 (Dev Optimization)
                                │
                                ▼
                          Sprint 8 (Holdout + per-group eval [v4-2/3])
                                │
                                ▼
                          Sprint 9 (Guard: VPBadEntryVote [v4-5], tilt→winProb [v4-7])
                                │
                                ▼
                          Sprint 10 (E2E Validation)
```

## 5.4. Output directory structure (v4)

```text
output/experiments/{experiment_id}/
├── research_contract.json
├── run_meta.json              ← kể cả n_total_hypotheses, target_mode [v4-1],
│                                bad_sl_threshold [v4-4]
├── holdout_access.json        ← persist ngay khi unseal
├── config_snapshot.json
├── experiment_manifest.json
│
├── L0_hygiene/
│   ├── entry_consistency_report.csv
│   ├── mae_mfe_sanity.csv
│   └── time_alignment.csv
│
├── L1_boundary/
│   ├── split_info.json
│   ├── feature_availability.csv
│   └── consensus_targets_summary.csv    ← [v4-8]
│
├── L3_eda/
│   ├── feature_shape_analysis.csv
│   ├── shape_mismatch_report.csv
│   └── feature_correlation.csv
│
├── L4_hard_gates/
│   ├── hard_gate_candidates.csv
│   └── hard_gate_discovery_summary.json
│
├── L4b_regime_blocks/
│   ├── regime_block_candidates.csv
│   └── regime_block_discovery_summary.json
│
├── L5_soft_gates/
│   ├── soft_gate_directions.csv
│   └── soft_gate_candidates.csv
│
├── L6_freeze/
│   ├── fdr_summary.json
│   ├── frozen_rules.json
│   ├── frozen_regime_blocks.json
│   ├── exit_canary_groups_frozen.json   ← [v4-2] grouped format
│   ├── mfe_canary_groups_frozen.json    ← [v4-3] grouped format
│   └── soft_gate_validated.csv
│
├── L7_dev_optimization/
│   ├── sl_tp_optimization.csv
│   ├── sizing_configurations.csv
│   ├── sl_risk_thresholds.json
│   └── optimization_summary.json
│
├── L8_holdout/
│   ├── holdout_evaluation.csv
│   ├── regime_block_holdout.csv
│   ├── sl_tp_holdout_report.csv
│   ├── sizing_holdout_report.csv
│   ├── sl_risk_holdout_report.csv
│   ├── canary_holdout_report.csv        ← [v4-2/3] per-group eval
│   └── holdout_degradation.csv
│
├── L9_attribution/
│   ├── entry_exit_attribution.csv
│   ├── exit_policy_decomposition.csv
│   └── style_consistency.csv
│
├── L10_exit_canary/                     ← [v4-2] exit-reason canary
│   ├── exit_canary_labels.csv
│   ├── exit_canary_features.csv
│   └── exit_canary_groups.json          ← grouped format
│
├── L10a_bad_entry_discovery/            ← [v4-3] MFE canary
│   ├── canary_labels.csv
│   ├── bad_entry_features.csv
│   ├── mfe_canary_groups.json           ← grouped format
│   └── bad_filter_holdout_report.csv
│
└── L11_result/
    └── experiment_result.json
```

---

# PHẦN 6 — GOVERNANCE

## 6.1. Bốn đường cấm tuyệt đối

```text
❌ SNOOPING
   Chạy → thấy holdout fail → sửa → chạy lại
   → Phải là experiment mới với contract mới.

❌ FEATURE DRIFT
   Thấy feature X có vẻ tốt → thêm vào PRE_REGISTERED
   → Contract mới. Không được.

❌ CHAINED LEAK
   Phase N dùng holdout → Phase N+1 dùng kết quả Phase N
   → L10/L10a (discovery) là dev-only (dev_df_3style).
   → L10b (evaluation) dùng holdout đã unsealed bởi L8 — không chained leak.

❌ META-ITERATION
   Experiment 1 fail → Exp 2 fail → Exp 3 fail → Exp 4 pass
   → Report chỉ Exp 4
   → Phải report toàn bộ lineage.
```

## 6.2. Sáu invariants phải verify mỗi lần chạy

```text
INV1: Holdout sealed trước rule freeze
   Verify: holdout_access.json KHÔNG tồn tại trước timestamp freeze.

INV2: Interaction scaler fit on dev only
   Verify: log fit_source = "development".

INV3: FDR áp trên final rule p-values với n_total cố định
   Verify: n_total trong run_meta.json == n_total dùng trong L6.
   n_total không thể thay đổi sau L1.

INV4: Holdout unsealed đúng một lần per experiment
   Verify: holdout_access.json tồn tại và experiment_id match.
   Check disk, không chỉ in-memory.

INV5: Mỗi layer dùng đúng target
   L4/L4b/L5/L7: profitUSD hoặc _all_styles_win (theo target_mode).  [v4-1]
   L10/L10a: exit-reason / MFE canary (dev_df_3style).               [v4-2/3]

INV6: [v4-1] target_mode nhất quán trong toàn bộ experiment
   Verify: target_mode trong run_meta.json == target_mode dùng tại L4/L5/L4b.
   Không được thay đổi sau khi L1 complete.
```

## 6.3. Ba levels of enforcement

```text
Level 1: TYPE ENFORCEMENT (mạnh nhất)
  - DevelopmentData ≠ SealedHoldout
  - FrozenRule / FrozenRegimeBlockRule immutable
  - FrozenBadEntryCanaryGroups immutable (grouped format) [v4-2/3]
  - API chỉ nhận đúng type
  - Target enum: EdgeDiscoveryTarget ≠ BadEntryCanaryTarget

Level 2: RUNTIME ENFORCEMENT
  - assert_holdout_sealed() checks disk log
  - assert_contract_valid()
  - assert_selection_budget_ok()
  - assert_n_total_frozen()
  - assert_target_mode_consistent() [v4-1]
  - assert_canary_grouped_format()  [v4-2/3]

Level 3: CONVENTION
  - Documentation, code review, tests
```

## 6.4. Audit checklist trước deploy (v4)

```text
□ Research contract hash recorded
□ Hai targets (edge_discovery, bad_entry_canary) + consensus targets có mặt
□ Experiment_id unique, lineage valid
□ Selection budget not exceeded
□ target_mode logged in run_meta.json                              [v4-1]
□ bad_sl_threshold logged in run_meta.json                         [v4-4]
□ n_total_hypotheses logged in run_meta.json for all 4 FDR pools
□ No holdout access before rule freeze
□ Holdout access log persisted to disk immediately on unseal
□ FDR pools isolated (4 pools: 10K/10K/10K/5K)                    [v4-10]
□ n_total used in FDR == n_total in run_meta
□ Rules immutable after freeze
□ Regime blocks validated on holdout
□ SL risk thresholds NOT in FDR pool (optimization, not hypothesis)
□ SL/TP tiebreaker applied (sl↑, tp↑)
□ Soft gate tilts exported to VPGetEdgeTiltMultiplier
□ VPGetEdgeTiltMultiplier output multiplied into winProbability     [v4-7]
□ InpMinTiltThreshold blocks trade when tilt < threshold            [v4-7]
□ L10/L10a output in grouped JSON format with global_fallback      [v4-2/3]
□ L10 and L10a both use dev_df_3style (before _prepare_discovery_df) [v4-12]
□ VPBadEntryVote accumulator pattern correct (reset/vote/check)    [v4-5]
□ generate_guards_direct.py merges L10 + L10a groups               [v4-9]
□ generate_guards_direct.py --max-soft = 5000                      [v4-9]
□ EA EdgeGuard pipeline has 9 steps                                [v4-6]
□ Consensus targets excluded from avail_features                   [v4-8]
□ L10 ran before L6 (discovery on dev before FDR)
□ L10b ran after L8.1 (evaluation on unsealed holdout)
□ Holdout unsealed exactly once
□ Null protocol followed
□ Provenance complete (rule_id, experiment_id, hashes, timestamps)
□ Old phases archived, not cherry-picked
```

---

# PHẦN 7 — THAM CHIẾU: KẾ THỪA TỪ PIPELINE CŨ

Những component từ `02_QuantResearch_VPEA/` có thể tái sử dụng:

| Component cũ | Layer mới | Ghi chú |
|---|---|---|
| `data_collect.py` — `_dedup_key_*`, `_sync_kind` | Ngoài pipeline | Dùng lại gần nguyên |
| `data_loader.py` — `merge_funnel_trades`, `split_by_style`, `robust_across_styles` | L1, L8, L9 | Tái sử dụng logic |
| `data_loader.py` — `FUNNEL_FEATURES`, `LAYER_MAP`, `REGIME_NAMES` | `_constants.py` | Copy trực tiếp |
| `data_loader.py` — `_build_consensus_targets()` | L1 | **[v4-8] Mới** — tính 4 consensus cols |
| `vp_02` — `_compute_interactions`, `INTERACTION_DEFS` | L2 `_constants.py` | Copy |
| `vp_02` — `_perm_test` (early stopping) | L4 `stats_helpers` | Copy |
| `vp_02` — `_bootstrap_ci`, `_t_test`, `_temporal_stability` | `core/stats_helpers.py` | Copy |
| `vp_02` — `_robustness_check` | L9.2 | Tái sử dụng logic |
| `vp_04` — `_style_comparison` | L9.2 | Port trực tiếp |
| `vp_05` — `_walkforward`, `_discover`, `_mask`, `_perm_test` | L4b | Port với governance wrapping |
| `vp_06` — `_kelly_raw`, `_calibrate` | L7b | Port |
| `vp_06` — `_robustness_check` (Kelly by style) | L7b validation | Port |
| `vp_99` — `_generate_mqh`, `_regime_name_to_int` | L12 | Extend cho 3 functions mới |
| `generate_contract.py` — FDR pool sizes | L12 | **[v4-10]** Tăng lên 10K/10K/10K/5K |
| `generate_guards_direct.py` — tilt logic | L12 | **[v4-9]** Thêm auto-detect scale, merge groups |

**KHÔNG port (có bugs đã biết hoặc đã redesign):**
- `vp_02` — `_inner_loop` (bug: threshold search trên toàn outer_train, không phải inner_train) → L4 đã fix
- `vp_05` — `_apply_prior_filters` (chỉ lọc Phase 02, chưa hoàn chỉnh) → không cần trong kiến trúc mới
- `vp_03` — `_compute_target` với `exitReason == TP_HIT` → L10a dùng MFE canary thay thế
- `VPIsBadEntry()` cũ trong EA → **[v4-5]** thay bằng `VPBadEntryVote()` (vote accumulator)

---

# PHẦN 8 — QUICK REFERENCE: THAY ĐỔI THIẾT KẾ QUAN TRỌNG (v4)

## 8.1. Target Mode (v4-1)

```text
production_profit (default):
  - Target: profitUSD của production trailing style
  - Dev data: production-style subset (1 row/signal)
  - Như v3

all_styles_win (mới):
  - Target: binary 1/0 — 1 nếu ALL 3 trailing styles có lãi
  - Dev data: dedup theo signalId (1 row/signal) TRƯỚC L4/L5
  - Đo chất lượng entry thuần túy, không phụ thuộc exit behavior
  - Chọn runtime qua _ask_target_mode() trong run_pipeline.py
```

## 8.2. Per-Group Canary Format (v4-2, v4-3)

```text
Trước v4:  L10 và L10a xuất flat list features + global threshold
           VPIsBadEntry(symbol, setup, feat, val) → bool

Từ v4:     L10 và L10a xuất grouped JSON
           Key: "{symbol}|{setupType}"
           Lookup: per-group → nếu không có → global_fallback
           VPBadEntryVote(cmd, sym, stp, feat, val)
             cmd = "__reset__"  → reset counter
             cmd = "__vote__"   → check + increment
             cmd = "__check__"  → return (votes >= min_votes)
```

## 8.3. VPBadEntryVote trong EA Pipeline (v4-5, v4-6)

```text
// Sử dụng trong EA (Step 9 của EdgeGuard pipeline):
VPBadEntryVote("__reset__", symbol, setup, "", 0);
VPBadEntryVote("__vote__",  symbol, setup, "feat_A", val_A);
VPBadEntryVote("__vote__",  symbol, setup, "feat_B", val_B);
VPBadEntryVote("__vote__",  symbol, setup, "feat_C", val_C);
if (VPBadEntryVote("__check__", symbol, setup, "", 0) == 1) {
    // block trade — bad entry detected
    return false;
}
```

## 8.4. Soft Tilt → winProbability (v4-7)

```text
Trước v4:  VPGetEdgeTiltMultiplier chỉ scale lot size
Từ v4:     Output còn được nhân vào m_state.winProbability
           → informational + ảnh hưởng tới lot sizing
           InpMinTiltThreshold (EA input): block trade nếu
           cumulative tilt (product của tất cả multipliers) < threshold
```

## 8.5. Consensus Targets (v4-8)

```text
Tính bởi _build_consensus_targets() trong data_loader.py:
  _all_styles_win:    1.0 nếu ALL 3 styles có lãi
  _all_styles_loss:   1.0 nếu ALL 3 styles thua
  _consensus_profit:  mean profit qua 3 styles
  _style_agree_count: số styles có lãi (0, 1, 2, hoặc 3)

Dùng bởi:
  - L4 khi target_mode = "all_styles_win" (dùng _all_styles_win làm target)
  - generate_guards_direct.py --cross-style-filter (dùng để post-filter)

KHÔNG dùng để:
  - Feature discovery (loại trừ khỏi avail_features)
  - Training bất kỳ model nào
```
