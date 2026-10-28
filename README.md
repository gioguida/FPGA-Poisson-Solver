# FPGA-CG-Poisson Solver

The aim of this project is to build an FPGA solver for the 2D Poisson Equation using the finite differences method coupled with a matrix-free conjugate gradient.

## 2D Poisson Equation

The poisson equation is the `"hello world"` of partial differential equations.
I chose it for this project because it allowed me to focus on the implementation and learning to work with HDL.

The problem I aim to solve is the 2D Poisson equation on the unit square with homogeneous Dirichlet boundary conditions:

$$ 
    \begin{cases}
        \begin{align*}
            -\Delta u &= f \quad \text{for} \quad u \in \Omega \\
            u &= 0 \quad \text{for} \quad u \in \partial\Omega
        \end{align*}
    \end{cases} 
    \qquad \text{where} \quad \Omega = (0,1)^2 
$$

## Discretization

The equation is diescretized using finite differences, in particular, the formula to approximate the second derivative of the function $v$
at $ z $, is

$$ 
    \frac{d^2 v}{d z^2}(z) \approx D^2_h v(z) = \frac{v(z-h) - 2v(z) + v(z+h)}{h^2}
$$

where $h$ is the discretization step. Using this formula to compute both second partial derivatives of $u$, the laplacian of $u$ at point $(x,y)$ is approximated as

$$
    \Delta u (x,y)  \approx \frac{u(x-h,y) + u(x+h,y) + u(x,y-h)+ u(x,y+h)-4u(x,y)}{h^2}
$$

I will call this the 5-points Poisson stencil.
I order to compute the approximated laplacian using the stencl formula, 
the center value and its four nearest neighbors are used. For neighbors outside the grid, the homogeneous Dirichlet boundary value is zero.

With the sign convention $-\Delta u=f$, the discrete equation at grid point $(i,j)$ is

$$
4u_{i,j}-u_{i-1,j}-u_{i+1,j}-u_{i,j-1}-u_{i,j+1}=h^2f_{i,j}.
$$

## Numerical method

The stencil defines a linear system $Au=b$, where $b_{i,j}=h^2f_{i,j}$. Conjugate Gradient solves it by repeatedly applying the stencil to a search direction, computing dot products, and updating the solution, residual, and search direction. The planned RTL solver uses fixed-point arithmetic and a fixed iteration count for deterministic latency.
