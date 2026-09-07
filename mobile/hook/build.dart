import 'dart:convert';
import 'dart:io';

import 'package:hooks/hooks.dart';

const _rustDirs = [
  'packages/foundation/fast_image/rust',
  'packages/foundation/fast_press/rust',
  'packages/foundation/fast_tokenizer/rust',
  'packages/foundation/fast_crypto/rust',
  'packages/foundation/fast_zip/rust',
  'packages/foundation/moodiary_rust/rust',
];
const _editorDir = 'packages/feature_base/moodiary_editor/editor';
const _npmManifest = '$_editorDir/build/third-party-licenses.json';
const _outPath = 'assets/licenses/third_party.json';

typedef _Entry = ({List<String> packages, String text});

void main(List<String> args) async {
  await build(args, (input, output) async {
    final repoRoot = input.packageRoot.resolve('../');
    final lockFile = File.fromUri(
      input.packageRoot.resolve('.dart_tool/licenses_build.lock'),
    )..createSync(recursive: true);
    final lock = await lockFile.open(mode: FileMode.write);
    await lock.lock(FileLock.blockingExclusive);
    try {
      await _generate(
        repoRoot,
        File.fromUri(input.packageRoot.resolve(_outPath)),
      );
    } finally {
      await lock.unlock();
      await lock.close();
    }
    output.dependencies.addAll([
      for (final dir in _rustDirs) ...[
        repoRoot.resolve('$dir/Cargo.lock'),
        repoRoot.resolve('$dir/about.toml'),
      ],
      repoRoot.resolve('$_editorDir/package.json'),
      repoRoot.resolve('$_editorDir/pnpm-lock.yaml'),
    ]);
  });
}

Future<void> _generate(Uri repoRoot, File out) async {
  final texts = <String, Set<String>>{};
  for (final e in [
    for (final dir in _rustDirs) ...await _rust(repoRoot.resolve(dir)),
    ..._npm(File.fromUri(repoRoot.resolve(_npmManifest))),
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

  await out.parent.create(recursive: true);
  await out.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
  );
}

Future<List<_Entry>> _rust(Uri rustDir) async {
  final ProcessResult proc;
  try {
    proc = await Process.run('cargo', [
      'about',
      'generate',
      '--format',
      'json',
    ], workingDirectory: rustDir.toFilePath());
  } on ProcessException {
    throw StateError('cargo not found on PATH; install rustup.');
  }
  if (proc.exitCode != 0) {
    stderr.write(proc.stderr);
    throw StateError(
      '`cargo about generate` failed in ${rustDir.toFilePath()}. '
      'Install it with `cargo install cargo-about --version 0.9.2 --locked`.',
    );
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

List<_Entry> _npm(File manifest) {
  if (!manifest.existsSync()) {
    throw StateError(
      '${manifest.path} is missing; it is written by the moodiary_editor build '
      'hook, which runs before this one. Run `dart tool/task.dart clean` and rebuild.',
    );
  }

  final deps = jsonDecode(manifest.readAsStringSync()) as List;
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
