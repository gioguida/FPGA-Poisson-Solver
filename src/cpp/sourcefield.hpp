#ifndef SOURCEFIELD_HPP
#define SOURCEFIELD_HPP

#include <fstream>
#include <iostream>
#include <cstring>
#include <string>
#include <vector>
#include <cmath>
#include <cstdint>
#include <variant>

#include "utils.hpp"


/*** WRITE RHS AND EXACT SOLUTIONS VECTORS ***/

using int_value_t = std::variant<
    std::int8_t,
    std::int16_t,
    std::int32_t,
    std::int64_t
>;

int_value_t make_int(int total_bits);

void write_vectors(
    int test_case,
    int nx,
    int iterations,
    int int_bits,
    int fractional_bits
);


/*** BENCHMARK FORCE FIELDS AND EXACT SOLUTIONS ***/


// single sine mode f = -\Delta u(x,y) = 2*pi^2*sin(pi*x)*sin(pi*y)
double singleSine_f (const double x, const double y);

// single sine mode u(x,y) = sin(pi*x)*sin(pi*y)
double singleSine_u (const double x, const double y);

// higher frequency sine mode f = -\Delta u(x,y) = (k^2 + l^2)*pi^2 * sin(k*pi*x)*sin(l*pi*y)
double highFreqSine_f (const double x, const double y, const int k, const int l);

// higher frequency sine mode u(x,y) = sin(k*pi*x)*sin(l*pi*y)
double highFreqSine_u (const double x, const double y, const int k, const int l);

// Polynomial manufactured solution f = 2(x(1-x) + y(1-y))
double polynomial_f (const double& x, const double& y);

// Polynomial manufactured solution u(x,y) = x(1-x)y(1-y)
double polynomial_u (const double& x, const double& y);

#endif
