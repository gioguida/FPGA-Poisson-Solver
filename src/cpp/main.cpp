// ******************************************
// implicit time stepping implementation of 2D diffusion problem
// Ben Cumming, CSCS
// *****************************************

// A small benchmark app that solves the 2D fisher equation using second-order
// finite differences.

// Syntax: ./main nx nt t [verbose]

#include <algorithm>
#include <fstream>
#include <iostream>

#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <cstring>


#include "data.hpp"
#include "linalg.hpp"
#include "walltime.hpp"

// =============================================================================

// read command line arguments
void readcmdline(Discretization& options, int argc, char* argv[]) {
    if (argc<2 || argc>3) {
        std::cerr << "Usage: main nx iters \n";
        std::cerr << "  nx      number of grid points in x-direction and "
                               "y-direction, respectively\n";
        std::cerr << " iters    number of CG iterations\n";
        exit(1);
    }

    // read nx
    options.nx = atoi(argv[1]);
    if (options.nx < 1) {
        std::cerr << "nx must be positive integer\n";
        exit(-1);
    }

    options.iters = atoi(argv[2]);
    if (options.iters < 1) {
        std::cerr << "iters must be positive integer\n";
        exit(-1);
    }

    // set total number of grid points
    options.N = options.nx * options.nx;

    // set distance between grid points
    // assume that x dimension has length 1.0
    options.dx = 1. / (options.nx - 1);
}

// =============================================================================

int main(int argc, char* argv[]) {
    // read command line arguments
    readcmdline(options, argc, argv);
    int nx = options.nx;
    int N  = options.N;

    // set iteration parameters
    int max_cg_iters = options.iters;
    double tolerance     = 1.e-6;

    // get number of threads
    // int threads = 1; // serial case

    // welcome message
    std::cout << std::string(80, '=') << std::endl;
    std::cout << "                      Welcome to mini-stencil!" << std::endl;
    std::cout << "version   :: C++ Serial" << std::endl;
    std::cout << "mesh      :: " << options.nx << " * " << options.nx
                                 << " dx = " << options.dx << std::endl;
    std::cout << "iteration :: " << "CG "          << max_cg_iters
                                 << ", tolerance " << tolerance << std::endl;
    std::cout << std::string(80, '=') << std::endl;

    // allocate global fields
    u.init(nx, nx);
    bndN.init(nx, 1);
    bndS.init(nx, 1);
    bndE.init(nx, 1);
    bndW.init(nx, 1);

    Field f(nx, nx);
    Field h2f(nx, nx);
    Field deltay(nx, nx);

    // set Dirichlet boundary conditions to 0 all around
    double const_bdy = 0;
    fill(bndN, const_bdy);
    fill(bndS, const_bdy);
    fill(bndE, const_bdy);
    fill(bndW, const_bdy);

    // set the initial condition
    // a circle of concentration 0.125 centred at (xdim/4, ydim/4) with radius
    // no larger than 1/8 of both xdim and ydim
    double const_fill = 0;
    double inner_circle = 1;
    fill(f, const_fill);
    double xc = 1.0 / 4.0;
    double yc = 1.0 / 4.0;
    double radius = std::min(xc, yc) / 2.0;
    for (int j = 0; j < nx; j++) {
        double y = (j - 1) * options.dx;
        for (int i = 0; i < nx; i++) {
            double x = (i - 1) * options.dx;
            if ((x - xc) * (x - xc) + (y - yc) * (y - yc) < radius * radius) {
                f(i,j) = inner_circle;
            }
        }
    }

    fill(u, 0);
    scale(h2f, options.dx*options.dx, f);

    unsigned int iters_cg = 0;
    bool cg_converged = false;
    double residual = 0.;

    // start timer
    double time_start = walltime();

    // Conjugate Gradient call
    iters_cg = cg(u, h2f, max_cg_iters, tolerance, residual,
                              cg_converged);

    // output some statistics
    if (cg_converged) {
        std::cout << " required " << iters_cg 
                    << " CG iterations "
                    << "for residual " << residual
                    << std::endl;
    }
    if (!cg_converged) {
        std::cerr << "iteration " << iters_cg
                    << " ERROR : Conjugate gradient failed to converge\n"
                    << "\t\t\t residual : " << residual 
                    << std::endl;
    }

    // get times
    double time_end = walltime();

    ////////////////////////////////////////////////////////////////////
    // write final solution to BOV file for visualization
    ////////////////////////////////////////////////////////////////////

    // binary data
    {
        FILE* output = fopen("output.bin", "w");
        fwrite(u.data(), sizeof(double), nx * nx, output);
        fclose(output);
    }

    std::ofstream fid("output.bov");
    fid << "DATA_FILE: output.bin" << std::endl;
    fid << "DATA_SIZE: " << options.nx << " " << options.nx << " 1"
        << std::endl;
    fid << "DATA_FORMAT: DOUBLE" << std::endl;
    fid << "VARIABLE: phi" << std::endl;
    fid << "DATA_ENDIAN: LITTLE" << std::endl;
    fid << "CENTERING: nodal" << std::endl;
    fid << "BRICK_ORIGIN: " << "0. 0. 0." << std::endl;
    fid << "BRICK_SIZE: " << (options.nx-1)*options.dx << ' '
                          << (options.nx-1)*options.dx << ' '
                          << " 1.0"
        << std::endl;

    // print table summarizing results
    double timespent = time_end - time_start;
    std::cout << std::string(80, '-') << std::endl;
    std::cout << "simulation took " << timespent << " seconds" << std::endl;
    std::cout << iters_cg
              << " conjugate gradient iterations, at rate of "
              << float(iters_cg)/timespent << " iters/second" << std::endl;
    std::cout << std::string(80, '-') << std::endl;
    std::cout << "### " 
                        // << threads << ", "
                        << options.nx << ", "
                        << iters_cg   << ", "
                        << timespent
              << " ###" << std::endl;
    std::cout << "Goodbye!" << std::endl;

    return 0;
}
