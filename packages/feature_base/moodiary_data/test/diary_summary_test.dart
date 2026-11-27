import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

class _Selects extends QueryInterceptor {
  final queries = <({String sql, List<Object?> args})>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    queries.add((sql: statement, args: args));
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;
  late _Selects selects;

  Future<void> insertDiary(
    String id, {
    String? category,
    bool show = true,
    int time = 10,
    int modified = 20,
    String? text,
  }) => db
      .into(db.diaries)
      .insert(
        DiariesCompanion.insert(
          id: id,
          title: 'Title $id',
          categoryId: Value(category),
          content: 'Body ' * 2000,
          contentText: text ?? '',
          time: time,
          lastModified: modified,
          show: show ? 1 : 0,
          type: DiaryType.tiptap.value,
          moodLevel: text == null
              ? const Value.absent()
              : Value(DiaryMood.okay.score),
          weatherIcon: text == null ? const Value.absent() : const Value('sun'),
          weatherTemp: const Value('20'),
          weatherText: const Value('Sunny'),
          placeId: text == null ? const Value.absent() : const Value('home'),
          aspect: text == null ? const Value.absent() : const Value(1.5),
        ),
      );

  setUp(() {
    selects = _Selects();
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ).interceptWith(selects),
    );
    repo = DiaryRepository(db);
    addTearDown(db.close);
    addTearDown(repo.dispose);
  });

  test(
    'home summaries match full diaries for filters, sorts and pages',
    () async {
      const token = '\uFDEF名字😀\uFDD0';
      final atRuneLimit = '${'😀' * 238}$token${' tail' * 400}';
      final atRawLimit = '${' ' * 395}ok$token';
      final exactRawLimit = 'exact${' ' * 395}';
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'category',
              name: 'Category',
              lastModified: 0,
            ),
          );
      await insertDiary('a', category: 'category', text: atRuneLimit);
      await insertDiary('b', category: 'category', text: atRawLimit);
      await insertDiary('c', category: 'orphan', time: 30, text: exactRawLimit);
      await insertDiary(
        'd',
        time: 1,
        modified: 40,
        text: '${exactRawLimit}tail',
      );
      await insertDiary('e', category: 'category', show: false);
      await insertDiary('f', category: 'category', time: 20, modified: 30);

      for (final id in ['tag1', 'tag2', 'deleted']) {
        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: id,
                name: 'Trip',
                deleted: Value(id == 'deleted' ? 1 : 0),
                lastModified: 0,
              ),
            );
      }
      for (final (id, tag, seq) in [
        ('a', 'tag1', 0),
        ('a', 'tag2', 1),
        ('b', 'tag2', 0),
        ('c', 'tag1', 0),
        ('d', 'deleted', 0),
        ('e', 'tag1', 0),
      ]) {
        await db
            .into(db.diaryTags)
            .insert(
              DiaryTagsCompanion.insert(diaryId: id, seq: seq, tagId: tag),
            );
      }
      for (final (kind, name, seq) in [
        ('image', 'image2', 1),
        ('video', 'video2', 1),
        ('image', 'image1', 0),
        ('video', 'video1', 0),
        ('image', 'image3', 2),
        ('audio', 'audio1', 0),
        ('audio', 'audio2', 1),
        ('file', 'file1', 0),
      ]) {
        await db
            .into(db.diaryMedia)
            .insert(
              DiaryMediaCompanion.insert(
                diaryId: 'a',
                kind: kind,
                seq: seq,
                fileName: name,
              ),
            );
      }

      for (final (category, uncat, tag, expectedIds) in [
        (null, false, null, ['a', 'b', 'c', 'd', 'f']),
        ('category', false, null, ['a', 'b', 'f']),
        (null, true, null, ['c', 'd']),
        (null, false, 'Trip', ['a', 'b', 'c']),
      ]) {
        for (final sort in DiarySort.values) {
          final full = await repo.getDiaryByCategory(
            categoryId: category,
            uncategorized: uncat,
            tagName: tag,
            sort: sort,
          );
          final expected = full.map(diarySummaryFromDiary).toList();
          final summaries = await repo.getDiarySummariesByCategory(
            categoryId: category,
            uncategorized: uncat,
            tagName: tag,
            sort: sort,
          );
          expect(
            summaries.map((summary) => summary.id),
            unorderedEquals(expectedIds),
          );
          expect(summaries, expected);
          final sorted = summaries.reversed.toList()
            ..sort(diarySummarySortComparator(sort));
          expect(sorted, summaries);
          expect(
            await repo.getDiarySummariesByCategory(
              categoryId: category,
              uncategorized: uncat,
              tagName: tag,
              sort: sort,
              offset: 1,
              limit: 2,
            ),
            expected.skip(1).take(2),
          );
        }
      }

      final all = await repo.getDiarySummariesByCategory();
      final byId = {for (final summary in all) summary.id: summary};
      expect(all.map((summary) => summary.id), ['c', 'f', 'b', 'a', 'd']);
      final rich = byId['a']!;
      expect(rich.contentPreview, '${'😀' * 238}…');
      expect(rich.visualMedia, const [
        DiaryVisualMedia(name: 'video1', isVideo: true),
        DiaryVisualMedia(name: 'video2', isVideo: true),
        DiaryVisualMedia(name: 'image1', isVideo: false),
      ]);
      expect(
        (rich.moreVisualCount, rich.audioCount, rich.fileCount),
        (2, 2, 1),
      );
      expect(byId['b']!.contentPreview, 'ok…');
      expect(byId['c']!.contentPreview, 'exact');
      expect(byId['d']!.contentPreview, 'exact…');
      expect(byId['f']!.visualMedia, isEmpty);
      expect(byId['f']!.moreVisualCount, 0);
    },
  );

  test(
    'summary SQL selects only needed data and uses the category sort index',
    () async {
      await insertDiary('a', category: 'category', text: 'before\u0000after');
      selects.queries.clear();
      expect(
        await repo.getDiarySummariesByCategory(categoryId: 'missing'),
        isEmpty,
      );
      expect(selects.queries, hasLength(1));
      selects.queries.clear();

      final summaries = await repo.getDiarySummariesByCategory(
        categoryId: 'category',
        sort: .lastModifiedDesc,
      );
      expect(summaries.single.contentPreview, 'before');
      expect(selects.queries, hasLength(2));
      final page = selects.queries.first;
      final media = selects.queries.last.sql;
      expect(
        page.sql,
        contains(RegExp(r'SUBSTR\([^,]+,\s*1,\s*400\)', caseSensitive: false)),
      );
      expect(
        page.sql,
        isNot(
          contains(RegExp(r'\b(content|tags_text|weather_text|diary_tags)\b')),
        ),
      );
      expect(media, contains('diary_media'));
      expect(media, isNot(contains(RegExp(r'\b(name|diary_tags)\b'))));

      final plan = await db.executor.runSelect(
        'EXPLAIN QUERY PLAN ${page.sql}',
        page.args,
      );
      final details = plan.map((row) => row['detail']).join('\n');
      expect(details, contains('idx_diaries_show_cat_lastmod'));
      expect(details, isNot(contains('TEMP B-TREE')));
    },
  );
}
