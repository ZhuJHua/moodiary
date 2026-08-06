/// Moodiary 同步包：一个自洽的同步 feature。
///
/// `src/data` + `src/application` = 无 widget 的引擎与 providers（增量引擎、编解码/密钥、
/// WebDAV/S3/本地后端 + [registerRemoteSync]、[AutoSyncWatcher]、[SyncLogger]、
/// [syncControllerProvider] 等）—— 桌面端可脱离移动 UI 直接复用其状态；
/// `src/presentation` = 备份/日志/密钥等移动 UI + [SyncStatusButton] + [syncRoutes]。
library;

export 'src/application/auto_sync_watcher.dart' show AutoSyncWatcher;
export 'src/application/sync_controller.dart'
    show
        SyncController,
        syncControllerProvider,
        SyncState,
        SyncIdle,
        SyncRunning,
        SyncSuccess,
        SyncError;
export 'src/application/tombstone_gc.dart' show purgeExpiredTombstones;
export 'src/data/impl/backup_archive_impl.dart' show SyncBackupArchive;
export 'src/data/sync_logger.dart' show SyncLogger;
export 'src/data/sync_registry.dart' show registerRemoteSync;
export 'src/presentation/backup_sync_page.dart' show BackupSyncPage;
export 'src/presentation/sync_log_page.dart' show SyncLogPage;
export 'src/presentation/widget/sync_status_button.dart' show SyncStatusButton;
export 'src/presentation/widget/sync_status_sheet.dart'
    show showSyncStatusSheet;
export 'src/routes.dart' show syncRoutes;
