#include "llvm/Passes/PassBuilder.h"
#include "llvm/Plugins/PassPlugin.h"
#include <cstdio>

extern "C" LLVM_ATTRIBUTE_WEAK llvm::PassPluginLibraryInfo llvmGetPassPluginInfo() {
  std::fputs("LLGO_PLUGIN_ENTRY\n", stderr);
  return {LLVM_PLUGIN_API_VERSION, "llgo-lld-release-test", "1",
          [](llvm::PassBuilder &PB) {
            PB.registerFullLinkTimeOptimizationEarlyEPCallback(
                [](llvm::ModulePassManager &, llvm::OptimizationLevel) {
                  std::fputs("LLGO_FULL_LTO_CALLBACK\n", stderr);
                });
          }};
}
