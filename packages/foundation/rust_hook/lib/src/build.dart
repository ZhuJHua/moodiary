import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart'
    show FlutterRustBridgeNativeAssetsBuilder;
import 'package:hooks/hooks.dart';
import 'package:meta/meta.dart';

Future<void> buildRustCrate(List<String> args, {bool androidCmake = false}) =>
    build(args, (input, output) async {
      // hooks 在 buildCodeAssets 为 false 时访问 code 会抛异常。
      if (!input.config.buildCodeAssets) return;
      final code = input.config.code;
      // flutter test 以宿主 OS 为目标，不构建 Rust 库。
      if (code.targetOS == OS.current) return;
      final env = rustCargoEnvironment(
        code,
        androidNdkRoot: androidCmake && code.targetOS == OS.android
            ? _androidNdkRoot(code)
            : null,
      );
      await FlutterRustBridgeNativeAssetsBuilder(
        cratePath: 'rust',
        extraCargoEnvironmentVariables: env,
      ).run(input: input, output: output);
      // native_toolchain_rust 只跟踪 .d 源文件，需登记清单和工具链以免复用旧库。
      output.dependencies.addAll([
        input.packageRoot.resolve('rust/Cargo.toml'),
        input.packageRoot.resolve('rust/Cargo.lock'),
        input.packageRoot.resolve('rust/rust-toolchain.toml'),
      ]);
    });

@visibleForTesting
Map<String, String> rustCargoEnvironment(
  CodeConfig code, {
  Uri? androidNdkRoot,
}) {
  // native_toolchain_rust 不传部署目标，rustc 默认 iOS 10.0，C 依赖按 SDK 编会引用 ___chkstk_darwin。
  return switch (code.targetOS) {
    OS.iOS => {'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0'},
    OS.macOS => {'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0'},
    OS.android => _androidEnvironment(code, androidNdkRoot),
    _ => const <String, String>{},
  };
}

Map<String, String> _androidEnvironment(CodeConfig code, Uri? ndkRoot) {
  final triple = switch (code.targetArchitecture) {
    Architecture.arm64 => 'aarch64-linux-android',
    Architecture.arm => 'armv7-linux-androideabi',
    Architecture.x64 => 'x86_64-linux-android',
    _ => throw UnsupportedError(
      'Unsupported Android architecture: ${code.targetArchitecture}',
    ),
  };
  final target = triple.replaceAll('-', '_');
  return {
    // native_toolchain_rust#116：旧 NDK 默认 4 KB，需显式要求 16 KB 页对齐。
    'CARGO_TARGET_${target.toUpperCase()}_RUSTFLAGS':
        '-C link-arg=-Wl,-z,max-page-size=16384',
    // turbojpeg-sys 的 cmake-rs 0.1.58 需通过目标专属环境变量找到 NDK 工具链。
    if (ndkRoot != null) ...{
      'CMAKE_TOOLCHAIN_FILE_$target': ndkRoot
          .resolve('build/cmake/android.toolchain.cmake')
          .toFilePath(),
      'ANDROID_NDK_ROOT': Directory.fromUri(ndkRoot).path,
    },
  };
}

Uri? _androidNdkRoot(CodeConfig code) {
  final compiler = code.cCompiler?.compiler;
  if (compiler == null) return null;
  var dir = File.fromUri(compiler).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  final toolchain = File('${dir.path}/build/cmake/android.toolchain.cmake');
  return toolchain.existsSync() ? dir.uri : null;
}
