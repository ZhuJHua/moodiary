import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';

enum AssistantRole { user, assistant }

typedef ToolPermissionRequester = Future<bool> Function(AssistantTool tool);

class AssistantMessage {
  final AssistantRole role;
  final String content;

  const AssistantMessage(this.role, this.content);

  const AssistantMessage.user(this.content) : role = AssistantRole.user;

  const AssistantMessage.assistant(this.content)
    : role = AssistantRole.assistant;
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

  final int maxTokens;

  final List<AssistantMessage> history;

  final ToolPermissionRequester? onToolPermission;

  const AssistantChatRequest({
    required this.type,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.systemPrompt,
    required this.maxTokens,
    required this.history,
    this.onToolPermission,
  });
}

abstract class AssistantService {
  factory AssistantService.get() => getIt.get<AssistantService>();

  Stream<String> chat(AssistantChatRequest request);
}
