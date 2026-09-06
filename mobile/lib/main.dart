import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fast_image/fast_image.dart';
import 'package:fast_tokenizer/fast_tokenizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_export/moodiary_export.dart' show showDiaryShareSheet;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_mobile/app/boot_failure_page.dart';
import 'package:moodiary_mobile/app/di/bootstrap.dart';
import 'package:moodiary_mobile/app/di/di.dart';
import 'package:moodiary_mobile/app/licenses.dart';
import 'package:moodiary_mobile/app/lifecycle/app_lock_observer.dart';
import 'package:moodiary_mobile/app/locale.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Future<void> _initSystem() async {
  await FastImageRuntime.init();
  await FastTokenizer.ensureInitialized();

  await bootstrapPlatform();
  await configureDependencies();
  await AppLockPin.load();

  try {
    await VersionMigrator.run();
  } catch (e, s) {
    logger.e('version migration failed', error: e, stackTrace: s);
  }

  unawaited(_platFormOption());

  final themeFuture = () async {
    try {
      final font = await getIt<FontRepository>().getActiveFont();
      await getIt<ThemeManager>().buildTheme(customFont: font?.themeDescriptor);
    } catch (e, s) {
      logger.e(
        'theme init failed, fallback to default',
        error: e,
        stackTrace: s,
      );
      try {
        await getIt<ThemeManager>().buildTheme();
      } catch (_) {
        // 再失败就让 lightTheme / darkTheme getter 自己回落到 buildMuiTheme()
      }
    }
  }();

  final localeFuture = () async {
    try {
      await setupPluralResolvers();
      await applyStoredLanguage();
    } catch (e, s) {
      logger.e('locale init failed, staying on base', error: e, stackTrace: s);
    }
  }();
  final migrationGateFuture = () async {
    try {
      await EngineMigrationService.refresh();
      await EditorMigrationService.refreshRequiresMigration();
    } catch (e, s) {
      logger.e('migration gate probe failed', error: e, stackTrace: s);
    }
  }();
  final syncBackendFuture = () async {
    try {
      await activateSyncProvider();
    } catch (e, s) {
      logger.e('sync provider activation failed', error: e, stackTrace: s);
    }
  }();

  await syncBackendFuture;
  if (getIt<MoodiaryDatabase>().upgradedFrom != null) {
    MoodiaryKVs.syncPendingLocal.set(true);
  }
  getIt<AutoSyncWatcher>().start();
  DiaryShare.register(showDiaryShareSheet);
  runStartupMaintenance();
  await Future.wait([themeFuture, localeFuture, migrationGateFuture]);

  SystemChrome.setEnabledSystemUIMode(.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  applyDeviceOrientationLock();
}

Future<void> _platFormOption() async {
  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
}

@visibleForTesting
String resolveInitialLocation() {
  if (AppLockPin.enabled.value) return LockRoute.path;
  return DiaryHomeRoute.path;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  registerThirdPartyLicenses();

  try {
    await _initSystem();
    buildRouter(initialLocation: resolveInitialLocation());
  } catch (e, s) {
    logger.f('bootstrap failed', error: e, stackTrace: s);
    runApp(BootFailurePage(error: e, stackTrace: s));
    return;
  }

  runApp(
    TranslationProvider(
      child: ProviderScope(retry: (_, _) => null, child: const Moodiary()),
    ),
  );
}

class Moodiary extends ConsumerWidget {
  const Moodiary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.common.appName,
      routerConfig: router,
      builder: (context, child) {
        final brightness = switch (settings.themeMode) {
          .light => Brightness.light,
          .dark => Brightness.dark,
          .system => MediaQuery.platformBrightnessOf(context),
        };
        return AnnotatedRegion(
          value: systemOverlayStyleOf(brightness),
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(
            child: FrostedGlassOverlayComponent(
              child: AppLockObserver(
                child: FlutterSmartDialog.init()(context, child!),
              ),
            ),
          ),
        );
      },
      theme: settings.lightTheme,
      darkTheme: settings.darkTheme,
      locale: TranslationProvider.of(context).flutterLocale,
      themeMode: settings.themeMode,
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        GlobalMuiLocalizations.delegate,
      ],
      supportedLocales: AppLocaleUtils.supportedLocales,
    );
  }
}
