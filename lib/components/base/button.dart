import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

class FrostedGlassButton extends StatelessWidget {
  final Widget child;
  final double size;
  final Function()? onPressed;

  const FrostedGlassButton(
      {super.key, required this.child, required this.size, this.onPressed});

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
  MultiFabLayoutDelegate({
    required this.controller,
    required this.layoutIds,
  }) : super(relayout: controller);

  final Animation<double> controller;
  final List<int> layoutIds;

  static const double mainButtonHeight = 56.0;
  static const double childButtonHeight = 46.0;
  static const double buttonSpacing = 8.0;

  @override
  void performLayout(Size size) {
    final animationValue = controller.value;

    // 布局主按钮
    if (hasChild(0)) {
      final mainButtonSize = layoutChild(
        0,
        BoxConstraints.loose(const Size(mainButtonHeight, mainButtonHeight)),
      );
      positionChild(
        0,
        Offset(size.width - mainButtonSize.width,
            size.height - mainButtonSize.height),
      );
    }

    // 布局子按钮
    for (int i = 1; i < layoutIds.length; i++) {
      final layoutId = layoutIds[i];
      if (hasChild(layoutId)) {
        final childButtonSize = layoutChild(
          layoutId,
          BoxConstraints(
            maxWidth: size.width,
            maxHeight: childButtonHeight,
          ),
        );

        // 动态计算子按钮的垂直偏移量
        final dyOffset = (mainButtonHeight + buttonSpacing) +
            (i - 1) * (childButtonSize.height + buttonSpacing) * animationValue;

        // 动态计算水平偏移量，使子按钮完全隐藏在主按钮底部时的水平位置对齐
        final dxOffset = (mainButtonHeight - childButtonSize.width) /
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

  const PageBackButton({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: IconButton(
        onPressed: onBack ?? Get.back,
        icon: const Icon(Icons.arrow_back_rounded),
        color: colorScheme.onSurface,
        tooltip: l10n.back,
      ),
    );
  }
}
