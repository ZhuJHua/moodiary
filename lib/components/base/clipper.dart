import 'package:flutter/rendering.dart';

class TopRRectClipper extends CustomClipper<RRect> {
  final double topOffset;

  TopRRectClipper({this.topOffset = 0});

  @override
  RRect getClip(Size size) {
    final Rect rect = Rect.fromLTWH(
      0,
      topOffset,
      size.width,
      size.height - topOffset,
    );
    const Radius radius = Radius.circular(12.0);
    return RRect.fromRectAndRadius(rect, radius);
  }

  @override
  bool shouldReclip(covariant TopRRectClipper oldClipper) {
    return oldClipper.topOffset != topOffset;
  }
}
