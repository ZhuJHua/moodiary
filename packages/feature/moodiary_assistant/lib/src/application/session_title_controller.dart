import 'dart:async';
import 'dart:convert';

import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

class SessionTitleController {
  final Set<String> _inFlight = <String>{};

  Future<ChatSession?> maybeTitle({
    required ChatSession session,
    required String firstUserText,
    required LlmProvider provider,
    required String model,
    required String apiKey,
    Duration timeout = assistantTitleTimeout,
  }) async {
    if (session.title.isNotEmpty) return null;
    if (_inFlight.contains(session.id)) return null;
    final seed = firstUserText.trim();
    if (seed.isEmpty) return null;

    final framed =
        'Generate the session title from this JSON array of user messages:\n'
        '${jsonEncode([seed])}';
    if (utf8.encode(framed).length > assistantTitleMaxInputBytes) return null;

    _inFlight.add(session.id);
    try {
      for (var attempt = 0; attempt <= assistantTitleRetries; attempt++) {
        final raw = await _generate(
          provider: provider,
          model: model,
          apiKey: apiKey,
          framed: framed,
          timeout: timeout,
        );
        final title = raw == null
            ? ''
            : normalizeSessionTitle(raw, maxBytes: assistantTitleMaxBytes);
        if (title.isNotEmpty) {
          return session.copyWith(title: title);
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(session.id);
    }
  }

  Future<String?> _generate({
    required LlmProvider provider,
    required String model,
    required String apiKey,
    required String framed,
    required Duration timeout,
  }) async {
    final route = ModelResolver.resolve(provider, model);
    final request = AssistantChatRequest(
      type: route.protocol,
      baseUrl: route.baseUrl,
      apiKey: apiKey,
      model: route.modelId,
      systemPrompt: buildTitleSystemPrompt(),
      maxTokens: assistantTitleMaxOutputTokens,
      history: [.user(framed)],
      tools: false,
    );

    final buffer = StringBuffer();
    final done = Completer<bool>();
    late final StreamSubscription<AssistantStreamEvent> sub;
    sub = getIt<AssistantService>()
        .chat(request)
        .listen(
          (event) {
            if (event.kind == .text) buffer.write(event.text);
          },
          onError: (_) {
            if (!done.isCompleted) done.complete(false);
          },
          onDone: () {
            if (!done.isCompleted) done.complete(true);
          },
        );
    final deadline = Timer(timeout, () {
      if (!done.isCompleted) done.complete(false);
    });

    final ok = await done.future;
    deadline.cancel();
    await sub.cancel();
    return ok ? buffer.toString() : null;
  }
}

final RegExp _controlCharacter = RegExp(
  r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]',
);

final RegExp _directionalControl = RegExp(
  r'[\u200B\u200E\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\uFEFF]',
);

final RegExp _thinkBlock = RegExp(
  r'<think>[\s\S]*?</think>',
  caseSensitive: false,
);

String normalizeSessionTitle(String input, {required int maxBytes}) {
  final body = input.replaceAll(_thinkBlock, '');
  final line = body
      .split('\n')
      .map(
        (e) => e
            .replaceAll(_controlCharacter, '')
            .replaceAll(_directionalControl, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      )
      .firstWhere((e) => e.isNotEmpty, orElse: () => '');
  return _truncateUtf8(line, maxBytes).trimRight();
}

String _truncateUtf8(String input, int maxBytes) {
  if (utf8.encode(input).length <= maxBytes) return input;
  final buffer = StringBuffer();
  var used = 0;
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final bytes = utf8.encode(char).length;
    if (used + bytes > maxBytes) break;
    buffer.write(char);
    used += bytes;
  }
  return buffer.toString();
}
