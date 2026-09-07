import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart' show uuidV7;

// 磁盘上区分两种角色的字面量，别换成枚举 .name 或改大小写
const String kRoleUser = 'user';
const String kRoleAssistant = 'assistant';

sealed class AssistantChatItem {
  const AssistantChatItem();

  String get id;
}

final class AssistantTurn extends AssistantChatItem {
  @override
  final String id;

  final bool fromUser;
  final String text;
  final DateTime createdAt;

  final String imageName;

  final String reasoning;
  final int thinkingMillis;

  final int inputTokens;
  final int outputTokens;

  final List<AssistantToolCall> toolCalls;

  final String model;

  final bool streaming;

  final bool thinkingActive;

  const AssistantTurn({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.createdAt,
    this.imageName = '',
    this.reasoning = '',
    this.thinkingMillis = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.toolCalls = const [],
    this.model = '',
    this.streaming = false,
    this.thinkingActive = false,
  });

  factory AssistantTurn.user(
    String text, {
    String imageName = '',
    DateTime? createdAt,
  }) => AssistantTurn(
    id: uuidV7(),
    fromUser: true,
    text: text,
    imageName: imageName,
    createdAt: createdAt ?? DateTime.timestamp(),
  );

  factory AssistantTurn.assistant(
    String text, {
    bool streaming = false,
    DateTime? createdAt,
    String model = '',
  }) => AssistantTurn(
    id: uuidV7(),
    fromUser: false,
    text: text,
    streaming: streaming,
    createdAt: createdAt ?? DateTime.timestamp(),
    model: model,
  );

  factory AssistantTurn.fromRecord(ChatMessage m) => AssistantTurn(
    id: m.id,
    fromUser: m.role == kRoleUser,
    text: m.content,
    createdAt: m.createdAt,
    imageName: m.imageName ?? '',
    reasoning: m.reasoning ?? '',
    thinkingMillis: m.thinkingMillis ?? 0,
    inputTokens: m.inputTokens ?? 0,
    outputTokens: m.outputTokens ?? 0,
    toolCalls: m.toolCalls,
    model: m.model ?? '',
  );

  ChatMessage toRecord(String sessionId) => ChatMessage(
    id: id,
    sessionId: sessionId,
    role: fromUser ? kRoleUser : kRoleAssistant,
    content: text,
    createdAt: createdAt,
    reasoning: reasoning.isEmpty ? null : reasoning,
    thinkingMillis: thinkingMillis == 0 ? null : thinkingMillis,
    imageName: imageName.isEmpty ? null : imageName,
    inputTokens: inputTokens == 0 ? null : inputTokens,
    outputTokens: outputTokens == 0 ? null : outputTokens,
    toolCalls: toolCalls,
    model: model.isEmpty ? null : model,
  );

  bool get isEmpty => text.isEmpty && imageName.isEmpty && toolCalls.isEmpty;

  AssistantTurn get settled =>
      copyWith(streaming: false, thinkingActive: false);

  AssistantTurn copyWith({
    String? text,
    String? reasoning,
    int? thinkingMillis,
    int? inputTokens,
    int? outputTokens,
    List<AssistantToolCall>? toolCalls,
    bool? streaming,
    bool? thinkingActive,
  }) => AssistantTurn(
    id: id,
    fromUser: fromUser,
    text: text ?? this.text,
    createdAt: createdAt,
    imageName: imageName,
    model: model,
    reasoning: reasoning ?? this.reasoning,
    thinkingMillis: thinkingMillis ?? this.thinkingMillis,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    toolCalls: toolCalls ?? this.toolCalls,
    streaming: streaming ?? this.streaming,
    thinkingActive: thinkingActive ?? this.thinkingActive,
  );
}

final class AssistantCompactionNotice extends AssistantChatItem {
  final String watermarkId;

  const AssistantCompactionNotice(this.watermarkId);

  @override
  String get id => 'compaction-$watermarkId';
}

final class AssistantModelSwitchNotice extends AssistantChatItem {
  final String beforeId;

  final String model;

  const AssistantModelSwitchNotice({
    required this.beforeId,
    required this.model,
  });

  @override
  String get id => 'model-switch-$beforeId';
}

List<AssistantModelSwitchNotice> modelSwitchNoticesFor(
  Iterable<AssistantChatItem> items,
) {
  final notices = <AssistantModelSwitchNotice>[];
  var lastModel = '';
  for (final item in items) {
    if (item is! AssistantTurn || item.fromUser) continue;
    if (item.model.isEmpty) continue;
    if (lastModel.isNotEmpty && item.model != lastModel) {
      notices.add(
        AssistantModelSwitchNotice(beforeId: item.id, model: item.model),
      );
    }
    lastModel = item.model;
  }
  return notices;
}
