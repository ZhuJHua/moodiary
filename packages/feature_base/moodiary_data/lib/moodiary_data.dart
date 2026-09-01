/// Moodiary 数据层（infra）：SQLite（drift）数据库 + 仓储 + DiaryContent，
/// 以及跨 feature 共享的进程级瞬态状态（feature 之间不能互引，data 是它们的最低公共祖先）。
///
/// 准入线：**只被单个 feature 读、又不被包内复用的东西不进 data**——那只是
/// 「放这儿方便」。assistant 专属的四个仓储已因此搬回 moodiary_assistant。
library;

export 'src/backup_archive.dart';
export 'src/category_controller.dart';
export 'src/category_repository.dart';
export 'src/dashboard_controller.dart';
export 'src/db/database.dart';
export 'src/db/db_codec.dart';
export 'src/diary_content.dart';
export 'src/diary_controller.dart';
export 'src/diary_derive.dart';
export 'src/diary_repository.dart';
export 'src/embed_chunker.dart';
export 'src/embed_index_service.dart';
export 'src/font_repository.dart';
export 'src/loadmore.dart';
export 'src/media_info_controller.dart';
export 'src/media_info_repository.dart';
export 'src/open_diary_registry.dart';
export 'src/repository_providers.dart';
export 'src/secret_controller.dart';
export 'src/sync_pending.dart';
export 'src/tombstone_repository.dart';
