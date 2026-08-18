import 'dart:async';
import 'dart:convert';

import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 会话标题：第一条用户消息发出后，用一次辅助模型调用把它总结成短标题。
///
/// 线路与模型**跟随本会话**——不另挑小模型：用户挑了什么就用什么，行为可预期，也不用
/// 为「标题该用哪个模型」再开一处配置。**但不带思考**：那 64 个 token 要全用来写标题，
/// 先想一轮就什么都不剩了。
///
/// **只喂用户那条消息，不等助手回复。** 回复对「这次会话在聊什么」几乎不添信息，
/// 却要把标题压在主交互的关键路径上——列表里那一行会一直挂着截断的原话。
///
/// 兜底（截断第一条消息）在建会话时就写好了，这里做的是把它**换掉**；任何一步不
/// 成立都返回 null，保留兜底。生成只发生一次，见 [ChatSession.titleFromModel]。
class SessionTitleController {
  final Set<String> _inFlight = <String>{};

  /// 返回带新标题的会话副本；已生成过 / 输入不合格 / 调用失败 / 超时一律返回 null。
  Future<ChatSession?> maybeTitle({
    required ChatSession session,
    required String firstUserText,
    required LlmProvider provider,
    required String model,
    required String apiKey,
    Duration timeout = assistantTitleTimeout,
  }) async {
    if (session.titleFromModel) return null;
    if (_inFlight.contains(session.id)) return null;
    final seed = firstUserText.trim();
    if (seed.isEmpty) return null;

    // 用 JSON 数组框起来，用户文本就撑不破分隔符——正文里写一行「Title: X」不会被
    // 当成结构的一部分。
    final framed =
        'Generate the session title from this JSON array of user messages:\n'
        '${jsonEncode([seed])}';
    if (utf8.encode(framed).length > assistantTitleMaxInputBytes) return null;

    _inFlight.add(session.id);
    try {
      // 报错、超时、洗完是空 —— 三种都重试。第三种是推理模型把额度全花在
      // `<think>` 上，再来一次往往就有了。
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
          return session.copyWith(title: title, titleFromModel: true);
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(session.id);
    }
  }

  /// 跑一次辅助调用，返回原始文本；超时返回 null。
  ///
  /// 超时**不吃已经到手的那半截**：截断的标题看不出是残的，还不如退回兜底。
  Future<String?> _generate({
    required LlmProvider provider,
    required String model,
    required String apiKey,
    required String framed,
    required Duration timeout,
  }) async {
    // 与对话同一条线路（协议按模型解析），但 reasoning 留默认的 off。
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
    sub = AssistantService.get()
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
    // 超时那条路必须真的把订阅停掉，否则请求还在后台跑完、白烧一份 token。
    await sub.cancel();
    return ok ? buffer.toString() : null;
  }
}

/// 非空白的 C0 / C1 控制字符。
final RegExp _controlCharacter = RegExp(
  r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]',
);

/// 方向控制与零宽字符：它们不占位置，却能让显示出来的标题与实际内容不符。
final RegExp _directionalControl = RegExp(
  r'[\u200B\u200E\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\uFEFF]',
);

/// 模型把思维链直接写进正文的 `<think>` 段。中转站上的推理模型常这么干，不剥的话
/// 标题就成了思维链的前几十个字节。
final RegExp _thinkBlock = RegExp(
  r'<think>[\s\S]*?</think>',
  caseSensitive: false,
);

/// 清洗模型给的标题：剥思维链 → 取第一条非空行 → 去控制字符 → 按 UTF-8 字节截断。
///
/// **取首行而不是把整段折成一行**：模型偶尔会回「标题\n\n然后解释一通」，折起来会把
/// 解释也拼进标题再截断，取首行则天然把后面整段丢掉。
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

/// 截到字节预算之内，且**不切碎码点**——切一半会留下一个替换符方块。
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
