#include <limits>

#include "../../src/cpp/data.hpp"
#include "../../src/cpp/linalg.hpp"

int main() {
    using Small = numeric::fixed<12, 20>;

    Stats s;
    Field<Small> x(256, 1);
    Field<Small> y(256, 1);

    for (int i = 0; i < x.length(); ++i) {
        x[i] = Small::from_base(1);
        y[i] = Small::from_base(1);
    }

    if (dot_wide(x, y, s) != wide_t(256))
        return 1;

    Small quotient;
    if (!checked_div_wide(wide_t(256), wide_t(256), quotient, s) ||
        quotient.to_raw() != Small::one)
        return 2;

    if (checked_div_wide(wide_t(1), wide_t(0), quotient, s))
        return 3;

    if (checked_div_wide(wide_t(1) << 40, wide_t(1), quotient, s))
        return 4;

    using Large = numeric::fixed<16, 16>;
    Field<Large> large_x(1024, 1);
    Field<Large> large_y(1024, 1);

    Large max_value = Large::from_base(
        std::numeric_limits<Large::base_type>::max());

    for (int i = 0; i < large_x.length(); ++i) {
        large_x[i] = max_value;
        large_y[i] = max_value;
    }

    if (dot_wide(large_x, large_y, s) != DOT_ACC_MAX)
        return 5;

    if (s.accumulation_overflows == 0)
        return 6;

    Field<Small> u(2, 2);
    Field<Small> f(2, 2);
    fill(u, Small(0));
    fill(f, Small(0));

    Small residual;
    bool success = false;
    bool numerical_breakdown = false;
    cg(u, f, 1, Small(-1), residual, success, numerical_breakdown, s);

    if (!numerical_breakdown)
        return 7;

    return 0;
}
