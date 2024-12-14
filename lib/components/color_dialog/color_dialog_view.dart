import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/colors.dart';

import '../../main.dart';
import 'color_dialog_logic.dart';

class ColorDialogComponent extends StatelessWidget {
  const ColorDialogComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(ColorDialogLogic());
    final state = Bind.find<ColorDialogLogic>().state;

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
              Text(AppColor.colorName(index)),
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
            Text(l10n.colorNameSystem),
            if (state.currentColor == -1) ...[const Icon(Icons.check)]
          ],
        ),
        onPressed: () {
          logic.changeSeedColor(-1);
        },
      );
    }

    return GetBuilder<ColorDialogLogic>(
      assignId: true,
      builder: (_) {
        return SimpleDialog(
          title: Text(l10n.settingColor),
          children: [
            if (state.supportDynamic) ...[buildSystemColor()],
            ...buildColorList()
          ],
        );
      },
    );
  }
}
