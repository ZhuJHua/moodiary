// 校验两侧生成物的 codegen 版本与 pubspec 钉的一致。不是完整的漂移检查（那要装
// codegen CLI 重跑一遍），只挡「用别的版本生成后提交」。改了 api/*.rs 忘记生成由
// cargo clippy 兜住 —— frb_generated.rs 是编译进去的。
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
  if (stale.isEmpty) return;
  stderr.writeln(
    '✗ 生成物 / 钉版本与 pubspec 的 $pinned 不一致：\n'
    '${stale.map((e) => '    ${e.key} = ${e.value ?? '未知'}').join('\n')}\n'
    '  跑 `dart tool/task.dart gen-rust` 重新生成。',
  );
  exit(1);
}
