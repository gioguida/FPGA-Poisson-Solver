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

using i32 = std::int32_t;
using i64 = std::int64_t;
using u32 = std::uint32_t;
using u64 = std::uint64_t;

constexpr unsigned FRAC_BITS = 24;
constexpr u64 SCALE = u64{1} << FRAC_BITS;
constexpr i32 MIN_RAW = std::numeric_limits<i32>::min();
constexpr i32 MAX_RAW = std::numeric_limits<i32>::max();

using Q8_24 = numeric::fixed<8, FRAC_BITS>;

// Each row describes one scalar AXPY transaction: y = x + gamma*z.
struct TestCase {
    i32 gamma;
    i32 x;
    i32 z;
};

std::vector<TestCase> generate_tests() {
    std::vector<TestCase> tests = {
        {0, 0, 0},
        {static_cast<i32>(SCALE), static_cast<i32>(SCALE),
         static_cast<i32>(2 * SCALE)},
        {static_cast<i32>(SCALE / 2), -static_cast<i32>(SCALE),
         static_cast<i32>(SCALE)},
        {-static_cast<i32>(SCALE), 0, static_cast<i32>(SCALE)},
        {static_cast<i32>(SCALE / 2), 0, 1},
        {static_cast<i32>(SCALE / 2), 0, -1},
        {static_cast<i32>(SCALE), MAX_RAW, 1},
        {static_cast<i32>(SCALE), MIN_RAW, -1},
        {MAX_RAW, MIN_RAW, MAX_RAW},
        {MIN_RAW, MAX_RAW, MIN_RAW},
    };

    constexpr std::size_t NUM_RANDOM = 1000;
    constexpr u64 SEED = 0xA8F1C0DEULL;
    std::mt19937_64 rng(SEED);
    std::uniform_int_distribution<i64> dist(MIN_RAW, MAX_RAW);
    for (std::size_t index = 0; index < NUM_RANDOM; ++index) {
        tests.push_back({static_cast<i32>(dist(rng)),
                         static_cast<i32>(dist(rng)),
                         static_cast<i32>(dist(rng))});
    }

    return tests;
}

int main(int argc, char** argv) {
    try {
        const fs::path output = (argc > 1)
            ? fs::path(argv[1])
            : fs::path("build/test_vectors/fxp_axpy_Q8_24.hex");
        if (!output.parent_path().empty()) {
            fs::create_directories(output.parent_path());
        }

        std::ofstream file(output);
        if (!file) {
            throw std::runtime_error("Cannot open output file: " +
                                     output.string());
        }

        const std::vector<TestCase> tests = generate_tests();
        Stats stats;
        for (const TestCase& test : tests) {
            const Q8_24 gamma = Q8_24::from_base(test.gamma);
            const Q8_24 x = Q8_24::from_base(test.x);
            const Q8_24 z = Q8_24::from_base(test.z);
            const Q8_24 product = checked_mul(gamma, z, stats);
            const Q8_24 expected = checked_add(x, product, stats);

            // Format: valid_i gamma_raw x_raw z_raw expected_y_raw.
            // Every field is one 32-bit raw Q8.24 value; no packed lanes.
            file << "1 " << std::hex << std::setfill('0')
                 << std::setw(8) << static_cast<u32>(test.gamma) << ' '
                 << std::setw(8) << static_cast<u32>(test.x) << ' '
                 << std::setw(8) << static_cast<u32>(test.z) << ' '
                 << std::setw(8) << static_cast<u32>(expected.to_raw())
                 << '\n';
        }

        file.close();
        if (!file) {
            throw std::runtime_error("Failed while writing test vectors");
        }

        std::cout << "Generated " << std::dec << tests.size()
                  << " scalar AXPY vectors\nOutput: " << output << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "ERROR: " << error.what() << '\n';
        return 1;
    }
}
