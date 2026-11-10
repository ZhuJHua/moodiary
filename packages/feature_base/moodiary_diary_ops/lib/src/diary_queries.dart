/// Read side of the diary catalog: keyword search, semantic search, fusion,
/// paging and the batch reads the tool layer needs.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_display.dart';

/// Result of the keyword path of a search: the rows, the total match count and
/// the filters that produced them (the tool layer echoes them in its answer).
typedef KeywordSearch = ({
  List<Diary> results,
  int total,
  List<String> keywords,
  String? categoryId,
  DateTime? start,
  DateTime? endExclusive,
});

/// One fused row: a diary (when it could be loaded), how it was found and the
/// semantic similarity when the meaning path contributed it.
typedef SearchRow = ({Diary diary, bool keyword, bool meaning, double? score});

/// Upper bound on the ids one batch read accepts.
const int maxBatchRead = 10;

/// Every read the assistant tools and the MCP server perform.
class DiaryQueries {
  DiaryQueries({required this.diaries, this.semantic});

  final DiaryRepository diaries;

  /// The local semantic index, when the device has one enabled.
  final EmbedIndexService? semantic;

  /// Keyword hit path, or a filtered browse when [query] is empty.
  ///
  /// When the keyword path returns a full page the repository is asked for the
  /// complete count as well, because the fused answer reports how many matches
  /// exist beyond the rows shown.
  Future<KeywordSearch> keyword({
    required String query,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
    String? sort,
    required int limit,
  }) async {
    final keywordsForDisplay = query
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    List<Diary> results;
    int? total;
    if (query.isNotEmpty) {
      final hits = await diaries.searchDiaries(
        query: query,
        categoryId: categoryId,
        start: start,
        end: endExclusive,
        sort: _toSearchSort(sort),
        limit: limit,
      );
      results = [for (final hit in hits) hit.diary];
      if (results.length >= limit) {
        total = await diaries.countSearchDiaries(
          query: query,
          categoryId: categoryId,
          start: start,
          end: endExclusive,
        );
      }
    } else if (start != null || endExclusive != null) {
      final ranged = await diaries.getDiariesByDateRange(
        start ?? DateTime.fromMillisecondsSinceEpoch(0),
        endExclusive ?? DateTime.now().add(const Duration(days: 1)),
      );
      results =
          ranged
              .where((d) => categoryId == null || d.categoryId == categoryId)
              .where((d) => _inRange(d.time, start, endExclusive))
              .toList()
            ..sort(_diaryComparator(sort));
    } else {
      results = await diaries.getDiaryByCategory(
        categoryId: categoryId,
        sort: _toDiarySort(sort),
        limit: limit,
      );
    }

    return (
      results: results,
      total: total ?? results.length,
      keywords: keywordsForDisplay,
      categoryId: categoryId,
      start: start,
      endExclusive: endExclusive,
    );
  }

  /// Meaning based hits; empty when no query or no enabled index.
  Future<List<SemanticHit>> semanticHits({
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
  List<({String id, Diary? diary, bool keyword, bool meaning, double? score})>
  fuse(List<Diary> keyword, List<SemanticHit> hits, {required int limit}) {
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
  Future<List<SearchRow>> resolve(
    List<({String id, Diary? diary, bool keyword, bool meaning, double? score})>
    rows,
  ) async {
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
      if (diary == null) continue;
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
  int overlap(List<Diary> keyword, List<SemanticHit> hits) {
    final ids = {for (final d in keyword) d.id};
    var n = 0;
    for (final h in hits) {
      if (ids.contains(h.diaryId)) n++;
    }
    return n;
  }

  /// One page of visible diaries. A time window is read in full and paged here
  /// because the repository only pages by category.
  Future<List<Diary>> page({
    String? categoryId,
    DateTime? start,
    DateTime? end,
    DiarySort sort = DiarySort.timeDesc,
    int offset = 0,
    int limit = 20,
  }) async {
    if (start == null && end == null) {
      return diaries.getDiaryByCategory(
        categoryId: categoryId,
        offset: offset,
        limit: limit,
        sort: sort,
      );
    }
    final all = await diaries.getDiariesByDateRange(
      start ?? DateTime.utc(1970),
      end ?? DateTime.utc(9000),
    );
    final filtered = [
      for (final diary in all)
        if (categoryId == null || diary.categoryId == categoryId) diary,
    ]..sort(diarySortComparator(sort));
    return filtered.skip(offset).take(limit).toList();
  }

  /// Batch read by business id; hidden diaries count as missing.
  Future<({List<Diary> found, List<String> missing})> read(
    List<String> ids, {
    int max = maxBatchRead,
  }) async {
    final found = <Diary>[];
    final missing = <String>[];
    for (final id in ids.take(max)) {
      final diary = await diaries.getDiaryByBusinessId(id);
      if (diary == null || !diary.show) {
        missing.add(id);
        continue;
      }
      found.add(diary);
    }
    return (found: found, missing: missing);
  }

  /// Tag usage over visible diaries, most used first. The database has no tag
  /// index, so this aggregates over every visible diary.
  Future<
    ({
      List<({String tag, int diaries})> tags,
      int totalDistinct,
      int scannedDiaries,
    })
  >
  tags({required int limit}) async {
    final all = await diaries.getAllDiaries();
    final counts = <String, int>{};
    var visible = 0;
    for (final diary in all) {
      if (!diary.show) continue;
      visible++;
      for (final tag in diary.tags) {
        counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return (
      tags: [
        for (final entry in sorted.take(limit))
          (tag: entry.key, diaries: entry.value),
      ],
      totalDistinct: counts.length,
      scannedDiaries: visible,
    );
  }

  /// Forward and backlink summaries of [diary].
  ///
  /// `dangling` lists the diary ids the body mentions but the table does not
  /// hold, in sorted order: a `moodiary://diary/<id>` link to a permanently
  /// deleted or never synced diary used to fail silently. `forward` and
  /// `backlinks` keep the repository's native query semantics, which exclude a
  /// self link from `forward` (a native bug tracked separately).
  Future<Map<String, dynamic>> linkSummary(Diary diary) async {
    final forward = await diaries.getForwardLinks(diary.id);
    final backlinks = await diaries.getBacklinks(diary.id);
    Map<String, dynamic> entry(Diary linked) => {
      'id': linked.id,
      'title': linked.title,
      'time': isoUtc(linked.time),
      'timeLocal': isoLocal(linked.time),
    };
    final referenced = DiaryContent.of(diary).links.toList()..sort();
    final dangling = <String>[];
    for (final id in referenced) {
      if (dangling.length >= _danglingLimit) break;
      if (await diaries.getDiaryByBusinessId(id) == null) dangling.add(id);
    }
    return {
      'forward': [for (final linked in forward) entry(linked)],
      'backlinks': [for (final linked in backlinks) entry(linked)],
      'dangling': dangling,
    };
  }
}

/// Upper bound on `dangling`, so one document cannot flood a result with ids.
const int _danglingLimit = 100;

SearchSort _toSearchSort(String? name) => switch (name) {
  'newest' => SearchSort.timeDesc,
  'oldest' => SearchSort.timeAsc,
  _ => SearchSort.relevance,
};

DiarySort _toDiarySort(String? name) => switch (name) {
  'oldest' => DiarySort.timeAsc,
  'modified' => DiarySort.lastModifiedDesc,
  _ => DiarySort.timeDesc,
};

int Function(Diary, Diary) _diaryComparator(String? name) => switch (name) {
  'oldest' => (a, b) => a.time.compareTo(b.time),
  'modified' => (a, b) => b.lastModified.compareTo(a.lastModified),
  _ => (a, b) => b.time.compareTo(a.time),
};

bool _inRange(DateTime time, DateTime? start, DateTime? endExclusive) {
  if (start != null && time.isBefore(start)) return false;
  if (endExclusive != null && !time.isBefore(endExclusive)) return false;
  return true;
}
