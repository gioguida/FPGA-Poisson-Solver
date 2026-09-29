// Sequential control for decoder input acceptance and output validity.
//
// Implement a small synchronous finite-state machine or valid pipeline around
// decoder_core. It must define the input accept condition, capture/hold syndrome
// data when needed, assert correction_valid for exactly the documented output
// transaction, and support the intended back-to-back behavior. Keep the
// correction calculation in decoder_core and the storage/handshake policy here.
//
// Use one clock, explicit synchronous reset behavior, default assignments in
// combinational logic, and a documented constant latency. Test reset, idle,
// ordinary transfers, and consecutive inputs.
