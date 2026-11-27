import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/hooks.dart';
import 'package:rust_hook/rust_hook.dart';

void main() {
  late Directory temp;

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('rust_hook_test_');
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  CodeConfig code(
    OS os, {
    Architecture architecture = Architecture.arm64,
    AppleVersion? iosVersion,
    AppleVersion? macosVersion,
  }) {
    final builder = BuildInputBuilder()
      ..setupShared(
        packageRoot: temp.uri,
        packageName: 'rust_hook',
        outputDirectoryShared: temp.uri.resolve('output/'),
        outputFile: temp.uri.resolve('output.json'),
      )
      ..setupBuildInput()
      ..addExtension(
        CodeAssetExtension(
          targetOS: os,
          targetArchitecture: architecture,
          linkModePreference: LinkModePreference.dynamic,
          iOS: os == OS.iOS
              ? IOSCodeConfig(
                  targetSdk: IOSSdk.iPhoneOS,
                  deploymentVersion: iosVersion ?? AppleVersion(16),
                )
              : null,
          macOS: os == OS.macOS
              ? MacOSCodeConfig(
                  deploymentVersion: macosVersion ?? AppleVersion(13),
                )
              : null,
          android: os == OS.android
              ? AndroidCodeConfig(targetNdkApi: 28)
              : null,
        ),
      );
    builder.config.setupBuild(linkingEnabled: false);
    return builder.build().config.code;
  }

  test('iOS formats the deployment target', () {
    expect(rustCargoEnvironment(code(OS.iOS)), {
      'IPHONEOS_DEPLOYMENT_TARGET': '16.0',
    });
    expect(
      rustCargoEnvironment(
        code(OS.iOS, iosVersion: AppleVersion(16, minor: 4)),
      ),
      {'IPHONEOS_DEPLOYMENT_TARGET': '16.4'},
    );
    expect(
      rustCargoEnvironment(
        code(OS.iOS, iosVersion: AppleVersion(16, minor: 4, patch: 1)),
      ),
      {'IPHONEOS_DEPLOYMENT_TARGET': '16.4.1'},
    );
  });

  test('macOS formats the deployment target', () {
    expect(rustCargoEnvironment(code(OS.macOS)), {
      'MACOSX_DEPLOYMENT_TARGET': '13.0',
    });
    expect(
      rustCargoEnvironment(
        code(OS.macOS, macosVersion: AppleVersion(14, minor: 2)),
      ),
      {'MACOSX_DEPLOYMENT_TARGET': '14.2'},
    );
  });

  for (final (architecture, target) in [
    (Architecture.arm64, 'aarch64_linux_android'),
    (Architecture.arm, 'armv7_linux_androideabi'),
    (Architecture.x64, 'x86_64_linux_android'),
  ]) {
    test('Android $architecture with CMake sets toolchain and NDK root', () {
      final ndkRoot = temp.uri.resolve('ndk/');
      expect(
        rustCargoEnvironment(
          code(OS.android, architecture: architecture),
          androidNdkRoot: ndkRoot,
        ),
        {
          'CMAKE_TOOLCHAIN_FILE_$target': ndkRoot
              .resolve('build/cmake/android.toolchain.cmake')
              .toFilePath(),
          'ANDROID_NDK_ROOT': Directory.fromUri(ndkRoot).path,
        },
      );
    });
  }

  test('unsupported Android architectures throw when CMake is enabled', () {
    expect(
      () => rustCargoEnvironment(
        code(OS.android, architecture: Architecture.ia32),
        androidNdkRoot: temp.uri.resolve('ndk/'),
      ),
      throwsUnsupportedError,
    );
  });

  test('other platforms need no extra environment', () {
    expect(rustCargoEnvironment(code(OS.linux)), isEmpty);
  });

  test('remaps CARGO_HOME, RUSTUP_HOME and workspace root in rustflags', () {
    final env = rustCargoEnvironment(
      code(OS.android, architecture: Architecture.arm64),
      processEnvironment: const {
        'CARGO_HOME': '/home/runner/.cargo/',
        'RUSTUP_HOME': '/home/runner/.rustup',
      },
      workspaceRoot: temp.uri,
    );
    final flags = env['CARGO_ENCODED_RUSTFLAGS']!.split('\x1f');
    final rootPath = temp.path.replaceFirst(RegExp(r'[/\\]+$'), '');
    expect(flags, [
      '--remap-path-prefix=/home/runner/.cargo=/cargo',
      '--remap-path-prefix=/home/runner/.rustup=/rustup',
      '--remap-path-prefix=$rootPath=/workspace',
      '-C',
      'link-arg=-Wl,-z,max-page-size=16384',
    ]);
  });

  test('falls back to HOME and preserves existing RUSTFLAGS', () {
    final env = rustCargoEnvironment(
      code(OS.android, architecture: Architecture.arm),
      processEnvironment: const {
        'HOME': '/home/vagrant',
        'RUSTFLAGS': '-C target-feature=+neon',
      },
    );
    final flags = env['CARGO_ENCODED_RUSTFLAGS']!.split('\x1f');
    expect(flags, [
      '-C',
      'target-feature=+neon',
      '--remap-path-prefix=/home/vagrant/.cargo=/cargo',
      '--remap-path-prefix=/home/vagrant/.rustup=/rustup',
    ]);
  });
}
