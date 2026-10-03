"""Information boundary: development vs sealed holdout.

Design principles:
  - The split is deterministic and recorded (split_time, split_ratio).
  - Development data is freely accessible for fitting and analysis.
  - Holdout is sealed by default; unsealing is:
      * Once per experiment_id
      * Logged with timestamp and reason
      * Persisted to disk (holdout_access.json) BEFORE data is returned
        so that a crash/restart cannot re-unseal the same experiment. [v3 Fix #4]
  - DataBoundary.apply(transformer) enforces fit-on-dev semantics:
    transformer.fit is called on dev only; holdout is transformed but
    remains sealed and shares the same access log.

v3 change (Fix #4):
  SealedHoldout.unseal_once() now accepts an optional persist_path. When
  provided it writes holdout_access.json to disk BEFORE returning the
  DataFrame. On construction, if the file already exists for the same
  experiment_id, it raises HoldoutAlreadyUnsealedError — preventing
  double-unseal even after a process restart.
"""
from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional, Protocol

import pandas as pd

from .exceptions import HoldoutAlreadyUnsealedError


# ─── Protocol for transformers ──────────────────────────────────

class FeatureTransformer(Protocol):
    """Fit on development DataFrame, transform any DataFrame with same schema."""
    def fit(self, dev_df: pd.DataFrame) -> Any: ...
    def transform(self, df: pd.DataFrame) -> pd.DataFrame: ...


# ─── Access logging ─────────────────────────────────────────────

@dataclass(frozen=True)
class HoldoutAccessRecord:
    experiment_id: str
    timestamp: str
    reason: str


class HoldoutAccessLog:
    """Persistent, shareable log of holdout unsealing events.

    The log is the source of truth for "has this experiment peeked at
    holdout?". Every derived SealedHoldout (after apply()) shares the
    same log instance so transformations cannot launder an access.

    v3 (Fix #4): persist_to_disk() writes the log to a JSON file.
    SealedHoldout.unseal_once() calls this BEFORE returning data so the
    record survives a crash between unseal and process completion.
    """

    def __init__(self) -> None:
        self._records: list[HoldoutAccessRecord] = []

    @property
    def records(self) -> tuple[HoldoutAccessRecord, ...]:
        return tuple(self._records)

    def __len__(self) -> int:
        return len(self._records)

    def has_unsealed(self, experiment_id: str) -> bool:
        return any(r.experiment_id == experiment_id for r in self._records)

    def record(self, experiment_id: str, reason: str) -> None:
        """Add an access record. Raises if already unsealed by this experiment."""
        if self.has_unsealed(experiment_id):
            raise HoldoutAlreadyUnsealedError(
                f"Experiment {experiment_id} has already unsealed this holdout"
            )
        self._records.append(HoldoutAccessRecord(
            experiment_id=experiment_id,
            timestamp=dt.datetime.utcnow().isoformat() + "Z",
            reason=reason,
        ))

    def persist_to_disk(self, path: Path) -> None:
        """Write current access log to path as JSON.

        Called BEFORE data is returned in unseal_once() so a crash cannot
        lead to a second unseal for the same experiment.
        """
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(self.to_dict(), indent=2),
            encoding="utf-8",
        )

    @classmethod
    def load_from_disk(cls, path: Path) -> "HoldoutAccessLog":
        """Restore a HoldoutAccessLog from a previously persisted file."""
        log = cls()
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        for item in data:
            # Bypass the duplicate check on reload (we're restoring history)
            log._records.append(HoldoutAccessRecord(
                experiment_id=item["experiment_id"],
                timestamp=item["timestamp"],
                reason=item["reason"],
            ))
        return log

    def to_dict(self) -> list[dict]:
        return [
            {
                "experiment_id": r.experiment_id,
                "timestamp": r.timestamp,
                "reason": r.reason,
            }
            for r in self._records
        ]


# ─── Data wrappers ──────────────────────────────────────────────

class DevelopmentData:
    """Read-only wrapper around the development DataFrame."""

    def __init__(self, df: pd.DataFrame):
        self._df = df

    @property
    def data(self) -> pd.DataFrame:
        """Read-only by convention. Do not mutate in place."""
        return self._df

    @property
    def columns(self) -> list[str]:
        return list(self._df.columns)

    def __len__(self) -> int:
        return len(self._df)

    def __repr__(self) -> str:
        return f"DevelopmentData(n={len(self._df)}, cols={len(self._df.columns)})"


class SealedHoldout:
    """Sealed holdout wrapper.

    Data is not accessible until unseal_once() is called. Metadata
    (size, columns, access_log) is always accessible.

    v3 Fix #4: unseal_once() accepts an optional persist_path. When
    provided:
      1. Checks disk for an existing holdout_access.json for this
         experiment_id — raises HoldoutAlreadyUnsealedError if found.
      2. Records the unseal in the in-memory log.
      3. Persists the updated log to disk BEFORE returning data.
    This makes the unseal atomic w.r.t. crashes: if step 3 fails the
    in-memory record is still present; if the process restarts without
    step 3 completing, the disk check in step 1 will not fire (the file
    was never written), so the log correctly reflects reality.
    """

    def __init__(
        self,
        df: pd.DataFrame,
        access_log: Optional[HoldoutAccessLog] = None,
    ):
        self._df = df
        self._access_log = access_log if access_log is not None else HoldoutAccessLog()

    @property
    def is_sealed(self) -> bool:
        return len(self._access_log) == 0

    @property
    def access_log(self) -> HoldoutAccessLog:
        return self._access_log

    @property
    def size(self) -> int:
        return len(self._df)

    @property
    def columns(self) -> list[str]:
        return list(self._df.columns)

    def unseal_once(
        self,
        experiment_id: str,
        reason: str,
        persist_path: Optional[Path] = None,
    ) -> pd.DataFrame:
        """Unseal holdout for a specific experiment.

        Args:
            experiment_id: The experiment requesting access.
            reason: Human-readable reason (logged for audit).
            persist_path: If provided, write holdout_access.json to this
                          path BEFORE returning data. [v3 Fix #4]

        Raises:
            HoldoutAlreadyUnsealedError: if experiment_id already unsealed,
                either in-memory or on disk (when persist_path is given).
        """
        # v3 Fix #4: check disk FIRST (survives restarts)
        if persist_path is not None:
            persist_path = Path(persist_path)
            if persist_path.exists():
                try:
                    existing = json.loads(
                        persist_path.read_text(encoding="utf-8")
                    )
                    ids_on_disk = {r["experiment_id"] for r in existing}
                    if experiment_id in ids_on_disk:
                        raise HoldoutAlreadyUnsealedError(
                            f"Experiment {experiment_id} has already unsealed "
                            f"this holdout (found in {persist_path})"
                        )
                except (json.JSONDecodeError, KeyError):
                    pass  # Corrupted file — let in-memory check be the arbiter

        # Record in-memory (raises if already unsealed by this experiment)
        self._access_log.record(experiment_id, reason)

        # v3 Fix #4: persist to disk BEFORE returning data
        if persist_path is not None:
            self._access_log.persist_to_disk(persist_path)

        return self._df

    def has_been_unsealed_by(self, experiment_id: str) -> bool:
        return self._access_log.has_unsealed(experiment_id)

    def __len__(self) -> int:
        return len(self._df)

    def __repr__(self) -> str:
        status = "sealed" if self.is_sealed else f"unsealed_by={len(self._access_log)}"
        return f"SealedHoldout(n={len(self._df)}, {status})"


# ─── Orchestrator ───────────────────────────────────────────────

class DataBoundary:
    """Coordinates split, access control, and fit-on-dev semantics.

    Lifecycle:
        boundary = DataBoundary.from_merged(merged, split_ratio=0.70)
        boundary2 = boundary.apply(MyTransformer())
        holdout_df = boundary2.holdout.unseal_once(
            experiment_id, reason, persist_path=output_dir/"holdout_access.json"
        )
    """

    def __init__(
        self,
        dev: DevelopmentData,
        holdout: SealedHoldout,
        split_time: Optional[str] = None,
        split_method: str = "temporal",
        split_ratio: Optional[float] = None,
    ):
        self._dev = dev
        self._holdout = holdout
        self.split_time = split_time
        self.split_method = split_method
        self.split_ratio = split_ratio

    # ─── Factory ────────────────────────────────────────────────

    @classmethod
    def from_merged(
        cls,
        merged_df: pd.DataFrame,
        split_ratio: float = 0.70,
        split_method: str = "temporal",
        time_col: str = "time",
    ) -> "DataBoundary":
        if not (0.0 < split_ratio < 1.0):
            raise ValueError(f"split_ratio must be in (0,1), got {split_ratio}")

        df = merged_df.copy()

        if split_method == "temporal":
            if time_col not in df.columns:
                raise ValueError(
                    f"split_method='temporal' requires column {time_col!r}"
                )
            df = df.sort_values(time_col).reset_index(drop=True)
            split_idx = int(len(df) * split_ratio)
            split_time = (
                str(df[time_col].iloc[split_idx])
                if 0 < split_idx < len(df) else None
            )
        elif split_method == "random":
            df = df.sample(frac=1.0, random_state=42).reset_index(drop=True)
            split_idx = int(len(df) * split_ratio)
            split_time = None
        else:
            raise ValueError(
                f"split_method must be 'temporal' or 'random', got {split_method!r}"
            )

        dev_df = df.iloc[:split_idx].reset_index(drop=True)
        holdout_df = df.iloc[split_idx:].reset_index(drop=True)

        return cls(
            dev=DevelopmentData(dev_df),
            holdout=SealedHoldout(holdout_df),
            split_time=split_time,
            split_method=split_method,
            split_ratio=split_ratio,
        )

    # ─── Access ─────────────────────────────────────────────────

    @property
    def dev(self) -> DevelopmentData:
        return self._dev

    @property
    def holdout(self) -> SealedHoldout:
        return self._holdout

    # ─── Fit-on-dev pattern ─────────────────────────────────────

    def apply(self, transformer: FeatureTransformer) -> "DataBoundary":
        """Fit transformer on dev, apply to both dev and holdout.

        The holdout result is a new SealedHoldout that shares the same
        access log. Transforming holdout does NOT count as unsealing.
        """
        transformer.fit(self._dev.data)
        dev_new = DevelopmentData(transformer.transform(self._dev.data))
        holdout_new = SealedHoldout(
            transformer.transform(self._holdout._df),
            access_log=self._holdout.access_log,
        )
        return DataBoundary(
            dev=dev_new,
            holdout=holdout_new,
            split_time=self.split_time,
            split_method=self.split_method,
            split_ratio=self.split_ratio,
        )

    # ─── Audit ──────────────────────────────────────────────────

    def audit_info(self) -> dict:
        return {
            "split_method": self.split_method,
            "split_ratio": self.split_ratio,
            "split_time": self.split_time,
            "dev_size": len(self._dev),
            "holdout_size": self._holdout.size,
            "holdout_accesses": self._holdout.access_log.to_dict(),
        }

    def __repr__(self) -> str:
        return (
            f"DataBoundary(dev_n={len(self._dev)}, "
            f"holdout_n={self._holdout.size}, "
            f"split={self.split_method}@{self.split_time}, "
            f"holdout_sealed={self._holdout.is_sealed})"
        )
