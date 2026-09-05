import 'package:freezed_annotation/freezed_annotation.dart';

import 'place.dart';

part 'place_event.freezed.dart';

/// 常用地点的领域事件。语义同 [CategoryEvent]：[PlaceDeleted] 表示行已硬删（删除
/// 事实由 SyncTombstone 表承载），[fromSync] 标记云 pull 落库以免除回声推送。
@freezed
sealed class PlaceEvent with _$PlaceEvent {
  const factory PlaceEvent.upserted(
    Place place, {
    @Default(false) bool fromSync,
  }) = PlaceUpserted;

  const factory PlaceEvent.deleted(String id, {@Default(false) bool fromSync}) =
      PlaceDeleted;
}
