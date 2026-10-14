# LLGo's temporary LLVM 22 Darwin linker

This branch starts at LLVM 22.1.8 (`ca7933e47d3a3451d81e72ac174dcb5aa28b59d1`).
It carries the TextAPI/Mach-O architecture-definition portion of
[upstream #222721](https://github.com/llvm/llvm-project/pull/222721), allowing
ordinary arm64 and x86_64 links to read SDK 27 stubs containing `arm64e.x1`.
It does not add arm64e.x1 code generation.

The `LLGo LLD` workflow builds macOS arm64 and amd64 binaries from this source,
checks native/ThinLTO/FullLTO linking and an LLVM 22 pass plugin, and tests the
arm64 artifact again on the `xcode-27` runner against the real SDK 27.
Publishing is gated on all those jobs. Run the workflow on `lld-22` with
`publish=true` to create `lld-<version>`; existing releases are never replaced.

Each release contains two `lld-<version>-darwin-<arch>.tar.gz` archives and
`SHA256SUMS`. An archive contains `bin/ld64.lld`, licenses, and a source/build
manifest. LLVM is linked statically; only macOS system dylibs are allowed.
Both architectures require macOS 11 or later. Optional zstd support is disabled
to avoid an additional runtime dependency; zlib support is retained.

Build locally on the desired host architecture:

```sh
bash llgo-lld/build.sh /tmp/llgo-lld-build /tmp/llgo-lld-output
```

The compiler used to build LLD is the selected Xcode/CLT compiler. Programs
linked by the resulting LLD use its own LLVM 22 LTO implementation.
No ESP toolchain is modified. LLGo can keep its existing compiler selection
and pass `-fuse-ld=/path/to/ld64.lld` for native Darwin links only. Remove this temporary
component when LLGo upgrades to an LLVM release containing the upstream fix.
