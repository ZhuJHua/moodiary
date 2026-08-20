import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class EmotionCurvePainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Color color;

  EmotionCurvePainter(
    this.value, {
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = .stroke
      ..strokeCap = .round
      ..strokeWidth = strokeWidth;

    final Path path = Path();

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double controlPointY = centerY + (value - 0.5) * size.height;

    path.moveTo(centerX + strokeWidth / 2 - size.width / 2, centerY);

    path.quadraticBezierTo(
      centerX,
      controlPointY,
      centerX - strokeWidth / 2 + size.width / 2,
      centerY,
    );

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
    return Container(
      decoration: BoxDecoration(
        // 心情色带是业务语义色，不跟主题走（见 AppColor.emoColorList）。
        color: .lerp(
          AppColor.emoColorList.first,
          AppColor.emoColorList.last,
          value,
        ),
        borderRadius: AppBorderRadius.smallBorderRadius,
      ),
      padding: const .all(4.0),
      child: CustomPaint(
        size: Size(width - 8.0, width - 8.0),
        painter: EmotionCurvePainter(
          value,
          strokeWidth: 4.0,
          color: context.theme.onMedia,
        ),
      ),
    );
  }
}
