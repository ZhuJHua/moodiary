import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'font_state.dart';

class FontLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final FontState state = FontState();

  void changeFontScale(value) {
    state.fontScale = value;
    update();
  }

  void changeWeight() {
    update();
  }

  //保存设置
  Future<void> saveFontScale() async {
    await showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: const Text('确认修改'),
            actions: [
              TextButton(
                  onPressed: () {
                    Get.backLegacy();
                  },
                  child: const Text('取消')),
              TextButton(
                  onPressed: () async {
                    Get.backLegacy();
                    await Utils().prefUtil.setValue<double>('fontScale', state.fontScale);
                    Get.forceAppUpdate();
                  },
                  child: const Text('确认'))
            ],
          );
        });
  }
}
