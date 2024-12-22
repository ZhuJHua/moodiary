import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedGlassButton extends StatelessWidget {
  final Widget child;
  final double size;
  final Function()? onPressed;

  const FrostedGlassButton({super.key, required this.child, required this.size, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.hardEdge,
        decoration: const ShapeDecoration(shape: CircleBorder()),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(child: child),
        ),
      ),
    );
  }
}
