import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final code = input.config.code;
    // Apple 部署目标由 hook 从 input.config 映射给工具链——hooks_runner 用环境白名单运行
    // hook（*_DEPLOYMENT_TARGET 进不来），native_toolchain_rust 又漏了这一步。不映射的话
    // rustc 按三元组默认（iOS 10.0）链接，Xcode 26 SDK 下会因 ___chkstk_darwin 直接链接失败。
    // ring 的 C 部分走 cc，CC / AR 由 native_toolchain_rust 按目标注入，Android 不需要额外变量。
    final env = switch (code.targetOS) {
      OS.iOS => {'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0'},
      OS.macOS => {'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0'},
      _ => const <String, String>{},
    };
    // assetName 就是写 `@Native` 声明的那个库文件：它的 `package:` URI 即 code asset 的 id。
    await RustBuilder(
      assetName: 'src/ffi.dart',
      cratePath: 'rust',
      extraCargoEnvironmentVariables: env,
    ).run(input: input, output: output);
  });
}
