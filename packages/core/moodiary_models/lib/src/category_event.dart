import 'package:freezed_annotation/freezed_annotation.dart';
import 'category.dart';

part 'category_event.freezed.dart';

/// [CategoryDeleted] 表示行已从表中移除（本地删除与同步 tombstone 皆是，删除事实
/// 由 SyncTombstone 表承载）；[CategoryUpserted] 为新建 / 改名 / 同步下载等 upsert。
///
/// [fromSync] 语义同 DiaryEvent：云 pull 落库的变更不触发回声推送。
@freezed
sealed class CategoryEvent with _$CategoryEvent {
  const factory CategoryEvent.upserted(
    Category category, {
    @Default(false) bool fromSync,
  }) = CategoryUpserted;

  const factory CategoryEvent.deleted(
    String id, {
    @Default(false) bool fromSync,
  }) = CategoryDeleted;
}
