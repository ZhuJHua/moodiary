// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_preset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentPreset _$AgentPresetFromJson(Map<String, dynamic> json) => _AgentPreset(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  persona: json['persona'] as String,
  tools: (json['tools'] as List<dynamic>?)?.map((e) => e as String).toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$AgentPresetToJson(_AgentPreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'persona': instance.persona,
      'tools': instance.tools,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
