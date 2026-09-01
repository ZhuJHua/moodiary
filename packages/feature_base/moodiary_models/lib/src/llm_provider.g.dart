// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LlmProvider _$LlmProviderFromJson(Map<String, dynamic> json) => _LlmProvider(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  baseUrl: json['baseUrl'] as String,
  defaultModel: json['defaultModel'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  sortOrder: (json['sortOrder'] as num).toInt(),
  presetId: json['presetId'] as String? ?? '',
  models:
      (json['models'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  toolCall: json['toolCall'] as bool? ?? false,
  reasoning: json['reasoning'] as bool? ?? false,
  attachment: json['attachment'] as bool? ?? false,
);

Map<String, dynamic> _$LlmProviderToJson(_LlmProvider instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'baseUrl': instance.baseUrl,
      'defaultModel': instance.defaultModel,
      'createdAt': instance.createdAt.toIso8601String(),
      'sortOrder': instance.sortOrder,
      'presetId': instance.presetId,
      'models': instance.models,
      'toolCall': instance.toolCall,
      'reasoning': instance.reasoning,
      'attachment': instance.attachment,
    };
