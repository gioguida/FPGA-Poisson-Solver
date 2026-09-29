# FPGA Surface-Code Decoder

An educational implementation of a low-latency FPGA decoder for a distance-3 surface-code memory. The FPGA consumes classical syndrome information and produces a correction (or Pauli-frame update); quantum-state simulation stays in software.

## First milestone

Build and verify a classical distance-3 decoder for independent data-qubit X and Z errors. Start with a syndrome-to-correction lookup decoder: it is small, deterministic, synthesizable, and provides a sound baseline before attempting a more structured algorithm.

Before implementing the decoder, document the code geometry and conventions: data-qubit and stabilizer numbering, stabilizer supports, boundaries, logical operators, syndrome bit order, and correction bit order. Python and RTL must use exactly the same conventions.

## Layout

- `python/` - software model, error generation, reference decoder, and RTL test-vector generation.
- `rtl/` - synthesizable SystemVerilog decoder datapath and control.
- `tb/` - self-checking RTL testbench that compares RTL results with generated reference vectors.
- `docs/` - geometry, architecture, and verification notes (create these before the corresponding implementation grows).

## Recommended implementation order

1. Implement and test `python/surface_code.py`.
2. Add the independent error model and reference decoder.
3. Generate directed and randomized vectors.
4. Implement the RTL lookup decoder and controller.
5. Run the self-checking testbench, including reset and back-to-back inputs.
6. Synthesize only after functional verification passes; record latency, throughput, and resource use.

The initial milestone deliberately excludes repeated measurement rounds, measurement errors, full MWPM, scalable distances, host interfaces, and ML.
