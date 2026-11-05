import 'dart:async';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'word_cloud_settings.dart';

part 'word_cloud_controller.g.dart';

/// 区间预设：默认按周 / 月 / 年，也可以自己指定。
enum WordCloudRangePreset { week, month, year, custom }

/// 时间轴参数：**时间范围** + **每张看多久**。
///
/// 「每张看多久」由用户按**周 / 月 / 季度 / 年**选（[unit]，对应说明书里的 W），
/// 没选过就按区间推荐（周/月预设推荐周，年预设推荐月，自定义按跨度）。
/// 「多久换一张」（Δ）固定在 W 上 —— 每张不重叠；播放快慢在控制条上调。
/// A（对齐）/ P（累积锚点）仍然隐含，理由记在 `docs/word-cloud-analysis.md`。
///
/// 要实现 `==` / `hashCode`：riverpod 用它做 family 缓存键。
class WordCloudTimeline {
  final WordCloudRangePreset preset;

  /// 自定义区间的起止（本地时间，都是闭区间的那一天）。仅 [custom] 用。
  final DateTime? customStart;
  final DateTime? customEnd;

  /// 每张覆盖的单位（= W）。null 表示用区间推荐的默认值。
  final WordCloudUnit? unit;

  const WordCloudTimeline({
    required this.preset,
    this.customStart,
    this.customEnd,
    this.unit,
  });

  const WordCloudTimeline.preset(this.preset, {this.unit})
    : customStart = null,
      customEnd = null;

  static WordCloudTimeline custom(
    DateTime start,
    DateTime end, {
    WordCloudUnit? unit,
  }) => WordCloudTimeline(
    preset: WordCloudRangePreset.custom,
    customStart: DateTime(start.year, start.month, start.day),
    customEnd: DateTime(end.year, end.month, end.day),
    unit: unit,
  );

  /// 区间起点（含）。用日历运算而不是 Duration，免得夏令时把零点挪走。
  DateTime startAt(DateTime now) => switch (preset) {
    WordCloudRangePreset.week => DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    ),
    WordCloudRangePreset.month => DateTime(now.year, now.month),
    WordCloudRangePreset.year => DateTime(now.year),
    WordCloudRangePreset.custom => _resolved(now).$1,
  };

  /// 区间终点（不含）—— 半开区间，避免和下一个区间重叠。
  DateTime endExclusiveAt(DateTime now) => switch (preset) {
    WordCloudRangePreset.week => DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1) + 7,
    ),
    WordCloudRangePreset.month => DateTime(now.year, now.month + 1),
    WordCloudRangePreset.year => DateTime(now.year + 1),
    WordCloudRangePreset.custom => _resolved(now).$2,
  };

  /// 每张覆盖的单位（= W）：用户选过就用它，否则按区间推荐。
  WordCloudUnit unitAt(DateTime now) =>
      unit ??
      switch (preset) {
        // 一周就是一张；一个月按周看（4~5 张）刚好能播
        WordCloudRangePreset.week => .week,
        WordCloudRangePreset.month => .week,
        WordCloudRangePreset.year => .month,
        WordCloudRangePreset.custom => WordCloudUnit.forSpan(
          endExclusiveAt(now).difference(startAt(now)),
        ),
      };

  WordCloudWindowPlan planAt(DateTime now) => WordCloudWindowPlan.build(
    unit: unitAt(now),
    length: 1,
    step: 1,
    t0: startAt(now),
    t1: endExclusiveAt(now),
  );

  /// 换区间：保留用户选过的「每张看多久」——那是他的偏好，不该被悄悄改掉。
  WordCloudTimeline withRange({
    required WordCloudRangePreset preset,
    DateTime? customStart,
    DateTime? customEnd,
  }) => WordCloudTimeline(
    preset: preset,
    customStart: customStart,
    customEnd: customEnd,
    unit: unit,
  );

  /// 换「每张看多久」。
  WordCloudTimeline withUnit(WordCloudUnit next) => WordCloudTimeline(
    preset: preset,
    customStart: customStart,
    customEnd: customEnd,
    unit: next,
  );

  /// 自定义区间缺失或颠倒时退回本年（按当前时间算），页面永远有图可画。
  (DateTime, DateTime) _resolved(DateTime now) {
    final start = customStart;
    final end = customEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return (DateTime(now.year), DateTime(now.year + 1));
    }
    return (start, DateTime(end.year, end.month, end.day + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is WordCloudTimeline &&
      other.preset == preset &&
      other.customStart == customStart &&
      other.customEnd == customEnd &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(preset, customStart, customEnd, unit);

  @override
  String toString() =>
      'WordCloudTimeline($preset, $customStart, $customEnd, unit: $unit)';
}

/// 时间范围选择器要用的轻量索引：最早/最晚一篇 + 每月篇数。
/// 只看 `time` 一列，不碰正文。
@riverpod
Future<({DateTime? first, DateTime? last, Map<DateTime, int> byMonth})>
wordCloudTimeIndex(Ref ref) async {
  final repository = getIt<DiaryRepository>();
  Timer? debounce;
  final sub = repository.diaryEvents.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
  final span = await repository.diaryTimeSpan();
  final byMonth = await repository.diaryCountByMonth();
  return (first: span.first, last: span.last, byMonth: byMonth);
}

/// 区间内所有日记的词云。屏蔽词/词典/单字开关一变就重算；
/// 日记一变（400ms 防抖）就重算。
@riverpod
Future<WordCloudData> wordCloudData(
  Ref ref, {
  required WordCloudTimeline timeline,
}) async {
  final blocked = ref.watch(wordCloudBlockedProvider).toSet();
  final keep = ref.watch(wordCloudLexiconListProvider).toSet();
  final hideSingleChars = ref.watch(wordCloudHideSingleCharsProvider);
  final repository = getIt<WordCloudRepository>();

  Timer? debounce;
  final sub = getIt<DiaryRepository>().diaryEvents.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });

  final now = DateTime.now();
  final plan = timeline.planAt(now);
  if (!plan.isValid) {
    return WordCloudData.empty(
      unit: plan.unit,
      start: plan.t0,
      endExclusive: plan.t1,
    );
  }
  return repository.build(
    plan: plan,
    blocked: blocked,
    lexicon: WordCloudLexicon(keep),
    hideSingleChars: hideSingleChars,
  );
}
