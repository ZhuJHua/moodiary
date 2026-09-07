import 'package:flutter/widgets.dart';
import 'package:mui/src/themes/tokens.dart';

class TopRRectClipper extends CustomClipper<RRect> {
  final double topOffset;

  TopRRectClipper({this.topOffset = 0});

  @override
  RRect getClip(Size size) {
    final Rect rect = .fromLTWH(
      0,
      topOffset,
      size.width,
      size.height - topOffset,
    );
    const Radius radius = .circular(12.0);
    return .fromRectAndRadius(rect, radius);
  }

  @override
  bool shouldReclip(covariant TopRRectClipper oldClipper) {
    return oldClipper.topOffset != topOffset;
  }
}

class PageClipper extends StatelessWidget {
  final Widget child;
  final CustomClipper<RRect>? clipper;

  const PageClipper({super.key, required this.child, this.clipper});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .all(8.0),
      child: ClipRRect(
        borderRadius: MuiRadius.md,
        clipper: clipper,
        child: child,
      ),
    );
  }
}
