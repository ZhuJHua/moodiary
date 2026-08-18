// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_model_preset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LlmModelPreset _$LlmModelPresetFromJson(Map<String, dynamic> json) =>
    _LlmModelPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: $enumDecode(_$AssistantProviderTypeEnumMap, json['protocol']),
      baseUrl: json['baseUrl'] as String,
      description: json['description'] as String? ?? '',
      toolCall: json['toolCall'] as bool? ?? false,
      reasoning: json['reasoning'] as bool? ?? false,
      structuredOutput: json['structuredOutput'] as bool?,
      temperature: json['temperature'] as bool?,
      reasoningOptions: (json['reasoningOptions'] as List<dynamic>?)
          ?.map((e) => ReasoningControl.fromJson(e as Map<String, dynamic>))
          .toList(),
      interleavedField: json['interleavedField'] as String?,
      contextLimit: (json['contextLimit'] as num?)?.toInt(),
      inputLimit: (json['inputLimit'] as num?)?.toInt(),
      outputLimit: (json['outputLimit'] as num?)?.toInt(),
      inputModalities:
          (json['inputModalities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      inputCost: json['inputCost'] as num?,
      outputCost: json['outputCost'] as num?,
      reasoningCost: json['reasoningCost'] as num?,
      cacheReadCost: json['cacheReadCost'] as num?,
      cacheWriteCost: json['cacheWriteCost'] as num?,
      releaseDate: json['releaseDate'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$LlmModelPresetToJson(_LlmModelPreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'protocol': _$AssistantProviderTypeEnumMap[instance.protocol]!,
      'baseUrl': instance.baseUrl,
      'description': instance.description,
      'toolCall': instance.toolCall,
      'reasoning': instance.reasoning,
      'structuredOutput': instance.structuredOutput,
      'temperature': instance.temperature,
      'reasoningOptions': instance.reasoningOptions,
      'interleavedField': instance.interleavedField,
      'contextLimit': instance.contextLimit,
      'inputLimit': instance.inputLimit,
      'outputLimit': instance.outputLimit,
      'inputModalities': instance.inputModalities,
      'inputCost': instance.inputCost,
      'outputCost': instance.outputCost,
      'reasoningCost': instance.reasoningCost,
      'cacheReadCost': instance.cacheReadCost,
      'cacheWriteCost': instance.cacheWriteCost,
      'releaseDate': instance.releaseDate,
      'status': instance.status,
    };

const _$AssistantProviderTypeEnumMap = {
  AssistantProviderType.openaiCompletions: 'openaiCompletions',
  AssistantProviderType.openaiResponses: 'openaiResponses',
  AssistantProviderType.anthropicMessages: 'anthropicMessages',
};
