# ESP support on upstream LLVM 23

This branch carries Espressif target support on the official LLVM 23 release
sources. It is maintained in `xgo-dev/llvm-project` so LLGo can use the same LLVM
major version for its host compiler libraries and ESP cross-compilation tools.

## Source provenance

- Base: official `llvmorg-23.1.4`, commit
  `7a941dfb2877a0b8cf30323fefa85ad019e0b0f5`.
- ESP support: the delta from official `llvmorg-22.1.4`
  (`35990504507d79e0b9deb809c8ee5e1b34ceef20`) to Espressif
  `esp-22.1.4_20260825` (`3f19539fb25df04eb74664ddf9dc81574953192c`).
- GNU assembler `.begin schedule` / `.end schedule` compatibility is included
  directly in the source, replacing the corresponding LLGo packaging patch.

The port includes Xtensa CPU and DSP support, ESP RISC-V CPUs and extensions,
Clang builtins and bare-metal drivers, Xtensa ELF linking, and the Espressif
runtime adaptations. Vendor CI and unrelated clangd changes are excluded.
Upstream LLVM 23 functionality remains the base; overlapping APIs are adapted
to the LLVM 23 interfaces instead of restoring older implementations.

Notable adaptations include multiple memory operands for target intrinsics,
alignment and address-space-aware legalization, the split conditional branch
IR opcode, and fragment-specific inline assembly target properties. The
subtarget feature bitset has seven words because the combined RISC-V feature
set exceeds LLVM 23's original 384-bit capacity. Build all libraries and tools
from the same sources; do not mix C++ LLVM libraries from different builds.

The port also fixes LLVM 23 integration failures exposed by the ESP tests:
loop information must be erased before extracting blocks into another
function, empty blocks use `hasTerminator()`, and Xtensa vector registers must
not reuse the DWARF numbers of address registers. A separate generic codegen
fix keeps physical-register and register-unit indices distinct when clearing
call-used registers, while preserving x86 partial-register return values.

## Build and check

Configure a Release build with assertions and the Xtensa experimental target:

```sh
cmake -S llvm -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS='clang;lld' \
  -DLLVM_TARGETS_TO_BUILD='X86;AArch64;RISCV;ARM;AVR;Mips;WebAssembly' \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=Xtensa
cmake --build build --parallel 4
bash esp/check.sh build 4
```

Use an external-disk ccache directory on macOS and pass its executable as both
`CMAKE_C_COMPILER_LAUNCHER` and `CMAKE_CXX_COMPILER_LAUNCHER` when available.

Compiler regression tests cover code generation and assembler behavior. They
are not a substitute for firmware execution on hardware or qualification of
all ESP runtime libraries.

Local qualification on macOS arm64 (2026-10-25), Release with assertions:

- 3,896 lit tests passed: complete Xtensa and RISC-V codegen/MC tests,
  RISC-V scheduling tests, ESP Clang builtins, relevant driver/preprocessor
  tests, and x86/AArch64/RISC-V register-clearing regressions.
- TargetParser unit tests: 670 passed, 3 platform-dependent AIX tests skipped.
- 16 ESP CPU configurations each compiled and linked ordinary objects and LTO
  bitcode (32 checks), with the linked symbol and ELF machine verified.

The `esp-check.yml` workflow repeats these compiler checks on Linux x86_64 and
macOS arm64. Binary distribution has its own platform validation gates.

## Binary distribution

The separate `xgo-dev/espressif-llvm-project-prebuilt` repository builds and
validates host payloads. Its `toolchain.env` must pin a full source commit from
this repository and record that commit in `LLGO-LLVM-MANIFEST.txt`. Update LLGo's
download version and host checksums only after the corresponding payloads have
completed their platform validation and been published.
