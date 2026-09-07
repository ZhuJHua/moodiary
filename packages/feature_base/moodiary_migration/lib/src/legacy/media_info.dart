// 字段顺序/形状即 isar 编码地址，改动会读坏旧库
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

import 'package:moodiary_models/moodiary_models.dart' show UtcDateTimeConverter;

part 'media_info.freezed.dart';
part 'media_info.g.dart';

String mediaTypeOfFileName(String fileName) {
  final i = fileName.indexOf('-');
  return i <= 0 ? 'other' : fileName.substring(0, i);
}

@freezed
@Collection(ignore: {'copyWith'})
abstract class MediaInfo with _$MediaInfo {
  const factory MediaInfo({
    @Id() required String fileName,
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
