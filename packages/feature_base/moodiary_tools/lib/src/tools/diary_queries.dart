import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_payloads.dart';

class DiaryToolQueries {
  DiaryToolQueries({required this.diaries});

  final DiaryRepository diaries;

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

  /// Link summaries include sorted `dangling` ids missing from the database.
  /// Self-links appear only in backlinks, matching the repository index.
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
