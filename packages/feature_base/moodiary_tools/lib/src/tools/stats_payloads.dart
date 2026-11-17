import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import '../ops/diary_display.dart';
import 'diary_payloads.dart';
import 'tool_values.dart';

class DiaryStatsPayloads {
  DiaryStatsPayloads({
    required this.diaries,
    required this.categories,
    required this.insights,
  });

  final DiaryRepository diaries;
  final CategoryRepository categories;
  final MoodInsightsRepository insights;

  /// Local-month buckets plus `olderDiaries` and `futureDiaries` always sum
  /// to `visibleDiaries`.
  Future<Map<String, dynamic>> statsPayload({int? months}) async {
    final total = await diaries.countAllDiaries();
    final byCategory = await diaries.diaryCountByCategory();
    final names = await categoryNames(categories);
    final monthly = await diaries.diaryCountByMonth(sort: DiarySort.timeDesc);

    final requestedMonths = months ?? statsMonths.fallback;
    final windowMonths = requestedMonths < statsMonths.min
        ? statsMonths.min
        : requestedMonths;
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

    // Include future dates so mood counts reconcile with visibleDiaries.
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
      'recycleBinDiaries': total - byCategory.total,
      'uncategorizedDiaries': byCategory.total - categorised,
      'firstDiaryTime': entries.isEmpty
          ? null
          : isoUtc(
              entries
                  .map((entry) => entry.time)
                  .reduce((first, next) => first.isBefore(next) ? first : next),
            ),
      'lastDiaryTime': entries.isEmpty
          ? null
          : isoUtc(
              entries
                  .map((entry) => entry.time)
                  .reduce((first, next) => first.isAfter(next) ? first : next),
            ),
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
