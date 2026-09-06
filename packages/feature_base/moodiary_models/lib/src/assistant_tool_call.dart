import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant_tool_call.freezed.dart';
part 'assistant_tool_call.g.dart';

@freezed
abstract class AssistantToolCall with _$AssistantToolCall {
  const factory AssistantToolCall({
    required String callId,

    required String name,

    @Default('') String argsJson,

    @Default('') String result,

    @Default(false) bool done,
  }) = _AssistantToolCall;

  const AssistantToolCall._();

  factory AssistantToolCall.fromJson(Map<String, dynamic> json) =>
      _$AssistantToolCallFromJson(json);
}
