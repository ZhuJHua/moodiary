import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:sqlite3_simple/sqlite3_simple.dart';

import 'drift/moodiary/generated/schema.dart';
import 'drift/moodiary/generated/schema_v1.dart' as v1;
import 'drift/moodiary/generated/schema_v2.dart' as v2;

String marked(String word) => '$searchHitStart$word$searchHitEnd';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    loadSimpleExtension();
    installJiebaDict();
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<int> userVersion(GeneratedDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.data.values.first as int;
  }

  Future<List<String>> columns(GeneratedDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return [for (final r in rows) r.read<String>('name')];
  }

  v1.DiariesCompanion v1Diary(
    String id, {
    double? lat,
    double? lon,
    String? placeName,
    int time = 0,
  }) => v1.DiariesCompanion.insert(
    id: id,
    title: '',
    content: '',
    contentText: '',
    time: time,
    lastModified: 0,
    show: 1,
    mood: 'neutral',
    type: 'tiptap',
    latitude: Value(lat),
    longitude: Value(lon),
    placeName: Value(placeName),
  );

  test('新库直接建到 v3，且与 v3 快照一致', () async {
    final db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    await verifier.migrateAndValidate(db, 3);
    expect(await userVersion(db), 3);
    await db.close();
  });

  test('v2 老库升级：旧行留空，预设被丢弃', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old
        .into(old.chatSessions)
        .insert(
          v2.ChatSessionsCompanion.insert(
            id: 's1',
            providerId: 'p1',
            model: 'm1',
            createdAt: 0,
            updatedAt: 0,
            agentPresetId: const Value('ap'),
            personaSnapshot: const Value('y'),
          ),
        );
    await old
        .into(old.chatMessages)
        .insert(
          v2.ChatMessagesCompanion.insert(
            id: 'm1',
            sessionId: 's1',
            role: 'user',
            content: 'hi',
            createdAt: 0,
          ),
        );
    await old
        .into(old.memories)
        .insert(
          v2.MemoriesCompanion.insert(
            id: 'f1',
            category: 'preference',
            content: 'call me 小竹',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await old
        .into(old.agentPresets)
        .insert(
          v2.AgentPresetsCompanion.insert(
            id: 'ap',
            name: 'x',
            persona: 'y',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await old.close();

    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final message = await db
        .customSelect("SELECT provider_id FROM chat_messages WHERE id = 'm1'")
        .getSingle();
    expect(message.readNullable<String>('provider_id'), isNull);
    final fact = await db
        .customSelect("SELECT source FROM memories WHERE id = 'f1'")
        .getSingle();
    expect(fact.readNullable<String>('source'), isNull);
    final session = await db
        .customSelect("SELECT model FROM chat_sessions WHERE id = 's1'")
        .getSingle();
    expect(session.read<String>('model'), 'm1');
    await db.close();
  });

  test('v1 老库升级：位置快照归并成常用地点，日记改引用，一篇不丢', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old
        .into(old.categories)
        .insert(
          v1.CategoriesCompanion.insert(id: 'c1', name: '生活', lastModified: 0),
        );
    await old.batch((b) {
      b.insertAll(old.diaries, [
        v1Diary('d1', lat: 30.28, lon: 120.15, placeName: '杭州市 西湖区', time: 1),
        v1Diary('d2', lat: 30.29, lon: 120.16, placeName: '杭州市 西湖区', time: 2),
        v1Diary('d3', lat: 24.48, lon: 118.08, placeName: '', time: 3),
        v1Diary('d4', time: 4),
      ]);
    });
    await old.close();

    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
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
    await db.close();
  });

  test('v2 老库升级：索引换成 simple external content，老数据重建后可搜', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old
        .into(old.diaries)
        .insert(
          v2.DiariesCompanion.insert(
            id: 'd1',
            title: '关于苹果的日记',
            content: '',
            contentText: '早上吃了一个苹果，味道不错',
            time: 1,
            lastModified: 0,
            show: 1,
            mood: 'neutral',
            type: 'tiptap',
          ),
        );
    await old.close();

    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final hit = (await DiaryRepository(db).searchDiaries(query: '苹果')).single;
    expect(hit.diary.id, 'd1', reason: "'rebuild' 从 diaries 重灌了整个索引");
    expect(hit.titleHighlight, '关于${marked('苹果')}的日记');
    await db.close();
  });

  test('已是 v3 的库重开不重复建表', () async {
    final schema = await verifier.schemaAt(3);
    var db = MoodiaryDatabase.forTesting(schema.newConnection());
    await PlaceRepository(
      db,
    ).insertAPlace(Place.create(name: '家', latitude: 30.1, longitude: 120.1));
    await db.close();

    db = MoodiaryDatabase.forTesting(schema.newConnection());
    expect(await userVersion(db), 3);
    expect(await PlaceRepository(db).getAllPlaces(), hasLength(1));
    expect(await columns(db, 'diaries'), isNot(contains('latitude')));
    await db.close();
  });
}
