// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Category _$CategoryFromJson(Map<String, dynamic> json) => _Category(
  id: json['id'] as String,
  categoryName: json['categoryName'] as String,
  deleted: json['deleted'] as bool? ?? false,
  lastModified: const UtcDateTimeConverter().fromJson(
    json['lastModified'] as String,
  ),
  parentId: json['parentId'] as String?,
  color: (json['color'] as num?)?.toInt(),
);

Map<String, dynamic> _$CategoryToJson(_Category instance) => <String, dynamic>{
  'id': instance.id,
  'categoryName': instance.categoryName,
  'deleted': instance.deleted,
  'lastModified': const UtcDateTimeConverter().toJson(instance.lastModified),
  'parentId': instance.parentId,
  'color': instance.color,
};
