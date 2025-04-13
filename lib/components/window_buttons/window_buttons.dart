import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryButtonColors = WindowButtonColors(
      iconNormal: context.theme.colorScheme.onSurfaceVariant,
      mouseDown: context.theme.colorScheme.primaryContainer,
      normal: Colors.transparent,
      iconMouseDown: context.theme.colorScheme.onPrimaryContainer,
      mouseOver: context.theme.colorScheme.primaryContainer,
      iconMouseOver: context.theme.colorScheme.onPrimaryContainer,
    );

    final secondaryButtonColors = WindowButtonColors(
      iconNormal: context.theme.colorScheme.onSurfaceVariant,
      mouseDown: context.theme.colorScheme.secondaryContainer,
      normal: Colors.transparent,
      iconMouseDown: context.theme.colorScheme.onSecondaryContainer,
      mouseOver: context.theme.colorScheme.secondaryContainer,
      iconMouseOver: context.theme.colorScheme.onSecondaryContainer,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: context.theme.colorScheme.secondary,
      mouseDown: context.theme.colorScheme.errorContainer,
      normal: Colors.transparent,
      iconMouseDown: context.theme.colorScheme.onErrorContainer,
      mouseOver: context.theme.colorScheme.errorContainer,
      iconMouseOver: context.theme.colorScheme.onErrorContainer,
    );
    var isMaximized = appWindow.isMaximized;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MinimizeWindowButton(colors: secondaryButtonColors, animate: true),
            StatefulBuilder(
              builder: (context, setState) {
                return isMaximized
                    ? RestoreWindowButton(
                      colors: primaryButtonColors,
                      animate: true,
                      onPressed: () {
                        appWindow.maximizeOrRestore();
                        setState(() {
                          isMaximized = !isMaximized;
                        });
                      },
                    )
                    : MaximizeWindowButton(
                      colors: primaryButtonColors,
                      animate: true,
                      onPressed: () {
                        appWindow.maximizeOrRestore();
                        setState(() {
                          isMaximized = !isMaximized;
                        });
                      },
                    );
              },
            ),
            CloseWindowButton(colors: closeButtonColors, animate: true),
          ],
        ),
      ),
    );
  }
}

class WindowsBar extends StatelessWidget {
  const WindowsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surfaceContainer,
      child: const SizedBox(height: 24, width: double.infinity),
    );
  }
}

class MoveTitle extends StatelessWidget {
  const MoveTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => appWindow.startDragging(),
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        height: 32,
        child: Visibility(
          visible: Platform.isWindows || Platform.isLinux,
          child: const WindowButtons(),
        ),
      ),
    );
  }
}
