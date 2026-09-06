import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sqlite_vec/moodiary_sqlite_vec.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

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
  MoodiaryDatabase.forTesting(super.e);

  static Future<MoodiaryDatabase> open({required String path}) async {
    // sqlite-vec 必须在任何连接创建前用 sqlite3_auto_extension 注册（进程级状态）
    loadSqliteVec();
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // bm25(1.5, 1.0): title/body 权重；写在 .drift 会触发 drift#3322 误报
      await customStatement(
        "INSERT INTO diary_fts(diary_fts, rank) VALUES('rank', 'bm25(1.5, 1.0)')",
      );
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
        await delete(table).go();
      }
      await customStatement(
        "INSERT INTO diary_fts(diary_fts) VALUES('delete-all')",
      );
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
