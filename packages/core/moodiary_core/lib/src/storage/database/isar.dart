import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/src/utils/file_util.dart';

/// Isar 纯基建封装：只负责 schema 注册、打开与清空数据库；
/// 领域查询一律走 moodiary_data 的仓储。
final class IsarDatabase {
  static final _instance = IsarDatabase._();

  IsarDatabase._();

  factory IsarDatabase.get() => _instance;

  late final Isar _isar;

  Isar get isar => _isar;

  static final _schemas = [
    DiarySchema,
    CategorySchema,
    FontSchema,
    DiarySearchIndexSchema,
    DiaryLinkIndexSchema,
    ReindexQueueSchema,
    LlmProviderSchema,
    ChatSessionSchema,
    ChatMessageSchema,
  ];

  Future<void> init() async {
    _isar = await Isar.openAsync(
      schemas: _schemas,
      directory: FileUtil.getRealPath('database', ''),
    );
  }

  Future<void> clear() async {
    await _isar.writeAsync((isar) {
      isar.clear();
    });
  }
}
