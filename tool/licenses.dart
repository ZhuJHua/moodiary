import 'dart:convert';
import 'dart:io';

const _rustDirs = [
  'packages/foundation/fast_image/rust',
  'packages/foundation/fast_press/rust',
  'packages/foundation/fast_tokenizer/rust',
  'packages/foundation/fast_crypto/rust',
  'packages/foundation/fast_zip/rust',
  'packages/foundation/moodiary_rust/rust',
];
const _npmManifest =
    'packages/feature_base/moodiary_editor/editor/build/third-party-licenses.json';
const _outPath = 'mobile/assets/licenses/third_party.json';

typedef _Entry = ({List<String> packages, String text});

Future<void> main() async {
  final texts = <String, Set<String>>{};
  for (final e in [
    for (final dir in _rustDirs) ...await _rust(dir),
    ..._npm(),
  ]) {
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

Future<List<_Entry>> _rust(String rustDir) async {
  final proc = await Process.run('cargo', [
    'about',
    'generate',
    '--format',
    'json',
  ], workingDirectory: rustDir);
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

String _npmText(Map<String, dynamic> dep) {
  final text = (dep['licenseText'] as String?)?.trim();
  final notice = (dep['noticeText'] as String?)?.trim();
  if (text == null || text.isEmpty) {
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
