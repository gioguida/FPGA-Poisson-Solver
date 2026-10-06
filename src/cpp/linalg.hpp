#ifndef LINALG_HPP
#define LINALG_HPP

#include "data.hpp"

//  blas level 1 reductions

double dot(Field const& x, Field const& y);

double norm2(Field const& x);

void fill(Field& x, const double value);

//  blas level 1 vector-vector operations

// y = alpha*x
void scale(Field& y, const double alpha, Field const& x);

// y = alpha*x + y
void axpy(Field& y, const double alpha, Field const& x);

// y := alpha*x + beta*z
void lcomb(Field& y, const double alpha, Field const& x, const double beta,
               Field const& z);

// y := x
void copy(Field& y, Field const& x);

// blas level 2
void stencil(Field& y, Field const& x);


// conjugate gradient solver
unsigned int cg(Field& u, Field const& f, 
                const int maxiters, const double tol, double& residual, bool& success);

#endif 
