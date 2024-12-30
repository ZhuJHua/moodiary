import 'package:flutter/material.dart';

class TimeLinePainter extends CustomPainter {
  final double lineWidth;
  final Color lineColor;
  final Color actionColor;

  TimeLinePainter({
    super.repaint,
    this.lineWidth = 2.0,
    required this.lineColor,
    required this.actionColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth;
    var actionPaint = Paint()..color = actionColor;
    canvas.drawLine(const Offset(20, 0), Offset(20, size.height), linePaint);
    canvas.drawCircle(Offset(20, size.height / 2), 10.0, actionPaint);
  }

  @override
  bool shouldRepaint(covariant TimeLinePainter oldDelegate) {
    return false;
  }
}

class TimeLineComponent extends StatelessWidget {
  const TimeLineComponent(
      {super.key, required this.actionColor, required this.child});

  final Color actionColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomPaint(
      painter: TimeLinePainter(
          lineColor: colorScheme.outline,
          actionColor: actionColor,
          lineWidth: 2.0),
      child: Padding(
        padding: const EdgeInsets.only(left: 40.0),
        child: child,
      ),
    );
  }
}
