import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // buildCodeAssets 为 false 时访问 input.config.code 会抛
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
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
    // Cargo.toml/Cargo.lock 改动不会自动触发钩子重跑，需显式登记为依赖
    output.dependencies.addAll([
      input.packageRoot.resolve('rust/Cargo.toml'),
      input.packageRoot.resolve('rust/Cargo.lock'),
    ]);
  });
}

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
