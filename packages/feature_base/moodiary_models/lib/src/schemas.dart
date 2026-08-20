import 'package:isar_plus/isar_plus.dart';

import 'agent_preset.dart';
import 'category.dart';
import 'chat_message.dart';
import 'chat_session.dart';
import 'diary.dart';
import 'diary_index_snapshot.dart';
import 'font.dart';
import 'link_posting.dart';
import 'llm_provider.dart';
import 'media_info.dart';
import 'memory_entry.dart';
import 'reindex_queue.dart';
import 'search_posting.dart';
import 'search_stats.dart';
import 'sync_tombstone.dart';

/// 本应用全部 Isar collection 的**注册顺序真源**。
///
/// isar_plus 按「打开时列表的位置下标」寻址 collection（没有按名解析），而
/// moodiary_migration 与 AppFiles 会用**子集列表**重挂载同一个原生实例——子集必须是
/// 本列表的**严格前缀**才能对齐下标。因此：
///
/// **新 schema 只能追加到末尾，永远不许重排或从中间插入。**
///
/// 插入中间会让已有数据被写进错误的表，且不报错。闸门在
/// `test/schema_order_test.dart`（按恒等断言，不按名字——`IsarGeneratedSchema`
/// 没有公开的名字成员，`.schema` 是 @protected）。
final List<IsarGeneratedSchema> moodiarySchemas = [
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
  AgentPresetSchema,
];

/// 重挂载用的**前缀切片**。它们必须逐项等于 [moodiarySchemas] 的开头，否则下标对不齐。
///
/// 集中放在这里而不是散在各调用点，是因为「前缀」这个性质只有对着真源才检查得了；
/// 写成字面量的话，往 [moodiarySchemas] 中间插一条不会让任何东西变红。
/// 闸门在 `test/schema_order_test.dart`。

/// 只读日记与分类：孤儿媒体清理。
final List<IsarGeneratedSchema> diaryAndCategorySchemas = [
  DiarySchema,
  CategorySchema,
];

/// 旧版数据迁移：日记、分类、字体。
final List<IsarGeneratedSchema> legacyMigrationSchemas = [
  DiarySchema,
  CategorySchema,
  FontSchema,
];
