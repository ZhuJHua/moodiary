import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final code = input.config.code;
    // Apple 部署目标由 hook 从 input.config 映射给工具链——hooks_runner 用环境白名单运行
    // hook（*_DEPLOYMENT_TARGET 进不来），native_toolchain_rust 又漏了这一步。不映射的话
    // rustc 按三元组默认（iOS 10.0）链接，Xcode 26 SDK 下会因 ___chkstk_darwin 直接链接失败。
    // 这个库没有 cmake 那条链（typst / docx-rs 全是纯 Rust），Android 不需要额外变量。
    final env = switch (code.targetOS) {
      OS.iOS => {'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0'},
      OS.macOS => {'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0'},
      _ => const <String, String>{},
    };
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: env,
    ).run(input: input, output: output);
    // native_toolchain_rust 只把 crate 自己的 src 文件（cargo dep-info）登记为依赖：
    // 改了 Cargo.toml / Cargo.lock（换依赖、换 [patch]、改 profile）钩子不会重跑，
    // hooks_runner 会一直复用上一份 .so。显式登记这两个文件把这条路堵上。
    output.dependencies.addAll([
      input.packageRoot.resolve('rust/Cargo.toml'),
      input.packageRoot.resolve('rust/Cargo.lock'),
    ]);
  });
}
