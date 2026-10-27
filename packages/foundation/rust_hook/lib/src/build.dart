import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart'
    show FlutterRustBridgeNativeAssetsBuilder;
import 'package:hooks/hooks.dart';
import 'package:meta/meta.dart';

Future<void> buildRustCrate(List<String> args, {bool androidCmake = false}) =>
    build(args, (input, output) async {
      if (!input.config.buildCodeAssets) return;
      // https://github.com/dart-lang/native/issues/2480
      if (input.userDefines['build_assets'] == false) return;
      final code = input.config.code;
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
    // https://github.com/GregoryConrad/native_toolchain_rust/issues/116
    'CARGO_TARGET_${target.toUpperCase()}_RUSTFLAGS':
        '-C link-arg=-Wl,-z,max-page-size=16384',
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
