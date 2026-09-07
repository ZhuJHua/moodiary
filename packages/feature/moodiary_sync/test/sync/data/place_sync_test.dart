import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

import '../sync_test_harness.dart';

void main() {
  late SyncLogger logger;

  setUp(() async {
    logger = (await setUpSyncEnv()).logger;
    await configureBackend(.webdav);
  });

  tearDown(tearDownSyncEnv);

  Place place(String id, String name, {int ms = 1000}) => Place(
    id: id,
    name: name,
    latitude: 30.28,
    longitude: 120.15,
    icon: 'building-2',
    lastModified: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
  );

  IncrementalSyncEngine engine(
    FakeRemoteBackend backend, {
    FakePlaceStore? places,
    FakeTombstoneStore? tombstones,
  }) {
    final tombstoneStore =
        tombstones ?? places?.tombstones ?? FakeTombstoneStore();
    return IncrementalSyncEngine(
      backend,
      logger: logger,
      diaryStore: FakeDiaryStore(const [], tombstoneStore),
      categoryStore: FakeCategoryStore(const [], tombstoneStore),
      placeStore: places ?? FakePlaceStore(const [], tombstoneStore),
      mediaInfoStore: FakeMediaInfoStore(const [], tombstoneStore),
      tombstoneStore: tombstoneStore,
      mediaFiles: FakeMediaFiles(),
      cipherProvider: () async => SyncCipher.plaintext,
      concurrency: 4,
    );
  }

  test('push 写出 p: 条目与 place/<id>.json 对象', () async {
    final backend = FakeRemoteBackend();
    final report = await engine(
      backend,
      places: FakePlaceStore([place('p1', '公司')]),
    ).push();

    expect(report.pushed.places, 1);
    expect(backend.objects, contains(SyncKeys.placeObjectPath('p1')));
    final manifest = backend.manifest()!;
    expect(manifest.entries, contains(SyncKeys.place('p1')));
    expect(SyncManifest.currentVersion, 2);
  });

  test('pull v1 远端：日记的 position 快照归并成地点，日记改引用', () async {
    final backend = FakeRemoteBackend();
    Uint8List jsonBytes(Object v) => .fromList(utf8.encode(jsonEncode(v)));
    Map<String, dynamic> legacyDiary(
      String id,
      Map<String, dynamic>? position,
    ) => {
      'id': id,
      'title': '',
      'content': '',
      'contentText': '',
      'time': '2026-01-01T00:00:00.000Z',
      'lastModified': '2026-01-01T00:00:00.000Z',
      'show': true,
      'mood': 'neutral',
      'imageName': <String>[],
      'audioName': <String>[],
      'videoName': <String>[],
      'tags': <String>[],
      'type': 'tiptap',
      'position': ?position,
    };
    backend.objects[SyncKeys.manifestPath] = jsonBytes({
      'version': SyncManifest.legacyVersion,
      'updatedAt': 1,
      'entries': {
        'd:a': {'t': 1000},
        'd:b': {'t': 1000},
        'd:c': {'t': 1000},
      },
    });
    backend.objects[SyncKeys.diaryObjectPath('a')] = jsonBytes(
      legacyDiary('a', {
        'latitude': 30.28,
        'longitude': 120.15,
        'name': '杭州市 西湖区',
      }),
    );
    backend.objects[SyncKeys.diaryObjectPath('b')] = jsonBytes(
      legacyDiary('b', {
        'latitude': 30.29,
        'longitude': 120.16,
        'name': '杭州市 西湖区',
      }),
    );
    backend.objects[SyncKeys.diaryObjectPath('c')] = jsonBytes(
      legacyDiary('c', {'latitude': 24.48, 'longitude': 118.08, 'name': ''}),
    );

    final tombstones = FakeTombstoneStore();
    final places = FakePlaceStore(const [], tombstones);
    final diaries = FakeDiaryStore(const [], tombstones);
    await IncrementalSyncEngine(
      backend,
      logger: logger,
      diaryStore: diaries,
      categoryStore: FakeCategoryStore(const [], tombstones),
      placeStore: places,
      mediaInfoStore: FakeMediaInfoStore(const [], tombstones),
      tombstoneStore: tombstones,
      mediaFiles: FakeMediaFiles(),
      cipherProvider: () async => SyncCipher.plaintext,
      concurrency: 4,
    ).pull();

    expect(places.places, hasLength(2), reason: '同名归并，没地名的拿坐标当名');
    final xihu = Place.idForName('杭州市 西湖区');
    expect(places.places[xihu]?.name, '杭州市 西湖区');
    expect(diaries.diaries['a']!.placeId, xihu);
    expect(diaries.diaries['b']!.placeId, xihu);
    expect(
      places.places[diaries.diaries['c']!.placeId]?.name,
      '24.4800, 118.0800',
    );
  });

  test('pull 把远端地点落到本地，字段一字不差', () async {
    final backend = FakeRemoteBackend();
    await engine(backend, places: FakePlaceStore([place('p1', '公司')])).push();

    final local = FakePlaceStore();
    await engine(backend, places: local).pull();

    expect(local.places, hasLength(1));
    final got = local.places['p1']!;
    expect(got.name, '公司');
    expect(got.icon, 'building-2');
  });

  test('LWW：本地更新的时间戳更晚，pull 不覆盖', () async {
    final backend = FakeRemoteBackend();
    await engine(backend, places: FakePlaceStore([place('p1', '旧名')])).push();

    final local = FakePlaceStore([place('p1', '新名', ms: 5000)]);
    await engine(backend, places: local).pull();

    expect(local.places['p1']!.name, '新名');
  });

  test('删除经墓碑传播：push 墓碑后另一端 pull 会删掉本地行', () async {
    final backend = FakeRemoteBackend();
    final source = FakePlaceStore([place('p1', '公司')]);
    await engine(backend, places: source).push();

    final other = FakePlaceStore();
    await engine(backend, places: other).pull();
    expect(other.places, hasLength(1));

    await source.tombstonePlace('p1');
    await engine(backend, places: source, tombstones: source.tombstones).push();
    await engine(backend, places: other, tombstones: other.tombstones).pull();

    expect(other.places, isEmpty);
    expect(backend.objects, isNot(contains(SyncKeys.placeObjectPath('p1'))));
  });

  test('不认识 p: 的旧客户端 push 不会抹掉它 —— manifest 是合并不是重建', () async {
    final backend = FakeRemoteBackend();
    await engine(backend, places: FakePlaceStore([place('p1', '公司')])).push();
    expect(backend.manifest()!.entries, contains(SyncKeys.place('p1')));

    await IncrementalSyncEngine(
      backend,
      logger: logger,
      diaryStore: FakeDiaryStore([buildDiary(id: 'd1', modifiedMs: 9000)]),
      categoryStore: FakeCategoryStore(),
      placeStore: FakePlaceStore(),
      mediaInfoStore: FakeMediaInfoStore(),
      tombstoneStore: FakeTombstoneStore(),
      mediaFiles: FakeMediaFiles(),
      cipherProvider: () async => SyncCipher.plaintext,
      concurrency: 4,
    ).push();

    final manifest = backend.manifest()!;
    expect(manifest.entries, contains(SyncKeys.diary('d1')));
    expect(manifest.entries, contains(SyncKeys.place('p1')));
    expect(backend.objects, contains(SyncKeys.placeObjectPath('p1')));
  });
}
