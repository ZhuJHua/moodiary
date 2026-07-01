import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary/feature/setting/application/app_settings_controller.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary/merge/merge.dart';
import 'package:moodiary/app/router/router.dart';
import 'package:moodiary/app/di/service_di.dart';

Future<Locale> _initSystem() async {
  final rustInit = RustLib.init();
  await injectBasicService();
  // 版本迁移钩子：在基础存储就位后、主题/服务初始化前运行（旧版内联在 KV.init）。
  await MergeUtil.runVersionMigration();
  unawaited(_platFormOption());
  final localeFuture = _findLanguage();
  await Future.wait([
    ThemeUtil().buildTheme(),
    registerService(),
    localeFuture,
    rustInit,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  applyDeviceOrientationLock();
  return localeFuture;
}

Future<Locale> _findLanguage() async {
  Language language = Language.values.firstWhere(
    (e) => e.languageCode == MoodiaryKVs.language.get()!,
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
  final locale = Locale(language.languageCode);
  Intl.defaultLocale = locale.languageCode;
  return locale;
}

Future<void> _platFormOption() async {
  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
}

String _resolveInitialLocation() {
  if (MoodiaryKVs.lock.get() == true) return '/lock';
  if (MoodiaryKVs.firstStart.get() == true) return '/start';
  return '/';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = await _initSystem();
  buildRouter(initialLocation: _resolveInitialLocation());

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
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

  runApp(
    ProviderScope(
      overrides: [appInitialLocaleProvider.overrideWithValue(locale)],
      child: const Moodiary(),
    ),
  );
}

class Moodiary extends ConsumerWidget {
  const Moodiary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      routerConfig: router,
      builder: (context, child) {
        return FlutterSmartDialog.init()(
          context,
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(settings.fontScale),
            ),
            child: child!,
          ),
        );
      },
      theme: settings.lightTheme,
      darkTheme: settings.darkTheme,
      locale: settings.locale,
      themeMode: settings.themeMode,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
