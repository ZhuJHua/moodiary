import 'dart:io';

import 'package:fast_zip/fast_zip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_sync/src/data/impl/legacy_data_exporter.dart';
import 'package:path/path.dart' as p;

class _RecordingZip extends Fake implements Zip {
  final files = <String, List<int>>{};
  Object? writeError;
  bool finished = false;
  bool disposed = false;

  @override
  Future<void> addFile({
    required String filePath,
    required String zipPath,
    String? password,
    bool? stored,
  }) async {
    expect(stored, isNot(true));
    expect(password, isNull);
    files[zipPath] = await File(filePath).readAsBytes();
  }

  @override
  Future<void> finish() async {
    if (writeError case final error?) throw error;
    finished = true;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  late Directory root;
  late Directory support;
  late Directory cache;
  late _RecordingZip zip;
  late SyncLegacyDataExporter exporter;

  Future<File> put(String path, List<int> bytes) async {
    final file = File(p.join(support.path, path));
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  Future<String> export({
    void Function(int, int)? progress,
    bool Function()? cancelled,
  }) => exporter.export(
    onProgress: progress ?? (_, _) {},
    isCancelled: cancelled ?? () => false,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('legacy-export-test-');
    support = Directory(p.join(root.path, 'support'));
    cache = await Directory(p.join(root.path, 'cache')).create();
    await put('database/default.isar', [0, 255, 13]);
    zip = _RecordingZip();
    exporter = SyncLegacyDataExporter.forTesting(
      support: support,
      cache: cache,
      openZip: (path) async {
        await File(path).create();
        return zip;
      },
    );
  });
  tearDown(() => root.delete(recursive: true));

  test('cleans obsolete export directories before opening the ZIP', () async {
    final stale = Directory(p.join(cache.path, 'legacy-export-stale'));
    await stale.create();
    await File(p.join(stale.path, 'unfinished.zip')).create();
    final unrelated = await Directory(p.join(cache.path, 'other')).create();
    final link = await Link(p.join(cache.path, 'legacy-export-link'))
        .create(unrelated.path);
    final regular = await File(p.join(cache.path, 'legacy-export-file'))
        .create();
    exporter = SyncLegacyDataExporter.forTesting(
      support: support,
      cache: cache,
      openZip: (_) async {
        expect(await stale.exists(), isFalse);
        expect(await unrelated.exists(), isTrue);
        expect(await link.exists(), isTrue);
        expect(await regular.exists(), isTrue);
        return zip;
      },
    );
    await export();
  });

  test(
    'exports the database and only regular legacy media files with Deflate',
    () async {
      final media = [
        'audio/nested/a',
        'video/v',
        'image/照片.jpg',
        'font/typeface',
      ];
      for (final path in media) {
        await put(path, [42]);
      }
      for (final path in [
        'database/moodiary.db',
        'image/thumb/nested/x',
        'file/unused',
      ]) {
        await put(path, [77]);
      }
      await Directory(p.join(support.path, 'image', 'empty')).create();
      await Link(p.join(support.path, 'image', 'linked'))
          .create(p.join(support.path, 'database'));
      expect(await exporter.inspect(), (
        databaseBytes: 3,
        mediaCount: 4,
        mediaBytes: 4,
      ));
      final updates = <(int, int)>[];
      final path = await export(
        progress: (done, total) => updates.add((done, total)),
      );
      expect(p.basename(path), matches(r'^心绪日记\d{4}-\d{2}-\d{2}备份\.zip$'));
      expect(
        zip.files.keys,
        unorderedEquals([matches(r'^\d+\.isar$'), ...media]),
      );
      expect(zip.files.values.first, [0, 255, 13]);
      expect(zip.finished && zip.disposed, isTrue);
      expect(updates, [for (var done = 0; done <= 5; done++) (done, 5)]);
    },
  );

  test(
    'cancellation between files releases the writer and removes its directory',
    () async {
      await put('image/photo', [1]);
      var processed = 0;
      await expectLater(
        export(
          progress: (done, _) => processed = done,
          cancelled: () => processed == 1,
        ),
        throwsA(isA<LegacyExportCancelled>()),
      );
      expect(zip.files, hasLength(1));
      expect(zip.disposed, isTrue);
      expect(cache.listSync(), isEmpty);
    },
  );

  for (final error in [
    const FileSystemException('write failed', '', OSError('disk full', 28)),
    StateError('No space left on device'),
    StateError('failed to finish ZIP (os error 28)'),
  ]) {
    test('maps $error and deletes the partial archive', () async {
      zip.writeError = error;
      await expectLater(
        export(),
        throwsA(isA<LegacyExportInsufficientSpace>()),
      );
      expect(zip.disposed, isTrue);
      expect(cache.listSync(), isEmpty);
    });
  }

  test('rejects an entry exceeding the ZIP32 limit before writing', () async {
    final oversized = await put('video/large', []);
    final handle = await oversized.open(mode: FileMode.write);
    try {
      await handle.truncate(1 << 32);
    } finally {
      await handle.close();
    }
    await expectLater(
      export(),
      throwsA(
        isA<LegacyExportFileTooLarge>().having(
          (error) => error.path,
          'path',
          'video/large',
        ),
      ),
    );
    expect(cache.listSync(), isEmpty);
  });
}
