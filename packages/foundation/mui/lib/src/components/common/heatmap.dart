import 'package:mui/mui.dart';

const double _kCellSize = 11;

const double _kSlotSize = 14;

const double _kRadius = 2.5;
const double _kMonthLabelHeight = 15;

const double _kMaxTextScale = 1.15;

const List<double> _kLevelStops = [0, 0.30, 0.53, 0.77, 1];

class MHeatmap extends StatefulWidget {
  final DateTime endDate;

  final int weeks;

  final Map<DateTime, int> levels;

  final DateTime? selected;

  final ValueChanged<DateTime>? onDaySelected;

  final String Function(DateTime month) monthLabel;

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

  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  static DateTime _weekStart(DateTime d) => _addDays(d, -(d.weekday % 7));

  @override
  Widget build(BuildContext context) {
    final firstColumn = _weekStart(
      _addDays(widget.endDate, -(widget.weeks - 1) * 7),
    );
    final contentWidth = widget.weeks * _kSlotSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        _controller ??= ScrollController(
          initialScrollOffset: (contentWidth - constraints.maxWidth).clamp(
            0.0,
            double.infinity,
          ),
        );
        return Semantics(
          label: widget.semanticsLabel,
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
      behavior: .opaque,
      onTap: () => callback(day),
      child: SizedBox.square(dimension: _kSlotSize, child: box),
    );
  }
}

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
