import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';

enum AssistantRole { user, assistant }

/// 流式回调事件类别：正文文本增量、思考 / 推理增量，或一次工具调用（[text] 为工具名）。
enum AssistantStreamKind { text, reasoning, tool }

/// 一次流式回复中的单个增量。思考模式下 [reasoning] 与 [text] 交织到来。
class AssistantStreamEvent {
  final AssistantStreamKind kind;
  final String text;

  const AssistantStreamEvent(this.kind, this.text);

  const AssistantStreamEvent.text(this.text) : kind = AssistantStreamKind.text;

  const AssistantStreamEvent.reasoning(this.text)
    : kind = AssistantStreamKind.reasoning;

  const AssistantStreamEvent.tool(this.text) : kind = AssistantStreamKind.tool;
}

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

  /// 是否开启思考（reasoning）模式。开启后按协议注入思考参数并回传思考增量。
  final bool thinking;

  final ToolPermissionRequester? onToolPermission;

  const AssistantChatRequest({
    required this.type,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.systemPrompt,
    required this.maxTokens,
    required this.history,
    this.thinking = false,
    this.onToolPermission,
  });
}

abstract class AssistantService {
  factory AssistantService.get() => getIt.get<AssistantService>();

  Stream<AssistantStreamEvent> chat(AssistantChatRequest request);
}
