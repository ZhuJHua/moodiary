// 跨平台开发任务入口（替代 Makefile —— `make` 在 Windows 上默认不可用）。
//
// 用法：dart tool/task.dart <command> [-- extra args...]
//   dart tool/task.dart setup            # 构建 editor + flutter pub get
//   dart tool/task.dart run              # 构建 editor + flutter run
//   dart tool/task.dart build-apk        # 同理 build-ios（桌面端构建后续在 desktop/ 内提供）
//   dart tool/task.dart analyze          # 分层检查 + flutter analyze
//   dart tool/task.dart check-layers     # 仅分层依赖检查
//   dart tool/task.dart deps             # 工作区依赖图（Mermaid；--pub 看第三方声明分布）
//   dart tool/task.dart build-runner     # 代码生成
//   dart tool/task.dart i18n             # slang 文案生成（moodiary_i18n + mui）
//   dart tool/task.dart licenses         # 第三方许可清单（Rust crates + 编辑器 npm）
//   dart tool/task.dart clean            # 删除 editor 构建产物
//
// 用 `dart`（非 `dart run`）调用本脚本可跳过 flutter_rust_bridge 的原生构建钩子。
import 'dart:io';

/// 跑一个子进程，继承 stdio；非零退出码直接终止。Windows 下走 shell 以解析 .bat/.cmd 包装器。
/// 本机装了 fvm 就用它钉住 SDK（.fvmrc 是仓库契约）；CI 上没有则回落裸 flutter。
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

// Flutter / Dart-app commands operate on the mobile app package (mobile/); the
// editor build, the layer check and this script itself run from the repo root.
Future<void> _flutter(List<String> args) =>
    _run('fvm', ['flutter', ...args], cwd: 'mobile');

/// 命令是否在 PATH 上。
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
  await _run('corepack', [
    'pnpm',
    'install',
  ], cwd: 'packages/feature_base/moodiary_editor/editor');
  await _run('corepack', [
    'pnpm',
    'build',
  ], cwd: 'packages/feature_base/moodiary_editor/editor');
}

const _rustPkgDir = 'packages/foundation/moodiary_rust';

/// CLI 是整条链上唯一不由仓库钉版本的东西，而它默认开着 auto_upgrade_dependency ——
/// 版本不一致时会反过来把 Cargo.toml / pubspec.yaml / lock 的钉版本改成它自己的。
Future<void> _assertCodegenVersion() async {
  final pinned = RegExp(
    r'^\s*flutter_rust_bridge:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(File('$_rustPkgDir/pubspec.yaml').readAsStringSync())?.group(1);
  if (pinned == null) {
    stderr.writeln('✗ 读不到 $_rustPkgDir/pubspec.yaml 里的 flutter_rust_bridge 版本');
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

const _genRustOutDir = '$_rustPkgDir/lib/src/rust';

/// ffigen 21 起会给每个结构体生成 `$allocate`，它的具名参数列表自带一层 `{}`。
/// FRB **2.13.0 之前**剥离 WireSyncRust2DartSse 用的是非贪婪正则（`.*?\}`），会止于那层
/// 内括号、把类头吃掉留下半截函数体，且 codegen 照样 exit 0。2.13.0 换成了按括号配对的
/// `remove_dart_class`，并带上以此命名的回归测试，所以 21 从这版起可用。
/// 上界留着只是因为 22 没验过 —— 不是已知坏。
const _ffigenMin = 8;
const _ffigenMaxExclusive = 22;

/// 从根 lock 读实际解析到的 ffigen 版本（workspace 下 dev 依赖记在根 lock 里）。
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

/// 产出坏绑定时 codegen 不会失败，所以 ffigen 只放行验过的大版本区间。
void _assertFfigenVersion(String version) {
  final major = int.tryParse(version.split('.').first);
  if (major == null || major < _ffigenMin || major >= _ffigenMaxExclusive) {
    stderr.writeln(
      '✗ ffigen 版本未验证：解析到 $version，需要 >=$_ffigenMin.0.0 且 <$_ffigenMaxExclusive.0.0。\n'
      '  产出坏绑定时 codegen 仍会 exit 0，所以这里只放行验过的区间。\n'
      '  请把 $_rustPkgDir/pubspec.yaml 的 ffigen 钉回区间内后重跑 flutter pub get。',
    );
    exit(1);
  }
}

/// FRB 走 `flutter pub run ffigen`，用的是 .dart_tool/pub/bin/ffigen 里的预编译快照；
/// 换 ffigen 版本后 pub get 不一定让它失效，会拿旧快照静默跑出「看着没问题」的产物。
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

/// 重新生成 Rust FFI 绑定（从包内运行）。
Future<void> _genRust() async {
  await _assertCodegenVersion();
  final ffigen = _resolvedFfigenVersion();
  _assertFfigenVersion(ffigen);
  _clearStaleFfigenSnapshot(ffigen);
  await _run('flutter_rust_bridge_codegen', ['generate'], cwd: _rustPkgDir);
  // 2.13.0 起 codegen 自己那趟 rustfmt 不带 style_edition，产物是 2015 风格，
  // 与 workspace 的 2024 对不上，`cargo fmt --check` 会红。补跑一次。
  await _run('cargo', ['fmt', '--all'], cwd: '$_rustPkgDir/rust');
  // codegen 产出坏文件时依然 exit 0 并打印 Done!，只能自己验一遍。
  await _run('fvm', ['dart', 'analyze', _genRustOutDir]);
}

Future<void> _checkLayers() => _run('fvm', ['dart', 'tool/check_layers.dart']);

/// slang 的两处文案：App 的在 moodiary_i18n，mui 组件自己那十来个通用词在 mui。
/// 不走 build_runner —— slang 的 CLI 是毫秒级的，塞进 build_runner 只会拖慢每次代码生成。
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
  // 分层依赖检查（上层依赖下层，同层不互引）+ flutter analyze
  'analyze': (_) async {
    await _run('dart', ['tool/check_generated.dart']);
    await _checkLayers();
    await _run('fvm', ['flutter', 'analyze']);
  },
  'check-layers': (_) => _checkLayers(),
  'deps': (rest) => _run('fvm', ['dart', 'tool/dep_graph.dart', ...rest]),
  // 全仓测试（CI 口径）。flutter 经 fvm 定位：裸 `dart tool/task.dart test` 启动时
  // PATH 上未必是钉住的 SDK（fvm dart 启动才会前置），跑错版本还毫无提示——这条
  // 命令的卖点恰恰是「与 CI 一致」；CI（无 fvm）回落裸 flutter，两端语义等价。
  // 真库集成测试（倒排索引 / 迁移）要 ISAR_TEST_DYLIB，见 diary_index_test 文件头。
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
  // 只跑 mobile/ 的测试（旧 `test` 的行为）。
  'test-mobile': (rest) => _flutter(['test', ...rest]),
  // build_runner 2.16.0 移除了 --delete-conflicting-outputs（默认行为已内建）。
  // 必须全仓扫：生成物散在各包（injectable 的 *.module.dart、freezed/riverpod 的
  // *.g.dart），只跑 mobile 会让包侧注解改动静默不生效——旧生成物照样编译，
  // 漂移只在运行时暴露。
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
    // injectable 的 micro-package 产物（*.module.dart）出炉不带格式，
    // 统一补一道，保住全仓 format 零差异闸门。
    await _run('fvm', ['dart', 'format', '.']);
  },
  // 代码生成：Rust FFI 绑定 / slang 文案；`gen` = 三者 + 编辑器资源（melos bootstrap 的 post hook）。
  'gen-rust': (_) => _genRust(),
  'i18n': (_) => _i18n(),
  // 第三方许可清单（Rust + npm）。pub 那份由 flutter tool 自己收，不在这里。
  // npm 那半是编辑器构建的产物（rollup-plugin-license），所以先构建再合并。
  'licenses': (_) async {
    await _editor();
    await _run('fvm', ['dart', 'run', 'tool/licenses.dart']);
  },
  'gen': (_) async {
    await _genRust();
    await _i18n();
    await _editor();
  },
  'clean': (_) async {
    final dir = Directory(
      'packages/feature_base/moodiary_editor/assets/editor',
    );
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      stdout.writeln(
        '已删除 packages/feature_base/moodiary_editor/assets/editor/',
      );
    } else {
      stdout.writeln(
        'packages/feature_base/moodiary_editor/assets/editor/ 不存在，跳过。',
      );
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
