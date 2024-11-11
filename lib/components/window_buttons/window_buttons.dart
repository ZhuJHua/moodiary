import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class WindowButtons extends StatelessWidget {
  final ColorScheme colorScheme;

  const WindowButtons({super.key, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: colorScheme.secondary,
      mouseDown: colorScheme.secondaryContainer,
      normal: colorScheme.surfaceContainer,
      iconMouseDown: colorScheme.secondary,
      mouseOver: colorScheme.secondaryContainer,
      iconMouseOver: colorScheme.onSecondaryContainer,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: colorScheme.secondary,
      mouseDown: colorScheme.secondaryContainer,
      normal: colorScheme.surfaceContainer,
      iconMouseDown: colorScheme.secondary,
      mouseOver: colorScheme.errorContainer,
      iconMouseOver: colorScheme.onErrorContainer,
    );
    return Container(
      color: colorScheme.surface,
      height: appWindow.titleBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          MinimizeWindowButton(colors: buttonColors),
          MaximizeWindowButton(colors: buttonColors),
          CloseWindowButton(colors: closeButtonColors),
        ],
      ),
    );
  }
}
