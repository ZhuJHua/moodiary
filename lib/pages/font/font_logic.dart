import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/font.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/font_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/theme_util.dart';
import 'package:path/path.dart';

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
    state.bottomSheetHeight.value = state.bottomSheetHeight.value.clamp(
      state.minHeight,
      state.maxHeight,
    );
  }

  void changeSelectedFont({Font? font}) async {
    if (font == null) {
      state.currentFontFamily.value = '';
      return;
    }

    state.currentFontFamily.value = font.fontFamily;
  }

  Future<void> getFontList() async {
    state.isFetching.value = true;
    state.fontList.value = await IsarUtil.getAllFonts();
    final loadList = <Future>[];
    for (final font in state.fontList) {
      loadList.add(
        FontUtil.loadFont(
          fontName: font.fontFamily,
          fontPath: FileUtil.getRealPath('font', font.fontFileName),
        ),
      );
    }
    await Future.wait(loadList);
    state.isFetching.value = false;
  }

  Future<void> addFont() async {
    final xFile = await FontUtil.pickFont();
    if (xFile == null) {
      return;
    }
    final fontType = extension(xFile.path);

    /// 如果 font family 已存在，但是字体格式不同，也视为相同字体
    final fontName = await FontUtil.getFontName(filePath: xFile.path);
    if (fontName == null) {
      toast.error(message: '字体名称获取失败');
      return;
    }
    if (state.fontList.any((element) => element.fontFamily == fontName)) {
      toast.info(message: '字体已存在');
      return;
    }
    final fontFileName = '$fontName$fontType';
    final newPath = FileUtil.getRealPath('font', fontFileName);
    final newFont = Font(
      fontFileName: fontFileName,
      fontWghtAxisMap: await FontUtil.getFontWghtAxis(filePath: xFile.path),
    );
    await xFile.saveTo(newPath);
    await IsarUtil.insertAFont(newFont);
    state.fontList.add(newFont);
    FontUtil.loadFont(
      fontName: newFont.fontFamily,
      fontPath: FileUtil.getRealPath('font', newFont.fontFileName),
    );
    toast.success(message: '添加成功');
  }

  //更改字体
  Future<void> changeFontTheme() async {
    await PrefUtil.setValue<String>(
      'customFont',
      state.currentFontFamily.value,
    );
    await ThemeUtil.forceUpdateTheme();

    EllipsisText.clearCache();
  }

  //删除字体
  Future<void> deleteFont({required Font font}) async {
    //如果是当前使用的字体，先切换到默认字体，再删除
    if (state.currentFontFamily.value == font.fontFamily) {
      state.currentFontFamily.value = '';
      await changeFontTheme();
    }
    await IsarUtil.deleteFont(font.id);
    await FileUtil.deleteFile(FileUtil.getRealPath('font', font.fontFileName));
    state.fontList.remove(font);
    toast.success(message: '删除成功');
  }

  //保存设置
  Future<void> saveFontScale() async {
    await PrefUtil.setValue<double>('fontScale', state.fontScale.value);
    await changeFontTheme();
    await Get.forceAppUpdate();
    toast.success(message: '保存成功');
  }
}
