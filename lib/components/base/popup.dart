import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';

class _TrianglePainter extends CustomPainter {
  final Color color;

  final Size size;

  _TrianglePainter({required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path =
        Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width / 2, 0)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => false;
}

void showPopupWidget({
  required BuildContext targetContext,
  required Widget child,
}) {
  SmartDialog.showAttach(
    targetContext: targetContext,
    maskColor: Colors.transparent,
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(12, 6),
            painter: _TrianglePainter(
              color: context.theme.colorScheme.surfaceContainer,
              size: const Size(12, 6),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainer,
              borderRadius: AppBorderRadius.mediumBorderRadius,
            ),
            child: child,
          ),
        ],
      );
    },
  );
}
