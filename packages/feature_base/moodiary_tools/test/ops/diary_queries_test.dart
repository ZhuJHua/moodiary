import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

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
  late TagRepository tagRepo;
  late DiaryRepository diaries;
  late DiaryQueries queries;

  setUp(() {
    db = openTestDatabase();
    tagRepo = TagRepository(db);
    diaries = DiaryRepository(db);
    queries = DiaryQueries(tags: tagRepo, diaries: diaries);
  });

  tearDown(() => db.close());

  group('search', () {
    test(
      'semantic search uses a fixed candidate window regardless of page size',
      () async {
        await diaries.insertADiary(makeDiary('entry', 'orchard'));
        final index = _SemanticIndex(['entry']);
        queries = DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: index,
        );

        final result = await queries.search(query: 'orchard', limit: 1030);

        expect(index.requestedLimit, 50);
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
      expect(result.rows.every((row) => row.keyword && !row.meaning), isTrue);

      final full = await queries.search(query: 'orchard', limit: 10);
      expect(full.rows, hasLength(4));
      expect(full.total, 4);
    });

    test(
      'fusion ranks shared hits first and reports an exact uncapped total',
      () async {
        await diaries.insertDiaries([
          makeDiary('keyword-first', 'orchard', time: DateTime.utc(2026, 1, 1)),
          makeDiary('shared', 'orchard', time: DateTime.utc(2026, 1, 2)),
          makeDiary('meaning-only', 'trees', time: DateTime.utc(2026, 1, 3)),
        ]);
        final index = _SemanticIndex(['shared', 'meaning-only']);
        queries = DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: index,
        );
        final result = await queries.search(
          query: 'orchard',
          sort: 'relevance',
          limit: 2,
        );

        expect(result.rows.map((row) => row.diary.id), [
          'shared',
          'keyword-first',
        ]);
        expect(index.requestedLimit, 50);
        expect(result.total, 3);
        expect(result.totalIsLowerBound, isFalse);
        expect(result.meaningRan, isTrue);
        final full = await queries.search(
          query: 'orchard',
          sort: 'relevance',
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
        final page = await queries.search(
          query: 'orchard',
          offset: 1,
          limit: 2,
        );
        expect(page.rows.map((row) => row.diary.id), [
          'keyword-first',
          'meaning-only',
        ]);
        final sorted = await queries.search(
          query: 'orchard',
          sort: 'oldest',
          limit: 4,
        );
        expect(sorted.rows.map((row) => row.diary.id), [
          'keyword-first',
          'shared',
          'meaning-only',
        ]);
      },
    );

    test(
      'meaning mode passes filters and keyword mode skips the index',
      () async {
        await diaries.insertADiary(
          makeDiary('meaning', 'trees', categoryId: 'work'),
        );
        final index = _SemanticIndex(['meaning']);
        queries = DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: index,
        );
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

    test(
      'semantic candidates exclude stale, hidden and tag mismatches',
      () async {
        await diaries.insertDiaries([
          makeDiary(
            'visible',
            'trees',
            tagIds: await tagRepo.ensureTags(['travel']),
          ),
          makeDiary('hidden', 'trees', show: false),
          makeDiary('other', 'trees'),
        ]);
        final result = await DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: _SemanticIndex(['hidden', 'unknown', 'other', 'visible']),
        ).search(query: 'trip', mode: 'meaning', tag: 'travel', limit: 10);
        expect(result.rows.single.diary.id, 'visible');
        final empty = await DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: _SemanticIndex([]),
        ).search(query: 'missing', limit: 10);
        expect(empty.rows, isEmpty);
        expect(empty.total, 0);
        expect(empty.meaningRan, true);
        expect(empty.semanticAvailable, true);
      },
    );

    test(
      'fusion pages have no repeats or omissions across fixed windows',
      () async {
        await diaries.insertDiaries([
          makeDiary('A', 'orchard', title: '', time: DateTime.utc(2026, 1, 2)),
          makeDiary('C', 'orchard', title: '', time: DateTime.utc(2026, 1, 1)),
          makeDiary('B', 'trees', title: ''),
        ]);
        final index = _SemanticIndex(['B', 'C']);
        queries = DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: index,
        );
        final ids = <String>[];
        for (var offset = 0; offset < 4; offset++) {
          final page = await queries.search(
            query: 'orchard',
            limit: 1,
            offset: offset,
          );
          ids.addAll(page.rows.map((row) => row.diary.id));
          expect(page.rows, hasLength(offset < 3 ? 1 : 0));
          expect(page.total, 3);
          expect(page.totalIsLowerBound, isFalse);
          expect(index.requestedLimit, 50);
        }
        expect(ids, ['C', 'A', 'B']);
      },
    );

    test('semantic tag filtering happens before page slicing', () async {
      await diaries.insertDiaries([
        makeDiary('A', 'trees'),
        makeDiary('B', 'trees', tagIds: await tagRepo.ensureTags(['travel'])),
      ]);
      for (final mode in ['auto', 'meaning']) {
        final index = _SemanticIndex(['A', 'B']);
        final result = await DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: index,
        ).search(query: 'trip', mode: mode, tag: 'travel', limit: 1);
        expect(result.rows.single.diary.id, 'B');
        expect(result.total, 1);
        expect(result.totalIsLowerBound, isFalse);
        expect(index.requestedLimit, 50);
      }
    });

    test(
      'meaning pages stop at the fixed window and mark capped totals',
      () async {
        final ids = [for (var index = 0; index < 51; index++) 'entry-$index'];
        await diaries.insertDiaries([
          for (final id in ids) makeDiary(id, 'trees'),
        ]);
        final index = _SemanticIndex(ids);
        queries = DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: index,
        );
        for (final offset in [0, 1, 49, 50, 100]) {
          final result = await queries.search(
            query: 'orchard',
            mode: 'meaning',
            limit: 1,
            offset: offset,
          );
          expect(
            result.rows.map((row) => row.diary.id),
            offset < 50 ? [ids[offset]] : isEmpty,
          );
          expect(result.total, 50);
          expect(result.totalIsLowerBound, isTrue);
          expect(index.requestedLimit, 50);
        }
      },
    );

    test('a full keyword window marks fusion totals as lower bounds', () async {
      await diaries.insertDiaries([
        for (var index = 0; index < 50; index++)
          makeDiary('entry-$index', 'orchard'),
      ]);
      queries = DiaryQueries(
        tags: tagRepo,
        diaries: diaries,
        semantic: _SemanticIndex([]),
      );
      final result = await queries.search(query: 'orchard', limit: 50);
      expect(result.rows, hasLength(50));
      expect(result.total, 50);
      expect(result.totalIsLowerBound, isTrue);
      final beyond = await queries.search(
        query: 'orchard',
        limit: 1,
        offset: 50,
      );
      expect(beyond.rows, isEmpty);
      expect(beyond.totalIsLowerBound, isTrue);
    });

    test(
      'keyword candidates stay capped before tag filtering and sorting',
      () async {
        await diaries.insertDiaries([
          for (var index = 0; index < 51; index++)
            makeDiary(
              'entry-$index',
              'orchard',
              title: '',
              time: DateTime.utc(2026, 1, index + 1),
              tagIds: await tagRepo.ensureTags(index == 0 ? ['travel'] : []),
            ),
        ]);
        queries = DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: _SemanticIndex([]),
        );
        final tagged = await queries.search(
          query: 'orchard',
          tag: 'travel',
          limit: 1,
        );
        expect(tagged.rows, isEmpty);
        expect(tagged.totalIsLowerBound, isTrue);
        final oldest = await queries.search(
          query: 'orchard',
          sort: 'oldest',
          limit: 1,
        );
        expect(oldest.rows.single.diary.id, 'entry-1');
        expect(oldest.total, 51);
        expect(oldest.totalIsLowerBound, isTrue);
      },
    );

    test(
      'browsing keeps paging beyond 50 even with an enabled index',
      () async {
        await diaries.insertDiaries([
          for (var index = 0; index < 51; index++)
            makeDiary(
              'entry-$index',
              'trees',
              time: DateTime.utc(2026, 1, index + 1),
            ),
        ]);
        final index = _SemanticIndex([]);
        final result =
            await DiaryQueries(
              tags: tagRepo,
              diaries: diaries,
              semantic: index,
            ).search(
              query: '',
              mode: 'meaning',
              sort: 'oldest',
              limit: 1,
              offset: 50,
            );
        expect(result.rows.single.diary.id, 'entry-50');
        expect(result.total, 51);
        expect(result.totalIsLowerBound, isFalse);
        expect(result.meaningRan, isFalse);
        expect(index.requestedLimit, isNull);
      },
    );

    test(
      'filtering a full semantic window still marks the total as bounded',
      () async {
        await diaries.insertADiary(
          makeDiary(
            'tagged',
            'trees',
            tagIds: await tagRepo.ensureTags(['travel']),
          ),
        );
        final index = _SemanticIndex([
          for (var index = 0; index < 49; index++) 'stale-$index',
          'tagged',
        ]);
        final result = await DiaryQueries(
          tags: tagRepo,
          diaries: diaries,
          semantic: index,
        ).search(query: 'trip', mode: 'meaning', tag: 'travel', limit: 1);
        expect(result.rows.single.diary.id, 'tagged');
        expect(result.total, 1);
        expect(result.totalIsLowerBound, isTrue);
      },
    );

    test(
      'an unavailable index falls back to keywords in meaning mode',
      () async {
        await diaries.insertADiary(makeDiary('keyword', 'orchard'));
        for (final index in [
          null,
          _SemanticIndex(['keyword'], enabled: false),
        ]) {
          final result = await DiaryQueries(
            tags: tagRepo,
            diaries: diaries,
            semantic: index,
          ).search(mode: 'meaning', query: 'orchard', limit: 2);
          expect(result.rows.single.diary.id, 'keyword');
          expect(result.rows.single.keyword, isTrue);
          expect(result.total, 1);
          expect(result.meaningRan, isFalse);
          expect(result.semanticAvailable, isFalse);
        }
      },
    );
  });
}
