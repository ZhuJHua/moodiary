// 字段顺序/形状即 isar 编码地址，改动会读坏旧库
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'assistant_tool_call.freezed.dart';
part 'assistant_tool_call.g.dart';

@freezed
@Embedded(ignore: {'copyWith'})
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
