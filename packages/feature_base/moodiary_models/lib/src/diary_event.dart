import 'package:freezed_annotation/freezed_annotation.dart';

import 'diary.dart';

part 'diary_event.freezed.dart';

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
