import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

@freezed
abstract class ChatSession with _$ChatSession {
  const factory ChatSession({
    required String id,

    @Default('') String title,

    required String providerId,

    required String model,

    required DateTime createdAt,

    required DateTime updatedAt,

    @Default('') String reasoningEffort,

    String? compactedSummary,

    String? compactedUpToMessageId,

    DateTime? compactedAt,

    int? compactedInputTokensAtTrigger,

    String? agentPresetId,

    String? personaSnapshot,

    List<String>? toolsSnapshot,
  }) = _ChatSession;

  factory ChatSession.create({
    required String providerId,
    required String model,
    String reasoningEffort = '',
    String? agentPresetId,
    String? personaSnapshot,
    List<String>? toolsSnapshot,
  }) {
    final now = DateTime.timestamp();
    return ChatSession(
      id: uuidV7(),
      providerId: providerId,
      model: model,
      createdAt: now,
      updatedAt: now,
      reasoningEffort: reasoningEffort,
      agentPresetId: agentPresetId,
      personaSnapshot: personaSnapshot,
      toolsSnapshot: toolsSnapshot,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
}
