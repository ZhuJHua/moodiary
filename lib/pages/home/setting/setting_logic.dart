import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mood_diary/components/dashboard/dashboard_logic.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/pages/home/home_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:refreshed/refreshed.dart';

import '../../../utils/data/pref.dart';
import '../../../utils/file_util.dart';
import '../../../utils/notice_util.dart';
import 'setting_state.dart';

class SettingLogic extends GetxController {
  final SettingState state = SettingState();
  late final homeLogic = Bind.find<HomeLogic>();

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    unawaited(getDataUsage());
    super.onReady();
  }

  //获取当前占用储存空间
  Future<void> getDataUsage() async {
    var sizeMap = await FileUtil.countSize();
    state.dataUsage = '${sizeMap['size']} ${sizeMap['unit']}';
    update(['DataUsage']);
    if (sizeMap['bytes'] > (1024 * 1024 * 100)) {
      await FileUtil.clearCache();
      await getDataUsage();
      NoticeUtil.showToast('缓存已自动清理');
    }
  }

  Future<void> deleteCache() async {
    await FileUtil.clearCache();
    await getDataUsage();
    NoticeUtil.showToast('清理成功');
  }

  //本地化
  Future<void> local(bool value) async {
    await PrefUtil.setValue<bool>('local', value);
    state.local = value;
    update(['Local']);
  }

  //立即锁定
  Future<void> lockNow(bool value) async {
    await PrefUtil.setValue<bool>('lockNow', value);
    state.lockNow = value;
    update(['Lock']);
  }

  void toAnalysePage() {
    HapticFeedback.selectionClick();
    Get.toNamed(AppRoutes.analysePage);
  }

  Future<void> toMap() async {
    if (PrefUtil.getValue<String>('tiandituKey') != null) {
      HapticFeedback.selectionClick();
      Get.toNamed(AppRoutes.mapPage);
    } else {
      NoticeUtil.showToast('请先配置Key');
    }
  }

  Future<void> toAi() async {
    if (PrefUtil.getValue<String>('tencentId') != null &&
        PrefUtil.getValue<String>('tencentKey') != null) {
      HapticFeedback.selectionClick();
      Get.toNamed(AppRoutes.assistantPage);
    } else {
      NoticeUtil.showToast('请先配置Key');
    }
  }

  Future<void> toCategoryManager() async {
    await Get.toNamed(AppRoutes.categoryManagerPage);
    Bind.find<DashboardLogic>().getCategoryCount();
  }

  Future<void> changeBackendPrivacy(bool value) async {
    await PrefUtil.setValue<bool>('backendPrivacy', value);
    state.backendPrivacy.value = value;
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

  Future<void> setCustomTitle({required String title}) async {
    state.customTitle = title.trim();
    update(['CustomTitle']);
    await PrefUtil.setValue<String>('customTitleName', state.customTitle);
    Bind.find<DiaryLogic>().updateTitle();
  }
}
