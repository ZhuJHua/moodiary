import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

typedef CompactionMessage = ({String id, bool fromUser, String text});

class ContextCompactionController {
  final Set<String> _inFlight = <String>{};

  Future<ChatSession?> maybeCompact({
    required ChatSession session,
    required List<CompactionMessage> orderedMessages,
    required int lastInputTokens,
    required int contextLimit,
    required LlmProvider provider,
    required String model,
    required String apiKey,
  }) async {
    if (_inFlight.contains(session.id)) return null;

    final budget = contextLimit > 0
        ? contextLimit
        : assistantDefaultContextBudget;
    if (orderedMessages.length < assistantCompactionMinMessages) return null;
    if (lastInputTokens < budget * assistantCompactionTriggerRatio) return null;
    if (orderedMessages.length <= assistantCompactionTailMessages) return null;

    final preTail = orderedMessages.sublist(
      0,
      orderedMessages.length - assistantCompactionTailMessages,
    );
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
        model: model,
        apiKey: apiKey,
        priorSummary: session.compactedSummary,
        messages: toSummarize,
      );
      if (summary == null || summary.trim().isEmpty) return null;
      return session.copyWith(
        compactedSummary: summary.trim(),
        compactedUpToMessageId: newWatermark,
        compactedAt: .timestamp(),
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
    required String model,
    required String apiKey,
    required String? priorSummary,
    required List<CompactionMessage> messages,
  }) async {
    final history = <AssistantMessage>[];
    if (priorSummary != null && priorSummary.trim().isNotEmpty) {
      history
        ..add(.user('[Earlier summary]\n${priorSummary.trim()}'))
        ..add(const .assistant('OK.'));
    }
    for (final m in messages) {
      history.add(m.fromUser ? .user(m.text) : .assistant(m.text));
    }
    history.add(
      const .user(
        'Summarize the conversation above following your instructions.',
      ),
    );

    final route = ModelResolver.resolve(provider, model);
    final request = AssistantChatRequest(
      type: route.protocol,
      baseUrl: route.baseUrl,
      apiKey: apiKey,
      model: route.modelId,
      systemPrompt: buildCompactionSystemPrompt(),
      maxTokens: assistantCompactionSummaryMaxTokens,
      history: history,
      tools: false,
    );

    final buffer = StringBuffer();
    await for (final event in getIt<AssistantService>().chat(request)) {
      if (event.kind == .text) buffer.write(event.text);
    }
    return buffer.toString();
  }
}
