/// Moodiary 一次性历史数据迁移：由组合根在 KV / Isar 就绪后调用 [MergeUtil.runVersionMigration]，
/// 按上次运行的版本号逐档补跑升级钩子并写回当前版本号。
library;

export 'src/merge.dart' show MergeUtil;
