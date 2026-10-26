import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/src/data/editor_migration_service.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

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

  group('内容 schema v2 升级', () {
    late MoodiaryDatabase db;
    late Directory support;
    final v1 = jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': '旧正文'},
          ],
        },
        {
          'type': 'audio',
          'attrs': {'filename': 'audio-1.m4a'},
        },
      ],
    });

    setUpAll(() {
      support = Directory.systemTemp.createTempSync('content-upgrade');
      PlatformService.get().applicationSupportPath = support.path;
    });

    tearDownAll(() => support.deleteSync(recursive: true));

    setUp(() {
      db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
      getIt
        ..registerSingleton<IKVStorage>(MemoryKVStorage())
        ..registerSingleton<DiaryRepository>(DiaryRepository(db));
      final backup = File(EditorMigrationService.contentBackupPath);
      if (backup.existsSync()) backup.deleteSync();
    });

    tearDown(() async {
      await getIt.reset();
      await db.close();
    });

    Future<void> rawInsert(String id, String content) => db
        .into(db.diaries)
        .insert(
          DiariesCompanion.insert(
            id: id,
            title: '',
            content: content,
            contentText: '陈旧',
            time: 1,
            lastModified: 2,
            show: 1,
            type: 'tiptap',
          ),
        );

    test('空库直接记为已升级，不进迁移页', () async {
      await EditorMigrationService.refreshRequiresMigration();
      expect(EditorMigrationService.requiresContentUpgrade, isFalse);
      expect(EditorMigrationService.requiresMigration, isFalse);
      expect(MoodiaryKVs.contentSchemaV2.get(), isTrue);
    });

    test('有日记且未升级 → 需要迁移；标志已置位 → 不需要', () async {
      await rawInsert('a', v1);
      await EditorMigrationService.refreshRequiresMigration();
      expect(EditorMigrationService.requiresContentUpgrade, isTrue);
      expect(EditorMigrationService.requiresMigration, isTrue);
      expect(EditorMigrationService.hasLegacyDiaries, isFalse);

      MoodiaryKVs.contentSchemaV2.set(true);
      await EditorMigrationService.refreshRequiresMigration();
      expect(EditorMigrationService.requiresMigration, isFalse);
    });

    test('先写全量备份再归一，成功后才置位；重跑不覆盖原始备份', () async {
      await rawInsert('a', v1);
      await rawInsert('b', v1);
      await EditorMigrationService.refreshRequiresMigration();

      final progress = <int>[];
      final changed = await EditorMigrationService.upgradeContent(
        onProgress: (done, total) => progress.add(done),
      );
      expect(changed, 2);
      expect(progress.last, 2);
      expect(MoodiaryKVs.contentSchemaV2.get(), isTrue);
      expect(EditorMigrationService.requiresContentUpgrade, isFalse);

      final backup = jsonDecode(
        File(EditorMigrationService.contentBackupPath).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(backup['kind'], 'content-v2-backup');
      final saved = backup['diaries'] as List;
      expect(saved.map((d) => d['id']), unorderedEquals(['a', 'b']));
      expect(saved.every((d) => d['content'] == v1), isTrue);

      final upgraded = (await getIt<DiaryRepository>().getDiaryByBusinessId(
        'a',
      ))!;
      expect(upgraded.content, isNot(contains('filename')));
      expect(upgraded.audioName, ['audio-1.m4a']);
      expect(upgraded.contentText, '旧正文');
      expect(upgraded.lastModified.microsecondsSinceEpoch, 2);

      await EditorMigrationService.upgradeContent();
      final again = jsonDecode(
        File(EditorMigrationService.contentBackupPath).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        (again['diaries'] as List).every((d) => d['content'] == v1),
        isTrue,
      );
    });
  });
}
