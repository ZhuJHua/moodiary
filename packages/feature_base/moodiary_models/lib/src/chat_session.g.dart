// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatSession _$ChatSessionFromJson(Map<String, dynamic> json) => _ChatSession(
  id: json['id'] as String,
  title: json['title'] as String? ?? '',
  providerId: json['providerId'] as String,
  model: json['model'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  reasoningEffort: json['reasoningEffort'] as String? ?? '',
  compactedSummary: json['compactedSummary'] as String?,
  compactedUpToMessageId: json['compactedUpToMessageId'] as String?,
  compactedAt: json['compactedAt'] == null
      ? null
      : DateTime.parse(json['compactedAt'] as String),
  compactedInputTokensAtTrigger: (json['compactedInputTokensAtTrigger'] as num?)
      ?.toInt(),
  agentPresetId: json['agentPresetId'] as String?,
  personaSnapshot: json['personaSnapshot'] as String?,
  toolsSnapshot: (json['toolsSnapshot'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ChatSessionToJson(_ChatSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'providerId': instance.providerId,
      'model': instance.model,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'reasoningEffort': instance.reasoningEffort,
      'compactedSummary': instance.compactedSummary,
      'compactedUpToMessageId': instance.compactedUpToMessageId,
      'compactedAt': instance.compactedAt?.toIso8601String(),
      'compactedInputTokensAtTrigger': instance.compactedInputTokensAtTrigger,
      'agentPresetId': instance.agentPresetId,
      'personaSnapshot': instance.personaSnapshot,
      'toolsSnapshot': instance.toolsSnapshot,
    };
