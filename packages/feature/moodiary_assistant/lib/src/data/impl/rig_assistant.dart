import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';

class RigAssistantService implements AssistantService {
  @override
  Stream<String> chat(AssistantChatRequest request) async* {
    if (request.apiKey.isEmpty) {
      throw const AssistantNotConfiguredException();
    }

    final tools = [
      for (final spec in AssistantToolRegistry.specs)
        rust.RigToolDef(
          name: spec.id,
          description: spec.description,
          parametersJson: jsonEncode(spec.jsonSchema),
        ),
    ];
    final history = [
      for (final m in request.history)
        rust.RigChatMessage(
          role: m.role == AssistantRole.user ? 'user' : 'assistant',
          content: m.content,
        ),
    ];
    final config = rust.RigProviderConfig(
      protocol: request.type.id,
      apiKey: request.apiKey,
      baseUrl: request.baseUrl,
      model: request.model,
      maxTokens: request.maxTokens,
    );

    final stream = rust.rigChatStream(
      config: config,
      systemPrompt: request.systemPrompt,
      history: history,
      tools: tools,
      maxTurns: assistantMaxTurns,
      toolDispatch: (name, argsJson) => _dispatch(request, name, argsJson),
    );

    await for (final event in stream) {
      if (event.kind == rust.RigEventKind.textDelta) {
        yield event.text;
      }
    }
  }

  Future<String> _dispatch(
    AssistantChatRequest request,
    String name,
    String argsJson,
  ) {
    return dispatchAssistantTool(
      spec: AssistantToolRegistry.byId(name),
      toolName: name,
      requester: request.onToolPermission,
      argsJson: argsJson,
    );
  }
}

@visibleForTesting
Future<String> dispatchAssistantTool({
  required AssistantToolSpec? spec,
  required String toolName,
  required ToolPermissionRequester? requester,
  required String argsJson,
}) async {
  if (spec == null) return '未知工具：$toolName。';

  if (requester != null && !await requester(spec.tool)) {
    return '用户拒绝了执行「$toolName」操作。请不要重试，可换一种方式继续对话。';
  }

  final trimmed = argsJson.trim();
  final raw = (trimmed.isEmpty || trimmed == 'null') ? '{}' : trimmed;
  final input = (jsonDecode(raw) as Map).cast<String, dynamic>();
  return spec.run(input);
}
