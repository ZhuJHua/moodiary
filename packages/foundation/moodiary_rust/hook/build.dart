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
    final env = switch (code.targetOS) {
      OS.iOS => {'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0'},
      OS.macOS => {'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0'},
      _ => const <String, String>{},
    };
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: env,
    ).run(input: input, output: output);
  });
}
