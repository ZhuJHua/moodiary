import 'dart:convert';
import 'dart:io';

const _base = 'develop';
final _pubspec = File('mobile/pubspec.yaml');

Never _fail(String message) {
  stderr.writeln('✗ $message');
  exit(1);
}

Future<String> _capture(
  String cmd,
  List<String> args, {
  bool check = true,
}) async {
  final r = await Process.run(cmd, args, runInShell: Platform.isWindows);
  if (check && r.exitCode != 0) {
    stderr.write(r.stderr);
    _fail('${[cmd, ...args].join(' ')} 失败');
  }
  return (r.stdout as String).trim();
}

Future<void> _run(String cmd, List<String> args) async {
  stdout.writeln('\$ ${[cmd, ...args].join(' ')}');
  final proc = await Process.start(
    cmd,
    args,
    mode: .inheritStdio,
    runInShell: Platform.isWindows,
  );
  final code = await proc.exitCode;
  if (code != 0) _fail('${[cmd, ...args].join(' ')} 退出码 $code');
}

Future<void> _requireTool(String name) async {
  try {
    final r = await Process.run(name, [
      '--version',
    ], runInShell: Platform.isWindows);
    if (r.exitCode != 0) _fail('$name 不可用');
  } catch (_) {
    _fail('找不到 $name，请先安装');
  }
}

({int major, int minor, int patch}) _parse(String v) {
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(v);
  if (m == null) _fail('版本号格式不对：$v（应为 X.Y.Z）');
  return (
    major: int.parse(m[1]!),
    minor: int.parse(m[2]!),
    patch: int.parse(m[3]!),
  );
}

Future<void> _preflight() async {
  await _requireTool('git');
  await _requireTool('gh');
  await _requireTool('git-cliff');

  final branch = await _capture('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch != _base) _fail('当前在 $branch，请切到 $_base 再执行');

  if ((await _capture('git', ['status', '--porcelain'])).isNotEmpty) {
    _fail('工作区不干净，请先提交或清理');
  }

  await _run('git', ['fetch', 'origin', _base, '--tags']);
  final local = await _capture('git', ['rev-parse', 'HEAD']);
  final remote = await _capture('git', ['rev-parse', 'origin/$_base']);
  if (local != remote) _fail('$_base 与 origin/$_base 不一致，请先 pull/push');
}

Future<void> main(List<String> argv) async {
  final args = argv.where((a) => a != '--').toList();
  final yes = args.remove('--yes');
  final bumpIndex = args.indexOf('--bump');
  String? bump;
  if (bumpIndex != -1) {
    if (bumpIndex + 1 >= args.length) _fail('--bump 需要 patch / minor / major');
    bump = args[bumpIndex + 1];
    args.removeRange(bumpIndex, bumpIndex + 2);
  }
  final explicit = args.isEmpty ? null : args.first;
  if (explicit == null && bump == null) {
    stdout.writeln(
      '用法：dart tool/release.dart <X.Y.Z> | --bump patch|minor|major [--yes]',
    );
    exit(2);
  }

  await _preflight();

  final source = _pubspec.readAsStringSync();
  final versionLine = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(source);
  if (versionLine == null) _fail('读不出 ${_pubspec.path} 里的 version');
  final current = versionLine[1]!;
  final build = int.parse(versionLine[2]!);

  final String next;
  if (explicit != null) {
    next = explicit.startsWith('v') ? explicit.substring(1) : explicit;
    _parse(next);
  } else {
    final c = _parse(current);
    next = switch (bump) {
      'patch' => '${c.major}.${c.minor}.${c.patch + 1}',
      'minor' => '${c.major}.${c.minor + 1}.0',
      'major' => '${c.major + 1}.0.0',
      _ => _fail('--bump 只接受 patch / minor / major'),
    };
  }
  final nextBuild = build + 1;
  final branch = 'release/$next';

  final lastTag = await _capture('git', [
    'describe',
    '--tags',
    '--abbrev=0',
    '--match=v*',
  ]);
  stdout.writeln(
    '\n发版 $current+$build → $next+$nextBuild（changelog 范围 $lastTag..HEAD）\n',
  );

  if ((await _capture('git', ['tag', '--list', 'v$next'])).isNotEmpty) {
    _fail('tag v$next 已存在');
  }

  await _run('git', ['switch', '-c', branch]);

  _pubspec.writeAsStringSync(
    source.replaceFirst(versionLine[0]!, 'version: $next+$nextBuild'),
  );
  stdout.writeln('已写入 ${_pubspec.path}: version: $next+$nextBuild');

  await _run('git-cliff', [
    '--config',
    'cliff.toml',
    '$lastTag..HEAD',
    '--tag',
    'v$next',
    '--prepend',
    'CHANGELOG.md',
  ]);

  if (!yes) {
    stdout.writeln(
      '\nCHANGELOG.md 的 [$next] 节已生成，现在人工审阅删噪音条目。'
      '\n改好后回到这里回车继续，Ctrl-C 中止（分支 $branch 会留在本地）。',
    );
    stdin.readLineSync();
  }

  await _run('git', ['add', 'CHANGELOG.md', _pubspec.path]);
  await _run('git', ['commit', '-m', 'chore(release): $next']);
  await _run('git', ['push', '-u', 'origin', branch]);

  final notes = LineSplitter()
      .convert(File('CHANGELOG.md').readAsStringSync())
      .skipWhile((l) => !l.startsWith('## [$next]'))
      .skip(1)
      .takeWhile((l) => !l.startsWith('## ['))
      .join('\n')
      .trim();

  final body = File('${Directory.systemTemp.path}/release-$next.md')
    ..writeAsStringSync('$notes\n');
  await _run('gh', [
    'pr',
    'create',
    '--base',
    _base,
    '--head',
    branch,
    '--title',
    'chore(release): $next',
    '--body-file',
    body.path,
  ]);
  await _run('gh', ['workflow', 'run', 'build.yml', '--ref', branch]);

  stdout.writeln('''

完成。接下来：
  1. CI 正在从 $branch 构建 APK，并建一个 v$next 的 draft release
     gh run watch
  2. 检查 draft release 与 APK 没问题后，合并这个 PR（squash）
     合并会自动把 draft 转正、打 tag v$next 并推 Telegram
''');
}
