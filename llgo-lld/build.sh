#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${1:?usage: build.sh BUILD_DIR OUTPUT_DIR}"
output_dir="${2:?usage: build.sh BUILD_DIR OUTPUT_DIR}"
mkdir -p "$build_dir" "$output_dir"
build_dir="$(cd "$build_dir" && pwd)"
output_dir="$(cd "$output_dir" && pwd)"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
version="$(cat "$root/llgo-lld/version.txt")"
case "$(uname -m)" in
  arm64) arch=arm64 ;;
  x86_64) arch=amd64 ;;
  *) echo 'Only macOS arm64 and x86_64 release hosts are supported' >&2; exit 1 ;;
esac

# Build all LLVM code used by LLD from this checkout. Only system dylibs may
# remain: a release must not depend on the builder's Homebrew installation.
cmake -S "$root/llvm" -B "$build_dir" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$(xcrun --find clang)" \
  -DCMAKE_CXX_COMPILER="$(xcrun --find clang++)" \
  -DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DLLVM_ENABLE_PROJECTS=lld '-DLLVM_TARGETS_TO_BUILD=AArch64;X86' \
  -DBUILD_SHARED_LIBS=OFF -DLLVM_BUILD_LLVM_DYLIB=OFF -DLLVM_LINK_LLVM_DYLIB=OFF \
  -DLLVM_ENABLE_PLUGINS=ON -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_ZLIB=FORCE_ON -DZLIB_LIBRARY="$sdk/usr/lib/libz.tbd" \
  -DZLIB_INCLUDE_DIR="$sdk/usr/include" \
  -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_CURL=OFF -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF
cmake --build "$build_dir" --parallel "${LLD_BUILD_JOBS:-$(sysctl -n hw.logicalcpu)}" \
  --target lld llvm-as llvm-mc opt FileCheck split-file not

stage="$output_dir/lld-$version-darwin-$arch"
mkdir -p "$stage/bin"
install -m 0755 "$build_dir/bin/lld" "$stage/bin/ld64.lld"
strip -S "$stage/bin/ld64.lld"
codesign --force --sign - "$stage/bin/ld64.lld"
install -m 0644 "$root/llvm/LICENSE.TXT" "$stage/LICENSE-LLVM.txt"
install -m 0644 "$root/lld/LICENSE.TXT" "$stage/LICENSE-LLD.txt"
python3 - "$root" "$stage" "$version" "$arch" "$sdk" <<'PY'
import json, pathlib, subprocess, sys
root, stage, version, arch, sdk = sys.argv[1:]
manifest = dict(version=version, llvm_version="22.1.8", architecture=arch,
               source_repository="https://github.com/xgo-dev/llvm-project",
               source_commit=subprocess.check_output(["git", "-C", root, "rev-parse", "HEAD"], text=True).strip(),
               upstream_commit="ca7933e47d3a3451d81e72ac174dcb5aa28b59d1",
               sdk_version=subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-version"], text=True).strip(),
               deployment_target="11.0", zstd=False)
pathlib.Path(stage, "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY

bash "$root/llgo-lld/prepare-tests.sh" "$build_dir" "$output_dir/test-inputs-$arch"
bash "$root/llgo-lld/test.sh" "$stage/bin/ld64.lld" "$output_dir/test-inputs-$arch"

# Exercise the checked-in lit regression with the build's own assembler/tools.
"$build_dir/bin/split-file" "$root/lld/test/MachO/arm64e-x1-tbd.s" "$output_dir/tbd-test"
for target in arm64 x86_64; do
  "$build_dir/bin/llvm-mc" -filetype=obj -triple="$target-apple-macos" \
    -o "$output_dir/tbd-test/$target.o" /dev/null
  "$stage/bin/ld64.lld" -arch "$target" -platform_version macos 11 27 -dylib \
    -syslibroot "$output_dir/tbd-test/sdk" -lSystem "$output_dir/tbd-test/$target.o" \
    -o "$output_dir/tbd-test/$target.dylib"
done
tar -czf "$output_dir/lld-$version-darwin-$arch.tar.gz" -C "$output_dir" "lld-$version-darwin-$arch"
(cd "$output_dir" && shasum -a 256 "lld-$version-darwin-$arch.tar.gz" > "lld-$version-darwin-$arch.tar.gz.sha256")
