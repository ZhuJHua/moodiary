import 'dart:math' as math;

import 'package:mui/mui.dart';

/// A discrete, nullable series. Missing samples break the connecting line.
class MLineChart extends StatefulWidget {
  final List<double?> values;
  final double yMin;
  final double yMax;
  final double? baseline;
  final Widget Function(int tick)? yLabelBuilder;
  final List<(int, String)> xLabels;
  final Color Function(int index, double value) pointColor;
  final Color? ringColor;
  final String Function(int index) tooltipBuilder;
  final String semanticsLabel;
  final double height;

  const MLineChart({
    super.key,
    required this.values,
    required this.yMin,
    required this.yMax,
    this.baseline,
    this.yLabelBuilder,
    this.xLabels = const [],
    required this.pointColor,
    this.ringColor,
    required this.tooltipBuilder,
    required this.semanticsLabel,
    this.height = 220,
  }) : assert(yMax > yMin);

  @override
  State<MLineChart> createState() => _MLineChartState();
}

class _MLineChartState extends State<MLineChart> {
  int? _selected;

  @override
  void didUpdateWidget(MLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final tooltip = Theme.of(context).tooltipTheme;
    final selected = _selected;
    return Semantics(
      label: widget.semanticsLabel,
      excludeSemantics: true,
      value: selected == null ? null : widget.tooltipBuilder(selected),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final left = widget.yLabelBuilder == null ? 10.0 : 28.0;
            final plot = Rect.fromLTRB(
              left + 7,
              44,
              constraints.maxWidth - 10,
              widget.height - 30,
            );
            double x(int index) => widget.values.length <= 1
                ? plot.center.dx
                : plot.left + plot.width * index / (widget.values.length - 1);
            double y(double value) =>
                plot.bottom -
                plot.height *
                    ((value - widget.yMin) / (widget.yMax - widget.yMin)).clamp(
                      0,
                      1,
                    );
            void select(Offset offset) {
              if (widget.values.isEmpty) return;
              final index = widget.values.length <= 1
                  ? 0
                  : ((offset.dx - plot.left) /
                            plot.width *
                            (widget.values.length - 1))
                        .round()
                        .clamp(0, widget.values.length - 1);
              setState(() => _selected = index);
            }

            final bubbleWidth = math.min(240.0, constraints.maxWidth);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (event) => select(event.localPosition),
              onHorizontalDragStart: (event) => select(event.localPosition),
              onHorizontalDragUpdate: (event) => select(event.localPosition),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LinePainter(
                        values: widget.values,
                        yMin: widget.yMin,
                        yMax: widget.yMax,
                        baseline: widget.baseline,
                        plot: plot,
                        grid: colors.outlineVariant,
                        line: colors.onSurfaceVariant,
                        ring: widget.ringColor ?? colors.surfaceContainerLow,
                        pointColors: [
                          for (var i = 0; i < widget.values.length; i++)
                            widget.values[i] == null
                                ? colors.outline
                                : widget.pointColor(i, widget.values[i]!),
                        ],
                      ),
                    ),
                  ),
                  if (widget.yLabelBuilder != null)
                    for (
                      var tick = widget.yMin.ceil();
                      tick <= widget.yMax.floor();
                      tick++
                    )
                      Positioned(
                        left: 0,
                        top: y(tick.toDouble()) - 10,
                        width: left,
                        height: 20,
                        child: Center(child: widget.yLabelBuilder!(tick)),
                      ),
                  for (final (index, label) in widget.xLabels)
                    if (index >= 0 && index < widget.values.length)
                      Positioned(
                        left: (x(index) - 18).clamp(
                          0,
                          constraints.maxWidth - 36,
                        ),
                        bottom: 0,
                        width: 36,
                        height: 22,
                        child: Center(
                          child: Text(
                            label,
                            maxLines: 1,
                            style: context
                                .theme
                                .typography
                                .labelSmall
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                  if (selected != null)
                    Positioned(
                      left: (x(selected) - bubbleWidth / 2).clamp(
                        0,
                        constraints.maxWidth - bubbleWidth,
                      ),
                      top: 0,
                      width: bubbleWidth,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            key: const ValueKey('line-chart-tooltip'),
                            padding:
                                tooltip.padding ??
                                const .symmetric(horizontal: 10, vertical: 6),
                            decoration:
                                tooltip.decoration ??
                                BoxDecoration(
                                  color: colors.inverseSurface,
                                  borderRadius: .circular(6),
                                ),
                            child: Text(
                              widget.tooltipBuilder(selected),
                              textAlign: .center,
                              style:
                                  tooltip.textStyle ??
                                  context.theme.typography.labelSmall.onSurface
                                      .copyWith(color: colors.onInverseSurface),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double?> values;
  final double yMin;
  final double yMax;
  final double? baseline;
  final Rect plot;
  final Color grid;
  final Color line;
  final Color ring;
  final List<Color> pointColors;

  _LinePainter({
    required this.values,
    required this.yMin,
    required this.yMax,
    required this.baseline,
    required this.plot,
    required this.grid,
    required this.line,
    required this.ring,
    required this.pointColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double x(int index) => values.length <= 1
        ? plot.center.dx
        : plot.left + plot.width * index / (values.length - 1);
    double y(double value) =>
        plot.bottom -
        plot.height * ((value - yMin) / (yMax - yMin)).clamp(0, 1);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0;
    for (var tick = yMin.ceil(); tick <= yMax.floor(); tick++) {
      gridPaint.strokeWidth = 0;
      canvas.drawLine(
        Offset(plot.left, y(tick.toDouble())),
        Offset(plot.right, y(tick.toDouble())),
        gridPaint,
      );
    }
    final reference = baseline;
    if (reference != null && reference >= yMin && reference <= yMax) {
      canvas.drawLine(
        Offset(plot.left, y(reference)),
        Offset(plot.right, y(reference)),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
    }
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = .stroke;
    Offset? previous;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        previous = null;
        continue;
      }
      final point = Offset(x(index), y(value));
      if (previous != null) canvas.drawLine(previous, point, linePaint);
      previous = point;
    }
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) continue;
      final point = Offset(x(index), y(value));
      canvas.drawCircle(point, 5.5, Paint()..color = ring);
      canvas.drawCircle(point, 4.5, Paint()..color = pointColors[index]);
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = ring
          ..style = .stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) => true;
}
