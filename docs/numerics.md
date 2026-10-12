# Numerical contract

The software fixed-point model stores solver fields as signed 32-bit Q values.
For a format with `F` fractional bits, dot products retain raw products at
`2F` fractional bits and accumulate them in a signed 72-bit accumulator.
The accumulator saturates and records an overflow. CG `alpha` and `beta` are
formed from the wide dot products, then truncated once back to the field Q
format. A zero denominator or scalar that cannot fit the field format causes
a controlled numerical-breakdown result.
