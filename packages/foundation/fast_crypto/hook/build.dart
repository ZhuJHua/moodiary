import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // buildCodeAssets 为 false 时 input.config.code 访问即抛
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    // *_DEPLOYMENT_TARGET 进不了 hooks_runner 环境白名单，不映射会按默认三元组链接，Xcode 26 下 ___chkstk_darwin 链接失败
    final env = switch (code.targetOS) {
      OS.iOS => {'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0'},
      OS.macOS => {'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0'},
      _ => const <String, String>{},
    };
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: env,
    ).run(input: input, output: output);
    // native_toolchain_rust 只登记 crate 自身 src 为依赖，显式加 Cargo.toml/lock 防止改依赖后钩子不重跑
    output.dependencies.addAll([
      input.packageRoot.resolve('rust/Cargo.toml'),
      input.packageRoot.resolve('rust/Cargo.lock'),
    ]);
  });
}
