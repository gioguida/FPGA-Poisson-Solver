#ifndef LINALG_HPP
#define LINALG_HPP

#include "data.hpp"
#include "fixed.hpp"

#include <cmath>
#include <iostream>
#include <type_traits>
#include <cstdint>
#include <cstddef>
#include <limits>
#include <algorithm>
#include <cstdlib>

/*** CHECKED OPERATIONS ***/

template<class T>
struct is_numeric_fixed : std::false_type {};

template<std::size_t IntegerBits, std::size_t FractionalBits>
struct is_numeric_fixed<numeric::fixed<IntegerBits, FractionalBits>>
    : std::true_type {
    static constexpr std::size_t integer_bits = IntegerBits;
    static constexpr std::size_t fractional_bits = FractionalBits;
    static constexpr std::size_t total_bits = IntegerBits + FractionalBits;
};

struct Stats {
    std::size_t total_overflow_count = 0;
    std::size_t add_overflows = 0;
    std::size_t sub_overflows = 0;
    std::size_t mul_overflows = 0;
    std::size_t div_overflows = 0;
    std::size_t accumulation_overflows = 0;

    std::int64_t max_abs_raw = 0;
};

inline Stats& default_stats() {
    static Stats stats;
    return stats;
}

template<class RealType>
RealType checked_add(RealType a, RealType b, Stats& s) {
    if constexpr (is_numeric_fixed<RealType>::value) {
        int64_t wide = int64_t(a.to_raw()) + int64_t(b.to_raw());
        using BaseType = typename RealType::base_type;

        s.max_abs_raw = std::max(s.max_abs_raw, std::abs(wide));

        if (wide > std::numeric_limits<BaseType>::max() ||
            wide < std::numeric_limits<BaseType>::min()) {
            ++s.add_overflows;
            ++s.total_overflow_count;
        }
        return RealType::from_base(static_cast<typename RealType::base_type>(wide));
    }
    return a + b;
}

template<class RealType>
RealType checked_sub(RealType a, RealType b, Stats& s) {
    if constexpr (is_numeric_fixed<RealType>::value) {
        int64_t wide = int64_t(a.to_raw()) - int64_t(b.to_raw());
        using BaseType = typename RealType::base_type;

        s.max_abs_raw = std::max(s.max_abs_raw, std::abs(wide));

        if (wide > std::numeric_limits<BaseType>::max() ||
            wide < std::numeric_limits<BaseType>::min()) {
            ++s.sub_overflows;
            ++s.total_overflow_count;
        }

        return RealType::from_base(static_cast<typename RealType::base_type>(wide));
    }
    return a - b;
}

template<class RealType>
RealType checked_mul(RealType a, RealType b, Stats& s) {
    if constexpr (is_numeric_fixed<RealType>::value) {
        int64_t wide = int64_t(a.to_raw()) * int64_t(b.to_raw());
        int64_t scaled = wide >> RealType::fractional_bits;
        using BaseType = typename RealType::base_type;

        s.max_abs_raw = std::max(s.max_abs_raw, std::abs(scaled));

        if (scaled > std::numeric_limits<BaseType>::max() ||
            scaled < std::numeric_limits<BaseType>::min()) {
            ++s.mul_overflows;
            ++s.total_overflow_count;
        }
        return RealType::from_base(static_cast<typename RealType::base_type>(scaled));
    }
    return a * b;
}

template<class RealType>
RealType checked_div(RealType a, RealType b, Stats& s) {
    if constexpr (is_numeric_fixed<RealType>::value) {
        if (b.to_raw() == 0)
            throw std::runtime_error("division by zero");

        int64_t numerator = int64_t(a.to_raw()) << RealType::fractional_bits;
        int64_t scaled = numerator / int64_t(b.to_raw());
        using BaseType = typename RealType::base_type;

        s.max_abs_raw = std::max(s.max_abs_raw, std::abs(scaled));

        if (scaled > std::numeric_limits<BaseType>::max() ||
            scaled < std::numeric_limits<BaseType>::min()) {
            ++s.div_overflows;
            ++s.total_overflow_count;
        }
        return RealType::from_base(static_cast<typename RealType::base_type>(scaled));
    }
    return a / b;
}

template<class RealType>
RealType checked_accumulate(RealType a, RealType b, Stats& s) {
    const std::size_t overflows = s.total_overflow_count;
    RealType result = checked_add(a, b, s);
    if (s.total_overflow_count != overflows)
        ++s.accumulation_overflows;
    return result;
}

/*** blas level 1 reductions ***/

template <class RealType>
RealType dot(Field<RealType> const& x, Field<RealType> const& y,
             Stats& s ) {
    int N = x.length();
    RealType result = 0.;
    for(int i=0; i < N; ++i)
        result = checked_accumulate(
            result, checked_mul(x[i], y[i], s), s);
    return result;
};

template <class RealType>
RealType norm2(Field<RealType> const& x, Stats& s ) {
    int N = x.length();
    RealType result = 0.;
    for(int i=0; i < N; ++i)
        result = checked_accumulate(
            result, checked_mul(x[i], x[i], s), s);
    if constexpr (std::is_floating_point<RealType>::value)
        return std::sqrt(result);
    else
        return RealType(std::sqrt(result.to_double()));
};

template <class RealType>
void fill(Field<RealType>& x, const RealType value,
          Stats& s ) {
    int N = x.length();
    for(int i=0; i < N; ++i) 
        x[i] = value;
};

/*** blas level 1 vector-vector operations ***/

// computes y := alpha*x
template <class RealType>
void scale(Field<RealType>& y, const RealType alpha,
           Field<RealType> const& x, Stats& s ) {
    int N = y.length();
    for(int i = 0; i < N; ++i)
        y[i] = checked_mul(alpha, x[i], s);
};

// y = alpha*x + y
template <class RealType>
void axpy(Field<RealType>& y, const RealType alpha,
          Field<RealType> const& x, Stats& s ) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] = checked_add(checked_mul(alpha, x[i], s), y[i], s);
};

// y := alpha*x + beta*z
template <class RealType>
void lcomb(Field<RealType>& y, const RealType alpha, Field<RealType> const& x, const RealType beta,
           Field<RealType> const& z, Stats& s ) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] = checked_add(
            checked_mul(alpha, x[i], s),
            checked_mul(beta, z[i], s), s);
};

// y := x
template <class RealType>
void copy(Field<RealType>& y, Field<RealType> const& x,
          Stats& s ) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] =  x[i];
};

/*** blas level 2 ***/

// y = Ax
// where A is the matrix that described the 5 point stencil for the Poisson Equation
// boundaries use the boundary elements
template <class RealType>
void stencil(Field<RealType>& y, Field<RealType> const& x,
             Stats& s ) {
    int nx = x.xdim();
    int ny = x.ydim();

    // interior grid points
    for(int i = 1; i < nx-1; ++i) {
        for(int j = 1; j < ny-1; ++j) {
            y(i,j) = checked_sub(
                checked_sub(
                    checked_sub(
                        checked_sub(
                            checked_mul(RealType(4), x(i,j), s),
                            x(i-1,j), s),
                        x(i+1,j), s),
                    x(i,j-1), s),
                x(i,j+1), s);
        }
    }

    // north boundary (corners excluded)
    for(int i = 1; i < nx-1; ++i) {
        y(i,0) = checked_sub(
            checked_sub(
                checked_sub(
                    checked_mul(RealType(4), x(i,0), s),
                    x(i-1,0), s),
                x(i+1,0), s),
            x(i,1), s);
    }

    // south boundary (corners excluded)
    for(int i = 1; i < nx-1; ++i) {
        y(i,ny-1) = checked_sub(
            checked_sub(
                checked_sub(
                    checked_mul(RealType(4), x(i,ny-1), s),
                    x(i-1,ny-1), s),
                x(i+1,ny-1), s),
            x(i,ny-2), s);
    }

    // west boundary (corners excluded)
    for(int j = 1; j < ny-1; ++j) {
        y(0,j) = checked_sub(
            checked_sub(
                checked_sub(
                    checked_mul(RealType(4), x(0,j), s),
                    x(1,j), s),
                x(0,j-1), s),
            x(0,j+1), s);
    }

    // east boundary (corners excluded)
    for(int j = 1; j < ny-1; ++j) {
        y(nx-1,j) = checked_sub(
            checked_sub(
                checked_sub(
                    checked_mul(RealType(4), x(nx-1,j), s),
                    x(nx-2,j), s),
                x(nx-1,j-1), s),
            x(nx-1,j+1), s);
    }

    // NW corner
    y(0,0) = checked_sub(
        checked_sub(checked_mul(RealType(4), x(0,0), s), x(1,0), s),
        x(0,1), s);

    // NE corner
    y(nx-1,0) = checked_sub(
        checked_sub(
            checked_mul(RealType(4), x(nx-1,0), s), x(nx-2,0), s),
        x(nx-1,1), s);

    // SE corner
    y(nx-1,ny-1) = checked_sub(
        checked_sub(
            checked_mul(RealType(4), x(nx-1,ny-1), s),
            x(nx-2,ny-1), s),
        x(nx-1,ny-2), s);

    // SW corner
    y(0,ny-1) = checked_sub(
        checked_sub(
            checked_mul(RealType(4), x(0,ny-1), s), x(1,ny-1), s),
        x(0,ny-2), s);
};


// conjugate gradient solver
template <class RealType>
int cg(Field<RealType>& u, Field<RealType> const& f, 
       const int maxiters, const RealType tol, RealType& residual,
       bool& success, Stats& s ) {
    int nx = u.xdim();
    int ny = u.ydim();
    RealType alpha = 0.;
    RealType beta = 0.;    
    RealType one = static_cast<RealType>(1.0);            
    Field<RealType> r(nx, ny); 
    Field<RealType> r_old(nx, ny);
    Field<RealType> p(nx, ny);
    Field<RealType> Ap(nx, ny);
    int k = 0;
    stencil<RealType>(Ap, u, s);

    // initialize residual
    lcomb<RealType>(r, one, f, checked_sub(RealType(0), one, s), Ap, s);
    residual = norm2<RealType>(r, s);
    // initialize step
    copy<RealType>(p, r, s);

    for(k = 0; (k < maxiters) && (residual > tol); ++k) {
        // precompute A*p_k
        stencil<RealType>(Ap, p, s);

        // alpha = <r_k,r_k>/<p_k,A*p_k>
        alpha = checked_div(dot<RealType>(r, r, s),
                            dot<RealType>(p, Ap, s), s);

        // x_{k+1} = x_k + alpha_k*p_k
        axpy<RealType>(u, alpha, p, s);

        // store r_k
        copy<RealType>(r_old, r, s);
        // r_{k+1} = r_k - alpha_k * A*p_k
        axpy<RealType>(r, checked_sub(RealType(0), alpha, s), Ap, s);
        // compute residual
        // std::cout << "residual = "<< residual << std::endl;
        residual = norm2<RealType>(r, s);

        // beta_k = <r_{k+1}, r_{k+1}>/<r_k,r_k>
        beta = checked_div(dot<RealType>(r, r, s),
                           dot<RealType>(r_old, r_old, s), s);

        // p_{k+1} = r_{k+1} + beta_k*p_k
        lcomb<RealType>(p, one, r, beta, p, s);
    }

    success = (residual < tol);

    return k;
};

#endif 
