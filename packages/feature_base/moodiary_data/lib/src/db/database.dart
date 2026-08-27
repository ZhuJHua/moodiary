import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

part 'database.g.dart';

/// SQLite 数据库（drift）。schema 真源在 `schema.drift`，具名查询在各 `*.drift`；
/// 领域仓储持本类实例做查询，organizes 同旧 Isar 时代的 `XxxRepository.get()` 惯例。
///
/// 并发模型：WAL + 1 写 N 读，全部 SQL 在后台 isolate 执行
/// （[NativeDatabase.createInBackground] 的 readPool），主 isolate 不碰 FFI。
@DriftDatabase(include: {'schema.drift', 'diary.drift'})
class MoodiaryDatabase extends _$MoodiaryDatabase {
  MoodiaryDatabase._(super.e);

  /// 测试用：内存库（同步单连接，无 isolate）。
  @visibleForTesting
  MoodiaryDatabase.forTesting(super.e);

  static MoodiaryDatabase? _instance;

  factory MoodiaryDatabase.get() {
    final db = _instance;
    if (db == null) {
      throw StateError('MoodiaryDatabase 未初始化：main 必须先 await open()');
    }
    return db;
  }

  /// 组合根调用一次；路径由调用方注入（本包不认识文件布局）。
  static Future<void> open({required String path}) async {
    assert(_instance == null, 'MoodiaryDatabase 已初始化');
    final executor = NativeDatabase.createInBackground(
      File(path),
      readPool: 3,
      setup: _setupConnection,
    );
    final db = MoodiaryDatabase._(executor);
    // 触发打开与迁移（drift 惰性连接，显式碰一次让建表错误在启动期就暴露）。
    await db.customSelect('SELECT 1').get();
    _instance = db;
  }

  /// 每个池内连接各跑一遍（写连接与读连接都在内）。
  static void _setupConnection(sqlite3.Database db) {
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('PRAGMA foreign_keys = ON');
  }

  @override
  int get schemaVersion => 1;

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
  );

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
    });
  }
}
