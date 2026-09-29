// Self-checking SystemVerilog testbench for the baseline decoder.
//
// Generate a clock and reset, instantiate rtl/top.sv, and read vectors produced
// by python/generate_vectors.py. Drive each syndrome using the exact top-level
// transaction protocol; on every correction_valid, compare the full correction
// vector with the expected value and terminate with a nonzero simulation failure
// on a mismatch. Print enough case information to reproduce a failure.
//
// Cover reset, zero syndrome, all directed single-error cases, randomized cases,
// and back-to-back inputs. The testbench is simulation-only; do not place
// synthesizable decoder logic or manually derived expected corrections here.
