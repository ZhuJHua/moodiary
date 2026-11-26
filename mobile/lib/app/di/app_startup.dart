import 'dart:async' show unawaited;
import 'dart:io';

import 'package:async/async.dart' show Result;
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
    _configureSystemUi();

    // Wave 0: start independent initializers concurrently; Result.capture
    // attaches error handlers immediately so early failures are never uncaught.
    final glass = Result.capture(MGlassApp.initialize());
    final fastImage = Result.capture(FastImageRuntime.init());
    final secureKv = Result.capture(FlutterSecureStorageKVStorage.create());
    await bootstrapPlatform(ref);

    // Wave 1: platform dirs exist — run DB, sync logger, and storage/probe
    // concurrently.
    final coordinator = ref.read(startupMigrationCoordinatorProvider);
    final (legacyState, _, _) = await (
      () async {
        final store = await Result.release(secureKv);
        SecureKVStore.install(store);
        final kv = await MmkvKVStorage.create(
          rootDir: path.join(
            PlatformService.get().applicationSupportPath,
            'mmkv',
          ),
          secureKv: store,
        );
        KVStore.install(kv);
        final (_, _, state) = await (
          AppLockPin.load(),
          _initLocaleSafely(),
          coordinator.probeLegacy(),
        ).wait;
        return state;
      }(),
      ref.watch(moodiaryDatabaseAsyncProvider.future),
      ref.watch(syncLoggerAsyncProvider.future),
    ).wait;

    if (legacyState == LegacyDatabaseState.abandoning) {
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

    // Wave 2: theme, data startup (with syncLogger ready), and Wave 0 tasks.
    final canStartData = ref.read(migrationGateProvider).canStartData;
    await (
      _initTheme(ref),
      canStartData
          ? coordinator.startData(() => resumeDataStartup(ref))
          : Future<void>.value(),
      Result.release(glass),
      Result.release(fastImage),
    ).wait;
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

void _configureSystemUi() {
  if (Platform.isAndroid) {
    unawaited(_enableHighRefreshRate());
  }
  unawaited(SystemChrome.setEnabledSystemUIMode(.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  applyDeviceOrientationLock();
}

Future<void> _enableHighRefreshRate() async {
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (error, stack) {
    logger.e('high refresh rate unavailable', error: error, stackTrace: stack);
  }
}
