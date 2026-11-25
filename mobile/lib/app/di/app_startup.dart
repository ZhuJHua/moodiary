import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_mobile/app/di/bootstrap.dart';
import 'package:moodiary_mobile/app/locale.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_startup.g.dart';

@Riverpod(keepAlive: true)
Future<void> appStartup(Ref ref) async {
  try {
    await MGlassApp.initialize();
    await FastImageRuntime.init();
    await bootstrapPlatform(ref);
    final secureKv = await FlutterSecureStorageKVStorage.create();
    SecureKVStore.install(secureKv);
    final kv = await MmkvKVStorage.create(
      rootDir: path.join(PlatformService.get().applicationSupportPath, 'mmkv'),
      secureKv: secureKv,
    );
    KVStore.install(kv);
    await AppLockPin.load();
    await Future.wait([
      ref.watch(moodiaryDatabaseAsyncProvider.future),
      ref.watch(syncLoggerAsyncProvider.future),
    ]);
    final coordinator = ref.read(startupMigrationCoordinatorProvider);
    if (await coordinator.probeLegacy() == LegacyDatabaseState.abandoning) {
      try {
        await coordinator.abandonLegacy(
          diaries: ref.read(diaryRepositoryProvider),
          fonts: ref.read(fontRepositoryProvider),
        );
      } catch (error, stack) {
        logger.e(
          'legacy quarantine interrupted',
          error: error,
          stackTrace: stack,
        );
      }
    }
    final canStartData = ref.read(migrationGateProvider).canStartData;
    await _initLocaleSafely();
    await Future.wait<void>([
      _initTheme(ref),
      if (canStartData) coordinator.startData(() => resumeDataStartup(ref)),
    ]);
    await _configureSystemUi();
    ref.read(appRouterProvider);
  } catch (error, stack) {
    logger.f('bootstrap failed', error: error, stackTrace: stack);
    rethrow;
  }
}

Future<void> _initLocaleSafely() async {
  try {
    await setupPluralResolvers();
    await applyStoredLanguage();
  } catch (error, stack) {
    logger.e(
      'locale init failed, staying on base',
      error: error,
      stackTrace: stack,
    );
  }
}

Future<void> _initTheme(Ref ref) async {
  final settings = ref.read(appSettingsControllerProvider.notifier);
  final mode = ThemeMode.values[MoodiaryKVs.themeMode.get()!];
  final builder = ref.read(themeBuilderProvider);
  try {
    final font = await ref.read(fontRepositoryProvider).getActiveFont();
    settings.initFromBuilt(
      await builder.buildTheme(customFont: font?.themeDescriptor),
      themeMode: mode,
    );
  } catch (error, stack) {
    logger.e(
      'theme init failed, using default',
      error: error,
      stackTrace: stack,
    );
    try {
      settings.initFromBuilt(await builder.buildTheme(), themeMode: mode);
    } catch (error, stack) {
      logger.e('default theme build failed', error: error, stackTrace: stack);
    }
  }
}

Future<void> _configureSystemUi() async {
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (error, stack) {
      logger.e(
        'high refresh rate unavailable',
        error: error,
        stackTrace: stack,
      );
    }
  }
  await SystemChrome.setEnabledSystemUIMode(.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  applyDeviceOrientationLock();
}
