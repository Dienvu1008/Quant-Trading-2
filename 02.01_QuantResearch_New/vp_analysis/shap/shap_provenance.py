"""SHAPProvenance — experiment identity and metadata tracking.

Every SHAP run is identified by a unique experiment_id derived from
the hash of (config, features, target, dataset). All outputs include
this ID so any result can be traced back to its exact inputs.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import uuid
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, List, Optional


# ─── Run metadata ────────────────────────────────────────────────

@dataclass
class SHAPRunMeta:
    """Immutable record of one SHAP analysis run."""
    experiment_id: str
    parent_pipeline_id: Optional[str]

    # Content hashes (for reproducibility audit)
    shap_config_hash: str
    dataset_hash: str          # hash of X feature matrix
    feature_names_hash: str    # hash of sorted feature names list
    model_hash: str            # hash of fitted model (set after fitting)
    code_hash: str             # hash of shap/ module files

    # Dataset summary
    target_name: str
    target_mode: str
    n_dev_rows: int            # rows before dedup
    n_signals: int             # signals after dedup
    n_features: int
    symbols: List[str]

    # Run config
    seed: int
    model_type: str

    # Timing
    ran_at: str
    elapsed_sec: float = 0.0

    # Status
    completed: bool = False
    null_result: bool = False
    warnings: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        d = asdict(self)
        return d

    def save(self, path: Path) -> None:
        """Write run_meta.json."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as fh:
            json.dump(self.to_dict(), fh, indent=2, default=str)

    @classmethod
    def load(cls, path: Path) -> "SHAPRunMeta":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        return cls(**data)


# ─── ID generation ───────────────────────────────────────────────

def make_experiment_id(prefix: str = "shap") -> str:
    """Generate a unique experiment ID with timestamp prefix."""
    ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
    uid = uuid.uuid4().hex[:8]
    return f"{prefix}_{ts}_{uid}"


def hash_config(config_dict: dict) -> str:
    """SHA-256 of canonicalised config dict."""
    canonical = json.dumps(
        _canonicalize(config_dict), sort_keys=True, separators=(",", ":")
    )
    return "sha256:" + hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def hash_feature_list(features: list) -> str:
    """SHA-256 of sorted feature names."""
    joined = "\n".join(sorted(str(f) for f in features))
    return "sha256:" + hashlib.sha256(joined.encode("utf-8")).hexdigest()


def hash_dataframe_sample(df, max_rows: int = 2000) -> str:
    """Stable hash of a DataFrame (columns + first max_rows values)."""
    try:
        import pandas as pd
        sample = df.head(max_rows)
        cols_str = ",".join(str(c) for c in sorted(sample.columns))
        vals_str = sample.to_csv(index=False)
        combined = cols_str + "\n" + vals_str
        return "sha256:" + hashlib.sha256(combined.encode("utf-8")).hexdigest()
    except Exception:
        return "sha256:unknown"


def hash_module_files(module_dir: Path) -> str:
    """Hash all .py files in the shap module directory."""
    py_files = sorted(Path(module_dir).glob("*.py"))
    h = hashlib.sha256()
    for f in py_files:
        try:
            h.update(f.read_bytes())
        except Exception:
            pass
    return "sha256:" + h.hexdigest()


def hash_model(model) -> str:
    """Hash a fitted model by serializing its params."""
    try:
        import joblib
        import io
        buf = io.BytesIO()
        joblib.dump(model, buf)
        return "sha256:" + hashlib.sha256(buf.getvalue()).hexdigest()
    except Exception:
        try:
            params_str = json.dumps(model.get_params(), sort_keys=True, default=str)
            return "sha256:" + hashlib.sha256(params_str.encode()).hexdigest()
        except Exception:
            return "sha256:unknown"


# ─── Helpers ─────────────────────────────────────────────────────

def _canonicalize(obj: Any) -> Any:
    """Convert obj to canonical JSON-serializable form."""
    if obj is None or isinstance(obj, (bool, int, str)):
        return obj
    if isinstance(obj, float):
        if obj != obj:
            return "__nan__"
        return repr(obj)
    if isinstance(obj, dict):
        return {str(k): _canonicalize(v) for k, v in sorted(obj.items())}
    if isinstance(obj, (list, tuple)):
        return [_canonicalize(x) for x in obj]
    if isinstance(obj, set):
        return sorted(_canonicalize(x) for x in obj)
    if isinstance(obj, Path):
        return str(obj)
    return str(obj)
