import 'dart:async';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

/// 路径 + 业务目录 + 日志：一切存储的前置，必须先于容器装配（Isar 要求 database
/// 目录存在；MMKV 的 rootDir 取 applicationSupportPath）。
///
/// 只做这一件事：RustLib.init / ThemeManager / 同步后端装载都含业务或 UI 决策，
/// 由 main.dart 显式编排。「SecureKV 必须先于 KV 就位」这条不再写在这里 ——
/// 它已是 `MmkvKVStorage.create(ISecureKVStorage)` 的类型边，由容器的 preResolve
/// 保证次序。
Future<void> bootstrapPlatform() async {
  await PlatformService.get().init();
  await AppFiles.initCreateDir();
  AppLogger.configure(logFilePath: AppFiles.getErrorLogPath());
}

/// 启动期维护：三条互不依赖、失败不该阻断启动的清理，发出即不等。
/// 调用点必须在 Rust 桥就绪之后 —— drainReindexQueue 立刻要用分词器。
void runStartupMaintenance() {
  // 不能静默失败：抛错时受影响的日记会带着空索引出队，从此搜不到。
  unawaited(
    DiaryRepository.get().drainReindexQueue().catchError((
      Object e,
      StackTrace s,
    ) {
      logger.e('drain reindex queue failed', error: e, stackTrace: s);
      return 0;
    }),
  );
  // 同步墓碑保留窗 GC（默认 90 天）：零后端用户的墓碑因此有界，不无限累积。
  unawaited(purgeExpiredTombstones());
  // 上次进程被杀时残留的同步临时密文（全尺寸，没人来收）。
  unawaited(purgeSyncMediaTemp());
}

/// 重置所有应用数据，恢复到「全新安装」状态（Isar 集合 / KV / SecureKV / 媒体 / 缓存）。
/// 返回后内存仍残留 Riverpod / get_it 单例状态，调用方必须立即接管界面（终态页），
/// 不得继续使用既有 provider / 单例；iOS 上退出进程不可依赖（SystemNavigator.pop
/// 是空操作），由用户手动重启后从干净存储初始化。
Future<void> resetAllData() async {
  // 先清空数据库集合（保持 Isar 句柄有效），再并发清空其余存储与文件。
  await IsarDatabase.get().clear();
  IKVStorage.get().clear();
  await Future.wait([
    ISecureKVStorage.get().clear(),
    // 2.8.0 的搬迁自己会删旧仓库，但重置可能发生在搬迁完成之前 —— 那时旧仓库还在，
    // 不清就会被下次启动的搬迁原样搬回来，重置成了摆设。
    LegacyPrefsKVSource.clearStore(),
    AppFiles.resetUserMediaDirs(),
    AppFiles.clearCache(),
    // 2.8.0 升级留下的两处日记明文档案，重置必须一并清掉：
    // 强制迁移为每篇旧日记写的 sidecar 原文备份（路径归 owner，不手抄字面量），
    // 与跨引擎迁移前的整库快照。
    EditorMigrationService.purgeBackups(),
    AppFiles.deleteFile(
      AppFiles.getRealPath('database', 'default.isar.v273bak'),
    ),
  ]);
}
