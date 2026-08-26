import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_controller.g.dart';

@riverpod
class DashboardController extends _$DashboardController {
  /// 有日记变更但还没重算。见 [refreshIfStale]。
  bool _stale = false;

  @override
  Future<DashboardStats> build() async {
    // 事件**只置脏、不重算**：本控制器服务的「我的」页是底栏的一格，会长期留在
    // IndexedStack 里。而这里是全表拉 + 内存聚合，isar_plus 的读查询又不走索引全靠
    // 扫描 —— 跟着每次写入重算等于每写一篇日记扫一次库。
    final diarySub = ref
        .read(diaryRepositoryProvider)
        .diaryEvents
        .listen(_markStale);
    final catSub = ref
        .read(categoryRepositoryProvider)
        .categoryEvents
        .listen(_markStale);
    ref.onDispose(diarySub.cancel);
    ref.onDispose(catSub.cancel);

    _stale = false;
    return _compute();
  }

  void _markStale(void _) => _stale = true;

  /// 页面重新可见时调一次；没有脏数据就是空操作。由根壳在切到「我的」tab 时触发 ——
  /// IndexedStack 不提供可见性回调，只能由持有 tab 状态的那层来说。
  Future<void> refreshIfStale() async {
    if (!_stale) return;
    _stale = false;
    state = AsyncData(await _compute());
  }

  Future<DashboardStats> _compute() async {
    final diaries = await ref.read(diaryRepositoryProvider).getAllDiaries();
    final cats =
        (await ref
                .read(categoryRepositoryProvider)
                .getAllCategoriesForSync()
                .run())
            .getOrElse((_) => const <Category>[]);

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

  /// 日粒度聚合 + 分级。key 归一到**本地**当天零点：模型里的 time 是绝对时刻（UTC），
  /// 分桶前必须 toLocal，否则东八区凌晨写的日记会掉到前一天。
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
    // 封面优先图片、其次视频（视频取封面缩略图）—— 与信息流那边一致。
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

  /// 连续打卡：从当前自然日向前，每天至少一篇即计 1，遇到空日停止。
  int _streakDays(Iterable<DateTime> days) {
    if (days.isEmpty) return 0;
    final set = days.toSet();
    var streak = 0;
    var cursor = _today();
    // 今天还没写则从昨天起算，避免清晨打开计数为 0。
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

/// 热力图色阶的分级器：给出「某天写了 count 篇、共 words 字」时该落第几级（1–4）。
///
/// 依据是**当天字数在用户自己分布里的分位数**，不是篇数 —— 日记的绝大多数日子非 0 即 1，
/// 按篇数分级会让五级退化成二值，热力图就成了打卡表。分位数是相对自己的，写短句的人和
/// 写长文的人都能看到梯度。
///
/// 两种情况退回按篇数：**有效日太少**（分位数没有意义，新用户点亮的第一格也该有中等
/// 深度，比一格浅灰更像「记了一笔」），或**字数没有分布**（p25 == p75，比如每天都写
/// 同样长度的一句话 —— 此时按字数分会把所有格子压成同一级）。
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

/// 某一天写了什么。只有写过的日子才有条目 —— 没写的日子不进表，热力图与日历查不到
/// 即为空格。
///
/// 后四个字段是**日历格子要画的东西**，取自当天第一篇。放在这里而不是让日历自己去查，
/// 是因为 isar_plus 的读查询不走二级索引：按月查一次就是全表扫一次，翻页翻不起。
/// 当天的全部日记则靠 [ids] 走主键 get（O(1)）按需取，不必把整条记录都缓在内存里。
class DayWriting {
  final int count;
  final int words;

  /// 热力图色阶，1–4。0 不会出现（它表示「这天不在表里」）。
  final int level;

  /// 当天日记的 id，按时间正序。
  final List<String> ids;

  /// 当天第一篇的封面文件名。没有媒体则为 null。
  final String? coverName;

  /// [coverName] 是视频（要取封面缩略图）还是图片。
  final bool coverIsVideo;

  /// 当天第一篇的分类与标题 —— 没有封面时格子退回「分类色条 + 标题」。
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

  /// 日粒度聚合，key 是**本地**当天零点。没写的日子不在表里。
  final Map<DateTime, DayWriting> byDay;

  /// 近 365 天的篇数合计。热力图标题用它而不是 [diaryCount] —— 标题的数字必须和格子
  /// 对得上，否则读者会去数格子然后发现对不上。
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
