import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_controller.g.dart';

@riverpod
class DashboardController extends _$DashboardController {
  bool _stale = false;

  @override
  Future<DashboardStats> build() async {
    final diarySub = getIt<DiaryRepository>().diaryEvents.listen(_markStale);
    final catSub = getIt<CategoryRepository>().categoryEvents.listen(
      _markStale,
    );
    ref.onDispose(diarySub.cancel);
    ref.onDispose(catSub.cancel);

    _stale = false;
    return _compute();
  }

  void _markStale(void _) => _stale = true;

  Future<void> refreshIfStale() async {
    if (!_stale) return;
    _stale = false;
    final stats = await _compute();
    if (!ref.mounted) return;
    state = AsyncData(stats);
  }

  Future<DashboardStats> _compute() async {
    final diaries = await getIt<DiaryRepository>().getAllDiaries();
    final cats = await getIt<CategoryRepository>().getAllCategories();

    final visible = diaries.where((d) => d.show).toList(growable: false);
    final byDay = _aggregateByDay(visible);

    return DashboardStats(
      useDays: _useDays(),
      diaryCount: visible.length,
      wordCount: _wordCount(visible),
      categoryCount: cats.length,
      streakDays: _streakDays(byDay.keys),
      thisMonthCount: _thisMonthCount(visible),
      tagCount: _tagCount(visible),
      byDay: byDay,
      lastYearCount: _lastYearCount(byDay),
    );
  }

  int _useDays() {
    final ms = MoodiaryKVs.startTime.get();
    if (ms == null || ms == 0) return 1;
    final first = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(first).inDays;
    return diff < 0 ? 1 : diff + 1;
  }

  int _wordCount(List<Diary> diaries) {
    var sum = 0;
    for (final d in diaries) {
      sum += d.contentText.length;
    }
    return sum;
  }

  Map<DateTime, DayWriting> _aggregateByDay(List<Diary> diaries) {
    final grouped = <DateTime, List<Diary>>{};
    for (final d in diaries) {
      final t = d.time.toLocal();
      final day = DateTime(t.year, t.month, t.day);
      (grouped[day] ??= []).add(d);
    }
    if (grouped.isEmpty) return const {};

    final words = {
      for (final e in grouped.entries)
        e.key: e.value.fold<int>(0, (a, d) => a + d.contentText.length),
    };
    final levelOf = heatmapLevelResolver(words.values);

    return {
      for (final e in grouped.entries)
        e.key: _dayOf(e.value, words[e.key]!, levelOf),
    };
  }

  DayWriting _dayOf(
    List<Diary> sameDay,
    int words,
    int Function(int, int) levelOf,
  ) {
    sameDay.sort((a, b) => a.time.compareTo(b.time));
    final first = sameDay.first;
    final image = first.imageName.firstOrNull;
    final video = image == null ? first.videoName.firstOrNull : null;
    return DayWriting(
      count: sameDay.length,
      words: words,
      level: levelOf(sameDay.length, words),
      ids: [for (final d in sameDay) d.id],
      coverName: image ?? video,
      coverIsVideo: image == null && video != null,
      categoryId: first.categoryId,
      title: first.title,
    );
  }

  int _streakDays(Iterable<DateTime> days) {
    if (days.isEmpty) return 0;
    final set = days.toSet();
    var streak = 0;
    var cursor = _today();
    if (!set.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (set.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _thisMonthCount(List<Diary> diaries) {
    final now = DateTime.now();
    var count = 0;
    for (final d in diaries) {
      final t = d.time.toLocal();
      if (t.year == now.year && t.month == now.month) count++;
    }
    return count;
  }

  int _lastYearCount(Map<DateTime, DayWriting> byDay) {
    final from = _today().subtract(const Duration(days: 364));
    var sum = 0;
    byDay.forEach((day, w) {
      if (!day.isBefore(from)) sum += w.count;
    });
    return sum;
  }

  int _tagCount(List<Diary> diaries) {
    final unique = <String>{};
    for (final d in diaries) {
      unique.addAll(d.tags);
    }
    return unique.length;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

int Function(int count, int words) heatmapLevelResolver(
  Iterable<int> dailyWords,
) {
  int byCount(int count, int _) => switch (count) {
    <= 1 => 2,
    2 => 3,
    _ => 4,
  };

  final sorted = dailyWords.toList()..sort();
  if (sorted.length < 8) return byCount;

  int at(double q) => sorted[((sorted.length - 1) * q).round()];
  final p25 = at(0.25), p50 = at(0.5), p75 = at(0.75);
  if (p75 <= p25) return byCount;

  return (_, w) => switch (w) {
    _ when w < p25 => 1,
    _ when w < p50 => 2,
    _ when w < p75 => 3,
    _ => 4,
  };
}

class DayWriting {
  final int count;
  final int words;

  final int level;

  final List<String> ids;

  final String? coverName;

  final bool coverIsVideo;

  final String? categoryId;
  final String title;

  const DayWriting({
    required this.count,
    required this.words,
    required this.level,
    required this.ids,
    required this.coverName,
    required this.coverIsVideo,
    required this.categoryId,
    required this.title,
  });
}

class DashboardStats {
  final int useDays;
  final int diaryCount;
  final int wordCount;
  final int categoryCount;
  final int streakDays;
  final int thisMonthCount;
  final int tagCount;

  final Map<DateTime, DayWriting> byDay;

  final int lastYearCount;

  const DashboardStats({
    required this.useDays,
    required this.diaryCount,
    required this.wordCount,
    required this.categoryCount,
    required this.streakDays,
    required this.thisMonthCount,
    required this.tagCount,
    required this.byDay,
    required this.lastYearCount,
  });
}
