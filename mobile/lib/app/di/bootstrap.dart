import 'dart:async';

import 'package:fast_image/fast_image.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/moodiary_migration.dart'
    show EngineMigrationService;
import 'package:moodiary_ml/moodiary_ml.dart' show EmbeddingModelManager;
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

/// 路径 + 业务目录 + 日志：一切存储的前置，必须先于容器装配（Isar 要求 database
/// 目录存在；MMKV 的 rootDir 取 applicationSupportPath）。
///
/// 只做这一件事：原生库装载 / ThemeManager / 同步后端装载都含业务或 UI 决策，
/// 由 main.dart 显式编排。「SecureKV 必须先于 KV 就位」这条不再写在这里 ——
/// 它已是 `MmkvKVStorage.create(ISecureKVStorage)` 的类型边，由容器的 preResolve
/// 保证次序。
Future<void> bootstrapPlatform() async {
  await PlatformService.get().init();
  await AppFiles.initCreateDir();
  // 图片管线只认路径与日志回调，不认识 AppFiles。
  FastImageRuntime.configure(
    imageDir: AppFiles.imageDir,
    thumbDir: AppFiles.imageThumbDir,
    log: logger.d,
  );
  AppLogger.configure(logFilePath: AppFiles.getErrorLogPath());
}

/// 启动期维护：互不依赖、失败不该阻断启动的清理，发出即不等。
void runStartupMaintenance() {
  // 同步墓碑保留窗 GC（默认 90 天）：零后端用户的墓碑因此有界，不无限累积。
  unawaited(purgeExpiredTombstones());
  // 上次进程被杀时残留的同步临时密文（全尺寸，没人来收）。
  unawaited(purgeSyncMediaTemp());
  // 语义索引启动兜底排空 + 事件驱动补嵌（模型未激活时均为 no-op）。
  unawaited(getIt<EmbedIndexService>().drain());
  getIt<EmbedQueueWatcher>().start();
}

/// 重置所有应用数据，恢复到「全新安装」状态（SQLite / KV / SecureKV / 媒体 / 缓存）。
/// 返回后内存仍残留 Riverpod / get_it 单例状态，调用方必须立即接管界面（终态页），
/// 不得继续使用既有 provider / 单例；iOS 上退出进程不可依赖（SystemNavigator.pop
/// 是空操作），由用户手动重启后从干净存储初始化。
///
/// 每一步各自 best-effort：本函数只在启动失败的兜底页可达，容器可能只装配了一半
/// （DB 是最后一个 preResolve，`configureDependencies` 抛出时它根本没注册）。逐步
/// `maybeGet`、各自 try/catch、最后汇总抛出——一步失败不能让后面的清理跟着跳过，
/// 但也不能静默：明文 sidecar 没删掉时重置必须报失败，用户可能正要转手设备。
Future<void> resetAllData() async {
  final failed = <String>[];
  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e, s) {
      logger.e('resetAllData: $name failed', error: e, stackTrace: s);
      failed.add(name);
    }
  }

  // 先清空数据库（保持句柄有效）；句柄不在或清空失败时直接删库文件（含 wal/shm），
  // 下次启动从空库建表。
  var dbCleared = false;
  final db = getIt.maybeGet<MoodiaryDatabase>();
  if (db != null) {
    await step('database.clearAll', () async {
      await db.clearAll();
      dbCleared = true;
    });
  }
  if (!dbCleared) {
    await step(
      'database.deleteFiles',
      () => Future.wait([
        for (final suffix in const ['', '-wal', '-shm', '-journal'])
          AppFiles.deleteFile(
            AppFiles.getRealPath('database', 'moodiary.db$suffix'),
          ),
      ]),
    );
  }
  await step('kv.clear', () async => getIt.maybeGet<IKVStorage>()?.clear());
  await Future.wait([
    step('secureKv.clear', () async {
      await getIt.maybeGet<ISecureKVStorage>()?.clear();
    }),
    // 2.8.0 的搬迁自己会删旧仓库，但重置可能发生在搬迁完成之前 —— 那时旧仓库还在，
    // 不清就会被下次启动的搬迁原样搬回来，重置成了摆设。
    step('legacyPrefs.clear', LegacyPrefsKVSource.clearStore),
    step('media.reset', AppFiles.resetUserMediaDirs),
    step('cache.clear', AppFiles.clearCache),
    // 2.8.0 升级留下的两处日记明文档案，重置必须一并清掉：
    // 强制迁移为每篇旧日记写的 sidecar 原文备份（路径归 owner 的常量，不手抄
    // 字面量；**不走吞错的 purgeBackups**），与跨引擎迁移前的整库快照。
    step(
      'editorBackups.delete',
      () => AppFiles.deleteDir(EditorMigrationService.backupDirPath),
    ),
    // 本地嵌入模型文件（KV 的激活状态由上面的 clear 一并清）。
    step(
      'models.delete',
      () => AppFiles.deleteDir(EmbeddingModelManager.modelsDirPath),
    ),
    step(
      'isarBackup.delete',
      () => AppFiles.deleteFile(
        AppFiles.getRealPath('database', 'default.isar.v273bak'),
      ),
    ),
    // 旧 Isar 主库（尚未搬迁时）与搬迁后的留底快照，一并清。
    step(
      'isar.delete',
      () =>
          AppFiles.deleteFile(AppFiles.getRealPath('database', 'default.isar')),
    ),
    step(
      'legacyBackup.delete',
      () => AppFiles.deleteFile(
        AppFiles.getRealPath(
          'database',
          EngineMigrationService.legacyBackupFileName,
        ),
      ),
    ),
  ]);
  if (failed.isNotEmpty) {
    throw StateError('resetAllData: ${failed.join(', ')} failed');
  }
}
