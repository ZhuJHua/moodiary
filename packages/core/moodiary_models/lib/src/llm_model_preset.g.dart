// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_model_preset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LlmModelPreset _$LlmModelPresetFromJson(Map<String, dynamic> json) =>
    _LlmModelPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      toolCall: json['toolCall'] as bool? ?? false,
      reasoning: json['reasoning'] as bool? ?? false,
      attachment: json['attachment'] as bool? ?? false,
      contextLimit: (json['contextLimit'] as num?)?.toInt(),
      outputLimit: (json['outputLimit'] as num?)?.toInt(),
      inputCost: json['inputCost'] as num?,
      outputCost: json['outputCost'] as num?,
      releaseDate: json['releaseDate'] as String?,
    );

Map<String, dynamic> _$LlmModelPresetToJson(_LlmModelPreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'toolCall': instance.toolCall,
      'reasoning': instance.reasoning,
      'attachment': instance.attachment,
      'contextLimit': instance.contextLimit,
      'outputLimit': instance.outputLimit,
      'inputCost': instance.inputCost,
      'outputCost': instance.outputCost,
      'releaseDate': instance.releaseDate,
    };
