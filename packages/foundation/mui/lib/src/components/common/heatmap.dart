import 'package:mui/mui.dart';

const double _kCellSize = 11;

const _kCellBorderRadius = BorderRadius.all(Radius.circular(2.5));

const double _kSlotSize = 14;

const double _kMonthLabelHeight = 15;

const double _kMaxTextScale = 1.15;

const List<double> _kLevelStops = [0, 0.30, 0.53, 0.77, 1];

enum MHeatmapEmptyCell { filled, dashed }

class MHeatmap extends StatefulWidget {
  final DateTime endDate;

  /// Optional inclusive lower bound; preceding week slots stay blank.
  final DateTime? startDate;

  final int weeks;

  final Map<DateTime, int> levels;

  /// Overrides levels; null uses [emptyCell].
  final Color? Function(DateTime day)? colorOf;

  /// Style of past or present null days in [colorOf] mode; levels are unchanged.
  final MHeatmapEmptyCell emptyCell;

  final ValueChanged<DateTime>? onMonthSelected;

  final DateTime? selected;

  final ValueChanged<DateTime>? onDaySelected;

  final String Function(DateTime month) monthLabel;

  final String semanticsLabel;

  const MHeatmap({
    super.key,
    required this.endDate,
    this.levels = const {},
    required this.monthLabel,
    required this.semanticsLabel,
    this.weeks = 53,
    this.startDate,
    this.colorOf,
    this.emptyCell = .filled,
    this.onMonthSelected,
    this.selected,
    this.onDaySelected,
  });

  static Color emptyColor(BuildContext context) => levelColor(context, 0);

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
                      startDate: widget.startDate,
                      onSelected: widget.onMonthSelected,
                    ),
                    Row(
                      children: [
                        for (var w = 0; w < widget.weeks; w++)
                          _Column(
                            weekStart: _addDays(firstColumn, w * 7),
                            endDate: widget.endDate,
                            levels: widget.levels,
                            startDate: widget.startDate,
                            colorOf: widget.colorOf,
                            emptyCell: widget.emptyCell,
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
  final DateTime? startDate;
  final ValueChanged<DateTime>? onSelected;

  const _MonthLabels({
    required this.firstColumn,
    required this.weeks,
    required this.label,
    required this.startDate,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    final marks = <(double, DateTime, String)>[];
    var lastMonth = -1;
    for (var w = 0; w < weeks; w++) {
      final columnStart = DateTime(
        firstColumn.year,
        firstColumn.month,
        firstColumn.day + w * 7,
      );
      final start = startDate != null && columnStart.isBefore(startDate!)
          ? startDate!
          : columnStart;
      if (start.month == lastMonth) continue;
      lastMonth = start.month;
      if (w > weeks - 3 && !(w == 0 && startDate != null)) continue;
      marks.add((
        w * _kSlotSize,
        DateTime(start.year, start.month),
        label(start),
      ));
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _kMaxTextScale,
      child: SizedBox(
        height: _kMonthLabelHeight,
        child: Stack(
          clipBehavior: .none,
          children: [
            for (final (x, month, text) in marks)
              Positioned(
                left: x,
                top: 0,
                child: onSelected == null
                    ? Text(text, style: style, maxLines: 1)
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: weeks * _kSlotSize - x,
                        ),
                        child: GestureDetector(
                          behavior: .opaque,
                          onTap: () => onSelected!(month),
                          child: Text(text, style: style, maxLines: 1),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final MHeatmapEmptyCell emptyCell;
  final DateTime? startDate;
  final Color? Function(DateTime day)? colorOf;
  final DateTime weekStart;
  final DateTime endDate;
  final Map<DateTime, int> levels;
  final DateTime? selected;
  final ValueChanged<DateTime>? onDaySelected;

  const _Column({
    required this.weekStart,
    required this.startDate,
    required this.colorOf,
    required this.emptyCell,
    required this.endDate,
    required this.levels,
    required this.selected,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
            if (day.isAfter(endDate) ||
                (startDate != null && day.isBefore(startDate!))) {
              return const SizedBox.square(dimension: _kSlotSize);
            }
            final color = colorOf?.call(day);
            return _Cell(
              day: day,
              color: colorOf == null
                  ? MHeatmap.levelColor(context, levels[day] ?? 0)
                  : color ?? MHeatmap.emptyColor(context),
              dashed:
                  colorOf != null &&
                  color == null &&
                  emptyCell == .dashed &&
                  !day.isAfter(today),
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
  final Color color;
  final bool dashed;
  final bool isToday;
  final bool isSelected;
  final ValueChanged<DateTime>? onTap;

  const _Cell({
    required this.day,
    required this.color,
    required this.dashed,
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

    final cell = Container(
      width: _kCellSize,
      height: _kCellSize,
      decoration: BoxDecoration(
        color: dashed ? null : color,
        borderRadius: _kCellBorderRadius,
        border: border,
      ),
    );
    final box = Center(
      child: Skeleton.replace(
        width: _kCellSize,
        height: _kCellSize,
        replacement: const Bone(
          width: _kCellSize,
          height: _kCellSize,
          borderRadius: _kCellBorderRadius,
        ),
        child: dashed
            ? Stack(
                children: [
                  const Positioned.fill(child: MHeatmapDashedSwatch()),
                  // Rings paint over the dashes without changing the cell size.
                  cell,
                ],
              )
            : cell,
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

/// Unfilled dashed square for empty heatmap cells.
class MHeatmapDashedSwatch extends StatelessWidget {
  const MHeatmapDashedSwatch({super.key});

  @override
  Widget build(BuildContext context) => Skeleton.replace(
    width: _kCellSize,
    height: _kCellSize,
    replacement: const Bone(
      width: _kCellSize,
      height: _kCellSize,
      borderRadius: _kCellBorderRadius,
    ),
    child: CustomPaint(
      size: const Size.square(_kCellSize),
      painter: _DashedCellPainter(context.theme.colors.outlineVariant),
    ),
  );
}

class _DashedCellPainter extends CustomPainter {
  const _DashedCellPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = Path()
      ..addRRect(_kCellBorderRadius.toRRect(Offset.zero & size).deflate(.5));
    final outline = path.computeMetrics().single;
    // About 1.5px of stroke and 1.5px of space, evenly around the corners.
    final count = (outline.length / 3).round();
    final step = outline.length / count;
    final paint = Paint()
      ..color = color
      ..style = .stroke
      ..strokeWidth = 1;
    for (var i = 0; i < count; i++) {
      canvas.drawPath(outline.extractPath(i * step, (i + .5) * step), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCellPainter oldDelegate) =>
      color != oldDelegate.color;
}

class MHeatmapLegend extends StatelessWidget {
  final String lessLabel;
  final String moreLabel;

  /// Custom scale colors, ordered from less to more. Defaults to level colors.
  final List<Color>? colors;

  const MHeatmapLegend({
    super.key,
    required this.lessLabel,
    required this.moreLabel,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    return Row(
      mainAxisSize: .min,
      children: [
        Text(lessLabel, style: style),
        for (var i = 0; i < (colors?.length ?? _kLevelStops.length); i++)
          Padding(
            padding: const .symmetric(horizontal: 2),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors?[i] ?? MHeatmap.levelColor(context, i),
                borderRadius: const .all(.circular(2)),
              ),
            ),
          ),
        Text(moreLabel, style: style),
      ],
    );
  }
}
