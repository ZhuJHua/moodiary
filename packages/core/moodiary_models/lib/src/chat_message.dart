import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_rust/moodiary_rust.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// 一条会话消息（持久化）。仅存 user / assistant 的文本轮次；单次回复内部的工具调用
/// 中间态不落库（由 rig 在内存内完成多轮）。
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
      createdAt: DateTime.timestamp(),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
