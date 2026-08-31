// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_data/moodiary_data.dart' as _i691;
import 'package:moodiary_sync/src/application/auto_sync_watcher.dart' as _i1035;
import 'package:moodiary_sync/src/data/impl/backup_archive_impl.dart' as _i218;
import 'package:moodiary_sync/src/data/sync_logger.dart' as _i59;
import 'package:moodiary_sync/src/data/sync_registry.dart' as _i586;

class MoodiarySyncPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) async {
    await gh.singletonAsync<_i59.SyncLogger>(
      () => _i59.SyncLogger.create(),
      preResolve: true,
    );
    gh.singleton<_i586.RemoteSyncRegistry>(() => _i586.RemoteSyncRegistry());
    gh.lazySingleton<_i691.IBackupArchive>(
      () => const _i218.SyncBackupArchive(),
    );
    gh.lazySingleton<_i1035.AutoSyncWatcher>(
      () => _i1035.AutoSyncWatcher(
        gh<_i59.SyncLogger>(),
        gh<_i586.RemoteSyncRegistry>(),
      ),
    );
  }
}
