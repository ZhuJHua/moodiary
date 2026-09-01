// 生成第三方许可证清单 —— Rust crates + 编辑器 npm 依赖。
//
// pub 依赖、Flutter/Dart SDK 与引擎那部分由 flutter tool 自动收进 `NOTICES`，
// 运行时 `LicensePage` 会自己读，这里不重复采集。产物是提交的：
//   mobile/assets/licenses/third_party.json
//
// 两侧都用各自生态的官方产物，本文件只做合并去重：
//   * Rust —— `cargo about generate --format json`（配置见 rust/about.toml）
//   * npm  —— vite 构建时 rollup-plugin-license 写出的 build/third-party-licenses.json
//
// 用法：dart tool/task.dart licenses（会先构建一次编辑器，npm 那份是构建产物）
// 前置：cargo-about（`cargo install cargo-about --locked --features cli`）。
import 'dart:convert';
import 'dart:io';

const _rustDir = 'packages/foundation/moodiary_rust/rust';
const _npmManifest =
    'packages/feature_base/moodiary_editor/editor/build/third-party-licenses.json';
const _outPath = 'mobile/assets/licenses/third_party.json';

/// 一条许可证正文，以及共用它的包。与 `LicenseEntryWithLineBreaks` 一一对应。
typedef _Entry = ({List<String> packages, String text});

Future<void> main() async {
  final texts = <String, Set<String>>{};
  for (final e in [...await _rust(), ..._npm()]) {
    texts.putIfAbsent(e.text, () => <String>{}).addAll(e.packages);
  }

  final entries =
      texts.entries.map((e) {
        final packages = e.value.toList()..sort();
        return {'packages': packages, 'text': e.key};
      }).toList()..sort((a, b) {
        final l = (a['packages']! as List).first as String;
        final r = (b['packages']! as List).first as String;
        return l.toLowerCase().compareTo(r.toLowerCase());
      });

  final out = File(_outPath);
  await out.parent.create(recursive: true);
  await out.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
  );

  final packageCount = entries.fold<int>(
    0,
    (n, e) => n + (e['packages']! as List).length,
  );
  stdout.writeln(
    '$_outPath: $packageCount 个包 / ${entries.length} 段许可证正文 '
    '(${(out.lengthSync() / 1024).round()} KiB)',
  );
}

/// cargo-about 的原生 JSON。`about.toml` 已按目标平台过滤，并排除构建期与测试期依赖。
Future<List<_Entry>> _rust() async {
  final proc = await Process.run('cargo', [
    'about',
    'generate',
    '--format',
    'json',
  ], workingDirectory: _rustDir);
  if (proc.exitCode != 0) {
    stderr.writeln(proc.stderr);
    throw StateError('cargo about 失败，先装 cargo-about');
  }

  final licenses =
      (jsonDecode(proc.stdout as String) as Map<String, dynamic>)['licenses']
          as List;
  return [
    for (final l in licenses.cast<Map<String, dynamic>>())
      (
        packages: [
          for (final u in l['used_by'] as List)
            _label(
              (u as Map<String, dynamic>)['crate'] as Map<String, dynamic>,
              'Rust',
            ),
        ],
        text: (l['text'] as String).trim(),
      ),
  ];
}

/// rollup-plugin-license 的产物：**只有真正进了 bundle 的模块**，不是全部 prod 依赖。
/// 它由 vite 构建写出，所以跑这个任务前编辑器必须已经构建过。
List<_Entry> _npm() {
  final file = File(_npmManifest);
  if (!file.existsSync()) {
    throw StateError('$_npmManifest 不存在，先构建一次编辑器');
  }

  final deps = jsonDecode(file.readAsStringSync()) as List;
  return [
    for (final d in deps.cast<Map<String, dynamic>>())
      (packages: [_label(d, 'npm')], text: _npmText(d)),
  ];
}

String _label(Map<String, dynamic> pkg, String origin) =>
    '${pkg['name']} ${pkg['version']} ($origin)';

/// Apache-2.0 的 NOTICE 与许可证正文都要留：前者是该许可证第 4(d) 条明确要求的。
String _npmText(Map<String, dynamic> dep) {
  final text = (dep['licenseText'] as String?)?.trim();
  final notice = (dep['noticeText'] as String?)?.trim();
  if (text == null || text.isEmpty) {
    // 包里没带正文时的兜底：至少把 SPDX id 与主页留下，别静默丢一条。
    return [
      '${dep['name']} is distributed under the ${dep['license']} license.',
      if (dep['homepage'] is String) dep['homepage'] as String,
      '',
      'The package ships no license file; see the project home page for the '
          'full text.',
    ].join('\n');
  }
  return notice == null || notice.isEmpty ? text : '$text\n\n$notice';
}
