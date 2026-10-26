import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:sqlite3_simple/sqlite3_simple.dart';
import 'package:sqlite3_vec/sqlite3_vec.dart';

import 'database.steps.dart';
import 'db_codec.dart';

part 'database.g.dart';

@DriftDatabase(
  include: {
    'diary_tables.drift',
    'base_tables.drift',
    'sync_tables.drift',
    'assistant_tables.drift',
    'rag_tables.drift',
    'diary.drift',
  },
)
class MoodiaryDatabase extends _$MoodiaryDatabase {
  MoodiaryDatabase._(super.e);

  int? upgradedFrom;

  @visibleForTesting
  MoodiaryDatabase.forTesting(super.e) {
    loadSimpleExtension();
    installJiebaDict();
  }

  static Future<MoodiaryDatabase> open({
    required String path,
    required String jiebaDictDir,
  }) async {
    // 扩展注册与词典路径都是进程级的，装一次覆盖后台 isolate 和整个读连接池，
    // 但必须赶在第一条连接之前；缺词典时首次查询是 abort 而不是报错。
    loadSqliteVec();
    loadSimpleExtension(jiebaDictDir: jiebaDictDir);
    final executor = NativeDatabase.createInBackground(
      File(path),
      readPool: 3,
      setup: _setupConnection,
    );
    final db = MoodiaryDatabase._(executor);
    await db.customSelect('SELECT 1').get();
    return db;
  }

  static void _setupConnection(sqlite3.Database db) {
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('PRAGMA foreign_keys = ON');
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) {
      upgradedFrom = from;
      return transaction(
        () => m.runMigrationSteps(
          from: from,
          to: to,
          steps: migrationSteps(
            from1To2: (m, schema) async {
              await m.createTable(schema.places);
              await m.addColumn(schema.diaries, schema.diaries.placeId);
              await _migratePositionsToPlaces();
              for (final column in ['latitude', 'longitude', 'place_name']) {
                await m.dropColumn(schema.diaries, column);
              }
            },
            from2To3: (m, schema) async {
              await m.addColumn(schema.diaries, schema.diaries.moodLevel);
              await m.createTable(schema.legacyMoodScenes);
              final moods = await customSelect('SELECT id, mood FROM diaries')
                  .get();
              for (final row in moods) {
                final legacy = LegacyMood.fromName(row.read<String>('mood'));
                await customStatement(
                  'UPDATE diaries SET mood_level = ? WHERE id = ?',
                  [legacy?.mood?.score, row.read<String>('id')],
                );
                if (legacy?.scene case final scene?) {
                  await customStatement(
                    'INSERT INTO legacy_mood_scenes (diary_id, scene) VALUES (?, ?)',
                    [row.read<String>('id'), scene.name],
                  );
                }
              }
              // mood is absent from all indexes and FTS triggers.
              await m.dropColumn(schema.diaries, 'mood');
              await m.addColumn(
                schema.chatMessages,
                schema.chatMessages.providerId,
              );
              await m.addColumn(schema.memories, schema.memories.source);
              await customStatement('DROP TABLE agent_presets');
              for (final column in [
                'agent_preset_id',
                'persona_snapshot',
                'tools_snapshot_json',
              ]) {
                await m.dropColumn(schema.chatSessions, column);
              }
              await _adoptMediaInfoNames();
              await m.deleteTable('media_infos');
              await customStatement(
                "DELETE FROM tombstones WHERE \"key\" LIKE 'm:%'",
              );
              await m.addColumn(schema.diaryMedia, schema.diaryMedia.name);
              await customStatement('DROP TABLE diary_fts');
              await m.createTable(schema.diaryFts);
              for (final trigger in [diaryFtsAi, diaryFtsAd, diaryFtsAu]) {
                await m.create(trigger);
              }
              await customStatement(
                "INSERT INTO diary_fts(diary_fts) VALUES('rebuild')",
              );
            },
          ),
        ),
      );
    },
  );

  Future<void> _migratePositionsToPlaces() async {
    final rows = await customSelect(
      'SELECT id, latitude, longitude, place_name FROM diaries '
      'WHERE latitude IS NOT NULL AND longitude IS NOT NULL '
      'ORDER BY time DESC',
    ).get();
    if (rows.isEmpty) return;
    final byName = <String, Place>{};
    final placeOf = <String, String>{};
    for (final row in rows) {
      final lat = row.read<double>('latitude');
      final lon = row.read<double>('longitude');
      var name = (row.readNullable<String>('place_name') ?? '').trim();
      if (name.isEmpty) name = Place.coordinateName(lat, lon);
      final place = byName.putIfAbsent(
        name,
        () => Place.forName(name, latitude: lat, longitude: lon),
      );
      placeOf[row.read<String>('id')] = place.id;
    }
    await batch((b) {
      for (final p in byName.values) {
        b.insert(
          places,
          PlacesCompanion.insert(
            id: p.id,
            name: p.name,
            latitude: p.latitude,
            longitude: p.longitude,
            lastModified: dbTime(p.lastModified),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      for (final MapEntry(key: diaryId, value: placeId) in placeOf.entries) {
        b.update(
          diaries,
          DiariesCompanion(placeId: Value(placeId)),
          where: (d) => d.id.equals(diaryId),
        );
      }
    });
  }

  // 2.8.1 的音频名只在 media_infos 里；正文其余的升级留给 upgradeContentSchema
  Future<void> _adoptMediaInfoNames() async {
    final names = {
      for (final row in await customSelect(
        'SELECT file_name, name FROM media_infos WHERE name IS NOT NULL',
      ).get())
        if (row.read<String>('name').trim() case final name
            when name.isNotEmpty)
          row.read<String>('file_name'): name,
    };
    if (names.isEmpty) return;
    final rows = await customSelect(
      'SELECT DISTINCT d.id, d.content FROM diaries d '
      'JOIN diary_media m ON m.diary_id = d.id '
      "WHERE m.kind = 'audio' AND d.type = 'tiptap'",
    ).get();
    for (final row in rows) {
      final content = row.read<String>('content');
      final named = TiptapContent.mapMediaNames(
        content,
        (type, src, name) =>
            type == 'audio' && (name == null || name.trim().isEmpty)
            ? names[src] ?? name
            : name,
      );
      if (identical(named, content)) continue;
      await customStatement('UPDATE diaries SET content = ? WHERE id = ?', [
        named,
        row.read<String>('id'),
      ]);
    }
  }

  /// Must run after locale loading and before sync can read migrated diaries.
  /// Kept transactional so interruption retries without duplicate scene tags.
  Future<void> applyLegacyMoodScenes(String Function(LegacyMoodScene) label) =>
      transaction(() async {
        final pending = await select(legacyMoodScenes).get();
        for (final row in pending) {
          final scene = LegacyMoodScene.values.byName(row.scene);
          final tag = label(scene);
          await customStatement(
            'INSERT INTO diary_tags (diary_id, seq, tag) '
            'SELECT ?, COALESCE(MAX(seq), -1) + 1, ? FROM diary_tags '
            'WHERE diary_id = ? HAVING NOT EXISTS '
            '(SELECT 1 FROM diary_tags WHERE diary_id = ? AND tag = ?)',
            [row.diaryId, tag, row.diaryId, row.diaryId, tag],
          );
        }
        await delete(legacyMoodScenes).go();
      });

  Future<void> clearAll() async {
    await transaction(() async {
      await customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in allTables) {
        // 虚表由 SQLite 自己维护（diary_fts 靠 diaries 上的删除触发器清空）
        if (table is VirtualTableInfo) continue;
        await delete(table).go();
      }
      // vec0 虚表不在 allTables（非 drift 管理）
      final vec = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [const Variable('vec_diary_chunks')],
      ).get();
      if (vec.isNotEmpty) {
        await customStatement('DELETE FROM vec_diary_chunks');
      }
    });
  }
}
