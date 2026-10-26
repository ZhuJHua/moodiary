import 'package:flutter/foundation.dart' show listEquals;
import 'package:mui/mui.dart';

/// A discrete, nullable series. Missing samples break the line by default.
class MLineChart extends StatelessWidget {
  final List<double?> values;
  final bool connectGaps;
  final double yMin;
  final double yMax;
  final double? baseline;
  final Widget Function(int tick)? yLabelBuilder;
  final List<(int, String)> xLabels;
  final Color Function(int index, double value) pointColor;
  final Color? ringColor;
  final String semanticsLabel;
  final double height;

  const MLineChart({
    super.key,
    required this.values,
    this.connectGaps = false,
    required this.yMin,
    required this.yMax,
    this.baseline,
    this.yLabelBuilder,
    this.xLabels = const [],
    required this.pointColor,
    this.ringColor,
    required this.semanticsLabel,
    this.height = 220,
  }) : assert(yMax > yMin);

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Skeleton.replace(
      replacement: Bone(
        width: double.infinity,
        height: height,
        borderRadius: .circular(12),
      ),
      child: Semantics(
        label: semanticsLabel,
        excludeSemantics: true,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final left = yLabelBuilder == null ? 10.0 : 28.0;
              final plot = Rect.fromLTRB(
                left + 7,
                yLabelBuilder == null ? 7 : 10,
                constraints.maxWidth - 10,
                height - 30,
              );
              double x(int index) => values.length <= 1
                  ? plot.center.dx
                  : plot.left + plot.width * index / (values.length - 1);
              double y(double value) =>
                  plot.bottom -
                  plot.height * ((value - yMin) / (yMax - yMin)).clamp(0, 1);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LinePainter(
                        values: values,
                        connectGaps: connectGaps,
                        yMin: yMin,
                        yMax: yMax,
                        baseline: baseline,
                        plot: plot,
                        grid: colors.outlineVariant,
                        line: colors.onSurfaceVariant,
                        ring: ringColor ?? colors.surfaceContainerLow,
                        pointColors: [
                          for (var i = 0; i < values.length; i++)
                            values[i] == null
                                ? colors.outline
                                : pointColor(i, values[i]!),
                        ],
                      ),
                    ),
                  ),
                  if (yLabelBuilder != null)
                    for (var tick = yMin.ceil(); tick <= yMax.floor(); tick++)
                      Positioned(
                        left: 0,
                        top: y(tick.toDouble()) - 10,
                        width: left,
                        height: 20,
                        child: Center(child: yLabelBuilder!(tick)),
                      ),
                  for (final (index, label) in xLabels)
                    if (index >= 0 && index < values.length)
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double?> values;
  final bool connectGaps;
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
    required this.connectGaps,
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
        if (!connectGaps) previous = null;
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
  bool shouldRepaint(_LinePainter oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      connectGaps != oldDelegate.connectGaps ||
      yMin != oldDelegate.yMin ||
      yMax != oldDelegate.yMax ||
      baseline != oldDelegate.baseline ||
      plot != oldDelegate.plot ||
      grid != oldDelegate.grid ||
      line != oldDelegate.line ||
      ring != oldDelegate.ring ||
      !listEquals(pointColors, oldDelegate.pointColors);
}
