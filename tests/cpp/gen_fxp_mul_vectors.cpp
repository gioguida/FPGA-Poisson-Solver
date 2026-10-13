
#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <utility>
#include <vector>

#include "../../src/cpp/linalg.hpp"

namespace fs = std::filesystem;

using i32 = std::int32_t;
using i64 = std::int64_t;
using u32 = std::uint32_t;
using u64 = std::uint64_t;

constexpr unsigned FRAC_BITS = 24;
constexpr u64 SCALE = u64{1} << FRAC_BITS;
constexpr u64 HALF = SCALE / 2;

constexpr i32 MIN_RAW = std::numeric_limits<i32>::min();
constexpr i32 MAX_RAW = std::numeric_limits<i32>::max();

using TestCase = std::pair<i32, i32>;
using Q8_24 = numeric::fixed<8, FRAC_BITS>;

std::vector<TestCase> generate_tests() {
    std::vector<TestCase> tests;

    auto add = [&](i32 a, i32 b) {
        tests.emplace_back(a, b);
    };

    // 1. Directed corner cases.
    const std::array<i32, 15> special = {
        0,
        1, -1,                      // +/- 1 LSB
        static_cast<i32>(SCALE),    // +1.0
        -static_cast<i32>(SCALE),   // -1.0
        static_cast<i32>(SCALE / 2),
        -static_cast<i32>(SCALE / 2),
        static_cast<i32>(2 * SCALE),
        -static_cast<i32>(2 * SCALE),
        MIN_RAW, MAX_RAW,
        MIN_RAW + 1, MAX_RAW - 1,
        0x000000FF,
        -0x000000FF
    };

    // Test every combination of special values.
    for (i32 a : special) {
        for (i32 b : special) {
            add(a, b);
        }
    }

    // 2. Truncation boundaries.
    //
    // Product magnitudes near 2^23 (half an output LSB).
    for (i32 sign_a : {-1, 1}) {
        for (i32 sign_b : {-1, 1}) {
            for (i32 offset : {-1, 0, 1}) {
                add(sign_a, sign_b *
                    static_cast<i32>(HALF + offset));
            }
        }
    }

    // Also test exact half-way cases.  checked_mul uses an arithmetic
    // right shift, so negative products round down rather than to zero.
    for (i32 n = 0; n < 20; ++n) {
        const i32 b = static_cast<i32>(HALF);
        const i32 a = 2 * n + 1;

        add(a, b);
        add(-a, b);
        add(a, -b);
        add(-a, -b);
    }

    // 3. Deterministic pseudorandom testing.
    constexpr std::size_t NUM_RANDOM = 10000;
    constexpr u64 SEED = 0x5EED1234ULL;

    std::mt19937_64 rng(SEED);
    std::uniform_int_distribution<i64> dist(
        static_cast<i64>(MIN_RAW),
        static_cast<i64>(MAX_RAW)
    );

    for (std::size_t i = 0; i < NUM_RANDOM; ++i) {
        add(static_cast<i32>(dist(rng)),
            static_cast<i32>(dist(rng)));
    }

    return tests;
}

int main(int argc, char** argv) {
    try {
        const fs::path output = (argc > 1)
            ? fs::path(argv[1])
            : fs::path(
                "build/test_vectors/fxp_mul_Q8_24.hex"
              );

        if (!output.parent_path().empty()) {
            fs::create_directories(output.parent_path());
        }

        std::ofstream file(output);

        if (!file) {
            throw std::runtime_error(
                "Cannot open output file: " + output.string()
            );
        }

        const auto tests = generate_tests();

        // Format: valid_i a_raw b_raw expected_y_raw.
        // Every value after valid_i is a 32-bit hexadecimal bit pattern.
        file << std::hex << std::setfill('0');

        Stats stats;

        for (const auto& [a, b] : tests) {
            const Q8_24 a_q = Q8_24::from_base(a);
            const Q8_24 b_q = Q8_24::from_base(b);
            const Q8_24 expected_q = checked_mul(a_q, b_q, stats);
            const u32 expected = static_cast<u32>(expected_q.to_raw());

            file << 1 << " "
                 << std::setw(8)
                 << static_cast<u32>(a) << " "
                 << std::setw(8)
                 << static_cast<u32>(b) << " "
                 << std::setw(8)
                 << expected << "\n";
        }

        file.close();

        if (!file) {
            throw std::runtime_error(
                "Failed while writing test vectors"
            );
        }

        std::cout << "Generated " << std::dec
                  << tests.size() << " test vectors\n"
                  << "Output: " << output << "\n";

        return 0;

    } catch (const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << "\n";
        return 1;
    }
}
