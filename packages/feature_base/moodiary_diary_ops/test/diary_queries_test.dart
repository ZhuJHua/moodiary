import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import 'support.dart';

class _SemanticIndex extends Fake implements EmbedIndexService {
  _SemanticIndex(this.ids, {this.enabled = true});

  final List<String> ids;
  @override
  final bool enabled;
  int? requestedLimit;
  String? category;
  DateTime? rangeStart;
  DateTime? rangeEnd;

  @override
  Future<List<SemanticHit>> search(
    String query, {
    int limit = 5,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    requestedLimit = limit;
    category = categoryId;
    rangeStart = start;
    rangeEnd = endExclusive;
    return [
      for (final id in ids.take(limit))
        (diaryId: id, distance: 0.25, startOff: 0, len: 1),
    ];
  }
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late DiaryQueries queries;

  setUp(() {
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    queries = DiaryQueries(diaries: diaries);
  });

  tearDown(() => db.close());

  group('search', () {
    test(
      'semantic search receives the requested limit without a cap',
      () async {
        await diaries.insertADiary(makeDiary('entry', 'orchard'));
        final index = _SemanticIndex(['entry']);
        queries = DiaryQueries(diaries: diaries, semantic: index);

        final result = await queries.search(query: 'orchard', limit: 1030);

        expect(index.requestedLimit, 1030);
        expect(result.rows.single.diary.id, 'entry');
        expect(result.total, 1);
        expect(result.totalIsLowerBound, isFalse);
      },
    );

    test('keyword search retains totals and sort without an index', () async {
      await diaries.insertDiaries([
        for (var index = 0; index < 4; index++)
          makeDiary(
            'entry-$index',
            'orchard',
            time: DateTime.utc(2026, 1, index + 1),
          ),
      ]);
      final result = await queries.search(
        query: 'orchard',
        sort: 'oldest',
        limit: 2,
      );

      expect(result.rows.map((row) => row.diary.id), ['entry-0', 'entry-1']);
      expect(result.total, 4);
      expect(result.totalIsLowerBound, isFalse);
      expect(result.meaningRan, isFalse);
      expect(result.semanticAvailable, isFalse);
      expect(result.keywords, ['orchard']);
      expect(result.rows.every((row) => row.keyword && !row.meaning), isTrue);

      final full = await queries.search(query: 'orchard', limit: 10);
      expect(full.rows, hasLength(4));
      expect(full.total, 4);
    });

    test(
      'fusion ranks shared hits first and reports a bounded total',
      () async {
        await diaries.insertDiaries([
          makeDiary('keyword-first', 'orchard', time: DateTime.utc(2026, 1, 1)),
          makeDiary('shared', 'orchard', time: DateTime.utc(2026, 1, 2)),
          makeDiary('meaning-only', 'trees'),
        ]);
        final index = _SemanticIndex(['shared', 'meaning-only']);
        queries = DiaryQueries(diaries: diaries, semantic: index);
        final result = await queries.search(
          query: 'orchard',
          sort: 'oldest',
          limit: 2,
        );

        expect(result.rows.map((row) => row.diary.id), [
          'shared',
          'keyword-first',
        ]);
        expect(index.requestedLimit, 2);
        expect(result.total, 3);
        expect(result.totalIsLowerBound, isTrue);
        expect(result.meaningRan, isTrue);
        final full = await queries.search(
          query: 'orchard',
          sort: 'oldest',
          limit: 4,
        );
        expect(full.rows.map((row) => row.diary.id), [
          'shared',
          'keyword-first',
          'meaning-only',
        ]);
        expect(full.rows.first.keyword, isTrue);
        expect(full.rows.first.meaning, isTrue);
        expect(full.rows.first.score, 0.75);
        expect(full.total, 3);
        expect(full.totalIsLowerBound, isFalse);
      },
    );

    test(
      'meaning mode passes filters and keyword mode skips the index',
      () async {
        await diaries.insertADiary(makeDiary('meaning', 'trees'));
        final index = _SemanticIndex(['meaning']);
        queries = DiaryQueries(diaries: diaries, semantic: index);
        final start = DateTime.utc(2026, 1, 1);
        final end = DateTime.utc(2026, 2, 1);
        final result = await queries.search(
          mode: 'meaning',
          query: 'orchard',
          categoryId: 'work',
          start: start,
          endExclusive: end,
          limit: 3,
        );
        expect(result.rows.single.diary.id, 'meaning');
        expect(result.meaningRan, isTrue);
        expect(index.category, 'work');
        expect(index.rangeStart, start);
        expect(index.rangeEnd, end);
        index.requestedLimit = null;
        final keyword = await queries.search(
          mode: 'keyword',
          query: 'trees',
          limit: 3,
        );
        expect(keyword.semanticAvailable, isTrue);
        expect(keyword.meaningRan, isFalse);
        expect(index.requestedLimit, isNull);
      },
    );

    test('an unavailable index leaves meaning mode empty', () async {
      await diaries.insertADiary(makeDiary('keyword', 'orchard'));
      for (final index in [
        null,
        _SemanticIndex(['keyword'], enabled: false),
      ]) {
        final result = await DiaryQueries(
          diaries: diaries,
          semantic: index,
        ).search(mode: 'meaning', query: 'orchard', limit: 2);
        expect(result.rows, isEmpty);
        expect(result.total, 0);
        expect(result.meaningRan, isFalse);
        expect(result.semanticAvailable, isFalse);
      }
    });
  });
}
