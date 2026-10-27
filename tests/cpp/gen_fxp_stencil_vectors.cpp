// Generate small, deterministic whole-grid vectors for the point stencil RTL.
// Header: rows cols data_bits fractional_bits case_count (decimal).
// Then rows*cols lines per case, in row-major order:
// input_raw expected_Ap_raw overflow (16-bit hex, 16-bit hex, decimal).
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <vector>

#include "../../src/cpp/linalg.hpp"

namespace fs = std::filesystem;

namespace {
constexpr int ROWS = 8;
constexpr int COLS = 5;
constexpr int DATA_BITS = 16;
constexpr int FRAC_BITS = 8;
constexpr int CELL_COUNT = ROWS * COLS;
constexpr int CASE_COUNT = 6;
using Fixed = numeric::fixed<8, FRAC_BITS>;
using Raw = Fixed::base_type;

static_assert(sizeof(Raw) * 8 == DATA_BITS);

std::vector<std::vector<Raw>> make_cases() {
    std::vector<std::vector<Raw>> cases(CASE_COUNT,
                                       std::vector<Raw>(CELL_COUNT, 0));
    std::mt19937 rng(0x5eed1234u);
    std::uniform_int_distribution<int> full_range(
        std::numeric_limits<Raw>::min(), std::numeric_limits<Raw>::max());

    for (int j = 0; j < COLS; ++j) {
        for (int i = 0; i < ROWS; ++i) {
            const int index = i + ROWS * j;
            cases[1][index] = static_cast<Raw>(index + 1);
            cases[2][index] =
                static_cast<Raw>(((37*i + 53*j + 19*i*j + 11) % 101) - 50);
            cases[4][index] = static_cast<Raw>((i + j) % 2 ? 30000 : -30000);
            cases[5][index] = static_cast<Raw>(full_range(rng));
        }
    }
    cases[3][3 + ROWS * 2] = 20000;
    return cases;
}

Fixed point_value(const Field<Fixed>& field, int i, int j) {
    if (i < 0 || i >= ROWS || j < 0 || j >= COLS)
        return Fixed::from_base(0);
    return field(i, j);
}

// Use the same checked fixed-point primitives as the C++ reference to obtain
// the per-point overflow flag. stencil() itself provides the output field.
bool point_overflow(const Field<Fixed>& field, int i, int j,
                    Raw expected_raw) {
    Stats stats;
    const Fixed center4 = checked_mul(Fixed(4), point_value(field, i, j), stats);
    const Fixed north_south = checked_add(point_value(field, i, j-1),
                                          point_value(field, i, j+1), stats);
    const Fixed west_east = checked_add(point_value(field, i-1, j),
                                        point_value(field, i+1, j), stats);
    const Fixed neighbors = checked_add(north_south, west_east, stats);
    const Fixed result = checked_sub(center4, neighbors, stats);
    if (result.to_raw() != expected_raw)
        throw std::runtime_error("point overflow model disagrees with C++ stencil");
    return stats.total_overflow_count != 0;
}
}  // namespace

int main(int argc, char** argv) {
    try {
        const fs::path output = argc > 1
            ? fs::path(argv[1])
            : fs::path("build/test_vectors/fxp_stencil_Q8_8.hex");
        if (!output.parent_path().empty())
            fs::create_directories(output.parent_path());
        std::ofstream file(output);
        if (!file)
            throw std::runtime_error("Cannot open vector file: " + output.string());

        const auto cases = make_cases();
        file << ROWS << ' ' << COLS << ' ' << DATA_BITS << ' ' << FRAC_BITS
             << ' ' << cases.size() << '\n';
        file << std::hex << std::setfill('0');

        for (const auto& inputs : cases) {
            Field<Fixed> field(ROWS, COLS);
            Field<Fixed> ap(ROWS, COLS);
            for (int index = 0; index < CELL_COUNT; ++index)
                field[index] = Fixed::from_base(inputs[index]);

            Stats stats;
            stencil(ap, field, stats);
            for (int j = 0; j < COLS; ++j) {
                for (int i = 0; i < ROWS; ++i) {
                    const int index = i + ROWS * j;
                    const Raw expected = ap(i, j).to_raw();
                    const bool overflow = point_overflow(field, i, j, expected);
                    file << std::setw(4)
                         << static_cast<std::uint16_t>(inputs[index]) << ' '
                         << std::setw(4)
                         << static_cast<std::uint16_t>(expected) << ' '
                         << (overflow ? 1 : 0) << '\n';
                }
            }
        }
        if (!file)
            throw std::runtime_error("Failed while writing vector file");
        std::cout << "Generated " << cases.size() << " stencil fields in "
                  << output << '\n';
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
