#ifndef LINALG_HPP
#define LINALG_HPP

#include "data.hpp"

#include <cmath>
#include <iostream>

template <class RealType, class IntegerType>
RealType dot(Field<RealType, IntegerType> const& x, Field<RealType, IntegerType> const& y) {
    IntegerType N = x.length();
    RealType result = 0.;
    for(IntegerType i=0; i < N; ++i)
        result += x[i] * y[i];
    return result;
};

template <class RealType, class IntegerType>
RealType norm2(Field<RealType, IntegerType> const& x) {
    IntegerType N = x.length();
    RealType result = 0.;
    for(IntegerType i=0; i < N; ++i)
        result += x[i] * x[i];
    return std::sqrt(result);
};

template <class RealType, class IntegerType>
void fill(Field<RealType, IntegerType>& x, const RealType value) {
    IntegerType N = x.length();
    for(IntegerType i=0; i < N; ++i) 
        x[i] = value;
};

//  blas level 1 vector-vector operations

// computes y := alpha*x
template <class RealType, class IntegerType>
void scale(Field<RealType, IntegerType>& y, const RealType alpha, Field<RealType, IntegerType> const& x) {
    IntegerType N = y.length();
    for(IntegerType i = 0; i < N; i++) {
        y[i] = alpha*x[i];
    }
};

// y = alpha*x + y
template <class RealType, class IntegerType>
void axpy(Field<RealType, IntegerType>& y, const RealType alpha, Field<RealType, IntegerType> const& x) {
    IntegerType N = x.length();
    for(IntegerType i=0; i < N; ++i)
        y[i] = alpha * x[i] + y[i];
};

// y := alpha*x + beta*z
template <class RealType, class IntegerType>
void lcomb(Field<RealType, IntegerType>& y, const RealType alpha, Field<RealType, IntegerType> const& x, const RealType beta,
               Field<RealType, IntegerType> const& z) {
    IntegerType N = x.length();
    for(IntegerType i=0; i < N; ++i)
        y[i] =  alpha*x[i] + beta*z[i];
};

// y := x
template <class RealType, class IntegerType>
void copy(Field<RealType, IntegerType>& y, Field<RealType, IntegerType> const& x) {
    IntegerType N = x.length();
    for(IntegerType i=0; i < N; ++i)
        y[i] =  x[i];
};

//  blas level 2 

// y = Ax
// where A is the matrix that described the 5 point stencil for the Poisson Equation
// boundaries use the boundary elements
template <class RealType, class IntegerType>
void stencil(Field<RealType, IntegerType>& y, Field<RealType, IntegerType> const& x) {
    IntegerType nx = x.xdim();
    IntegerType ny = x.ydim();

    // interior grid points
    for(IntegerType i = 1; i < nx-1; ++i) {
        for(IntegerType j = 1; j < ny-1; ++j) {
            y(i,j) = 4*x(i,j) 
                    - x(i-1,j) - x(i+1,j) 
                    - x(i,j-1) - x(i,j+1); 
        }
    }

    // north boundary (corners excluded)
    for(IntegerType i = 1; i < nx-1; ++i) {
        y(i,0) = 4*x(i,0) 
                - x(i-1,0) - x(i+1,0) - x(i,1); 
    }

    // south boundary (corners excluded)
    for(IntegerType i = 1; i < nx-1; ++i) {
        y(i,ny-1) = 4*x(i,ny-1) 
                - x(i-1,ny-1) - x(i+1,ny-1) - x(i,ny-2); 
    }

    // west boundary (corners excluded)
    for(IntegerType j = 1; j < ny-1; ++j) {
        y(0,j) = 4*x(0,j) 
                - x(1,j) - x(0,j-1) - x(0,j+1); 
    }

    // east boundary (corners excluded)
    for(IntegerType j = 1; j < ny-1; ++j) {
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
template <class RealType, class IntegerType>
IntegerType cg(Field<RealType, IntegerType>& u, Field<RealType, IntegerType> const& f, 
                const IntegerType maxiters, const RealType tol, RealType& residual, bool& success) {
    IntegerType nx = u.xdim();
    IntegerType ny = u.ydim();
    RealType alpha = 0.;
    RealType beta = 0.;    
    RealType one = static_cast<RealType>(1.0);            
    Field<RealType, IntegerType> r(nx, ny); 
    Field<RealType, IntegerType> r_old(nx, ny);
    Field<RealType, IntegerType> p(nx, ny);
    Field<RealType, IntegerType> Ap(nx, ny);
    IntegerType k = 0;
    stencil<RealType, IntegerType>(Ap, u);

    // initialize residual
    lcomb<RealType, IntegerType>(r, one, f, -one, Ap);
    residual = norm2<RealType, IntegerType>(r);
    // initialize step
    copy<RealType, IntegerType>(p, r);

    for(k = 0; (k < maxiters) && (residual > tol); ++k) {
        // precompute A*p_k
        stencil<RealType, IntegerType>(Ap, p);

        // alpha = <r_k,r_k>/<p_k,A*p_k>
        alpha = dot<RealType, IntegerType>(r, r)/dot<RealType, IntegerType>(p, Ap);

        // x_{k+1} = x_k + alpha_k*p_k
        axpy<RealType, IntegerType>(u, alpha, p);

        // store r_k
        copy<RealType, IntegerType>(r_old, r);
        // r_{k+1} = r_k - alpha_k * A*p_k
        axpy<RealType, IntegerType>(r, -alpha, Ap);
        // compute residual
        // std::cout << "residual = "<< residual << std::endl;
        residual = norm2<RealType, IntegerType>(r);

        // beta_k = <r_{k+1}, r_{k+1}>/<r_k,r_k>
        beta = dot<RealType, IntegerType>(r,r)/dot<RealType, IntegerType>(r_old,r_old);

        // p_{k+1} = r_{k+1} + beta_k*p_k
        lcomb<RealType, IntegerType>(p, one, r, beta, p);
    }

    success = (residual < tol);

    return k;
};

#endif 
