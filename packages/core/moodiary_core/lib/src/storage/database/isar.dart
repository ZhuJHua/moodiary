import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/src/files/app_files.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// Isar 纯基建封装：只负责 schema 注册、打开与清空数据库；
/// 领域查询一律走 moodiary_data 的仓储。
final class IsarDatabase {
  static final _instance = IsarDatabase._();

  IsarDatabase._();

  factory IsarDatabase.get() => _instance;

  late final Isar _isar;

  Isar get isar => _isar;

  // isar_plus 按「打开时列表的位置下标」寻址 collection（无按名解析），而
  // moodiary_migration / app_files 会用子集列表重挂载同一原生实例——子集必须是
  // 本列表的严格前缀才能对齐下标。因此**新 schema 只能追加到末尾**，插入中间会
  // 让迁移把数据写进错误的表。
  static final _schemas = [
    DiarySchema,
    CategorySchema,
    FontSchema,
    SearchPostingSchema,
    SearchStatsSchema,
    LinkPostingSchema,
    DiaryIndexSnapshotSchema,
    ReindexQueueSchema,
    SyncTombstoneSchema,
    LlmProviderSchema,
    ChatSessionSchema,
    ChatMessageSchema,
    MemoryEntrySchema,
    MediaInfoSchema,
  ];

  Future<void> init() async {
    _isar = await Isar.openAsync(
      schemas: _schemas,
      directory: AppFiles.getRealPath('database', ''),
      // 默认 128MiB 是 mdbx 硬上限（写满直接抛错）。此值只是虚拟映射上限，不预分配
      // 磁盘；全平台均为 64 位目标，放大无代价。4GiB ≈ 十万篇量级的 2000 字日记。
      maxSizeMiB: 4096,
    );
  }

  Future<void> clear() async {
    await _isar.writeAsync((isar) {
      isar.clear();
    });
  }
}
