import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

enum AssistantRole { user, assistant }

/// 思考控制的下发方式。与 Rust 的 `reasoning_mode` 一一对应。
enum AssistantReasoningMode {
  /// 不注入任何思考参数。
  off('off'),

  /// 下发档位（Anthropic 走 output_config.effort，OpenAI 走 reasoning_effort）。
  effort('effort'),

  /// 下发 token 预算（Anthropic 老模型的 thinking.budget_tokens）。
  budget('budget');

  final String id;

  const AssistantReasoningMode(this.id);
}

/// 一轮请求的思考设置。选哪种由模型在 models.dev 上声明的 `reasoning_options` 决定，
/// 不由我们猜 —— 新 Claude 只认 effort，老 Claude 只认 budget_tokens，猜错就是 400。
class AssistantReasoning {
  final AssistantReasoningMode mode;

  /// [AssistantReasoningMode.effort] 时的档位值。
  final String effort;

  /// [AssistantReasoningMode.budget] 时的思考 token 预算。
  final int budgetTokens;

  const AssistantReasoning.off() : mode = .off, effort = '', budgetTokens = 0;

  const AssistantReasoning.effort(this.effort)
    : mode = .effort,
      budgetTokens = 0;

  const AssistantReasoning.budget(this.budgetTokens)
    : mode = .budget,
      effort = '';
}

/// 流式事件类别。
///
/// - `text` / `reasoning`：正文与思考增量
/// - `tool`：模型开始调工具（[AssistantStreamEvent.text] 是工具名）。只作
///   「思考阶段结束」的信号，展示走下面两个
/// - `toolStarted` / `toolFinished`：一次工具调用的开始与结果，靠 `callId` 配对
/// - `usage`：token 用量
enum AssistantStreamKind {
  text,
  reasoning,
  tool,
  toolStarted,
  toolFinished,
  usage,
}

/// 一次流式回复中的单个增量。思考模式下 [reasoning] 与 [text] 交织到来。
class AssistantStreamEvent {
  final AssistantStreamKind kind;
  final String text;
  final int inputTokens;
  final int outputTokens;

  /// 命中供应商缓存的输入 token（Anthropic 的 cache_read）。供应商不报时为 0。
  final int cachedInputTokens;

  /// 写入供应商缓存的输入 token（Anthropic 的 cache_creation）。
  final int cacheWriteTokens;

  /// 工具事件的关联 id，把 toolStarted 与 toolFinished 配成一对。
  final String callId;

  /// toolStarted 时模型传的入参（原样 JSON）。
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

  /// 一次工具调用开始执行。[text] 是工具 id，[argsJson] 是模型传的入参。
  const AssistantStreamEvent.toolStarted({
    required this.callId,
    required this.text,
    required this.argsJson,
  }) : kind = .toolStarted,
       inputTokens = 0,
       outputTokens = 0,
       cachedInputTokens = 0,
       cacheWriteTokens = 0;

  /// 一次工具调用的结果。[text] 是结果文本。
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

  /// 稳定 system prompt（缓存前缀）。仅含身份 / 护栏 / 预设人格 / 工具目录，每轮字节一致。
  final String systemPrompt;

  /// 易变前缀：拼到本轮外发消息上、不进 system（避免污染缓存前缀）。见 [buildVolatilePrompt]。
  final String volatilePrefix;

  final int maxTokens;

  final List<AssistantMessage> history;

  /// 本轮的思考设置。协议差异（adaptive+effort / budget_tokens / reasoning_effort /
  /// reasoning.summary）全部在 Rust 侧按 [type] 展开。
  final AssistantReasoning reasoning;

  /// 是否给模型挂载工具。模型不支持工具调用时应为 false（否则可能被供应商拒）。
  final bool tools;

  /// 预设声明的工具 id 子集（会话快照，dsh：预设声明它 mount 哪些工具）。
  /// null = 全部。空列表调用方应直接置 [tools] 为 false。
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
  factory AssistantService.get() => getIt.get<AssistantService>();

  Stream<AssistantStreamEvent> chat(AssistantChatRequest request);
}
