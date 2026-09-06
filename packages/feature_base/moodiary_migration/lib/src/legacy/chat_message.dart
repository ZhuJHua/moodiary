// 字段顺序/形状即 isar 编码地址，改动会读坏旧库
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'assistant_tool_call.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    @Id() required String id,

    @Index() required String sessionId,

    required String role,

    required String content,

    required DateTime createdAt,

    String? reasoning,

    int? thinkingMillis,

    String? imageName,

    int? inputTokens,

    int? outputTokens,

    String? model,

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
