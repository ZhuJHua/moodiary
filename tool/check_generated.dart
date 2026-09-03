// 校验两侧生成物的 codegen 版本与 pubspec 钉的一致，外加两侧 content hash 相等。
// 不是完整的漂移检查（那要装 codegen CLI 重跑一遍，而 CI 刻意不带缓存），挡的是：
//   1) 用别的 codegen 版本生成后提交；
//   2) 只提交了两份生成物里的一份（content hash 对不上）。
//
// 剩下的缺口只有一个，且它需要 codegen 真的跑过：**content hash 只对 api 函数名做
// SHA1**（codegen 的 generate_content_hash 取 sha1 前四字节），参数类型、返回类型、
// 结构体定义都不在里面。所以「改了签名但没改名、且只提交了 Rust 那半」不会被 hash
// 抓到 —— 不过那一半里 frb_generated.rs 是编译进去的，cargo clippy 会先炸。真正裸奔的
// 是「只提交了 Dart 那半」，此时 Dart 按新签名编码、Rust 按旧签名解码，静默错解。
// 要堵死它得在 CI 里装 flutter_rust_bridge_codegen 重跑 + git diff --exit-code。
//
// 纯 dart:io，不依赖 fvm / flutter，CI 可直接 `dart tool/check_generated.dart`。
import 'dart:io';

/// 带自己 FRB 的包，与 tool/task.dart 的 _frbPkgDirs 同一份。
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
    // Rust 侧的钉版本没有别的检查覆盖，一并比对。
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

  // 两侧的 content hash 由同一次 codegen 写出，必须相等。不等 = 只提交了一半生成物，
  // 而运行时那句 StateError 要等到 XxxLib.init() 才响，测试跑不到就发不出来。
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

/// 没有 `[workspace.dependencies]` 了：同一 crate 在多个原生库包里各钉一次，这里比对它们相等；
/// 同样比对各包 rust-toolchain.toml 的 channel，以及各 FRB 包 pubspec 的 flutter_rust_bridge / ffigen。
/// 漂了就红：FRB / tokio / reqwest 两份不同版本进两个 .so 既是体积倒退也是行为分叉。
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
  // crate → {包目录: 版本}
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
