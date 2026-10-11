/// 词云的时间轴模型：单位、窗口（半开区间）与窗口方案。
///
/// 窗口方案把说明书的三个独立变量显式化：
///  * `length`（W）：一个窗口覆盖几个单位；
///  * `step`（Δ）：窗口每次推进几个单位；
///  * `unit`：单位（天/周/月/年）。
/// `W == Δ` 是不重叠阶段（按天/按周/按月）；`W > Δ` 是滑动阶段（相邻窗口重叠）。
library;

/// 时间轴单位。窗口长度与步长都以它计数。
///
/// 词云页只让用户选 [week] / [month] / [quarter] / [year]（见 [wordCloudLengthUnits]）；
/// [day] 留在底层给更细的用法与测试，页面不产生它。
enum WordCloudUnit {
  day,
  week,
  month,
  quarter,
  year;

  /// 按跨度推荐单位（自定义区间用；预设各自有写死的默认值）。
  /// 目的只是让窗口数落在可看的范围里。
  static WordCloudUnit forSpan(Duration span) {
    final days = span.inDays;
    if (days <= 120) return .week; // 一个季度多点 → 周
    if (days <= 730) return .month; // 两年内 → 月
    if (days <= 2920) return .quarter; // 八年内 → 季度
    return .year;
  }

  /// 以 [start] 为第 0 段起点，第 [index] 个单位的起点。
  ///
  /// `index <= 0` 时就是 [start] 本身 —— 第 0 段从区间起点开始算，
  /// 所以区间起点不是自然边界时，第 0 段是不完整的。
  DateTime align(DateTime start, int index) {
    if (index <= 0) return start;
    return switch (this) {
      .day => DateTime(start.year, start.month, start.day + index),
      .week => DateTime(start.year, start.month, start.day + index * 7),
      .month => DateTime(start.year, start.month + index),
      .quarter => DateTime(start.year, start.month + index * 3),
      .year => DateTime(start.year + index),
    };
  }

  /// [time] 所属的**自然**单位起点（用来判断一个窗口边界是否自然对齐）。
  DateTime floor(DateTime time) => switch (this) {
    .day => DateTime(time.year, time.month, time.day),
    .week => DateTime(time.year, time.month, time.day - (time.weekday - 1)),
    .month => DateTime(time.year, time.month),
    .quarter => DateTime(time.year, ((time.month - 1) ~/ 3) * 3 + 1),
    .year => DateTime(time.year),
  };

  /// 第 [index] 段在 [start] 起算时的落段（假定 time >= start）。
  int indexOf(DateTime time, DateTime start) {
    final months = (time.year - start.year) * 12 + time.month - start.month;
    return switch (this) {
      .day => _daysBetween(start, time),
      .week => _daysBetween(start, time) ~/ 7,
      .month => months,
      .quarter => months ~/ 3,
      .year => time.year - start.year,
    };
  }

  /// 用本地日历日算天数差：UTC 零点相减，绕开夏令时导致的 23/25 小时。
  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// 词云页「每张看多久」能选的单位：按周 / 按月 / 按季度 / 按年。
const List<WordCloudUnit> wordCloudLengthUnits = [
  WordCloudUnit.week,
  WordCloudUnit.month,
  WordCloudUnit.quarter,
  WordCloudUnit.year,
];

/// 一个窗口：**半开区间** `[start, endExclusive)`。
///
/// 用半开区间是因为边界上那篇日记只能属于一个窗口；闭区间会让它被
/// 相邻两个窗口各算一次（滑动窗口下更是成倍重复）。
class WordCloudWindow {
  final DateTime start;
  final DateTime endExclusive;

  /// 边界不是自然单位边界（起点不在单位边界上，或被区间首尾截断）。
  final bool partial;

  const WordCloudWindow({
    required this.start,
    required this.endExclusive,
    required this.partial,
  });

  Duration get span => endExclusive.difference(start);

  /// 窗口里最后一天的任一时刻（给"3月1日 – 3月31日"这种标签用）。
  DateTime get lastMoment =>
      endExclusive.subtract(const Duration(microseconds: 1));

  bool contains(DateTime time) =>
      !time.isBefore(start) && time.isBefore(endExclusive);
}

/// 窗口方案的错误。UI 负责翻译成人话。
enum WordCloudPlanError { emptyRange, badStep, badLength, tooManyWindows }

/// 窗口方案：单位 × 长度 W × 步长 Δ，配上区间 [t0, t1)。
class WordCloudWindowPlan {
  final WordCloudUnit unit;

  /// W：一个窗口覆盖几个单位。
  final int length;

  /// Δ：窗口每次推进几个单位。
  final int step;

  final DateTime t0;
  final DateTime t1;

  /// 生成的窗口（按时间升序）。校验不通过时为空。
  final List<WordCloudWindow> windows;

  final WordCloudPlanError? error;

  const WordCloudWindowPlan._({
    required this.unit,
    required this.length,
    required this.step,
    required this.t0,
    required this.t1,
    required this.windows,
    required this.error,
  });

  /// 窗口数上限：10 年 × 日窗口 = 3650 段既算不快也没人看。
  /// 超上限**不自动改用户参数**，而是报错让用户改（谨慎优先）。
  static const int maxWindows = 400;

  bool get isValid => error == null && windows.isNotEmpty;

  int get windowCount => windows.length;

  /// W > Δ：相邻窗口重叠。
  bool get isSliding => length > step;

  /// 相邻窗口的重叠比例（滑动时才有意义）。
  double get overlapRatio => length <= 0 ? 0 : (length - step) / length;

  WordCloudWindow? windowAt(int index) =>
      index >= 0 && index < windows.length ? windows[index] : null;

  static WordCloudWindowPlan build({
    required WordCloudUnit unit,
    required int length,
    required int step,
    required DateTime t0,
    required DateTime t1,
  }) {
    if (!t1.isAfter(t0)) {
      return _invalid(unit, length, step, t0, t1, .emptyRange);
    }
    if (step <= 0) return _invalid(unit, length, step, t0, t1, .badStep);
    if (length <= 0) return _invalid(unit, length, step, t0, t1, .badLength);

    final windows = <WordCloudWindow>[];
    for (var k = 0; ; k++) {
      final start = unit.align(t0, k * step);
      if (!start.isBefore(t1)) break;
      if (windows.length >= maxWindows) {
        return _invalid(unit, length, step, t0, t1, .tooManyWindows);
      }
      var end = unit.align(t0, k * step + length);
      var partial = unit.floor(start) != start;
      if (end.isAfter(t1)) {
        end = t1;
        partial = true;
      } else if (unit.floor(end) != end) {
        partial = true;
      }
      windows.add(
        WordCloudWindow(start: start, endExclusive: end, partial: partial),
      );
    }
    return WordCloudWindowPlan._(
      unit: unit,
      length: length,
      step: step,
      t0: t0,
      t1: t1,
      windows: List<WordCloudWindow>.unmodifiable(windows),
      error: null,
    );
  }

  static WordCloudWindowPlan _invalid(
    WordCloudUnit unit,
    int length,
    int step,
    DateTime t0,
    DateTime t1,
    WordCloudPlanError error,
  ) => WordCloudWindowPlan._(
    unit: unit,
    length: length,
    step: step,
    t0: t0,
    t1: t1,
    windows: const [],
    error: error,
  );

  /// 空方案（区间非法或没有窗口时用）。
  static WordCloudWindowPlan empty({
    required WordCloudUnit unit,
    required int length,
    required int step,
    required DateTime t0,
    required DateTime t1,
  }) => _invalid(unit, length, step, t0, t1, .emptyRange);
}
