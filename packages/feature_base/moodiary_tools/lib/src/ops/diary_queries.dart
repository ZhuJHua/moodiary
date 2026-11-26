library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';

typedef _KeywordSearch = ({
  List<Diary> results,
  int total,
  Map<String, DiarySearchHit> hits,
  bool capped,
});

typedef DiarySearch = ({
  List<SearchRow> rows,
  int total,
  bool totalIsLowerBound,
  bool meaningRan,
  bool semanticAvailable,
  Map<String, DiarySearchHit> keywordHits,
});

typedef SearchRow = ({Diary diary, bool keyword, bool meaning, double? score});

typedef _FusedSearchRow = ({
  String id,
  Diary? diary,
  bool keyword,
  bool meaning,
  double? score,
});

const int maxBatchRead = 10;
const int _searchCandidateLimit = 50;

class DiaryQueries {
  DiaryQueries({required this.diaries, required this.tags, this.semantic});

  final DiaryRepository diaries;
  final TagRepository tags;

  final EmbedIndexService? semantic;

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
    final tagIds = tag == null
        ? null
        : {
            for (final entry in await tags.getAllTags())
              if (entry.name == tag) entry.id,
          };
    final semanticAvailable = semantic?.enabled ?? false;
    final meaningRan =
        mode != 'keyword' && query.isNotEmpty && semanticAvailable;
    final keywordRan = !meaningRan || mode != 'meaning';
    final keywordResult = keywordRan
        ? await _keyword(
            query: query,
            categoryId: categoryId,
            start: start,
            endExclusive: endExclusive,
            sort: meaningRan ? 'relevance' : sort,
            limit: meaningRan ? _searchCandidateLimit : limit,
            offset: meaningRan ? 0 : offset,
            tagIds: tagIds,
            fixedWindow: meaningRan,
          )
        : (
            results: <Diary>[],
            total: 0,
            hits: <String, DiarySearchHit>{},
            capped: false,
          );
    final candidates = meaningRan
        ? await _semanticHits(
            query: query,
            limit: _searchCandidateLimit,
            categoryId: categoryId,
            start: start,
            endExclusive: endExclusive,
          )
        : const <SemanticHit>[];
    final semanticDiaries = {
      for (final diary in await diaries.getDiariesByIds([
        for (final hit in candidates) hit.diaryId,
      ]))
        diary.id: diary,
    };
    final hits = <SemanticHit>[];
    for (final hit in candidates) {
      final diary = semanticDiaries[hit.diaryId];
      if (diary == null ||
          !diary.show ||
          (categoryId != null && diary.categoryId != categoryId) ||
          !_inRange(diary.time, start, endExclusive) ||
          (tagIds != null && !diary.tagIds.any(tagIds.contains))) {
        continue;
      }
      hits.add(hit);
    }
    final fused = _fuse(
      keywordResult.results,
      hits,
      limit: keywordResult.results.length + hits.length,
    );
    final rows = _resolve(fused, semanticDiaries);
    if (sort != null && sort != 'relevance') {
      rows.sort(
        (first, next) =>
            diarySortComparator(parseDiarySort(sort))(first.diary, next.diary),
      );
    }
    final bounded =
        meaningRan &&
        (candidates.length >= _searchCandidateLimit || keywordResult.capped);
    final observed =
        keywordResult.results.length +
        hits.length -
        _overlap(keywordResult.results, hits);
    return (
      rows: rows.skip(meaningRan ? offset : 0).take(limit).toList(),
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
      keywordHits: keywordResult.hits,
    );
  }

  Future<_KeywordSearch> _keyword({
    required String query,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
    String? sort,
    required int limit,
    required int offset,
    Set<String>? tagIds,
    bool fixedWindow = false,
  }) async {
    if (query.isNotEmpty) {
      final filterInDart = tagIds != null || sort == 'modified';
      final hits = await diaries.searchDiaries(
        query: query,
        categoryId: categoryId,
        start: start,
        end: endExclusive,
        sort: _parseSearchSort(sort),
        limit: filterInDart && !fixedWindow ? -1 : limit,
        offset: filterInDart ? 0 : offset,
      );
      final total = filterInDart
          ? hits.length
          : hits.length >= limit || (offset > 0 && hits.isEmpty)
          ? await diaries.countSearchDiaries(
              query: query,
              categoryId: categoryId,
              start: start,
              end: endExclusive,
            )
          : offset + hits.length;
      final matched = [
        for (final hit in hits)
          if (tagIds == null || hit.diary.tagIds.any(tagIds.contains))
            hit.diary,
      ];
      if (sort == 'modified') {
        matched.sort(diarySortComparator(DiarySort.lastModifiedDesc));
      }
      return (
        results: matched.skip(filterInDart ? offset : 0).take(limit).toList(),
        total: tagIds == null ? total : matched.length,
        hits: {for (final hit in hits) hit.diary.id: hit},
        capped: fixedWindow && hits.length >= _searchCandidateLimit,
      );
    }
    if (tagIds == null && start == null && endExclusive == null) {
      final counts = await diaries.diaryCountByCategory();
      final page = await diaries.getDiaryByCategory(
        categoryId: categoryId,
        sort: parseDiarySort(sort),
        limit: limit,
        offset: offset,
      );
      return (
        results: page,
        total: categoryId == null
            ? counts.total
            : counts.byCategory[categoryId] ?? 0,
        hits: const <String, DiarySearchHit>{},
        capped: false,
      );
    }
    final all = start != null || endExclusive != null
        ? await diaries.getDiariesByDateRange(
            start ?? DateTime.utc(1),
            endExclusive ?? DateTime.utc(9999),
          )
        : await diaries.getDiaryByCategory(
            categoryId: categoryId,
            sort: parseDiarySort(sort),
          );
    final matched =
        all
            .where(
              (diary) =>
                  (categoryId == null || diary.categoryId == categoryId) &&
                  _inRange(diary.time, start, endExclusive) &&
                  (tagIds == null || diary.tagIds.any(tagIds.contains)),
            )
            .toList()
          ..sort(diarySortComparator(parseDiarySort(sort)));
    return (
      results: matched.skip(offset).take(limit).toList(),
      total: matched.length,
      hits: const <String, DiarySearchHit>{},
      capped: false,
    );
  }

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

  List<SearchRow> _resolve(
    List<_FusedSearchRow> rows,
    Map<String, Diary> semanticDiaries,
  ) {
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
      final diary = semanticDiaries[row.id];
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
    final requested = ids.take(maxBatchRead).toList();
    final byId = {
      for (final diary in await diaries.getDiariesByIds(requested))
        diary.id: diary,
    };
    final found = <Diary>[];
    final missing = <String>[];
    for (final id in requested) {
      final diary = byId[id];
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
