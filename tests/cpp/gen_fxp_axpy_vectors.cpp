#include <array>
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

constexpr unsigned V = 8;
constexpr unsigned FRAC_BITS = 24;
constexpr u64 SCALE = u64{1} << FRAC_BITS;
constexpr i32 MIN_RAW = std::numeric_limits<i32>::min();
constexpr i32 MAX_RAW = std::numeric_limits<i32>::max();

using Q8_24 = numeric::fixed<8, FRAC_BITS>;

struct TestCase {
    i32 gamma;
    std::array<i32, V> x;
    std::array<i32, V> z;
};

std::vector<TestCase> generate_tests() {
    std::vector<TestCase> tests;

    auto add = [&](i32 gamma, const std::array<i32, V>& x,
                   const std::array<i32, V>& z) {
        tests.push_back({gamma, x, z});
    };

    // Directed cases: zero, ordinary values, truncation, and wraparound.
    add(0, {0, 1, -1, static_cast<i32>(SCALE), -static_cast<i32>(SCALE),
            MAX_RAW, MIN_RAW, 12345},
           {MIN_RAW, MAX_RAW, 17, -17, 3, -3, 42, -42});

    add(static_cast<i32>(SCALE / 2),
        {static_cast<i32>(SCALE), -static_cast<i32>(SCALE), 0, 1, -1,
         MAX_RAW, MIN_RAW, 0x000000ff},
        {static_cast<i32>(SCALE), static_cast<i32>(SCALE),
         static_cast<i32>(SCALE / 2), static_cast<i32>(SCALE / 2),
         static_cast<i32>(SCALE / 2), static_cast<i32>(SCALE),
         static_cast<i32>(SCALE), -0x000000ff});

    add(-static_cast<i32>(SCALE),
        {MAX_RAW, MIN_RAW, 0, static_cast<i32>(SCALE),
         -static_cast<i32>(SCALE), 1, -1, 0},
        {-1, 1, MAX_RAW, MIN_RAW, MAX_RAW, MIN_RAW,
         static_cast<i32>(SCALE), -static_cast<i32>(SCALE)});

    // Exact half-LSB products exercise arithmetic-right-shift truncation.
    add(static_cast<i32>(SCALE / 2),
        {0, 0, 0, 0, 0, 0, 0, 0},
        {1, -1, 3, -3, 5, -5, 7, -7});

    // Deterministic pseudorandom coverage, including multiplication and
    // addition overflow cases.  Keep this small enough for quick RTL runs.
    constexpr std::size_t NUM_RANDOM = 1000;
    constexpr u64 SEED = 0xA8F1C0DEULL;
    std::mt19937_64 rng(SEED);
    std::uniform_int_distribution<i64> dist(MIN_RAW, MAX_RAW);

    for (std::size_t test = 0; test < NUM_RANDOM; ++test) {
        TestCase entry{};
        entry.gamma = static_cast<i32>(dist(rng));
        for (unsigned lane = 0; lane < V; ++lane) {
            entry.x[lane] = static_cast<i32>(dist(rng));
            entry.z[lane] = static_cast<i32>(dist(rng));
        }
        tests.push_back(entry);
    }

    return tests;
}

template <std::size_t N>
void write_packed_vector(std::ofstream& file, const std::array<i32, N>& v) {
    // Element zero occupies the least-significant packed bits, matching
    // fxp_axpy's [lane*N +: N] slices.
    for (std::size_t lane = N; lane-- > 0;) {
        file << std::setw(8) << static_cast<u32>(v[lane]);
    }
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

        const auto tests = generate_tests();
        file << std::hex << std::setfill('0');

        for (const TestCase& test : tests) {
            std::array<i32, V> expected{};
            Stats stats;

            for (unsigned lane = 0; lane < V; ++lane) {
                const Q8_24 product = checked_mul(
                    Q8_24::from_base(test.gamma),
                    Q8_24::from_base(test.z[lane]), stats);
                expected[lane] = checked_add(
                    Q8_24::from_base(test.x[lane]), product, stats).to_raw();
            }

            // Format: valid_i gamma_raw x_packed z_packed expected_y_packed.
            // Scalar fields are 32-bit hexadecimal bit patterns.  Packed
            // vector fields contain element V-1 first through element 0 last.
            file << 1 << " " << std::setw(8)
                 << static_cast<u32>(test.gamma) << " ";
            write_packed_vector(file, test.x);
            file << " ";
            write_packed_vector(file, test.z);
            file << " ";
            write_packed_vector(file, expected);
            file << "\n";
        }

        file.close();
        if (!file) {
            throw std::runtime_error("Failed while writing test vectors");
        }

        std::cout << "Generated " << std::dec << tests.size()
                  << " test vectors\nOutput: " << output << "\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << "\n";
        return 1;
    }
}
