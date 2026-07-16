import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_rust/moodiary_rust.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

/// 一次 AI 助手会话（持久化），消息体存于 [ChatMessage]。创建时绑定当时的 [providerId]/[model]，
/// 切换激活 Provider 不影响历史会话语义；API Key 不存这里。
@freezed
@Collection(ignore: {'copyWith'})
abstract class ChatSession with _$ChatSession {
  const factory ChatSession({
    @Id() required String id,

    required String title,

    required String providerId,

    required String model,

    required DateTime createdAt,

    /// 最后一条消息的时间，列表按此倒序。
    required DateTime updatedAt,

    /// 本会话是否开启思考模式（新建时取自全局默认 assistantThinkingEnabled）。
    @Default(false) bool thinking,

    /// 上下文压缩：滚动摘要（覆盖至 [compactedUpToMessageId] 为止）；null 表示未压缩，整段历史逐字发送。
    String? compactedSummary,

    /// 压缩水位：摘要覆盖到的最后一条消息 id；发送历史时此消息及之前内容改用摘要，Isar 消息永不删除，故可逆。
    String? compactedUpToMessageId,

    /// 最近一次压缩的时刻。
    DateTime? compactedAt,

    /// 触发压缩时该轮上报的输入 token 数（用于提示 / 调试）。
    int? compactedInputTokensAtTrigger,
  }) = _ChatSession;

  factory ChatSession.create({
    required String title,
    required String providerId,
    required String model,
    bool thinking = false,
  }) {
    final now = DateTime.timestamp();
    return ChatSession(
      id: uuidV7(),
      title: title,
      providerId: providerId,
      model: model,
      createdAt: now,
      updatedAt: now,
      thinking: thinking,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
}
