// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MediaInfo _$MediaInfoFromJson(Map<String, dynamic> json) => _MediaInfo(
  fileName: json['fileName'] as String,
  name: json['name'] as String?,
  durationMs: (json['durationMs'] as num?)?.toInt(),
  lastModified: const UtcDateTimeConverter().fromJson(
    json['lastModified'] as String,
  ),
);

Map<String, dynamic> _$MediaInfoToJson(
  _MediaInfo instance,
) => <String, dynamic>{
  'fileName': instance.fileName,
  'name': instance.name,
  'durationMs': instance.durationMs,
  'lastModified': const UtcDateTimeConverter().toJson(instance.lastModified),
};
