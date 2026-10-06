#!/usr/bin/env python

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def read_bov_header(fname):
    """Read VisIt BOV file header."""
    header_path = Path(fname).resolve()
    header = {}
    with header_path.open("r", encoding="utf-8") as file:
        for line in file:
            line = line.strip()
            if not line or ":" not in line:
                continue
            key, value = line.split(":", 1)
            header[key.strip().upper()] = value.strip()

    required = {
        "DATA_FILE",
        "DATA_SIZE",
        "DATA_FORMAT",
        "DATA_ENDIAN",
        "BRICK_ORIGIN",
        "BRICK_SIZE",
    }
    missing = required - header.keys()
    if missing:
        raise ValueError(
            f"Missing BOV header field(s): {', '.join(sorted(missing))}"
        )

    try:
        data_size = tuple(int(value) for value in header["DATA_SIZE"].split())
        brick_origin = tuple(
            float(value) for value in header["BRICK_ORIGIN"].split()
        )
        brick_size = tuple(
            float(value) for value in header["BRICK_SIZE"].split()
        )
    except ValueError as error:
        raise ValueError(f"Invalid numeric value in {header_path}") from error

    if len(data_size) != 3 or len(brick_origin) != 3 or len(brick_size) != 3:
        raise ValueError("DATA_SIZE, BRICK_ORIGIN, and BRICK_SIZE must have 3 values")

    data_file = Path(header["DATA_FILE"])
    if not data_file.is_absolute():
        data_file = header_path.parent / data_file

    return {
        "data_file": data_file,
        "data_size": data_size,
        "data_format": header["DATA_FORMAT"].upper(),
        "data_endian": header["DATA_ENDIAN"].upper(),
        "brick_origin": brick_origin,
        "brick_size": brick_size,
    }


def read_bov_data(header):
    """Read VisIt BOV file data."""
    if header["data_format"] == "FLOAT":
        dtype = np.dtype(np.float32)
    elif header["data_format"] == "DOUBLE":
        dtype = np.dtype(np.float64)
    else:
        raise ValueError(f"Unknown data format: {header['data_format']}")

    endian = header["data_endian"]
    if endian in {"LITTLE", "LITTLE_ENDIAN"}:
        dtype = dtype.newbyteorder("<")
    elif endian in {"BIG", "BIG_ENDIAN"}:
        dtype = dtype.newbyteorder(">")
    else:
        raise ValueError(f"Unknown data endian: {endian}")

    data_size = header["data_size"]
    expected_values = int(np.prod(data_size))
    data = np.fromfile(header["data_file"], dtype=dtype)
    if data.size != expected_values:
        raise ValueError(
            f"Expected {expected_values} values in {header['data_file']}, "
            f"found {data.size}"
        )

    # BOV stores x as the contiguous dimension.  The C++ Field uses the same
    # layout, so the NumPy shape is (z, y, x) in row-major order.
    return data.reshape((data_size[2], data_size[1], data_size[0]))[0]


def plot_data(fname, save=True):
    """Plot data from VisIt BOV file."""
    header = read_bov_header(fname)
    res = header["data_size"]
    brick_origin = header["brick_origin"]
    brick_size = header["brick_size"]
    x = np.linspace(brick_origin[0], brick_origin[0] + brick_size[0], res[0])
    y = np.linspace(brick_origin[1], brick_origin[1] + brick_size[1], res[1])
    data = read_bov_data(header)
    fig, ax = plt.subplots()
    ax.set_aspect("equal")
    ax.set_xlabel(r"$x$")
    ax.set_ylabel(r"$y$")
    C = ax.pcolormesh(x, y, data, shading="auto", cmap="jet")
    cbar = fig.colorbar(C, ax=ax)
    cbar.minorticks_on()
    if save:
        output = Path(fname).with_suffix(".png")
        fig.savefig(output, dpi=300, bbox_inches="tight")
        # plt.close(fig)
    plt.show()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plot a VisIt BOV solution.")
    parser.add_argument(
        "bov_file",
        nargs="?",
        default="output.bov",
        help="BOV header written by main.cpp (default: output.bov)",
    )
    args = parser.parse_args()
    plot_data(args.bov_file, save=True)
