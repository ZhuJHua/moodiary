import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_core/moodiary_core.dart';

class FrostedGlassButton extends StatelessWidget {
  final Widget child;
  final double size;
  final Function()? onPressed;

  const FrostedGlassButton({
    super.key,
    required this.child,
    required this.size,
    this.onPressed,
  });

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

class MultiFabLayoutDelegate extends MultiChildLayoutDelegate {
  MultiFabLayoutDelegate({required this.controller, required this.layoutIds})
    : super(relayout: controller);

  final Animation<double> controller;
  final List<int> layoutIds;

  static const double mainButtonHeight = 56.0;
  static const double childButtonHeight = 46.0;
  static const double buttonSpacing = 8.0;

  @override
  void performLayout(Size size) {
    final animationValue = controller.value;

    if (hasChild(0)) {
      final mainButtonSize = layoutChild(
        0,
        BoxConstraints.loose(const Size(mainButtonHeight, mainButtonHeight)),
      );
      positionChild(
        0,
        Offset(
          size.width - mainButtonSize.width,
          size.height - mainButtonSize.height,
        ),
      );
    }

    for (int i = 1; i < layoutIds.length; i++) {
      final layoutId = layoutIds[i];
      if (hasChild(layoutId)) {
        final childButtonSize = layoutChild(
          layoutId,
          BoxConstraints(maxWidth: size.width, maxHeight: childButtonHeight),
        );

        final dyOffset =
            (mainButtonHeight + buttonSpacing) +
            (i - 1) * (childButtonSize.height + buttonSpacing) * animationValue;

        final dxOffset =
            (mainButtonHeight - childButtonSize.width) /
            2 *
            (1 - animationValue);

        positionChild(
          layoutId,
          Offset(
            size.width - mainButtonHeight + dxOffset,
            size.height - mainButtonHeight - dyOffset,
          ),
        );
      }
    }
  }

  @override
  bool shouldRelayout(MultiFabLayoutDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.layoutIds != layoutIds;
  }
}

class PageBackButton extends StatelessWidget {
  final Function()? onBack;

  final Color? color;

  const PageBackButton({super.key, this.onBack, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        onPressed: onBack ?? () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded),
        color: color ?? context.theme.colorScheme.onSurface,
        tooltip: context.l10n.back,
      ),
    );
  }
}
