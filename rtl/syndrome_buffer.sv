// One-entry registered syndrome input stage.
//
// Implement this module only if the selected interface needs to hold an accepted
// syndrome while the decoder is working. It should capture a complete packed
// syndrome on an explicit accept event, present a stable stored value to the
// core, and expose full/empty or valid/consume control signals. Define its
// behavior for a simultaneous consume and new input, and clear its valid state
// synchronously on reset.
//
// Do not decode syndrome bits here. Parameterize only the syndrome width.
