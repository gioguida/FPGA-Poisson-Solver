// FPGA-facing top-level wrapper for the baseline decoder.
//
// Define the project clock and active-low reset, the syndrome input transaction
// interface, and the correction output transaction interface here. Instantiate
// only the decoder integration logic needed for the first milestone, normally
// decoder_core and decoder_controller (and the syndrome buffer if used). Keep
// this module free of code-geometry knowledge except for shared parameters.
//
// State the cycle-level contract in comments before implementation: when an
// input is accepted, whether back-pressure exists, fixed latency to output, and
// what reset does to valid signals. Use synthesizable, vendor-neutral RTL.
