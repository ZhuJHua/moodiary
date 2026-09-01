import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sqlite_vec/moodiary_sqlite_vec.dart';
import 'package:sqlite3/sqlite3.dart';

Uint8List _f32(List<double> v) => Float32List.fromList(v).buffer.asUint8List();

void main() {
  setUpAll(loadSqliteVec);

  test('vec_version 可用', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final version = db.select('SELECT vec_version() AS v').single['v'];
    expect(version, startsWith('v0.1.9'));
  });

  test('vec0 建表 + KNN + 按 rowid 删', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute(
      'CREATE VIRTUAL TABLE vec_chunks USING vec0('
      'embedding float[4] distance_metric=cosine)',
    );
    final insert = db.prepare(
      'INSERT INTO vec_chunks(rowid, embedding) VALUES (?, ?)',
    );
    insert
      ..execute([
        1,
        _f32([1, 0, 0, 0]),
      ])
      ..execute([
        2,
        _f32([0, 1, 0, 0]),
      ])
      ..execute([
        3,
        _f32([0.9, 0.1, 0, 0]),
      ])
      ..close();

    final rows = db.select(
      'SELECT rowid, distance FROM vec_chunks '
      'WHERE embedding MATCH ? AND k = 2 ORDER BY distance',
      [
        _f32([1, 0, 0, 0]),
      ],
    );
    expect(rows.map((r) => r['rowid']), [1, 3]);

    db.execute('DELETE FROM vec_chunks WHERE rowid = 3');
    final after = db.select(
      'SELECT rowid FROM vec_chunks '
      'WHERE embedding MATCH ? AND k = 3 ORDER BY distance',
      [
        _f32([1, 0, 0, 0]),
      ],
    );
    expect(after.map((r) => r['rowid']), [1, 2]);
  });

  test('维度不符直接报错（闸门语义）', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE VIRTUAL TABLE vec_bad USING vec0(embedding float[4])');
    expect(
      () => db.execute('INSERT INTO vec_bad(rowid, embedding) VALUES (1, ?)', [
        _f32([1, 0]),
      ]),
      throwsA(isA<SqliteException>()),
    );
  });
}
