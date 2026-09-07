import 'dart:convert';
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

Future<List<String>> _capture(String cmd, List<String> args) async {
  final r = await Process.run(cmd, args, runInShell: Platform.isWindows);
  if (r.exitCode != 0) {
    stderr.write(r.stderr);
    exit(r.exitCode);
  }
  return const LineSplitter().convert(r.stdout as String);
}

Future<List<String>?> _affectedPackages(String ref) async {
  final changed = {
    ...await _capture('git', ['diff', '--name-only', ref]),
    ...await _capture('git', ['ls-files', '--others', '--exclude-standard']),
  }.where((f) => f.isNotEmpty).toList();
  if (changed.any((f) => f == 'pubspec.yaml' || f == 'pubspec.lock')) {
    stdout.writeln('根 pubspec 有改动，测试全仓。');
    return null;
  }

  final root = Directory.current.path;
  final packages = (jsonDecode(
    (await _capture('melos', ['list', '--json'])).join(),
  ) as List).cast<Map<String, dynamic>>();
  final graph =
      (jsonDecode((await _capture('melos', ['list', '--graph'])).join())
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as List).cast<String>()));

  final byDir = {
    for (final p in packages)
      '${(p['location'] as String).substring(root.length + 1)}/':
          p['name'] as String,
  };
  final direct = <String>{};
  for (final f in changed) {
    for (final e in byDir.entries) {
      if (f.startsWith(e.key)) direct.add(e.value);
    }
  }

  final affected = {...direct};
  var grew = true;
  while (grew) {
    grew = false;
    for (final e in graph.entries) {
      if (!affected.contains(e.key) && e.value.any(affected.contains)) {
        affected.add(e.key);
        grew = true;
      }
    }
  }
  final result = affected.toList()..sort();
  stdout.writeln(
    '改动的包：${direct.isEmpty ? '无' : (direct.toList()..sort()).join(', ')}\n'
    '受影响的包（含依赖方）：${result.isEmpty ? '无' : result.join(', ')}',
  );
  return result;
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
  'setup': (_) async {
    await _flutter(['pub', 'get']);
  },
  'run': (rest) async {
    await _flutter(['run', ...rest]);
  },
  'build-apk': (rest) async {
    await _flutter(['build', 'apk', ...rest]);
  },
  'build-ios': (rest) async {
    await _flutter(['build', 'ios', ...rest]);
  },
  'analyze': (_) async {
    await _run('dart', ['tool/check_generated.dart']);
    await _checkLayers();
    await _run('fvm', ['flutter', 'analyze']);
  },
  'check-layers': (_) => _checkLayers(),
  'deps': (rest) => _run('fvm', ['dart', 'tool/dep_graph.dart', ...rest]),
  'test': (rest) async {
    var all = false;
    var diff = 'HEAD';
    final flutterArgs = <String>[];
    for (final a in rest) {
      if (a == '--all') {
        all = true;
      } else if (a.startsWith('--diff=')) {
        diff = a.substring('--diff='.length);
      } else {
        flutterArgs.add(a);
      }
    }
    final scopes = all ? null : await _affectedPackages(diff);
    if (scopes != null && scopes.isEmpty) {
      stdout.writeln('相对 $diff 没有受影响的包，跳过测试。');
      return;
    }
    await _run('melos', [
      'exec',
      '--dir-exists=test',
      '--fail-fast',
      if (scopes != null)
        for (final s in scopes) '--scope=$s',
      '-c',
      '1',
      '--',
      if (_hasFvm) 'fvm',
      'flutter',
      'test',
      ...flutterArgs,
    ]);
  },
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
  'gen': (_) async {
    await _genRust();
    await _i18n();
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
