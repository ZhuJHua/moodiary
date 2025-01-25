import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
    return GestureDetector(
      onPanStart: (_) => appWindow.startDragging(),
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        height: 46,
        child: Visibility(
          visible: Platform.isWindows,
          child: Align(
            alignment: Alignment.topRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MinimizeWindowButton(
                  colors: buttonColors,
                  animate: true,
                ),
                MaximizeWindowButton(
                  colors: buttonColors,
                  animate: true,
                ),
                CloseWindowButton(
                  colors: closeButtonColors,
                  animate: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
