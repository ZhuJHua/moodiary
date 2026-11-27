import 'dart:convert';
import 'dart:io';

const _base = 'develop';
const _pubspecPath = 'mobile/pubspec.yaml';
final _fullShaPattern = RegExp(r'^[0-9a-f]{40}$');
final _semverPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');
final _positiveIntPattern = RegExp(r'^[1-9]\d*$');

sealed class ReleaseCommand {
  const ReleaseCommand();
}

final class PrepareCommand extends ReleaseCommand {
  const PrepareCommand({this.explicitVersion, this.bump, required this.yes});

  final String? explicitVersion;
  final String? bump;
  final bool yes;
}

final class PublishCommand extends ReleaseCommand {
  const PublishCommand({this.version, required this.yes});

  final String? version;
  final bool yes;
}

final class IosBetaCommand extends ReleaseCommand {
  const IosBetaCommand({this.ref});

  final String? ref;
}

final class IosSubmitCommand extends ReleaseCommand {
  const IosSubmitCommand({
    required this.buildNumber,
    this.ref,
    required this.skipMetadata,
  });

  final String buildNumber;
  final String? ref;
  final bool skipMetadata;
}

final class HelpCommand extends ReleaseCommand {
  const HelpCommand();
}

final class DraftReleaseInfo {
  const DraftReleaseInfo({
    required this.id,
    required this.tagName,
    required this.targetCommitish,
    required this.apkSize,
    required this.checksumSize,
  });

  final int id;
  final String tagName;
  final String targetCommitish;
  final int apkSize;
  final int checksumSize;
}

String normalizeVersion(String raw) {
  final v = raw.startsWith('v') ? raw.substring(1) : raw;
  if (!_semverPattern.hasMatch(v)) {
    throw FormatException('版本号格式不对：$raw（应为 X.Y.Z）');
  }
  return v;
}

({String version, int build}) parsePubspecVersion(String pubspecContent) {
  final m = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspecContent);
  if (m == null) {
    throw const FormatException('读不出 $_pubspecPath 里的 version');
  }
  return (version: m[1]!, build: int.parse(m[2]!));
}

String computeNextVersion(String current, {String? explicit, String? bump}) {
  if (explicit != null) return normalizeVersion(explicit);
  final m = _semverPattern.firstMatch(current)!;
  final major = int.parse(m[1]!);
  final minor = int.parse(m[2]!);
  final patch = int.parse(m[3]!);
  return switch (bump) {
    'patch' => '$major.$minor.${patch + 1}',
    'minor' => '$major.${minor + 1}.0',
    'major' => '${major + 1}.0.0',
    _ => throw FormatException('--bump 只接受 patch / minor / major，收到：$bump'),
  };
}

ReleaseCommand parseCommand(List<String> argv) {
  final args = argv.where((a) => a != '--').toList();
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    return const HelpCommand();
  }

  return switch (args.first) {
    'prepare' => _parsePrepare(args.sublist(1)),
    'publish' => _parsePublish(args.sublist(1)),
    'ios-beta' => _parseIosBeta(args.sublist(1)),
    'ios-submit' => _parseIosSubmit(args.sublist(1)),
    _ => _parsePrepare(args),
  };
}

PrepareCommand _parsePrepare(List<String> args) {
  String? explicitVersion;
  String? bump;
  var yes = false;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--yes') {
      yes = true;
    } else if (a == '--bump') {
      if (i + 1 >= args.length) {
        throw const FormatException('--bump 需要 patch / minor / major');
      }
      if (bump != null) {
        throw const FormatException('--bump 不能重复指定');
      }
      bump = args[++i];
      if (bump != 'patch' && bump != 'minor' && bump != 'major') {
        throw FormatException('--bump 只接受 patch / minor / major，收到：$bump');
      }
    } else if (a.startsWith('-')) {
      throw FormatException('未知参数：$a');
    } else {
      if (explicitVersion != null) {
        throw FormatException('多余参数：$a');
      }
      explicitVersion = normalizeVersion(a);
    }
  }

  if (explicitVersion != null && bump != null) {
    throw const FormatException('不能同时指定版本号和 --bump');
  }
  if (explicitVersion == null && bump == null) {
    throw const FormatException('prepare 需要版本号或 --bump patch|minor|major');
  }
  return PrepareCommand(explicitVersion: explicitVersion, bump: bump, yes: yes);
}

PublishCommand _parsePublish(List<String> args) {
  String? version;
  var yes = false;

  for (final a in args) {
    if (a == '--yes') {
      yes = true;
    } else if (a.startsWith('-')) {
      throw FormatException('未知参数：$a');
    } else {
      if (version != null) {
        throw FormatException('多余参数：$a');
      }
      version = normalizeVersion(a);
    }
  }
  return PublishCommand(version: version, yes: yes);
}

IosBetaCommand _parseIosBeta(List<String> args) {
  String? ref;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--ref') {
      if (i + 1 >= args.length || args[i + 1].trim().isEmpty) {
        throw const FormatException('--ref 需要分支、tag 或 commit SHA');
      }
      ref = args[++i].trim();
    } else if (a.startsWith('--ref=')) {
      final v = a.substring('--ref='.length).trim();
      if (v.isEmpty) {
        throw const FormatException('--ref 不能为空');
      }
      ref = v;
    } else {
      throw FormatException('未知参数：$a');
    }
  }
  return IosBetaCommand(ref: ref);
}

IosSubmitCommand _parseIosSubmit(List<String> args) {
  String? buildNumber;
  String? ref;
  var skipMetadata = false;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--skip-metadata') {
      skipMetadata = true;
    } else if (a == '--ref') {
      if (i + 1 >= args.length || args[i + 1].trim().isEmpty) {
        throw const FormatException('--ref 需要分支、tag 或 commit SHA');
      }
      ref = args[++i].trim();
    } else if (a.startsWith('--ref=')) {
      final v = a.substring('--ref='.length).trim();
      if (v.isEmpty) {
        throw const FormatException('--ref 不能为空');
      }
      ref = v;
    } else if (a.startsWith('-')) {
      throw FormatException('未知参数：$a');
    } else {
      if (buildNumber != null) {
        throw FormatException('多余参数：$a');
      }
      buildNumber = a;
    }
  }

  if (buildNumber == null || !_positiveIntPattern.hasMatch(buildNumber)) {
    throw const FormatException('ios-submit 需要正整数 TestFlight build_number');
  }
  return IosSubmitCommand(
    buildNumber: buildNumber,
    ref: ref,
    skipMetadata: skipMetadata,
  );
}

List<String> buildIosBetaWorkflowArgs({String? ref}) => [
  'workflow',
  'run',
  'ios-release.yml',
  '--ref',
  _base,
  if (ref != null) ...['-f', 'ref=$ref'],
];

List<String> buildIosSubmitWorkflowArgs({
  required String buildNumber,
  String? ref,
  required bool skipMetadata,
}) => [
  'workflow',
  'run',
  'ios-submit.yml',
  '--ref',
  _base,
  '-f',
  'build_number=$buildNumber',
  if (ref != null) ...['-f', 'ref=$ref'],
  if (skipMetadata) ...['-f', 'skip_metadata=true'],
];

DraftReleaseInfo validateDraftRelease({
  required List<Map<String, dynamic>> releases,
  required String version,
}) {
  final expectedTag = 'v$version';
  final expectedApk = 'moodiary-$version-android-arm64.apk';
  const expectedChecksums = 'SHA256SUMS.txt';

  final matching = releases
      .where((r) => r['draft'] == true && r['tag_name'] == expectedTag)
      .toList();
  if (matching.isEmpty) {
    throw FormatException('找不到待发布的草稿 Release $expectedTag');
  }
  if (matching.length > 1) {
    throw FormatException(
      '存在 ${matching.length} 个同名草稿 Release $expectedTag，请先在 GitHub 清理重复草稿',
    );
  }

  final release = matching.single;
  final id = release['id'];
  if (id is! int) {
    throw FormatException('草稿 Release $expectedTag 缺少有效 id');
  }

  final target = (release['target_commitish'] as String? ?? '').trim();
  if (!_fullShaPattern.hasMatch(target)) {
    throw FormatException(
      '草稿 Release $expectedTag 的 target_commitish 不是完整 40 位 SHA：$target',
    );
  }

  final rawAssets = (release['assets'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  int requireUploadedAsset(String name) {
    final matches = rawAssets.where((a) => a['name'] == name).toList();
    if (matches.isEmpty) {
      throw FormatException('草稿 Release $expectedTag 缺少附件 $name');
    }
    final asset = matches.single;
    final state = asset['state'] as String?;
    final size = asset['size'] as int? ?? 0;
    if (state != 'uploaded' || size <= 0) {
      throw FormatException(
        '附件 $name 未完整上传（state=$state, size=$size）',
      );
    }
    return size;
  }

  final apkSize = requireUploadedAsset(expectedApk);
  final checksumSize = requireUploadedAsset(expectedChecksums);
  return DraftReleaseInfo(
    id: id,
    tagName: expectedTag,
    targetCommitish: target,
    apkSize: apkSize,
    checksumSize: checksumSize,
  );
}

void _printUsage() {
  stdout.writeln('''
用法：
  dart tool/release.dart [prepare] (<X.Y.Z> | --bump patch|minor|major) [--yes]
      准备发版 PR（更新 pubspec 与 CHANGELOG，合并后自动生成 Android 草稿与 iOS TestFlight）

  dart tool/release.dart publish [X.Y.Z] [--yes]
      校验并发布 Android GitHub 草稿 Release（原子创建 tag vX.Y.Z，触发 Telegram 与 F-Droid）

  dart tool/release.dart ios-beta [--ref <branch|tag|sha>]
      单独触发 iOS TestFlight 构建（例如拒审后的 ios-fix/X.Y.Z 分支，不影响 Android / F-Droid）

  dart tool/release.dart ios-submit <build_number> [--ref <branch|tag|sha>] [--skip-metadata]
      提交指定 TestFlight build 至 App Store 审核
''');
}

Never _fail(String message) {
  stderr.writeln('✗ $message');
  exit(1);
}

Future<String> _capture(
  String cmd,
  List<String> args, {
  bool check = true,
}) async {
  final r = await Process.run(cmd, args, runInShell: Platform.isWindows);
  if (check && r.exitCode != 0) {
    stderr.write(r.stderr);
    _fail('${[cmd, ...args].join(' ')} 失败');
  }
  return (r.stdout as String).trim();
}

Future<void> _run(String cmd, List<String> args) async {
  stdout.writeln('\$ ${[cmd, ...args].join(' ')}');
  final proc = await Process.start(
    cmd,
    args,
    mode: .inheritStdio,
    runInShell: Platform.isWindows,
  );
  final code = await proc.exitCode;
  if (code != 0) _fail('${[cmd, ...args].join(' ')} 退出码 $code');
}

Future<void> _requireTool(String name) async {
  try {
    final r = await Process.run(name, [
      '--version',
    ], runInShell: Platform.isWindows);
    if (r.exitCode != 0) _fail('$name 不可用');
  } catch (_) {
    _fail('找不到 $name，请先安装');
  }
}

Future<List<Map<String, dynamic>>> _fetchRecentReleases() async {
  final raw = await _capture('gh', [
    'api',
    'repos/{owner}/{repo}/releases?per_page=30',
  ]);
  final decoded = jsonDecode(raw) as List;
  return decoded.cast<Map<String, dynamic>>();
}

Future<void> _runPrepare(PrepareCommand cmd) async {
  await _requireTool('git');
  await _requireTool('gh');
  await _requireTool('git-cliff');

  final branch = await _capture('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch != _base) _fail('当前在 $branch，请切到 $_base 再执行');

  if ((await _capture('git', ['status', '--porcelain'])).isNotEmpty) {
    _fail('工作区不干净，请先提交或清理');
  }

  await _run('git', ['fetch', 'origin', _base, '--tags']);
  final local = await _capture('git', ['rev-parse', 'HEAD']);
  final remote = await _capture('git', ['rev-parse', 'origin/$_base']);
  if (local != remote) _fail('$_base 与 origin/$_base 不一致，请先 pull/push');

  final openPrsRaw = await _capture('gh', [
    'pr',
    'list',
    '--base',
    _base,
    '--state',
    'open',
    '--json',
    'number,headRefName',
  ]);
  final openReleasePrs = (jsonDecode(openPrsRaw) as List)
      .cast<Map<String, dynamic>>()
      .where((p) => (p['headRefName'] as String? ?? '').startsWith('release/'))
      .toList();
  if (openReleasePrs.isNotEmpty) {
    final summary = openReleasePrs
        .map((p) => '#${p['number']} (${p['headRefName']})')
        .join(', ');
    _fail('已有未合并的发版 PR：$summary，请先处理完成');
  }

  final drafts = (await _fetchRecentReleases())
      .where((r) => r['draft'] == true)
      .toList();
  if (drafts.isNotEmpty) {
    final tags = drafts.map((r) => r['tag_name']).join(', ');
    _fail('已有未发布的草稿 Release（$tags），请先发布或删除后再准备新版本');
  }

  final pubspecFile = File(_pubspecPath);
  final source = pubspecFile.readAsStringSync();
  final parsed = parsePubspecVersion(source);
  final next = computeNextVersion(
    parsed.version,
    explicit: cmd.explicitVersion,
    bump: cmd.bump,
  );
  final nextBuild = parsed.build + 1;
  final releaseBranch = 'release/$next';

  final lastTag = await _capture('git', [
    'describe',
    '--tags',
    '--abbrev=0',
    '--match=v*',
  ]);
  stdout.writeln(
    '\n发版 ${parsed.version}+${parsed.build} → $next+$nextBuild（changelog 范围 $lastTag..HEAD）\n',
  );

  if ((await _capture('git', ['tag', '--list', 'v$next'])).isNotEmpty) {
    _fail('本地已存在 tag v$next');
  }
  final remoteTag = await _capture('git', [
    'ls-remote',
    '--tags',
    'origin',
    'refs/tags/v$next',
  ]);
  if (remoteTag.isNotEmpty) {
    _fail('远端已存在 tag v$next');
  }

  await _run('git', ['switch', '-c', releaseBranch]);

  pubspecFile.writeAsStringSync(
    source.replaceFirst(
      RegExp(r'^version:\s*\d+\.\d+\.\d+\+\d+\s*$', multiLine: true),
      'version: $next+$nextBuild',
    ),
  );

  await _run('git-cliff', [
    '--config',
    'cliff.toml',
    '$lastTag..HEAD',
    '--tag',
    'v$next',
    '--prepend',
    'CHANGELOG.md',
  ]);

  if (!cmd.yes) {
    stdout.writeln(
      '\nCHANGELOG.md 的 [$next] 节已生成，现在人工审阅删噪音条目。'
      '\n改好后回到这里回车继续，Ctrl-C / EOF 中止（分支 $releaseBranch 会留在本地）。',
    );
    if (stdin.readLineSync() == null) {
      _fail('收到 EOF，已中止（分支 $releaseBranch 保留在本地）');
    }
  }

  await _run('git', ['add', 'CHANGELOG.md', _pubspecPath]);
  await _run('git', ['commit', '-m', 'chore(release): $next']);
  await _run('git', ['push', '-u', 'origin', releaseBranch]);

  final notes = LineSplitter()
      .convert(File('CHANGELOG.md').readAsStringSync())
      .skipWhile((l) => !l.startsWith('## [$next]'))
      .skip(1)
      .takeWhile((l) => !l.startsWith('## ['))
      .join('\n')
      .trim();

  final body = File('${Directory.systemTemp.path}/release-$next.md')
    ..writeAsStringSync('$notes\n');
  await _run('gh', [
    'pr',
    'create',
    '--base',
    _base,
    '--head',
    releaseBranch,
    '--title',
    'chore(release): $next',
    '--body-file',
    body.path,
  ]);
  stdout.writeln(
    '\n已创建发版 PR。合并进 $_base 后会自动从 merge commit 构建 Android 草稿 Release 与 iOS TestFlight。'
    '\n后续操作：'
    '\n  1. 核对 Android 草稿 APK 后发布：fvm dart tool/release.dart publish $next'
    '\n  2. 核对 TestFlight 后提审 iOS：fvm dart tool/release.dart ios-submit <build_number>',
  );
}

Future<void> _runPublish(PublishCommand cmd) async {
  await _requireTool('git');
  await _requireTool('gh');

  final version =
      cmd.version ??
      parsePubspecVersion(File(_pubspecPath).readAsStringSync()).version;
  final expectedTag = 'v$version';

  final remoteTag = await _capture('git', [
    'ls-remote',
    '--tags',
    'origin',
    'refs/tags/$expectedTag',
  ]);
  if (remoteTag.isNotEmpty) {
    _fail('远端已存在 tag $expectedTag，拒绝覆盖发布');
  }

  final releases = await _fetchRecentReleases();
  final draft = validateDraftRelease(releases: releases, version: version);

  stdout.writeln('''
即将发布 GitHub Release：
  Tag:    ${draft.tagName}
  ID:     ${draft.id}
  Commit: ${draft.targetCommitish}
  APK:    moodiary-$version-android-arm64.apk (${(draft.apkSize / (1024 * 1024)).toStringAsFixed(1)} MB)
  SHA256: SHA256SUMS.txt (${draft.checksumSize} B)
''');

  if (!cmd.yes) {
    stdout.write('确认公开此 Release 并原子创建 tag ${draft.tagName}？[y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer != 'y' && answer != 'yes') {
      _fail('已取消发布');
    }
  }

  final publishedRaw = await _capture('gh', [
    'api',
    '-X',
    'PATCH',
    'repos/{owner}/{repo}/releases/${draft.id}',
    '-F',
    'draft=false',
  ]);
  final published = jsonDecode(publishedRaw) as Map<String, dynamic>;
  stdout.writeln(
    '\n✓ 已发布 ${draft.tagName}：${published['html_url']}'
    '\n  Telegram 通知将自动触发，F-Droid 会在后续 checkupdates 轮询中拉取该 tag。',
  );
}

Future<void> _runIosBeta(IosBetaCommand cmd) async {
  await _requireTool('gh');
  final args = buildIosBetaWorkflowArgs(ref: cmd.ref);
  await _run('gh', args);
  stdout.writeln(
    '\n✓ 已触发 iOS TestFlight 构建（source=${cmd.ref ?? _base}）。'
    '\n  不会影响 Android、GitHub Release、tag 或 F-Droid。',
  );
}

Future<void> _runIosSubmit(IosSubmitCommand cmd) async {
  await _requireTool('gh');
  final args = buildIosSubmitWorkflowArgs(
    buildNumber: cmd.buildNumber,
    ref: cmd.ref,
    skipMetadata: cmd.skipMetadata,
  );
  await _run('gh', args);
  stdout.writeln(
    '\n✓ 已触发 iOS App Store Review 提审（build=${cmd.buildNumber}, source=${cmd.ref ?? _base}）。',
  );
}

Future<void> main(List<String> argv) async {
  final ReleaseCommand cmd;
  try {
    cmd = parseCommand(argv);
  } on FormatException catch (e) {
    stderr.writeln('✗ ${e.message}\n');
    _printUsage();
    exit(2);
  }

  try {
    switch (cmd) {
      case HelpCommand():
        _printUsage();
      case PrepareCommand():
        await _runPrepare(cmd);
      case PublishCommand():
        await _runPublish(cmd);
      case IosBetaCommand():
        await _runIosBeta(cmd);
      case IosSubmitCommand():
        await _runIosSubmit(cmd);
    }
  } on FormatException catch (e) {
    _fail(e.message);
  }
}
