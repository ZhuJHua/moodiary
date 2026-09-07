import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('moodiary-migration-');
    path = '${dir.path}/test.sqlite';
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  Future<MoodiaryDatabase> open() async {
    final db = MoodiaryDatabase.forTesting(NativeDatabase(File(path)));
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<int> userVersion(MoodiaryDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.data.values.first as int;
  }

  Future<List<String>> columns(MoodiaryDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return [for (final r in rows) r.read<String>('name')];
  }

  Future<void> downgradeToV1(MoodiaryDatabase db) async {
    await db.customStatement('DROP TABLE places');
    await db.customStatement('ALTER TABLE diaries DROP COLUMN place_id');
    await db.customStatement('ALTER TABLE diaries ADD COLUMN latitude REAL');
    await db.customStatement('ALTER TABLE diaries ADD COLUMN longitude REAL');
    await db.customStatement('ALTER TABLE diaries ADD COLUMN place_name TEXT');
    await db.customStatement('PRAGMA user_version = 1');
  }

  Future<void> insertV1Diary(
    MoodiaryDatabase db,
    String id, {
    double? lat,
    double? lon,
    String? placeName,
    int time = 0,
  }) => db.customStatement(
    'INSERT INTO diaries (id, title, content, content_text, time, '
    'last_modified, show, mood, type, latitude, longitude, place_name) '
    "VALUES (?, '', '', '', ?, 0, 1, 'neutral', 'tiptap', ?, ?, ?)",
    [id, time, lat, lon, placeName],
  );

  test('新库直接建到 v2，places 就位', () async {
    final db = await open();
    expect(await userVersion(db), 2);
    expect(await PlaceRepository(db).getAllPlaces(), isEmpty);
    expect(await columns(db, 'diaries'), isNot(contains('latitude')));
    await db.close();
  });

  test('v1 老库升级：位置快照归并成常用地点，日记改引用，一篇不丢', () async {
    var db = await open();
    await CategoryRepository(db).insertACategory(
      Category(
        id: 'c1',
        categoryName: '生活',
        lastModified: DateTime.utc(2026, 1, 1),
      ),
    );
    await downgradeToV1(db);
    await insertV1Diary(
      db,
      'd1',
      lat: 30.28,
      lon: 120.15,
      placeName: '杭州市 西湖区',
      time: 1,
    );
    await insertV1Diary(
      db,
      'd2',
      lat: 30.29,
      lon: 120.16,
      placeName: '杭州市 西湖区',
      time: 2,
    );
    await insertV1Diary(
      db,
      'd3',
      lat: 24.48,
      lon: 118.08,
      placeName: '',
      time: 3,
    );
    await insertV1Diary(db, 'd4', time: 4);
    await db.close();

    db = await open();
    expect(await userVersion(db), 2);
    expect(await columns(db, 'diaries'), isNot(contains('latitude')));
    final places = await PlaceRepository(db).getAllPlaces();
    expect(places, hasLength(2));
    final xihu = places.singleWhere((p) => p.name == '杭州市 西湖区');
    expect(xihu.id, Place.idForName('杭州市 西湖区'), reason: 'id 由地名派生，跨设备一致');
    expect(xihu.latitude, 30.29, reason: '坐标取最近一篇');
    final byCoords = places.singleWhere((p) => p.name != '杭州市 西湖区');
    expect(byCoords.name, '24.4800, 118.0800');
    final repo = DiaryRepository(db);
    expect((await repo.getDiaryByBusinessId('d1'))!.placeId, xihu.id);
    expect((await repo.getDiaryByBusinessId('d2'))!.placeId, xihu.id);
    expect((await repo.getDiaryByBusinessId('d3'))!.placeId, byCoords.id);
    expect((await repo.getDiaryByBusinessId('d4'))!.placeId, isNull);
    expect(
      (await CategoryRepository(db).getCategoryById('c1'))?.categoryName,
      '生活',
    );
    await PlaceRepository(db).insertAPlace(
      Place.create(name: '公司', latitude: 30.28, longitude: 120.15),
    );
    expect(await PlaceRepository(db).getAllPlaces(), hasLength(3));
    await db.close();
  });

  test('v1 升级中途被杀（places 与 place_id 已建、列未删、版本未拨）：重开能续跑', () async {
    var db = await open();
    await downgradeToV1(db);
    await insertV1Diary(db, 'd1', lat: 30.28, lon: 120.15, placeName: '公司');
    await db.customStatement(
      'CREATE TABLE places (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, '
      'latitude REAL NOT NULL, longitude REAL NOT NULL, icon TEXT, '
      'last_modified INTEGER NOT NULL)',
    );
    await db.customStatement('ALTER TABLE diaries ADD COLUMN place_id TEXT');
    await db.close();

    db = await open();
    expect(await userVersion(db), 2);
    expect(await columns(db, 'diaries'), isNot(contains('latitude')));
    final place = (await PlaceRepository(db).getAllPlaces()).single;
    expect(place.name, '公司');
    expect(
      (await DiaryRepository(db).getDiaryByBusinessId('d1'))!.placeId,
      place.id,
    );
    await db.close();
  });

  test('已是 v2 的库重开不重复建表', () async {
    var db = await open();
    await PlaceRepository(
      db,
    ).insertAPlace(Place.create(name: '家', latitude: 30.1, longitude: 120.1));
    await db.close();

    db = await open();
    expect(await userVersion(db), 2);
    expect(await PlaceRepository(db).getAllPlaces(), hasLength(1));
    await db.close();
  });
}
