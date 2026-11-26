import 'dart:async' show unawaited;
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

typedef _Outcome<T> = ({T? value, Object? error, StackTrace? stack});

Future<_Outcome<T>> _capture<T>(Future<T> future) => future.then<_Outcome<T>>(
  (value) => (value: value, error: null, stack: null),
  onError: (Object error, StackTrace stack) =>
      (value: null, error: error, stack: stack),
);

void _rethrowIfError(_Outcome<Object?> outcome) {
  if (outcome.error != null) {
    Error.throwWithStackTrace(outcome.error!, outcome.stack!);
  }
}

T _unwrap<T>(_Outcome<T> outcome) {
  _rethrowIfError(outcome);
  return outcome.value as T;
}

@Riverpod(keepAlive: true)
Future<void> appStartup(Ref ref) async {
  try {
    _configureSystemUi();

    // Wave 0: start independent native/platform initializers concurrently,
    // attaching error handlers immediately so early failures never escape.
    final glassOutcome = _capture(MGlassApp.initialize());
    final fastImageOutcome = _capture(FastImageRuntime.init());
    final secureKvOutcome = _capture(FlutterSecureStorageKVStorage.create());
    await bootstrapPlatform(ref);

    // Wave 1: once platform dirs exist, run DB open, sync logger init, and
    // MMKV -> (AppLock + Locale + legacy probe) concurrently.
    final coordinator = ref.read(startupMigrationCoordinatorProvider);
    final storageOutcome = _capture(() async {
      final secureKv = _unwrap(await secureKvOutcome);
      SecureKVStore.install(secureKv);
      final kv = await MmkvKVStorage.create(
        rootDir: path.join(
          PlatformService.get().applicationSupportPath,
          'mmkv',
        ),
        secureKv: secureKv,
      );
      KVStore.install(kv);
      final results = await Future.wait<Object?>([
        AppLockPin.load(),
        _initLocaleSafely(),
        coordinator.probeLegacy(),
      ]);
      return results[2]! as LegacyDatabaseState;
    }());
    final dbOutcome = _capture(ref.watch(moodiaryDatabaseAsyncProvider.future));
    final syncLoggerOutcome = _capture(
      ref.watch(syncLoggerAsyncProvider.future),
    );

    final wave1 = await Future.wait([
      storageOutcome,
      dbOutcome,
      syncLoggerOutcome,
    ]);
    final legacyState = _unwrap(wave1[0] as _Outcome<LegacyDatabaseState>);
    _rethrowIfError(wave1[1]);
    _rethrowIfError(wave1[2]);

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

    // Wave 2: theme build, data startup (with syncLogger already ready), and
    // any still-in-flight Wave 0 native initializers.
    final canStartData = ref.read(migrationGateProvider).canStartData;
    final wave2 = await Future.wait([
      _capture(_initTheme(ref)),
      if (canStartData)
        _capture(coordinator.startData(() => resumeDataStartup(ref))),
      glassOutcome,
      fastImageOutcome,
    ]);
    for (final outcome in wave2) {
      _rethrowIfError(outcome);
    }
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
