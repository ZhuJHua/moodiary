import 'package:flutter/foundation.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/font_util.dart';
import 'package:moodiary/utils/media_util.dart';

class MergeUtil {
  static Future<void> merge({required String lastAppVersion}) async {
    final appVersionCode = lastAppVersion.split('+')[0];

    /// 数据库版本变更
    /// v2.4.8
    if (appVersionCode.compareTo('2.4.8') < 0) {
      await compute(
        IsarUtil.mergeToV2_4_8,
        FileUtil.getRealPath('database', ''),
      );
    }

    /// v2.6.0
    if (appVersionCode.compareTo('2.6.0') < 0) {
      await compute(
        IsarUtil.mergeToV2_6_0,
        FileUtil.getRealPath('database', ''),
      );
    }

    /// 修复bug
    /// v2.6.2
    /// 修复部分视频缩略图无法生成的问题
    if (appVersionCode.compareTo('2.6.2') < 0) {
      await MediaUtil.regenerateMissingThumbnails();
    }

    /// v2.6.3
    /// 修复同步失败导致本地分类丢失
    /// 视频缩略图重复生成
    if (appVersionCode.compareTo('2.6.3') < 0) {
      await FileUtil.cleanFile(FileUtil.getRealPath('database', ''));
      await MediaUtil.regenerateMissingThumbnails();
      await compute(IsarUtil.fixV2_6_3, FileUtil.getRealPath('database', ''));
    }

    /// v2.7.3
    /// 修改自定义字体存储方式
    if (appVersionCode.compareTo('2.7.3') < 0) {
      await PrefUtil.setValue('customFont', '');
      final allFont = await FontUtil.getAllFonts();
      await compute(IsarUtil.mergeToV2_7_3, {
        'database': FileUtil.getRealPath('database', ''),
        'fonts': allFont,
      });
    }
  }
}
