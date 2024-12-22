import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';

import 'font_manage_dialog_logic.dart';

class FontManageDialogComponent extends StatelessWidget {
  final String fontPath;

  const FontManageDialogComponent({super.key, required this.fontPath});

  @override
  Widget build(BuildContext context) {
    final FontManageDialogLogic logic = Get.put(FontManageDialogLogic(currentFontPath: fontPath));
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('字体管理'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: logic.fontNameController,
            decoration: InputDecoration(
              fillColor: colorScheme.secondaryContainer,
              filled: true,
              border: const OutlineInputBorder(
                  borderRadius: AppBorderRadius.smallBorderRadius, borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {},
          child: Text(
            '删除字体',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () {
            Get.backLegacy();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Get.backLegacy();
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
