#ifndef UTILS_HPP
#define UTILS_HPP

#include <fstream>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <vector>

#include "fixed.hpp"
#include "linalg.hpp"
#include "walltime.hpp"

using BYTE = unsigned char;

/*** READ RHS AND EXACT SOLUTIONS VECTORS ***/

struct FixedPointFormat {
    int total_bits;
    int fractional_bits;
    bool is_signed;
};

// Metadata stored alongside an exported source field.  The field names follow
// the JSON schema, except for "signed", which is a C++ keyword.
struct SourceFieldMetadata {
    int grid_nx;
    int grid_ny;
    int iterations;
    FixedPointFormat fixed_point;
    std::string dtype;
    std::string endianness;
    std::string layout;
    std::string boundary;
    void print(const std::string& filename);
};

SourceFieldMetadata read_source_field_metadata(const std::string& filename);

template<class T>
struct is_numeric_fixed : std::false_type {};

template<std::size_t IntegerBits, std::size_t FractionalBits>
struct is_numeric_fixed<numeric::fixed<IntegerBits, FractionalBits>>
    : std::true_type {
    static constexpr std::size_t integer_bits = IntegerBits;
    static constexpr std::size_t fractional_bits = FractionalBits;
    static constexpr std::size_t total_bits = IntegerBits + FractionalBits;
};

template<class RealType>
void load_fixed_rhs(Field<RealType>& field,
                    const std::string& filename,
                    const SourceFieldMetadata& meta) {

    if (meta.fixed_point.total_bits != 32)
        throw std::invalid_argument("Unsupported RHS format");

    if constexpr (is_numeric_fixed<RealType>::value) {
        if (RealType::total_bits != 32 ||
            RealType::fractional_bits != meta.fixed_point.fractional_bits)
            throw std::invalid_argument("RHS format does not match fixed type");
    }

    std::ifstream input(filename, std::ios::binary);
    if (!input)
        throw std::runtime_error("Could not open RHS file: " + filename);

    const double scale = std::ldexp(
        1.0, meta.fixed_point.fractional_bits);

    for (int i = 0; i < field.length(); ++i) {
        std::int32_t raw;
        if (!input.read(reinterpret_cast<char*>(&raw), sizeof(raw)))
            throw std::runtime_error("Could not read RHS file: " + filename);

        if constexpr (is_numeric_fixed<RealType>::value)
            field[i] = RealType::from_base(raw);
        else
            field[i] = static_cast<RealType>(raw / scale);
    }
}

template<class RealType>
int run_case(
    const SourceFieldMetadata& meta, 
    const std::string& test_case, 
    const std::string& precision
) {
    int nx = meta.grid_nx;
    int N  = nx * nx;
    RealType dx = 1.0/(nx-1);

    // set iteration parameters
    int max_cg_iters = meta.iterations;
    // WIP set tolerance to a dummy value
    RealType tolerance = -1.0;

    // allocate fields
    Field<RealType> u(nx, nx);
    Field<RealType> bndN(nx, 1);
    Field<RealType> bndS(nx, 1);
    Field<RealType> bndE(nx, 1);
    Field<RealType> bndW(nx, 1);

    Field<RealType> f(nx, nx);
    std::string const filepath = test_case + "/rhs.bin";
    load_fixed_rhs<RealType>(f, filepath, meta);

    Field<RealType> rhs(nx,nx);

    // set Dirichlet boundary conditions to 0 all around
    RealType const_bdy = 0.0;
    fill(bndN, const_bdy);
    fill(bndS, const_bdy);
    fill(bndE, const_bdy);
    fill(bndW, const_bdy);

    fill<RealType>(u, 0);
    scale<RealType>(rhs, dx*dx, f);

    int iters_cg = 0;
    bool cg_converged = false;
    RealType residual = 0.;

    // start timer
    double time_start = walltime();

    // Conjugate Gradient call
    iters_cg = cg(u, rhs, max_cg_iters, tolerance, residual,
                              cg_converged);

    // output some statistics
    std::cout << " CG executed for " << iters_cg 
                << " iterations "
                << "for residual " << residual
                << std::endl;

    // get times
    double time_end = walltime();

    // write final solution to BOV file for visualization

    // binary data
    if(precision == "double") {
        FILE* output = fopen((test_case + "/u_double.bin").c_str(), "w");
        fwrite(u.data(), sizeof(RealType), nx * nx, output);
        fclose(output);
    } else {
        FILE* output = fopen((test_case + "/u_fixed.bin").c_str(), "w");
        fwrite(u.data(), sizeof(RealType), nx * nx, output);
        fclose(output);
    }
    
    // print table summarizing results
    double timespent = time_end - time_start;
    std::cout << std::string(80, '-') << std::endl;
    std::cout << "simulation took " << timespent << " seconds" << std::endl;
    std::cout << iters_cg
              << " conjugate gradient iterations, at rate of "
              << float(iters_cg)/timespent << " iters/second" << std::endl;
    std::cout << std::string(80, '-') << std::endl;
    std::cout << "### " 
                        << nx << ", "
                        << iters_cg   << ", "
                        << timespent
              << " ###" << std::endl;
    std::cout << "Goodbye!" << std::endl;

    return 0;
}

#endif