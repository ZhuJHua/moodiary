import 'package:freezed_annotation/freezed_annotation.dart';

import 'diary.dart';

part 'diary_event.freezed.dart';

/// 日记写操作的领域事件，列表视图据此对内存列表做原地增量更新。
/// 批量写每条各发一个事件。[DiaryUpdated] 含回收站移入 / 还原这类只改字段的操作；
/// [DiaryDeleted] 表示行已从表中移除（永久删除留同步墓碑，草稿丢弃不留）。
///
/// [fromSync] = 该变更由活跃云后端的 pull 落库（远端已持有），AutoSyncWatcher
/// 据此不标脏、不回声推送；归档导入 / 局域网接收仍为 false（需推送到云端）。
@freezed
sealed class DiaryEvent with _$DiaryEvent {
  const factory DiaryEvent.created(
    Diary diary, {
    @Default(false) bool fromSync,
  }) = DiaryCreated;

  const factory DiaryEvent.updated(
    Diary diary, {
    @Default(false) bool fromSync,
  }) = DiaryUpdated;

  const factory DiaryEvent.deleted(String id, {@Default(false) bool fromSync}) =
      DiaryDeleted;
}
