import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';

class RigAssistantService implements AssistantService {
  @override
  Stream<AssistantStreamEvent> chat(AssistantChatRequest request) async* {
    if (request.apiKey.isEmpty) {
      throw const AssistantNotConfiguredException();
    }

    final tools = <rust.RigToolDef>[
      if (request.tools)
        for (final spec in AssistantToolRegistry.specs)
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
          role: m.role == AssistantRole.user ? 'user' : 'assistant',
          content: m.content,
          imageBase64: imageBase64,
          imageMime: imageMime,
        ),
      );
    }
    // 易变前缀拼到本轮外发消息上（不进 system，不污染缓存前缀）；history 是临时发送副本，不落库。
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
      thinking: request.thinking,
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
      switch (event.kind) {
        case rust.RigEventKind.textDelta:
          yield AssistantStreamEvent.text(event.text);
        case rust.RigEventKind.reasoningDelta:
          yield AssistantStreamEvent.reasoning(event.text);
        case rust.RigEventKind.toolCall:
          // 不在气泡里展示，但用作「思考阶段结束」的信号（冻结思考计时）。
          yield AssistantStreamEvent.tool(event.text);
        case rust.RigEventKind.usage:
          yield AssistantStreamEvent.usage(
            event.inputTokens,
            event.outputTokens,
          );
      }
    }
  }

  /// 按文件内容（magic number）判定 MIME——扩展名可能与实际内容不符（原图质量不重编码），
  /// 否则会因 media_type 不符被供应商拒；识别不出再按扩展名兜底。
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

  // 只读工具直接执行；写入 / 破坏性工具先请用户确认。
  if (spec.tool.needsApproval &&
      requester != null &&
      !await requester(spec.tool)) {
    return '用户拒绝了执行「$toolName」操作。请不要重试，可换一种方式继续对话。';
  }

  final trimmed = argsJson.trim();
  final raw = (trimmed.isEmpty || trimmed == 'null') ? '{}' : trimmed;
  final input = (jsonDecode(raw) as Map).cast<String, dynamic>();
  return spec.run(input);
}
