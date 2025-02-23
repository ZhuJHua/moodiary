import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/values/language.dart';
import 'package:moodiary/components/env_badge/badge.dart';
import 'package:moodiary/components/frosted_glass_overlay/frosted_glass_overlay_view.dart';
import 'package:moodiary/components/window_buttons/window_buttons.dart';
import 'package:moodiary/config/env.dart';
import 'package:moodiary/l10n/app_localizations.dart';
import 'package:moodiary/presentation/isar.dart';
import 'package:moodiary/router/app_pages.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/src/rust/frb_generated.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/theme_util.dart';
import 'package:moodiary/utils/webdav_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'presentation/pref.dart';

late AppLocalizations l10n;
late Locale locale;

Future<void> _initSystem() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await PrefUtil.initPref();
  await IsarUtil.initIsar();
  await WebDavUtil().initWebDav();
  VideoPlayerMediaKit.ensureInitialized(
      android: true, iOS: true, macOS: true, windows: true);
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapStore').manage.create();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  await _findLanguage();
  await _platFormOption();
}

Future<void> _findLanguage() async {
  Language language = Language.values.firstWhere(
    (e) => e.languageCode == PrefUtil.getValue<String>('language')!,
    orElse: () => Language.system,
  );
  if (language == Language.system) {
    final systemLocale = await findSystemLocale();
    final systemLanguageCode = systemLocale.contains('_')
        ? systemLocale.split('_').first
        : systemLocale;
    language = Language.values.firstWhere(
      (e) => e.languageCode == systemLanguageCode,
      orElse: () => Language.english,
    );
  }
  locale = Locale(language.languageCode);
  Intl.defaultLocale = locale.languageCode;
}

Future<void> _platFormOption() async {
  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
    MediaUtil.useAndroidImagePicker();
  }
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(600, 640);
      appWindow.size = const Size(1024, 640);
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }
}

String _getInitialRoute() {
  if (PrefUtil.getValue<bool>('lock')!) return AppRoutes.lockPage;
  if (PrefUtil.getValue<bool>('firstStart')!) return AppRoutes.startPage;
  return AppRoutes.homePage;
}

void main() async {
  await _initSystem();
  FlutterError.onError = (details) {
    LogUtil.printError('Flutter error',
        error: details.exception, stackTrace: details.stack);
    if (details.exceptionAsString().contains('Render')) {
      // NoticeUtil.showBug(
      //   message:
      //       Env.debugMode ? details.exceptionAsString() : l10n.layoutErrorToast,
      // );
    } else {
      // NoticeUtil.showBug(
      //   message: Env.debugMode ? details.exceptionAsString() : l10n.errorToast,
      // );
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogUtil.printWTF('Error', error: error, stackTrace: stack);
    NoticeUtil.showBug(
      message: Env.debugMode ? error.toString() : l10n.errorToast,
    );
    return true;
  };
  runApp(GetMaterialApp.router(
    routeInformationParser: GetInformationParser.createInformationParser(
      initialRoute: _getInitialRoute(),
    ),
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
    backButtonDispatcher: GetRootBackButtonDispatcher(),
    builder: (context, child) {
      l10n = AppLocalizations.of(context)!;
      final mediaQuery = MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler:
                TextScaler.linear(PrefUtil.getValue<double>('fontScale')!)),
        child: FToastBuilder()(context, child!),
      );
      return Stack(
        children: [
          mediaQuery,
          const FrostedGlassOverlayComponent(),
          if (Env.debugMode)
            const Positioned(
              top: -15,
              right: -15,
              child: EnvBadge(envMode: '测试版'),
            ),
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MoveTitle(),
            ),
        ],
      );
    },
    theme: await ThemeUtil.buildTheme(Brightness.light),
    darkTheme: await ThemeUtil.buildTheme(Brightness.dark),
    locale: locale,
    themeMode: ThemeMode.values[PrefUtil.getValue<int>('themeMode')!],
    getPages: AppPages.routes,
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      FlutterQuillLocalizations.delegate
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  ));
}

class GetRootBackButtonDispatcher extends BackButtonDispatcher
    with WidgetsBindingObserver {
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
    return (await Get.rawRoute?.navigator?.maybePop()) ??
        invokeCallback(Future.value(false));
  }
}
