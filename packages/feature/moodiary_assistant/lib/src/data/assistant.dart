import 'package:moodiary_models/moodiary_models.dart';

enum AssistantRole { user, assistant }

enum AssistantReasoningMode {
  off('off'),

  effort('effort'),

  budget('budget');

  final String id;

  const AssistantReasoningMode(this.id);
}

// 新 Claude 只认 effort，老 Claude 只认 budget_tokens，选错会 400
class AssistantReasoning {
  final AssistantReasoningMode mode;

  final String effort;

  final int budgetTokens;

  const AssistantReasoning.off() : mode = .off, effort = '', budgetTokens = 0;

  const AssistantReasoning.effort(this.effort)
    : mode = .effort,
      budgetTokens = 0;

  const AssistantReasoning.budget(this.budgetTokens)
    : mode = .budget,
      effort = '';
}

enum AssistantStreamKind {
  text,
  reasoning,
  tool,
  toolStarted,
  toolFinished,
  usage,
}

class AssistantStreamEvent {
  final AssistantStreamKind kind;
  final String text;
  final int inputTokens;
  final int outputTokens;

  final int cachedInputTokens;

  final int cacheWriteTokens;

  final String callId;

  final String argsJson;

  const AssistantStreamEvent(
    this.kind,
    this.text, {
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedInputTokens = 0,
    this.cacheWriteTokens = 0,
    this.callId = '',
    this.argsJson = '',
  });

  const AssistantStreamEvent.text(this.text)
    : kind = .text,
      inputTokens = 0,
      outputTokens = 0,
      cachedInputTokens = 0,
      cacheWriteTokens = 0,
      callId = '',
      argsJson = '';

  const AssistantStreamEvent.reasoning(this.text)
    : kind = .reasoning,
      inputTokens = 0,
      outputTokens = 0,
      cachedInputTokens = 0,
      cacheWriteTokens = 0,
      callId = '',
      argsJson = '';

  const AssistantStreamEvent.tool(this.text)
    : kind = .tool,
      inputTokens = 0,
      outputTokens = 0,
      cachedInputTokens = 0,
      cacheWriteTokens = 0,
      callId = '',
      argsJson = '';

  const AssistantStreamEvent.toolStarted({
    required this.callId,
    required this.text,
    required this.argsJson,
  }) : kind = .toolStarted,
       inputTokens = 0,
       outputTokens = 0,
       cachedInputTokens = 0,
       cacheWriteTokens = 0;

  const AssistantStreamEvent.toolFinished({
    required this.callId,
    required this.text,
  }) : kind = .toolFinished,
       argsJson = '',
       inputTokens = 0,
       outputTokens = 0,
       cachedInputTokens = 0,
       cacheWriteTokens = 0;

  const AssistantStreamEvent.usage(
    this.inputTokens,
    this.outputTokens, {
    this.cachedInputTokens = 0,
    this.cacheWriteTokens = 0,
  }) : kind = .usage,
       text = '',
       callId = '',
       argsJson = '';
}

class AssistantMessage {
  final AssistantRole role;
  final String content;

  final String? imagePath;

  const AssistantMessage(this.role, this.content, {this.imagePath});

  const AssistantMessage.user(this.content, {this.imagePath}) : role = .user;

  const AssistantMessage.assistant(this.content)
    : role = .assistant,
      imagePath = null;
}

class AssistantNotConfiguredException implements Exception {
  const AssistantNotConfiguredException();

  @override
  String toString() => 'AssistantNotConfiguredException';
}

class AssistantChatRequest {
  final AssistantProviderType type;

  final String baseUrl;

  final String apiKey;

  final String model;

  final String systemPrompt;

  final String volatilePrefix;

  final int maxTokens;

  final List<AssistantMessage> history;

  final AssistantReasoning reasoning;

  final bool tools;

  final List<String>? allowedTools;

  const AssistantChatRequest({
    required this.type,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.systemPrompt,
    this.volatilePrefix = '',
    required this.maxTokens,
    required this.history,
    this.reasoning = const AssistantReasoning.off(),
    this.tools = true,
    this.allowedTools,
  });
}

abstract class AssistantService {
  Stream<AssistantStreamEvent> chat(AssistantChatRequest request);
}
