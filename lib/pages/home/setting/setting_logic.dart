import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/dashboard/dashboard_logic.dart';
import 'package:mood_diary/pages/home/home_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

import 'setting_state.dart';

class SettingLogic extends GetxController {
  final SettingState state = SettingState();
  late final homeLogic = Bind.find<HomeLogic>();

  late TextEditingController textEditingController = TextEditingController(text: state.customTitle);

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    unawaited(getDataUsage());
    super.onReady();
  }

  @override
  void onClose() {
    textEditingController.dispose();
    super.onClose();
  }

  //获取当前占用储存空间
  Future<void> getDataUsage() async {
    var sizeMap = await Utils().fileUtil.countSize();
    state.dataUsage = '${sizeMap['size']} ${sizeMap['unit']}';
    update(['DataUsage']);
    if (sizeMap['bytes'] > (1024 * 1024 * 100)) {
      await Utils().fileUtil.clearCache();
      await getDataUsage();
      Utils().noticeUtil.showToast('缓存已自动清理');
    }
  }

  Future<void> deleteCache() async {
    await Utils().fileUtil.clearCache();
    await getDataUsage();
    Utils().noticeUtil.showToast('清理成功');
  }

  //本地化
  Future<void> local(bool value) async {
    await Utils().prefUtil.setValue<bool>('local', value);
    state.local = value;
    update(['Local']);
  }

  //立即锁定
  Future<void> lockNow(bool value) async {
    await Utils().prefUtil.setValue<bool>('lockNow', value);
    state.lockNow = value;
    update(['Lock']);
  }

  void toAnalysePage() {
    HapticFeedback.selectionClick();
    Get.toNamed(AppRoutes.analysePage);
  }

  Future<void> toMap() async {
    if (Utils().prefUtil.getValue<String>('tiandituKey') != null) {
      HapticFeedback.selectionClick();
      Get.toNamed(AppRoutes.mapPage);
    } else {
      Utils().noticeUtil.showToast('请先配置Key');
    }
  }

  Future<void> toAi() async {
    if (Utils().prefUtil.getValue<String>('tencentId') != null &&
        Utils().prefUtil.getValue<String>('tencentKey') != null) {
      HapticFeedback.selectionClick();
      Get.toNamed(AppRoutes.assistantPage);
    } else {
      Utils().noticeUtil.showToast('请先配置Key');
    }
  }

  Future<void> toCategoryManager() async {
    await Get.toNamed(AppRoutes.categoryManagerPage);
    Bind.find<DashboardLogic>().getCategoryCount();
  }

  //进入回收站
  void toRecyclePage() {
    Get.toNamed(AppRoutes.recyclePage);
  }

  //进入字体大小设置页
  void toFontSizePage() {
    Get.toNamed(AppRoutes.fontPage);
  }

  void toLaboratoryPage() {
    Get.toNamed(AppRoutes.laboratoryPage);
  }

  void toAboutPage() {
    Get.toNamed(AppRoutes.aboutPage);
  }

  void toDiarySettingPage() {
    Get.toNamed(AppRoutes.diarySettingPage);
  }

  void toBackupAndSyncPage() {
    Get.toNamed(AppRoutes.backupSyncPage);
  }

  void cancelCustomTitle() {
    textEditingController.clear();
    Get.backLegacy();
  }

  Future<void> setCustomTitle() async {
    if (textEditingController.text.isNotEmpty) {
      state.customTitle = textEditingController.text;
      update(['CustomTitle']);
      await Utils().prefUtil.setValue<String>('customTitleName', textEditingController.text);
      Get.backLegacy();
      textEditingController.clear();
      Utils().noticeUtil.showToast('重启应用后生效');
    }
  }

  //更改字体
  Future<void> changeFontTheme(int value) async {
    Get.backLegacy();
    await Utils().prefUtil.setValue<int>('fontTheme', value);
    state.fontTheme.value = value;
    Get.changeTheme(Utils().themeUtil.buildTheme(Brightness.light));
    Get.changeTheme(Utils().themeUtil.buildTheme(Brightness.dark));
  }
}
