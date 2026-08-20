import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'assistant_tool_call.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// 一条会话消息（持久化）。
@freezed
@Collection(ignore: {'copyWith'})
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    @Id() required String id,

    @Index() required String sessionId,

    /// `"user"` 或 `"assistant"`。
    required String role,

    required String content,

    required DateTime createdAt,

    /// assistant 回复的思考 / 推理过程（思考模式开启时才有）。null 表示非思考回复。
    String? reasoning,

    /// 思考耗时（毫秒）。null 表示无思考过程。
    int? thinkingMillis,

    /// 随消息发送的图片文件名（存于 image 目录，用 AppFiles.getRealPath 解析）。null 表示无图。
    String? imageName,

    /// 本轮（assistant 回复）消耗的输入 token 数。null 表示无用量数据。
    int? inputTokens,

    /// 本轮（assistant 回复）产生的输出 token 数。null 表示无用量数据。
    int? outputTokens,

    /// 生成本条 assistant 回复的模型 id。null = 旧数据或 user 消息。
    /// 相邻两条回复的 model 不同时，界面在其间合成「已切换到 X」提示。
    String? model,

    /// 本轮用到的工具调用，按发生顺序。
    ///
    /// **必须落库**：不落的话工具调用只在本轮可见，重开会话就没了 —— 而且模型
    /// 下一轮也看不到上一轮查到过什么（那正是它会重复调同一个工具的原因）。
    @Default(<AssistantToolCall>[]) List<AssistantToolCall> toolCalls,
  }) = _ChatMessage;

  factory ChatMessage.create({
    required String sessionId,
    required String role,
    required String content,
  }) {
    return ChatMessage(
      id: uuidV7(),
      sessionId: sessionId,
      role: role,
      content: content,
      createdAt: .timestamp(),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
