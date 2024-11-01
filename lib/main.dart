import 'dart:async';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/intl_standalone.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mood_diary/router/app_pages.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/channel.dart';
import 'package:mood_diary/utils/utils.dart';

Future<void> initSystem() async {
  //获取系统语言
  unawaited(findSystemLocale());
  //初始化pref
  await Utils().prefUtil.initPref();
  //初始化Isar
  await Utils().isarUtil.initIsar();
  //初始化视频播放
  MediaKit.ensureInitialized();
  //地图缓存
  await FMTCObjectBoxBackend().initialise();
  unawaited(const FMTCStore('mapStore').manage.create());
  platFormOption();
  //supabase初始化
  //await Utils().supabaseUtil.initSupabase();
}

void platFormOption() {
  if (Platform.isAndroid) {
    //设置高刷
    unawaited(FlutterDisplayMode.setHighRefreshRate());
    //设置状态栏沉浸
    unawaited(ViewChannel.setSystemUIVisibility());
  }

  if (Platform.isWindows) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(512, 640);
      appWindow.size = const Size(1024, 640);
      appWindow.show();
    });
  }
}

String getInitialRoute() {
  var initialRoute = AppRoutes.homePage;
  if (Utils().prefUtil.getValue<bool>('firstStart')!) {
    initialRoute = AppRoutes.startPage;
  }
  if (Utils().prefUtil.getValue<bool>('lock')!) {
    initialRoute = AppRoutes.lockPage;
  }
  return initialRoute;
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      Utils().logUtil.printError('Flutter error', error: details.exception, stackTrace: details.stack);
      Utils().noticeUtil.showBug();
    };
    //初始化系统
    await initSystem();
    runApp(GetMaterialApp(
      initialRoute: getInitialRoute(),
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      builder: (context, child) {
        final mediaQuery = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(Utils().prefUtil.getValue<double>('fontScale')!),
          ),
          child: child!,
        );
        final windowChild = Platform.isWindows ? MoveWindow(child: mediaQuery) : mediaQuery;

        return FToastBuilder()(context, windowChild);
      },
      theme: await Utils().themeUtil.buildTheme(Brightness.light),
      darkTheme: await Utils().themeUtil.buildTheme(Brightness.dark),
      themeMode: ThemeMode.values[Utils().prefUtil.getValue<int>('themeMode')!],
      defaultTransition: Transition.cupertino,
      getPages: AppPages.routes,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
  }, (error, stack) {
    Utils().logUtil.printWTF('Error', error: error, stackTrace: stack);
    Utils().noticeUtil.showBug();
  });
}
