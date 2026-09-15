import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _rustDirs = [
  'packages/foundation/fast_image/rust',
  'packages/foundation/fast_press/rust',
  'packages/foundation/fast_tokenizer/rust',
  'packages/foundation/fast_crypto/rust',
  'packages/foundation/fast_zip/rust',
  'packages/foundation/moodiary_rust/rust',
];

/// Dependencies whose third-party licenses cargo-about cannot see, because the
/// sources are not Rust. Each ships the entries as `third_party.json` at its root.
const _externalLicensePackages = ['sqlite3_simple'];
const _editorDir = 'packages/feature_base/moodiary_editor/editor';
const _npmManifest = '$_editorDir/build/third-party-licenses.json';
const _outPath = 'assets/licenses/third_party.json';

typedef _Entry = ({List<String> packages, String text});

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets &&
        input.config.code.targetOS == OS.current) {
      return;
    }
    final repoRoot = input.packageRoot.resolve('../');
    final rustDirs = [for (final dir in _rustDirs) repoRoot.resolve(dir)];
    final externalManifests = _externalLicenseManifests(repoRoot);
    final lockFile = File.fromUri(
      input.packageRoot.resolve('.dart_tool/licenses_build.lock'),
    )..createSync(recursive: true);
    final lock = await lockFile.open(mode: FileMode.write);
    await lock.lock(FileLock.blockingExclusive);
    try {
      await _generate(
        repoRoot,
        rustDirs,
        externalManifests,
        File.fromUri(input.packageRoot.resolve(_outPath)),
      );
    } finally {
      await lock.unlock();
      await lock.close();
    }
    output.dependencies.addAll([
      for (final dir in rustDirs) ...[
        dir.resolve('Cargo.lock'),
        dir.resolve('about.toml'),
      ],
      ...externalManifests,
      repoRoot.resolve('$_editorDir/package.json'),
      repoRoot.resolve('$_editorDir/pnpm-lock.yaml'),
    ]);
  });
}

List<Uri> _externalLicenseManifests(Uri repoRoot) {
  final config = File.fromUri(
    repoRoot.resolve('.dart_tool/package_config.json'),
  );
  if (!config.existsSync()) {
    throw StateError(
      '${config.path} is missing; run `dart tool/task.dart setup` first.',
    );
  }
  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, dynamic>)['packages']
          as List;
  return [
    for (final name in _externalLicensePackages)
      () {
        final entry = packages.cast<Map<String, dynamic>>().firstWhere(
          (p) => p['name'] == name,
          orElse: () => throw StateError(
            '$name is not in the package config; the license manifest cannot '
            'cover its third-party sources.',
          ),
        );
        return config.parent.uri
            .resolve('${entry['rootUri']}/')
            .resolve('third_party.json');
      }(),
  ];
}

List<_Entry> _externalEntries(File manifest) {
  if (!manifest.existsSync()) {
    throw StateError(
      '${manifest.path} is missing; the license manifest cannot cover it.',
    );
  }
  return [
    for (final e in jsonDecode(manifest.readAsStringSync()) as List)
      (
        packages: [
          for (final p in (e as Map<String, dynamic>)['packages'] as List)
            p as String,
        ],
        text: e['text'] as String,
      ),
  ];
}

Future<void> _generate(
  Uri repoRoot,
  List<Uri> rustDirs,
  List<Uri> externalManifests,
  File out,
) async {
  final texts = <String, Set<String>>{};
  for (final e in [
    for (final dir in rustDirs) ...await _rust(dir),
    for (final uri in externalManifests) ..._externalEntries(File.fromUri(uri)),
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
