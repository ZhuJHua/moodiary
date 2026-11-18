// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Tag _$TagFromJson(Map<String, dynamic> json) => _Tag(
  id: json['id'] as String,
  name: json['name'] as String,
  deleted: json['deleted'] as bool? ?? false,
  lastModified: const UtcDateTimeConverter().fromJson(
    json['lastModified'] as String,
  ),
);

Map<String, dynamic> _$TagToJson(_Tag instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'deleted': instance.deleted,
  'lastModified': const UtcDateTimeConverter().toJson(instance.lastModified),
};
