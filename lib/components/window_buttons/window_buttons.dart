import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/utils/utils.dart';

class WindowButtons extends StatelessWidget {
  final ColorScheme colorScheme;

  final RxString hitokoto = ''.obs;

  //获取一言
  Future<void> getHitokoto() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      var res = await Utils().cacheUtil.getCacheList('hitokoto', Api().updateHitokoto, maxAgeMillis: 15 * 60000);
      if (res != null) {
        hitokoto.value = res.first;
      }
    }
  }

  WindowButtons({super.key, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    getHitokoto();
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
      child: MoveWindow(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            MinimizeWindowButton(colors: buttonColors),
            MaximizeWindowButton(colors: buttonColors),
            CloseWindowButton(colors: closeButtonColors),
          ],
        ),
      ),
    );
  }
}
