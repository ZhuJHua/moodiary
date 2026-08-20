/// Moodiary 一次性历史数据迁移：由组合根在 KV / Isar 就绪后调用 [VersionMigrator.run]，
/// 按上次运行的版本号逐档补跑升级钩子并写回当前版本号。
library;

export 'src/version_migrator.dart' show VersionMigrator;
