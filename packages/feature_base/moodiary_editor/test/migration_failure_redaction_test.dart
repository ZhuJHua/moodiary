import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_editor/src/data/editor_migration_service.dart';

void main() {
  const title = '出差第三天';
  const body = '{"type":"doc","content":[{"type":"paragraph"}]}';

  String sqliteExceptionText({String? explanation}) =>
      'SqliteException(13): while executing statement, database or disk is full'
      '${explanation == null ? '' : ', $explanation'}'
      '\n  Causing statement: INSERT INTO diaries (id, title, content) '
      'VALUES (?, ?, ?) ON CONFLICT DO UPDATE SET title = ?, '
      'parameters: abc-123, $title, $body, $title';

  group('redactDbError', () {
    test('截掉 Causing statement 之后的整段，标题与正文都不出现', () {
      final redacted = EditorMigrationService.redactDbError(
        sqliteExceptionText(),
      );
      expect(redacted, isNot(contains(title)));
      expect(redacted, isNot(contains(body)));
      expect(redacted, isNot(contains('Causing statement')));
      expect(redacted, isNot(contains('parameters:')));
      expect(redacted, contains('SqliteException(13)'));
      expect(redacted, contains('database or disk is full'));
    });

    test('explanation 段留在切点之前，不被误删', () {
      final redacted = EditorMigrationService.redactDbError(
        sqliteExceptionText(explanation: 'SQLITE_FULL'),
      );
      expect(redacted, contains('SQLITE_FULL'));
      expect(redacted, isNot(contains(title)));
    });

    test('FTS 那条把整篇分词后的正文当参数绑上，同样被截掉', () {
      final redacted = EditorMigrationService.redactDbError(
        'SqliteException(1): no such table: diary_fts\n'
        '  Causing statement: INSERT INTO diary_fts VALUES (?, ?), '
        'parameters: 1, 出差 第三 天 今天 很 累',
      );
      expect(redacted, 'SqliteException(1): no such table: diary_fts');
    });

    test('认不出形状的异常仍有长度上限，防止正文以别的形状漏出去', () {
      final redacted = EditorMigrationService.redactDbError(
        'StateError: ${'日' * 2000}',
      );
      expect(redacted.length, lessThan(560));
      expect(redacted, endsWith('…[truncated]'));
    });

    test('普通异常原样保留（不该为了脱敏牺牲可读性）', () {
      expect(
        EditorMigrationService.redactDbError(
          const FileSystemException('Cannot open file', '/data/x.json'),
        ),
        contains('Cannot open file'),
      );
    });
  });
}
