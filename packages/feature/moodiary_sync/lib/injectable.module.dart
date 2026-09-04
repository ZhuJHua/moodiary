// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_data/moodiary_data.dart' as _i691;
import 'package:moodiary_sync/src/application/auto_sync_watcher.dart' as _i1035;
import 'package:moodiary_sync/src/data/impl/backup_archive_impl.dart' as _i218;
import 'package:moodiary_sync/src/data/impl/s3_sync.dart' as _i454;
import 'package:moodiary_sync/src/data/impl/webdav_sync.dart' as _i351;
import 'package:moodiary_sync/src/data/sync.dart' as _i472;
import 'package:moodiary_sync/src/data/sync_cancellation.dart' as _i870;
import 'package:moodiary_sync/src/data/sync_logger.dart' as _i59;

class MoodiarySyncPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) async {
    gh.singleton<_i870.SyncCancellation>(() => _i870.SyncCancellation());
    await gh.singletonAsync<_i59.SyncLogger>(
      () => _i59.SyncLogger.create(),
      preResolve: true,
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i472.IRemoteSyncBackend>(
      () => _i351.WebDavSyncBackend(),
      instanceName: 'webdav',
    );
    gh.lazySingleton<_i472.IRemoteSyncBackend>(
      () => _i454.S3SyncBackend(),
      instanceName: 's3',
    );
    gh.lazySingleton<_i691.IBackupArchive>(
      () => const _i218.SyncBackupArchive(),
    );
    gh.lazySingleton<_i1035.AutoSyncWatcher>(
      () => _i1035.AutoSyncWatcher(
        gh<_i59.SyncLogger>(),
        gh<_i691.DiaryRepository>(),
        gh<_i691.CategoryRepository>(),
        gh<_i691.MediaInfoRepository>(),
        gh<_i691.SyncDirtyTracker>(),
        gh<_i691.OpenDiaryRegistry>(),
      ),
      dispose: (i) => i.dispose(),
    );
  }
}
