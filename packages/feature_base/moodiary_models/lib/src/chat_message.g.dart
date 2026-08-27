// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => _ChatMessage(
  id: json['id'] as String,
  sessionId: json['sessionId'] as String,
  role: json['role'] as String,
  content: json['content'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  reasoning: json['reasoning'] as String?,
  thinkingMillis: (json['thinkingMillis'] as num?)?.toInt(),
  imageName: json['imageName'] as String?,
  inputTokens: (json['inputTokens'] as num?)?.toInt(),
  outputTokens: (json['outputTokens'] as num?)?.toInt(),
  model: json['model'] as String?,
  toolCalls:
      (json['toolCalls'] as List<dynamic>?)
          ?.map((e) => AssistantToolCall.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AssistantToolCall>[],
);

Map<String, dynamic> _$ChatMessageToJson(_ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'role': instance.role,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
      'reasoning': instance.reasoning,
      'thinkingMillis': instance.thinkingMillis,
      'imageName': instance.imageName,
      'inputTokens': instance.inputTokens,
      'outputTokens': instance.outputTokens,
      'model': instance.model,
      'toolCalls': instance.toolCalls,
    };
