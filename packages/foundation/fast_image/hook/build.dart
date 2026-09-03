import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final code = input.config.code;
    // Apple 部署目标由 hook 从 input.config 映射给工具链——这是 Native Assets 的
    // 架构约定：hooks_runner 用环境白名单运行 hook（*_DEPLOYMENT_TARGET 进不来），
    // native_toolchain_c 内部就做同样的映射（targetVersion → -mios-version-min），
    // native_toolchain_rust 漏了这一步（上游缺口）。不映射的话 cc 编译的 C 依赖
    // （zstd/ring）吃 SDK 默认口径、rustc 按三元组默认（iOS 10.0）链接，Xcode 26
    // SDK 下会因 ___chkstk_darwin（iOS 13+ 才进 libSystem）直接链接失败。
    //
    // turbojpeg-sys 走 cmake（cmake-rs）编 vendored libjpeg-turbo，与 cc 那条链不同源，
    // 要再补两样：Android 的 NDK toolchain 文件（cmake-rs 只认 CMAKE_TOOLCHAIN_FILE_<target>
    // 这个环境变量，NDK 根从 Flutter 给的 clang 路径推），iOS 模拟器的 SDKROOT
    // （cmake-rs 对 aarch64-apple-ios-sim 只设 CMAKE_SYSTEM_NAME=iOS，不切模拟器 sysroot）。
    final env = switch (code.targetOS) {
      OS.iOS => {
        'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0',
        if (code.iOS.targetSdk == IOSSdk.iPhoneSimulator)
          'SDKROOT': _xcrunSdkPath('iphonesimulator'),
      },
      OS.macOS => {'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0'},
      OS.android => _androidCmakeEnv(code),
      _ => const <String, String>{},
    };
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: env,
    ).run(input: input, output: output);
    // native_toolchain_rust 只把 crate 自己的 src 文件（cargo dep-info）登记为依赖：
    // 改了 Cargo.toml / Cargo.lock（换依赖、换 [patch]、改 profile）钩子不会重跑，
    // hooks_runner 会一直复用上一份 .so。显式登记这两个文件把这条路堵上。
    output.dependencies.addAll([
      input.packageRoot.resolve('rust/Cargo.toml'),
      input.packageRoot.resolve('rust/Cargo.lock'),
    ]);
  });
}

/// `.../ndk/<ver>/toolchains/llvm/prebuilt/<host>/bin/<triple><api>-clang` → NDK 根。
Map<String, String> _androidCmakeEnv(CodeConfig code) {
  final compiler = code.cCompiler?.compiler;
  if (compiler == null) return const {};
  var dir = File.fromUri(compiler).parent; // bin
  for (var i = 0; i < 5; i++) {
    dir = dir.parent; // <host> → prebuilt → llvm → toolchains → <ndk root>
  }
  final toolchain = File('${dir.path}/build/cmake/android.toolchain.cmake');
  if (!toolchain.existsSync()) return const {};
  final triple = switch (code.targetArchitecture) {
    Architecture.arm64 => 'aarch64_linux_android',
    Architecture.arm => 'armv7_linux_androideabi',
    Architecture.x64 => 'x86_64_linux_android',
    Architecture.ia32 => 'i686_linux_android',
    _ => null,
  };
  if (triple == null) return const {};
  return {
    'CMAKE_TOOLCHAIN_FILE_$triple': toolchain.path,
    'ANDROID_NDK_ROOT': dir.path,
  };
}

String _xcrunSdkPath(String sdk) {
  final result = Process.runSync('xcrun', ['--sdk', sdk, '--show-sdk-path']);
  return (result.stdout as String).trim();
}
