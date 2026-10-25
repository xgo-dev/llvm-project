#!/usr/bin/env python3
"""Compile and link freestanding ESP code with the tools from one build."""

from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: esp/smoke.py BUILD_DIR")
    binary = Path(sys.argv[1]).resolve() / "bin"

    def run(tool, *args):
        return subprocess.check_output([str(binary / tool), *map(str, args)], text=True)

    targets = {
        "xtensa-esp-unknown-elf": ["esp8266", "esp32", "esp32s2", "esp32s3"],
        "riscv32-esp-unknown-elf": [
            "esp32c2", "esp32c3", "esp32c5", "esp32c6", "esp32c61eco0",
            "esp32c61", "esp32h2", "esp32h21", "esp32h4", "esp32p4eco4",
            "esp32p4", "esp32s31",
        ],
    }
    with tempfile.TemporaryDirectory(prefix="esp-llvm-smoke-") as temporary:
        directory = Path(temporary)
        source = directory / "add.c"
        source.write_text("int esp_add(int a, int b) { return a + b; }\n")
        for triple, cpus in targets.items():
            for cpu in cpus:
                for lto in (False, True):
                    label = cpu + ("-lto" if lto else "")
                    obj = directory / (label + ".o")
                    linked = directory / (label + "-linked.o")
                    flags = ["-flto"] if lto else []
                    run("clang", "--target=" + triple, "-mcpu=" + cpu,
                        "-O2", "-Werror", "-ffreestanding", *flags,
                        "-c", source, "-o", obj)
                    run("ld.lld", "-r", obj, "-o", linked)
                    symbols = run("llvm-nm", "--defined-only", linked)
                    if " T esp_add" not in symbols:
                        raise RuntimeError(label + ": linked function is missing")
                    headers = run("llvm-readobj", "--file-headers", linked)
                    machine = "EM_XTENSA" if triple.startswith("xtensa") else "EM_RISCV"
                    if machine not in headers:
                        raise RuntimeError(label + ": wrong ELF machine")
                    print(label + ": compile and relocatable link passed", flush=True)


if __name__ == "__main__":
    main()
