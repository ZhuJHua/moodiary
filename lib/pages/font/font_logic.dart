import 'dart:io';

import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/src/rust/api/font.dart';
import 'package:mood_diary/utils/file_util.dart';
import 'package:path/path.dart';

import '../../utils/data/pref.dart';
import '../../utils/notice_util.dart';
import '../../utils/theme_util.dart';
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

  Future<void> getFontList({bool inInit = true}) async {
    if (inInit) {
      state.isFetching.value = true;
    }

    final filePathList = await FileUtil.getDirFilePath('font');
    for (var filePath in filePathList) {
      if (filePath.endsWith('.ttf')) {
        //尝试获取字体名称，如果获取失败，不添加到列表
        var fontName =
            await FontReader.getFontNameFromTtf(ttfFilePath: filePath);
        if (fontName != null) {
          state.fontMap[filePath] = fontName;
        }
      }
    }
    List<Future<void>> fontLoadFutures = [];
    // 预加载字体
    for (var entry in state.fontMap.entries) {
      if (loadedFonts.contains(entry.value)) {
        continue;
      }
      fontLoadFutures.add(
          DynamicFont.file(fontFamily: entry.value, filepath: entry.key)
              .load());
    }
    await Future.wait(fontLoadFutures);
    update();
    state.isFetching.value = false;
  }

  Future<void> addFont() async {
    var res = await FilePicker.platform.pickFiles(
      dialogTitle: '选择字体，仅支持ttf格式，使用可变字体最佳',
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['ttf'],
    );
    if (res != null) {
      var path = res.files.single.path!;
      // 检查字体名称，是否已经存在
      var fontName = await FontReader.getFontNameFromTtf(ttfFilePath: path);
      if (state.fontMap.containsValue(fontName)) {
        NoticeUtil.showToast('字体已存在');
        return;
      }
      var newPath = FileUtil.getRealPath('font', basename(path));
      File(path).copy(newPath);
      await getFontList(inInit: false);
      NoticeUtil.showToast('添加成功');
    } else {
      NoticeUtil.showToast('取消文件选择');
    }
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
