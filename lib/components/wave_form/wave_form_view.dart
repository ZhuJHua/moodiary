import 'package:flutter/material.dart';

class WaveFormPainter extends CustomPainter {
  final double barWidth;
  final double spaceWidth;
  final Color color;
  final List<double> amplitudes;

  WaveFormPainter(
    this.amplitudes, {
    required this.barWidth,
    required this.spaceWidth,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..style = PaintingStyle.fill;

    final barHeightFactor = size.height - barWidth;
    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * (barWidth + spaceWidth) + barWidth / 2;
      final y = barHeightFactor * (1 - amplitudes[i]);
      canvas.drawLine(Offset(x, barHeightFactor), Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class WaveFormComponent extends StatelessWidget {
  const WaveFormComponent({
    super.key,
    required this.amplitudes,
    this.barWidth = 4.0,
    this.spaceWidth = 2.0,
    required this.height,
  });

  final List<double> amplitudes;
  final double barWidth;
  final double spaceWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: WaveFormPainter(amplitudes, color: colorScheme.primary, barWidth: barWidth, spaceWidth: spaceWidth),
      size: Size(amplitudes.length * (barWidth + spaceWidth), height),
    );
  }
}
