"""Baseline physical-error sampling for the software experiment.

Implement independent data-qubit X and Z errors for the geometry defined in
``surface_code.py``. Provide reproducible sampling through an explicit random
seed or caller-supplied RNG, validate probabilities, and return errors in the
shared correction/error representation. A helper may enumerate all patterns for
exhaustive distance-3 tests.

Keep this module limited to data errors. Do not add measurement noise,
circuit-level noise, or quantum simulation until the baseline is verified.
"""
