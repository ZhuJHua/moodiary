import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryButtonColors = WindowButtonColors(
      iconNormal: colorScheme.onSurfaceVariant,
      mouseDown: colorScheme.primaryContainer,
      normal: Colors.transparent,
      iconMouseDown: colorScheme.onPrimaryContainer,
      mouseOver: colorScheme.primaryContainer,
      iconMouseOver: colorScheme.onPrimaryContainer,
    );

    final secondaryButtonColors = WindowButtonColors(
      iconNormal: colorScheme.onSurfaceVariant,
      mouseDown: colorScheme.secondaryContainer,
      normal: Colors.transparent,
      iconMouseDown: colorScheme.onSecondaryContainer,
      mouseOver: colorScheme.secondaryContainer,
      iconMouseOver: colorScheme.onSecondaryContainer,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: colorScheme.secondary,
      mouseDown: colorScheme.errorContainer,
      normal: Colors.transparent,
      iconMouseDown: colorScheme.onErrorContainer,
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
                  colors: secondaryButtonColors,
                  animate: true,
                ),
                MaximizeWindowButton(
                  colors: primaryButtonColors,
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
