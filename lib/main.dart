import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/values/language.dart';
import 'package:moodiary/components/env_badge/badge.dart';
import 'package:moodiary/components/frosted_glass_overlay/frosted_glass_overlay_view.dart';
import 'package:moodiary/components/window_buttons/window_buttons.dart';
import 'package:moodiary/config/env.dart';
import 'package:moodiary/l10n/app_localizations.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/hive.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_pages.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/src/rust/frb_generated.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/theme_util.dart';
import 'package:moodiary/utils/webdav_util.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

Future<void> _initSystem() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefUtil.initPref();
  await IsarUtil.initIsar();
  await HiveUtil().init();
  unawaited(RustLib.init());
  unawaited(_platFormOption());
  WebDavUtil().initWebDav();
  VideoPlayerMediaKit.ensureInitialized(windows: true);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await ThemeUtil().buildTheme();
}

Future<Locale> _findLanguage() async {
  Language language = Language.values.firstWhere(
    (e) => e.languageCode == PrefUtil.getValue<String>('language')!,
    orElse: () => Language.system,
  );
  if (language == Language.system) {
    final systemLocale = await findSystemLocale();
    final systemLanguageCode =
        systemLocale.contains('_')
            ? systemLocale.split('_').first
            : systemLocale;
    language = Language.values.firstWhere(
      (e) => e.languageCode == systemLanguageCode,
      orElse: () => Language.english,
    );
  }
  final locale = Locale(language.languageCode);
  Intl.defaultLocale = locale.languageCode;
  return locale;
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
  final locale = await _findLanguage();
  FlutterError.onError = (details) {
    logger.e(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.f('Error', error: error, stackTrace: stack);
    return true;
  };

  runApp(Moodiary(locale: locale));
}

class Moodiary extends StatelessWidget {
  final Locale locale;

  const Moodiary({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    final themeData = ThemeUtil().getThemeData();
    return GetMaterialApp.router(
      routeInformationParser: GetInformationParser.createInformationParser(
        initialRoute: _getInitialRoute(),
      ),
      onGenerateTitle: (context) => context.l10n.appName,
      backButtonDispatcher: GetRootBackButtonDispatcher(),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: (context, child) {
        final smartDialog = FlutterSmartDialog.init();
        final mediaQuery = MediaQuery(
          data: context.mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              PrefUtil.getValue<double>('fontScale')!,
            ),
          ),
          child: child!,
        );
        final home = Stack(
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
              const Positioned(top: 0, left: 0, right: 0, child: MoveTitle()),
          ],
        );
        return smartDialog(context, home);
      },
      theme: themeData.$1,
      darkTheme: themeData.$2,
      locale: locale,
      themeMode: ThemeMode.values[PrefUtil.getValue<int>('themeMode')!],
      getPages: AppPages.routes,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
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
