import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/impl/local_archive.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

/// 内存归档 sink：记录条目字节，断言导出布局。
final class MemoryArchiveSink implements ArchiveSink {
  final Map<String, Uint8List> entries = {};

  @override
  Future<void> addBytes(String zipPath, Uint8List data) async {
    entries[zipPath] = data;
  }

  @override
  Future<void> addLocalFile(String zipPath, String filePath) async {
    entries[zipPath] = Uint8List(0);
  }

  @override
  Future<void> finish() async {}
}

void main() {
  late SyncLogger logger;

  setUp(() async {
    logger = (await setUpSyncEnv()).logger;
    await configureBackend(.webdav);
  });

  tearDown(tearDownSyncEnv);

  IncrementalSyncEngine engineOn(
    FakeRemoteBackend backend, {
    FakeDiaryStore? diaries,
    FakeMediaInfoStore? mediaInfos,
    FakeTombstoneStore? tombstones,
  }) {
    final tombstoneStore =
        tombstones ??
        diaries?.tombstones ??
        mediaInfos?.tombstones ??
        FakeTombstoneStore();
    return IncrementalSyncEngine(
      backend,
      logger: logger,
      diaryStore: diaries ?? FakeDiaryStore(const [], tombstoneStore),
      categoryStore: FakeCategoryStore(const [], tombstoneStore),
      mediaInfoStore:
          mediaInfos ?? FakeMediaInfoStore(const [], tombstoneStore),
      tombstoneStore: tombstoneStore,
      mediaFiles: FakeMediaFiles(),
      cipherProvider: () async => SyncCipher.plaintext,
      concurrency: 4,
    );
  }

  group('mediaInfo push/pull 往返', () {
    test('push 写 mediainfo/<type>/ 对象与 m: 条目，pull 在另一端落库', () async {
      final backend = FakeRemoteBackend();
      final sender = FakeMediaInfoStore([
        buildMediaInfo(
          fileName: 'audio-1.m4a',
          modifiedMs: 100,
          name: '深夜长谈',
          durationMs: 125000,
        ),
      ]);
      final report = await engineOn(backend, mediaInfos: sender).push();
      expect(report.failed, 0);
      expect(report.mediaInfoCount, 1);
      expect(
        backend.objects.containsKey('mediainfo/audio/audio-1.m4a.json'),
        isTrue,
      );

      final receiver = FakeMediaInfoStore();
      final pulled = await engineOn(backend, mediaInfos: receiver).pull();
      expect(pulled.failed, 0);
      expect(pulled.mediaInfoCount, 1);
      final row = receiver.mediaInfos['audio-1.m4a'];
      expect(row, isNotNull);
      expect(row!.name, '深夜长谈');
      expect(row.durationMs, 125000);
    });

    test('LWW：远端不新于本地时不覆盖（改名不被旧远端抹掉）', () async {
      final backend = FakeRemoteBackend();
      await engineOn(
        backend,
        mediaInfos: FakeMediaInfoStore([
          buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 100, name: '旧名'),
        ]),
      ).push();

      final local = FakeMediaInfoStore([
        buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 200, name: '新名'),
      ]);
      final pulled = await engineOn(backend, mediaInfos: local).pull();
      expect(pulled.failed, 0);
      expect(local.mediaInfos['audio-1.m4a']!.name, '新名');
    });

    test('墓碑推送删除远端对象，另一端 pull 后行随之删除', () async {
      final backend = FakeRemoteBackend();
      // 设备 A 推上去，设备 B 也拉到本地。
      await engineOn(
        backend,
        mediaInfos: FakeMediaInfoStore([
          buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 100),
        ]),
      ).push();
      final deviceB = FakeMediaInfoStore();
      await engineOn(backend, mediaInfos: deviceB).pull();
      expect(deviceB.mediaInfos, isNotEmpty);

      // 设备 A 删除（行硬删 + 墓碑），push 墓碑。
      final tombstones = FakeTombstoneStore();
      tombstones.rows['m:audio-1.m4a'] = buildMediaInfoTombstone(
        'audio-1.m4a',
        modifiedMs: 200,
      );
      final pushReport = await engineOn(
        backend,
        mediaInfos: FakeMediaInfoStore(const [], tombstones),
        tombstones: tombstones,
      ).push();
      expect(pushReport.failed, 0);
      expect(
        backend.objects.containsKey('mediainfo/audio/audio-1.m4a.json'),
        isFalse,
        reason: '墓碑提交后远端对象应被删除',
      );

      // 设备 B pull 应用墓碑。
      final pulled = await engineOn(backend, mediaInfos: deviceB).pull();
      expect(pulled.failed, 0);
      expect(deviceB.mediaInfos, isEmpty);
      expect(deviceB.tombstones.rows.containsKey('m:audio-1.m4a'), isTrue);
    });

    test('对象身份不符计 failed 不落库', () async {
      final backend = FakeRemoteBackend();
      await engineOn(
        backend,
        mediaInfos: FakeMediaInfoStore([
          buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 100),
        ]),
      ).push();
      // 篡改远端对象：manifest 键指向 audio-1，对象却自称 audio-2。
      final tampered = buildMediaInfo(fileName: 'audio-2.m4a', modifiedMs: 100);
      backend.objects['mediainfo/audio/audio-1.m4a.json'] = await SyncCipher
          .plaintext
          .encode(tampered.toJson());
      final receiver = FakeMediaInfoStore();
      final pulled = await engineOn(backend, mediaInfos: receiver).pull();
      expect(pulled.failed, 1);
      expect(receiver.mediaInfos, isEmpty);
    });
  });

  test('未知前缀墓碑不打断 push，正常条目照常推送', () async {
    final backend = FakeRemoteBackend();
    final tombstones = FakeTombstoneStore();
    tombstones.rows['z:weird'] = SyncTombstone(
      key: 'z:weird',
      timeMs: atMs(100).millisecondsSinceEpoch,
      pushedBackends: const [],
    );
    final sender = FakeMediaInfoStore([
      buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 100),
    ], tombstones);
    final report = await engineOn(
      backend,
      mediaInfos: sender,
      tombstones: tombstones,
    ).push();
    expect(report.failed, 0);
    expect(report.mediaInfoCount, 1);
    // 脏行原样保留，不推送也不清除。
    expect(tombstones.rows.containsKey('z:weird'), isTrue);
  });

  group('mediaInfo 本地归档', () {
    test('导出 manifest 含 m: 条目，writeArchive 落 mediainfo 对象', () async {
      final manifest = await LocalArchive.buildManifest(
        diaries: const [],
        categories: const [],
        mediaInfos: [
          buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 100, name: 'n'),
        ],
        tombstones: const [],
        mediaBaseDir: '/nonexistent',
      );
      expect(manifest.entries.containsKey('m:audio-1.m4a'), isTrue);

      final sink = MemoryArchiveSink();
      final count = await LocalArchive.writeArchive(
        sink: sink,
        diaries: const [],
        categories: const [],
        mediaInfos: [
          buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 100, name: 'n'),
        ],
        tombstones: const [],
        mediaBaseDir: '/nonexistent',
      );
      expect(count, 1);
      expect(
        sink.entries.containsKey('mediainfo/audio/audio-1.m4a.json'),
        isTrue,
      );
    });

    test('增量导出：对方已是最新的 mediaInfo 条目不进包', () async {
      final remote = SyncManifest(
        version: SyncManifest.currentVersion,
        updatedAtMs: 0,
        entries: {
          'm:audio-1.m4a': ManifestEntry(
            timeMs: atMs(200).millisecondsSinceEpoch,
          ),
        },
      );
      final sink = MemoryArchiveSink();
      final count = await LocalArchive.writeArchive(
        sink: sink,
        diaries: const [],
        categories: const [],
        mediaInfos: [buildMediaInfo(fileName: 'audio-1.m4a', modifiedMs: 100)],
        tombstones: const [],
        mediaBaseDir: '/nonexistent',
        remote: remote,
      );
      expect(count, 0);
    });
  });
}
