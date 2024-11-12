import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:share_plus/share_plus.dart';

import 'laboratory_state.dart';

class LaboratoryLogic extends GetxController {
  final LaboratoryState state = LaboratoryState();
  late TextEditingController idTextEditingController = TextEditingController();
  late TextEditingController keyTextEditingController = TextEditingController();
  late TextEditingController qweatherTextEditingController = TextEditingController();

  late TextEditingController tiandituTextEditingController = TextEditingController();

  @override
  void onClose() {
    idTextEditingController.dispose();
    qweatherTextEditingController.dispose();
    keyTextEditingController.dispose();
    tiandituTextEditingController.dispose();

    super.onClose();
  }

  Future<void> setTencentID() async {
    if (idTextEditingController.text.isNotEmpty && keyTextEditingController.text.isNotEmpty) {
      await Utils().prefUtil.setValue<String>('tencentId', idTextEditingController.text);
      await Utils().prefUtil.setValue<String>('tencentKey', keyTextEditingController.text);
      Get.backLegacy();
    }
    update();
  }

  Future<void> setQweatherKey() async {
    if (qweatherTextEditingController.text.isNotEmpty) {
      await Utils().prefUtil.setValue<String>('qweatherKey', qweatherTextEditingController.text);
      Get.backLegacy();
    }
    update();
  }

  Future<void> setTiandituKey() async {
    if (tiandituTextEditingController.text.isNotEmpty) {
      await Utils().prefUtil.setValue<String>('tiandituKey', tiandituTextEditingController.text);
      Get.backLegacy();
    }
    update();
  }

  Future<void> exportErrorLog() async {
    if (File(Utils().fileUtil.getErrorLogPath()).existsSync()) {
      Share.shareXFiles([XFile(Utils().fileUtil.getErrorLogPath())]);
    } else {
      Utils().noticeUtil.showToast('暂无日志');
    }
  }
}
