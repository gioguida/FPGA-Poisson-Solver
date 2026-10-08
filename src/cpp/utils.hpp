#ifndef UTILS_HPP
#define UTILS_HPP

#include <fstream>
#include <iostream>
#include <cstring>
#include <string>
#include <vector>

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

std::vector<BYTE> read_binary(const char* filename);

SourceFieldMetadata read_source_field_metadata(const std::string& filename);

#endif