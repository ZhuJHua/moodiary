import 'package:freezed_annotation/freezed_annotation.dart';

import 'media_info.dart';

part 'media_info_event.freezed.dart';

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
