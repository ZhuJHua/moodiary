import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'laboratory_state.dart';

class LaboratoryLogic extends GetxController {
  final LaboratoryState state = LaboratoryState();
  late TextEditingController idTextEditingController = TextEditingController();
  late TextEditingController keyTextEditingController = TextEditingController();
  late TextEditingController qweatherTextEditingController = TextEditingController();

  @override
  void onReady() {
    initInfo();
    super.onReady();
  }

  @override
  void onClose() {
    idTextEditingController.dispose();
    qweatherTextEditingController.dispose();
    keyTextEditingController.dispose();

    super.onClose();
  }

  Future<void> initInfo() async {
    state.deviceInfo = await Utils().packageUtil.getInfo();
    update();
  }

  Future<void> setTencentID() async {
    if (idTextEditingController.text.isNotEmpty && keyTextEditingController.text.isNotEmpty) {
      await Utils().prefUtil.setValue<String>('tencentId', idTextEditingController.text);
      await Utils().prefUtil.setValue<String>('tencentKey', keyTextEditingController.text);
      Get.backLegacy();
    }
  }

  Future<void> setQweatherKey() async {
    if (qweatherTextEditingController.text.isNotEmpty) {
      await Utils().prefUtil.setValue<String>('qweatherKey', qweatherTextEditingController.text);
      Get.backLegacy();
    }
  }
}
