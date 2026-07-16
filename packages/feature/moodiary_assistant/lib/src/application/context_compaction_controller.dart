import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';

/// 参与压缩判定的一条消息（从聊天控制器的文本消息投影而来）。
typedef CompactionMessage = ({String id, bool fromUser, String text});

/// 自动上下文压缩：把较早对话摘要进 [ChatSession]，只影响发送给模型的历史（Isar 消息永不
/// 删除，可逆）。任何失败都返回 null，不打断主对话。
class ContextCompactionController {
  final Set<String> _inFlight = <String>{};

  /// 判定并执行压缩，返回带新摘要/水位的会话副本；无需压缩或失败返回 null。
  /// [force] 跳过 token 阈值判定，但仍要求有足够可摘要的历史。
  Future<ChatSession?> maybeCompact({
    required ChatSession session,
    required List<CompactionMessage> orderedMessages,
    required int lastInputTokens,
    required int contextLimit,
    required LlmProvider provider,
    required String apiKey,
    bool force = false,
  }) async {
    if (_inFlight.contains(session.id)) return null;

    final budget = contextLimit > 0 ? contextLimit : assistantDefaultContextBudget;
    if (orderedMessages.length < assistantCompactionMinMessages) return null;
    if (!force && lastInputTokens < budget * assistantCompactionTriggerRatio) {
      return null;
    }
    if (orderedMessages.length <= assistantCompactionTailMessages) return null;

    // 末尾若干条逐字保留；其余为可压缩范围。
    final preTail = orderedMessages.sublist(
      0,
      orderedMessages.length - assistantCompactionTailMessages,
    );
    // 只折叠上次水位之后新增的部分（滚动摘要），不重复摘要已压缩内容。
    var startIdx = 0;
    final watermark = session.compactedUpToMessageId;
    if (watermark != null) {
      final at = preTail.indexWhere((m) => m.id == watermark);
      if (at >= 0) startIdx = at + 1;
    }
    final toSummarize = preTail.sublist(startIdx);
    if (toSummarize.isEmpty) return null;
    final newWatermark = preTail.last.id;

    _inFlight.add(session.id);
    try {
      final summary = await _summarize(
        provider: provider,
        apiKey: apiKey,
        priorSummary: session.compactedSummary,
        messages: toSummarize,
      );
      if (summary == null || summary.trim().isEmpty) return null;
      return session.copyWith(
        compactedSummary: summary.trim(),
        compactedUpToMessageId: newWatermark,
        compactedAt: DateTime.timestamp(),
        compactedInputTokensAtTrigger: lastInputTokens,
      );
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(session.id);
    }
  }

  Future<String?> _summarize({
    required LlmProvider provider,
    required String apiKey,
    required String? priorSummary,
    required List<CompactionMessage> messages,
  }) async {
    final history = <AssistantMessage>[];
    if (priorSummary != null && priorSummary.trim().isNotEmpty) {
      history
        ..add(AssistantMessage.user('[Earlier summary]\n${priorSummary.trim()}'))
        ..add(const AssistantMessage.assistant('OK.'));
    }
    for (final m in messages) {
      history.add(
        m.fromUser
            ? AssistantMessage.user(m.text)
            : AssistantMessage.assistant(m.text),
      );
    }
    history.add(
      const AssistantMessage.user(
        'Summarize the conversation above following your instructions.',
      ),
    );

    final request = AssistantChatRequest(
      type: provider.protocol,
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      model: provider.model,
      systemPrompt: buildCompactionSystemPrompt(),
      maxTokens: assistantCompactionSummaryMaxTokens,
      history: history,
      tools: false,
    );

    final buffer = StringBuffer();
    await for (final event in AssistantService.get().chat(request)) {
      if (event.kind == AssistantStreamKind.text) buffer.write(event.text);
    }
    return buffer.toString();
  }
}
