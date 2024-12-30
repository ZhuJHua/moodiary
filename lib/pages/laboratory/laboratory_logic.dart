import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/data/pref.dart';
import '../../utils/file_util.dart';
import '../../utils/notice_util.dart';
import 'laboratory_state.dart';

class LaboratoryLogic extends GetxController {
  final LaboratoryState state = LaboratoryState();
  late TextEditingController idTextEditingController = TextEditingController();
  late TextEditingController keyTextEditingController = TextEditingController();
  late TextEditingController qweatherTextEditingController =
      TextEditingController();

  late TextEditingController tiandituTextEditingController =
      TextEditingController();

  @override
  void onClose() {
    idTextEditingController.dispose();
    qweatherTextEditingController.dispose();
    keyTextEditingController.dispose();
    tiandituTextEditingController.dispose();

    super.onClose();
  }

  Future<void> setTencentID() async {
    if (idTextEditingController.text.isNotEmpty &&
        keyTextEditingController.text.isNotEmpty) {
      await PrefUtil.setValue<String>(
          'tencentId', idTextEditingController.text);
      await PrefUtil.setValue<String>(
          'tencentKey', keyTextEditingController.text);
      Get.backLegacy();
    }
    update();
  }

  Future<void> setQweatherKey() async {
    if (qweatherTextEditingController.text.isNotEmpty) {
      await PrefUtil.setValue<String>(
          'qweatherKey', qweatherTextEditingController.text);
      Get.backLegacy();
    }
    update();
  }

  Future<void> setTiandituKey() async {
    if (tiandituTextEditingController.text.isNotEmpty) {
      await PrefUtil.setValue<String>(
          'tiandituKey', tiandituTextEditingController.text);
      Get.backLegacy();
    }
    update();
  }

  Future<void> exportErrorLog() async {
    if (await File(FileUtil.getErrorLogPath()).exists()) {
      var result = await Share.shareXFiles([XFile(FileUtil.getErrorLogPath())]);
      // 如果分享成功则删除日志
      if (result.status == ShareResultStatus.success) {
        await File(FileUtil.getErrorLogPath()).delete();
        NoticeUtil.showToast('日志导出成功，已删除本地日志');
      }
    } else {
      NoticeUtil.showToast('暂无日志');
    }
  }
}
