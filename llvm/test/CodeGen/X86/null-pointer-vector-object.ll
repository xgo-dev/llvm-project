; RUN: llc -mtriple=x86_64-unknown-linux-gnu -data-sections -filetype=obj %s -o %t
; RUN: llvm-readobj --symbols %t | FileCheck %s
; RUN: llc -mtriple=i686-unknown-linux-gnu -data-sections -filetype=obj %s -o %t.32
; RUN: llc -mtriple=x86_64-pc-windows-msvc -data-sections -filetype=obj %s -o %t.obj

; Null pointer splats wider than eight bytes must not be emitted as a single
; integer. Besides asserting in MCStreamer, that read past its byte buffer in
; release builds, producing nonzero bytes in BSS.
@scalar = global ptr null
@v2 = global <2 x ptr> splat (ptr null)
@v4 = global <4 x ptr> splat (ptr null)
@array = global [2 x ptr] zeroinitializer

; CHECK:      Name: scalar
; CHECK:      Size: 8
; CHECK:      Section: .bss.scalar
; CHECK:      Name: v2
; CHECK:      Size: 16
; CHECK:      Section: .bss.v2
; CHECK:      Name: v4
; CHECK:      Size: 32
; CHECK:      Section: .bss.v4
; CHECK:      Name: array
; CHECK:      Size: 16
; CHECK:      Section: .bss.array
