/// 词云：一段时间内所有日记的用词统计，按窗口切分。
///
/// 只读派生数据 —— 由仓储现算，不入库、不同步、不进备份。
/// 窗口的切法见 [WordCloudWindowPlan]；这里只放结果。
library;

import 'word_cloud_windows.dart';

class WordCloudTerm {
  final String word;

  /// 整个区间的词频，用于排序与字号映射。
  final int total;

  /// 每个窗口的词频，长度 = [WordCloudData.windowCount]。
  final List<int> counts;

  const WordCloudTerm({
    required this.word,
    required this.total,
    required this.counts,
  });

  int countAt(int index) =>
      index >= 0 && index < counts.length ? counts[index] : 0;

  /// 播放到第 [index] 个窗口为止的累计词频（含该窗口）。
  int cumulativeAt(int index) {
    var sum = 0;
    for (var i = 0; i <= index && i < counts.length; i++) {
      sum += counts[i];
    }
    return sum;
  }
}

class WordCloudData {
  /// 按 [WordCloudTerm.total] 降序、同频按词升序 —— 顺序确定，布局才稳定。
  final List<WordCloudTerm> terms;

  /// 参与统计的窗口（升序）。词频列与它按下标对齐。
  final List<WordCloudWindow> windows;

  final WordCloudUnit unit;

  final DateTime start;

  final DateTime endExclusive;

  /// 区间内参与统计的日记数（已排除回收站）。
  final int diaryCount;

  /// 通过过滤、进入统计的词次总数。
  final int tokenCount;

  /// 第一个 / 最后一个**有词**的窗口下标（含）。
  ///
  /// 空白窗口在仓储里就已经被剔掉了，所以现在恒为 `0..windowCount-1`；
  /// 留着它们是为了让「播放范围」这个概念在模型里显式存在。
  final int activeFirst;
  final int activeLast;

  const WordCloudData({
    required this.terms,
    required this.windows,
    required this.unit,
    required this.start,
    required this.endExclusive,
    required this.diaryCount,
    required this.tokenCount,
    required this.activeFirst,
    required this.activeLast,
  });

  bool get isEmpty => terms.isEmpty;

  int get windowCount => windows.length;

  /// 播放范围内的**张数**（标签上的「第 i/N 张」用这个）。
  ///
  /// 注意与 [segmentCount] 区分：那是**段间隔数**（张数 − 1），只该用来算播放时长。
  int get activeWindowCount => activeLast - activeFirst + 1;

  WordCloudWindow? windowAt(int index) =>
      index >= 0 && index < windows.length ? windows[index] : null;

  /// 播放段数（张数 − 1，即插值间隔数）：至少 1（只有一个窗口时没有可插值的下一段）。
  int get segmentCount =>
      activeLast > activeFirst ? activeLast - activeFirst : 1;

  /// 播放进度（0..1）对应的浮点窗口下标，落在 [activeFirst]..[activeLast]。
  ///
  /// 用真实跨度插值（不是 [segmentCount]）：只有一个窗口时进度两端都落在它上面，
  /// 否则标签会跑到窗口外面去。
  double windowPositionAt(double progress) =>
      activeFirst + progress.clamp(0.0, 1.0) * (activeLast - activeFirst);

  /// 进度落在**哪一张**上（吸附：正好落在两张中间时按方向取整）。
  ///
  /// [forward] 为 true（往前拖或正在播放）时取后一张，否则取前一张。
  int nearestWindowAt(double progress, {bool forward = true}) {
    final position = windowPositionAt(progress);
    final base = position.floorToDouble();
    final fraction = position - base;
    final index = switch (fraction) {
      0 => base.toInt(),
      > 0.5 => base.toInt() + 1,
      0.5 => forward ? base.toInt() + 1 : base.toInt(),
      _ => base.toInt(),
    };
    if (index < activeFirst) return activeFirst;
    if (index > activeLast) return activeLast;
    return index;
  }

  /// 把进度**吸附**到最近的一张，返回吸附后的进度。
  ///
  /// 拖进度条松手、暂停、滑动切段之后都用这个：画面停在一张完整的词云上，
  /// 而不是两张之间的插值。
  double snapToWindow(double progress, {bool forward = true}) {
    final span = activeLast - activeFirst;
    if (span <= 0) return 0;
    return (nearestWindowAt(progress, forward: forward) - activeFirst) / span;
  }

  /// 第 [index] 张对应的（已吸附的）进度。越界会夹回播放范围。
  double progressForWindow(int index) {
    final span = activeLast - activeFirst;
    if (span <= 0) return 0;
    final clamped = index < activeFirst
        ? activeFirst
        : (index > activeLast ? activeLast : index);
    return (clamped - activeFirst) / span;
  }

  /// [time] 落在哪一张里；落在空档（被跳过的空白时段）里就取它前面最近的一张。
  ///
  /// 用来在数据重算后**保持当前时间点**：换了区间/单位之后，仍然显示同一个时间的那一段。
  int windowIndexAt(DateTime time) {
    if (windows.isEmpty) return 0;
    var previous = -1;
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].contains(time)) return i;
      if (!windows[i].start.isAfter(time)) previous = i;
    }
    return previous >= 0 ? previous : 0;
  }

  static WordCloudData empty({
    required WordCloudUnit unit,
    required DateTime start,
    required DateTime endExclusive,
  }) => WordCloudData(
    terms: const [],
    windows: const [],
    unit: unit,
    start: start,
    endExclusive: endExclusive,
    diaryCount: 0,
    tokenCount: 0,
    activeFirst: 0,
    activeLast: 0,
  );
}
