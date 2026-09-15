import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sqlite_vec/moodiary_sqlite_vec.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:sqlite3_simple/sqlite3_simple.dart';

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
    // drift 不把 onUpgrade 包进事务
    onUpgrade: (m, from, to) async {
      upgradedFrom = from;
      if (from < 2) {
        await transaction(() async {
          await m.createTable(places);
          if (!await _hasColumn('diaries', 'place_id')) {
            await m.addColumn(diaries, diaries.placeId);
          }
          if (await _hasColumn('diaries', 'latitude')) {
            await _migratePositionsToPlaces();
            for (final column in ['latitude', 'longitude', 'place_name']) {
              await customStatement('ALTER TABLE diaries DROP COLUMN $column');
            }
          }
        });
      }
      if (from < 3) {
        await transaction(() async {
          await customStatement('DROP TABLE IF EXISTS diary_fts');
          await m.createTable(diaryFts);
          for (final trigger in [diaryFtsAi, diaryFtsAd, diaryFtsAu]) {
            await m.create(trigger);
          }
          await customStatement(
            "INSERT INTO diary_fts(diary_fts) VALUES('rebuild')",
          );
        });
      }
    },
  );

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

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
