import 'package:flutter/material.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'theme_mode_dialog_logic.dart';

class ThemeModeDialogComponent extends StatelessWidget {
  const ThemeModeDialogComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(ThemeModeDialogLogic());
    final state = Bind.find<ThemeModeDialogLogic>().state;

    return GetBuilder<ThemeModeDialogLogic>(
      assignId: true,
      builder: (_) {
        return SimpleDialog(
          title: Text(l10n.settingThemeMode),
          children: [
            SimpleDialogOption(
              child: Row(
                spacing: 8.0,
                children: [
                  if (state.themeMode == 0) ...[
                    const Icon(Icons.check),
                  ] else ...[
                    const Icon(Icons.brightness_auto_outlined),
                  ],
                  Text(l10n.themeModeSystem),
                ],
              ),
              onPressed: () {
                logic.changeThemeMode(0);
              },
            ),
            SimpleDialogOption(
              child: Row(
                spacing: 8.0,
                children: [
                  if (state.themeMode == 1) ...[
                    const Icon(Icons.check),
                  ] else ...[
                    const Icon(Icons.light_mode_outlined),
                  ],
                  Text(l10n.themeModeLight),
                ],
              ),
              onPressed: () {
                logic.changeThemeMode(1);
              },
            ),
            SimpleDialogOption(
              child: Row(
                spacing: 8.0,
                children: [
                  if (state.themeMode == 2) ...[
                    const Icon(Icons.check),
                  ] else ...[
                    const Icon(Icons.dark_mode_outlined),
                  ],
                  Text(l10n.themeModeDark),
                ],
              ),
              onPressed: () {
                logic.changeThemeMode(2);
              },
            ),
          ],
        );
      },
    );
  }
}
