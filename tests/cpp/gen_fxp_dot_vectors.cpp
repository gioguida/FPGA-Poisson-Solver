#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs = std::filesystem;

using i32 = std::int32_t;
using i64 = std::int64_t;
using i128 = __int128_t;
using u32 = std::uint32_t;
using u128 = __uint128_t;

// Match the RTL test configuration. With N=32 and V=256, the unscaled
// reduction result is 72 bits wide (products retain all 48 fractional bits).
constexpr unsigned V = 256;
constexpr unsigned N = 32;
constexpr unsigned DOT_WIDE = 2 * N + 8; // clog2(256)
constexpr unsigned HEX_DIGITS = (DOT_WIDE + 3) / 4;
constexpr i32 MIN_RAW = std::numeric_limits<i32>::min();
constexpr i32 MAX_RAW = std::numeric_limits<i32>::max();

struct TestCase {
    std::array<i32, V> x{};
    std::array<i32, V> y{};
};

u128 as_unsigned_bits(i128 value) {
    // Return the low 128-bit representation; this also handles negative sums
    // without negating the most-negative signed value.
    return static_cast<u128>(value);
}

std::string hex_u128(u128 value, unsigned digits) {
    static constexpr char HEX[] = "0123456789abcdef";
    std::string result(digits, '0');
    for (unsigned pos = 0; pos < digits; ++pos) {
        result[digits - 1 - pos] = HEX[static_cast<unsigned>(value & 0xf)];
        value >>= 4;
    }
    return result;
}

void fill(TestCase& test, i32 x, i32 y) {
    test.x.fill(x);
    test.y.fill(y);
}

std::vector<TestCase> generate_tests() {
    std::vector<TestCase> tests;

    TestCase test{};
    fill(test, 0, 0);
    tests.push_back(test);

    // Large same-sign sums: the expected dot product is wider than either
    // an input element or a 64-bit accumulator, while fitting the 72-bit RTL.
    fill(test, MAX_RAW, MAX_RAW);
    tests.push_back(test);
    fill(test, MIN_RAW, MAX_RAW);
    tests.push_back(test);
    fill(test, MIN_RAW, MIN_RAW);
    tests.push_back(test);

    // Exact cancellation, followed by a single raw-product LSB.
    for (unsigned lane = 0; lane < V; ++lane) {
        test.x[lane] = (lane & 1) ? -1 : 1;
        test.y[lane] = MAX_RAW;
    }
    tests.push_back(test);
    for (unsigned lane = 0; lane < V; ++lane) {
        test.x[lane] = (lane == 0) ? 1 : 0;
        test.y[lane] = (lane == 0) ? 1 : 0;
    }
    tests.push_back(test);

    // Sparse, fractional, and sign-mixed values exercise low product bits
    // without scaling or rounding the reduction.
    test = {};
    for (unsigned lane = 0; lane < V; ++lane) {
        test.x[lane] = (lane % 4 == 0) ? 1 : (lane % 4 == 1) ? -1 : 0;
        test.y[lane] = (lane % 3 == 0) ? MAX_RAW :
                       (lane % 3 == 1) ? MIN_RAW : 0x0100'0000;
    }
    tests.push_back(test);

    constexpr std::size_t NUM_RANDOM = 24;
    constexpr std::uint64_t SEED = 0xD07F1AEDULL;
    std::mt19937_64 rng(SEED);
    std::uniform_int_distribution<i64> dist(MIN_RAW, MAX_RAW);
    for (std::size_t index = 0; index < NUM_RANDOM; ++index) {
        for (unsigned lane = 0; lane < V; ++lane) {
            test.x[lane] = static_cast<i32>(dist(rng));
            test.y[lane] = static_cast<i32>(dist(rng));
        }
        tests.push_back(test);
    }

    return tests;
}

template <std::size_t Size>
void write_packed_vector(std::ofstream& file,
                         const std::array<i32, Size>& vector) {
    // Lane zero maps to the least-significant RTL slice [N-1:0].
    for (std::size_t lane = Size; lane-- > 0;) {
        file << std::setw(N / 4) << static_cast<u32>(vector[lane]);
    }
}

int main(int argc, char** argv) {
    try {
        const fs::path output = (argc > 1)
            ? fs::path(argv[1])
            : fs::path("build/test_vectors/fxp_dot_Q8_24.hex");
        if (!output.parent_path().empty()) {
            fs::create_directories(output.parent_path());
        }

        std::ofstream file(output);
        if (!file) {
            throw std::runtime_error("Cannot open output file: " +
                                     output.string());
        }

        const auto tests = generate_tests();
        for (const TestCase& test : tests) {
            i128 sum = 0;
            for (unsigned lane = 0; lane < V; ++lane) {
                // Keep the exact signed 32x32 product and accumulate its raw
                // Q*.48 value. There is no per-product rescaling.
                sum += static_cast<i128>(test.x[lane]) * test.y[lane];
            }

            const i128 min_value = -(i128{1} << (DOT_WIDE - 1));
            const i128 max_value = (i128{1} << (DOT_WIDE - 1)) - 1;
            const bool overflow = sum < min_value || sum > max_value;
            if (sum < min_value) sum = min_value;
            if (sum > max_value) sum = max_value;

            file << "1 " << std::hex << std::setfill('0');
            write_packed_vector(file, test.x);
            file << ' ';
            write_packed_vector(file, test.y);
            file << ' ' << std::setw(HEX_DIGITS)
                 << hex_u128(as_unsigned_bits(sum), HEX_DIGITS)
                 << ' ' << std::dec << (overflow ? 1 : 0) << '\n';
        }

        file.close();
        if (!file) {
            throw std::runtime_error("Failed while writing test vectors");
        }

        std::cout << "Generated " << tests.size()
                  << " dot-product vectors (V=" << V << ", result width="
                  << DOT_WIDE << " bits)\nOutput: " << output << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "ERROR: " << error.what() << '\n';
        return 1;
    }
}
