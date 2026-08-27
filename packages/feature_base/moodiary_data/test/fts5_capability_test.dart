// P0 spike：验证宿主测试环境下 sqlite3 code asset 可用性与 FTS5 能力。
// 结论回填 docs/sqlite-migration.md §6 后，本文件保留作为能力闸门。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('宿主能拿到 sqlite3 库，版本满足 contentless_delete 门槛', () {
    final version = sqlite3.version;
    // ignore: avoid_print
    print('sqlite3: ${version.libVersion} (${version.sourceId})');
    expect(
      version.versionNumber,
      greaterThanOrEqualTo(3043000),
      reason: 'contentless_delete 需要 SQLite >= 3.43',
    );
  });

  test('FTS5 编译进库', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final row = db.select(
      "SELECT sqlite_compileoption_used('ENABLE_FTS5') AS v",
    );
    expect(row.first['v'], 1);
  });

  test('contentless_delete + prefix + bm25 全链路', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('''
      CREATE VIRTUAL TABLE diary_fts USING fts5(
        title_tok, body_tok,
        content='', contentless_delete=1,
        tokenize='unicode61', prefix='2', detail=full, columnsize=1
      );
    ''');
    db.execute(
      "INSERT INTO diary_fts(diary_fts, rank) VALUES('rank', 'bm25(1.5, 1.0)')",
    );

    // 预分词写入：rowid 显式指定，模拟 diaries.rid 对齐
    final insert = db.prepare(
      'INSERT INTO diary_fts(rowid, title_tok, body_tok) VALUES (?, ?, ?)',
    );
    insert.execute([1, '周末 计划', '今天 天气 很 好 出门 爬山 爬山 很 累']);
    insert.execute([2, '工作 记录', '今天 加班 到 很 晚 心情 不 好']);
    insert.execute([3, '', '北京大学 校园 散步']);
    insert.close();

    // OR 召回 + rank 排序（bm25 越小越相关，升序）
    final hits = db.select(
      "SELECT rowid FROM diary_fts WHERE diary_fts MATCH '\"爬山\" OR \"加班\"' ORDER BY rank",
    );
    expect(hits.map((r) => r['rowid']).toList(), [1, 2]);

    // 词频生效：爬山出现 2 次的行 bm25 更优
    final tf = db.select(
      "SELECT rowid, bm25(diary_fts) AS s FROM diary_fts WHERE diary_fts MATCH '爬山'",
    );
    expect(tf.first['rowid'], 1);

    // 前缀索引
    final prefix = db.select(
      "SELECT rowid FROM diary_fts WHERE diary_fts MATCH '北京*'",
    );
    expect(prefix.map((r) => r['rowid']).toList(), [3]);

    // 短语查询（detail=full 的新能力）
    final phrase = db.select(
      'SELECT rowid FROM diary_fts WHERE diary_fts MATCH ?',
      ['"天气 很 好"'],
    );
    expect(phrase.map((r) => r['rowid']).toList(), [1]);

    // contentless_delete：按 rowid 直接 DELETE
    db.execute('DELETE FROM diary_fts WHERE rowid = 1');
    final after = db.select(
      "SELECT rowid FROM diary_fts WHERE diary_fts MATCH '爬山'",
    );
    expect(after, isEmpty);

    // delete-all 重建路径可用（'rebuild' 在 contentless 上不可用）
    db.execute("INSERT INTO diary_fts(diary_fts) VALUES('delete-all')");
    final empty = db.select(
      "SELECT rowid FROM diary_fts WHERE diary_fts MATCH '加班'",
    );
    expect(empty, isEmpty);
  });

  test('事务：BEGIN/COMMIT/ROLLBACK + autocommit 判据', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');

    db.execute('BEGIN');
    expect(db.autocommit, isFalse);
    db.execute('INSERT INTO t (id, v) VALUES (1, ?)', ['a']);
    db.execute('COMMIT');
    expect(db.autocommit, isTrue);

    db.execute('BEGIN');
    db.execute('INSERT INTO t (id, v) VALUES (2, ?)', ['b']);
    db.execute('ROLLBACK');
    expect(db.select('SELECT COUNT(*) AS c FROM t').first['c'], 1);
  });
}
