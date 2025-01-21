import 'dart:math';

import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:moodiary/common/values/border.dart';

class FloatingModal extends StatelessWidget {
  final Widget child;
  final bool isScrollControlled;

  const FloatingModal(
      {super.key, required this.child, required this.isScrollControlled});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final padding = MediaQuery.viewPaddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final maxHeight = isScrollControlled
        ? size.height - (padding.top - padding.bottom)
        : size.height * 9.0 / 16.0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, bottom: max(padding.bottom, 16)),
          child: Material(
            color: colorScheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            borderRadius: AppBorderRadius.largeBorderRadius,
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<T> showFloatingModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) async {
  final result = await showCustomModalBottomSheet(
      context: context,
      builder: builder,
      enableDrag: isScrollControlled,
      containerWidget: (_, animation, child) => FloatingModal(
            isScrollControlled: isScrollControlled,
            child: child,
          ),
      expand: false);

  return result;
}
