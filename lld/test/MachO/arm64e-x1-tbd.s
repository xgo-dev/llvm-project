# REQUIRES: aarch64, x86
## SDK 27 adds arm64e.x1 slices even to stubs used by ordinary arm64/x86_64
## programs. Recognize the slice without rejecting the entire library.
# RUN: split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=arm64-apple-macos -o %t/arm64.o /dev/null
# RUN: llvm-mc -filetype=obj -triple=x86_64-apple-macos -o %t/x86_64.o /dev/null
# RUN: %no-arg-lld -arch arm64 -platform_version macos 11 27 -dylib -syslibroot %t/sdk -lSystem %t/arm64.o -o %t/arm64.dylib
# RUN: %no-arg-lld -arch x86_64 -platform_version macos 11 27 -dylib -syslibroot %t/sdk -lSystem %t/x86_64.o -o %t/x86_64.dylib

#--- sdk/usr/lib/libSystem.tbd
--- !tapi-tbd
tbd-version: 4
targets: [ arm64-macos, x86_64-macos, arm64e.x1-macos, arm64e.x1-maccatalyst ]
install-name: '/usr/lib/libSystem.B.dylib'
current-version: 1.0.0
...
