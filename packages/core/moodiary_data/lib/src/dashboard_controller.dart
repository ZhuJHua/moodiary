import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_controller.g.dart';

@riverpod
class DashboardController extends _$DashboardController {
  @override
  Future<DashboardStats> build() async {
    // 日记 / 分类变更即失效重算，保持看板实时（新增/删除日记后数量、字数等随之更新）。
    // 本 provider autoDispose，仅设置页可见时存活，故重算开销可控。
    final diarySub = DiaryRepository.get().diaryEvents.listen(
      (_) => ref.invalidateSelf(),
    );
    final catSub = CategoryRepository.get().categoryEvents.listen(
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(diarySub.cancel);
    ref.onDispose(catSub.cancel);

    final diaries = await DiaryRepository.get().getAllDiaries();
    final cats =
        (await CategoryRepository.get().getAllCategoriesForSync().run())
            .getOrElse((_) => const <Category>[]);

    final visibleDiaries = diaries.where((d) => d.show).toList(growable: false);

    return DashboardStats(
      useDays: _useDays(),
      diaryCount: visibleDiaries.length,
      wordCount: _wordCount(visibleDiaries),
      categoryCount: cats.length,
      streakDays: _streakDays(visibleDiaries),
      thisMonthCount: _thisMonthCount(visibleDiaries),
      averageMood: _averageMood(visibleDiaries),
      tagCount: _tagCount(visibleDiaries),
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

  /// 连续打卡：从当前自然日向前，每天至少一篇即计 1，遇到空日停止。
  int _streakDays(List<Diary> diaries) {
    if (diaries.isEmpty) return 0;
    final dates = <String>{};
    for (final d in diaries) {
      final local = d.time.toLocal();
      dates.add(_ymd(local));
    }
    var streak = 0;
    var cursor = DateTime.now();
    // 今天还没写则从昨天起算，避免清晨打开计数为 0
    if (!dates.contains(_ymd(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (dates.contains(_ymd(cursor))) {
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

  /// 0~100 整数表示百分比，便于 UI 显示「68%」。
  int _averageMood(List<Diary> diaries) {
    if (diaries.isEmpty) return 0;
    var sum = 0.0;
    for (final d in diaries) {
      sum += d.mood;
    }
    final avg = sum / diaries.length;
    return (avg.clamp(0.0, 1.0) * 100).round();
  }

  int _tagCount(List<Diary> diaries) {
    final unique = <String>{};
    for (final d in diaries) {
      unique.addAll(d.tags);
    }
    return unique.length;
  }

  String _ymd(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

class DashboardStats {
  final int useDays;
  final int diaryCount;
  final int wordCount;
  final int categoryCount;
  final int streakDays;
  final int thisMonthCount;

  /// 平均心情，0~100 整数（百分比）。
  final int averageMood;
  final int tagCount;

  const DashboardStats({
    required this.useDays,
    required this.diaryCount,
    required this.wordCount,
    required this.categoryCount,
    required this.streakDays,
    required this.thisMonthCount,
    required this.averageMood,
    required this.tagCount,
  });
}
