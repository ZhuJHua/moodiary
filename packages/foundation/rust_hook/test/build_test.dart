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

  CodeConfig code(OS os, {Architecture architecture = Architecture.arm64}) {
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
                  deploymentVersion: AppleVersion(15),
                )
              : null,
          macOS: os == OS.macOS
              ? MacOSCodeConfig(deploymentVersion: AppleVersion(12))
              : null,
          android: os == OS.android
              ? AndroidCodeConfig(targetNdkApi: 24)
              : null,
        ),
      );
    builder.config.setupBuild(linkingEnabled: false);
    return builder.build().config.code;
  }

  test('iOS passes the deployment target', () {
    expect(rustCargoEnvironment(code(OS.iOS)), {
      'IPHONEOS_DEPLOYMENT_TARGET': '15.0',
    });
  });

  test('macOS passes the deployment target', () {
    expect(rustCargoEnvironment(code(OS.macOS)), {
      'MACOSX_DEPLOYMENT_TARGET': '12.0',
    });
  });

  test('Android arm64 points CMake at the NDK toolchain', () {
    final ndkRoot = temp.uri.resolve('ndk/');
    expect(rustCargoEnvironment(code(OS.android), androidNdkRoot: ndkRoot), {
      'CMAKE_TOOLCHAIN_FILE_aarch64_linux_android': ndkRoot
          .resolve('build/cmake/android.toolchain.cmake')
          .toFilePath(),
      'ANDROID_NDK_ROOT': Directory.fromUri(ndkRoot).path,
    });
  });
}
