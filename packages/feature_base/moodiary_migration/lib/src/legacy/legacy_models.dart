/// 2.8.0 之前的 Isar 数据模型全家福（只读留底），供引擎搬迁与历史版本迁移钩子
/// 打开旧 `default.isar` 用。消费侧一律 `import ... as legacy` 前缀引用，
/// 避免与 moodiary_models 的新模型同名冲突。
library;

export 'agent_preset.dart';
export 'assistant_tool_call.dart';
export 'category.dart';
export 'chat_message.dart';
export 'chat_session.dart';
export 'diary.dart';
export 'diary_index_snapshot.dart';
export 'font.dart';
export 'link_posting.dart';
export 'llm_provider.dart';
export 'media_info.dart';
export 'memory_entry.dart';
export 'reindex_queue.dart';
export 'schemas.dart';
export 'search_posting.dart';
export 'search_stats.dart';
export 'sync_tombstone.dart';
