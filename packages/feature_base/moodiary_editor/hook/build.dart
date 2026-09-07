import 'dart:io';

import 'package:hooks/hooks.dart';

const _sourceFiles = [
  'index.html',
  'package.json',
  'pnpm-lock.yaml',
  'pnpm-workspace.yaml',
  'tsconfig.json',
  'vite.config.ts',
];

void main(List<String> args) async {
  await build(args, (input, output) async {
    final editorDir = input.packageRoot.resolve('editor/');
    final lockFile = File.fromUri(
      input.packageRoot.resolve('.dart_tool/editor_build.lock'),
    )..createSync(recursive: true);
    final lock = await lockFile.open(mode: FileMode.write);
    await lock.lock(FileLock.blockingExclusive);
    try {
      await _pnpm(['install', '--frozen-lockfile'], editorDir);
      await _pnpm(['build'], editorDir);
    } finally {
      await lock.unlock();
      await lock.close();
    }
    output.dependencies.addAll([
      for (final name in _sourceFiles) editorDir.resolve(name),
      ...Directory.fromUri(editorDir.resolve('src/'))
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.uri),
    ]);
  });
}

Future<void> _pnpm(List<String> args, Uri cwd) async {
  final ProcessResult result;
  try {
    result = await Process.run('corepack', [
      'pnpm',
      ...args,
    ], workingDirectory: cwd.toFilePath());
  } on ProcessException {
    throw StateError(
      'corepack not found on PATH; the editor web bundle is built by this hook. '
      'Install it with `npm i -g corepack` or `brew install corepack`.',
    );
  }
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw StateError(
      '`corepack pnpm ${args.join(' ')}` failed in ${cwd.toFilePath()}',
    );
  }
}
