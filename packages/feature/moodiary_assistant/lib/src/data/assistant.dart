import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';

enum AssistantRole { user, assistant }

/// 流式事件类别：text=正文增量，reasoning=思考增量，tool=工具调用（[text] 为工具名），usage=token 用量。
enum AssistantStreamKind { text, reasoning, tool, usage }

/// 一次流式回复中的单个增量。思考模式下 [reasoning] 与 [text] 交织到来。
class AssistantStreamEvent {
  final AssistantStreamKind kind;
  final String text;
  final int inputTokens;
  final int outputTokens;

  const AssistantStreamEvent(
    this.kind,
    this.text, {
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  const AssistantStreamEvent.text(this.text)
    : kind = .text,
      inputTokens = 0,
      outputTokens = 0;

  const AssistantStreamEvent.reasoning(this.text)
    : kind = .reasoning,
      inputTokens = 0,
      outputTokens = 0;

  const AssistantStreamEvent.tool(this.text)
    : kind = .tool,
      inputTokens = 0,
      outputTokens = 0;

  const AssistantStreamEvent.usage(this.inputTokens, this.outputTokens)
    : kind = .usage,
      text = '';
}

typedef ToolPermissionRequester = Future<bool> Function(AssistantTool tool);

class AssistantMessage {
  final AssistantRole role;
  final String content;

  /// 随 user 消息发送的图片绝对路径。null 表示无图。
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

  /// 稳定 system prompt（缓存前缀）。仅含身份 / 护栏 / SOUL / 工具目录，每轮字节一致。
  final String systemPrompt;

  /// 易变前缀：拼到本轮外发消息上、不进 system（避免污染缓存前缀）。见 [buildVolatilePrompt]。
  final String volatilePrefix;

  final int maxTokens;

  final List<AssistantMessage> history;

  /// 是否开启思考（reasoning）模式。开启后按协议注入思考参数并回传思考增量。
  final bool thinking;

  /// 是否给模型挂载工具。模型不支持工具调用时应为 false（否则可能被供应商拒）。
  final bool tools;

  final ToolPermissionRequester? onToolPermission;

  const AssistantChatRequest({
    required this.type,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.systemPrompt,
    this.volatilePrefix = '',
    required this.maxTokens,
    required this.history,
    this.thinking = false,
    this.tools = true,
    this.onToolPermission,
  });
}

abstract class AssistantService {
  factory AssistantService.get() => getIt.get<AssistantService>();

  Stream<AssistantStreamEvent> chat(AssistantChatRequest request);
}
