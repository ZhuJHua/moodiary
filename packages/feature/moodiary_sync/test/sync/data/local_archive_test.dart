import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sync/src/data/impl/local_archive.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:path/path.dart' as p;

import '../sync_test_harness.dart';

/// 内存归档 sink：记录条目字节，断言导出布局。
final class MemoryArchiveSink implements ArchiveSink {
  final Map<String, Uint8List> entries = {};
  final List<String> localFiles = [];
  bool finished = false;

  @override
  Future<void> addBytes(String zipPath, Uint8List data) async {
    entries[zipPath] = data;
  }

  @override
  Future<void> addLocalFile(String zipPath, String filePath) async {
    localFiles.add('$zipPath <- $filePath');
    entries[zipPath] = await File(filePath).readAsBytes();
  }

  @override
  Future<void> finish() async => finished = true;

  Map<String, dynamic> json(String zipPath) =>
      jsonDecode(utf8.decode(entries[zipPath]!)) as Map<String, dynamic>;
}

/// 目录归档 sink：直接写出「解压后」的目录，喂给 importDirectory 做回环测试。
final class DirArchiveSink implements ArchiveSink {
  final String root;

  DirArchiveSink(this.root);

  File _file(String zipPath) => File(p.join(root, zipPath));

  @override
  Future<void> addBytes(String zipPath, Uint8List data) async {
    final f = _file(zipPath);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(data);
  }

  @override
  Future<void> addLocalFile(String zipPath, String filePath) async {
    final f = _file(zipPath);
    await f.parent.create(recursive: true);
    await File(filePath).copy(f.path);
  }

  @override
  Future<void> finish() async {}
}

void main() {
  late Directory tmp;

  setUp(() async {
    await setUpSyncEnv();
    tmp = await Directory.systemTemp.createTemp('local-archive-test-');
  });

  tearDown(() async {
    await tearDownSyncEnv();
    await tmp.delete(recursive: true);
  });

  /// 在临时媒体目录写一个假媒体文件。
  Future<void> putMedia(String type, String name) async {
    final f = File(p.join(tmp.path, 'media-src', type, name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(utf8.encode(name));
  }

  String mediaSrc() => p.join(tmp.path, 'media-src');

  group('writeArchive 布局', () {
    test('普通条目 + tombstone + 媒体缺失 → 与远端布局一致', () async {
      await putMedia('image', 'img-1.png');
      await putMedia('video', 'video-abc.mp4');
      await putMedia('video', 'thumbnail-abc.jpeg');
      // audio-1.m4a 故意缺失

      final sink = MemoryArchiveSink();
      await LocalArchive.writeArchive(
        sink: sink,
        diaries: [
          buildDiary(
            id: 'd1',
            modifiedMs: 100,
            title: 'hello',
            images: ['img-1.png'],
            audios: ['audio-1.m4a'],
            videos: ['video-abc.mp4'],
          ),
        ],
        categories: [buildCategory(id: 'c1', modifiedMs: 50)],
        tombstones: [
          buildDiaryTombstone('d2', modifiedMs: 200),
          buildCategoryTombstone('c2', modifiedMs: 60),
        ],
        mediaBaseDir: mediaSrc(),
      );

      expect(sink.finished, isTrue);
      expect(
        sink.entries.keys,
        containsAll([
          'manifest.json',
          'diary/d1.json',
          'category/c1.json',
          'media/image/img-1.png',
          'media/video/video-abc.mp4',
          'media/video/thumbnail-abc.jpeg',
        ]),
      );
      // tombstone 不带 body
      expect(sink.entries.containsKey('diary/d2.json'), isFalse);
      expect(sink.entries.containsKey('category/c2.json'), isFalse);
      // 本地缺失的媒体不进包
      expect(sink.entries.containsKey('media/audio/audio-1.m4a'), isFalse);

      final manifest = SyncManifest.fromJson(sink.json('manifest.json'));
      expect(manifest.version, SyncManifest.currentVersion);
      final d1 = manifest.entries['d:d1']!;
      expect(d1.deleted, isFalse);
      expect(d1.timeMs, atMs(100).millisecondsSinceEpoch);
      // manifest 只声明真实进包的媒体
      expect(
        d1.media,
        unorderedEquals([
          'image/img-1.png',
          'video/video-abc.mp4',
          'video/thumbnail-abc.jpeg',
        ]),
      );
      expect(manifest.entries['d:d2']!.deleted, isTrue);
      expect(manifest.entries['c:c1']!.deleted, isFalse);
      expect(manifest.entries['c:c2']!.deleted, isTrue);

      final diaryJson = sink.json('diary/d1.json');
      expect(diaryJson['title'], 'hello');
    });

    test('多篇日记共享同一媒体只进包一次，但都写进各自 manifest 条目', () async {
      await putMedia('image', 'shared.png');
      final sink = MemoryArchiveSink();
      await LocalArchive.writeArchive(
        sink: sink,
        diaries: [
          buildDiary(id: 'a', images: ['shared.png']),
          buildDiary(id: 'b', images: ['shared.png']),
        ],
        categories: const [],
        tombstones: const [],
        mediaBaseDir: mediaSrc(),
      );
      expect(sink.localFiles, hasLength(1));
      final manifest = SyncManifest.fromJson(sink.json('manifest.json'));
      expect(manifest.entries['d:a']!.media, ['image/shared.png']);
      expect(manifest.entries['d:b']!.media, ['image/shared.png']);
    });
  });

  group('writeArchive 增量（remote 非 null）', () {
    test('LWW 过滤：只发比对方新的，含 tombstone；对方没有的不发 tombstone', () async {
      final remote = SyncManifest(
        version: SyncManifest.currentVersion,
        updatedAtMs: 0,
        entries: {
          'd:newer-remote': ManifestEntry(
            timeMs: atMs(2000).millisecondsSinceEpoch,
          ),
          'd:older-remote': ManifestEntry(
            timeMs: atMs(1000).millisecondsSinceEpoch,
          ),
          'd:alive-remote': ManifestEntry(
            timeMs: atMs(1000).millisecondsSinceEpoch,
          ),
          'c:cat-old': ManifestEntry(timeMs: atMs(0).millisecondsSinceEpoch),
        },
      );
      final sink = MemoryArchiveSink();
      final count = await LocalArchive.writeArchive(
        sink: sink,
        diaries: [
          buildDiary(id: 'newer-remote', modifiedMs: 1000),
          buildDiary(id: 'older-remote', modifiedMs: 2000),
          buildDiary(id: 'brand-new', modifiedMs: 100),
        ],
        categories: [buildCategory(id: 'cat-old', modifiedMs: 500)],
        tombstones: [
          buildDiaryTombstone('alive-remote', modifiedMs: 2000),
          buildDiaryTombstone('unknown-tomb', modifiedMs: 2000),
        ],
        mediaBaseDir: mediaSrc(),
        remote: remote,
      );

      final manifest = SyncManifest.fromJson(sink.json('manifest.json'));
      expect(
        manifest.entries.keys,
        unorderedEquals([
          'd:older-remote',
          'd:alive-remote',
          'd:brand-new',
          'c:cat-old',
        ]),
      );
      expect(count, 4);
      expect(manifest.entries['d:alive-remote']!.deleted, isTrue);
      // 对方比本地新 → 不发；对方从未有过 → tombstone 无意义不发
      expect(sink.entries.containsKey('diary/newer-remote.json'), isFalse);
      expect(manifest.entries.containsKey('d:unknown-tomb'), isFalse);
      // 入选的普通条目带 body
      expect(sink.entries.containsKey('diary/older-remote.json'), isTrue);
      expect(sink.entries.containsKey('diary/brand-new.json'), isTrue);
      expect(sink.entries.containsKey('category/cat-old.json'), isTrue);
    });

    test('对方已有的媒体不进包，但仍留在条目 media 列表', () async {
      await putMedia('image', 'both.png');
      await putMedia('image', 'only-local.png');
      final remote = SyncManifest(
        version: SyncManifest.currentVersion,
        updatedAtMs: 0,
        entries: {
          'd:x': ManifestEntry(
            timeMs: atMs(0).millisecondsSinceEpoch,
            media: const ['image/both.png'],
          ),
        },
      );
      final sink = MemoryArchiveSink();
      await LocalArchive.writeArchive(
        sink: sink,
        diaries: [
          buildDiary(
            id: 'x',
            modifiedMs: 1000,
            images: ['both.png', 'only-local.png'],
          ),
        ],
        categories: const [],
        tombstones: const [],
        mediaBaseDir: mediaSrc(),
        remote: remote,
      );
      expect(sink.entries.containsKey('media/image/both.png'), isFalse);
      expect(sink.entries.containsKey('media/image/only-local.png'), isTrue);
      final manifest = SyncManifest.fromJson(sink.json('manifest.json'));
      expect(
        manifest.entries['d:x']!.media,
        unorderedEquals(['image/both.png', 'image/only-local.png']),
      );
    });

    test('对方已是最新 → 条目数 0', () async {
      final remote = SyncManifest(
        version: SyncManifest.currentVersion,
        updatedAtMs: 0,
        entries: {
          'd:a': ManifestEntry(timeMs: atMs(1000).millisecondsSinceEpoch),
        },
      );
      final sink = MemoryArchiveSink();
      final count = await LocalArchive.writeArchive(
        sink: sink,
        diaries: [buildDiary(id: 'a', modifiedMs: 1000)],
        categories: const [],
        tombstones: const [],
        mediaBaseDir: mediaSrc(),
        remote: remote,
      );
      expect(count, 0);
      final manifest = SyncManifest.fromJson(sink.json('manifest.json'));
      expect(manifest.entries, isEmpty);
    });
  });

  group('importDirectory LWW', () {
    /// 用 DirArchiveSink 生成「解压后」目录。
    Future<String> buildArchiveDir({
      required List<Diary> diaries,
      List<Category> categories = const [],
      List<SyncTombstone> tombstones = const [],
    }) async {
      final dir = p.join(tmp.path, 'archive');
      await LocalArchive.writeArchive(
        sink: DirArchiveSink(dir),
        diaries: diaries,
        categories: categories,
        tombstones: tombstones,
        mediaBaseDir: mediaSrc(),
      );
      return dir;
    }

    test('缺 manifest.json → SyncException', () async {
      final dir = p.join(tmp.path, 'empty');
      await Directory(dir).create(recursive: true);
      expect(
        () => LocalArchive.importDirectory(dir),
        throwsA(isA<SyncException>()),
      );
    });

    test('归档较新 → 覆盖本地；本地较新 → 保留', () async {
      final dir = await buildArchiveDir(
        diaries: [
          buildDiary(id: 'newer', modifiedMs: 2000, title: 'from-archive'),
          buildDiary(id: 'older', modifiedMs: 1000, title: 'from-archive'),
        ],
      );
      final diaryStore = FakeDiaryStore([
        buildDiary(id: 'newer', modifiedMs: 1000, title: 'local'),
        buildDiary(id: 'older', modifiedMs: 2000, title: 'local'),
      ]);
      final report = await LocalArchive.importDirectory(
        dir,
        diaryStore: diaryStore,
        categoryStore: FakeCategoryStore(),
        tombstoneStore: diaryStore.tombstones,
        mediaFiles: FakeMediaFiles(),
      );
      expect(report.failed, 0);
      expect(report.diaryCount, 1);
      expect(diaryStore.diaries['newer']!.title, 'from-archive');
      expect(diaryStore.diaries['older']!.title, 'local');
    });

    test('新增日记连媒体一起落地', () async {
      await putMedia('image', 'img-1.png');
      final dir = await buildArchiveDir(
        diaries: [
          buildDiary(id: 'fresh', modifiedMs: 100, images: ['img-1.png']),
        ],
        categories: [buildCategory(id: 'c1', modifiedMs: 100)],
      );
      final diaryStore = FakeDiaryStore();
      final categoryStore = FakeCategoryStore();
      final mediaFiles = FakeMediaFiles();
      final report = await LocalArchive.importDirectory(
        dir,
        diaryStore: diaryStore,
        categoryStore: categoryStore,
        tombstoneStore: diaryStore.tombstones,
        mediaFiles: mediaFiles,
      );
      expect(report.failed, 0);
      expect(report.diaryCount, 1);
      expect(report.categoryCount, 1);
      expect(diaryStore.diaries.containsKey('fresh'), isTrue);
      // 归档导入不是云后端 pull：事件不带 fromSync，仍触发向云端的推送。
      expect(diaryStore.writeOrigins['fresh'], isFalse);
      expect(categoryStore.categories.containsKey('c1'), isTrue);
      expect(mediaFiles.files.containsKey('image/img-1.png'), isTrue);
      expect(mediaFiles.files['image/img-1.png'], utf8.encode('img-1.png'));
    });

    test('归档 tombstone 较新 → 删本地落墓碑并清媒体；本地较新 → 保留', () async {
      final dir = await buildArchiveDir(
        diaries: const [],
        tombstones: [
          buildDiaryTombstone('dead', modifiedMs: 2000),
          buildDiaryTombstone('alive', modifiedMs: 1000),
        ],
      );
      final diaryStore = FakeDiaryStore([
        buildDiary(id: 'dead', modifiedMs: 1000, images: ['img-1.png']),
        buildDiary(id: 'alive', modifiedMs: 2000),
      ]);
      final mediaFiles = FakeMediaFiles()..put('image', 'img-1.png');
      final report = await LocalArchive.importDirectory(
        dir,
        diaryStore: diaryStore,
        categoryStore: FakeCategoryStore(),
        tombstoneStore: diaryStore.tombstones,
        mediaFiles: mediaFiles,
      );
      expect(report.failed, 0);
      expect(diaryStore.diaries.containsKey('dead'), isFalse);
      expect(diaryStore.tombstones.rows.containsKey('d:dead'), isTrue);
      expect(
        diaryStore.writeOrigins['dead'],
        isFalse,
        reason: '归档导入应用的删除仍需推送到云端',
      );
      expect(mediaFiles.files.containsKey('image/img-1.png'), isFalse);
      expect(
        diaryStore.diaries.containsKey('alive'),
        isTrue,
        reason: '本地比归档 tombstone 新 → 保留',
      );
    });

    test('导入不推进 lastSyncTime', () async {
      final dir = await buildArchiveDir(
        diaries: [buildDiary(id: 'd1', modifiedMs: 100)],
      );
      await LocalArchive.importDirectory(
        dir,
        diaryStore: FakeDiaryStore(),
        categoryStore: FakeCategoryStore(),
        tombstoneStore: FakeTombstoneStore(),
        mediaFiles: FakeMediaFiles(),
      );
      expect(MoodiaryKVs.lastSyncTime.get(), anyOf(isNull, 0));
    });
  });
}
