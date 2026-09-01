// 2.8.0 之前的 Isar collection 定义（引擎搬迁的只读留底）。
// ⚠️ 逐字节冻结：schema 由「注册顺序 + 字段形状」决定（位置即地址），任何改动都会
// 让旧库被错误解读。新世界的模型在 moodiary_models，这里永不跟进。
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

final List<IsarGeneratedSchema> diaryAndCategorySchemas = [
  DiarySchema,
  CategorySchema,
];

final List<IsarGeneratedSchema> legacyMigrationSchemas = [
  DiarySchema,
  CategorySchema,
  FontSchema,
];
