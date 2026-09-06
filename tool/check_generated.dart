import 'dart:io';

const _frbPkgDirs = [
  'packages/foundation/fast_crypto',
  'packages/foundation/fast_image',
  'packages/foundation/fast_press',
  'packages/foundation/fast_tokenizer',
  'packages/foundation/fast_zip',
  'packages/foundation/moodiary_rust',
];

void main() {
  for (final dir in _frbPkgDirs) {
    _check(dir);
  }
  _checkConsistency();
}

void _check(String pkgDir) {
  String? grab(String path, RegExp re) =>
      re.firstMatch(File(path).readAsStringSync())?.group(1);

  final pinned = grab(
    '$pkgDir/pubspec.yaml',
    RegExp(r'^\s*flutter_rust_bridge:\s*(\S+)\s*$', multiLine: true),
  );
  if (pinned == null) {
    stderr.writeln('✗ 读不到 $pkgDir/pubspec.yaml 里的 flutter_rust_bridge 版本');
    exit(1);
  }

  final versions = {
    'rust/src/frb_generated.rs': grab(
      '$pkgDir/rust/src/frb_generated.rs',
      RegExp(r'FLUTTER_RUST_BRIDGE_CODEGEN_VERSION: &str = "([^"]+)"'),
    ),
    'lib/src/rust/frb_generated.dart': grab(
      '$pkgDir/lib/src/rust/frb_generated.dart',
      RegExp(r"codegenVersion => '([^']+)'"),
    ),
    'rust/Cargo.toml': grab(
      '$pkgDir/rust/Cargo.toml',
      RegExp(r'^flutter_rust_bridge = "=([^"]+)"', multiLine: true),
    ),
  };

  final stale = versions.entries.where((e) => e.value != pinned).toList();
  if (stale.isNotEmpty) {
    stderr.writeln(
      '✗ $pkgDir：生成物 / 钉版本与 pubspec 的 $pinned 不一致：\n'
      '${stale.map((e) => '    ${e.key} = ${e.value ?? '未知'}').join('\n')}\n'
      '  跑 `dart tool/task.dart gen-rust` 重新生成。',
    );
    exit(1);
  }

  final rustHash = grab(
    '$pkgDir/rust/src/frb_generated.rs',
    RegExp(r'FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = (-?\d+);'),
  );
  final dartHash = grab(
    '$pkgDir/lib/src/rust/frb_generated.dart',
    RegExp(r'rustContentHash => (-?\d+);'),
  );
  if (rustHash == null || dartHash == null) {
    stderr.writeln(
      '✗ 读不到 content hash（rust=${rustHash ?? '未知'} dart=${dartHash ?? '未知'}）——'
      '生成物格式变了，请同步更新本脚本的正则。',
    );
    exit(1);
  }
  if (rustHash != dartHash) {
    stderr.writeln(
      '✗ $pkgDir：两侧 content hash 不一致：rust=$rustHash dart=$dartHash\n'
      '  只提交了一半生成物。跑 `dart tool/task.dart gen-rust` 并把两份都提交。',
    );
    exit(1);
  }
}

void _checkConsistency() {
  final dirs =
      Directory('packages/foundation')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.replaceAll('\\', '/'))
          .where((p) => File('$p/rust/Cargo.toml').existsSync())
          .toList()
        ..sort();
  final depRe = RegExp(
    r'^([A-Za-z0-9_-]+)\s*=\s*(?:"=([^"]+)"|\{[^}]*?version\s*=\s*"=([^"]+)")',
    multiLine: true,
  );
  final pins = <String, Map<String, String>>{};
  final channels = <String, String>{};
  final frbPins = <String, String>{};
  final ffigenPins = <String, String>{};
  for (final dir in dirs) {
    final cargo = File('$dir/rust/Cargo.toml');
    if (!cargo.existsSync()) continue;
    for (final m in depRe.allMatches(cargo.readAsStringSync())) {
      pins.putIfAbsent(m.group(1)!, () => {})[dir] = m.group(2) ?? m.group(3)!;
    }
    final channel = RegExp(r'channel\s*=\s*"([^"]+)"')
        .firstMatch(File('$dir/rust/rust-toolchain.toml').readAsStringSync())
        ?.group(1);
    if (channel != null) channels[dir] = channel;
    if (File('$dir/flutter_rust_bridge.yaml').existsSync()) {
      final pubspec = File('$dir/pubspec.yaml').readAsStringSync();
      String? pin(String name) => RegExp(
        '^\\s*$name:\\s*(\\S+)\\s*\$',
        multiLine: true,
      ).firstMatch(pubspec)?.group(1);
      frbPins[dir] = pin('flutter_rust_bridge') ?? '?';
      ffigenPins[dir] = pin('ffigen') ?? '?';
    }
  }

  final drift = <String>[];
  void compare(String what, Map<String, String> byDir) {
    if (byDir.values.toSet().length > 1) {
      drift.add(
        '$what：${byDir.entries.map((e) => '${e.key.split('/').last}=${e.value}').join(' / ')}',
      );
    }
  }

  for (final e in pins.entries) {
    compare('crate ${e.key}', e.value);
  }
  compare('rust-toolchain channel', channels);
  compare('pubspec flutter_rust_bridge', frbPins);
  compare('pubspec ffigen', ffigenPins);
  if (drift.isNotEmpty) {
    stderr.writeln('✗ 原生库包之间的钉版本不一致（同一 crate 必须钉同一个版本）：');
    for (final d in drift) {
      stderr.writeln('    $d');
    }
    exit(1);
  }
}
