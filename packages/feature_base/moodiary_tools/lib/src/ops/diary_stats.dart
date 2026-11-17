/// Diary aggregates for assistant summaries.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_display.dart';

/// The numbers the assistant's `get_stats` tool prints.
typedef AssistantOverview = ({
  int total,
  DateTime? oldest,
  DateTime? newest,
  List<({String id, String name, int count})> categories,
  int uncategorized,
  Map<DiaryMood?, int> moods,
});

class DiaryStatsOps {
  DiaryStatsOps({
    required this.diaries,
    required this.categories,
    required this.insights,
  });

  final DiaryRepository diaries;
  final CategoryRepository categories;

  final MoodInsightsRepository insights;

  /// Visible count, span, per-category counts and the mood distribution.
  Future<AssistantOverview> overviewForModel() async {
    final counts = await diaries.diaryCountByCategory();
    if (counts.total == 0) {
      return (
        total: 0,
        oldest: null,
        newest: null,
        categories: const <({String id, String name, int count})>[],
        uncategorized: 0,
        moods: const <DiaryMood?, int>{},
      );
    }

    final nameById = await categoryNames(categories);
    final newest = await diaries.getDiaryByCategory(
      sort: DiarySort.timeDesc,
      limit: 1,
    );
    final oldest = await diaries.getDiaryByCategory(
      sort: DiarySort.timeAsc,
      limit: 1,
    );

    final categorized = counts.byCategory.values.fold<int>(0, (a, b) => a + b);
    final entries = counts.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryRows = [
      for (final entry in entries)
        (
          id: entry.key,
          name: nameById[entry.key] ?? '(deleted category)',
          count: entry.value,
        ),
    ];

    final visible = await insights.allVisibleEntries();
    final mood = summarizeMood(visible);
    final recorded = mood.distribution.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final moods = <DiaryMood?, int>{
      for (final entry in mood.distribution.entries)
        if (entry.value > 0) entry.key: entry.value,
      if (visible.length > recorded) null: visible.length - recorded,
    };

    return (
      total: counts.total,
      oldest: oldest.isEmpty ? null : oldest.first.time,
      newest: newest.isEmpty ? null : newest.first.time,
      categories: categoryRows,
      uncategorized: counts.total - categorized,
      moods: moods,
    );
  }
}
