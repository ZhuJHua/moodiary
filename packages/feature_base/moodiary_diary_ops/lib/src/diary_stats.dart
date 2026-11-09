/// Aggregates over the diary table.
///
/// Two shapes are served: the compact overview the in-app assistant renders as
/// text, and the JSON payload the MCP tools and resources hand to a client.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_display.dart';

/// The numbers the assistant's `diaryOverview` tool prints.
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
    this.insights,
  });

  final DiaryRepository diaries;
  final CategoryRepository categories;

  /// Only the MCP payload needs the mood read model; the assistant overview
  /// reads the diary table alone.
  final MoodInsightsRepository? insights;

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

    final allCategories = await categories.getAllCategories();
    final nameById = {
      for (final category in allCategories) category.id: category.categoryName,
    };
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

    // The assistant prints every level including the unrecorded one, so the
    // distribution is counted from the visible rows themselves.
    final rows = await diaries.getDiaryByCategory(
      sort: DiarySort.timeDesc,
      limit: 9999,
    );
    final moods = <DiaryMood?, int>{};
    for (final diary in rows) {
      moods[diary.mood] = (moods[diary.mood] ?? 0) + 1;
    }

    return (
      total: counts.total,
      oldest: oldest.isEmpty ? null : oldest.first.time,
      newest: newest.isEmpty ? null : newest.first.time,
      categories: categoryRows,
      uncategorized: counts.total - categorized,
      moods: moods,
    );
  }

  /// The `get_stats` payload, also served as `moodiary://stats/overview`.
  ///
  /// The month buckets cover the local calendar months of the requested
  /// window, and `olderDiaries` / `futureDiaries` account for the visible rows
  /// outside it, so `sum(months) + olderDiaries + futureDiaries` always equals
  /// `visibleDiaries` — including future-dated entries and entries older than
  /// the window, which used to disappear from the sum without a trace.
  Future<Map<String, dynamic>> statsPayload({int months = 12}) async {
    final total = await diaries.countAllDiaries();
    final byCategory = await diaries.diaryCountByCategory();
    final categoryList = await categories.getAllCategories();
    final names = {
      for (final category in categoryList) category.id: category.categoryName,
    };
    final monthly = await diaries.diaryCountByMonth(sort: DiarySort.timeDesc);
    final earliest = await insights!.earliestEntry();

    // A non-positive window would make the invariant meaningless, so one month
    // is the floor; the tool layer already clamps its own range.
    final windowMonths = months < 1 ? 1 : months;
    final now = DateTime.now();
    final windowStart = DateTime(now.year, now.month - (windowMonths - 1));
    final windowEnd = DateTime(now.year, now.month);
    final monthRows = <Map<String, dynamic>>[];
    for (var back = windowMonths - 1; back >= 0; back--) {
      final key = DateTime(now.year, now.month - back);
      monthRows.add({'month': _monthKey(key), 'diaries': monthly[key] ?? 0});
    }
    var olderDiaries = 0;
    var futureDiaries = 0;
    for (final entry in monthly.entries) {
      if (entry.key.isBefore(windowStart)) {
        olderDiaries += entry.value;
      } else if (entry.key.isAfter(windowEnd)) {
        futureDiaries += entry.value;
      }
    }

    final entries = await visibleEntries();
    final mood = summarizeMood(entries);
    final recorded = mood.distribution.values.fold(0, (sum, n) => sum + n);
    final categorised = byCategory.byCategory.values.fold(
      0,
      (sum, n) => sum + n,
    );

    final categoryRows = <Map<String, dynamic>>[
      for (final entry in byCategory.byCategory.entries)
        {
          'categoryId': entry.key,
          'categoryName': names[entry.key],
          'diaries': entry.value,
        },
    ]..sort((a, b) => (b['diaries']! as int).compareTo(a['diaries']! as int));

    return {
      'totalDiaries': total,
      'visibleDiaries': byCategory.total,
      // The recycle bin is exactly the hidden rows, so no second query is needed.
      'recycleBinDiaries': total - byCategory.total,
      'uncategorizedDiaries': byCategory.total - categorised,
      'firstDiaryTime': earliest == null ? null : isoUtc(earliest),
      'months': monthRows,
      'monthsWindow': {
        'from': _monthKey(windowStart),
        'to': _monthKey(windowEnd),
      },
      'olderDiaries': olderDiaries,
      'futureDiaries': futureDiaries,
      'categories': categoryRows,
      'moods': {
        'distribution': {
          for (final level in DiaryMood.values)
            level.name: mood.distribution[level] ?? 0,
        },
        'recordedDiaries': recorded,
        'diariesWithoutMood': byCategory.total - recorded,
        'averageScore': mood.average,
        'recordedDays': mood.recordedDays,
      },
      'generatedAt': isoUtc(DateTime.now()),
    };
  }

  /// Every visible diary as the light projection the mood insights read model
  /// uses. Prompt completions need days and titles without loading diary bodies.
  Future<List<MoodInsightEntry>> visibleEntries() =>
      visibleDiaryEntries(insights!);

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
}

/// Every visible diary as the light projection the mood insights read model
/// uses. Prompt completions need days and titles without loading diary bodies.
Future<List<MoodInsightEntry>> visibleDiaryEntries(
  MoodInsightsRepository insights,
) async {
  final earliest = await insights.earliestEntry();
  if (earliest == null) return const [];
  return insights.entries(
    earliest,
    DateTime.now().add(const Duration(days: 1)),
  );
}
