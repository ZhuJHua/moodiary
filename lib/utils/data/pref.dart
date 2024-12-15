import 'package:flutter/foundation.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/utils/auth_util.dart';
import 'package:mood_diary/utils/media_util.dart';
import 'package:mood_diary/utils/package_util.dart';
import 'package:mood_diary/utils/theme_util.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../file_util.dart';
import 'isar.dart';

class PrefUtil {
  static late final SharedPreferencesWithCache _prefs;

  static const allowList = {
    //应用版本
    'appVersion',
    //首次启动标识
    'firstStart',
    //自动同步
    'autoSync',
    //动态配色支持
    'supportDynamicColor',
    //当前系统颜色
    'systemColor',
    //主题颜色
    'color',
    //主题模式
    'themeMode',
    //动态配色
    'dynamicColor',
    //图片质量
    'quality',
    //本地化
    'local',
    //应用锁
    'lock',
    //uuid
    'uuid',
    //字体缩放
    'fontScale',
    //立即锁定
    'lockNow',
    //字体样式
    'fontTheme',
    //和风key
    'qweatherKey',
    'tencentId',
    'tencentKey',
    'tiandituKey',
    //侧边栏天气
    'getWeather',
    //天气缓存
    'weather',
    //一言缓存
    'hitokoto',
    //图片缓存
    'bingImage',
    //第一次打开的时间
    'startTime',
    //应用文档路径
    'supportPath',
    //缓存路径
    'cachePath',
    //密码
    'password',
    //生物识别支持
    'supportBiometrics',
    //自定义首页名称
    'customTitleName',
    //首页视图模式
    'homeViewMode',
    //自动获取天气
    'autoWeather',
    //webdav配置
    'webDavOption',
    // 日记展示头图
    'diaryHeader',
    // 首行缩进
    'firstLineIndent',
    // 自动设置分类
    'autoCategory',
    // 展示写作时长
    'showWritingTime',
    // 展示字数统计
    'showWordCount',
  };

  static Future<void> initPref() async {
    _prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(allowList: allowList));
    // 首次启动
    var firstStart = _prefs.getBool('firstStart') ?? true;
    await _prefs.setBool('firstStart', firstStart);

    // 获取当前应用版本
    var packageInfo = await PackageUtil.getPackageInfo();
    var currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    var appVersion = _prefs.getString('appVersion');

    /// 数据库版本变更
    /// v2.4.8
    if (appVersion != null && appVersion.split('+')[0].compareTo('2.4.8') < 0) {
      await compute(IsarUtil.mergeToV2_4_8, FileUtil.getRealPath('database', ''));
    }

    /// v2.6.0
    if (appVersion != null && appVersion.split('+')[0].compareTo('2.6.0') < 0) {
      await compute(IsarUtil.mergeToV2_6_0, FileUtil.getRealPath('database', ''));
    }

    /// 修复bug
    /// v2.6.2
    /// 修复部分视频缩略图无法生成的问题
    if (appVersion != null && appVersion.split('+')[0].compareTo('2.6.2') < 0) {
      await MediaUtil.regenerateMissingThumbnails();
    }

    /// v2.6.3
    /// 修复同步失败导致本地分类丢失
    /// 视频缩略图重复生成
    if (appVersion != null && appVersion.split('+')[0].compareTo('2.6.3') < 0) {
      await compute(FileUtil.cleanFile, FileUtil.getRealPath('database', ''));
      await MediaUtil.regenerateMissingThumbnails();
      await compute(IsarUtil.fixV2_6_3, FileUtil.getRealPath('database', ''));
    }

    // 如果是首次启动或版本不一致
    if (kDebugMode || firstStart || appVersion == null || appVersion != currentVersion) {
      await _prefs.setString('appVersion', currentVersion);
      await setDefaultValues();
      //初始化所需目录
      await FileUtil.initCreateDir();
    }
  }

  // 设置默认值的方法
  static Future<void> setDefaultValues() async {
    await _prefs.setBool('autoSync', _prefs.getBool('autoSync') ?? false);

    /// 支持相关，每次都重新获取
    await _prefs.setBool('supportBiometrics', await AuthUtil.canCheckBiometrics());

    var supportDynamicColor = await ThemeUtil.supportDynamicColor();
    await _prefs.setBool('supportDynamicColor', supportDynamicColor);

    if (supportDynamicColor) {
      var color = await ThemeUtil.getDynamicColor();
      await _prefs.setInt(
          'systemColor',
          ((color.a * 255).toInt() << 24) |
              ((color.r * 255).toInt() << 16) |
              ((color.g * 255).toInt() << 8) |
              (color.b * 255).toInt());
    }

    await _prefs.setInt('color', _prefs.getInt('color') ?? (await ThemeUtil.supportDynamicColor() ? -1 : 4));
    await _prefs.setInt('themeMode', _prefs.getInt('themeMode') ?? 0);
    await _prefs.setBool('dynamicColor', _prefs.getBool('dynamicColor') ?? true);
    await _prefs.setInt('quality', _prefs.getInt('quality') ?? 2);
    await _prefs.setBool('local', _prefs.getBool('local') ?? false);
    await _prefs.setBool('lock', _prefs.getBool('lock') ?? false);
    await _prefs.setDouble('fontScale', _prefs.getDouble('fontScale') ?? 1.0);
    await _prefs.setBool('lockNow', _prefs.getBool('lockNow') ?? false);
    await _prefs.setInt('fontTheme', _prefs.getInt('fontTheme') ?? 0);

    /// 支持相关，重新获取
    await _prefs.setString('supportPath', (await getApplicationSupportDirectory()).path);
    await _prefs.setString('cachePath', (await getApplicationCacheDirectory()).path);

    await _prefs.setBool('getWeather', _prefs.getBool('getWeather') ?? false);
    await _prefs.setInt('startTime', _prefs.getInt('startTime') ?? DateTime.now().millisecondsSinceEpoch);
    await _prefs.setString('customTitleName', _prefs.getString('customTitleName') ?? '');
    await _prefs.setInt('homeViewMode', _prefs.getInt('homeViewMode') ?? ViewModeType.list.number);
    await _prefs.setBool('autoWeather', _prefs.getBool('autoWeather') ?? false);
    await _prefs.setStringList('webDavOption', _prefs.getStringList('webDavOption') ?? []);
    await _prefs.setBool('diaryHeader', _prefs.getBool('diaryHeader') ?? true);
    await _prefs.setBool('firstLineIndent', _prefs.getBool('firstLineIndent') ?? false);
    await _prefs.setBool('autoCategory', _prefs.getBool('autoCategory') ?? false);
    await _prefs.setBool('showWritingTime', _prefs.getBool('showWritingTime') ?? true);
    await _prefs.setBool('showWordCount', _prefs.getBool('showWordCount') ?? true);
  }

  static Future<void> setValue<T>(String key, T value) async {
    if (T == int) {
      await _prefs.setInt(key, value as int);
    } else if (T == bool) {
      await _prefs.setBool(key, value as bool);
    } else if (T == double) {
      await _prefs.setDouble(key, value as double);
    } else if (T == String) {
      await _prefs.setString(key, value as String);
    } else if (T == List<String>) {
      await _prefs.setStringList(key, value as List<String>);
    } else {
      throw ArgumentError('Unsupported type: $T');
    }
  }

  static T? getValue<T>(String key) {
    if (T == int) {
      return _prefs.getInt(key) as T?;
    } else if (T == bool) {
      return _prefs.getBool(key) as T?;
    } else if (T == double) {
      return _prefs.getDouble(key) as T?;
    } else if (T == String) {
      return _prefs.getString(key) as T?;
    } else if (T == List<String>) {
      return _prefs.getStringList(key) as T?;
    } else {
      throw ArgumentError('Unsupported type: $T');
    }
  }

  static Future<void> removeValue(String key) async {
    await _prefs.remove(key);
  }
}
