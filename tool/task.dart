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

Future<void> _flutter(List<String> args, {String? cwd = 'mobile'}) => _hasFvm
    ? _run('fvm', ['flutter', ...args], cwd: cwd)
    : _run('flutter', args, cwd: cwd);

Future<List<String>> _capture(String cmd, List<String> args) async {
  final r = await Process.run(cmd, args, runInShell: Platform.isWindows);
  if (r.exitCode != 0) {
    stderr.write(r.stderr);
    exit(r.exitCode);
  }
  return const LineSplitter().convert(r.stdout as String);
}

Future<String> _branchBase() async {
  final r = await Process.run('git', ['merge-base', 'origin/develop', 'HEAD']);
  if (r.exitCode != 0) return 'HEAD';
  return (r.stdout as String).trim();
}

Future<Map<String, String>> _packageDirs() async {
  final root = Directory.current.path;
  final packages = (jsonDecode(
    (await _capture('melos', ['list', '--json'])).join(),
  ) as List).cast<Map<String, dynamic>>();
  return {
    for (final p in packages)
      p['name'] as String: (p['location'] as String).substring(root.length + 1),
  };
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

  final dirs = await _packageDirs();
  final graph =
      (jsonDecode((await _capture('melos', ['list', '--graph'])).join())
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as List).cast<String>()));

  final direct = <String>{};
  for (final f in changed) {
    for (final e in dirs.entries) {
      if (f.startsWith('${e.value}/')) direct.add(e.key);
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
  'packages/foundation/fast_core',
];

const _frbAnchorDir = 'packages/foundation/fast_image';

Future<void> _assertCodegenVersion() async {
  final pinned =
      RegExp(
            r'^\s*flutter_rust_bridge:\s*(\S+)(?:\s+#.*)?\s*$',
            multiLine: true,
          )
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

Future<void> _genRust() async {
  await _assertCodegenVersion();
  for (final dir in _frbPkgDirs) {
    await _run('flutter_rust_bridge_codegen', ['generate'], cwd: dir);
    await _run('cargo', ['fmt', '--all'], cwd: '$dir/rust');
    await _run('fvm', ['dart', 'analyze', '$dir/lib/src/rust']);
  }
}

Future<void> _checkLayers() => _run('fvm', ['dart', 'tool/check_layers.dart']);

const _slangPkgDirs = [
  'packages/core/moodiary_i18n',
  'packages/foundation/mui',
];

const _pigeonPkgDir = 'packages/core/moodiary_native';

Future<void> _pigeon() async {
  final inputs =
      Directory('$_pigeonPkgDir/pigeons').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final input in inputs) {
    await _run('fvm', [
      'dart',
      'run',
      'pigeon',
      '--input',
      'pigeons/${input.uri.pathSegments.last}',
    ], cwd: _pigeonPkgDir);
  }
  await _run('fvm', ['dart', 'format', '$_pigeonPkgDir/lib']);
}

Future<void> _i18n() async {
  for (final dir in _slangPkgDirs) {
    await _run('fvm', ['dart', 'run', 'slang'], cwd: dir);
  }
}

final Map<String, Future<void> Function(List<String> rest)> _tasks = {
  'setup': (rest) async {
    final hasSdkPath =
        rest.any(
          (arg) => arg == '--sdk-path' || arg.startsWith('--sdk-path='),
        ) ||
        (Platform.environment['MELOS_SDK_PATH']?.isNotEmpty ?? false);
    if (!hasSdkPath && !Directory('.fvm/flutter_sdk').existsSync()) {
      stderr.writeln(
        '✗ 找不到 .fvm/flutter_sdk。请先运行 `fvm use` 初始化当前工作区的 Flutter SDK，或通过 `--sdk-path` / `MELOS_SDK_PATH` 指定。',
      );
      exit(1);
    }
    await _run('fvm', [
      'dart',
      'run',
      'melos',
      'bootstrap',
      if (!hasSdkPath) '--sdk-path=.fvm/flutter_sdk',
      ...rest,
    ]);
  },
  'run': (rest) async {
    await _flutter(['run', ...rest]);
  },
  'build-apk': (rest) async {
    final hasFlavor = rest.any(
      (arg) => arg == '--flavor' || arg.startsWith('--flavor='),
    );
    await _flutter([
      'build',
      'apk',
      if (!hasFlavor) ...['--flavor', 'production'],
      ...rest,
    ]);
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
    String? diff;
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
    diff ??= await _branchBase();
    final scopes = all ? null : await _affectedPackages(diff);
    if (scopes != null && scopes.isEmpty) {
      stdout.writeln('相对 $diff 没有受影响的包，跳过测试。');
      return;
    }
    final dirs = await _packageDirs();
    final testDirs = [
      for (final name in (scopes ?? dirs.keys.toList())..sort())
        if (Directory('${dirs[name]}/test').existsSync()) '${dirs[name]}/test',
    ];
    if (testDirs.isEmpty) {
      stdout.writeln('受影响的包里没有测试，跳过。');
      return;
    }
    await _flutter(['test', ...testDirs, ...flutterArgs], cwd: null);
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
  'pigeon': (_) => _pigeon(),
  'migrations': (_) => _run('fvm', [
    'dart',
    'run',
    'drift_dev',
    'make-migrations',
  ], cwd: 'packages/feature_base/moodiary_data'),
  'gen': (_) async {
    await _genRust();
    await _i18n();
    await _pigeon();
  },
  'clean': (_) async {
    for (final path in ['.dart_tool/hooks_runner']) {
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
