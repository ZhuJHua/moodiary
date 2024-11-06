import 'dart:async';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/find_locale.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mood_diary/router/app_pages.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/channel.dart';
import 'package:mood_diary/utils/utils.dart';

Future<void> initSystem() async {
  WidgetsFlutterBinding.ensureInitialized();
  //获取系统语言
  await findSystemLocale();
  //初始化pref
  await Utils().prefUtil.initPref();
  //初始化Isar
  await Utils().isarUtil.initIsar();
  //初始化视频播放
  MediaKit.ensureInitialized();
  //地图缓存
  //await FMTCObjectBoxBackend().initialise();
  //await const FMTCStore('mapStore').manage.create();
  platFormOption();
}

void platFormOption() {
  if (Platform.isAndroid) {
    //设置高刷
    unawaited(FlutterDisplayMode.setHighRefreshRate());
    //设置状态栏沉浸
    unawaited(ViewChannel.setSystemUIVisibility());
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

void main() {
  runZonedGuarded(() {
    FlutterError.onError = (details) {
      Utils().logUtil.printError('Flutter error', error: details.exception, stackTrace: details.stack);
      Utils().noticeUtil.showBug();
    };
    initSystem().then((_) {
      return runApp(GetMaterialApp(
        initialRoute: getInitialRoute(),
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
        builder: (context, child) {
          final fontScale = Utils().prefUtil.getValue<double>('fontScale')!;
          final mediaQuery = MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontScale),
            ),
            child: FToastBuilder()(context, child!),
          );
          // 根据平台决定是否需要 MoveWindow
          final windowChild = (Platform.isWindows || Platform.isMacOS || Platform.isWindows)
              ? MoveWindow(child: mediaQuery)
              : mediaQuery;
          return windowChild;
        },
        theme: Utils().themeUtil.buildTheme(Brightness.light),
        darkTheme: Utils().themeUtil.buildTheme(Brightness.dark),
        themeMode: ThemeMode.values[Utils().prefUtil.getValue<int>('themeMode')!],
        defaultTransition: Transition.cupertino,
        getPages: AppPages.routes,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ));
    });
  }, (error, stack) {
    Utils().logUtil.printWTF('Error', error: error, stackTrace: stack);
    Utils().noticeUtil.showBug();
  });
}
