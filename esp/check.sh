#!/usr/bin/env bash
# Run from any directory after configuring the build described in README.md.
set -euo pipefail

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$(cd "${1:?usage: esp/check.sh BUILD_DIR [JOBS]}" && pwd)"
jobs="${2:-4}"

cmake --build "$build_root" --parallel "$jobs" --target \
  clang lld llc opt llvm-mc llvm-objdump llvm-readobj llvm-ar llvm-nm \
  llvm-config llvm-as llvm-dis llvm-link llvm-objcopy llvm-readelf llvm-size \
  llvm-strip llvm-ranlib llvm-dwarfdump llvm-symbolizer llvm-otool llvm-mca \
  llvm-lto llvm-lto2 FileCheck not count split-file yaml2obj obj2yaml \
  TargetParserTests

"$build_root/unittests/TargetParser/TargetParserTests"
cd "$source_root"
"$build_root/bin/llvm-lit" -sv -j "$jobs" \
  llvm/test/MC/Xtensa llvm/test/CodeGen/Xtensa \
  llvm/test/Transforms/AtomicExpand/Xtensa lld/test/ELF/xtensa-reloc.s \
  llvm/test/MC/RISCV llvm/test/CodeGen/RISCV \
  llvm/test/CodeGen/X86/zero-call-used-regs* \
  llvm/test/CodeGen/AArch64/zero-call-used-regs.ll \
  llvm/test/tools/llvm-mca/RISCV \
  clang/test/CodeGen/Xtensa clang/test/CodeGen/xtensa-inline-asm.c \
  clang/test/CodeGen/RISCV/esp32p4-intrinsics \
  clang/test/CodeGen/RISCV/riscv-esp32h4.c \
  clang/test/CodeGen/RISCV/xespv-march-versions.c \
  clang/test/Sema/RISCV/esp32p4-vcmp-u21-only.c \
  clang/test/Driver/xtensa* clang/test/Driver/riscv* \
  clang/test/Driver/print-enabled-extensions/riscv* \
  clang/test/Driver/print-supported-extensions-riscv.c \
  clang/test/Driver/baremetal-esp.cpp clang/test/Driver/baremetal-sysroot.cpp \
  clang/test/Misc/pragma-attribute-supported-attributes-list.test \
  clang/test/Misc/target-invalid-cpu-note/riscv.c \
  clang/test/Preprocessor/init.c clang/test/Preprocessor/stdint.c \
  clang/test/Preprocessor/xtensa-target-features.c

python3 esp/smoke.py "$build_root"
