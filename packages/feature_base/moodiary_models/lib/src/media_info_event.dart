import 'package:freezed_annotation/freezed_annotation.dart';

import 'media_info.dart';

part 'media_info_event.freezed.dart';

/// [MediaInfoDeleted] 表示行已从表中移除（本地删除与同步 tombstone 皆是，删除
/// 事实由 SyncTombstone 表承载）；[MediaInfoUpserted] 为新建 / 改名 / 同步下载
/// 等 upsert。[fromSync] 语义同 CategoryEvent：云 pull 落库的变更不触发回声推送。
@freezed
sealed class MediaInfoEvent with _$MediaInfoEvent {
  const factory MediaInfoEvent.upserted(
    MediaInfo mediaInfo, {
    @Default(false) bool fromSync,
  }) = MediaInfoUpserted;

  const factory MediaInfoEvent.deleted(
    String fileName, {
    @Default(false) bool fromSync,
  }) = MediaInfoDeleted;
}
