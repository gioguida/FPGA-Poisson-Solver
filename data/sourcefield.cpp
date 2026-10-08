#include "sourcefield.hpp"

#include <iterator>
#include <iostream>
#include <cstdint>
#include <filesystem>

/*** WRITE RHS AND EXACT SOLUTIONS VECTORS ***/

// Build binary vectors containing rhs and true solution with fixed-point format
// select test_case = 0 for building all test case vectors
void write_vectors (
    int test_case,
    int nx,
    int iterations,
    int int_bits,
    int fractional_bits
) {
    SourceFieldMetadata metadata;
    metadata.grid_nx = nx;
    metadata.grid_ny = nx;
    metadata.iterations = iterations;
    metadata.fixed_point.total_bits = int_bits + fractional_bits;
    metadata.fixed_point.fractional_bits = fractional_bits;
    metadata.fixed_point.is_signed = true;

    int total_bits = int_bits + fractional_bits;

    using int_t = std::int64_t;

    switch (total_bits){
        case 8: using int_t = std::int8_t;
            break;
        case 16: using int_t = std::int16_t;
            break;
        case 32: using int_t = std::int32_t;
            break;
        case 64: using int_t = std::int64_t;
            break;
        default: 
            std::cerr << "Number of bits is not supported, allowed word sizes: 8, 16, 32, 64" << std::endl;
            exit(-1);
            break;
    }

    std::string path = "case001/";
    std::string metadata_name = "meta.json";
    std::vector<int_t> f(nx*nx);
    std::vector<int_t> u(nx*nx);
    double x = 0.;
    double y = 0.;
    double h = 1.0/(nx-1);
    double scale = std::pow(2.0, fractional_bits);

    if(test_case == 1 || test_case == 0) {
        path = "case001/";
        std::filesystem::create_directories(path);

        for(int j = 0; j < nx; ++j) {
            for(int i = 0; i < nx; ++i) {
                x = i*h;
                y = j*h;
                u[i+j*nx] = static_cast<int_t>(std::round(singleSine_u(x,y) * scale));
                f[i+j*nx] = static_cast<int_t>(std::round(singleSine_f(x,y) * scale));
            }
        }

        metadata.print(path + metadata_name);

        FILE* input = fopen((path + "rhs.bin").c_str(), "wb");
        fwrite(f.data(), sizeof(int_t), f.size(), input);
        fclose(input);

        FILE* output = fopen((path + "u_ex.bin").c_str(), "wb");
        fwrite(u.data(), sizeof(int_t), u.size(), output);
        fclose(output);

    } else if (test_case == 2 || test_case == 0) {
        path = "case002/";
        std::filesystem::create_directories(path);

        for(int j = 0; j < nx; ++j) {
            for(int i = 0; i < nx; ++i) {
                x = i*h;
                y = j*h;
                u[i+j*nx] = static_cast<int_t>(std::round(highFreqSine_u(x,y, 3, 2) * scale));
                f[i+j*nx] = static_cast<int_t>(std::round(highFreqSine_f(x,y, 3, 2) * scale));
            }
        }

        metadata.print(path + metadata_name);

        FILE* input = fopen((path + "rhs.bin").c_str(), "wb");
        fwrite(f.data(), sizeof(int_t), f.size(), input);
        fclose(input);

        FILE* output = fopen((path + "u_ex.bin").c_str(), "wb");
        fwrite(u.data(), sizeof(int_t), u.size(), output);
        fclose(output);

    } else if (test_case == 3 || test_case == 0) {
        path = "case003/";
        std::filesystem::create_directories(path);

        for(int j = 0; j < nx; ++j) {
            for(int i = 0; i < nx; ++i) {
                x = i*h;
                y = j*h;
                u[i+j*nx] = static_cast<int_t>(std::round(polynomial_u(x,y) * scale));
                f[i+j*nx] = static_cast<int_t>(std::round(polynomial_f(x,y) * scale));
            }
        }

        metadata.print(path + metadata_name);

        FILE* input = fopen((path + "rhs.bin").c_str(), "wb");
        fwrite(f.data(), sizeof(int_t), f.size(), input);
        fclose(input);

        FILE* output = fopen((path + "u_ex.bin").c_str(), "wb");
        fwrite(u.data(), sizeof(int_t), u.size(), output);
        fclose(output);

    } else if (test_case == 4 || test_case == 0) {
        path = "case004/";
        std::filesystem::create_directories(path);

        for(int j = 0; j < nx; ++j) {
            for(int i = 0; i < nx; ++i) {
                x = i*h;
                y = j*h;
                u[i+j*nx] = static_cast<int_t>(std::round(double(1.0) * scale));
                f[i+j*nx] = static_cast<int_t>(std::round(double(1.0) * scale));
            }
        }

        metadata.print(path + metadata_name);

        FILE* input = fopen((path + "rhs.bin").c_str(), "wb");
        fwrite(f.data(), sizeof(int_t), f.size(), input);
        fclose(input);

        FILE* output = fopen((path + "u_ex.bin").c_str(), "wb");
        fwrite(u.data(), sizeof(int_t), u.size(), output);
        fclose(output);
    }
    
}

/*** BENCHMARK FORCE FIELDS AND EXACT SOLUTIONS ***/


// single sine mode f = -\Delta u(x,y) = 2*pi^2*sin(pi*x)*sin(pi*y)
double singleSine_f (const double x, const double y) {
    double pi = std::acos(-1);
    return 2 *pi*pi* std::sin(pi * x) * std::sin(pi * y); 
}

// single sine mode u(x,y) = sin(pi*x)*sin(pi*y)
double singleSine_u (const double x, const double y) {
    double pi = std::acos(-1);
    return std::sin(pi * x) * std::sin(pi * y); 
}

// higher frequency sine mode f = -\Delta u(x,y) = (k^2 + l^2)*pi^2 * sin(k*pi*x)*sin(l*pi*y)
double highFreqSine_f (const double x, const double y, const int k, const int l) {
    double pi = std::acos(-1);
    return (k*k + l*l) * pi*pi* std::sin(k * pi * x) * std::sin(l * pi * y); 
}

// higher frequency sine mode u(x,y) = sin(k*pi*x)*sin(l*pi*y)
double highFreqSine_u (const double x, const double y, const int k, const int l) {
    double pi = std::acos(-1);
    return  std::sin(k * pi * x) * std::sin(l * pi * y); 
}

// Polynomial manufactured solution f = 2(x(1-x) + y(1-y))
double polynomial_f (const double& x, const double& y) {
    return 2 * (x*(1-x) + y*(1-y));
}

// Polynomial manufactured solution u(x,y) = x(1-x)y(1-y)
double polynomial_u (const double& x, const double& y) {
    return x*(1-x) * y*(1-y);
}
