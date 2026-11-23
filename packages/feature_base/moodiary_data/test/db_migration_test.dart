import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_lint/testing.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:sqlite3_simple/sqlite3_simple.dart';

import 'drift/moodiary/generated/schema.dart';
import 'drift/moodiary/generated/schema_v1.dart' as v1;
import 'drift/moodiary/generated/schema_v2.dart' as v2;
import 'drift/moodiary/generated/schema_v3.dart' as v3;

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

  test('新库直接建到 v4，且与 v4 快照一致', () async {
    final db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    await verifier.migrateAndValidate(db, 4);
    expect(await userVersion(db), 4);
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
    await verifier.migrateAndValidate(db, 4);
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
    await verifier.migrateAndValidate(db, 4);
    final places = await PlaceRepository(
      db,
      DiaryRepository(db),
    ).getAllPlaces();
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
    await verifier.migrateAndValidate(db, 4);
    final hit = (await DiaryRepository(db).searchDiaries(query: '苹果')).single;
    expect(hit.diary.id, 'd1', reason: "'rebuild' 从 diaries 重灌了整个索引");
    expect(hit.titleHighlight, '关于${marked('苹果')}的日记');
    await db.close();
  });

  test('v2 老库升级：media_infos 里的音频名并进正文后删表，m: 墓碑一并清掉', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    final content = jsonEncode({
      'type': 'doc',
      'content': [
        for (final file in ['audio-1.m4a', 'audio-2.m4a', 'audio-3.m4a'])
          {
            'type': 'audio',
            'attrs': {
              'filename': file,
              if (file == 'audio-2.m4a') 'name': '已有名',
            },
          },
      ],
    });
    await old
        .into(old.diaries)
        .insert(
          v2.DiariesCompanion.insert(
            id: 'd1',
            title: '',
            content: content,
            contentText: '',
            time: 1,
            lastModified: 7,
            show: 1,
            mood: 'neutral',
            type: 'tiptap',
          ),
        );
    for (final (seq, file) in [
      (0, 'audio-1.m4a'),
      (1, 'audio-2.m4a'),
      (2, 'audio-3.m4a'),
    ]) {
      await old
          .into(old.diaryMedia)
          .insert(
            v2.DiaryMediaCompanion.insert(
              diaryId: 'd1',
              kind: 'audio',
              seq: seq,
              fileName: file,
            ),
          );
    }
    for (final (file, name) in [
      ('audio-1.m4a', ' 晨间录音 '),
      ('audio-2.m4a', '旧名'),
      ('audio-3.m4a', null),
    ]) {
      await old
          .into(old.mediaInfos)
          .insert(
            v2.MediaInfosCompanion.insert(
              fileName: file,
              name: Value(name),
              lastModified: 0,
            ),
          );
    }
    for (final key in ['m:audio-1.m4a', 'd:gone']) {
      await old
          .into(old.tombstones)
          .insert(v2.TombstonesCompanion.insert(key: key, timeMs: 1));
    }
    await old.close();

    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    final row = await db
        .customSelect(
          "SELECT content, last_modified FROM diaries WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.read<int>('last_modified'), 7);
    expect(
      [
        for (final node
            in (jsonDecode(row.read<String>('content')) as Map)['content']
                as List)
          (node as Map)['attrs']['name'],
      ],
      ['晨间录音', '已有名', null],
    );
    final keys = await db.customSelect('SELECT "key" FROM tombstones').get();
    expect(keys.map((r) => r.read<String>('key')), ['d:gone']);
    await db.close();
  });

  test(
    'v2 moods migrate to nullable scores; scene tags wait for the UI locale',
    () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      final expected = <String, DiaryMood?>{
        'fulfilled': .great,
        'love': .great,
        'positive': .good,
        'neutral': null,
        'negative': .bad,
        'anxious': .bad,
        'tired': .bad,
        'speechless': .bad,
        'sick': .bad,
        'angry': .awful,
        for (final scene in LegacyMoodScene.values) scene.name: null,
      };
      for (final name in expected.keys) {
        await old
            .into(old.diaries)
            .insert(
              v2.DiariesCompanion.insert(
                id: name,
                title: name,
                content: '',
                contentText: name,
                time: 1,
                lastModified: 7,
                show: 1,
                mood: name,
                type: 'tiptap',
              ),
            );
      }
      // The selected language's existing tag must not be added a second time.
      await old
          .into(old.diaryTags)
          .insert(
            v2.DiaryTagsCompanion.insert(
              diaryId: 'travel',
              seq: 4,
              tag: 'Travel',
            ),
          );
      await old
          .into(old.diaryTags)
          .insert(
            v2.DiaryTagsCompanion.insert(
              diaryId: 'work',
              seq: 2,
              tag: 'existing',
            ),
          );
      await old.close();
      final db = MoodiaryDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      final columns = await db.customSelect('PRAGMA table_info(diaries)').get();
      expect(
        columns.map((r) => r.read<String>('name')),
        isNot(contains('mood')),
      );
      final repo = DiaryRepository(db);
      for (final entry in expected.entries) {
        final diary = (await repo.getDiaryByBusinessId(entry.key))!;
        expect(diary.mood, entry.value, reason: entry.key);
        expect(diary.lastModified, dbToTime(7));
      }
      expect((await repo.getDiaryByBusinessId('study'))!.tagIds, isEmpty);
      expect(await db.select(db.legacyMoodScenes).get(), hasLength(6));
      await expectLater(
        db.applyLegacyMoodScenes((scene) {
          if (scene == LegacyMoodScene.food) {
            throw StateError('locale interrupted');
          }
          return scene.name;
        }),
        throwsStateError,
      );
      expect((await repo.getDiaryByBusinessId('study'))!.tagIds, isEmpty);
      expect(await db.select(db.legacyMoodScenes).get(), hasLength(6));
      await db.applyLegacyMoodScenes(
        (scene) => switch (scene) {
          .study => 'Research',
          .work => 'Work',
          .travel => 'Travel',
          .sports => 'Sports',
          .food => 'Food',
          .slacking => 'Slacking',
        },
      );
      expect((await repo.getDiaryByBusinessId('travel'))!.tagIds, [
        Tag.legacyId('Travel'),
      ]);
      expect((await repo.getDiaryByBusinessId('work'))!.tagIds, [
        Tag.legacyId('existing'),
        Tag.legacyId('Work'),
      ]);
      expect((await repo.getDiaryByBusinessId('study'))!.tagIds, [
        Tag.legacyId('Research'),
      ]);
      expect(await db.select(db.legacyMoodScenes).get(), isEmpty);
      await db.applyLegacyMoodScenes((_) => 'wrong locale');
      expect((await repo.getDiaryByBusinessId('travel'))!.tagIds, [
        Tag.legacyId('Travel'),
      ]);
      final study = (await repo.getDiaryByBusinessId('study'))!;
      expect(study.lastModified, dbToTime(7));
      expect(
        (await repo.searchDiaries(query: 'Research')).single.diary.id,
        'study',
      );
      // SQLite itself rejects invalid scores.
      await expectLater(
        db.customStatement(
          "UPDATE diaries SET mood_level = 6 WHERE id = 'study'",
        ),
        throwsA(anything),
      );
      await db.close();
    },
  );

  test('v3 tags and category tombstones migrate with released triggers installed', () async {
    final schema = await verifier.schemaAt(3);
    final old = v3.DatabaseAtV3(schema.newConnection());
    final snapshot = jsonDecode(
      await File(
        '$repoRoot/packages/feature_base/moodiary_data/drift_schemas/moodiary/drift_schema_v3.json',
      ).readAsString(),
    ) as Map;
    for (final entity in snapshot['entities'] as List) {
      if (entity['type'] == 'trigger') {
        await old.customStatement(entity['data']['sql'] as String);
      }
    }
    for (final (id, show) in [('a', 1), ('b', 0)]) {
      await old
          .into(old.diaries)
          .insert(
            v3.DiariesCompanion.insert(
              id: id,
              title: '',
              content: '',
              contentText: '',
              time: 0,
              lastModified: 123,
              show: show,
              type: 'tiptap',
            ),
          );
    }
    for (final (diary, seq, name) in [
      ('a', 8, 'two words'),
      ('a', 2, ' # Voyager '),
      ('a', 4, '#'),
      ('a', 6, ' two\t words '),
      ('b', 5, 'Voyager'),
    ]) {
      await old
          .into(old.diaryTags)
          .insert(
            v3.DiaryTagsCompanion.insert(diaryId: diary, seq: seq, tag: name),
          );
    }
    await old
        .into(old.categories)
        .insert(
          v3.CategoriesCompanion.insert(
            id: 'known',
            name: 'Keep',
            lastModified: 1,
          ),
        );
    for (final key in ['c:known', 'c:missing', 'd:other']) {
      await old
          .into(old.tombstones)
          .insert(v3.TombstonesCompanion.insert(key: key, timeMs: 1234));
    }
    await old.close();
    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
    expect(
      await TagRepository(db).getAllTags(),
      unorderedEquals([Tag.legacy('Voyager'), Tag.legacy('two words')]),
    );
    final refs = await db
        .customSelect(
          'SELECT diary_id, seq, tag_id FROM diary_tags ORDER BY diary_id, seq',
        )
        .get();
    expect(
      refs.map(
        (r) => (
          r.read<String>('diary_id'),
          r.read<int>('seq'),
          r.read<String>('tag_id'),
        ),
      ),
      [
        ('a', 0, Tag.legacyId('Voyager')),
        ('a', 1, Tag.legacyId('two words')),
        ('b', 0, Tag.legacyId('Voyager')),
      ],
    );
    final diaries = await (db.select(
      db.diaries,
    )..orderBy([(d) => OrderingTerm.asc(d.id)])).get();
    expect(diaries.map((d) => (d.tagsText, d.lastModified)), [
      ('Voyager two words', 123),
      ('Voyager', 123),
    ]);
    expect(
      (await DiaryRepository(db).searchDiaries(query: 'Voyager'))
          .single
          .diary
          .id,
      'a',
    );
    final categories = await CategoryRepository(db).getAllCategoriesForSync();
    expect(
      categories.map(
        (c) => (c.categoryName, c.deleted, dbTime(c.lastModified)),
      ),
      [('Keep', true, 1234000), ('', true, 1234000)],
    );
    expect((await TombstoneRepository(db).getAll()).single.key, 'd:other');
  });

  group('逐档迁移', () {
    const versions = GeneratedHelper.versions;
    for (var i = 0; i + 1 < versions.length; i++) {
      final (from, to) = (versions[i], versions[i + 1]);
      test('v$from → v$to 落在下一档快照上', () async {
        final schema = await verifier.schemaAt(from);
        final db = MoodiaryDatabase.forTesting(schema.newConnection());
        await verifier.migrateAndValidate(db, to);
        await db.close();
      });
    }
  });
}
