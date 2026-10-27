# Fixed-Point arithmetic specifications

This file contains the details of the Fidex-Point numerical format used in the FPGA implementation of a CG-based Poisson solver.

## Numerical Formats

The software fixed-point model stores solver fields as signed 32-bit Q values.
For a format with `F` fractional bits, dot products retain raw products at
`2F` fractional bits and accumulate them in a signed 72-bit accumulator.
The accumulator saturates and records an overflow. CG `alpha` and `beta` are
formed from the wide dot products, then truncated once back to the field Q
format. A zero denominator or scalar that cannot fit the field format causes
a controlled numerical-breakdown result.

|Quantity	                    | Signed    |	Total width |	Fractional bits |
| ---                           | ---       | ---           | ---               |
|$x,r,p,Ap$                     |	Yes     |	32          |	24              |
| Full multiplication product   |	Yes	    |64	            |   48              |
| Stored multiplication result	|Yes	    |32	            |24                 |
| Dot-product accumulator	    |Yes	    |72	            |48|
| Stored $\alpha,\beta$	        |Yes	    |32	            |24|
| Wide scalar division intermediates	    |yes	        |72	    | 48        |

## Arithmetic rules

Addition, Subtraction, Multiplication and (standard) Division all operate in the same way:
they take 32-bit Q values as inputs, convert them to 64-bit raw values, perform the operation with the needed shifts on 
the raw values, check overflow on this raw result and return a truncated 32-bit result without 
saturating. 

```c++
// Addition: a+b
wide = int64_t(a.to_raw()) + int64_t(b.to_raw());
/* Check for overflow... */
sum = fixed<8,24>::from_base(static_cast<int32_t>(wide));
```
Rounding: none. Addition keeps the Q8.24 binary-point position, so no fractional bits are removed. A result that fits in 32 bits is exact; an out-of-range result follows the documented overflow narrowing.

```c++
// SUbtraction: a-b
wide = int64_t(a.to_raw()) - int64_t(b.to_raw());
/* Check for overflow... */
sub = fixed<8,24>::from_base(static_cast<int32_t>(wide));
```
Rounding: none. Subtraction also keeps the Q8.24 binary-point position, so a representable result is exact. Only an out-of-range result loses information through the documented 32-bit narrowing.

```c++
// Multiplication: a*b
wide = int64_t(a.to_raw()) * int64_t(b.to_raw());
scaled = wide >> 24;    // scale back properly
/* Check for overflow... */
prod = fixed<8,24>::from_base(static_cast<int32_t>(scaled));
```
Rounding: `wide >> 24` is an arithmetic right shift. It rounds down: in units of the destination LSB, `+2.5` becomes `+2` and `-2.5` becomes `-3`. Exact results are unchanged.

```c++
// Division: a/b
numerator = int64_t(a.to_raw()) << 24  // perform the shift in the numerator
scaled = numerator / int64_t(b.to_raw());
/* Check for overflow... */
div = fixed<8,24>::from_base(static_cast<int32_t>(scaled));
```
Rounding: signed integer division truncates toward zero. In units of the destination LSB, `+2.5` becomes `+2` and `-2.5` becomes `-2`; exact quotients are unchanged.

A wider format is used for dot products and particularly sensible quantities.
Specifically, dot prods are computed on 72-bit values (`int128_t` with overflow checks at 72 bits), if overflow
occurs, the result is saturated at the corresponding 72-bits extremum.
Also the wide division uses this format, as it is used for computing $\alpha$ and $\beta$:
once the operation is performed using this higher precision, the results are truncated back to 32-bit values. 

Rounding: a dot product retains every Q16.48 raw product in the Q*.48 accumulator, so it performs no per-product or final rounding. Wide division for $\alpha$ and $\beta$ truncates its scaled signed quotient toward zero when converting it to Q8.24: `+2.5` becomes `+2` and `-2.5` becomes `-2` in destination-LSB units.

## Operation-specific precision

### Blas level-1 reductions:
As mentioned, the wide dot products uses wider type, and the euclidean norm 
uses directly the wide dot product and then computes the square root and truncates

```c++
result = dot_wide(x, x, s);
norm2 = fixed<8,24>(sqrt(static_cast<double>(result) / pow(2,2*24)));
```
### Blas level-1 vector-vector operations:

This class of operations contains `axpy` and `lcomb`, both use compositions of 
previously described operations:

```c++
// axpy: y = y + a*x
y[i] = checked_add(
        checked_mul(a, x[i]), 
        y[i]);
```
```c++
// lcomb: y = a*x + b*z
y[i] = checked_add(
        checked_mul(a, x[i]),
        checked_mul(b, z[i]));
```

### Blas level-2 stencil operator
The `stencil` function computes the Matrix-vector product that defines 
the action of the discretized 2D laplacian on the vector $x$:

$$
(Ax)_{i,j} = 4x_{i,j} -x_{i-1,j} -x_{i+1,j} -x_{i,j-1} -x_{i,j+1}.
$$

Just as the blas level-1 operations, this linear combination is obtained
by composing the previously described sum and multiplications.
First, the neighboring points are accumulated using a three-sum reduction,
second, the enighbor sum is subtracted from the center point multiplied by four

```cpp
// y(i,j) = 4x(i,j) - x(i-1,j) - x(i+1,j) - x(i,j-1) - x(i,j+1)
center4 = checked_mul(4.0, x(i,j));
north_south = checked_add(x(i,j-1), x(i,j+1));
west_east = checked_add(x(i-1,j), x(i+1,j));
neighbors = checked_add(north_south, west_east);
y(i,j) = checked_sub(center4, neighbors);
```

All points outside the $16 \times 16$ domain contribute to 0 in the computation, as prescribed by Dirichlet BC.

## Exceptional cases

### Overflow:
In all operations except for wide division, When an overflow occurs, execution isn't stopped but it is recorded and reported at the end of the execution. The overflow handling differs between different operations: for wide dot product, the returned value is clamped at the corresponding 72-bit extremum, while for the remaining operations, the truncated reuslt is returned.
Every operation has a custom overflow counter: `add_overflows`, `sub_overflows`, `mul_overflows`, `div_overflows`, `accumulation_overflows`. Additionally, the maximum 64-bit value encountered in the program execution is tracked as `max_abs_raw`,
ths is used to have an estimate of the distance from overflow in program execution.

On the other hand, when wide division detects an overflow, a flag `numerical_breakdown` is set to true and this causes execution to stop inside the CG solver.

### Zero denominator:
When a zero denominator is detected, both in the wide and standard division, the execution stops.
In standard division an exception is thrown, for wide division the flag `numerical_breakdown` is set to true and 
execution is therefore stopped in the CG solver.

## Verification contract

## Numerical justification

