import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_payloads.dart';

class McpStatsPayloads {
  McpStatsPayloads({
    required this.diaries,
    required this.categories,
    required this.insights,
  });

  final DiaryRepository diaries;
  final CategoryRepository categories;
  final MoodInsightsRepository insights;

  /// Local-month buckets plus `olderDiaries` and `futureDiaries` always sum
  /// to `visibleDiaries`.
  Future<Map<String, dynamic>> statsPayload({int months = 12}) async {
    final total = await diaries.countAllDiaries();
    final byCategory = await diaries.diaryCountByCategory();
    final names = await categoryNames(categories);
    final monthly = await diaries.diaryCountByMonth(sort: DiarySort.timeDesc);
    final earliest = await insights.earliestEntry();

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

    // The mood counts describe the same population as the diary totals: every
    // visible row, future-dated ones included, so `recordedDiaries +
    // diariesWithoutMood` always equals `visibleDiaries`.
    final entries = await insights.allVisibleEntries();
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

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
}
