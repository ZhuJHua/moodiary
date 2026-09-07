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
