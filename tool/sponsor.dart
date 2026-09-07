import 'dart:io';

const _base = 'develop';
const _start = '<!-- sponsors:start -->';
const _end = '<!-- sponsors:end -->';

final _readmes = {File('README.md'): ', ', File('README.zh.md'): '、'};

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

/// `@name` 渲染成 GitHub 链接，其余按昵称原样展示。
String _render(String raw) {
  final name = raw.startsWith('@') ? raw.substring(1) : null;
  return name == null ? raw : '[$name](https://github.com/$name)';
}

List<String> _listOf(File file) {
  final src = file.readAsStringSync();
  final s = src.indexOf(_start);
  final e = src.indexOf(_end);
  if (s == -1 || e == -1 || e < s)
    _fail('${file.path} 里找不到 $_start / $_end 标记');
  final body = src.substring(s + _start.length, e).trim();
  return body.isEmpty
      ? const []
      : body
            .split(RegExp(r',\s*|、'))
            .map((x) => x.trim())
            .where((x) => x.isNotEmpty)
            .toList();
}

void _append(File file, String separator, List<String> entries) {
  final src = file.readAsStringSync();
  final s = src.indexOf(_start) + _start.length;
  final e = src.indexOf(_end);
  final current = src.substring(s, e).trim();
  final added = entries.join(separator);
  final next = current.isEmpty ? added : '$current$separator$added';
  file.writeAsStringSync('${src.substring(0, s)}\n$next\n${src.substring(e)}');
}

String _slug(List<String> raws) {
  final s = raws
      .map((x) => x.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-'))
      .join('-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '')
      .toLowerCase();
  if (s.isNotEmpty) return s.length > 40 ? s.substring(0, 40) : s;
  return DateTime.now()
      .toIso8601String()
      .substring(0, 16)
      .replaceAll(RegExp(r'[-:T]'), '');
}

Future<void> _preflight() async {
  await _requireTool('git');
  await _requireTool('gh');

  if ((await _capture('git', ['status', '--porcelain'])).isNotEmpty) {
    _fail('工作区不干净，请先提交或清理');
  }
  await _run('git', ['fetch', 'origin', _base]);
}

Future<void> main(List<String> argv) async {
  final args = argv.where((a) => a != '--').toList();
  final yes = args.remove('--yes');
  if (args.isEmpty) {
    stdout.writeln(
      '用法：dart tool/sponsor.dart <@github 用户名 | 昵称> [更多...] [--yes]',
    );
    exit(2);
  }

  final entries = args.map(_render).toList();
  final existing = _listOf(_readmes.keys.first);
  final duplicated = entries.where(existing.contains).toList();
  if (duplicated.isNotEmpty) _fail('已在名单里：${duplicated.join(', ')}');

  await _preflight();

  final branch = 'chore/sponsor-${_slug(args)}';
  await _run('git', ['switch', '-c', branch, 'origin/$_base']);
  _readmes.forEach((file, separator) => _append(file, separator, entries));
  await _run('git', [
    '--no-pager',
    'diff',
    '--',
    ..._readmes.keys.map((f) => f.path),
  ]);

  if (!yes) {
    stdout.writeln('\n以上是将要提交的改动，回车继续，Ctrl-C 中止（改动会留在分支 $branch）。');
    stdin.readLineSync();
  }

  final title = 'chore(readme): add sponsor ${args.join(', ')}';
  await _run('git', ['add', ..._readmes.keys.map((f) => f.path)]);
  await _run('git', ['commit', '-m', '$title [skip ci]']);
  await _run('git', ['push', '-u', 'origin', branch]);
  await _run('gh', [
    'pr',
    'create',
    '--base',
    _base,
    '--head',
    branch,
    '--title',
    title,
    '--body',
    '更新捐助者名单。',
  ]);

  stdout.writeln('\n完成。PR 已创建（不跑 CI），人工合并即可。');
}
