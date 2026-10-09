#ifndef LINALG_HPP
#define LINALG_HPP

#include "data.hpp"
#include "fixed.hpp"

#include <cmath>
#include <iostream>
#include <type_traits>

template <class RealType>
RealType dot(Field<RealType> const& x, Field<RealType> const& y) {
    int N = x.length();
    RealType result = 0.;
    for(int i=0; i < N; ++i)
        result += x[i] * y[i];
    return result;
};

template <class RealType>
RealType norm2(Field<RealType> const& x) {
    int N = x.length();
    RealType result = 0.;
    for(int i=0; i < N; ++i)
        result += x[i] * x[i];
    if constexpr (std::is_floating_point<RealType>::value)
        return std::sqrt(result);
    else
        return RealType(std::sqrt(result.to_double()));
};

template <class RealType>
void fill(Field<RealType>& x, const RealType value) {
    int N = x.length();
    for(int i=0; i < N; ++i) 
        x[i] = value;
};

//  blas level 1 vector-vector operations

// computes y := alpha*x
template <class RealType>
void scale(Field<RealType>& y, const RealType alpha, Field<RealType> const& x) {
    int N = y.length();
    for(int i = 0; i < N; i++) {
        y[i] = alpha*x[i];
    }
};

// y = alpha*x + y
template <class RealType>
void axpy(Field<RealType>& y, const RealType alpha, Field<RealType> const& x) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] = alpha * x[i] + y[i];
};

// y := alpha*x + beta*z
template <class RealType>
void lcomb(Field<RealType>& y, const RealType alpha, Field<RealType> const& x, const RealType beta,
               Field<RealType> const& z) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] =  alpha*x[i] + beta*z[i];
};

// y := x
template <class RealType>
void copy(Field<RealType>& y, Field<RealType> const& x) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] =  x[i];
};

//  blas level 2 

// y = Ax
// where A is the matrix that described the 5 point stencil for the Poisson Equation
// boundaries use the boundary elements
template <class RealType>
void stencil(Field<RealType>& y, Field<RealType> const& x) {
    int nx = x.xdim();
    int ny = x.ydim();

    // interior grid points
    for(int i = 1; i < nx-1; ++i) {
        for(int j = 1; j < ny-1; ++j) {
            y(i,j) = 4*x(i,j) 
                    - x(i-1,j) - x(i+1,j) 
                    - x(i,j-1) - x(i,j+1); 
        }
    }

    // north boundary (corners excluded)
    for(int i = 1; i < nx-1; ++i) {
        y(i,0) = 4*x(i,0) 
                - x(i-1,0) - x(i+1,0) - x(i,1); 
    }

    // south boundary (corners excluded)
    for(int i = 1; i < nx-1; ++i) {
        y(i,ny-1) = 4*x(i,ny-1) 
                - x(i-1,ny-1) - x(i+1,ny-1) - x(i,ny-2); 
    }

    // west boundary (corners excluded)
    for(int j = 1; j < ny-1; ++j) {
        y(0,j) = 4*x(0,j) 
                - x(1,j) - x(0,j-1) - x(0,j+1); 
    }

    // east boundary (corners excluded)
    for(int j = 1; j < ny-1; ++j) {
        y(nx-1,j) = 4*x(nx-1,j) 
                - x(nx-2,j) - x(nx-1,j-1) - x(nx-1,j+1); 
    }

    // NW corner
    y(0,0) = 4*x(0,0) - x(1,0) - x(0,1);

    // NE corner
    y(nx-1,0) = 4*x(nx-1,0)
            - x(nx-2,0) - x(nx-1,1);

    // SE corner
    y(nx-1,ny-1) = 4*x(nx-1,ny-1)
            - x(nx-2,ny-1) - x(nx-1,ny-2);

    // SW corner
    y(0,ny-1) = 4*x(0,ny-1)
            - x(1,ny-1) - x(0,ny-2);
};


// conjugate gradient solver
template <class RealType>
int cg(Field<RealType>& u, Field<RealType> const& f, 
                const int maxiters, const RealType tol, RealType& residual, bool& success) {
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
    stencil<RealType>(Ap, u);

    // initialize residual
    lcomb<RealType>(r, one, f, -one, Ap);
    residual = norm2<RealType>(r);
    // initialize step
    copy<RealType>(p, r);

    for(k = 0; (k < maxiters) && (residual > tol); ++k) {
        // precompute A*p_k
        stencil<RealType>(Ap, p);

        // alpha = <r_k,r_k>/<p_k,A*p_k>
        alpha = dot<RealType>(r, r)/dot<RealType>(p, Ap);

        // x_{k+1} = x_k + alpha_k*p_k
        axpy<RealType>(u, alpha, p);

        // store r_k
        copy<RealType>(r_old, r);
        // r_{k+1} = r_k - alpha_k * A*p_k
        axpy<RealType>(r, -alpha, Ap);
        // compute residual
        // std::cout << "residual = "<< residual << std::endl;
        residual = norm2<RealType>(r);

        // beta_k = <r_{k+1}, r_{k+1}>/<r_k,r_k>
        beta = dot<RealType>(r,r)/dot<RealType>(r_old,r_old);

        // p_{k+1} = r_{k+1} + beta_k*p_k
        lcomb<RealType>(p, one, r, beta, p);
    }

    success = (residual < tol);

    return k;
};

#endif 
