import 'dart:io';

final bool _hasFvm = () {
  try {
    return Process.runSync('fvm', ['--version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}();

Future<void> _run(String cmd, List<String> args, {String? cwd}) async {
  stdout.writeln(
    '\$ ${[cmd, ...args].join(' ')}${cwd != null ? '  (cwd: $cwd)' : ''}',
  );
  final proc = await Process.start(
    cmd,
    args,
    workingDirectory: cwd,
    mode: .inheritStdio,
    runInShell: Platform.isWindows,
  );
  final code = await proc.exitCode;
  if (code != 0) exit(code);
}

Future<void> _flutter(List<String> args) =>
    _run('fvm', ['flutter', ...args], cwd: 'mobile');

Future<bool> _hasCommand(String cmd) async {
  try {
    final r = await Process.run(Platform.isWindows ? 'where' : 'which', [
      cmd,
    ], runInShell: Platform.isWindows);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<void> _editor() async {
  if (!await _hasCommand('corepack')) {
    stderr.writeln(
      '✗ 找不到 corepack（Node ≥25 起不再随 Node 内置）。请先安装后重试：\n'
      '    npm i -g corepack    或    brew install corepack\n'
      '  编辑器构建用 corepack 提供 package.json 中固定版本的 pnpm。',
    );
    exit(1);
  }
  await _run('corepack', ['enable']);
  await _run('corepack', [
    'pnpm',
    'install',
  ], cwd: 'packages/feature_base/moodiary_editor/editor');
  await _run('corepack', [
    'pnpm',
    'build',
  ], cwd: 'packages/feature_base/moodiary_editor/editor');
}

const _frbPkgDirs = [
  'packages/foundation/fast_crypto',
  'packages/foundation/fast_image',
  'packages/foundation/fast_press',
  'packages/foundation/fast_tokenizer',
  'packages/foundation/fast_zip',
  'packages/foundation/moodiary_rust',
];

const _frbAnchorDir = 'packages/foundation/fast_image';

Future<void> _assertCodegenVersion() async {
  final pinned =
      RegExp(r'^\s*flutter_rust_bridge:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(File('$_frbAnchorDir/pubspec.yaml').readAsStringSync())
          ?.group(1);
  if (pinned == null) {
    stderr.writeln(
      '✗ 读不到 $_frbAnchorDir/pubspec.yaml 里的 flutter_rust_bridge 版本',
    );
    exit(1);
  }
  final ProcessResult r;
  try {
    r = await Process.run('flutter_rust_bridge_codegen', [
      '--version',
    ], runInShell: Platform.isWindows);
  } catch (_) {
    stderr.writeln(
      '✗ 找不到 flutter_rust_bridge_codegen。安装与 pubspec 一致的版本：\n'
      '    cargo install flutter_rust_bridge_codegen --version $pinned --locked',
    );
    exit(1);
  }
  final actual = RegExp(r'(\d+\.\S+)')
      .firstMatch('${r.stdout}'.trim())
      ?.group(1);
  if (actual != pinned) {
    stderr.writeln(
      '✗ codegen 版本不一致：CLI = ${actual ?? '未知'}，pubspec 钉的是 $pinned。\n'
      '  直接生成会把仓库里的钉版本改写成 CLI 的版本。请先对齐：\n'
      '    cargo install flutter_rust_bridge_codegen --version $pinned --locked',
    );
    exit(1);
  }
}

const _ffigenMin = 8;
const _ffigenMaxExclusive = 22;

String _resolvedFfigenVersion() {
  final lock = File('pubspec.lock').readAsStringSync();
  final v = RegExp(
    r'^  ffigen:$.*?^    version:\s*"?([^"\s]+)"?$',
    multiLine: true,
    dotAll: true,
  ).firstMatch(lock)?.group(1);
  if (v == null) {
    stderr.writeln('✗ pubspec.lock 里读不到 ffigen 版本，先跑 flutter pub get');
    exit(1);
  }
  return v;
}

void _assertFfigenVersion(String version) {
  final major = int.tryParse(version.split('.').first);
  if (major == null || major < _ffigenMin || major >= _ffigenMaxExclusive) {
    stderr.writeln(
      '✗ ffigen 版本未验证：解析到 $version，需要 >=$_ffigenMin.0.0 且 <$_ffigenMaxExclusive.0.0。\n'
      '  产出坏绑定时 codegen 仍会 exit 0，所以这里只放行验过的区间。\n'
      '  请把 $_frbAnchorDir/pubspec.yaml 的 ffigen 钉回区间内后重跑 flutter pub get。',
    );
    exit(1);
  }
}

void _clearStaleFfigenSnapshot(String version) {
  final stamp = File('.dart_tool/moodiary_ffigen_snapshot_version');
  if (stamp.existsSync() && stamp.readAsStringSync().trim() == version) return;
  final dir = Directory('.dart_tool/pub/bin/ffigen');
  if (dir.existsSync()) {
    stdout.writeln('· ffigen 版本变为 $version，清掉旧的预编译快照');
    dir.deleteSync(recursive: true);
  }
  stamp.parent.createSync(recursive: true);
  stamp.writeAsStringSync(version);
}

Future<void> _genRust() async {
  await _assertCodegenVersion();
  final ffigen = _resolvedFfigenVersion();
  _assertFfigenVersion(ffigen);
  _clearStaleFfigenSnapshot(ffigen);
  for (final dir in _frbPkgDirs) {
    await _run('flutter_rust_bridge_codegen', ['generate'], cwd: dir);
    await _run('cargo', ['fmt', '--all'], cwd: '$dir/rust');
    await _run('fvm', ['dart', 'analyze', '$dir/lib/src/rust']);
  }
}

Future<void> _checkLayers() => _run('fvm', ['dart', 'tool/check_layers.dart']);

const _slangPkgDirs = [
  'packages/foundation/moodiary_i18n',
  'packages/foundation/mui',
];

Future<void> _i18n() async {
  for (final dir in _slangPkgDirs) {
    await _run('fvm', ['dart', 'run', 'slang'], cwd: dir);
  }
}

final Map<String, Future<void> Function(List<String> rest)> _tasks = {
  'editor': (_) => _editor(),
  'setup': (_) async {
    await _editor();
    await _flutter(['pub', 'get']);
  },
  'run': (rest) async {
    await _editor();
    await _flutter(['run', ...rest]);
  },
  'build-apk': (rest) async {
    await _editor();
    await _flutter(['build', 'apk', ...rest]);
  },
  'build-ios': (rest) async {
    await _editor();
    await _flutter(['build', 'ios', ...rest]);
  },
  'analyze': (_) async {
    await _run('dart', ['tool/check_generated.dart']);
    await _checkLayers();
    await _run('fvm', ['flutter', 'analyze']);
  },
  'check-layers': (_) => _checkLayers(),
  'deps': (rest) => _run('fvm', ['dart', 'tool/dep_graph.dart', ...rest]),
  'test': (rest) => _run('melos', [
    'exec',
    '--dir-exists=test',
    '--fail-fast',
    '-c',
    '1',
    '--',
    if (_hasFvm) 'fvm',
    'flutter',
    'test',
    ...rest,
  ]),
  'test-mobile': (rest) => _flutter(['test', ...rest]),
  'build-runner': (_) async {
    await _run('melos', [
      'exec',
      '--depends-on=build_runner',
      '-c',
      '1',
      '--',
      'fvm',
      'dart',
      'run',
      'build_runner',
      'build',
    ]);
    await _run('fvm', ['dart', 'format', '.']);
  },
  'gen-rust': (_) => _genRust(),
  'i18n': (_) => _i18n(),
  'licenses': (_) async {
    await _editor();
    await _run('fvm', ['dart', 'run', 'tool/licenses.dart']);
  },
  'sponsors': (_) => _run('fvm', ['dart', 'run', 'tool/sponsors.dart']),
  'social': (_) => _run('fvm', ['dart', 'run', 'tool/social_image.dart']),
  'gen': (_) async {
    await _genRust();
    await _i18n();
    await _editor();
  },
  'clean': (_) async {
    for (final path in [
      'packages/feature_base/moodiary_editor/assets/editor',
      '.dart_tool/hooks_runner',
    ]) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        stdout.writeln('已删除 $path/');
      } else {
        stdout.writeln('$path/ 不存在，跳过。');
      }
    }
  },
};

Future<void> main(List<String> argv) async {
  final cmd = argv.isEmpty ? null : argv.first;
  final task = cmd == null ? null : _tasks[cmd];
  if (task == null) {
    final out = cmd == null ? stdout : stderr;
    if (cmd != null) out.writeln('未知命令：$cmd\n');
    out.writeln('可用命令：');
    for (final k in _tasks.keys) {
      out.writeln('  $k');
    }
    out.writeln('\n用法：dart tool/task.dart <command> [-- extra flutter args]');
    exit(cmd == null ? 0 : 2);
  }
  final rest = argv.skip(1).where((a) => a != '--').toList();
  await task(rest);
}
