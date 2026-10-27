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
    IOSSdk sdk = IOSSdk.iPhoneOS,
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
              ? IOSCodeConfig(targetSdk: sdk, targetVersion: 15)
              : null,
          macOS: os == OS.macOS ? MacOSCodeConfig(targetVersion: 12) : null,
          android: os == OS.android
              ? AndroidCodeConfig(targetNdkApi: 24)
              : null,
        ),
      );
    builder.config.setupBuild(linkingEnabled: false);
    return builder.build().config.code;
  }

  test('iOS device keeps the deployment target', () {
    expect(rustCargoEnvironment(code(OS.iOS)), {
      'IPHONEOS_DEPLOYMENT_TARGET': '15.0',
    });
  });

  for (final architecture in [Architecture.arm64, Architecture.x64]) {
    test('iOS $architecture simulator needs no SDKROOT', () {
      expect(
        rustCargoEnvironment(
          code(OS.iOS, architecture: architecture, sdk: IOSSdk.iPhoneSimulator),
        ),
        {'IPHONEOS_DEPLOYMENT_TARGET': '15.0'},
      );
    });
  }

  test('macOS keeps the deployment target', () {
    expect(rustCargoEnvironment(code(OS.macOS)), {
      'MACOSX_DEPLOYMENT_TARGET': '12.0',
    });
  });

  for (final (architecture, target) in [
    (Architecture.arm64, 'AARCH64_LINUX_ANDROID'),
    (Architecture.arm, 'ARMV7_LINUX_ANDROIDEABI'),
    (Architecture.x64, 'X86_64_LINUX_ANDROID'),
  ]) {
    test('Android $architecture uses 16 KB pages without CMake', () {
      expect(
        rustCargoEnvironment(code(OS.android, architecture: architecture)),
        {
          'CARGO_TARGET_${target}_RUSTFLAGS':
              '-C link-arg=-Wl,-z,max-page-size=16384',
        },
      );
    });
  }

  test('Android arm64 adds CMake without dropping the 16 KB flag', () {
    final ndkRoot = temp.uri.resolve('ndk/');
    expect(rustCargoEnvironment(code(OS.android), androidNdkRoot: ndkRoot), {
      'CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS':
          '-C link-arg=-Wl,-z,max-page-size=16384',
      'CMAKE_TOOLCHAIN_FILE_aarch64_linux_android': ndkRoot
          .resolve('build/cmake/android.toolchain.cmake')
          .toFilePath(),
      'ANDROID_NDK_ROOT': Directory.fromUri(ndkRoot).path,
    });
  });

  test('unsupported Android architectures still throw', () {
    expect(
      () => rustCargoEnvironment(
        code(OS.android, architecture: Architecture.ia32),
      ),
      throwsUnsupportedError,
    );
  });

  test('other platforms need no extra environment', () {
    expect(rustCargoEnvironment(code(OS.linux)), isEmpty);
  });
}
