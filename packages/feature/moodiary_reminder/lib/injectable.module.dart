// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_platform/moodiary_platform.dart' as _i861;
import 'package:moodiary_reminder/src/application/reminder_service.dart'
    as _i78;
import 'package:moodiary_reminder/src/data/reminder_notifications.dart' as _i81;

class MoodiaryReminderPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i81.ReminderNotifications>(
      () => _i81.NativeReminderNotifications(),
    );
    gh.lazySingleton<_i78.ReminderService>(
      () => _i78.ReminderService(
        gh<_i81.ReminderNotifications>(),
        gh<_i861.NotificationPermission>(),
      ),
      dispose: (i) => i.dispose(),
    );
  }
}
