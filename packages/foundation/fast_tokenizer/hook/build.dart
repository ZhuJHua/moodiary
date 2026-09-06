import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // buildCodeAssets 为 false 时访问 input.config.code 即抛
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    // hooks_runner 用环境白名单运行 hook，*_DEPLOYMENT_TARGET 进不来；不映射的话 rustc 按默认三元组（iOS 10.0）链接，Xcode 26 SDK 下会因 ___chkstk_darwin 链接失败
    final env = switch (code.targetOS) {
      OS.iOS => {'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0'},
      OS.macOS => {'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0'},
      _ => const <String, String>{},
    };
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: env,
    ).run(input: input, output: output);
    // native_toolchain_rust 不追踪 Cargo.toml / Cargo.lock，改了它们钩子不会重跑，会复用旧 .so
    output.dependencies.addAll([
      input.packageRoot.resolve('rust/Cargo.toml'),
      input.packageRoot.resolve('rust/Cargo.lock'),
    ]);
  });
}
