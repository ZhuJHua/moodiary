import 'package:mui/mui.dart';

/// 方块热力图（GitHub 贡献图那种）的固定版式。改这里就等于改版式，别在调用方另写字面量。
const double _kCellSize = 11;

/// 点击区。格子只有 11dp，中间那 3dp 间隙也算进点击区才勉强够按 —— 视觉间距不变，
/// 但相邻两格的可点区域是连续的。
const double _kSlotSize = 14;

const double _kRadius = 2.5;
const double _kMonthLabelHeight = 15;

/// 列标签跟着系统字号涨会把行高撑开、月份和列对不齐。热力图是图表不是正文，封顶。
const double _kMaxTextScale = 1.15;

/// 五级色阶在 `surfaceContainerHighest → primary` 之间取点。
///
/// **不要改成「primary 按透明度叠在卡片上」**：那样在灰度档很好看（那档的 primary 是
/// 纯黑，跨度拉满），但换成有彩强调色就塌 —— 有彩档的 primary 是 tone-40，
/// 24% 叠在浅色卡片上和空格子只差 20/255，L0 与 L1 分不出来。
const List<double> _kLevelStops = [0, 0.30, 0.53, 0.77, 1];

/// 一年的方块热力图。**只画网格**，标题、图例、选中详情由调用方组合 —— 那些都要文案，
/// 而 mui 是零 `moodiary_*` 依赖的叶子包。
class MHeatmap extends StatefulWidget {
  /// 最后一列里的那天，通常是今天。必须是**本地**当天零点。
  final DateTime endDate;

  /// 列数（周）。53 列 ≈ 一年。
  final int weeks;

  /// 日粒度色阶，key 是本地当天零点，value 取 1–4。表里没有的日子 = 空格。
  final Map<DateTime, int> levels;

  final DateTime? selected;

  /// 给 null 则格子不可点。
  final ValueChanged<DateTime>? onDaySelected;

  /// 列标签文案。locale 数据由调用方给。
  final String Function(DateTime month) monthLabel;

  /// 整块网格对读屏播报的一句话。见下面 [ExcludeSemantics] 处的说明。
  final String semanticsLabel;

  const MHeatmap({
    super.key,
    required this.endDate,
    required this.levels,
    required this.monthLabel,
    required this.semanticsLabel,
    this.weeks = 53,
    this.selected,
    this.onDaySelected,
  });

  /// 某一级对应的颜色。图例要和网格用同一个来源，所以公开。
  static Color levelColor(BuildContext context, int level) {
    final colors = context.theme.colors;
    final t = _kLevelStops[level.clamp(0, _kLevelStops.length - 1)];
    return Color.lerp(colors.surfaceContainerHighest, colors.primary, t)!;
  }

  @override
  State<MHeatmap> createState() => _MHeatmapState();
}

class _MHeatmapState extends State<MHeatmap> {
  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 本地日期加减。**不能用 `Duration(days: n)`** —— 跨夏令时会算出前一天的 23:00，
  /// 而这里的 key 全是当天零点，差一秒就查不到。
  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  /// 该周的周日。`DateTime.weekday` 是周一 1 到周日 7，`% 7` 正好把周日折成 0。
  static DateTime _weekStart(DateTime d) => _addDays(d, -(d.weekday % 7));

  @override
  Widget build(BuildContext context) {
    final firstColumn = _weekStart(
      _addDays(widget.endDate, -(widget.weeks - 1) * 7),
    );
    final contentWidth = widget.weeks * _kSlotSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 初始位置贴最右（今天）。**别用 post-frame 的 jumpTo** —— 那会先渲染一帧
        // 最左边（一年前，多半是空的），下一帧才跳过来，冷启动时肉眼可见地闪一下。
        // 这里内容宽度是算得出来的，直接给准确的初始 offset。
        _controller ??= ScrollController(
          initialScrollOffset: (contentWidth - constraints.maxWidth).clamp(
            0.0,
            double.infinity,
          ),
        );
        return Semantics(
          label: widget.semanticsLabel,
          // 371 个格子逐个上语义节点会让语义树膨胀十倍，而读屏挨个念格子也没有意义；
          // 选中某天的信息由调用方那行详情承担。
          child: ExcludeSemantics(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: .horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    _MonthLabels(
                      firstColumn: firstColumn,
                      weeks: widget.weeks,
                      label: widget.monthLabel,
                    ),
                    Row(
                      children: [
                        for (var w = 0; w < widget.weeks; w++)
                          _Column(
                            weekStart: _addDays(firstColumn, w * 7),
                            endDate: widget.endDate,
                            levels: widget.levels,
                            selected: widget.selected,
                            onDaySelected: widget.onDaySelected,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthLabels extends StatelessWidget {
  final DateTime firstColumn;
  final int weeks;
  final String Function(DateTime month) label;

  const _MonthLabels({
    required this.firstColumn,
    required this.weeks,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    final marks = <(double, String)>[];
    var lastMonth = -1;
    for (var w = 0; w < weeks; w++) {
      final start = DateTime(
        firstColumn.year,
        firstColumn.month,
        firstColumn.day + w * 7,
      );
      if (start.month == lastMonth) continue;
      lastMonth = start.month;
      // 最后两列的标签会被右边界截断，且此时新月份才刚开头，标了也没有对照价值。
      if (w > weeks - 3) continue;
      marks.add((w * _kSlotSize, label(start)));
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _kMaxTextScale,
      child: SizedBox(
        height: _kMonthLabelHeight,
        child: Stack(
          clipBehavior: .none,
          children: [
            for (final (x, text) in marks)
              Positioned(
                left: x,
                top: 0,
                child: Text(text, style: style, maxLines: 1),
              ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final DateTime weekStart;
  final DateTime endDate;
  final Map<DateTime, int> levels;
  final DateTime? selected;
  final ValueChanged<DateTime>? onDaySelected;

  const _Column({
    required this.weekStart,
    required this.endDate,
    required this.levels,
    required this.selected,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        for (var i = 0; i < 7; i++)
          () {
            final day = DateTime(
              weekStart.year,
              weekStart.month,
              weekStart.day + i,
            );
            // 末列里今天之后的那几格：留空占位，让网格保持矩形而不是缺一角。
            if (day.isAfter(endDate)) {
              return const SizedBox.square(dimension: _kSlotSize);
            }
            return _Cell(
              day: day,
              level: levels[day] ?? 0,
              isToday: day == endDate,
              isSelected: day == selected,
              onTap: onDaySelected,
            );
          }(),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final DateTime day;
  final int level;
  final bool isToday;
  final bool isSelected;
  final ValueChanged<DateTime>? onTap;

  const _Cell({
    required this.day,
    required this.level,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final border = isSelected
        ? Border.all(color: colors.onSurface, width: 1.6)
        : isToday
        ? Border.all(color: colors.outline, width: 1.2)
        : null;

    final box = Center(
      child: Container(
        width: _kCellSize,
        height: _kCellSize,
        decoration: BoxDecoration(
          color: MHeatmap.levelColor(context, level),
          borderRadius: const .all(.circular(_kRadius)),
          border: border,
        ),
      ),
    );

    final callback = onTap;
    if (callback == null) {
      return SizedBox.square(dimension: _kSlotSize, child: box);
    }
    return GestureDetector(
      // opaque：连格子之间那 3dp 间隙也吃掉，相邻格的点击区因此是连续的。
      behavior: .opaque,
      onTap: () => callback(day),
      child: SizedBox.square(dimension: _kSlotSize, child: box),
    );
  }
}

/// 「少 ▢▢▢▢▢ 多」。色阶来自 [MHeatmap.levelColor]，和网格同一个来源。
class MHeatmapLegend extends StatelessWidget {
  final String lessLabel;
  final String moreLabel;

  const MHeatmapLegend({
    super.key,
    required this.lessLabel,
    required this.moreLabel,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    return Row(
      mainAxisSize: .min,
      children: [
        Text(lessLabel, style: style),
        for (var i = 0; i < _kLevelStops.length; i++)
          Padding(
            padding: const .symmetric(horizontal: 2),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: MHeatmap.levelColor(context, i),
                borderRadius: const .all(.circular(2)),
              ),
            ),
          ),
        Text(moreLabel, style: style),
      ],
    );
  }
}
