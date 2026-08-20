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

const _rustPkgDir = 'packages/foundation/moodiary_rust';

void main() {
  String? grab(String path, RegExp re) =>
      re.firstMatch(File(path).readAsStringSync())?.group(1);

  final pinned = grab(
    '$_rustPkgDir/pubspec.yaml',
    RegExp(r'^\s*flutter_rust_bridge:\s*(\S+)\s*$', multiLine: true),
  );
  if (pinned == null) {
    stderr.writeln('✗ 读不到 $_rustPkgDir/pubspec.yaml 里的 flutter_rust_bridge 版本');
    exit(1);
  }

  final versions = {
    'rust/src/frb_generated.rs': grab(
      '$_rustPkgDir/rust/src/frb_generated.rs',
      RegExp(r'FLUTTER_RUST_BRIDGE_CODEGEN_VERSION: &str = "([^"]+)"'),
    ),
    'lib/src/rust/frb_generated.dart': grab(
      '$_rustPkgDir/lib/src/rust/frb_generated.dart',
      RegExp(r"codegenVersion => '([^']+)'"),
    ),
    // Rust 侧的钉版本没有别的检查覆盖，一并比对。
    'rust/Cargo.toml': grab(
      '$_rustPkgDir/rust/Cargo.toml',
      RegExp(r'^flutter_rust_bridge = "=([^"]+)"', multiLine: true),
    ),
  };

  final stale = versions.entries.where((e) => e.value != pinned).toList();
  if (stale.isNotEmpty) {
    stderr.writeln(
      '✗ 生成物 / 钉版本与 pubspec 的 $pinned 不一致：\n'
      '${stale.map((e) => '    ${e.key} = ${e.value ?? '未知'}').join('\n')}\n'
      '  跑 `dart tool/task.dart gen-rust` 重新生成。',
    );
    exit(1);
  }

  // 两侧的 content hash 由同一次 codegen 写出，必须相等。不等 = 只提交了一半生成物，
  // 而运行时那句 StateError 要等到 RustLib.init() 才响，测试跑不到就发不出来。
  final rustHash = grab(
    '$_rustPkgDir/rust/src/frb_generated.rs',
    RegExp(r'FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = (-?\d+);'),
  );
  final dartHash = grab(
    '$_rustPkgDir/lib/src/rust/frb_generated.dart',
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
      '✗ 两侧 content hash 不一致：rust=$rustHash dart=$dartHash\n'
      '  只提交了一半生成物。跑 `dart tool/task.dart gen-rust` 并把两份都提交。',
    );
    exit(1);
  }
}
