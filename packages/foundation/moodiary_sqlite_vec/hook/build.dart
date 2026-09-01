import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // loadable 扩展：不定义 SQLITE_CORE，sqlite3ext.h 走宿主函数表，
    // 由 Dart 侧经 sqlite3_auto_extension 注册进 sqlite3 包自带的 SQLite。
    final builder = CBuilder.library(
      name: 'sqlite_vec',
      assetName: 'src/bindings.dart',
      sources: ['src/sqlite-vec.c'],
      includes: ['src'],
      flags: [
        if (input.config.code.targetOS == OS.android)
          // Android 15+ 的 16KB page 设备要求 .so 段按 16KB 对齐。
          '-Wl,-z,max-page-size=16384',
      ],
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger.detached('moodiary_sqlite_vec')
        ..level = Level.ALL
        ..onRecord.listen((r) => print(r.message)),
    );
  });
}
