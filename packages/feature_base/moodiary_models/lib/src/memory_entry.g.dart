// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MemoryEntry _$MemoryEntryFromJson(Map<String, dynamic> json) => _MemoryEntry(
  id: json['id'] as String,
  category: json['category'] as String,
  text: json['text'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MemoryEntryToJson(_MemoryEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'text': instance.text,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
