import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/home/home_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'setting_state.dart';

class SettingLogic extends GetxController {
  final SettingState state = SettingState();
  late final homeLogic = Bind.find<HomeLogic>();

  late TextEditingController textEditingController = TextEditingController(text: state.customTitle.value);

  @override
  void onInit() {
    // TODO: implement onInit
    getDataUsage();
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady

    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    textEditingController.dispose();

    super.onClose();
  }

  //获取当前占用储存空间
  Future<void> getDataUsage() async {
    var sizeMap = await Utils().fileUtil.countSize();
    state.dataUsage.value = '${sizeMap['size']} ${sizeMap['unit']}';
    if (sizeMap['bytes'] > (1024 * 1024 * 100)) {
      await deleteCache();
      Utils().noticeUtil.showToast('缓存已自动清理');
    }
  }

  Future<void> deleteCache() async {
    await Utils().fileUtil.clearCache();
    await getDataUsage();
    Utils().noticeUtil.showToast('清理成功');
  }

  //动态配色
  Future<void> dynamicColor(bool value) async {
    await Utils().prefUtil.setValue<bool>('dynamicColor', value);
    state.dynamicColor.value = value;
  }

  //图片质量
  Future<void> quality(int value) async {
    Get.backLegacy();
    await Utils().prefUtil.setValue<int>('quality', value);
    state.quality.value = value;
  }

  //本地化
  Future<void> local(bool value) async {
    await Utils().prefUtil.setValue<bool>('local', value);
    state.local.value = value;
  }

  //获取天气
  Future<void> weather(bool value) async {
    if (await Utils().permissionUtil.checkPermission(Permission.location)) {
      await Utils().prefUtil.setValue<bool>('getWeather', value);
      state.getWeather.value = value;
    }
  }

  //立即锁定
  Future<void> lockNow(bool value) async {
    await Utils().prefUtil.setValue<bool>('lockNow', value);
    state.lockNow.value = value;
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

  void cancelCustomTitle() {
    textEditingController.clear();
    Get.backLegacy();
  }

  Future<void> setCustomTitle() async {
    if (textEditingController.text.isNotEmpty) {
      state.customTitle.value = textEditingController.text;
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
    Get.changeTheme(await Utils().themeUtil.buildTheme(Brightness.light));
    Get.changeTheme(await Utils().themeUtil.buildTheme(Brightness.dark));
  }

  Future<void> exportFile() async {
    Get.backLegacy();
    Utils().noticeUtil.showToast('正在处理中');
    final dataPath = Utils().fileUtil.getRealPath('', '');
    final zipPath = Utils().fileUtil.getCachePath('');
    final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
    var path = await compute(Utils().fileUtil.zipFile, isolateParams);
    await Share.shareXFiles([XFile(path)]);
  }

  //导入
  Future<void> import() async {
    Get.backLegacy();
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowedExtensions: ['zip'], type: FileType.custom);
    if (result != null) {
      Utils().noticeUtil.showToast('数据导入中，请不要离开页面');
      await Utils().fileUtil.extractFile(result.files.single.path!);
      Utils().noticeUtil.showToast('导入成功');
    } else {
      Utils().noticeUtil.showToast('取消文件选择');
    }
  }
}
