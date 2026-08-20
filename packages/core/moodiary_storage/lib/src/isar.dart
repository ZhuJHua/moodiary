import 'package:isar_plus/isar_plus.dart';

/// Isar 纯基建封装：只负责 schema 注册、打开与清空数据库；
/// 领域查询一律走 moodiary_data 的仓储。
final class IsarDatabase {
  static final _instance = IsarDatabase._();

  IsarDatabase._();

  factory IsarDatabase.get() => _instance;

  late final Isar _isar;

  Isar get isar => _isar;

  /// [schemas] 的**位置就是 collection 地址**（isar_plus 没有按名解析），所以真源是
  /// `moodiary_models` 的 `moodiarySchemas`，由 app 组合根注入——core 不认识领域类型。
  /// 那份列表只许在末尾追加，改动会静默错位已有数据；闸门在 models 的
  /// `schema_order_test.dart`。
  /// [directory] 由 app 组合根给出（`AppFiles.getRealPath('database', '')`）。
  /// 存储层不认识文件布局——那是 moodiary_files 的事，而它在本包之上。
  Future<void> init({
    required List<IsarGeneratedSchema> schemas,
    required String directory,
  }) async {
    _isar = await Isar.openAsync(
      schemas: schemas,
      directory: directory,
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
