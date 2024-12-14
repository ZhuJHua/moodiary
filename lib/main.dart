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
import 'package:mood_diary/utils/data/isar.dart';
import 'package:mood_diary/utils/data/pref.dart';
import 'package:mood_diary/utils/log_util.dart';
import 'package:mood_diary/utils/notice_util.dart';
import 'package:mood_diary/utils/theme_util.dart';
import 'package:mood_diary/utils/webdav_util.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'components/window_buttons/window_buttons.dart';

late final AppLocalizations l10n;

Future<void> initSystem() async {
  WidgetsFlutterBinding.ensureInitialized();
  await findSystemLocale();
  await RustLib.init();
  await PrefUtil.initPref();
  await IsarUtil.initIsar();
  await WebDavUtil().initWebDav();
  VideoPlayerMediaKit.ensureInitialized(android: true, iOS: true, macOS: true, windows: true);
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapStore').manage.create();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  platFormOption();
}

void platFormOption() {
  if (Platform.isAndroid) unawaited(FlutterDisplayMode.setHighRefreshRate());
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
  if (PrefUtil.getValue<bool>('lock')!) return AppRoutes.lockPage;
  if (PrefUtil.getValue<bool>('firstStart')!) return AppRoutes.startPage;
  return AppRoutes.homePage;
}

void main() async {
  await initSystem();
  FlutterError.onError = (details) {
    LogUtil.printError('Flutter error', error: details.exception, stackTrace: details.stack);
    if (details.exceptionAsString().contains('Render')) {
      NoticeUtil.showBug(message: '布局异常！');
    } else {
      NoticeUtil.showBug(message: '出错了，请联系开发者处理！');
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogUtil.printWTF('Error', error: error, stackTrace: stack);
    NoticeUtil.showBug(message: '出错了，请联系开发者处理！');
    return true;
  };
  runApp(GetMaterialApp.router(
    routeInformationParser: GetInformationParser.createInformationParser(initialRoute: getInitialRoute()),
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
    backButtonDispatcher: GetRootBackButtonDispatcher(),
    builder: (context, child) {
      l10n = AppLocalizations.of(context)!;
      final mediaQuery = MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(PrefUtil.getValue<double>('fontScale')!)),
        child: FToastBuilder()(context, child!),
      );
      final windowChild = (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
          ? Column(children: [WindowButtons(), Expanded(child: mediaQuery)])
          : mediaQuery;
      return windowChild;
    },
    theme: ThemeUtil.buildTheme(Brightness.light),
    darkTheme: ThemeUtil.buildTheme(Brightness.dark),
    themeMode: ThemeMode.values[PrefUtil.getValue<int>('themeMode')!],
    defaultTransition: Transition.cupertino,
    getPages: AppPages.routes,
    localizationsDelegates: const [...AppLocalizations.localizationsDelegates, FlutterQuillLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
  ));
}

class GetRootBackButtonDispatcher extends BackButtonDispatcher with WidgetsBindingObserver {
  GetRootBackButtonDispatcher();

  @override
  void addCallback(ValueGetter<Future<bool>> callback) {
    if (!hasCallbacks) {
      WidgetsBinding.instance.addObserver(this);
    }
    super.addCallback(callback);
  }

  @override
  void removeCallback(ValueGetter<Future<bool>> callback) {
    super.removeCallback(callback);
    if (!hasCallbacks) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  Future<bool> didPopRoute() async {
    return (await Get.rawRoute?.navigator?.maybePop()) ?? invokeCallback(Future.value(false));
  }
}
