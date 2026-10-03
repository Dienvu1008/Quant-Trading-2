"""VP Analysis — Research pipeline with governance kernel."""
__version__ = "0.2.0"

from .pipeline import run_pipeline, PipelineResult
from .pipeline_config import PipelineConfig, load_config

__all__ = [
    "run_pipeline", "PipelineResult",
    "PipelineConfig", "load_config",
]
