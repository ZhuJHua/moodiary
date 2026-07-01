// 跨平台开发任务入口（替代 Makefile —— `make` 在 Windows 上默认不可用）。
//
// 用法：dart tool/task.dart <command> [-- extra args...]
//   dart tool/task.dart setup            # 构建 editor + flutter pub get
//   dart tool/task.dart run              # 构建 editor + flutter run
//   dart tool/task.dart build-apk        # 同理 build-ios / build-windows / build-macos
//   dart tool/task.dart analyze          # 分层检查 + flutter analyze
//   dart tool/task.dart check-layers     # 仅分层依赖检查
//   dart tool/task.dart build-runner     # 代码生成
//   dart tool/task.dart clean            # 删除 editor 构建产物
//
// 用 `dart`（非 `dart run`）调用本脚本可跳过 flutter_rust_bridge 的原生构建钩子。
import 'dart:io';

/// 跑一个子进程，继承 stdio；非零退出码直接终止。Windows 下走 shell 以解析 .bat/.cmd 包装器。
Future<void> _run(String cmd, List<String> args, {String? cwd}) async {
  stdout.writeln('\$ ${[cmd, ...args].join(' ')}${cwd != null ? '  (cwd: $cwd)' : ''}');
  final proc = await Process.start(
    cmd,
    args,
    workingDirectory: cwd,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final code = await proc.exitCode;
  if (code != 0) exit(code);
}

// Flutter / Dart-app commands operate on the mobile app package (mobile/); the
// editor build, the layer check and this script itself run from the repo root.
Future<void> _flutter(List<String> args) =>
    _run('fvm', ['flutter', ...args], cwd: 'mobile');
Future<void> _dartApp(List<String> args) =>
    _run('fvm', ['dart', ...args], cwd: 'mobile');

/// 命令是否在 PATH 上。
Future<bool> _hasCommand(String cmd) async {
  try {
    final r = await Process.run(
      Platform.isWindows ? 'where' : 'which',
      [cmd],
      runInShell: Platform.isWindows,
    );
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// 构建 editor web 资源（多数任务的前置）。pnpm 由 Corepack 提供（版本固定于
/// editor/package.json 的 packageManager 字段），无需全局安装 pnpm。
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
  await _run('corepack', ['pnpm', 'install'], cwd: 'packages/product/moodiary_editor/editor');
  await _run('corepack', ['pnpm', 'build'], cwd: 'packages/product/moodiary_editor/editor');
}

/// 重新生成 Rust FFI 绑定（从包内运行；codegen CLI 版本须与库版本一致）。
Future<void> _genRust() =>
    _run('flutter_rust_bridge_codegen', ['generate'], cwd: 'packages/foundation/moodiary_rust');

Future<void> _checkLayers() => _run('fvm', ['dart', 'tool/check_layers.dart']);

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
  'build-windows': (rest) async {
    await _editor();
    await _flutter(['build', 'windows', ...rest]);
  },
  'build-macos': (rest) async {
    await _editor();
    await _flutter(['build', 'macos', ...rest]);
  },
  // 分层依赖检查（上层依赖下层，同层不互引）+ flutter analyze
  'analyze': (_) async {
    await _checkLayers();
    await _flutter(['analyze']);
  },
  'check-layers': (_) => _checkLayers(),
  'test': (rest) => _flutter(['test', ...rest]),
  'build-runner': (_) =>
      _dartApp(['run', 'build_runner', 'build', '--delete-conflicting-outputs']),
  // 代码生成：Rust FFI 绑定；`gen` = 绑定 + 编辑器资源（melos bootstrap 的 post hook）。
  'gen-rust': (_) => _genRust(),
  'gen': (_) async {
    await _genRust();
    await _editor();
  },
  'clean': (_) async {
    final dir = Directory('packages/product/moodiary_editor/assets/editor');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      stdout.writeln('已删除 packages/product/moodiary_editor/assets/editor/');
    } else {
      stdout.writeln('packages/product/moodiary_editor/assets/editor/ 不存在，跳过。');
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
  // `--` 之后的参数透传给底层 flutter（如 dart tool/task.dart run -- --release）。
  final rest = argv.skip(1).where((a) => a != '--').toList();
  await task(rest);
}
