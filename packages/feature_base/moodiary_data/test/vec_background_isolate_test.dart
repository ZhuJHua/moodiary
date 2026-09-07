import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sqlite_vec/moodiary_sqlite_vec.dart';

Uint8List _f32(List<double> v) => Float32List.fromList(v).buffer.asUint8List();

void main() {
  test('vec0 在后台 isolate 连接（含 readPool 读连接）上可用', () async {
    // sqlite3_auto_extension 是进程级 C 状态：注册一次覆盖所有连接，必须先于任何连接打开
    loadSqliteVec();

    final dir = await Directory.systemTemp.createTemp('vec_bg_test');
    addTearDown(() => dir.delete(recursive: true));
    final db = MoodiaryDatabase.forTesting(
      NativeDatabase.createInBackground(
        File('${dir.path}/test.db'),
        readPool: 2,
      ),
    );
    addTearDown(db.close);

    await db.customStatement(
      'CREATE VIRTUAL TABLE vec_t USING vec0(embedding float[4])',
    );
    await db.customStatement(
      'INSERT INTO vec_t(rowid, embedding) VALUES (1, ?)',
      [
        _f32([1, 0, 0, 0]),
      ],
    );

    final version = await db
        .customSelect('SELECT vec_version() AS v')
        .getSingle();
    expect(version.read<String>('v'), startsWith('v0.1.9'));

    final rows = await db
        .customSelect(
          'SELECT rowid FROM vec_t WHERE embedding MATCH ? AND k = 1',
          variables: [
            Variable(_f32([1, 0, 0, 0])),
          ],
        )
        .get();
    expect(rows.single.read<int>('rowid'), 1);
  });
}
