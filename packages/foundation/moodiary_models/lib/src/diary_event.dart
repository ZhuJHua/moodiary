import 'package:freezed_annotation/freezed_annotation.dart';
import 'diary.dart';

part 'diary_event.freezed.dart';

/// 日记写操作的领域事件，列表视图据此对内存列表做原地增量更新。
/// 批量写每条各发一个事件。[DiaryUpdated] 含软删除 / 还原这类只改字段的操作。
@freezed
sealed class DiaryEvent with _$DiaryEvent {
  const factory DiaryEvent.created(Diary diary) = DiaryCreated;

  const factory DiaryEvent.updated(Diary diary) = DiaryUpdated;

  const factory DiaryEvent.deleted(int isarId) = DiaryDeleted;
}
