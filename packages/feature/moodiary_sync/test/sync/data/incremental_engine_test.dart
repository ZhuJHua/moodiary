import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

void main() {
  late SyncLogger logger;

  setUp(() async {
    logger = (await setUpSyncEnv()).logger;
    // 默认把 webdav 标记为唯一已配置后端，使单后端 tombstone 推完即可硬删。
    await configureBackend(SyncProviderType.webdav);
  });

  tearDown(tearDownSyncEnv);

  IncrementalSyncEngine engineOn(
    FakeRemoteBackend backend, {
    FakeDiaryStore? diaries,
    FakeCategoryStore? categories,
    FakeTombstoneStore? tombstones,
    FakeMediaFiles? media,
    int concurrency = 4,
  }) {
    // 引擎与日记/分类 store 必须共享同一墓碑表（镜像真实仓储的同库不变量）。
    final tombstoneStore =
        tombstones ??
        diaries?.tombstones ??
        categories?.tombstones ??
        FakeTombstoneStore();
    return IncrementalSyncEngine(
      backend,
      logger: logger,
      diaryStore: diaries ?? FakeDiaryStore(const [], tombstoneStore),
      categoryStore: categories ?? FakeCategoryStore(const [], tombstoneStore),
      tombstoneStore: tombstoneStore,
      mediaFiles: media ?? FakeMediaFiles(),
      cipherProvider: () async => SyncCipher.plaintext,
      concurrency: concurrency,
    );
  }

  /// 用一个独立 store 的引擎把 [diaries]/[cats] push 到 [backend]，模拟「另一台设备
  /// 已经同步过」。[media] 须含被引用的媒体文件，否则不会被声明进 manifest。
  Future<void> seedRemote(
    FakeRemoteBackend backend, {
    List<dynamic> diaries = const [],
    List<dynamic> cats = const [],
    FakeMediaFiles? media,
  }) async {
    await IncrementalSyncEngine(
      backend,
      logger: logger,
      diaryStore: FakeDiaryStore(diaries.cast()),
      categoryStore: FakeCategoryStore(cats.cast()),
      tombstoneStore: FakeTombstoneStore(),
      mediaFiles: media ?? FakeMediaFiles(),
      cipherProvider: () async => SyncCipher.plaintext,
      concurrency: 4,
    ).push();
  }

  Uint8List jsonBytes(Object v) =>
      Uint8List.fromList(utf8.encode(jsonEncode(v)));

  group('push — first sync', () {
    test('uploads all diaries + categories and writes a v4 manifest', () async {
      final backend = FakeRemoteBackend();
      final store = FakeDiaryStore([
        buildDiary(id: 'a', modifiedMs: 100, title: 'A'),
        buildDiary(id: 'b', modifiedMs: 200, title: 'B'),
      ]);
      final cats = FakeCategoryStore([buildCategory(id: 'c1', modifiedMs: 50)]);

      final report = await engineOn(
        backend,
        diaries: store,
        categories: cats,
      ).push();

      expect(report.diaryCount, 2);
      expect(report.categoryCount, 1);
      expect(report.failed, 0);
      expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isTrue);
      expect(backend.hasObject(SyncKeys.diaryObjectPath('b')), isTrue);
      expect(backend.hasObject(SyncKeys.categoryObjectPath('c1')), isTrue);

      final manifest = backend.manifest()!;
      expect(manifest.version, SyncManifest.currentVersion);
      expect(manifest.entries.keys, containsAll(['d:a', 'd:b', 'c:c1']));
      expect(manifest.entries['d:a']!.timeMs, atMs(100).millisecondsSinceEpoch);
      // 成功且无失败 → 推进「上次同步时间」。
      expect(MoodiaryKVs.lastSyncTime.get(), greaterThan(0));
    });

    test('does not write manifest when there is nothing to push', () async {
      final backend = FakeRemoteBackend();
      final report = await engineOn(backend).push();
      expect(report.diaryCount, 0);
      expect(backend.opCount('write', SyncKeys.manifestPath), 0);
      expect(backend.manifest(), isNull);
    });
  });

  group('push — open-diary skip', () {
    test('skips diaries open in the editor, uploads the rest', () async {
      final backend = FakeRemoteBackend();
      final store = FakeDiaryStore([
        buildDiary(id: 'open', modifiedMs: 100, title: 'editing'),
        buildDiary(id: 'closed', modifiedMs: 100, title: 'done'),
      ]);
      OpenDiaryRegistry.instance.open('open');
      addTearDown(() => OpenDiaryRegistry.instance.close('open'));

      final report = await engineOn(backend, diaries: store).push();

      expect(report.diaryCount, 1);
      expect(backend.hasObject(SyncKeys.diaryObjectPath('closed')), isTrue);
      expect(backend.hasObject(SyncKeys.diaryObjectPath('open')), isFalse);
      // 被跳过的日记不进 manifest。
      expect(backend.manifest()!.entries.keys, isNot(contains('d:open')));
    });

    test('uploads a previously-open diary once it is closed', () async {
      final backend = FakeRemoteBackend();
      final store = FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 100)]);

      OpenDiaryRegistry.instance.open('a');
      addTearDown(() => OpenDiaryRegistry.instance.close('a'));
      final first = await engineOn(backend, diaries: store).push();
      expect(first.diaryCount, 0);
      expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isFalse);

      OpenDiaryRegistry.instance.close('a');
      final second = await engineOn(backend, diaries: store).push();
      expect(second.diaryCount, 1);
      expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isTrue);
    });
  });

  group('push — dirty badge', () {
    test('clears 待同步 for an uploaded diary after commit', () async {
      final backend = FakeRemoteBackend();
      final store = FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 100)]);
      SyncDirtyTracker.instance.markDirty('a');
      addTearDown(() => SyncDirtyTracker.instance.clearDirty('a'));

      await engineOn(backend, diaries: store).push();

      expect(SyncDirtyTracker.instance.listenable.value.contains('a'), isFalse);
    });

    test('keeps 待同步 for a diary skipped because it is open', () async {
      final backend = FakeRemoteBackend();
      final store = FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 100)]);
      SyncDirtyTracker.instance.markDirty('a');
      OpenDiaryRegistry.instance.open('a');
      addTearDown(() {
        SyncDirtyTracker.instance.clearDirty('a');
        OpenDiaryRegistry.instance.close('a');
      });

      await engineOn(backend, diaries: store).push();

      // 被「打开中」过滤、未上传 → 仍保留待同步角标。
      expect(SyncDirtyTracker.instance.listenable.value.contains('a'), isTrue);
    });
  });

  group('push — last-writer-wins (millisecond int)', () {
    test('skips re-upload when local is not newer than remote', () async {
      final backend = FakeRemoteBackend();
      final store = FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 1000)]);
      await engineOn(backend, diaries: store).push();
      final firstWrites = backend.opCount(
        'write',
        SyncKeys.diaryObjectPath('a'),
      );

      // 同一份本地（时间戳不变）再 push 一次 → 不应重传。
      final report = await engineOn(backend, diaries: store).push();
      expect(report.diaryCount, 0);
      expect(
        backend.opCount('write', SyncKeys.diaryObjectPath('a')),
        firstWrites,
      );
    });

    test('re-uploads when local is strictly newer', () async {
      final backend = FakeRemoteBackend();
      await engineOn(
        backend,
        diaries: FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 1000)]),
      ).push();

      final report = await engineOn(
        backend,
        diaries: FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 2000)]),
      ).push();
      expect(report.diaryCount, 1);
      expect(
        backend.manifest()!.entries['d:a']!.timeMs,
        atMs(2000).millisecondsSinceEpoch,
      );
    });

    test('skips when remote is newer than local', () async {
      final backend = FakeRemoteBackend();
      await engineOn(
        backend,
        diaries: FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 2000)]),
      ).push();
      final writes = backend.opCount('write', SyncKeys.diaryObjectPath('a'));

      final report = await engineOn(
        backend,
        diaries: FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 1000)]),
      ).push();
      expect(report.diaryCount, 0);
      expect(backend.opCount('write', SyncKeys.diaryObjectPath('a')), writes);
      expect(
        backend.manifest()!.entries['d:a']!.timeMs,
        atMs(2000).millisecondsSinceEpoch,
      );
    });
  });

  group('push — media', () {
    test(
      'uploads media BEFORE the diary JSON and records confirmed refs',
      () async {
        final backend = FakeRemoteBackend();
        final media = FakeMediaFiles()..put('image', 'img-1.jpg');
        final store = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 100, images: ['img-1.jpg']),
        ]);

        await engineOn(backend, diaries: store, media: media).push();

        final mediaWrite = backend.ops.indexOf('write media/image/img-1.jpg');
        final jsonWrite = backend.ops.indexOf(
          'write ${SyncKeys.diaryObjectPath('a')}',
        );
        expect(mediaWrite, greaterThanOrEqualTo(0));
        expect(
          jsonWrite,
          greaterThan(mediaWrite),
          reason: '媒体必须先于 diary JSON 上传',
        );
        expect(backend.manifest()!.entries['d:a']!.media, ['image/img-1.jpg']);
      },
    );

    test(
      'locally-missing media is skipped, not claimed in manifest, no failure',
      () async {
        final backend = FakeRemoteBackend();
        // 媒体文件本地缺失（FakeMediaFiles 为空）。
        final store = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 100, images: ['gone.jpg']),
        ]);

        final report = await engineOn(backend, diaries: store).push();
        expect(report.failed, 0);
        expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isTrue);
        // 本地缺失的引用绝不能写进 manifest（否则谎报存在、永失补传机会）。
        expect(backend.manifest()!.entries['d:a']!.media, isEmpty);
        expect(backend.hasObject('media/image/gone.jpg'), isFalse);
      },
    );

    test(
      'a real media upload failure aborts the diary JSON write (no broken ref)',
      () async {
        final backend = FakeRemoteBackend();
        final media = FakeMediaFiles()..put('image', 'img-1.jpg');
        backend.beforeOp = (op, key) {
          if (op == 'write' && key == 'media/image/img-1.jpg') {
            throw const SyncException('boom');
          }
        };
        final store = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 100, images: ['img-1.jpg']),
        ]);

        final report = await engineOn(
          backend,
          diaries: store,
          media: media,
        ).push();
        expect(report.failed, 1);
        // 媒体上传失败 → diary JSON 不得写入（避免远端 JSON 引用到未上传的媒体）。
        expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isFalse);
        expect(
          backend.manifest()?.entries.containsKey('d:a') ?? false,
          isFalse,
        );
        // 有失败条目 → 不推进上次同步时间。
        expect(MoodiaryKVs.lastSyncTime.get(), 0);
      },
    );

    test(
      'deferred stale-media delete spares media re-referenced by another diary',
      () async {
        // 回归：A 把共享媒体 R 判为 stale 后,同一次 push 里新日记 B 又引用了 R。
        // 推迟删除必须按终态 manifest 再确认——R 仍被 B 引用,不能删（否则 B 破图）。
        final backend = FakeRemoteBackend();
        final media = FakeMediaFiles()..put('image', 'R.jpg');
        // 远端已有 A 引用 R。
        await seedRemote(
          backend,
          diaries: [
            buildDiary(id: 'a', modifiedMs: 100, images: ['R.jpg']),
          ],
          media: media,
        );
        expect(backend.hasObject('media/image/R.jpg'), isTrue);

        // 本地：A 改成不再引用 R；新增 B 引用同一个 R。顺序 [a, b] + 串行,确保 A 先处理。
        final local = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 200, images: []),
          buildDiary(id: 'b', modifiedMs: 150, images: ['R.jpg']),
        ]);
        await engineOn(
          backend,
          diaries: local,
          media: media,
          concurrency: 1,
        ).push();

        expect(
          backend.hasObject('media/image/R.jpg'),
          isTrue,
          reason: 'R 仍被 B 引用,推迟删除应跳过它',
        );
        expect(backend.manifest()!.entries['d:b']!.media, ['image/R.jpg']);
        expect(backend.manifest()!.entries['d:a']!.media, isEmpty);
      },
    );

    test('removes remote media no longer referenced after an edit', () async {
      final backend = FakeRemoteBackend();
      final media = FakeMediaFiles()
        ..put('image', 'old.jpg')
        ..put('image', 'new.jpg');
      // 先同步带 old.jpg 的版本。
      await engineOn(
        backend,
        diaries: FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 100, images: ['old.jpg']),
        ]),
        media: media,
      ).push();
      expect(backend.hasObject('media/image/old.jpg'), isTrue);

      // 编辑成只引用 new.jpg。
      await engineOn(
        backend,
        diaries: FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 200, images: ['new.jpg']),
        ]),
        media: media,
      ).push();

      expect(backend.hasObject('media/image/new.jpg'), isTrue);
      expect(
        backend.hasObject('media/image/old.jpg'),
        isFalse,
        reason: '不再被引用的旧媒体应从远端删除',
      );
      expect(backend.manifest()!.entries['d:a']!.media, ['image/new.jpg']);
    });
  });

  group('push — partial failure', () {
    test(
      'one failed diary does not block others and does not advance sync time',
      () async {
        final backend = FakeRemoteBackend();
        backend.beforeOp = (op, key) {
          if (op == 'write' && key == SyncKeys.diaryObjectPath('bad')) {
            throw const SyncException('boom');
          }
        };
        final store = FakeDiaryStore([
          buildDiary(id: 'ok', modifiedMs: 100),
          buildDiary(id: 'bad', modifiedMs: 200),
        ]);

        final report = await engineOn(backend, diaries: store).push();
        expect(report.failed, 1);
        expect(report.diaryCount, 1);
        expect(backend.hasObject(SyncKeys.diaryObjectPath('ok')), isTrue);
        expect(backend.hasObject(SyncKeys.diaryObjectPath('bad')), isFalse);
        // 失败条目不进 manifest → 下次 LWW 仍判本地更新会重试。
        expect(backend.manifest()!.entries.containsKey('d:bad'), isFalse);
        expect(MoodiaryKVs.lastSyncTime.get(), 0);
      },
    );
  });

  group('pull — first sync', () {
    test(
      'downloads remote diaries, categories and media into empty local',
      () async {
        final backend = FakeRemoteBackend();
        final remoteMedia = FakeMediaFiles()..put('image', 'p.jpg');
        await seedRemote(
          backend,
          diaries: [
            buildDiary(id: 'a', modifiedMs: 100, images: ['p.jpg']),
          ],
          cats: [buildCategory(id: 'c1', modifiedMs: 50)],
          media: remoteMedia,
        );

        final localDiaries = FakeDiaryStore();
        final localCats = FakeCategoryStore();
        final localMedia = FakeMediaFiles();
        final report = await engineOn(
          backend,
          diaries: localDiaries,
          categories: localCats,
          media: localMedia,
        ).pull();

        expect(report.diaryCount, 1);
        expect(report.categoryCount, 1);
        expect(localDiaries.diaries.containsKey('a'), isTrue);
        expect(localCats.categories.containsKey('c1'), isTrue);
        expect(await localMedia.exists('image', 'p.jpg'), isTrue);
      },
    );

    test('empty remote returns a warning and changes nothing', () async {
      final backend = FakeRemoteBackend();
      final local = FakeDiaryStore([buildDiary(id: 'x', modifiedMs: 1)]);
      final report = await engineOn(backend, diaries: local).pull();
      expect(report.diaryCount, 0);
      expect(report.warning, isNotNull);
      expect(local.diaries.containsKey('x'), isTrue);
    });
  });

  group('pull — last-writer-wins', () {
    test(
      'does not overwrite a newer local edit with an older remote',
      () async {
        final backend = FakeRemoteBackend();
        await seedRemote(
          backend,
          diaries: [buildDiary(id: 'a', modifiedMs: 1000, title: 'remote')],
        );

        final local = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 2000, title: 'local-newer'),
        ]);
        final report = await engineOn(backend, diaries: local).pull();
        expect(report.diaryCount, 0);
        expect(local.diaries['a']!.title, 'local-newer');
      },
    );

    test('downloads when remote is newer than local', () async {
      final backend = FakeRemoteBackend();
      await seedRemote(
        backend,
        diaries: [buildDiary(id: 'a', modifiedMs: 2000, title: 'remote-newer')],
      );

      final local = FakeDiaryStore([
        buildDiary(id: 'a', modifiedMs: 1000, title: 'local'),
      ]);
      final report = await engineOn(backend, diaries: local).pull();
      expect(report.diaryCount, 1);
      expect(local.diaries['a']!.title, 'remote-newer');
    });

    test(
      'backfills missing media on an otherwise-skipped (equal) entry',
      () async {
        final backend = FakeRemoteBackend();
        final remoteMedia = FakeMediaFiles()..put('image', 'p.jpg');
        await seedRemote(
          backend,
          diaries: [
            buildDiary(id: 'a', modifiedMs: 1000, images: ['p.jpg']),
          ],
          media: remoteMedia,
        );

        // 本地已有同版本 diary 但缺媒体（上次媒体下载失败）。
        final local = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 1000, images: ['p.jpg']),
        ]);
        final localMedia = FakeMediaFiles();
        final report = await engineOn(
          backend,
          diaries: local,
          media: localMedia,
        ).pull();
        expect(report.diaryCount, 0); // 没下载 diary
        expect(
          await localMedia.exists('image', 'p.jpg'),
          isTrue,
          reason: 'skip 分支也应补拉缺失媒体',
        );
      },
    );
  });

  group('pull — tombstone', () {
    test('soft-deletes a local diary and deletes its media', () async {
      final backend = FakeRemoteBackend();
      // 远端把 a 标记删除（tombstoneMs=2000）。
      backend.objects[SyncKeys.manifestPath] = jsonBytes({
        'version': 4,
        'updatedAt': 1,
        'entries': {
          'd:a': {'t': atMs(2000).millisecondsSinceEpoch, 'd': true},
        },
      });
      final local = FakeDiaryStore([
        buildDiary(id: 'a', modifiedMs: 1000, images: ['p.jpg']),
      ]);
      final media = FakeMediaFiles()..put('image', 'p.jpg');

      final report = await engineOn(
        backend,
        diaries: local,
        media: media,
      ).pull();
      expect(report.diaryCount, 1);
      expect(
        local.diaries.containsKey('a'),
        isFalse,
        reason: '远端 tombstone → 本地行硬删',
      );
      expect(
        local.tombstones.rows.containsKey('d:a'),
        isTrue,
        reason: '删除事实落墓碑表',
      );
      expect(await media.exists('image', 'p.jpg'), isFalse);
    });

    test(
      'keeps a local edit that is newer than the remote tombstone (fix [2])',
      () async {
        final backend = FakeRemoteBackend();
        backend.objects[SyncKeys.manifestPath] = jsonBytes({
          'version': 4,
          'updatedAt': 1,
          'entries': {
            'd:a': {'t': atMs(1000).millisecondsSinceEpoch, 'd': true},
          },
        });
        final local = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 2000, title: 'edited-after-delete'),
        ]);

        final report = await engineOn(backend, diaries: local).pull();
        expect(report.diaryCount, 0);
        expect(
          local.diaries['a']!.title,
          'edited-after-delete',
          reason: '本地比 tombstone 新 → 保留本地活跃版本',
        );
        expect(local.tombstones.rows, isEmpty);
      },
    );

    test(
      'writes the tombstone record BEFORE deleting media (fix [2] ordering)',
      () async {
        final backend = FakeRemoteBackend();
        backend.objects[SyncKeys.manifestPath] = jsonBytes({
          'version': 4,
          'updatedAt': 1,
          'entries': {
            'd:a': {'t': atMs(2000).millisecondsSinceEpoch, 'd': true},
          },
        });
        final local = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 1000, images: ['p.jpg']),
        ]);
        final media = FakeMediaFiles()..put('image', 'p.jpg');
        bool? tombstonedAtMediaDelete;
        media.onDelete = (type, name) {
          // 媒体删除时，记录必须已经落成墓碑（先落记录再删媒体），
          // 否则并发编辑可在「删媒体」与「写 tombstone」之间插入并丢失。
          tombstonedAtMediaDelete =
              !local.diaries.containsKey('a') &&
              local.tombstones.rows.containsKey('d:a');
        };

        await engineOn(backend, diaries: local, media: media).pull();
        expect(tombstonedAtMediaDelete, isTrue);
      },
    );

    test('skips a remote tombstone for a diary open in the editor', () async {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.manifestPath] = jsonBytes({
        'version': 4,
        'updatedAt': 1,
        'entries': {
          'd:a': {'t': atMs(2000).millisecondsSinceEpoch, 'd': true},
        },
      });
      final local = FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 1000)]);
      OpenDiaryRegistry.instance.open('a');
      addTearDown(() => OpenDiaryRegistry.instance.close('a'));

      final report = await engineOn(backend, diaries: local).pull();
      expect(report.diaryCount, 0);
      expect(
        local.diaries.containsKey('a'),
        isTrue,
        reason: '打开中的日记不应用远端删除（否则编辑器脚下抽行丢稿）',
      );
      expect(local.tombstones.rows, isEmpty);

      // 关闭后下一轮 pull 正常收敛。
      OpenDiaryRegistry.instance.close('a');
      final second = await engineOn(backend, diaries: local).pull();
      expect(second.diaryCount, 1);
      expect(local.diaries.containsKey('a'), isFalse);
      expect(local.tombstones.rows.containsKey('d:a'), isTrue);
    });
  });

  group('sync — pull then push in one critical section', () {
    test('merges remote-only and local-only entries', () async {
      final backend = FakeRemoteBackend();
      await seedRemote(
        backend,
        diaries: [buildDiary(id: 'remote', modifiedMs: 100)],
      );

      final local = FakeDiaryStore([buildDiary(id: 'local', modifiedMs: 200)]);
      final report = await engineOn(backend, diaries: local).sync();

      expect(local.diaries.keys, containsAll(['remote', 'local']));
      final manifest = backend.manifest()!;
      expect(manifest.entries.keys, containsAll(['d:remote', 'd:local']));
      expect(report.failed, 0);
    });
  });

  group('cancellation', () {
    test(
      'a requested stop skips remaining items and does not advance sync time',
      () async {
        final backend = FakeRemoteBackend();
        final store = FakeDiaryStore([
          buildDiary(id: 'a', modifiedMs: 100),
          buildDiary(id: 'b', modifiedMs: 200),
        ]);
        SyncCancellation.instance.requestStop();

        final report = await engineOn(backend, diaries: store).push();
        expect(report.cancelled, isTrue);
        expect(report.diaryCount, 0);
        expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isFalse);
        expect(MoodiaryKVs.lastSyncTime.get(), 0);
      },
    );
  });

  group(
    'multi-backend tombstone (never lose a deletion before all backends)',
    () {
      test(
        'hard-deletes only after EVERY configured backend received the tombstone',
        () async {
          // 两个云后端都已配置。
          await configureBackend(SyncProviderType.webdav);
          await configureBackend(SyncProviderType.s3);

          final webdav = FakeRemoteBackend(backendId: 'webdav');
          final s3 = FakeRemoteBackend(backendId: 's3');

          // 两个远端都已有 a 的普通条目。
          await seedRemote(
            webdav,
            diaries: [buildDiary(id: 'a', modifiedMs: 100)],
          );
          await seedRemote(s3, diaries: [buildDiary(id: 'a', modifiedMs: 100)]);

          // 本地把 a 删除（行已硬删，墓碑行承载删除事实）。共享同一墓碑表
          // （同一台设备切换后端）。
          final tombstones = FakeTombstoneStore([
            buildDiaryTombstone('a', modifiedMs: 200),
          ]);
          final local = FakeDiaryStore(const [], tombstones);

          // 推到 webdav：仅覆盖 webdav，未覆盖全部 → 墓碑行不得清除。
          await engineOn(webdav, diaries: local).push();
          expect(
            tombstones.rows.containsKey('d:a'),
            isTrue,
            reason: 'tombstone 未覆盖 s3 前不得清除墓碑行',
          );
          expect(tombstones.rows['d:a']!.pushedBackends, contains('webdav'));
          expect(webdav.manifest()!.entries['d:a']!.deleted, isTrue);

          // 切到 s3 再推：现在两后端都覆盖 → 清除墓碑行。
          await engineOn(s3, diaries: local).push();
          expect(
            tombstones.rows.containsKey('d:a'),
            isFalse,
            reason: '所有已配置后端都收到 tombstone 后才清除墓碑行',
          );
          expect(s3.manifest()!.entries['d:a']!.deleted, isTrue);
        },
      );
    },
  );

  group(
    'regression — corrupt remote manifest must not rebuild from zero (fix [1])',
    () {
      test(
        'a present-but-non-object manifest aborts push instead of dropping entries',
        () async {
          final backend = FakeRemoteBackend();
          // 远端 manifest 被外部写成 JSON 数组（合法 JSON 但不是对象）。
          backend.objects[SyncKeys.manifestPath] = jsonBytes(<dynamic>[]);
          final store = FakeDiaryStore([
            buildDiary(id: 'local', modifiedMs: 1),
          ]);

          await expectLater(
            engineOn(backend, diaries: store).push(),
            throwsA(isA<SyncException>()),
          );
          // 关键：绝不能把 manifest 重建/覆盖掉。
          expect(backend.opCount('write', SyncKeys.manifestPath), 0);
          expect(
            backend.objects[SyncKeys.manifestPath],
            jsonBytes(<dynamic>[]),
          );
        },
      );
    },
  );

  group(
    'regression — stale local deletion must not clobber newer remote (fix [5])',
    () {
      test('tombstone push skips when the remote entry is newer', () async {
        final backend = FakeRemoteBackend();
        // 远端有 a 的较新普通条目（来自别的设备的更新）。
        await seedRemote(
          backend,
          diaries: [
            buildDiary(id: 'a', modifiedMs: 2000, title: 'newer-remote'),
          ],
        );
        expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isTrue);

        // 本地持有一个过期的删除（删除时间早于远端更新）。
        final tombstones = FakeTombstoneStore([
          buildDiaryTombstone('a', modifiedMs: 1000),
        ]);
        final report = await engineOn(backend, tombstones: tombstones).push();

        expect(report.diaryCount, 0);
        // 远端较新的内容不得被旧 tombstone 删除/覆盖。
        expect(backend.hasObject(SyncKeys.diaryObjectPath('a')), isTrue);
        expect(backend.manifest()!.entries['d:a']!.deleted, isFalse);
        expect(
          backend.manifest()!.entries['d:a']!.timeMs,
          atMs(2000).millisecondsSinceEpoch,
        );
        // 未推送 → 墓碑行保留（下次 pull 按 LWW 复活时随复活清除）。
        expect(tombstones.rows.containsKey('d:a'), isTrue);
        expect(tombstones.rows['d:a']!.pushedBackends, isEmpty);
      });
    },
  );

  group('regression — concurrent manifest clobber aborts cleanly (lease CAS)', () {
    Uint8List foreignManifest() => jsonBytes({
      'version': 4,
      'updatedAt': 1,
      'w': 'another-device',
      'entries': {
        'd:a': {'t': atMs(100).millisecondsSinceEpoch},
      },
    });

    test(
      'write-then-readback token mismatch → throw, no remote/local destruction',
      () async {
        final backend = FakeRemoteBackend();
        // 远端已有普通条目 a + 其媒体。
        final media = FakeMediaFiles()..put('image', 'p.jpg');
        await seedRemote(
          backend,
          diaries: [
            buildDiary(id: 'a', modifiedMs: 100, images: ['p.jpg']),
          ],
          media: media,
        );

        // 本地删除 a（行已硬删、墓碑承载）：push 会想删远端 a.json + 媒体 + 清墓碑行。
        final tombstones = FakeTombstoneStore([
          buildDiaryTombstone('a', modifiedMs: 200),
        ]);

        // 注入并发覆盖：我们写完 manifest 后，回读时它已被另一台设备覆盖（不同 token）。
        var wroteManifest = false;
        backend.beforeOp = (op, key) {
          if (op == 'write' && key == SyncKeys.manifestPath) {
            wroteManifest = true;
          } else if (op == 'read' &&
              key == SyncKeys.manifestPath &&
              wroteManifest) {
            backend.objects[SyncKeys.manifestPath] = foreignManifest();
          }
        };

        final syncTimeBefore = MoodiaryKVs.lastSyncTime.get();
        await expectLater(
          engineOn(backend, tombstones: tombstones, media: media).push(),
          throwsA(isA<SyncException>()),
        );

        // 关键不变量：中止后远端对象 / 媒体都没被删，墓碑行也没清 / 没记推送，
        // 删除事实零丢失。
        expect(
          backend.hasObject(SyncKeys.diaryObjectPath('a')),
          isTrue,
          reason: '回读校验失败 → 推迟的远端删除不得执行',
        );
        expect(backend.hasObject('media/image/p.jpg'), isTrue);
        expect(
          tombstones.rows.containsKey('d:a'),
          isTrue,
          reason: '回读校验失败 → 不得清除墓碑行',
        );
        expect(
          tombstones.rows['d:a']!.pushedBackends,
          isEmpty,
          reason: '回读校验失败 → 推送记录不得落库',
        );
        // 抛错中止 → 不推进上次同步时间。
        expect(MoodiaryKVs.lastSyncTime.get(), syncTimeBefore);
      },
    );

    test(
      'normal push succeeds when readback token matches (deferred deletes run)',
      () async {
        final backend = FakeRemoteBackend();
        final media = FakeMediaFiles()
          ..put('image', 'old.jpg')
          ..put('image', 'new.jpg');
        await seedRemote(
          backend,
          diaries: [
            buildDiary(id: 'a', modifiedMs: 100, images: ['old.jpg']),
          ],
          media: media,
        );

        // 正常 push（无并发覆盖）：回读 token 命中 → 推迟的旧媒体删除照常执行。
        final report = await engineOn(
          backend,
          diaries: FakeDiaryStore([
            buildDiary(id: 'a', modifiedMs: 200, images: ['new.jpg']),
          ]),
          media: media,
        ).push();

        expect(report.failed, 0);
        expect(backend.hasObject('media/image/new.jpg'), isTrue);
        expect(
          backend.hasObject('media/image/old.jpg'),
          isFalse,
          reason: '提交校验通过后，推迟的旧媒体删除应执行',
        );
      },
    );
  });

  group('re-audit fixes', () {
    test(
      'category tombstone push skips when the remote category is newer (A)',
      () async {
        final backend = FakeRemoteBackend();
        await seedRemote(
          backend,
          cats: [
            buildCategory(id: 'c1', modifiedMs: 2000, name: 'newer-remote'),
          ],
        );
        expect(backend.hasObject(SyncKeys.categoryObjectPath('c1')), isTrue);

        // 本地持有过期的分类删除。
        final tombstones = FakeTombstoneStore([
          buildCategoryTombstone('c1', modifiedMs: 1000),
        ]);
        final report = await engineOn(backend, tombstones: tombstones).push();

        expect(report.categoryCount, 0);
        expect(
          backend.hasObject(SyncKeys.categoryObjectPath('c1')),
          isTrue,
          reason: '远端较新的分类不得被旧删除覆盖/删除',
        );
        expect(backend.manifest()!.entries['c:c1']!.deleted, isFalse);
      },
    );

    test(
      'pull counts a category local-write failure (no false success) (B)',
      () async {
        final backend = FakeRemoteBackend();
        await seedRemote(
          backend,
          cats: [buildCategory(id: 'c1', modifiedMs: 1000)],
        );
        await MoodiaryKVs.lastSyncTime.set(0); // 清掉 seed push 推进的时间

        final localCats = FakeCategoryStore()..insertSucceeds = false;
        final report = await engineOn(backend, categories: localCats).pull();

        expect(report.failed, greaterThan(0), reason: '本地写失败必须计入 failed');
        expect(localCats.categories.containsKey('c1'), isFalse);
        // 有失败 → 不推进上次同步时间。
        expect(MoodiaryKVs.lastSyncTime.get(), 0);
      },
    );

    test(
      'corrupt entries field (non-Map) aborts push, no manifest rebuild (C)',
      () async {
        final backend = FakeRemoteBackend();
        backend.objects[SyncKeys.manifestPath] = jsonBytes({
          'version': 4,
          'updatedAt': 1,
          'entries': 'corrupt-not-a-map',
        });
        final store = FakeDiaryStore([buildDiary(id: 'local', modifiedMs: 1)]);

        await expectLater(
          engineOn(backend, diaries: store).push(),
          throwsA(isA<SyncException>()),
        );
        expect(backend.opCount('write', SyncKeys.manifestPath), 0);
      },
    );

    test(
      'emits a syncEnd even when push throws (auto-sync gate safety) (D)',
      () async {
        final backend = FakeRemoteBackend();
        backend.objects[SyncKeys.manifestPath] = jsonBytes(<dynamic>[]); // 触发抛错
        final kinds = <SyncEventKind>[];
        final sub = logger.events.listen((e) => kinds.add(e.kind));

        await expectLater(
          engineOn(
            backend,
            diaries: FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 1)]),
          ).push(),
          throwsA(isA<SyncException>()),
        );
        await Future<void>.delayed(Duration.zero); // 让广播事件投递完
        await sub.cancel();

        expect(kinds, contains(SyncEventKind.syncStart));
        expect(
          kinds,
          contains(SyncEventKind.syncEnd),
          reason: '抛错也必须补发 syncEnd，否则 AutoSyncWatcher 卡死',
        );
      },
    );
  });

  group('idle-sync 网络成本', () {
    test('空转 sync 只读一次 manifest（pull 快照复用给 push）', () async {
      final backend = FakeRemoteBackend();
      final store = FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 100)]);
      await engineOn(backend, diaries: store).push();
      backend.ops.clear();

      final report = await engineOn(backend, diaries: store).sync();
      expect(report.failed, 0);
      expect(report.diaryCount, 0);
      expect(
        backend.opCount('read', SyncKeys.manifestPath),
        1,
        reason: '空转 sync 的 push 应复用 pull 的 manifest 快照',
      );
    });

    test('pull 有实际落库时 push 仍重读 manifest（保守基线）', () async {
      final backend = FakeRemoteBackend();
      await seedRemote(
        backend,
        diaries: [buildDiary(id: 'a', modifiedMs: 100)],
      );
      backend.ops.clear();

      final local = FakeDiaryStore();
      await engineOn(backend, diaries: local).sync();
      expect(local.diaries.containsKey('a'), isTrue);
      expect(
        backend.opCount('read', SyncKeys.manifestPath),
        2,
        reason: '有变更的 pull 不复用快照，push 重读',
      );
    });
  });

  group('pull — 对象身份校验', () {
    test('远端 JSON 的 id 与 manifest 键不符 → 计入 failed 且不落库', () async {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.manifestPath] = jsonBytes({
        'version': 4,
        'updatedAt': 1,
        'entries': {
          'd:a': {'t': atMs(1000).millisecondsSinceEpoch},
        },
      });
      backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes(
        buildDiary(id: 'b', modifiedMs: 1000).toJson(),
      );

      final local = FakeDiaryStore();
      final report = await engineOn(backend, diaries: local).pull();
      expect(report.failed, 1, reason: '身份不符按失败计，不推进 lastSyncTime');
      expect(local.diaries, isEmpty, reason: '错位对象不得落库');
    });
  });

  group('事件来源标记（回声推送抑制）', () {
    test('云后端 pull 下载落库带 fromSync=true', () async {
      final backend = FakeRemoteBackend();
      await seedRemote(
        backend,
        diaries: [buildDiary(id: 'a', modifiedMs: 100)],
      );

      final local = FakeDiaryStore();
      await engineOn(backend, diaries: local).pull();
      expect(
        local.writeOrigins['a'],
        isTrue,
        reason: '云 pull 的写入远端已持有，事件应带 fromSync',
      );
    });

    test('云 pull 应用远端墓碑带 fromSync=true', () async {
      final backend = FakeRemoteBackend();
      backend.objects[SyncKeys.manifestPath] = jsonBytes({
        'version': 4,
        'updatedAt': 1,
        'entries': {
          'd:a': {'t': atMs(2000).millisecondsSinceEpoch, 'd': true},
        },
      });
      final local = FakeDiaryStore([buildDiary(id: 'a', modifiedMs: 1000)]);
      await engineOn(backend, diaries: local).pull();
      expect(local.writeOrigins['a'], isTrue);
    });
  });
}
