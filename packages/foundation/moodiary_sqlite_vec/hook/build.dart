import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final builder = CBuilder.library(
      name: 'sqlite_vec',
      assetName: 'src/bindings.dart',
      sources: ['src/sqlite-vec.c'],
      includes: ['src'],
      flags: [
        if (input.config.code.targetOS == OS.android)
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
