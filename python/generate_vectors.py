"""Generate self-checking software-to-RTL decoder test vectors.

Use ``noise_model``, ``surface_code``, and ``reference_decoder`` to create
directed vectors (zero error, every single-qubit error, boundary cases) plus
seeded randomized and back-to-back cases. For each case, write the packed input
syndrome, expected correction, and any metadata needed to diagnose a failure.
Choose one simple, documented text format that SystemVerilog can read reliably
(for example, one fixed-width binary record per line).

Make output paths, vector count, and seed configurable. Do not hand-maintain
expected RTL results in this file: all expected values must come from the
reference decoder.
"""
