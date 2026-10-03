"""Deterministic hashing utilities for research provenance.

All hashes must be:
  - Deterministic: same input → same hash
  - Stable across Python versions and platforms
  - Canonical: independent of dict ordering, whitespace

Format: 'sha256:<hex>' so hash type is self-describing.
"""
from __future__ import annotations

import fnmatch
import hashlib
import json
from pathlib import Path
from typing import Any, Iterable

import pandas as pd


# ─── String / object hashing ────────────────────────────────────

def hash_string(s: str) -> str:
    return "sha256:" + hashlib.sha256(s.encode("utf-8")).hexdigest()


def _canonicalize(obj: Any) -> Any:
    """Convert obj to canonical form for stable hashing."""
    if obj is None or isinstance(obj, (bool, int, str)):
        return obj
    if isinstance(obj, float):
        if obj != obj:               # NaN
            return "__nan__"
        if obj == float("inf"):
            return "__inf__"
        if obj == float("-inf"):
            return "__-inf__"
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


def hash_dict(d: dict) -> str:
    canonical = _canonicalize(d)
    serialized = json.dumps(canonical, sort_keys=True, separators=(",", ":"))
    return hash_string(serialized)


# ─── File / directory hashing ───────────────────────────────────

def hash_file(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def hash_files(
    paths: Iterable[Path],
    exclude_patterns: Iterable[str] = (),
) -> str:
    """Hash a set of files in deterministic order.

    exclude_patterns: fnmatch patterns applied to the full path string.
    Directories are expanded recursively.
    """
    exclude_patterns = list(exclude_patterns)
    collected: list[Path] = []

    for p in paths:
        p = Path(p)
        if not p.exists():
            continue
        candidates = p.rglob("*") if p.is_dir() else [p]
        for f in candidates:
            if not f.is_file():
                continue
            if any(fnmatch.fnmatch(str(f), pat) for pat in exclude_patterns):
                continue
            collected.append(f)

    collected = sorted(set(collected), key=lambda x: str(x))
    per_file = [{"path": str(f), "hash": hash_file(f)} for f in collected]
    return hash_dict({"files": per_file})


# ─── DataFrame hashing ──────────────────────────────────────────

def hash_dataframe(
    df: pd.DataFrame,
    exclude_cols: Iterable[str] = (),
) -> str:
    """Stable hash of a DataFrame's content.

    Uses pandas' built-in hashing. Columns are sorted for determinism;
    excluded columns are dropped before hashing.
    """
    exclude_cols = set(exclude_cols)
    cols = [c for c in sorted(df.columns) if c not in exclude_cols]
    subset = df[cols]
    h = hashlib.sha256(
        pd.util.hash_pandas_object(subset, index=True).values.tobytes()
    )
    return "sha256:" + h.hexdigest()
