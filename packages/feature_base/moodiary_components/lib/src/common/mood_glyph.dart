import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';

class MoodGlyph extends StatelessWidget {
  const MoodGlyph({
    super.key,
    required this.mood,
    this.size = 24,
    this.palette,
    this.semanticLabel,
  });

  final DiaryMood? mood;
  final double size;
  final MoodPalette? palette;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Skeleton.replace(
    width: size,
    height: size,
    replacement: Bone.circle(size: size),
    child: Semantics(
      label:
          semanticLabel ??
          mood?.label(context) ??
          context.l10n.common.moodUnset,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MoodPainter(
          mood: mood,
          fill: mood?.colorOf(context, palette: palette),
          ink:
              mood?.onColorOf(context, palette: palette) ??
              context.theme.colors.outline,
          small: size < 20,
        ),
      ),
    ),
  );
}

class _MoodPainter extends CustomPainter {
  const _MoodPainter({
    required this.mood,
    required this.fill,
    required this.ink,
    required this.small,
  });

  final DiaryMood? mood;
  final Color? fill;
  final Color ink;
  final bool small;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = ink
      ..style = .stroke
      ..strokeCap = .round
      ..strokeJoin = .round;
    if (mood == null) {
      stroke.strokeWidth = 1.5;
      const radius = 10.2;
      const circumference = 2 * math.pi * radius;
      for (var distance = 0.0; distance < circumference; distance += 4.8) {
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: radius),
          distance / radius,
          math.min(2.6, circumference - distance) / radius,
          false,
          stroke,
        );
      }
    } else {
      canvas.drawCircle(const Offset(12, 12), 11.5, Paint()..color = fill!);
      stroke.strokeWidth = small ? 3 : 2.6;
      final eyeY = mood == .awful ? 10.6 : 9.6;
      canvas.drawPoints(ui.PointMode.points, [
        Offset(9, eyeY),
        Offset(15, eyeY),
      ], stroke);
      stroke.strokeWidth = small ? 2.1 : 1.8;
      final mouth = Path();
      switch (mood!) {
        case .awful:
          mouth
            ..moveTo(16.5, 17.2)
            ..cubicTo(16.5, 17.2, 14.9, 14.5, 12, 14.5)
            ..cubicTo(9.1, 14.5, 7.5, 17.2, 7.5, 17.2)
            ..moveTo(7.6, 8.6)
            ..lineTo(10, 7.7)
            ..moveTo(16.4, 8.6)
            ..lineTo(14, 7.7);
        case .bad:
          mouth
            ..moveTo(16, 16.2)
            ..cubicTo(16, 16.2, 14.5, 14.2, 12, 14.2)
            ..cubicTo(9.5, 14.2, 8, 16.2, 8, 16.2);
        case .okay:
          mouth
            ..moveTo(8, 15)
            ..lineTo(16, 15);
        case .good:
          mouth
            ..moveTo(8, 14)
            ..cubicTo(8, 14, 9.5, 16, 12, 16)
            ..cubicTo(14.5, 16, 16, 14, 16, 14);
        case .great:
          mouth
            ..moveTo(17.5, 13)
            ..arcToPoint(
              const Offset(6.5, 13),
              radius: const Radius.circular(5.6),
            )
            ..close();
      }
      canvas.drawPath(mouth, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoodPainter oldDelegate) =>
      mood != oldDelegate.mood ||
      fill != oldDelegate.fill ||
      ink != oldDelegate.ink ||
      small != oldDelegate.small;
}
