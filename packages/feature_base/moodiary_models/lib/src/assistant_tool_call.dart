import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant_tool_call.freezed.dart';
part 'assistant_tool_call.g.dart';

/// 一次工具调用的记录，作为内嵌对象跟着 [ChatMessage] 落库。
@freezed
abstract class AssistantToolCall with _$AssistantToolCall {
  const factory AssistantToolCall({
    /// rig 生成的关联 id，用来把「开始」与「结果」两个事件配成一对。
    required String callId,

    /// 工具 id（与 `AssistantTool.id` 一致）。
    required String name,

    /// 模型传的入参，原样 JSON。
    @Default('') String argsJson,

    /// 工具返回的文本。[done] 为 false 时无意义。
    @Default('') String result,

    /// 是否已拿到结果。流式期间先是 false（转圈），拿到结果才置真。
    @Default(false) bool done,
  }) = _AssistantToolCall;

  const AssistantToolCall._();

  factory AssistantToolCall.fromJson(Map<String, dynamic> json) =>
      _$AssistantToolCallFromJson(json);
}
