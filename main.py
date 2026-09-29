"""Project entry point.

Keep this file small. Once the Python model exists, make ``main()`` a convenient
command-line entry point for one clearly named workflow (for example, generating
vectors or running a reference-model demonstration). Parse arguments here and
delegate all surface-code logic to modules in ``python/``; do not duplicate that
logic in this file. Print useful paths and summary results, and return a nonzero
exit status when a requested workflow fails.
"""

def main():
    print("Hello from fpga-surface-code-decoder!")


if __name__ == "__main__":
    main()
