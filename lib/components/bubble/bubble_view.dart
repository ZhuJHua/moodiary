import 'package:flutter/material.dart';

class Bubble extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double borderRadius;

  const Bubble({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BubblePainter(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: child,
        ),
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  BubblePainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const arrowWidth = 16.0;
    const arrowHeight = 8.0;
    final rectWidth = size.width;
    final rectHeight = size.height - arrowHeight; // 减去箭头的高度

    // 创建带圆角的矩形区域
    final rrect = RRect.fromLTRBR(
      0,
      0,
      rectWidth,
      rectHeight,
      Radius.circular(borderRadius),
    );

    // 创建路径
    final path = Path()
      ..addRRect(rrect) // 添加圆角矩形
      ..moveTo((rectWidth - arrowWidth) / 2, rectHeight) // 箭头左侧
      ..lineTo(rectWidth / 2, rectHeight + arrowHeight) // 箭头尖端
      ..lineTo((rectWidth + arrowWidth) / 2, rectHeight); // 箭头右侧

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
