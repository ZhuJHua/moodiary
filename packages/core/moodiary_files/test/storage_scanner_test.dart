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
    ).scan().toList();
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
    expect(events.last.reclaimableCacheBytes, 8);
    expect(events.last.total, expected.values.fold(0, (a, b) => a + b));
    expect(
      events[3].done,
      containsAll([StorageArea.model, StorageArea.database, StorageArea.font]),
    );
  });

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
      for (final name in AppFiles.protectedCacheDirectories) {
        expect(File('${root.path}/cache/$name/a').existsSync(), isTrue);
      }
      expect(Directory('${root.path}/cache/idle').existsSync(), isFalse);
      expect(File('${root.path}/cache/temporary').existsSync(), isFalse);
      await AppFiles.clearCache(
        cachePath: '${root.path}/cache',
        inUseDirectories: {'sync-media'},
      );
      expect(File('${root.path}/cache/sync-media/a').existsSync(), isTrue);
      expect(Directory('${root.path}/cache/export').existsSync(), isFalse);
    },
  );
}
