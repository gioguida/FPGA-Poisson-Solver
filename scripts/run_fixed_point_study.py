#!/usr/bin/env python3

import argparse
import json
import math
import re
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


FORMATS = [
    ("Q16.16", 16, 16),
    ("Q12.20", 12, 20),
    ("Q8.24", 8, 24),
]

CASES = ["case001", "case002", "case003", "case004"]


@dataclass
class RunResult:
    format_name: str
    case: str
    precision: str

    success: bool
    returncode: int
    failure_reason: Optional[str] = None

    iterations: Optional[int] = None
    residual: Optional[float] = None
    runtime_s: Optional[float] = None
    iters_per_second: Optional[float] = None

    total_overflows: Optional[int] = None
    add_overflows: Optional[int] = None
    sub_overflows: Optional[int] = None
    mul_overflows: Optional[int] = None
    div_overflows: Optional[int] = None
    reduction_overflows: Optional[int] = None

    max_abs_raw: Optional[int] = None
    raw_limit: Optional[int] = None

    rel_error_vs_exact: Optional[float] = None
    rel_error_vs_double: Optional[float] = None

    stdout: str = ""
    stderr: str = ""


# ---------------------------------------------------------------------------
# Process execution
# ---------------------------------------------------------------------------

def run_command(cmd, cwd, timeout=120):
    try:
        p = subprocess.run(
            cmd,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        return p.returncode, p.stdout, p.stderr

    except subprocess.TimeoutExpired as e:
        return 124, e.stdout or "", e.stderr or "TIMEOUT"


def compile_project(root: Path):
    print("Compiling...")

    for target in ["vectors", "cpp"]:
        p = subprocess.run(["make", target], cwd=root)

        if p.returncode != 0:
            raise RuntimeError(f"`make {target}` failed")


# ---------------------------------------------------------------------------
# Output parsing
# ---------------------------------------------------------------------------

def parse_main_output(
    stdout: str,
    stderr: str,
    returncode: int,
    format_name: str,
    case: str,
    precision: str,
) -> RunResult:

    result = RunResult(
        format_name=format_name,
        case=case,
        precision=precision,
        success=(returncode == 0),
        returncode=returncode,
        stdout=stdout,
        stderr=stderr,
    )

    if returncode != 0:
        if returncode == 2:
            result.failure_reason = "numerical breakdown"
        elif returncode == -11:
            result.failure_reason = "SIGSEGV"
        elif returncode == -8:
            result.failure_reason = "SIGFPE / possible division by zero"
        elif returncode == 124:
            result.failure_reason = "timeout"
        else:
            result.failure_reason = f"exit status {returncode}"

    patterns = {
        "iterations":
            r"CG executed for\s+(\d+)\s+iterations",

        "residual":
            r"CG executed for\s+\d+\s+iterations for residual\s+"
            r"([eE0-9.+-]+)",

        "runtime_s":
            r"simulation took\s+([eE0-9.+-]+)\s+seconds",

        "iters_per_second":
            r"at rate of\s+([eE0-9.+-]+)\s+iters/second",

        "total_overflows":
            r"total overlows:\s+(\d+)",

        "add_overflows":
            r"add\s+overlows:\s+(\d+)",

        "sub_overflows":
            r"sub\s+overlows:\s+(\d+)",

        "mul_overflows":
            r"mult\s+overlows:\s+(\d+)",

        "div_overflows":
            r"div\s+overlows:\s+(\d+)",

        "reduction_overflows":
            r"reduc\s+overlows:\s+(\d+)",

        "max_abs_raw":
            r"max absolute raw value\s+(-?\d+)",

        "raw_limit":
            r"limit:\s+(-?\d+)",
    }

    integer_fields = {
        "iterations",
        "total_overflows",
        "add_overflows",
        "sub_overflows",
        "mul_overflows",
        "div_overflows",
        "reduction_overflows",
        "max_abs_raw",
        "raw_limit",
    }

    for field, pattern in patterns.items():
        match = re.search(pattern, stdout)

        if match:
            value = match.group(1)

            if field in integer_fields:
                setattr(result, field, int(value))
            else:
                setattr(result, field, float(value))

    return result


# ---------------------------------------------------------------------------
# Binary solution loading
# ---------------------------------------------------------------------------

def load_meta(case_dir: Path):
    with open(case_dir / "meta.json") as f:
        return json.load(f)


def read_binary(path: Path, dtype: str, endian: str = "little"):
    raw = path.read_bytes()

    endian_char = "<" if endian == "little" else ">"

    formats = {
        "float64": ("d", 8),
        "double": ("d", 8),
        "float32": ("f", 4),
        "int32": ("i", 4),
        "int64": ("q", 8),
        "int16": ("h", 2),
    }

    if dtype not in formats:
        raise ValueError(f"Unsupported dtype: {dtype}")

    fmt, size = formats[dtype]

    if len(raw) % size != 0:
        raise ValueError(
            f"{path}: file length {len(raw)} is not divisible by {size}"
        )

    n = len(raw) // size

    return list(
        struct.unpack(f"{endian_char}{n}{fmt}", raw)
    )


def get_frac_bits(meta):
    # Supports both:
    #
    # "fractional_bits": 20
    #
    # and
    #
    # "fixed_point": {
    #     "fractional_bits": 20
    # }

    if "fractional_bits" in meta:
        return int(meta["fractional_bits"])

    if "fixed_point" in meta:
        return int(meta["fixed_point"]["fractional_bits"])

    raise KeyError("fractional_bits missing from meta.json")


def get_endianness(meta):
    return meta.get("endianness", "little")


def load_solutions(case_dir: Path):
    meta = load_meta(case_dir)

    endian = get_endianness(meta)
    frac_bits = get_frac_bits(meta)

    # The analytic reference is a signed 64-bit raw fixed-point field.  It
    # deliberately uses a wider container than the 32-bit DUT format while
    # retaining the format's fractional-bit scaling.
    raw_exact = read_binary(
        case_dir / "u_ex.bin",
        "int64",
        endian,
    )

    u_double = read_binary(
        case_dir / "u_double.bin",
        "float64",
        endian,
    )

    # Both raw integer fields use x_real = x_raw / 2^fractional_bits.
    raw_fixed = read_binary(
        case_dir / "u_fixed.bin",
        "int32",
        endian,
    )

    scale = 2.0 ** frac_bits

    u_exact = [
        x / scale
        for x in raw_exact
    ]

    u_fixed = [
        x / scale
        for x in raw_fixed
    ]

    if not (
        len(u_exact)
        == len(u_double)
        == len(u_fixed)
    ):
        raise ValueError(
            f"{case_dir}: solution files have different lengths"
        )

    return u_exact, u_double, u_fixed


# ---------------------------------------------------------------------------
# Error metrics
# ---------------------------------------------------------------------------

def l2_norm(x):
    return math.sqrt(sum(v * v for v in x))


def relative_l2_error(x, reference):
    if len(x) != len(reference):
        raise ValueError("Vector lengths differ")

    diff = [
        a - b
        for a, b in zip(x, reference)
    ]

    denominator = l2_norm(reference)

    if denominator == 0.0:
        return float("nan")

    return l2_norm(diff) / denominator


def max_abs_error(x, reference):
    return max(
        abs(a - b)
        for a, b in zip(x, reference)
    )


# ---------------------------------------------------------------------------
# Vector generation / execution
# ---------------------------------------------------------------------------

def generate_vectors(
    root: Path,
    nx: int,
    iterations: int,
    integer_bits: int,
    fractional_bits: int,
):
    cmd = [
        "./vectors",
        "0",
        str(nx),
        str(iterations),
        str(integer_bits),
        str(fractional_bits),
    ]

    code, stdout, stderr = run_command(cmd, root)

    if code != 0:
        raise RuntimeError(
            f"Vector generation failed for "
            f"Q{integer_bits}.{fractional_bits}\n"
            f"{stdout}\n{stderr}"
        )


def execute_case(
    root: Path,
    format_name: str,
    case: str,
    precision: str,
):
    code, stdout, stderr = run_command(
        [
            "./main",
            f"data/{case}",
            precision,
        ],
        root,
    )

    return parse_main_output(
        stdout,
        stderr,
        code,
        format_name,
        case,
        precision,
    )


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def sci(x):
    if x is None:
        return "-"
    return f"{x:.6e}"


def fixed6(x):
    if x is None:
        return "-"
    return f"{x:.6f}"


def write_report(results, output_path, nx, iterations):
    out = []

    out += [
        "=" * 92,
        "FPGA POISSON SOLVER — FIXED-POINT NUMERICAL STUDY",
        "=" * 92,
        "",
        f"Grid:             {nx} x {nx}",
        f"CG iterations:    {iterations}",
        f"Formats tested:   {', '.join(f[0] for f in FORMATS)}",
        "",
    ]

    # -----------------------------------------------------------------------
    # Individual cases
    # -----------------------------------------------------------------------

    for case in CASES:
        out += [
            "=" * 92,
            case,
            "=" * 92,
        ]

        for format_name, _, _ in FORMATS:

            double = next(
                (
                    r for r in results
                    if r.case == case
                    and r.format_name == format_name
                    and r.precision == "double"
                ),
                None,
            )

            fixed = next(
                (
                    r for r in results
                    if r.case == case
                    and r.format_name == format_name
                    and r.precision == "fixed"
                ),
                None,
            )

            out += [
                "",
                format_name,
                "-" * 50,
            ]

            if double and double.success:
                out.append(
                    f"double residual              {sci(double.residual)}"
                )
                out.append(
                    f"double relative L2 error     "
                    f"{sci(double.rel_error_vs_exact)}"
                )
                out.append(
                    f"double runtime [s]           "
                    f"{fixed6(double.runtime_s)}"
                )
            else:
                reason = double.failure_reason if double else "missing"
                out.append(
                    f"DOUBLE RUN FAILED: {reason}"
                )

            if not fixed or not fixed.success:
                reason = fixed.failure_reason if fixed else "missing"
                out.append(
                    f"FIXED RUN FAILED: {reason}"
                )
                continue

            out.append(
                f"fixed residual               {sci(fixed.residual)}"
            )

            out.append(
                f"fixed relative L2 error      "
                f"{sci(fixed.rel_error_vs_exact)}"
            )

            out.append(
                f"fixed-vs-double L2 error     "
                f"{sci(fixed.rel_error_vs_double)}"
            )

            out.append(
                f"fixed runtime [s]            "
                f"{fixed6(fixed.runtime_s)}"
            )

            out.append(
                f"fixed throughput [iter/s]    "
                f"{fixed6(fixed.iters_per_second)}"
            )

            out.append(
                f"total overflows              "
                f"{fixed.total_overflows}"
            )

            out.append(
                "overflow breakdown           "
                f"add={fixed.add_overflows}, "
                f"sub={fixed.sub_overflows}, "
                f"mul={fixed.mul_overflows}, "
                f"div={fixed.div_overflows}, "
                f"reduction={fixed.reduction_overflows}"
            )

            if (
                fixed.max_abs_raw is not None
                and fixed.raw_limit is not None
                and fixed.raw_limit > 0
            ):
                usage = fixed.max_abs_raw / fixed.raw_limit

                out.append(
                    f"max |raw|                    "
                    f"{fixed.max_abs_raw}"
                )

                out.append(
                    f"raw limit                    "
                    f"{fixed.raw_limit}"
                )

                out.append(
                    f"raw range utilisation        "
                    f"{100 * usage:.4f}%"
                )

                out.append(
                    f"remaining raw headroom       "
                    f"{100 * (1 - usage):.4f}%"
                )

    # -----------------------------------------------------------------------
    # Format summary
    # -----------------------------------------------------------------------

    out += [
        "",
        "=" * 92,
        "FORMAT SUMMARY",
        "=" * 92,
        "",
    ]

    format_scores = []

    for format_name, _, frac_bits in FORMATS:
        fixed_runs = [
            r for r in results
            if r.format_name == format_name
            and r.precision == "fixed"
        ]

        successful = [
            r for r in fixed_runs
            if r.success
        ]

        failed = [
            r for r in fixed_runs
            if not r.success
        ]

        overflow_count = sum(
            r.total_overflows or 0
            for r in successful
        )

        errors = [
            r.rel_error_vs_exact
            for r in successful
            if r.rel_error_vs_exact is not None
            and math.isfinite(r.rel_error_vs_exact)
        ]

        fp_errors = [
            r.rel_error_vs_double
            for r in successful
            if r.rel_error_vs_double is not None
            and math.isfinite(r.rel_error_vs_double)
        ]

        max_usage = 0.0

        for r in successful:
            if (
                r.max_abs_raw is not None
                and r.raw_limit is not None
                and r.raw_limit > 0
            ):
                max_usage = max(
                    max_usage,
                    r.max_abs_raw / r.raw_limit,
                )

        mean_error = (
            sum(errors) / len(errors)
            if errors else None
        )

        mean_fp_error = (
            sum(fp_errors) / len(fp_errors)
            if fp_errors else None
        )

        out += [
            format_name,
            f"  successful cases:            "
            f"{len(successful)}/{len(CASES)}",
            f"  failed cases:                "
            f"{len(failed)}",
            f"  total detected overflows:    "
            f"{overflow_count}",
            f"  mean relative L2 error:      "
            f"{sci(mean_error)}",
            f"  mean fixed-vs-double error:  "
            f"{sci(mean_fp_error)}",
            f"  maximum range utilisation:   "
            f"{100 * max_usage:.4f}%",
        ]

        for r in failed:
            out.append(
                f"  FAILED {r.case}: {r.failure_reason}"
            )

        out.append("")

        safe = (
            len(successful) == len(CASES)
            and overflow_count == 0
        )

        if safe and mean_fp_error is not None:
            format_scores.append(
                (
                    mean_fp_error,
                    -frac_bits,
                    format_name,
                )
            )

    # -----------------------------------------------------------------------
    # Recommendation
    # -----------------------------------------------------------------------

    out += [
        "=" * 92,
        "AUTOMATIC PRELIMINARY RECOMMENDATION",
        "=" * 92,
        "",
    ]

    if not format_scores:
        out += [
            "No format completed every benchmark without detected overflow.",
            "Inspect failures and increase integer range before proceeding.",
        ]

    else:
        format_scores.sort()

        best_error, _, best_name = format_scores[0]

        out += [
            f"Numerically best safe format: {best_name}",
            "",
            f"Mean fixed-vs-double relative L2 error: "
            f"{best_error:.6e}",
            "",
            "Selection criterion:",
            "  1. all benchmark runs must succeed;",
            "  2. zero detected arithmetic overflows;",
            "  3. among safe formats, prefer the smallest numerical error;",
        ]

    out += [
        "",
        "=" * 92,
    ]

    output_path.write_text(
        "\n".join(out) + "\n"
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--nx",
        type=int,
        default=16,
        help="grid points per dimension",
    )

    parser.add_argument(
        "--iters",
        type=int,
        default=20,
        help="number of CG iterations",
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=Path("results/fixed_point_study.txt"),
        help="output report",
    )

    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent

    try:
        compile_project(root)
    except RuntimeError as e:
        print(e, file=sys.stderr)
        sys.exit(1)

    results = []

    for format_name, int_bits, frac_bits in FORMATS:

        print()
        print("=" * 72)
        print(f"{format_name}")
        print("=" * 72)

        try:
            generate_vectors(
                root,
                args.nx,
                args.iters,
                int_bits,
                frac_bits,
            )

        except RuntimeError as e:
            print(e, file=sys.stderr)
            continue

        for case in CASES:

            print(f"{case}")

            # ---------------------------------------------------------------
            # Double run
            # ---------------------------------------------------------------

            double_result = execute_case(
                root,
                format_name,
                case,
                "double",
            )

            results.append(double_result)

            if not double_result.success:
                print(
                    f"  double: FAILED "
                    f"({double_result.failure_reason})"
                )
            else:
                print(
                    f"  double residual: "
                    f"{double_result.residual}"
                )

            # ---------------------------------------------------------------
            # Fixed run
            # ---------------------------------------------------------------

            fixed_result = execute_case(
                root,
                format_name,
                case,
                "fixed",
            )

            results.append(fixed_result)

            if not fixed_result.success:
                print(
                    f"  fixed: FAILED "
                    f"({fixed_result.failure_reason})"
                )

                # Don't attempt to analyze an output that may be
                # incomplete/corrupted after a crash.
                continue

            print(
                f"  fixed residual:  "
                f"{fixed_result.residual}"
            )

            # ---------------------------------------------------------------
            # Solution-field analysis
            # ---------------------------------------------------------------

            case_dir = root / "data" / case

            try:
                u_exact, u_double, u_fixed = load_solutions(
                    case_dir
                )

                if double_result.success:
                    double_result.rel_error_vs_exact = (
                        relative_l2_error(
                            u_double,
                            u_exact,
                        )
                    )

                fixed_result.rel_error_vs_exact = (
                    relative_l2_error(
                        u_fixed,
                        u_exact,
                    )
                )

                fixed_result.rel_error_vs_double = (
                    relative_l2_error(
                        u_fixed,
                        u_double,
                    )
                )

                print(
                    f"  fixed/exact L2: "
                    f"{fixed_result.rel_error_vs_exact:.3e}"
                )

                print(
                    f"  fixed/double L2: "
                    f"{fixed_result.rel_error_vs_double:.3e}"
                )

            except Exception as e:
                print(
                    f"  WARNING: solution analysis failed: {e}",
                    file=sys.stderr,
                )

    output = args.output

    if not output.is_absolute():
        output = root / output

    output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    write_report(
        results,
        output,
        args.nx,
        args.iters,
    )

    print()
    print("=" * 72)
    print("Study complete")
    print(f"Report: {output}")
    print("=" * 72)


if __name__ == "__main__":
    main()
