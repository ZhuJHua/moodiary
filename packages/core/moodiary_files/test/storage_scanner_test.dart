import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('storage-scanner-'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, int bytes) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List.filled(bytes, 0));
  }

  test('areas are disjoint, progress is cumulative, all areas finish', () async {
    final expected = <StorageArea, int>{
      .model: 10,
      .database: 15,
      .font: 3,
      .image: 12,
      .audio: 5,
      .video: 13,
      .file: 7,
      .cache: 19,
      .logs: 23,
      .legacyBackups: 31,
      .other: 37,
    };
    write('support/model/live.onnx', 10);
    write('support/database/diary.sqlite', 8);
    write('support/database/jieba/dict', 7);
    write('support/font/a.ttf', 3);
    write('support/image/a.jpg', 10);
    write('support/image/thumb/a.jpg', 2);
    write('support/audio/a.m4a', 5);
    write('support/video/a.mp4', 11);
    write('support/video/thumbnail-a.jpeg', 2);
    write('support/file/a.txt', 7);
    write('cache/tmp', 8);
    write('cache/sync-media/in-use', 11);
    write('support/error.log', 13);
    write('support/error.log.1', 4);
    write('support/sync_logs/today', 6);
    write('support/database/default.isar.pre-sqlite.bak', 17);
    write('support/database/default.isar.v273bak', 10);
    write('support/migration_backup/diary.json', 4);
    write('support/mmkv/settings', 29);
    write('support/unknown', 8);
    // Enough files to exercise throttled intermediate progress within an area.
    for (var i = 0; i < 450; i++) {
      write('support/image/$i.jpg', 1);
    }
    expected[StorageArea.image] = expected[StorageArea.image]! + 450;
    final events = await StorageScanner(
      supportPath: '${root.path}/support',
      cachePath: '${root.path}/cache',
    ).scan(StorageScanInput()).toList();
    expect(events.length, greaterThan(StorageArea.values.length + 1));
    var previousTotal = 0;
    var previousCount = 0;
    var previousDone = <StorageArea>{};
    var previousBytes = <StorageArea, int>{};
    for (final event in events) {
      expect(event.total, greaterThanOrEqualTo(previousTotal));
      expect(event.files, greaterThanOrEqualTo(previousCount));
      expect(event.done.containsAll(previousDone), isTrue);
      for (final area in StorageArea.values) {
        expect(
          event.bytes[area],
          greaterThanOrEqualTo(previousBytes[area] ?? 0),
        );
      }
      previousTotal = event.total;
      previousCount = event.files;
      previousDone = event.done;
      previousBytes = event.bytes;
    }
    expect(events.last.complete, isTrue);
    expect(events.last.done, StorageArea.values.toSet());
    expect(events.last.bytes, expected);
    expect(events.last.candidates[StorageCleanupKind.cache]!.bytes, 8);
    expect(events.last.total, expected.values.fold(0, (a, b) => a + b));
    expect(
      events[3].done,
      containsAll([StorageArea.model, StorageArea.database, StorageArea.font]),
    );
  });

  test(
    'candidates match references and publish only for finalized kinds',
    () async {
      final input = StorageScanInput(
        referencedMedia: (
          images: {'live.jpg'},
          audios: {'live.m4a'},
          videos: {'video-live.mp4'},
          files: {'live.txt'},
        ),
        liveModelFiles: {'live.onnx', 'live.tokenizer.json'},
        retiredModelStems: {'old'},
        includeLegacyBackups: true,
      );
      final sizes = {
        'model/live.onnx': 1,
        'model/live.tokenizer.json': 2,
        'model/old': 3,
        'model/old.onnx': 4,
        'model/old.tokenizer.json': 5,
        'model/older.onnx': 6,
        'model/unknown.bin': 7,
        'model/old.onnx.part': 8,
        'model/live.onnx.part': 9,
        'image/live.jpg': 10,
        'image/orphan.jpg': 11,
        'image/thumb/live_512.jpg': 12,
        'image/thumb/orphan_512.jpg': 13,
        'image/thumb/orphan_base.jpg': 14,
        'image/thumb/unrecognized.jpg': 15,
        'image/thumb/junk.bin': 16,
        'image/thumb/fresh.part': 17,
        'image/thumb/old.part': 18,
        'audio/live.m4a': 19,
        'audio/orphan.m4a': 20,
        'video/video-live.mp4': 21,
        'video/thumbnail-live.jpeg': 22,
        'video/video-orphan.mp4': 23,
        'video/thumbnail-orphan.jpeg': 24,
        'file/live.txt': 25,
        'file/orphan.txt': 26,
        'database/default.isar.pre-sqlite.bak': 27,
        'database/default.isar.v273bak': 28,
        'migration_backup/keep.json': 29,
      };
      for (final entry in sizes.entries) {
        write('support/${entry.key}', entry.value);
      }
      for (final name in ['old.onnx.part', 'live.onnx.part']) {
        File('${root.path}/support/model/$name').setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 2)),
        );
      }
      File(
        '${root.path}/support/image/thumb/old.part',
      ).setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
      for (final name in const ['sync-media', 'export', 'import']) {
        write('cache/$name/in-use', 30);
      }
      write('cache/tmp/a', 31);
      // Neither storage usage nor cleanup follows symlinks.
      Link('${root.path}/support/image/link.jpg')
          .createSync('${root.path}/support/image/orphan.jpg');
      Link('${root.path}/support/model/cycle')
          .createSync('${root.path}/support/model');
      final events = await StorageScanner(
        supportPath: '${root.path}/support',
        cachePath: '${root.path}/cache',
      ).scan(input).toList();
      for (final report in events) {
        for (final kind in StorageCleanupKind.values) {
          expect(report.candidates.containsKey(kind), report.finished(kind));
          if (report.finished(kind)) {
            expect(
              report.candidates[kind]!.files.map((file) => file.path),
              events.last.candidates[kind]!.files.map((file) => file.path),
            );
          }
        }
      }
      final report = events.last;
      List<String> names(StorageCleanupKind kind) => report
          .candidates[kind]!
          .files
          .map((f) => f.path.substring('${root.path}/support/'.length))
          .toList();
      expect(
        names(.retiredModel),
        unorderedEquals([
          'model/old',
          'model/old.onnx',
          'model/old.tokenizer.json',
        ]),
      );
      expect(
        names(.unusedModel),
        unorderedEquals(['model/older.onnx', 'model/unknown.bin']),
      );
      expect(
        names(.partialDownload),
        unorderedEquals(['model/old.onnx.part', 'model/live.onnx.part']),
      );
      expect(
        names(.unusedMedia),
        unorderedEquals([
          'image/orphan.jpg',
          'image/thumb/orphan_512.jpg',
          'image/thumb/orphan_base.jpg',
          'image/thumb/junk.bin',
          'image/thumb/old.part',
          'audio/orphan.m4a',
          'video/video-orphan.mp4',
          'video/thumbnail-orphan.jpeg',
          'file/orphan.txt',
        ]),
      );
      final media = report.candidates[StorageCleanupKind.unusedMedia]!;
      expect(media.counts, {
        MediaType.image: 1,
        MediaType.audio: 1,
        MediaType.video: 1,
        MediaType.file: 1,
      });
      expect(media.areaBytes, {
        StorageArea.image: 72,
        StorageArea.audio: 20,
        StorageArea.video: 47,
        StorageArea.file: 26,
      });
      expect(report.candidates[StorageCleanupKind.cache]!.bytes, 31);
      expect(report.bytes[StorageArea.cache], 121);
      expect(report.candidates[StorageCleanupKind.legacyBackup]!.bytes, 55);
      expect(report.bytes[StorageArea.legacyBackups], 84);
      expect(report.total, sizes.values.fold(121, (sum, size) => sum + size));
      final disabled = await StorageScanner(
        supportPath: '${root.path}/support',
        cachePath: '${root.path}/cache',
      ).scan(StorageScanInput()).last;
      expect(
        disabled.candidates[StorageCleanupKind.legacyBackup]!.files,
        isEmpty,
      );
      expect(disabled.bytes, report.bytes);
    },
  );

  test(
    'snapshot cache cleanup retains new files and protected workspaces',
    () async {
      write('cache/idle/scanned', 3);
      write('cache/idle/new', 5);
      write('cache/export/keep', 7);
      final paths = {
        '${root.path}/cache/idle/scanned',
        '${root.path}/cache/export/keep',
      };
      expect(
        await AppFiles.clearCache(
          cachePath: '${root.path}/cache',
          filePaths: paths,
        ),
        3,
      );
      expect(File('${root.path}/cache/idle/scanned').existsSync(), isFalse);
      expect(File('${root.path}/cache/idle/new').existsSync(), isTrue);
      expect(File('${root.path}/cache/export/keep').existsSync(), isTrue);
    },
  );

  test(
    'cache root and in-use workspaces survive; idle children are removed',
    () async {
      write('cache/sync-media/a', 1);
      write('cache/export/a', 1);
      write('cache/import/a', 1);
      write('cache/idle/a', 1);
      write('cache/temporary', 1);
      expect(await AppFiles.clearCache(cachePath: '${root.path}/cache'), 2);
      expect(Directory('${root.path}/cache').existsSync(), isTrue);
      for (final name in const ['sync-media', 'export', 'import']) {
        expect(File('${root.path}/cache/$name/a').existsSync(), isTrue);
      }
      expect(Directory('${root.path}/cache/idle').existsSync(), isFalse);
      expect(File('${root.path}/cache/temporary').existsSync(), isFalse);
      await AppFiles.clearCache(
        cachePath: '${root.path}/cache',
        protectWorkspaces: false,
      );
      expect(File('${root.path}/cache/sync-media/a').existsSync(), isFalse);
      expect(Directory('${root.path}/cache/export').existsSync(), isFalse);
    },
  );

  test(
    'backup workspaces survive scans and both cleanup modes until reset',
    () async {
      final protected = [
        'sync-media/a',
        'export/a',
        'import/a',
        'backup-import-123/a',
        'moodiary-backup-20261028.zip',
      ];
      for (final name in protected) {
        write('cache/$name', 7);
        expect(AppFiles.isProtectedCacheEntry(name.split('/').first), isTrue);
      }
      write('cache/idle.zip', 3);
      final report = await StorageScanner(
        supportPath: '${root.path}/support',
        cachePath: '${root.path}/cache',
      ).scan(StorageScanInput()).last;
      expect(
        report.candidates[StorageCleanupKind.cache]!.files.single.path,
        '${root.path}/cache/idle.zip',
      );
      final allPaths = {
        for (final name in protected) '${root.path}/cache/$name',
        '${root.path}/cache/idle.zip',
      };
      expect(
        await AppFiles.clearCache(
          cachePath: '${root.path}/cache',
          filePaths: allPaths,
        ),
        3,
      );
      expect(await AppFiles.clearCache(cachePath: '${root.path}/cache'), 0);
      for (final name in protected) {
        expect(File('${root.path}/cache/$name').existsSync(), isTrue);
      }
      expect(
        await AppFiles.clearCache(
          cachePath: '${root.path}/cache',
          protectWorkspaces: false,
        ),
        35,
      );
    },
  );

  test('only model partials older than one hour are candidates', () async {
    write('support/model/fresh.part', 3);
    write('support/model/old.part', 5);
    File('${root.path}/support/model/old.part')
        .setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
    final report = await StorageScanner(
      supportPath: '${root.path}/support',
      cachePath: '${root.path}/cache',
    ).scan(StorageScanInput()).last;
    final files = report.candidates[StorageCleanupKind.partialDownload]!.files;
    expect(files.single.path, endsWith('/old.part'));
    expect(files.single.modified, isNotNull);
    expect(report.candidates[StorageCleanupKind.unusedModel]!.files, isEmpty);
    expect(report.bytes[StorageArea.model], 8);
  });

  test('each candidate list crosses the isolate once', () async {
    write('support/model/old.bin', 5);
    for (var i = 0; i < 450; i++) {
      write('support/image/$i.jpg', 1);
    }
    final payloads = <StorageReport>[];
    final reports = await StorageScanner(
      supportPath: '${root.path}/support',
      cachePath: '${root.path}/cache',
      onWorkerReport: payloads.add,
    ).scan(StorageScanInput()).toList();
    final sent = <StorageCleanupKind>{};
    var previousDone = <StorageArea>{};
    for (final payload in payloads) {
      for (final kind in payload.candidates.keys) {
        expect(sent.add(kind), isTrue, reason: '$kind was sent twice');
        expect(previousDone.containsAll(kind.areas), isFalse);
        expect(payload.done.containsAll(kind.areas), isTrue);
      }
      if (payload.done.length == previousDone.length) {
        expect(payload.candidates, isEmpty);
      }
      previousDone = payload.done;
    }
    expect(sent, StorageCleanupKind.values.toSet());
    expect(payloads.where((p) => p.candidates.isEmpty).length, greaterThan(2));
    for (final report in reports.where(
      (r) => r.done.contains(StorageArea.model),
    )) {
      expect(report.candidates[StorageCleanupKind.unusedModel]!.bytes, 5);
    }
    expect(
      reports.last.candidates[StorageCleanupKind.unusedMedia]!.files,
      hasLength(450),
    );
  });

  test('cleaned kinds are removed from candidates and area totals', () {
    final report = StorageReport(
      bytes: const {StorageArea.model: 100, StorageArea.cache: 50},
      done: StorageArea.values.toSet(),
      area: .other,
      files: 3,
      candidates: {
        StorageCleanupKind.partialDownload: StorageCandidates(const [
          StorageCandidate(path: '/m.part', bytes: 40, area: .model),
        ]),
        StorageCleanupKind.cache: StorageCandidates(const [
          StorageCandidate(path: '/c', bytes: 50, area: .cache),
        ]),
      },
    );
    final left = report.without({StorageCleanupKind.partialDownload});
    expect(left.bytes[StorageArea.model], 60);
    expect(left.bytes[StorageArea.cache], 50);
    expect(left.candidates.keys, [StorageCleanupKind.cache]);
    expect(left.complete, isTrue);
  });
}
