import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart'
    show FlutterRustBridgeNativeAssetsBuilder;
import 'package:hooks/hooks.dart';
import 'package:meta/meta.dart';

const _rustflagsSep = '\x1f';
const _android16kPageSizeLinkArg = 'link-arg=-Wl,-z,max-page-size=16384';

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
        processEnvironment: Platform.environment,
        workspaceRoot: input.packageRoot.resolve('../../../'),
      );
      await FlutterRustBridgeNativeAssetsBuilder(
        cratePath: 'rust',
        extraCargoBuildArgs: const ['--locked'],
        extraCargoEnvironmentVariables: env,
      ).run(input: input, output: output);
    });

@visibleForTesting
Map<String, String> rustCargoEnvironment(
  CodeConfig code, {
  Uri? androidNdkRoot,
  Map<String, String>? processEnvironment,
  Uri? workspaceRoot,
}) {
  final rustflags = _buildEncodedRustflags(
    code,
    processEnvironment: processEnvironment,
    workspaceRoot: workspaceRoot,
  );
  return {
    ...switch (code.targetOS) {
      OS.iOS => {
        'IPHONEOS_DEPLOYMENT_TARGET': _formatAppleVersion(
          code.iOS.deploymentVersion,
        ),
      },
      OS.macOS => {
        'MACOSX_DEPLOYMENT_TARGET': _formatAppleVersion(
          code.macOS.deploymentVersion,
        ),
      },
      OS.android when androidNdkRoot != null => _androidCmakeEnvironment(
        code,
        androidNdkRoot,
      ),
      _ => const <String, String>{},
    },
    'CARGO_ENCODED_RUSTFLAGS': ?rustflags,
  };
}

String? _buildEncodedRustflags(
  CodeConfig code, {
  Map<String, String>? processEnvironment,
  Uri? workspaceRoot,
}) {
  if (processEnvironment == null && workspaceRoot == null) return null;
  final env = processEnvironment ?? const <String, String>{};
  final flags = <String>[];

  final existingEncoded = env['CARGO_ENCODED_RUSTFLAGS'];
  final existingRaw = env['RUSTFLAGS'];
  if (existingEncoded != null && existingEncoded.isNotEmpty) {
    flags.addAll(existingEncoded.split(_rustflagsSep));
  } else if (existingRaw != null && existingRaw.trim().isNotEmpty) {
    flags.addAll(existingRaw.trim().split(RegExp(r'\s+')));
  }

  final home = _nonEmpty(env['HOME']) ?? _nonEmpty(env['USERPROFILE']);
  final cargoHome =
      _nonEmpty(env['CARGO_HOME']) ?? (home != null ? '$home/.cargo' : null);
  final rustupHome =
      _nonEmpty(env['RUSTUP_HOME']) ?? (home != null ? '$home/.rustup' : null);

  if (cargoHome != null) {
    flags.add('--remap-path-prefix=${_stripTrailingSep(cargoHome)}=/cargo');
  }
  if (rustupHome != null) {
    flags.add('--remap-path-prefix=${_stripTrailingSep(rustupHome)}=/rustup');
  }
  if (workspaceRoot != null) {
    final rootPath = _stripTrailingSep(Directory.fromUri(workspaceRoot).path);
    flags.add('--remap-path-prefix=$rootPath=/workspace');
  }

  // Setting CARGO_ENCODED_RUSTFLAGS suppresses native_toolchain_rust's
  // automatic 16 KB page-size linker flag for 64-bit Android targets, so
  // preserve it explicitly here.
  if (code.targetOS == OS.android &&
      (code.targetArchitecture == Architecture.arm64 ||
          code.targetArchitecture == Architecture.x64) &&
      !flags.contains(_android16kPageSizeLinkArg)) {
    flags.addAll(const ['-C', _android16kPageSizeLinkArg]);
  }

  return flags.isEmpty ? null : flags.join(_rustflagsSep);
}

String? _nonEmpty(String? value) =>
    value != null && value.isNotEmpty ? value : null;

String _stripTrailingSep(String path) =>
    path.replaceFirst(RegExp(r'[/\\]+$'), '');

String _formatAppleVersion(AppleVersion version) => version.patch > 0
    ? '${version.major}.${version.minor}.${version.patch}'
    : '${version.major}.${version.minor}';

Map<String, String> _androidCmakeEnvironment(CodeConfig code, Uri ndkRoot) {
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
    'CMAKE_TOOLCHAIN_FILE_$target': ndkRoot
        .resolve('build/cmake/android.toolchain.cmake')
        .toFilePath(),
    'ANDROID_NDK_ROOT': Directory.fromUri(ndkRoot).path,
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
