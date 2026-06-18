"""Server memory embodied-carbon model: per-GB carbon by memory type.

Values come from the EcoServe paper (Table 1 / Section 3.1.2): TechInsights
"Micron 1a DRAM technology" (Nov 2024) + SK hynix HBM3e (2024), scaling
wafer-scale DRAM carbon by per-technology bit-density. This unifies EServe's GPU
and CPU memory coefficients onto one paper-backed source (HBM3e = 0.24 kgCO2e/GB),
replacing the GPU calculator's unsourced 0.85.

Kept float-based (no pint) so EServe's stdlib-style calculators can consume it.
"""
import os

import yaml

ACT_ROOT = os.path.dirname(__file__)
DEFAULT_MEMORY_CONFIG = f"{ACT_ROOT}/models/memory/server_memory.yaml"


class MemoryModel:
    """Per-GB embodied carbon (kgCO2e/GB) by memory type."""

    def __init__(self, model_file: str = DEFAULT_MEMORY_CONFIG):
        with open(model_file) as f:
            self.cf_per_gb = yaml.safe_load(f)

    def get_cpg(self, memory_type) -> float:
        """Embodied carbon per GB (kgCO2e/GB).

        Accepts a string (e.g. ``"HBM3e"``) or an enum with a ``.value``
        attribute (e.g. EServe's ``MemoryType.HBM3E``).
        """
        key = getattr(memory_type, "value", memory_type)
        if key not in self.cf_per_gb:
            raise KeyError(f"No memory carbon coefficient for memory type {key!r}")
        return float(self.cf_per_gb[key])

    def get_carbon(self, memory_type, capacity_gb: float) -> float:
        """Total embodied carbon (kgCO2e) for ``capacity_gb`` of a memory type."""
        return self.get_cpg(memory_type) * capacity_gb
