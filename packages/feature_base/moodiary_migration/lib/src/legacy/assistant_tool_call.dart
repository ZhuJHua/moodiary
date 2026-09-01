// 2.8.0 之前的 Isar collection 定义（引擎搬迁的只读留底）。
// ⚠️ 逐字节冻结：schema 由「注册顺序 + 字段形状」决定（位置即地址），任何改动都会
// 让旧库被错误解读。新世界的模型在 moodiary_models，这里永不跟进。
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'assistant_tool_call.freezed.dart';
part 'assistant_tool_call.g.dart';

/// 一次工具调用的记录，作为内嵌对象跟着 [ChatMessage] 落库。
@freezed
@Embedded(ignore: {'copyWith'})
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
