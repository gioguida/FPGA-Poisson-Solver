#include <iostream>
#include <stdexcept>

#include "sourcefield.hpp"

int main(int argc, char* argv[]) {

    if(argc != 6) {
        std::cerr << "Usage: vectors test_case nx, \n" 
            << "test_case:  benchmark problem for which to generate data (0 to generate all)\n";
            exit(-1); 
    }

    int test_case = atoi(argv[1]);
    if(test_case < 0 || test_case > 4) {
        std::cerr << "Test case must be an integer in [0, 4]" << std::endl;
        exit(-1);
    }

    int nx = atoi(argv[2]);
    int iterations = atoi(argv[3]);
    int int_bits = atoi(argv[4]);
    int fractional_bits = atoi(argv[5]);

    write_vectors(test_case, nx, iterations, int_bits, fractional_bits);
}