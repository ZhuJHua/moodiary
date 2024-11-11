import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/colors.dart';

import 'color_dialog_logic.dart';

class ColorDialogComponent extends StatelessWidget {
  const ColorDialogComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(ColorDialogLogic());
    final state = Bind.find<ColorDialogLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    String colorName(index) {
      return switch (index) {
        0 => i18n.colorNameQunQin,
        1 => i18n.colorNameJiHe,
        2 => i18n.colorNameQinDai,
        3 => i18n.colorNameXianYe,
        4 => i18n.colorNameJinYu,
        _ => i18n.colorNameSystem
      };
    }

    List<Widget> buildColorList() {
      return List.generate(AppColor.themeColorList.length, (index) {
        return SimpleDialogOption(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10.0,
            children: [
              Icon(
                Icons.circle,
                color: AppColor.themeColorList[index],
              ),
              Text(colorName(index)),
              if (state.currentColor == index) ...[const Icon(Icons.check)]
            ],
          ),
          onPressed: () {
            logic.changeSeedColor(index);
          },
        );
      });
    }

    Widget buildSystemColor() {
      return SimpleDialogOption(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10.0,
          children: [
            Icon(
              Icons.circle,
              color: state.systemColor,
            ),
            Text(i18n.colorNameSystem),
            if (state.currentColor == -1) ...[const Icon(Icons.check)]
          ],
        ),
        onPressed: () {
          logic.changeSeedColor(-1);
        },
      );
    }

    return GetBuilder<ColorDialogLogic>(
      builder: (_) {
        return SimpleDialog(
          title: Text(i18n.settingColor),
          children: [
            if (state.supportDynamic) ...[buildSystemColor()],
            ...buildColorList()
          ],
        );
      },
    );
  }
}
