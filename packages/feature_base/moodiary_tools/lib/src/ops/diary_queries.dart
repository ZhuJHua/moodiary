/// Read side of the diary catalog: keyword search, semantic search, fusion,
/// and the batch reads the tool layer needs.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// Keyword matches and their total count.
typedef _KeywordSearch = ({
  List<Diary> results,
  int total,
  List<String> keywords,
  Map<String, DiarySearchHit> hits,
});

typedef DiarySearch = ({
  List<SearchRow> rows,
  int total,
  bool totalIsLowerBound,
  bool meaningRan,
  bool semanticAvailable,
  List<String> keywords,
  Map<String, DiarySearchHit> keywordHits,
});

/// One fused row: a diary (when it could be loaded), how it was found and the
/// semantic similarity when the meaning path contributed it.
typedef SearchRow = ({Diary diary, bool keyword, bool meaning, double? score});

typedef _FusedSearchRow = ({
  String id,
  Diary? diary,
  bool keyword,
  bool meaning,
  double? score,
});

final RegExp _whitespace = RegExp(r'\s+');

/// Upper bound on the ids one batch read accepts.
const int maxBatchRead = 10;

/// Diary search and batch reads.
class DiaryQueries {
  DiaryQueries({required this.diaries, this.semantic});

  final DiaryRepository diaries;

  /// The local semantic index, when the device has one enabled.
  final EmbedIndexService? semantic;

  /// Searches both paths and returns their fused ranking.
  Future<DiarySearch> search({
    String mode = 'auto',
    required String query,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
    String? sort,
    required int limit,
    int offset = 0,
    String? tag,
  }) async {
    final candidateLimit = limit + offset;
    final semanticAvailable = semantic?.enabled ?? false;
    final keywordRan = query.isEmpty || mode != 'meaning';
    final meaningRan =
        mode != 'keyword' && query.isNotEmpty && semanticAvailable;
    final keywordResult = keywordRan
        ? await _keyword(
            query: query,
            categoryId: categoryId,
            start: start,
            endExclusive: endExclusive,
            sort: sort,
            limit: candidateLimit,
            tag: tag,
          )
        : (
            results: <Diary>[],
            total: 0,
            keywords: <String>[],
            hits: <String, DiarySearchHit>{},
          );
    final candidates = meaningRan
        ? await _semanticHits(
            query: query,
            limit: candidateLimit,
            categoryId: categoryId,
            start: start,
            endExclusive: endExclusive,
          )
        : const <SemanticHit>[];
    final hits = <SemanticHit>[];
    for (final hit in candidates) {
      final diary = await diaries.getDiaryByBusinessId(hit.diaryId);
      if (diary == null ||
          !diary.show ||
          (categoryId != null && diary.categoryId != categoryId) ||
          !_inRange(diary.time, start, endExclusive) ||
          (tag != null && !diary.tags.contains(tag))) {
        continue;
      }
      hits.add(hit);
    }
    final fused = _fuse(
      keywordResult.results,
      hits,
      limit: keywordResult.results.length + hits.length,
    );
    final rows = await _resolve(fused);
    if (sort != null && sort != 'relevance') {
      rows.sort(
        (first, next) =>
            diarySortComparator(parseDiarySort(sort))(first.diary, next.diary),
      );
    }
    final bounded =
        meaningRan &&
        (candidates.length >= candidateLimit ||
            keywordResult.total > keywordResult.results.length);
    final observed =
        keywordResult.results.length +
        hits.length -
        _overlap(keywordResult.results, hits);
    return (
      rows: rows.skip(offset).take(limit).toList(),
      total: meaningRan
          ? (bounded
                ? (keywordResult.total > observed
                      ? keywordResult.total
                      : observed)
                : observed)
          : keywordResult.total,
      totalIsLowerBound: bounded,
      meaningRan: meaningRan,
      semanticAvailable: semanticAvailable,
      keywords: keywordResult.keywords,
      keywordHits: keywordResult.hits,
    );
  }

  /// Keyword search, or filtered browsing for an empty query. Full pages also
  /// query the complete match count.
  Future<_KeywordSearch> _keyword({
    required String query,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
    String? sort,
    required int limit,
    String? tag,
  }) async {
    final keywords = query
        .split(_whitespace)
        .where((word) => word.isNotEmpty)
        .toList();
    if (query.isNotEmpty) {
      final total = await diaries.countSearchDiaries(
        query: query,
        categoryId: categoryId,
        start: start,
        end: endExclusive,
      );
      final hits = await diaries.searchDiaries(
        query: query,
        categoryId: categoryId,
        start: start,
        end: endExclusive,
        sort: _parseSearchSort(sort),
        limit: tag == null && sort != 'modified'
            ? limit
            : total < 1
            ? 1
            : total,
      );
      final matched = [
        for (final hit in hits)
          if (tag == null || hit.diary.tags.contains(tag)) hit.diary,
      ];
      if (sort == 'modified') {
        matched.sort(diarySortComparator(DiarySort.lastModifiedDesc));
      }
      return (
        results: matched.take(limit).toList(),
        total: tag == null ? total : matched.length,
        keywords: keywords,
        hits: {for (final hit in hits) hit.diary.id: hit},
      );
    }
    if (tag == null && start == null && endExclusive == null) {
      final counts = await diaries.diaryCountByCategory();
      final page = await diaries.getDiaryByCategory(
        categoryId: categoryId,
        sort: parseDiarySort(sort),
        limit: limit,
      );
      return (
        results: page,
        total: categoryId == null
            ? counts.total
            : counts.byCategory[categoryId] ?? 0,
        keywords: keywords,
        hits: const <String, DiarySearchHit>{},
      );
    }
    final all = await diaries.getDiaryByCategory(
      categoryId: categoryId,
      sort: parseDiarySort(sort),
    );
    final matched = all
        .where(
          (diary) =>
              _inRange(diary.time, start, endExclusive) &&
              (tag == null || diary.tags.contains(tag)),
        )
        .toList();
    return (
      results: matched.take(limit).toList(),
      total: matched.length,
      keywords: keywords,
      hits: const <String, DiarySearchHit>{},
    );
  }

  /// Meaning based hits; empty when no query or no enabled index.
  Future<List<SemanticHit>> _semanticHits({
    required String query,
    required int limit,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    if (query.isEmpty) return const [];
    final index = semantic;
    if (index == null || !index.enabled) return const [];
    return index.search(
      query,
      limit: limit,
      categoryId: categoryId,
      start: start,
      endExclusive: endExclusive,
    );
  }

  /// Reciprocal-rank fusion of the keyword and meaning paths.
  List<_FusedSearchRow> _fuse(
    List<Diary> keyword,
    List<SemanticHit> hits, {
    required int limit,
  }) {
    const k = 60;
    final score = <String, double>{};
    final byId = <String, Diary>{};
    final fromKeyword = <String>{};
    final fromMeaning = <String>{};
    final similarity = <String, double>{};
    for (var i = 0; i < keyword.length; i++) {
      final d = keyword[i];
      byId[d.id] = d;
      fromKeyword.add(d.id);
      score[d.id] = (score[d.id] ?? 0) + 1 / (k + i + 1);
    }
    for (var i = 0; i < hits.length; i++) {
      final h = hits[i];
      fromMeaning.add(h.diaryId);
      similarity[h.diaryId] = (1 - h.distance).clamp(-1.0, 1.0);
      score[h.diaryId] = (score[h.diaryId] ?? 0) + 1 / (k + i + 1);
    }
    final ids = score.keys.toList()
      ..sort((a, b) => score[b]!.compareTo(score[a]!));
    return [
      for (final id in ids.take(limit))
        (
          id: id,
          diary: byId[id],
          keyword: fromKeyword.contains(id),
          meaning: fromMeaning.contains(id),
          score: similarity[id],
        ),
    ];
  }

  /// Loads the diaries the fused rows only know by id.
  Future<List<SearchRow>> _resolve(List<_FusedSearchRow> rows) async {
    final resolved = <SearchRow>[];
    for (final row in rows) {
      if (row.diary != null) {
        resolved.add((
          diary: row.diary!,
          keyword: row.keyword,
          meaning: row.meaning,
          score: row.score,
        ));
        continue;
      }
      final diary = await diaries.getDiaryByBusinessId(row.id);
      if (diary == null || !diary.show) continue;
      resolved.add((
        diary: diary,
        keyword: row.keyword,
        meaning: row.meaning,
        score: row.score,
      ));
    }
    return resolved;
  }

  /// Number of rows the keyword and meaning paths share, so the fused total
  /// does not count a diary twice.
  int _overlap(List<Diary> keyword, List<SemanticHit> hits) {
    final ids = {for (final d in keyword) d.id};
    var n = 0;
    for (final h in hits) {
      if (ids.contains(h.diaryId)) n++;
    }
    return n;
  }

  /// Batch read by business id; hidden diaries count as missing.
  Future<({List<Diary> found, List<String> missing})> read(
    List<String> ids,
  ) async {
    final found = <Diary>[];
    final missing = <String>[];
    for (final id in ids.take(maxBatchRead)) {
      final diary = await diaries.getDiaryByBusinessId(id);
      if (diary == null || !diary.show) {
        missing.add(id);
        continue;
      }
      found.add(diary);
    }
    return (found: found, missing: missing);
  }
}

SearchSort _parseSearchSort(String? name) => switch (name) {
  'newest' => SearchSort.timeDesc,
  'oldest' => SearchSort.timeAsc,
  _ => SearchSort.relevance,
};

DiarySort parseDiarySort(String? name) => switch (name) {
  'oldest' => DiarySort.timeAsc,
  'modified' => DiarySort.lastModifiedDesc,
  _ => DiarySort.timeDesc,
};

bool _inRange(DateTime time, DateTime? start, DateTime? endExclusive) {
  if (start != null && time.isBefore(start)) return false;
  if (endExclusive != null && !time.isBefore(endExclusive)) return false;
  return true;
}
