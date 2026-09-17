"""iShamela data pipeline."""

from ishamela_data.build_bundle import SCHEMA_VERSION
from ishamela_data.normalizer import NORM_VERSION, normalize

__all__ = ["NORM_VERSION", "SCHEMA_VERSION", "normalize"]
