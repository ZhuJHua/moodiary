import 'package:flutter/material.dart';
import 'package:mui/mui.dart';

class Modal extends StatelessWidget {
  final Animation<double> animation;
  final Function() onTap;

  const Modal({super.key, required this.animation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Visibility(
          visible: animation.value > 0,
          child: ModalBarrier(
            color: context.theme.colors.surfaceContainer.withValues(
              alpha: 0.6 * animation.value,
            ),
            barrierSemanticsDismissible: false,
            onDismiss: onTap,
          ),
        );
      },
    );
  }
}
