"""Distance-3 surface-code geometry and deterministic syndrome operations.

Define the single source of truth for the baseline code: data-qubit indices,
X- and Z-stabilizer indices and supports, boundary convention, logical X/Z
operators, syndrome-bit order, and correction-bit order. Expose small pure
functions to validate Pauli/error bit-vectors, calculate X and Z syndromes from
data-qubit errors, apply a candidate correction, and determine whether the
combined error has a logical component. Use integer/bit-vector representations
that can be written unchanged into RTL vectors.

Document every ordering explicitly. Do not model quantum amplitudes, noisy
measurement rounds, or a decoder algorithm here. Add unit tests for zero,
single-qubit, boundary, and representative multi-qubit errors.
"""
