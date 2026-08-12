import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/app/di/service_di.dart';
import 'package:moodiary/app/router/router.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show FlutterSmartDialog;
import 'package:mui/mui.dart';

Future<Locale> _initSystem() async {
  final rustInit = RustLib.init();
  await injectBasicService();
  // 版本迁移钩子：在基础存储就位后、主题/服务初始化前运行（旧版内联在 KV.init）。
  // 用 try/catch 包裹：迁移抛异常时只记日志、不阻断启动——否则 appVersion 不推进，
  // 每次启动都在同一步崩，陷入永久崩溃循环把用户锁在数据外。步骤幂等，下次启动重试。
  try {
    await VersionMigrator.run();
  } catch (e, s) {
    logger.e('version migration failed', error: e, stackTrace: s);
  }
  unawaited(_platFormOption());
  final localeFuture = _findLanguage();
  // registerService 会立刻打到 Rust，必须先等桥就绪。
  await rustInit;
  await Future.wait([
    FontRepository.get().getActiveFont().then(
      (font) => ThemeManager().buildTheme(customFont: font),
    ),
    registerService(),
    localeFuture,
  ]);

  SystemChrome.setEnabledSystemUIMode(.edgeToEdge);
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
  if (language == .system) {
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
        // 字号与 MuiTheme 都套在 SmartDialog **外面**：init() 会自建 Overlay，把传入的
        // child 放进 entry[0]，而 toast / loading 是与之平级的兄弟 entry —— 包在里面
        // 的话那些浮层既吃不到字号缩放，也读不到 mui 配色（toast.dart 的 builder 要取色）。
        final brightness = switch (settings.themeMode) {
          .light => Brightness.light,
          .dark => Brightness.dark,
          .system => MediaQuery.platformBrightnessOf(context),
        };
        // 字号档已经解析进主题（见 MuiTextSize），所以这里把缩放**钉死为 1**：
        // 再乘一次会与主题里的尺寸叠加，局部 `textScaler:` 覆盖也会失去参照。
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: .noScaling),
          child: MuiAnimatedTheme(
            data: brightness == .light
                ? settings.lightMuiTheme
                : settings.darkMuiTheme,
            child: FlutterSmartDialog.init()(context, child!),
          ),
        );
      },
      theme: settings.lightTheme,
      darkTheme: settings.darkTheme,
      locale: settings.locale,
      themeMode: settings.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
