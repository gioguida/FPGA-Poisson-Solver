"""Golden classical decoder for the documented distance-3 conventions.

Implement the same deterministic syndrome-to-correction mapping that the first
RTL decoder will implement. Decode X and Z channels independently where the
chosen conventions allow it, and return a correction in the exact packed order
defined by ``surface_code.py``. Build and validate the lookup mapping from known
error patterns or a documented tie-breaking rule; every syndrome must have a
deterministic result.

Include helpers that evaluate whether an error followed by a correction succeeds
or leaves a logical error. This is the oracle for vector generation, not a
hardware model and not a scalable MWPM implementation.
"""
