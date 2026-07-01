import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/core/values/assistant.dart';

enum AssistantRole { user, assistant }

/// 工具调用前向用户征求授权的回调（由 UI 提供），返回是否放行**本次**调用。
/// 「仅一次 / 始终允许 / 拒绝」三态由 UI 内部消化，对服务层只表现为 true / false。
typedef ToolPermissionRequester = Future<bool> Function(AssistantTool tool);

class AssistantMessage {
  final AssistantRole role;
  final String content;

  const AssistantMessage(this.role, this.content);

  const AssistantMessage.user(this.content) : role = AssistantRole.user;

  const AssistantMessage.assistant(this.content)
    : role = AssistantRole.assistant;
}

/// 助手尚未配置可用 Provider / API Key 时抛出。
class AssistantNotConfiguredException implements Exception {
  const AssistantNotConfiguredException();

  @override
  String toString() => 'AssistantNotConfiguredException';
}

/// 一次对话请求的全部参数。「用哪个 Provider / 模型 / Key」由调用方解析后传入，
/// Service 不读全局 KV，便于按会话绑定不同 Provider。
class AssistantChatRequest {
  /// 决定底层走 OpenAI / Anthropic 协议。
  final AssistantProviderType type;

  /// 自定义 baseUrl，留空表示该协议官方端点。
  final String baseUrl;

  final String apiKey;

  final String model;

  /// 系统提示词（为空则不注入）。
  final String systemPrompt;

  /// 采样温度不传，由各 provider 自取默认。
  final int maxTokens;

  /// 完整的多轮上下文（不含系统提示词）。
  final List<AssistantMessage> history;

  /// 为 null 表示不做权限校验（直接放行）。
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

/// AI 助手服务。底层 agent 框架为 rig（Rust，经 flutter_rust_bridge）。
abstract class AssistantService {
  factory AssistantService.get() => getIt.get<AssistantService>();

  /// 流式发起一次对话，按文本增量逐段产出。
  /// [AssistantChatRequest.apiKey] 为空时抛出 [AssistantNotConfiguredException]。
  Stream<String> chat(AssistantChatRequest request);
}
