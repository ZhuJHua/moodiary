library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/backup_sync_page.dart';
import 'src/presentation/lan_receive_page.dart';
import 'src/presentation/lan_send_page.dart';
import 'src/presentation/sync_console_page.dart';

export 'src/application/auto_sync_watcher.dart' show AutoSyncWatcher;
export 'src/application/sync_controller.dart'
    show
        SyncController,
        syncControllerProvider,
        SyncState,
        SyncIdle,
        SyncRunning,
        SyncPartial,
        SyncSuccess,
        SyncError;
export 'src/application/tombstone_gc.dart' show purgeExpiredTombstones;
export 'src/data/impl/backup_archive_impl.dart' show SyncBackupArchive;
export 'src/data/incremental_engine.dart' show purgeSyncMediaTemp;
export 'src/data/model/sync_provider.dart' show SyncProviderType;
export 'src/data/sync.dart' show IRemoteSyncBackend;
export 'src/data/sync_logger.dart' show SyncLogger;
export 'src/data/sync_provider_scope.dart'
    show activateSyncProvider, configuredCloudBackendIds;
export 'src/presentation/backup_sync_page.dart' show BackupSyncPage;
export 'src/presentation/sync_console_page.dart' show SyncConsolePage;
export 'src/presentation/widget/sync_status_button.dart' show SyncStatusButton;

List<RouteBase> syncRoutes() => [
  GoRoute(
    path: BackupSyncRoute.path,
    builder: (_, _) => const BackupSyncPage(),
  ),
  GoRoute(path: SyncLogRoute.path, builder: (_, _) => const SyncConsolePage()),
  GoRoute(path: LanSendRoute.path, builder: (_, _) => const LanSendPage()),
  GoRoute(
    path: LanReceiveRoute.path,
    builder: (_, _) => const LanReceivePage(),
  ),
];
