import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/find_locale.dart';
import 'package:mood_diary/router/app_pages.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/src/rust/frb_generated.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'components/window_buttons/window_buttons.dart';

Future<void> initSystem() async {
  WidgetsFlutterBinding.ensureInitialized();
  // GestureBinding.instance.resamplingEnabled = true;
  //获取系统语言
  await findSystemLocale();
  //初始化pref
  await Utils().prefUtil.initPref();
  //初始化Isar
  await Utils().isarUtil.initIsar();
  //初始化视频播放
  VideoPlayerMediaKit.ensureInitialized(android: true, iOS: true, macOS: true, windows: true, linux: true);
  //地图缓存
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapStore').manage.create();
  await Utils().webDavUtil.initWebDav();
  RustLib.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent, systemNavigationBarContrastEnforced: false));
  platFormOption();
}

void platFormOption() {
  if (Platform.isAndroid) {
    //设置高刷
    unawaited(FlutterDisplayMode.setHighRefreshRate());
  }
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(512, 640);
      appWindow.size = const Size(1024, 640);
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }
}

String getInitialRoute() {
  final prefs = Utils().prefUtil;
  if (prefs.getValue<bool>('lock')!) return AppRoutes.lockPage;
  if (prefs.getValue<bool>('firstStart')!) return AppRoutes.startPage;
  return AppRoutes.homePage;
}

void main() async {
  await initSystem();
  FlutterError.onError = (details) async {
    Utils().logUtil.printError('Flutter error', error: details.exception, stackTrace: details.stack);
    if (details.exceptionAsString().contains('Render')) {
      Utils().noticeUtil.showBug(message: '布局异常！');
    } else {
      Utils().noticeUtil.showBug(message: '出错了，请联系开发者！');
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Utils().logUtil.printWTF('Error', error: error, stackTrace: stack);
    Utils().noticeUtil.showBug(message: '出错了，请联系开发者！');
    return true;
  };
  runApp(GetMaterialApp(
    initialRoute: getInitialRoute(),
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
    builder: (context, child) {
      final fontScale = Utils().prefUtil.getValue<double>('fontScale')!;
      final colorScheme = Theme.of(context).colorScheme;
      final mediaQuery = MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
        child: FToastBuilder()(context, child!),
      );
      // 根据平台决定是否需要 MoveWindow
      final windowChild = (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
          ? Column(children: [WindowButtons(colorScheme: colorScheme), Expanded(child: mediaQuery)])
          : mediaQuery;
      return windowChild;
    },
    theme: Utils().themeUtil.buildTheme(Brightness.light),
    darkTheme: Utils().themeUtil.buildTheme(Brightness.dark),
    themeMode: ThemeMode.values[Utils().prefUtil.getValue<int>('themeMode')!],
    defaultTransition: Transition.cupertino,
    getPages: AppPages.routes,
    localizationsDelegates: const [...AppLocalizations.localizationsDelegates, FlutterQuillLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
  ));
}
