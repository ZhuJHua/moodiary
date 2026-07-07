import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_rust/moodiary_rust.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

/// 一次 AI 助手会话（持久化）。消息体存于 [ChatMessage]（按 sessionId 关联）。
///
/// 创建时绑定当时的 [providerId] / [model]，使切换激活 Provider 不影响历史会话语义。
/// API Key 不存这里。
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
