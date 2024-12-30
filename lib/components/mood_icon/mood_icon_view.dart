import 'package:flutter/material.dart';
import 'package:mood_diary/common/values/border.dart';

class EmotionCurvePainter extends CustomPainter {
  final double value;
  final double strokeWidth;

  EmotionCurvePainter(this.value, {required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    Path path = Path();

    double centerX = size.width / 2;
    double centerY = size.height / 2;
    double controlPointY = centerY + (value - 0.5) * size.height; // 动态控制点的Y坐标

    // 起点
    path.moveTo(centerX + strokeWidth / 2 - size.width / 2, centerY);

    // 控制点和终点
    path.quadraticBezierTo(centerX, controlPointY,
        centerX - strokeWidth / 2 + size.width / 2, centerY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class MoodIconComponent extends StatelessWidget {
  const MoodIconComponent({super.key, this.width = 32.0, required this.value});

  final double value;

  final double width;

  @override
  Widget build(BuildContext context) {
    // final logic = Get.put(MoodIconLogic());
    // final state = Bind.find<MoodIconLogic>().state;

    return Container(
      decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFFFA4659), const Color(0xFF2EB872), value),
          borderRadius: AppBorderRadius.smallBorderRadius),
      padding: const EdgeInsets.all(4.0),
      child: CustomPaint(
        size: Size(width - 8.0, width - 8.0),
        painter: EmotionCurvePainter(value, strokeWidth: 4.0),
      ),
    );
  }
}
