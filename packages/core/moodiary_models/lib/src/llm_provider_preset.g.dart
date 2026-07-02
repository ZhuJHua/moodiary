// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_provider_preset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LlmProviderPreset _$LlmProviderPresetFromJson(Map<String, dynamic> json) =>
    _LlmProviderPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: $enumDecode(_$AssistantProviderTypeEnumMap, json['protocol']),
      baseUrl: json['baseUrl'] as String,
      models: (json['models'] as List<dynamic>)
          .map((e) => LlmModelPreset.fromJson(e as Map<String, dynamic>))
          .toList(),
      docUrl: json['docUrl'] as String?,
      env:
          (json['env'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      logoUrl: json['logoUrl'] as String?,
    );

Map<String, dynamic> _$LlmProviderPresetToJson(_LlmProviderPreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'protocol': _$AssistantProviderTypeEnumMap[instance.protocol]!,
      'baseUrl': instance.baseUrl,
      'models': instance.models,
      'docUrl': instance.docUrl,
      'env': instance.env,
      'logoUrl': instance.logoUrl,
    };

const _$AssistantProviderTypeEnumMap = {
  AssistantProviderType.openai: 'openai',
  AssistantProviderType.anthropic: 'anthropic',
};
