import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_rust/llm.dart' as rust;

@LazySingleton(as: AssistantService)
class RigAssistantService implements AssistantService {
  @override
  Stream<AssistantStreamEvent> chat(AssistantChatRequest request) async* {
    if (request.apiKey.isEmpty) {
      throw const AssistantNotConfiguredException();
    }

    final tools = <rust.RigToolDef>[
      if (request.tools)
        for (final spec in AssistantToolRegistry.specsFor(request.allowedTools))
          rust.RigToolDef(
            name: spec.id,
            description: spec.description,
            parametersJson: jsonEncode(spec.jsonSchema),
          ),
    ];
    final history = <rust.RigChatMessage>[];
    for (final m in request.history) {
      var imageBase64 = '';
      var imageMime = '';
      final path = m.imagePath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          imageBase64 = base64Encode(bytes);
          imageMime = _imageMime(bytes, path);
        }
      }
      history.add(
        rust.RigChatMessage(
          role: m.role == .user ? 'user' : 'assistant',
          content: m.content,
          imageBase64: imageBase64,
          imageMime: imageMime,
        ),
      );
    }
    if (request.volatilePrefix.isNotEmpty && history.isNotEmpty) {
      final last = history.last;
      history[history.length - 1] = rust.RigChatMessage(
        role: last.role,
        content: last.content.isEmpty
            ? request.volatilePrefix
            : '${request.volatilePrefix}\n\n${last.content}',
        imageBase64: last.imageBase64,
        imageMime: last.imageMime,
      );
    }
    final config = rust.RigProviderConfig(
      protocol: request.type.id,
      apiKey: request.apiKey,
      baseUrl: request.baseUrl,
      model: request.model,
      maxTokens: request.maxTokens,
      reasoningMode: request.reasoning.mode.id,
      reasoningEffort: request.reasoning.effort,
      reasoningBudget: request.reasoning.budgetTokens,
    );

    await rust.MoodiaryRust.ensureInitialized();
    final stream = rust.rigChatStream(
      config: config,
      systemPrompt: request.systemPrompt,
      history: history,
      tools: tools,
      maxTurns: assistantMaxTurns,
      toolDispatch: (name, argsJson) => _dispatch(request, name, argsJson),
    );

    await for (final event in stream) {
      yield switch (event) {
        rust.RigStreamEvent_TextDelta(:final field0) =>
          AssistantStreamEvent.text(field0),
        rust.RigStreamEvent_ReasoningDelta(:final field0) =>
          AssistantStreamEvent.reasoning(field0),
        rust.RigStreamEvent_ToolCall(:final field0) =>
          AssistantStreamEvent.tool(field0),
        rust.RigStreamEvent_ToolStarted(
          :final callId,
          :final name,
          :final argsJson,
        ) =>
          AssistantStreamEvent.toolStarted(
            callId: callId,
            text: name,
            argsJson: argsJson,
          ),
        rust.RigStreamEvent_ToolFinished(:final callId, :final result) =>
          AssistantStreamEvent.toolFinished(callId: callId, text: result),
        rust.RigStreamEvent_Usage(
          :final inputTokens,
          :final outputTokens,
          :final cachedInputTokens,
          :final cacheWriteTokens,
        ) =>
          AssistantStreamEvent.usage(
            inputTokens,
            outputTokens,
            cachedInputTokens: cachedInputTokens,
            cacheWriteTokens: cacheWriteTokens,
          ),
      };
    }
  }

  String _imageMime(List<int> b, String path) {
    if (b.length >= 4 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (b.length >= 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    if (b.length >= 3 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
      return 'image/gif';
    }
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String> _dispatch(
    AssistantChatRequest request,
    String name,
    String argsJson,
  ) {
    final allowed = request.allowedTools;
    final spec = allowed != null && !allowed.contains(name)
        ? null
        : AssistantToolRegistry.byId(name);
    return dispatchAssistantTool(
      spec: spec,
      toolName: name,
      argsJson: argsJson,
    );
  }
}

@visibleForTesting
@visibleForTesting
Future<String> dispatchAssistantTool({
  required AssistantToolSpec? spec,
  required String toolName,
  required String argsJson,
}) async {
  if (spec == null) return 'Failed: unknown tool "$toolName".';

  try {
    final trimmed = argsJson.trim();
    final raw = (trimmed.isEmpty || trimmed == 'null') ? '{}' : trimmed;
    final input = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return await spec.run(input);
  } catch (e) {
    return 'Failed: $toolName threw $e. Check the arguments against the schema, '
        'then retry or take another route.';
  }
}
