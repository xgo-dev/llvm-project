#!/usr/bin/env bash
set -euo pipefail
linker="${1:?usage: test.sh LD64_LLD TEST_INPUTS}"
inputs="${2:?usage: test.sh LD64_LLD TEST_INPUTS}"
"$linker" --version
codesign --verify "$linker"
# Fail rather than publishing a binary tied to Homebrew, libLLVM, or a build tree.
otool -L "$linker" | awk 'NR > 1 {print $1}' | while IFS= read -r dependency; do
  case "$dependency" in
    /usr/lib/*|/System/Library/*) ;;
    *) echo "Unexpected runtime dependency: $dependency" >&2; exit 1 ;;
  esac
done
sdk="$(xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
if [[ "${LLD_REQUIRE_SDK27:-0}" == 1 && "$sdk_version" != 27* ]]; then
  echo "SDK 27 required, got $sdk_version at $sdk" >&2
  exit 1
fi
echo "Testing $(uname -m) with SDK $sdk_version at $sdk"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for mode in native thin full; do
  "$linker" -arch "$(uname -m)" -platform_version macos 11 "$sdk_version" \
    -syslibroot "$sdk" -lSystem "$inputs/$mode.o" -o "$work/$mode"
  [[ "$("$work/$mode")" == 'LLD probe OK' ]]
done
"$linker" -arch "$(uname -m)" -platform_version macos 11 "$sdk_version" \
  -syslibroot "$sdk" -lSystem "$inputs/full.o" \
  "--load-pass-plugin=$inputs/plugin.dylib" -o "$work/plugin" 2> "$work/plugin.log"
cat "$work/plugin.log"
grep -q '^LLGO_PLUGIN_ENTRY$' "$work/plugin.log"
grep -q '^LLGO_FULL_LTO_CALLBACK$' "$work/plugin.log"
[[ "$("$work/plugin")" == 'LLD probe OK' ]]
