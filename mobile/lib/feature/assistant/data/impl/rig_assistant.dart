import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary/core/values/assistant.dart';
import 'package:moodiary/feature/assistant/data/assistant.dart';
import 'package:moodiary/feature/assistant/data/assistant_tools.dart';

/// 基于 [rig](https://github.com/0xPlaygrounds/rig)（pure Rust）的助手实现。
/// Rust 侧只做 provider 连接 + 流式 + 多轮工具循环；工具定义作为数据传给 Rust，
/// 真正的执行与权限闸门经 [rust.rigChatStream] 的 `toolDispatch` 回调回到这里完成。
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
      // 工具调用事件暂不透传给 UI，仅取文本增量。
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

/// 工具分发纯逻辑：权限闸门 + 入参解析 + 执行。未知工具 / 权限被拒时返回一句说明
/// （不抛错）让模型优雅继续；[requester] 为 null 表示不做权限校验。
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

  // 入参全可选的工具，模型常发 `null` / 空串，统一兜底为 `{}`。
  final trimmed = argsJson.trim();
  final raw = (trimmed.isEmpty || trimmed == 'null') ? '{}' : trimmed;
  final input = (jsonDecode(raw) as Map).cast<String, dynamic>();
  return spec.run(input);
}
