import 'package:mui/mui.dart';

class Bubble extends StatelessWidget {
  final Widget child;

  /// 不给就跟着主题走。默认参数必须是编译期常量，取不到 context，所以留空。
  final Color? backgroundColor;
  final double borderRadius;

  const Bubble({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BubblePainter(
        color: backgroundColor ?? context.theme.colors.surfaceContainerHigh,
        borderRadius: borderRadius,
      ),
      child: Align(
        alignment: .topCenter,
        child: Padding(padding: const .all(4.0), child: child),
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
      ..style = .fill;
    const arrowWidth = 16.0;
    const arrowHeight = 8.0;
    final rectWidth = size.width;
    final rectHeight = size.height - arrowHeight;

    final rrect = RRect.fromLTRBR(
      0,
      0,
      rectWidth,
      rectHeight,
      .circular(borderRadius),
    );

    final path = Path()
      ..addRRect(rrect)
      ..moveTo((rectWidth - arrowWidth) / 2, rectHeight)
      ..lineTo(rectWidth / 2, rectHeight + arrowHeight)
      ..lineTo((rectWidth + arrowWidth) / 2, rectHeight);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
