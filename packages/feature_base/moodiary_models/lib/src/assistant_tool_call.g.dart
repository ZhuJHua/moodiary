// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_tool_call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AssistantToolCall _$AssistantToolCallFromJson(Map<String, dynamic> json) =>
    _AssistantToolCall(
      callId: json['callId'] as String,
      name: json['name'] as String,
      argsJson: json['argsJson'] as String? ?? '',
      result: json['result'] as String? ?? '',
      done: json['done'] as bool? ?? false,
    );

Map<String, dynamic> _$AssistantToolCallToJson(_AssistantToolCall instance) =>
    <String, dynamic>{
      'callId': instance.callId,
      'name': instance.name,
      'argsJson': instance.argsJson,
      'result': instance.result,
      'done': instance.done,
    };
