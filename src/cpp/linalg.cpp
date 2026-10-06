#include "linalg.hpp"
#include <cmath>
#include <iostream>

double dot(Field const& x, Field const& y) {
    int N = x.length();
    double result = 0.;
    for(int i=0; i < N; ++i)
        result += x[i] * y[i];
    return result;
}

double norm2(Field const& x) {
    int N = x.length();
    double result = 0.;
    for(int i=0; i < N; ++i)
        result += x[i] * x[i];
    return std::sqrt(result);
}

void fill(Field& x, const double value) {
    int N = x.length();
    for(int i=0; i < N; ++i) 
        x[i] = value;
}

//  blas level 1 vector-vector operations

// computes y := alpha*x
void scale(Field& y, const double alpha, Field const& x) {
    int N = y.length();
    for(int i = 0; i < N; i++) {
        y[i] = alpha*x[i];
    }
}

// y = alpha*x + y
void axpy(Field& y, const double alpha, Field const& x) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] = alpha * x[i] + y[i];
}

// y := alpha*x + beta*z
void lcomb(Field& y, const double alpha, Field const& x, const double beta,
               Field const& z) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] =  alpha*x[i] + beta*z[i];
}

// y := x
void copy(Field& y, Field const& x) {
    int N = x.length();
    for(int i=0; i < N; ++i)
        y[i] =  x[i];
}

//  blas level 2 

// y = Ax
// where A is the matrix that described the 5 point stencil for the Poisson Equation
// boundaries use the boundary elements
void stencil(Field& y, Field const& x) {
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
}


// conjugate gradient solver
unsigned int cg(Field& u, Field const& f, 
                const int maxiters, const double tol, double& residual, bool& success) {
    int nx = u.xdim();
    int ny = u.ydim();
    double alpha = 0.;
    double beta = 0.;                
    Field r(nx, ny); 
    Field r_old(nx, ny);
    Field p(nx, ny);
    Field Ap(nx, ny);
    unsigned int k = 0;
    stencil(Ap, u);

    // initialize residual
    lcomb(r, 1.0, f, -1.0, Ap);
    residual = norm2(r);
    // initialize step
    copy(p, r);

    for(k = 0; (k < maxiters) && (residual > tol); ++k) {
        // precompute A*p_k
        stencil(Ap, p);

        // alpha = <r_k,r_k>/<p_k,A*p_k>
        alpha = dot(r, r)/dot(p, Ap);

        // x_{k+1} = x_k + alpha_k*p_k
        axpy(u, alpha, p);

        // store r_k
        copy(r_old, r);
        // r_{k+1} = r_k - alpha_k * A*p_k
        axpy(r, -alpha, Ap);
        // compute residual
        // std::cout << "residual = "<< residual << std::endl;
        residual = norm2(r);

        // beta_k = <r_{k+1}, r_{k+1}>/<r_k,r_k>
        beta = dot(r,r)/dot(r_old,r_old);

        // p_{k+1} = r_{k+1} + beta_k*p_k
        lcomb(p, 1.0, r, beta, p);
    }

    success = (residual < tol);

    return k;
}