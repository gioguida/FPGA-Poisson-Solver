#include <algorithm>
#include <fstream>
#include <iostream>

#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <cstring>

#include "fixed.hpp"
#include "utils.hpp"
#include "data.hpp"
#include "linalg.hpp"
#include "walltime.hpp"

// read command line arguments
void readcmdline(
    std::string& test_case, 
    std::string& precision, 
    int argc, 
    char* argv[]
) {
    if (argc != 3) {
        std::cerr << "Usage: main test_case precision \n";
        std::cerr << " test_case        test case to evaluate (data/case00{1,2,3,4})\n";
        std::cerr << " precision        fixed or double\n";
        exit(1);
    }

    // read test case
    test_case = argv[1];

    precision = argv[2];
    if ((precision != "double") && (precision != "fixed")) {
        std::cerr << "precision must be either fixed or double\n";
        exit(-1);
    }
}

// =============================================================================

int main(int argc, char* argv[]) {
    // read command line arguments
    std::string test_case;
    std::string precision;
    readcmdline(test_case, precision, argc, argv);

    // read simulation metadata
    SourceFieldMetadata meta = read_source_field_metadata(test_case + "/meta.json");

    if(precision == "double") {
        return run_case<double>(meta, test_case, precision);
    }

    if(meta.fixed_point.total_bits == 32) {
        switch (meta.fixed_point.fractional_bits) {
            case 20: return run_case<numeric::fixed<12,20>>(meta, test_case, precision);
            case 24: return run_case<numeric::fixed<8,24>>(meta, test_case, precision);
            case 16: return run_case<numeric::fixed<16,16>>(meta, test_case, precision);
            default: throw std::runtime_error("unsupported fixed point type");
        }
    }
    throw std::runtime_error("Unsupported numeric format");
}
