import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/font_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/theme_util.dart';
import 'package:refreshed/refreshed.dart';

import 'font_state.dart';

class FontLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final FontState state = FontState();

  @override
  void onReady() async {
    await getFontList();
    super.onReady();
  }

  void changeFontScale(value) {
    state.fontScale.value = value;
  }

  void onVerticalDragStart(DragUpdateDetails details) {
    state.bottomSheetHeight.value -= details.delta.dy;
    state.bottomSheetHeight.value =
        state.bottomSheetHeight.value.clamp(state.minHeight, state.maxHeight);
  }

  void changeSelectedFontPath({required String path}) {
    state.currentFontPath.value = path;
  }

  Future<void> getFontList() async {
    state.isFetching.value = true;
    final filePathList = await FileUtil.getDirFilePath('font');
    for (final filePath in filePathList) {
      if (filePath.endsWith('.ttf')) {
        final fontName = await FontUtil.getFontName(filePath: filePath);
        if (fontName != null) {
          state.fontMap[filePath] = fontName;
          await FontUtil.loadFont(fontName: fontName, fontPath: filePath);
        }
      }
    }
    state.isFetching.value = false;
  }

  Future<void> addFont() async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: '选择字体，仅支持ttf格式，使用可变字体最佳',
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['ttf'],
    );
    if (res != null) {
      final path = res.files.single.path!;
      // 检查字体名称，是否已经存在
      final fontName = await FontUtil.getFontName(filePath: path);
      if (state.fontMap.containsValue(fontName)) {
        NoticeUtil.showToast('字体已存在');
        return;
      }
      final newPath = FileUtil.getRealPath('font', '$fontName.ttf');
      File(path).copy(newPath);
      await getFontList();
      NoticeUtil.showToast('添加成功');
    } else {
      NoticeUtil.showToast('取消文件选择');
    }
    update();
  }

  //更改字体
  Future<void> changeFontTheme() async {
    await PrefUtil.setValue<String>('customFont', state.currentFontPath.value);
    Get.changeTheme(await ThemeUtil.buildTheme(Brightness.light));
    Get.changeTheme(await ThemeUtil.buildTheme(Brightness.dark));
  }

  //删除字体
  Future<void> deleteFont({required String fontPath}) async {
    //如果是当前使用的字体，先切换到默认字体，再删除
    if (state.currentFontPath.value == fontPath) {
      state.currentFontPath.value = '';
      await changeFontTheme();
    }
    await File(fontPath).delete();
    state.fontMap.remove(fontPath);
    NoticeUtil.showToast('删除成功');
  }

  //保存设置
  Future<void> saveFontScale() async {
    await PrefUtil.setValue<double>('fontScale', state.fontScale.value);
    await changeFontTheme();
    await Get.forceAppUpdate();
    NoticeUtil.showToast('保存成功');
  }
}
