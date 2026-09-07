import 'package:freezed_annotation/freezed_annotation.dart';

import 'utc_date_time_converter.dart';

part 'media_info.freezed.dart';
part 'media_info.g.dart';

String mediaTypeOfFileName(String fileName) {
  final i = fileName.indexOf('-');
  return i <= 0 ? 'other' : fileName.substring(0, i);
}

@freezed
abstract class MediaInfo with _$MediaInfo {
  const factory MediaInfo({
    required String fileName,
    String? name,
    int? durationMs,
    @UtcDateTimeConverter() required DateTime lastModified,
  }) = _MediaInfo;

  const MediaInfo._();

  factory MediaInfo.create({
    required String fileName,
    String? name,
    int? durationMs,
  }) {
    return MediaInfo(
      fileName: fileName,
      name: name,
      durationMs: durationMs,
      lastModified: .timestamp(),
    );
  }

  String get mediaType => mediaTypeOfFileName(fileName);

  factory MediaInfo.fromJson(Map<String, dynamic> json) =>
      _$MediaInfoFromJson(json);
}
