import 'dart:math';

import 'package:flutter/material.dart';

class EenBadgePainter extends CustomPainter {
  final String envMode;

  EenBadgePainter({super.repaint, required this.envMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffc03546)
      ..style = PaintingStyle.fill;

    final double diagonal = size.width * sqrt(2);
    final double height = size.height / 3;

    canvas.save();

    canvas.rotate(pi / 4);

    final path = Path()
      ..moveTo(0, height)
      ..lineTo(diagonal, height)
      ..lineTo(diagonal - height, 0)
      ..lineTo(height, 0)
      ..close();

    canvas.drawPath(path, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: envMode,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final double centerX = diagonal / 2 - textPainter.width / 2;
    final double centerY = height / 2 - textPainter.height / 2;
    textPainter.paint(canvas, Offset(centerX, centerY));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class EnvBadge extends StatelessWidget {
  final String envMode;

  const EnvBadge({super.key, required this.envMode});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: EenBadgePainter(envMode: envMode),
      child: const SizedBox(
        width: 64,
        height: 64,
      ),
    );
  }
}
