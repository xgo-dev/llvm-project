#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${1:?usage: prepare-tests.sh BUILD_DIR OUTPUT_DIR}"
output_dir="${2:?usage: prepare-tests.sh BUILD_DIR OUTPUT_DIR}"
mkdir -p "$output_dir"
arch="$(uname -m)"
cat > "$output_dir/main.c" <<'EOF'
extern int puts(const char *);
int main(void) { puts("LLD probe OK"); return 0; }
EOF
xcrun clang -target "$arch-apple-macos11" -O2 -c "$output_dir/main.c" -o "$output_dir/native.o"
cat > "$output_dir/main.ll" <<EOF
target triple = "$arch-apple-macosx11.0.0"
@message = private constant [13 x i8] c"LLD probe OK\00"
declare i32 @puts(ptr)
define i32 @main() {
  %r = call i32 @puts(ptr @message)
  ret i32 0
}
EOF
"$build_dir/bin/llvm-as" "$output_dir/main.ll" -o "$output_dir/full.o"
"$build_dir/bin/opt" -module-summary "$output_dir/full.o" -o "$output_dir/thin.o"
xcrun clang++ -std=c++17 -mmacosx-version-min=11.0 -shared -fPIC \
  -I"$root/llvm/include" -I"$build_dir/include" \
  "$root/llgo-lld/plugin.cpp" -Wl,-undefined,dynamic_lookup -o "$output_dir/plugin.dylib"
