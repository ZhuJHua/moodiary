import 'package:flutter/material.dart';

class WaveFormPainter extends CustomPainter {
  final double barWidth;
  final double spaceWidth;
  final Color color;
  final List<double> amplitudes;
  final Paint _paint;

  WaveFormPainter(
    this.amplitudes, {
    required this.barWidth,
    required this.spaceWidth,
    this.color = Colors.white,
  }) : _paint = Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = barWidth
          ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final barHeightFactor = size.height - barWidth;

    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * (barWidth + spaceWidth) + barWidth / 2;
      final y = barHeightFactor * (1 - amplitudes[i]);
      canvas.drawLine(Offset(x, barHeightFactor), Offset(x, y), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveFormPainter oldDelegate) {
    return true;
  }
}
