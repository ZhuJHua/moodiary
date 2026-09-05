import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sqlite_vec/moodiary_sqlite_vec.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'db_codec.dart';

part 'database.g.dart';

/// SQLite 数据库（drift）。schema 真源按领域拆在 `*_tables.drift`（日记 / 基础 /
/// 同步 / 助手），具名查询只给 Dart DSL 表达不了的 SQL（FTS5，见 `diary.drift`）；
/// 领域仓储经构造器注入持本类实例做查询；本类由组合根的 @module 打开后注册进容器。
///
/// 全库 schema 约定：
/// - 业务主键统一 uuid v7 `TEXT PRIMARY KEY`；`diaries.rid` 是唯一的整数键残留，
///   只做 FTS5 rowid 胶水（引擎硬约束），不出仓储层；
/// - `DateTime` 一律 INTEGER 存 UTC 微秒（db_codec.dart）；
/// - 「没有值」是真 NULL，没有哨兵；
/// - 小集合字段留 JSON 文本列，NULL 与 '[]' 语义不同；
/// - 改 schema = 追加 user_version 迁移档（onUpgrade），不改已发布档。
///
/// 并发模型：WAL + 1 写 N 读，全部 SQL 在后台 isolate 执行
/// （[NativeDatabase.createInBackground] 的 readPool），主 isolate 不碰 FFI。
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

  /// 本次打开时从哪一档升上来的；没升级为 null。组合根据此把「本地有待推变更」置位
  /// ——迁移写出的常用地点不走仓储事件，自动同步的空转短路否则会一直跳过它们。
  int? upgradedFrom;

  /// 测试用：内存库（同步单连接，无 isolate）。
  @visibleForTesting
  MoodiaryDatabase.forTesting(super.e);

  /// 组合根调用一次；路径由调用方注入（本包不认识文件布局）。
  static Future<MoodiaryDatabase> open({required String path}) async {
    // sqlite-vec 走 sqlite3_auto_extension（进程级 C 状态），必须在任何连接
    // 打开之前注册；之后写连接与 readPool 的每个连接自动带上 vec0。
    loadSqliteVec();
    final executor = NativeDatabase.createInBackground(
      File(path),
      readPool: 3,
      setup: _setupConnection,
    );
    final db = MoodiaryDatabase._(executor);
    // 触发打开与迁移（drift 惰性连接，显式碰一次让建表错误在启动期就暴露）。
    await db.customSelect('SELECT 1').get();
    return db;
  }

  /// 每个池内连接各跑一遍（写连接与读连接都在内）。
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
      // FTS5 的持久化 bm25 列权重：title 1.5 / body 1.0（命令语句放 .drift 会
      // 报虚假 lint，drift#3322）。
      await customStatement(
        "INSERT INTO diary_fts(diary_fts, rank) VALUES('rank', 'bm25(1.5, 1.0)')",
      );
    },
    // .drift 里的建表语句永远是**最新形状**（全新安装 createAll 直接带齐）；老库靠这里
    // 一档一档追上去，每档只做增量。db_migration_test 用「把新库降回旧档」的办法复现
    // 旧形状，所以每档都要能从上一档的真实形状迁过来。
    // drift 不把 onUpgrade 包进事务：中途被杀会留下半成品、user_version 仍是旧值，
    // 下次打开再跑一遍。所以每档都（1）整体放进一个事务，（2）按实际形状判断再动手，
    // 两道保险叠着上。
    onUpgrade: (m, from, to) async {
      upgradedFrom = from;
      // v1（已发布的 2.8.0）→ v2：常用地点表 + 日记改为引用地点。日记原来的
      // latitude / longitude / place_name 快照按地名归并成地点，再把列删掉。
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

  /// v1 日记的位置快照 → 常用地点。同名归并（和风反查出的行政区名会反复出现），
  /// 坐标取最近一篇的；没有地名的拿坐标当名字，**一篇都不丢**。地点 id 由地名派生
  /// （[Place.forName]），两台设备各自升级也会得到同一批 id，同步时合并。
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

  /// 清空全部数据但保持句柄有效（`resetAllData` 的契约）。FTS 虚表走
  /// `delete-all`，影子表由引擎自管。
  Future<void> clearAll() async {
    await transaction(() async {
      await customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in allTables) {
        await delete(table).go();
      }
      await customStatement(
        "INSERT INTO diary_fts(diary_fts) VALUES('delete-all')",
      );
      // vec0 虚表不在 allTables（非 drift 管理），存在才清。
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
