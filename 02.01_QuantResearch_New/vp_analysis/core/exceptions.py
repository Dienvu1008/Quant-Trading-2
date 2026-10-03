"""Governance exception hierarchy.

All exceptions raised by the governance kernel inherit from GovernanceError,
so callers can catch them uniformly if needed.
"""


class GovernanceError(Exception):
    """Base class for all governance-related errors."""


class ContractValidationError(GovernanceError):
    """Raised when a ResearchContract is invalid or inconsistent."""


class ContractFrozenError(GovernanceError):
    """Raised when attempting to modify a frozen contract."""


class ManifestStateError(GovernanceError):
    """Raised on invalid ExperimentManifest state transition."""


class LineageError(GovernanceError):
    """Raised for DAG/lineage consistency violations."""


class BudgetExceededError(GovernanceError):
    """Raised when a selection budget constraint is violated."""


class CooldownError(GovernanceError):
    """Raised when experiments are run too close together."""


# ── Sprint 0B additions ─────────────────────────────────────────

class HoldoutSealedError(GovernanceError):
    """Raised when attempting to access sealed holdout data."""


class HoldoutAlreadyUnsealedError(GovernanceError):
    """Raised when unseal_once is called twice for the same experiment."""


class FrozenMutationError(GovernanceError):
    """Raised when attempting to mutate a frozen artifact."""


# ── Sprint 0C additions ─────────────────────────────────────────

class PoolRegistrationError(GovernanceError):
    """Raised on invalid FDR pool registration."""


class PoolCorrectedError(GovernanceError):
    """Raised when modifying or re-correcting an already-corrected FDR pool."""


class OptimizationError(GovernanceError):
    """Raised on invalid optimization registry operations."""
