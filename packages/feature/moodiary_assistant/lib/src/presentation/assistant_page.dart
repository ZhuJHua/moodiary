import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/application/context_compaction_controller.dart';
import 'package:moodiary_assistant/src/application/session_title_controller.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_assistant/src/data/soul_repository.dart';
import 'package:moodiary_assistant/src/presentation/assistant_notice.dart';
import 'package:moodiary_assistant/src/presentation/assistant_summary_tile.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:moodiary_assistant/src/presentation/markdown_code_block.dart';
import 'package:moodiary_assistant/src/presentation/model_picker_sheet.dart';
import 'package:moodiary_assistant/src/routes.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 「+」菜单里的三项。
enum _ComposerTool { diary, image, fullscreen }

/// 控制条右侧那两颗按钮（「+」与发送 / 停止）的直径。
///
/// 它们撑起整条的高度；左边的思考胶囊保持自己的高度，靠底对齐把底边对齐到同一条线上。
const double _kComposerControlSize = 40;

/// 面板内壁到控件的留白。与 [_kComposerControlSize] 一起决定同心圆角的收缩量。
const double _kComposerPadding = 8;

Widget _codeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) => MarkdownCodeBlock(name: name, code: code);

class AssistantPage extends ConsumerStatefulWidget {
  final String? initialSessionId;

  const AssistantPage({super.key, this.initialSessionId});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

/// 会话标题：空表示还没生成出来，显示「新对话」。**别把这句存进库**——存了就等于把
/// 生成当时的语种烤进历史记录。
String _sessionTitle(ChatSession? session, Translations l10n) {
  final title = session?.title.trim() ?? '';
  return title.isEmpty ? l10n.assistant.newChat : title;
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _chatScroll = ScrollController();
  final _listKey = GlobalKey<AssistantChatListState>();

  late final AssistantChatController _chat;

  StreamSubscription<AssistantStreamEvent>? _streamSub;

  AssistantTurn? _streamingMessage;

  /// 思考模式流式状态（每轮生成开始时由 [_resetThinkingState] 重置）。
  DateTime? _reasoningStart;
  String _streamingReasoning = '';
  int _thinkingMillis = 0;
  bool _thinkingActive = false;

  /// 重新生成时被移除的旧回复 id：等新回复成功落库后才真正删除（兜底防丢）。
  List<String> _staleReplyIds = [];

  int _generation = 0;

  bool _sending = false;
  bool _ready = true;
  bool _initialized = false;

  /// 本次会话的思考档位。空串 = 关。
  String _reasoningLevel = '';

  /// 本次会话用的供应商与模型。首条消息落库时钉进 [ChatSession]，之后改设置里的
  /// 默认供应商不影响它。
  LlmProvider? _provider;
  String _modelId = '';

  /// 当前模型是否支持图片附件（决定是否显示「发送图片」入口）。
  bool _canSendImage = false;

  /// 当前模型可选的思考档位（来自目录的 `reasoning_options`）。空 = 不给强度控件。
  List<String> _reasoningLevels = const [];

  /// 当前模型的目录条目；自定义供应商或缓存未命中时为 null。
  LlmModelPreset? _activeModel;

  /// 单次回复的 max_tokens，取自目录的 `limit.output`。
  int _maxTokens = assistantFallbackMaxTokens;

  /// 当前模型是否支持工具调用（不支持则本轮不挂载工具）。
  bool _canUseTools = true;

  /// 已选、待随下一条消息发送的图片文件名（image 目录内）。null 表示无待发图片。
  String? _pendingImageName;


  final ContextCompactionController _compaction = ContextCompactionController();
  final SessionTitleController _title = SessionTitleController();

  /// 最近一轮 provider 上报的输入 token 数（压缩触发判据）。0 表示尚无用量数据。
  int _lastTurnInputTokens = 0;

  /// 当前激活模型的上下文窗口（用于上下文占用指示与压缩阈值）。随 provider 变化刷新。
  int _contextLimit = assistantDefaultContextBudget;

  /// 「立即压缩」进行中，避免重复触发。
  bool _compacting = false;

  /// 悬浮输入面板的实测高度：列表底部留白与「回到底部」按钮的位置都读它。
  double _composerHeight = 0;

  ChatSession? _session;

  bool _disclaimerAccepted = false;

  @override
  void initState() {
    super.initState();
    _chat = AssistantChatController();
    _disclaimerAccepted =
        MoodiaryKVs.assistantDisclaimerAccepted.get() ?? false;
    _reasoningLevel = MoodiaryKVs.assistantReasoningEffort.get() ?? '';
    _refreshReady();
    if (!_disclaimerAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDisclaimer();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // 新会话就是一张空列表 —— 不再合成欢迎语。它从前还会作为一条真正的
    // assistant 轮次进 `_buildHistory` 一起发给模型。
    final id = widget.initialSessionId;
    if (id != null) _loadSessionById(id);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _chatScroll.dispose();
    _streamSub?.cancel();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _refreshReady() async {
    final repo = LlmProviderRepository.get();
    final session = _session;
    // 会话已建立就用它钉住的那份；供应商被删了就回落到默认，别让历史会话打不开。
    final pinned = session == null || session.providerId.isEmpty
        ? null
        : await repo.getProvider(session.providerId);
    final provider = pinned ?? await repo.getActiveProvider();
    final key = provider == null ? null : await repo.getKey(provider.id);
    final wanted = pinned != null && (session?.model.isNotEmpty ?? false)
        ? session!.model
        : (_modelId.isEmpty ? (provider?.defaultModel ?? '') : _modelId);
    final resolved = provider == null
        ? null
        : ModelResolver.resolve(provider, wanted);
    final model = resolved?.preset;
    final caps = _capabilities(provider, model);
    final levels = provider == null
        ? const <String>[]
        : ModelResolver.levelsFor(provider, wanted);
    if (mounted) {
      setState(() {
        _ready = provider != null && key != null && key.isNotEmpty;
        _provider = provider;
        _modelId = resolved?.modelId ?? '';
        _activeModel = model;
        _reasoningLevels = levels;
        _canSendImage = caps.attachment;
        _canUseTools = caps.tools;
        _contextLimit = model?.contextLimit ?? assistantDefaultContextBudget;
        _maxTokens = maxTokensFor(model?.outputLimit);
        // 档位表按模型给，换了模型旧档位可能已经不在表里。
        if (_reasoningLevel.isNotEmpty && !levels.contains(_reasoningLevel)) {
          _reasoningLevel = '';
        }
        // 切到不收图的模型：丢弃已选但还没发出的图片，免得发出去被供应商拒。
        if (!caps.attachment) _pendingImageName = null;
      });
    }
  }

  /// 目录命中就以目录为准（逐模型），否则按自定义供应商声明的标记；
  /// preset 但缓存未命中时保守放行工具（多数模型支持）。
  ({bool tools, bool attachment}) _capabilities(
    LlmProvider? provider,
    LlmModelPreset? model,
  ) {
    if (provider == null) return const (tools: true, attachment: false);
    if (model != null) {
      return (tools: model.toolCall, attachment: model.acceptsImage);
    }
    if (provider.isPreset) return const (tools: true, attachment: false);
    return (tools: provider.toolCall, attachment: provider.attachment);
  }

  /// 会话开始前可以改模型与思考强度；开始后只读（[_session] 非空即已开始）。
  Future<void> _pickModel() async {
    final provider = _provider;
    if (provider == null || _session != null) return;
    final options = ModelResolver.optionsFor(provider);
    if (options.isEmpty) return;
    final choice = await showModelPicker(
      context,
      providerName: provider.name,
      options: options,
      modelId: _modelId,
      level: _reasoningLevel,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _modelId = choice.modelId;
      _reasoningLevel = choice.level;
    });
    // 档位是「最后一次用的」，作为下个新会话的起始值。模型不写默认 ——
    // 那是供应商列表页那枚「默认」标记的事。
    MoodiaryKVs.assistantReasoningEffort.set(choice.level);
    await _refreshReady();
  }

  Future<void> _loadSessionById(String id) async {
    final session = await ChatRepository.get().getSession(id);
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).maybePop();
      return;
    }
    await _loadSession(session);
  }

  Future<void> _loadSession(ChatSession session) async {
    _generation++;
    _streamSub?.cancel();
    _streamSub = null;
    _streamingMessage = null;
    _staleReplyIds = [];
    await _chat.loadSession(session.id);
    if (!mounted) return;
    setState(() {
      _session = session;
      _reasoningLevel = session.reasoningEffort; // 恢复该会话钉住的档位
      _pendingImageName = null;
      _sending = false;
    });
    // 会话钉住的供应商 / 模型要重新解析一遍（可能与当前默认不是同一个）。
    await _refreshReady();
    if (!mounted) return;
    // 会话若已压缩，按水位重新合成压缩提示 chip（完整消息仍在库里、照常展示）。
    _syncCompactionNotice();
    _listKey.currentState?.pinToBottom();
  }

  Future<ChatSession?> _ensureSession(String firstUserText) async {
    final existing = _session;
    if (existing != null) return existing;
    final provider = _provider;
    if (provider == null) return null;
    // 标题留空 → 界面显示「新对话」，模型总结好之后就地换掉。
    final session = ChatSession.create(
      providerId: provider.id,
      model: _modelId,
      reasoningEffort: _reasoningLevel, // 定格：开始之后不再可改
    );
    await ChatRepository.get().upsertSession(session);
    _chat.sessionId = session.id;
    if (mounted) setState(() => _session = session);
    // 与本轮回复并行跑，不 await：标题的延迟和失败都不该压在主回复上。
    unawaited(_generateTitle(session, firstUserText));
    return session;
  }

  /// 用模型把第一条消息总结成标题，替掉兜底。失败静默——兜底本来就够用。
  Future<void> _generateTitle(ChatSession session, String firstUserText) async {
    final provider = _provider;
    if (provider == null) return;
    final key = await LlmProviderRepository.get().getKey(provider.id);
    if (key == null || key.isEmpty) return;
    if (!mounted || _session?.id != session.id) return;

    final updated = await _title.maybeTitle(
      session: session,
      firstUserText: firstUserText,
      provider: provider,
      model: _modelId,
      apiKey: key,
    );
    // 跑的这段时间里会话可能已被切走或删掉，落库前后各查一次。
    if (updated == null || !mounted || _session?.id != session.id) return;
    await ChatRepository.get().upsertSession(updated);
    if (!mounted || _session?.id != session.id) return;
    setState(() => _session = updated);
  }

  /// 全屏编辑：把输入框内容搬到一整页去改，回来再塞回控制器。
  /// 取消（返回键 / 关闭）返回 null，此时一个字都不动。
  Future<void> _openFullscreenComposer() async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenComposerPage(text: _inputController.text),
      ),
    );
    if (edited == null || !mounted) return;
    _inputController
      ..text = edited
      // 光标落到末尾，回来就能接着写。
      ..selection = TextSelection.collapsed(offset: edited.length);
    _inputFocusNode.requestFocus();
  }

  Future<void> _openSettings() async {
    await const AssistantSettingRoute().push(context);
    await _refreshReady();
  }

  Future<void> _showDisclaimer() async {
    final l10n = context.l10n;
    final agreed = await MAlert.confirm(
      context,
      icon: LucideIcons.shieldAlert,
      title: l10n.assistant.disclaimerTitle,
      message: l10n.assistant.disclaimerContent,
      confirmLabel: l10n.assistant.disclaimerAgree,
      cancelLabel: l10n.assistant.disclaimerDecline,
      barrierDismissible: false,
    );
    if (agreed) {
      MoodiaryKVs.assistantDisclaimerAccepted.set(true);
      if (!mounted) return;
      setState(() => _disclaimerAccepted = true);
      await _refreshReady();
    }
  }

  Future<AssistantChatRequest?> _buildRequest(
    List<AssistantMessage> history, {
    required String systemPrompt,
    required String volatilePrefix,
  }) async {
    final provider = _provider;
    if (provider == null) return null;
    final key = await LlmProviderRepository.get().getKey(provider.id);
    if (key == null || key.isEmpty) return null;
    // 协议与 baseUrl 按**模型**解析：中转站底下 Claude 走 messages、GPT 走
    // responses，取供应商级的会直接发错地方。
    final route = ModelResolver.resolve(provider, _modelId);
    return AssistantChatRequest(
      type: route.protocol,
      baseUrl: route.baseUrl,
      apiKey: key,
      model: route.modelId,
      systemPrompt: systemPrompt,
      volatilePrefix: volatilePrefix,
      maxTokens: _maxTokens,
      history: history,
      reasoning: resolveReasoning(
        level: _reasoningLevels.contains(_reasoningLevel)
            ? _reasoningLevel
            : '',
        model: _activeModel,
        maxTokens: _maxTokens,
      ),
      tools: _canUseTools,
    );
  }

  void _resetThinkingState() {
    _reasoningStart = null;
    _streamingReasoning = '';
    _thinkingMillis = 0;
    _thinkingActive = false;
  }

  Future<void> _submit(String text) async {
    text = text.trim();
    final imageName = _pendingImageName;
    if ((text.isEmpty && imageName == null) ||
        _sending ||
        !_disclaimerAccepted) {
      return;
    }
    final imageLabel = context.l10n.assistant.imageMessageLabel;
    final gen = ++_generation;
    // 用户开启了新一轮对话：放弃上一次失败重生成遗留的旧回复（保留在库里，不删）。
    _staleReplyIds = [];

    final base = DateTime.timestamp();
    final userMsg = AssistantTurn.user(
      text,
      imageName: imageName ?? '',
      createdAt: base,
    );
    _chat.add(userMsg);
    _inputController.clear();
    setState(() {
      _sending = true;
      _pendingImageName = null;
    });

    await _generate(
      gen: gen,
      sessionSeedText: text.isEmpty ? imageLabel : text,
      userMessage: userMsg,
      placeholderAt: base.add(const Duration(milliseconds: 1)),
    );
  }

  /// 重新回答：删掉最后一条用户消息之后的全部内容，基于同一条用户消息重新生成；也用于停止/报错后重试。
  Future<void> _regenerate() async {
    if (_sending || !_disclaimerAccepted) return;
    final gen = ++_generation;
    _streamSub?.cancel();
    _streamSub = null;
    _streamingMessage = null;

    final items = _chat.items;
    var lastUserIdx = -1;
    for (var i = items.length - 1; i >= 0; i--) {
      final m = items[i];
      if (m is AssistantTurn && m.fromUser) {
        lastUserIdx = i;
        break;
      }
    }
    if (lastUserIdx == -1) return;
    final userMsg = items[lastUserIdx] as AssistantTurn;

    setState(() => _sending = true);
    // 旧回复先只从内存移除，落库删除推迟到新回复落库后（_purgeStaleReplies），避免重新生成失败时连旧答案一起丢掉。
    final trailing = items.sublist(lastUserIdx + 1).toList();
    // 一次性删完再发一次通知：逐条删会发 N 次通知、触发 N 轮补跳互相 abort，肉眼是抖。
    _chat.batch(() {
      for (final m in trailing) {
        _chat.remove(m);
        if (m is AssistantTurn) _staleReplyIds.add(m.id);
      }
    });
    if (!mounted || gen != _generation) return;

    await _generate(
      gen: gen,
      sessionSeedText: userMsg.text,
      userMessage: userMsg,
      placeholderAt: .timestamp(),
    );
  }

  Future<void> _generate({
    required int gen,
    required String sessionSeedText,
    required AssistantTurn userMessage,
    required DateTime placeholderAt,
  }) async {
    // 发送与重新回答都从这里进，所以强制跟随放这一层。
    // 特别是「重新回答」：它删掉尾部回复会让 RangeMaintainingScrollPhysics 在布局里
    // 静默 clamp（走 correctPixels，不发通知），位置其实已经在底部而标志位还是旧的。
    _listKey.currentState?.pinToBottom();
    final l10n = context.l10n;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    // 稳定前缀（身份/护栏/SOUL/工具目录）逐轮字节一致以命中缓存；易变文本另拼到外发消息。
    final soul = await SoulRepository.get().read();
    final memories = await MemoryRepository.get().getRecent(
      memoryInjectionLimit,
    );
    if (!mounted || gen != _generation) return;
    final systemPrompt = buildStableSystemPrompt(
      soul: soul,
      toolsEnabled: _canUseTools,
    );
    final volatilePrefix = buildVolatilePrompt(
      localeTag: localeTag,
      nowLocal: .now(),
      memories: [for (final m in memories) '(${m.category}) ${m.text}'],
    );

    _resetThinkingState();
    final placeholder = AssistantTurn.assistant(
      '',
      streaming: true,
      createdAt: placeholderAt,
    );
    _chat.beginStreaming(placeholder);
    _streamingMessage = placeholder;

    final history = _buildHistory();

    final request = await _buildRequest(
      history,
      systemPrompt: systemPrompt,
      volatilePrefix: volatilePrefix,
    );
    if (!mounted || gen != _generation) return;
    if (request == null) {
      _appendDelta(l10n.assistant.needProvider);
      _finalizeStreaming(persist: false);
      await _refreshReady();
      if (mounted && gen == _generation) setState(() => _sending = false);
      return;
    }

    final session = await _ensureSession(sessionSeedText);
    if (!mounted || gen != _generation) return;
    if (session != null) {
      await _chat.persist(userMessage);
      if (!mounted || gen != _generation) return;
    }

    final needApiKeyText = l10n.assistant.needApiKey;
    var errored = false;
    try {
      _streamSub = AssistantService.get()
          .chat(request)
          .listen(
            (event) {
              if (gen != _generation) return;
              switch (event.kind) {
                case .text:
                  _appendDelta(event.text);
                case .reasoning:
                  _appendReasoning(event.text);
                case .tool:
                  // 模型开始调用工具 → 思考阶段结束，冻结计时（不计入工具执行时间）。
                  _freezeThinkingOnTool();
                case .toolStarted:
                  _applyToolStarted(event.callId, event.text, event.argsJson);
                case .toolFinished:
                  _applyToolFinished(event.callId, event.text);
                case .usage:
                  _applyUsage(event.inputTokens, event.outputTokens);
              }
            },
            onError: (Object e) {
              if (gen != _generation) return;
              errored = true;
              if (e is AssistantNotConfiguredException) {
                _appendDelta(needApiKeyText);
                _refreshReady();
              } else {
                _appendDelta(l10n.assistant.streamError(error: '$e'));
              }
              // 落库：屏幕上已经有这半截回复 + 出错标记，不存的话重进会话就凭空少一段。
              // 空回复由 _finalizeStreaming 自己剔除。
              _finalizeStreaming(persist: true);
              if (mounted) setState(() => _sending = false);
            },
            onDone: () {
              if (gen != _generation) return;
              // 默认 cancelOnError: false，出错后流仍会正常关闭 —— 不挡住的话这一轮会被
              // 收尾两次，还会对一次失败的对话发起自动压缩。
              if (errored) return;
              _finalizeStreaming(persist: true);
              if (mounted) setState(() => _sending = false);
              // 本轮已落库、拿到 provider 上报的输入 token 后，按阈值尝试压缩上下文。
              unawaited(_maybeCompact());
            },
          );
    } catch (e) {
      _appendDelta(l10n.assistant.requestFailed(error: '$e'));
      _finalizeStreaming(persist: false);
      if (mounted) setState(() => _sending = false);
    }
  }

  List<AssistantMessage> _buildHistory() {
    // 1. 收集逐字文本消息（带 id，供压缩水位定位）。
    final raw =
        <
          ({String id, AssistantRole role, String content, String? imagePath})
        >[];
    for (final m in _chat.items) {
      if (m is! AssistantTurn) continue;
      final hasImage = m.imageName.isNotEmpty;
      final content = m.fromUser ? m.text : _withToolRecord(m);
      if (content.isEmpty && !hasImage) continue;
      raw.add((
        id: m.id,
        role: m.fromUser ? AssistantRole.user : AssistantRole.assistant,
        content: content,
        imagePath: hasImage ? AppFiles.getRealPath('image', m.imageName) : null,
      ));
    }

    // 2. 应用压缩水位：丢弃水位（含）之前的逐字内容，改由摘要代表。
    final session = _session;
    final summary = session?.compactedSummary;
    final watermark = session?.compactedUpToMessageId;
    var start = 0;
    if (summary != null && summary.isNotEmpty && watermark != null) {
      final at = raw.indexWhere((e) => e.id == watermark);
      if (at >= 0) start = at + 1;
    }
    final kept = raw.sublist(start);

    // 3. 压缩过则先放一对合成的「摘要」问答；放历史里、不进 system，保持缓存前缀稳定。
    final result = <AssistantMessage>[];
    if (start > 0 && summary != null && summary.isNotEmpty) {
      result
        ..add(.user('[Summary of earlier conversation]\n$summary'))
        ..add(const .assistant('Understood — I have the earlier context.'));
    }

    // 4. 合并相邻同角色纯文本；含图片的独立成条（避免图片被并进别的气泡）。
    for (final e in kept) {
      if (e.imagePath == null &&
          result.isNotEmpty &&
          result.last.role == e.role &&
          result.last.imagePath == null) {
        result.last = AssistantMessage(
          e.role,
          '${result.last.content}\n\n${e.content}',
        );
      } else {
        result.add(AssistantMessage(e.role, e.content, imagePath: e.imagePath));
      }
    }
    return result;
  }

  /// 把这一轮用过的工具补进 assistant 那条消息（见 [AssistantToolRegistry.recordOf]）。
  String _withToolRecord(AssistantTurn turn) {
    final record = AssistantToolRegistry.recordOf(turn.toolCalls);
    if (record.isEmpty) return turn.text;
    return turn.text.isEmpty ? record : '$record\n\n${turn.text}';
  }

  /// 每轮结束后按 token 阈值自动尝试压缩。
  Future<void> _maybeCompact() => _runCompaction(force: false);

  /// 「立即压缩」手动触发：跳过阈值，给出结果提示。
  Future<void> _compactNow() async {
    if (_compacting) return;
    setState(() => _compacting = true);
    final l10n = context.l10n;
    final updated = await _runCompaction(force: true);
    if (!mounted) return;
    setState(() => _compacting = false);
    if (updated != null) {
      toast.success(message: l10n.assistant.compactionDone);
    } else {
      toast.info(message: l10n.assistant.compactionNothing);
    }
  }

  Future<ChatSession?> _runCompaction({required bool force}) async {
    final session = _session;
    if (session == null || (!force && _lastTurnInputTokens <= 0)) return null;
    final provider = _provider;
    if (provider == null) return null;
    final key = await LlmProviderRepository.get().getKey(provider.id);
    if (key == null || key.isEmpty) return null;
    if (!mounted || _session?.id != session.id) return null;

    final ordered = <CompactionMessage>[
      for (final m in _chat.items)
        if (m is AssistantTurn && !m.isEmpty)
          (
            id: m.id,
            fromUser: m.fromUser,
            text: m.text.isEmpty ? l10n.assistant.imagePlaceholder : m.text,
          ),
    ];

    final updated = await _compaction.maybeCompact(
      session: session,
      orderedMessages: ordered,
      lastInputTokens: _lastTurnInputTokens,
      contextLimit: _contextLimit,
      provider: provider,
      model: _modelId,
      apiKey: key,
      force: force,
    );
    if (updated == null || !mounted || _session?.id != session.id) return null;
    await ChatRepository.get().upsertSession(updated);
    if (!mounted || _session?.id != session.id) return null;
    setState(() => _session = updated);
    _syncCompactionNotice();
    return updated;
  }

  /// 按当前会话压缩水位，把提示 chip 对齐到边界：移除旧的、在水位消息后插入新的。
  void _syncCompactionNotice() {
    // 整段包进 batch：删旧 chip + 插新 chip 是一次逻辑改动，分两次通知会让
    // 列表在一轮结束的瞬间抖一下 —— 而那正是用户翻历史的时刻。
    _chat.batch(() {
      _chat.removeWhere((m) => m is AssistantCompactionNotice);
      final session = _session;
      final watermark = session?.compactedUpToMessageId;
      if (session?.compactedSummary == null || watermark == null) return;
      final idx = _chat.indexOfId(watermark);
      if (idx < 0) return;
      _chat.insertAt(idx + 1, AssistantCompactionNotice(watermark));
    });
  }

  /// 撤销压缩：清空会话的摘要 / 水位（Isar 消息未动，整段历史恢复逐字发送）。
  Future<void> _restoreFullHistory() async {
    final session = _session;
    if (session == null || session.compactedSummary == null) return;
    final restored = session.copyWith(
      compactedSummary: null,
      compactedUpToMessageId: null,
      compactedAt: null,
      compactedInputTokensAtTrigger: null,
    );
    await ChatRepository.get().upsertSession(restored);
    if (!mounted) return;
    setState(() => _session = restored);
    _syncCompactionNotice();
  }

  void _stop() {
    if (!_sending) return;
    _generation++;
    _streamSub?.cancel();
    _streamSub = null;
    _finalizeStreaming(persist: true);
    setState(() => _sending = false);
  }

  void _finalizeStreaming({required bool persist}) {
    final cur = _streamingMessage;
    _streamingMessage = null;
    if (cur == null) return;
    if (cur.text.isEmpty) {
      _chat.batch(() {
        _chat.remove(cur);
        _chat.endStreaming();
      });
    } else {
      final settled = cur.settled;
      _chat.batch(() {
        _chat.replace(settled);
        _chat.endStreaming();
      });
      if (persist) {
        _chat.persist(settled);
        _purgeStaleReplies();
      }
    }
  }

  /// 新回复已成功落库后，才删除被它替换掉的旧回复；在此之前旧回复一直留在库里兜底。
  void _purgeStaleReplies() {
    if (_staleReplyIds.isEmpty) return;
    final ids = _staleReplyIds;
    _staleReplyIds = [];
    for (final id in ids) {
      unawaited(_chat.deleteMessage(id));
    }
  }

  void _appendDelta(String delta) {
    if (delta.isEmpty) return;
    // 首个正文 token 到来即结束思考阶段（不计入后续正文时间）。
    _freezeThinkingTimer();
    final cur = _streamingMessage;
    if (cur == null) return;
    _syncReasoning(cur.copyWith(text: cur.text + delta));
  }

  void _appendReasoning(String delta) {
    if (delta.isEmpty) return;
    final cur = _streamingMessage;
    if (cur == null) return;
    // 开启（或在工具调用后重新开启）一个思考分段；耗时按分段累加，排除工具等待间隙。
    _reasoningStart ??= DateTime.timestamp();
    _thinkingActive = true;
    _streamingReasoning += delta;
    _syncReasoning(cur);
  }

  /// 一次工具调用开始执行：先挂一条未完成的记录（界面上是转圈那条）。
  void _applyToolStarted(String callId, String name, String argsJson) {
    final cur = _streamingMessage;
    if (cur == null) return;
    // 同一个 callId 重复上报就忽略，别把同一次调用画两条。
    if (cur.toolCalls.any((c) => c.callId == callId)) return;
    final next = cur.copyWith(
      toolCalls: [
        ...cur.toolCalls,
        AssistantToolCall(callId: callId, name: name, argsJson: argsJson),
      ],
    );
    _chat.updateStreaming(next);
    _streamingMessage = next;
  }

  /// 工具结果回来了：就地把那一条标成完成。
  void _applyToolFinished(String callId, String result) {
    final cur = _streamingMessage;
    if (cur == null) return;
    final index = cur.toolCalls.indexWhere((c) => c.callId == callId);
    if (index == -1) return;
    final updated = [...cur.toolCalls];
    updated[index] = updated[index].copyWith(result: result, done: true);
    final next = cur.copyWith(toolCalls: updated);
    _chat.updateStreaming(next);
    _streamingMessage = next;
  }

  /// 本轮结束的 token 用量：写回当前流式消息（随后 settled 保留、落库）。
  void _applyUsage(int inputTokens, int outputTokens) {
    if (inputTokens > 0) _lastTurnInputTokens = inputTokens;
    final cur = _streamingMessage;
    if (cur == null || (inputTokens <= 0 && outputTokens <= 0)) return;
    final next = cur.copyWith(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );
    _chat.updateStreaming(next);
    _streamingMessage = next;
  }

  /// 模型转入工具调用：冻结思考计时并把「已思考」态写回当前流式消息。
  void _freezeThinkingOnTool() {
    if (!_thinkingActive) return;
    _freezeThinkingTimer();
    final cur = _streamingMessage;
    if (cur != null) _syncReasoning(cur);
  }

  /// 结束当前思考分段：把已过去的时间累加进 [_thinkingMillis]，停表。幂等。
  void _freezeThinkingTimer() {
    if (!_thinkingActive) return;
    _thinkingActive = false;
    final start = _reasoningStart;
    if (start != null) {
      _thinkingMillis += DateTime.timestamp().difference(start).inMilliseconds;
      _reasoningStart = null;
    }
  }

  /// 累计思考耗时（已冻结分段之和 + 当前分段进行中的时长）。
  int _liveThinkingMillis() {
    final start = _reasoningStart;
    if (_thinkingActive && start != null) {
      return _thinkingMillis +
          DateTime.timestamp().difference(start).inMilliseconds;
    }
    return _thinkingMillis;
  }

  /// 把当前思考状态（正文 + 思考正文 / 时长 / 是否进行中）刷进流式消息并更新引用。
  void _syncReasoning(AssistantTurn message) {
    var next = message;
    if (_streamingReasoning.isNotEmpty) {
      next = next.copyWith(
        reasoning: _streamingReasoning,
        thinkingMillis: _liveThinkingMillis(),
        thinkingActive: _thinkingActive,
      );
    }
    if (_streamingMessage == null) return;
    _chat.updateStreaming(next);
    _streamingMessage = next;
  }

  Future<void> _pickAndSendDiary() async {
    if (_sending) return;
    _inputFocusNode.unfocus();
    final diary = await const AssistantDiaryPickerRoute().push<Diary>(context);
    if (diary == null || !mounted) return;
    await _submit(_formatDiaryMessage(diary));
  }

  /// 相册选一张图，经 MediaManager 转码/压缩存进 image 目录，挂到输入框待发（可再配文字）。
  Future<void> _pickImage() async {
    if (_sending) return;
    _inputFocusNode.unfocus();
    final files = await IFilePicker.get().pickImages(context, maxAssets: 1);
    if (files.isEmpty || !mounted) return;
    final first = files.first;
    final saved = await MediaManager.saveImages(imageFileList: [first]);
    final name = saved[first.path];
    if (name == null || !mounted) return;
    setState(() => _pendingImageName = name);
  }

  void _removePendingImage() {
    setState(() => _pendingImageName = null);
  }

  String _formatDiaryMessage(Diary diary) {
    final l10n = context.l10n;
    final date = TimeFormat.fullDate(diary.time);
    final title = diary.title.trim();
    final header = title.isEmpty ? date : '$date · $title';
    final body = diary.contentText.trim();
    return '${l10n.assistant.sendDiaryLead}\n\n【$header】\n$body';
  }

  /// 点击消息列表时收起键盘与工具面板（焦点从输入框移开）。
  void _dismissComposer() {
    if (_inputFocusNode.hasFocus) _inputFocusNode.unfocus();
  }

  Widget _buildChat() {
    return AssistantChatList(
      key: _listKey,
      controller: _chat,
      scrollController: _chatScroll,
      itemBuilder: _buildItem,
      scrollToBottomBuilder: _buildScrollToBottom,
      onPointerDown: _dismissComposer,
      bottomPadding: _composerHeight + 8,
    );
  }

  Widget _buildItem(BuildContext context, AssistantChatItem item, int index) {
    return switch (item) {
      AssistantTurn() => _buildTurn(item),
      AssistantCompactionNotice() => _CompactionNoticeChip(
        summary: _session?.compactedSummary ?? '',
        onRestore: _restoreFullHistory,
      ),
    };
  }

  Widget _buildTurn(AssistantTurn turn) {
    final items = _chat.items;
    final isLast = items.isNotEmpty && items.last.id == turn.id;
    if (turn.fromUser) {
      // 用户消息落在末尾（首个 token 前被停止 / 本轮未产出回复）时也给出重试入口。
      return _UserBubble(
        text: turn.text,
        imageName: turn.imageName,
        onRetry: (!_sending && isLast) ? _regenerate : null,
      );
    }
    final hasUserTurn = items.any((m) => m is AssistantTurn && m.fromUser);
    return _AssistantBubble(
      text: turn.text,
      reasoning: turn.reasoning,
      thinkingMillis: turn.thinkingMillis,
      thinkingActive: turn.thinkingActive,
      inputTokens: turn.inputTokens,
      outputTokens: turn.outputTokens,
      toolCalls: turn.toolCalls,
      streaming: turn.streaming,
      onRegenerate: (!_sending && isLast && hasUserTurn) ? _regenerate : null,
    );
  }

  /// 回到底部：悬在输入区正上方、居中。
  Widget _buildScrollToBottom(
    BuildContext context,
    bool visible,
    VoidCallback onTap,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      // 悬在输入面板正上方。
      bottom: _composerHeight + 8,
      child: Center(
        child: AnimatedSlide(
          offset: visible ? .zero : const Offset(0, 0.6),
          duration: Durations.short4,
          curve: Easing.standard,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Durations.short4,
            // 隐藏时不能还挡着最后一条气泡的点击。
            child: IgnorePointer(
              ignoring: !visible,
              child: _ScrollToBottomButton(onTap: onTap),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    final composer = _AssistantComposer(
      controller: _inputController,
      focusNode: _inputFocusNode,
      sending: _sending,
      onSend: () => _submit(_inputController.text),
      onStop: _stop,
      usedTokens: _lastTurnInputTokens,
      contextLimit: _contextLimit,
      onSendDiary: _pickAndSendDiary,
      onSendImage: _canSendImage ? _pickImage : null,
      onFullscreen: _openFullscreenComposer,
      modelLabel: _activeModel?.name ?? _modelId,
      reasoningLevel: _reasoningLevel,
      // 会话一开始就锁死：模型和强度都是定格进 ChatSession 的。
      onPickModel: _session == null ? _pickModel : null,
      pendingImageName: _pendingImageName,
      onRemoveImage: _removePendingImage,
    );

    return Column(
      children: [
        if (!_ready) _NotConfiguredBanner(onTap: _openSettings),
        // 消息列表铺满，输入面板浮在它上面 —— 内容从面板底下穿过去。
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildChat()),
              Positioned(
                // 缺了 left/right，Positioned 在横向就不受约束，Column 会缩成内容宽。
                left: 0,
                right: 0,
                bottom: 0,
                child: _SizeReporter(
                  onHeight: (height) {
                    if (mounted) setState(() => _composerHeight = height);
                  },
                  child: composer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final Widget chatArea = !_disclaimerAccepted
        ? _DisclaimerGate(onReview: _showDisclaimer)
        : _buildConversation(context);

    return Scaffold(
      // 键盘由 Scaffold 抬：浮起来的输入面板贴在 body 底边，body 一缩它就跟着上来。
      // （原先是 false + ChatBottomPanelContainer 自己垫键盘高度，那套已经拆掉。）
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_sessionTitle(_session, l10n)),
        actions: [
          MMenuButton<String>(
            tooltip: l10n.common.more,
            entries: [
              MMenuEntry(
                value: 'compact',
                label: l10n.assistant.compactNow,
                icon: LucideIcons.foldVertical,
                enabled: _session != null && !_compacting && !_sending,
              ),
            ],
            onSelected: (value) {
              if (value == 'compact') unawaited(_compactNow());
            },
            child: const Padding(
              padding: .all(12),
              child: Icon(LucideIcons.ellipsisVertical),
            ),
          ),
        ],
      ),
      body: chatArea,
    );
  }
}

/// 上下文占用指示：一枚小圆环，挂在「+」左边。
///
/// 输入 token 占模型窗口的比例，接近 / 达到压缩阈值时转黄、转红。具体数字进 tooltip ——
/// 输入区寸土寸金，常驻一个百分比数字太吵。
class _ContextUsageRing extends StatelessWidget {
  final int usedTokens;
  final int contextLimit;

  static const double _diameter = 18;

  const _ContextUsageRing({
    required this.usedTokens,
    required this.contextLimit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final ratio = contextLimit <= 0 ? 0.0 : usedTokens / contextLimit;
    final percent = (ratio * 100).clamp(0, 999).round();
    final Color color;
    if (ratio >= assistantCompactionTriggerRatio) {
      color = scheme.error;
    } else if (ratio >= assistantCompactionTriggerRatio * 0.8) {
      color = scheme.tertiary;
    } else {
      color = scheme.onSurfaceVariant;
    }
    return Tooltip(
      message:
          '${context.l10n.assistant.contextUsageLabel} $percent% · '
          '$usedTokens / $contextLimit',
      // 控制条是底对齐的（迁就矮一截的思考胶囊），圆环只有 18 —— 装进一个和右边
      // 按钮等高的盒子里居中，视觉上才和它们在同一条水平线上。
      child: SizedBox(
        height: _kComposerControlSize,
        child: Center(
          child: SizedBox.square(
            dimension: _diameter,
            child: CircularProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              strokeWidth: 2.5,
              color: color,
              backgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
    );
  }
}

/// 上下文压缩提示：居中的低调 chip，点开可看摘要并「恢复完整历史」。
class _CompactionNoticeChip extends StatelessWidget {
  final String summary;
  final VoidCallback onRestore;

  const _CompactionNoticeChip({required this.summary, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    // 和思考块同一个组件：一行、无容器、onSurfaceVariant。它不就地展开而是开弹窗
    // （里面还有「恢复完整历史」这个动作），所以画的是**向右**箭头。
    return AssistantNotice(
      icon: LucideIcons.foldVertical,
      kind: context.l10n.assistant.compactionNotice,
      onTap: () => _showSheet(context),
    );
  }

  void _showSheet(BuildContext context) {
    MSheet.show<void>(
      context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return MSheetScaffold<void>(
          title: l10n.assistant.compactionSheetTitle,
          icon: LucideIcons.chevronsUpDown,
          actions: [
            MAction(label: l10n.common.cancel),
            MAction(
              label: l10n.assistant.compactionRestore,
              isPrimary: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onRestore();
              },
            ),
          ],
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              Text(
                l10n.assistant.compactionSheetNote,
                style: sheetContext.theme.typography.bodySmall.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                summary.isEmpty ? '—' : summary,
                style: sheetContext.theme.typography.bodyMedium.onSurface,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DisclaimerGate extends StatelessWidget {
  final VoidCallback onReview;

  const _DisclaimerGate({required this.onReview});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const .all(32),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(LucideIcons.shield, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.assistant.disclaimerGateTitle,
              textAlign: .center,
              style: context.theme.typography.titleMedium.onSurface,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onReview,
              icon: const Icon(LucideIcons.fileText),
              label: Text(l10n.assistant.disclaimerGateAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConfiguredBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _NotConfiguredBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Material(
      color: scheme.errorContainer,
      child: MInkWell(
        onTap: onTap,
        child: Padding(
          padding: const .all(12),
          child: Row(
            children: [
              Icon(LucideIcons.triangleAlert, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.assistant.notConfiguredBanner,
                  style: context.theme.typography.bodyMedium.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onStop;

  /// 上下文占用。两者都 > 0 才显示那枚圆环（还没拿到用量数据时不占位）。
  final int usedTokens;
  final int contextLimit;

  final VoidCallback onSendDiary;

  /// null 表示当前模型不支持图片附件，菜单里就不出这一项。
  final VoidCallback? onSendImage;
  final String modelLabel;
  final String reasoningLevel;
  final VoidCallback onFullscreen;

  /// null 表示会话已开始 —— chip 照常显示，但不可点。
  final VoidCallback? onPickModel;
  final String? pendingImageName;
  final VoidCallback onRemoveImage;

  const _AssistantComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.onStop,
    required this.usedTokens,
    required this.contextLimit,
    required this.onSendDiary,
    required this.onSendImage,
    required this.modelLabel,
    required this.reasoningLevel,
    required this.onFullscreen,
    required this.onPickModel,
    required this.pendingImageName,
    required this.onRemoveImage,
  });

  /// 输入区的最大行数随系统字号收缩。
  ///
  /// App 内的字号设置已经整个删掉、只跟系统走，所以 2.0× 是可达的 —— 那时 6 行
  /// 正文加上图片预览能占到 500px，而面板现在是浮在列表上的，盖住的是对话本身。
  int _maxLines(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (scale >= 1.6) return 3;
    if (scale >= 1.3) return 4;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    const radius = MuiRadius.xl;
    // 底部安全区现在归自己让。用 `paddingOf` 而不是 `viewPaddingOf`：
    // Scaffold 开了 resizeToAvoidBottomInset，键盘弹起时 padding.bottom 会归零
    // （那段已经被 viewInsets 吃掉、body 整体抬了上来），正好不该再让第二次。
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: .fromLTRB(12, 0, 12, 8 + MediaQuery.paddingOf(context).bottom),
        // 面板得自己吃掉点击：输入框与按钮行之间那几 px 缝隙一旦漏下去就打在
        // 列表上，正打字时按到就收键盘。跟 mui 的底栏一样显式声明，不靠
        // Material 的 absorbHitTest 顺带兜住。
        child: GestureDetector(
          behavior: .opaque,
          child: DecoratedBox(
            // 底色 / 发丝边 / 投影一个 ShapeDecoration 全包了，不需要再叠一层
            // Material —— 面板内部的按钮各自带 Material，水波不依赖这里。
            // 不透明元素可以直接让 ShapeDecoration 画投影；玻璃面那边要自绘挖空，
            // 是因为投影会被 BackdropFilter 当背景采走。
            decoration: ShapeDecoration(
              color: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: scheme.outlineVariant,
                  // 一个物理像素，与玻璃面同一条规矩：写死 0.5 在 3x 屏上是 1.5 个
                  // 物理像素，粗得能看出来。
                  width: 1 / MediaQuery.devicePixelRatioOf(context),
                ),
              ),
              shadows: MGlassSurface.defaultShadows(scheme),
            ),
            child: Padding(
              padding: const .all(_kComposerPadding),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  if (pendingImageName != null)
                    _ComposerImagePreview(
                      imageName: pendingImageName!,
                      onRemove: onRemoveImage,
                    ),
                  // 文字输入区：独占上方，向上增高。无背景 —— 面板本身就是容器了。
                  //
                  // 上内边距与左右取齐（都是面板的 8 再加这里的 8 = 16）。给 2 的话
                  // 上是 10、左右是 16，整块文字看着往上贴。
                  Padding(
                    padding: const .fromLTRB(8, 8, 8, 6),
                    child: MField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !sending,
                      maxLines: _maxLines(context),
                      variant: .plain,
                      showClear: false,
                      textInputAction: .send,
                      hintText: l10n.assistant.inputHint,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  // 底部控制条：左边是模型 + 思考强度，右「+」与发送 / 停止一组。
                  //
                  // 底对齐而不是居中：chip 比右边那两颗按钮矮，居中会让它多浮起来
                  // 半个高度差，底边距就不再等于左边距（都该是面板的 8），看着脱离
                  // 面板的角。底对齐之后四个角一致，而 chip 保持自己的高度。
                  //
                  // 整条右对齐、**不放 Spacer**：Spacer 是 tight flex，会把剩余
                  // 宽度先分掉一半，模型名就白白被截短。右对齐之后富余的空白自然
                  // 落在左边，Flexible 的 chip 能一直长到真的放不下为止。
                  Row(
                    crossAxisAlignment: .end,
                    mainAxisAlignment: .end,
                    children: [
                      if (usedTokens > 0 && contextLimit > 0) ...[
                        _ContextUsageRing(
                          usedTokens: usedTokens,
                          contextLimit: contextLimit,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (modelLabel.isNotEmpty)
                        Flexible(
                          child: _ModelChip(
                            modelLabel: modelLabel,
                            reasoningLevel: reasoningLevel,
                            onTap: onPickModel,
                          ),
                        ),
                      // 锚点贴着屏幕底，MMenu 会自己算出 preferAbove 向上弹。
                      MMenuButton<_ComposerTool>(
                        tooltip: l10n.assistant.tool,
                        entries: [
                          MMenuEntry(
                            value: .diary,
                            label: l10n.assistant.toolSendDiary,
                            icon: LucideIcons.bookOpen,
                            enabled: !sending,
                          ),
                          if (onSendImage != null)
                            MMenuEntry(
                              value: .image,
                              label: l10n.assistant.toolSendImage,
                              icon: LucideIcons.image,
                              enabled: !sending,
                            ),
                          MMenuEntry(
                            value: .fullscreen,
                            label: l10n.assistant.composerFullscreen,
                            icon: LucideIcons.maximize2,
                          ),
                        ],
                        onSelected: (tool) => switch (tool) {
                          _ComposerTool.diary => onSendDiary(),
                          _ComposerTool.image => onSendImage?.call(),
                          _ComposerTool.fullscreen => onFullscreen(),
                        },
                        child: SizedBox.square(
                          dimension: _kComposerControlSize,
                          child: Icon(
                            LucideIcons.plus,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          if (sending) {
                            return MCircleButton(
                              tooltip: l10n.assistant.stop,
                              onPressed: onStop,
                              size: _kComposerControlSize,
                              icon: const Icon(LucideIcons.square),
                            );
                          }
                          final canSend =
                              value.text.trim().isNotEmpty ||
                              pendingImageName != null;
                          return MCircleButton(
                            tooltip: l10n.assistant.send,
                            onPressed: canSend ? onSend : null,
                            size: _kComposerControlSize,
                            icon: const Icon(LucideIcons.arrowUp),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 把 [child] 的高度报给外面。用来让消息列表给悬浮输入面板让出底部空间。
///
/// 走 [SizeChangedLayoutNotifier] 而不是「在 initState / didUpdateWidget 里各测一次」：
/// 后者要把所有会改高度的原因**列全**才对，而输入框长出一行是重排不是重建，
/// 系统字号和语言变化也不经过 didUpdateWidget —— 漏一个就是最后一条气泡永久压在
/// 面板底下，且没有任何报错。notifier 不管原因，只管「重排了」。
class _SizeReporter extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeight;

  const _SizeReporter({required this.child, required this.onHeight});

  @override
  State<_SizeReporter> createState() => _SizeReporterState();
}

class _SizeReporterState extends State<_SizeReporter> {
  final _key = GlobalKey();
  double _last = -1;

  @override
  void initState() {
    super.initState();
    // notifier 不为首次布局发通知，所以初值要自己测一次。
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final height = box.size.height;
      // 阈值兼作循环闸门：报高度会让外面 setState，别让它抖回来。
      if ((height - _last).abs() < 0.5) return;
      _last = height;
      widget.onHeight(height);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    // NotificationListener 必须在 notifier **之上** —— 通知是往上冒的。
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _schedule();
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _key, child: widget.child),
      ),
    );
  }
}

/// 回到底部。浮在输入面板上方的小圆片。
class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScrollToBottomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MCircleButton(
      tooltip: context.l10n.assistant.scrollToBottom,
      onPressed: onTap,
      tone: .plain,
      size: 36,
      elevated: true,
      icon: const Icon(LucideIcons.chevronDown),
    );
  }
}

/// 当前模型 + 思考强度。会话开始前可点开换（[onTap] 非空），开始后变成只读标签 ——
/// 模型和强度在首条消息落库时就钉进 `ChatSession` 了，中途换等于让同一段对话
/// 前后由不同模型作答，历史里却看不出来。
///
/// 没有容器底色：它挨着「+」，再套一层胶囊会和右边两颗圆钮抢视觉重量，
/// 而它只是个状态标签。
class _ModelChip extends StatelessWidget {
  final String modelLabel;
  final String reasoningLevel;
  final VoidCallback? onTap;

  const _ModelChip({
    required this.modelLabel,
    required this.reasoningLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = onTap == null;
    final typography = context.theme.typography;

    final label = Row(
      mainAxisSize: .min,
      children: [
        // 只有模型名可压缩：强度和箭头都是定宽的小东西，先让它们占住位。
        Flexible(
          child: Text(
            modelLabel,
            maxLines: 1,
            overflow: .ellipsis,
            style: typography.labelMedium.onSurface,
          ),
        ),
        if (reasoningLevel.isNotEmpty) ...[
          const SizedBox(width: 5),
          // 目录原值，不翻译（见 model_picker_sheet）。
          Text(reasoningLevel, style: typography.labelSmall.onSurfaceVariant),
        ],
        if (!locked) ...[
          const SizedBox(width: 2),
          Icon(
            LucideIcons.chevronDown,
            size: 15,
            color: context.theme.colors.onSurfaceVariant,
          ),
        ],
      ],
    );

    if (locked) {
      return Padding(
        padding: const .symmetric(horizontal: 6, vertical: 10),
        child: label,
      );
    }
    return MInkWell(
      shape: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const .symmetric(horizontal: 6, vertical: 10),
        child: label,
      ),
    );
  }
}

class _ComposerImagePreview extends StatelessWidget {
  final String imageName;
  final VoidCallback onRemove;

  const _ComposerImagePreview({
    required this.imageName,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Padding(
      padding: const .fromLTRB(8, 6, 8, 2),
      child: Align(
        alignment: .centerLeft,
        child: Stack(
          clipBehavior: .none,
          children: [
            ClipRRect(
              // 同心圆角：面板内壁是 xl(24)，缩略图离内壁 8（面板 padding）+ 8
              // （这层自己的 padding）= 16，所以取 24 − 16 = 8。
              borderRadius: MuiRadius.inside(
                MuiRadius.xl,
                _kComposerPadding * 2,
              ),
              child: Image.file(
                File(AppFiles.getRealPath('image', imageName)),
                width: 72,
                height: 72,
                fit: .cover,
                errorBuilder: (_, _, _) => _brokenImage(scheme, 72),
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: .circle,
                    border: .all(color: scheme.surfaceContainer, width: 2),
                  ),
                  padding: const .all(2),
                  child: Icon(
                    LucideIcons.x,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _brokenImage(ColorScheme scheme, double size) => Container(
  width: size,
  height: size,
  color: scheme.surfaceContainerHighest,
  child: Icon(LucideIcons.imageOff, color: scheme.onSurfaceVariant),
);

class _UserBubble extends StatelessWidget {
  final String text;
  final String imageName;
  final VoidCallback? onRetry;

  const _UserBubble({required this.text, this.imageName = '', this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    final hasImage = imageName.isNotEmpty;
    final hasText = text.isNotEmpty;

    final parts = <Widget>[];
    if (hasImage) {
      parts.add(
        ClipRRect(
          borderRadius: .circular(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 260),
            child: Image.file(
              File(AppFiles.getRealPath('image', imageName)),
              fit: .cover,
              errorBuilder: (_, _, _) => _brokenImage(scheme, 120),
            ),
          ),
        ),
      );
    }
    if (hasText) {
      if (hasImage) parts.add(const SizedBox(height: 6));
      parts.add(
        Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const .symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: const .only(
              topLeft: .circular(16),
              topRight: .circular(16),
              bottomLeft: .circular(16),
              bottomRight: .circular(4),
            ),
          ),
          child: SelectableText(
            text,
            style: context.theme.typography.bodyMedium.onPrimaryContainer,
          ),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: .end,
      mainAxisSize: .min,
      children: parts,
    );

    if (onRetry == null) return content;
    return Column(
      crossAxisAlignment: .end,
      mainAxisSize: .min,
      children: [
        content,
        _BubbleActionButton(
          icon: LucideIcons.rotateCw,
          label: context.l10n.assistant.regenerate,
          onTap: onRetry!,
        ),
      ],
    );
  }
}

/// token 数紧凑显示：≥100 万用 M、≥1000 用 K，均保留一位小数；千以内直接显示原值。
String _compactTokens(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

/// 思考时长的短写：10 秒以上取整，以下保留一位。
String _durationText(int millis) {
  final secs = millis / 1000;
  if (secs >= 10) return secs.toStringAsFixed(0);
  return (secs < 0.1 ? 0.1 : secs).toStringAsFixed(1);
}

/// 从思考正文里取一行当摘要。[tail] 为真取最后一行（思考中，跟着长），
/// 否则取第一行（结束了，要个稳定的开头）。Markdown 的标记符号先剥掉，
/// 一行摘要里出现 `## ` 或 `- ` 只是噪声。
String _reasoningPeek(String reasoning, {required bool tail}) {
  final lines = [
    for (final line in reasoning.split('\n'))
      if (line.trim().isNotEmpty)
        line.trim().replaceAll(RegExp(r'^[#>\-*\s]+'), ''),
  ];
  if (lines.isEmpty) return '';
  return tail ? lines.last : lines.first;
}

class _AssistantBubble extends StatelessWidget {
  final String text;
  final String reasoning;
  final int thinkingMillis;
  final bool thinkingActive;
  final int inputTokens;
  final int outputTokens;
  final List<AssistantToolCall> toolCalls;
  final bool streaming;
  final VoidCallback? onRegenerate;

  const _AssistantBubble({
    required this.text,
    required this.reasoning,
    required this.thinkingMillis,
    required this.thinkingActive,
    required this.inputTokens,
    required this.outputTokens,
    required this.toolCalls,
    required this.streaming,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;

    final hasText = text.isNotEmpty;
    final showThinking = thinkingActive || reasoning.isNotEmpty;

    // 助手正文**不带气泡**：整段 Markdown 拿回全屏宽（列表、代码块在 82% 宽的
    // 气泡里每行都被截短），而且页面上唯一带底色的东西就只剩用户自己发的那句 ——
    // 「模型说的」与「过程信息」不再都装在盒子里、分不开。分层改由颜色承担：
    // 正文 onSurface，过程提示 onSurfaceVariant。
    Widget? bubble;
    if (hasText) {
      bubble = SelectionArea(
        child: GptMarkdown(
          text,
          style: context.theme.typography.bodyMedium.onSurface,
          codeBuilder: _codeBlock,
        ),
      );
    } else if (!showThinking) {
      bubble = const Padding(
        padding: .symmetric(vertical: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final stacked = <Widget>[
      if (showThinking)
        AssistantNotice(
          icon: thinkingActive ? null : LucideIcons.brain,
          kind: thinkingActive
              ? l10n.assistant.thinking
              : l10n.assistant.thoughtFor(
                  duration: _durationText(thinkingMillis),
                ),
          // 思考中给**最后一行**（跟着长，看得出在动），结束后给第一行（稳定的开头）。
          summary: _reasoningPeek(reasoning, tail: thinkingActive),
          detail: reasoning.isEmpty
              ? null
              : (context) => GptMarkdown(
                  reasoning,
                  style: context.theme.typography.bodySmall.onSurfaceVariant,
                  codeBuilder: _codeBlock,
                ),
        ),
      // 工具调用排在思考之后、正文之前 —— 那正是它们发生的顺序。
      for (final call in toolCalls) _toolNotice(context, call),
      ?bubble,
    ];

    // 流式中或还没有正文：只堆叠提示条 + 正文，不显示操作按钮。
    if (!hasText || streaming) {
      return _fullWidth(
        Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: stacked,
        ),
      );
    }

    final hasTokens = inputTokens > 0 || outputTokens > 0;
    return _fullWidth(
      Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          ...stacked,
          // 复制 / 重新回答，token 用量紧跟其右；用 Wrap，窄屏放不下时自动换行不溢出。
          Wrap(
            crossAxisAlignment: .center,
            children: [
              _BubbleActionButton(
                icon: LucideIcons.copy,
                label: l10n.assistant.copyTooltip,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  toast.success(message: l10n.assistant.copied);
                },
              ),
              if (onRegenerate != null)
                _BubbleActionButton(
                  icon: LucideIcons.rotateCw,
                  label: l10n.assistant.regenerate,
                  onTap: onRegenerate!,
                ),
              if (hasTokens)
                Padding(
                  padding: const .symmetric(horizontal: 6, vertical: 4),
                  child: DefaultTextStyle.merge(
                    style: context.theme.typography.labelSmall.onSurfaceVariant,
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        Icon(
                          LucideIcons.arrowUp,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(_compactTokens(inputTokens)),
                        const SizedBox(width: 8),
                        Icon(
                          LucideIcons.arrowDown,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(_compactTokens(outputTokens)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一次工具调用渲染成一条提示条。与思考同一个组件。
///
/// 摘要由工具自己给（`AssistantToolSpec.summaryOf`）——截断结果字符串得到的是
/// 半截元数据，工具自己才知道该说「7 条 · 08-11 至 08-17」。
Widget _toolNotice(BuildContext context, AssistantToolCall call) {
  final spec = AssistantToolRegistry.byId(call.name);
  final display = spec == null
      ? call.name
      : assistantToolDisplay(context, spec.tool).title;
  if (!call.done) {
    // 还在跑：转圈，没有箭头（还没有下文可展开）。
    return AssistantNotice(kind: display);
  }
  final input = _decodeArgs(call.argsJson);
  return AssistantNotice(
    icon: LucideIcons.wrench,
    kind: display,
    summary: spec?.summaryOf(input, call.result) ?? call.result,
    detail: call.result.isEmpty
        ? null
        : (context) => SelectableText(
            call.result,
            style: context.theme.typography.bodySmall.onSurfaceVariant,
          ),
  );
}

Map<String, dynamic> _decodeArgs(String raw) {
  if (raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : const {};
  } catch (_) {
    return const {};
  }
}

/// 助手那一列钉成满宽。
///
/// 列表给条目的是**紧**的横向约束，但 `_align` 外面还包了一层 `Align`（授权卡
/// 要靠那层松约束保住自己 400 的宽度上限），松约束下 Column 会按内容缩包 ——
/// 短回复窄一截还好说，markdown 的表格和代码块拿不到完整可用宽度就不行了。
/// 气泡都去掉了，正文就不该再有任何宽度限制。
Widget _fullWidth(Widget child) => SizedBox(width: .infinity, child: child);

class _BubbleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BubbleActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return MInkWell(
      borderRadius: .circular(8),
      onTap: onTap,
      child: Padding(
        padding: const .symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: .min,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.theme.typography.bodySmall.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantSessionListPage extends StatelessWidget {
  const AssistantSessionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      // 顶栏那颗 ⚙ 撤掉了：全 App 的 ⚙ 现在只有一个含义（全局设置，在「我的」tab 的
      // 底栏动作按钮上），助手自己的配置归 `设置 → 智能助手`。取而代之的是下面这行
      // 摘要 —— 它比一个齿轮多给一条信息：你现在用的是哪个模型。
      appBar: AppBar(title: Text(l10n.assistant.settingFunctionAIAssistant)),
      // 「新对话」不在本页了 —— 本页是根壳的一个 tab，入口是底栏胶囊右边那颗按钮
      // （站在助手 tab 上它就是新对话）。
      body: Column(
        children: [
          Padding(
            padding: const .fromLTRB(12, 4, 12, 8),
            child: Card.filled(
              color: context.theme.colors.surfaceContainerLow,
              margin: .zero,
              child: const AssistantSummaryTile(),
            ),
          ),
          Expanded(
            child: _SessionListView(
              currentId: null,
              onSelect: (session) =>
                  AssistantConversationRoute(sessionId: session.id)
                      .push(context),
              onDelete: (session) =>
                  ChatRepository.get().deleteSession(session.id),
              // 根壳开了 extendBody，底栏整条带高已折进 padding.bottom，直接读来让开。
              padding: .fromLTRB(
                12,
                0,
                12,
                8 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionListView extends StatefulWidget {
  final String? currentId;

  final void Function(ChatSession session) onSelect;

  final void Function(ChatSession session) onDelete;

  final EdgeInsetsGeometry padding;

  const _SessionListView({
    required this.currentId,
    required this.onSelect,
    required this.onDelete,
    this.padding = const .symmetric(horizontal: 12),
  });

  @override
  State<_SessionListView> createState() => _SessionListViewState();
}

class _SessionListViewState extends State<_SessionListView> {
  List<ChatSession>? _sessions;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ChatRepository.get().sessionEvents.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final sessions = await ChatRepository.get().getAllSessions();
    if (mounted) setState(() => _sessions = sessions);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return switch (sessions) {
      null => const Center(child: CircularProgressIndicator()),
      [] => _EmptySessions(),
      final list => ListView.builder(
        padding: widget.padding,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final session = list[index];
          return _SessionCard(
            session: session,
            selected: session.id == widget.currentId,
            onTap: () => widget.onSelect(session),
            onDelete: () => widget.onDelete(session),
          );
        },
      ),
    };
  }
}

class _EmptySessions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.messagesSquare,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.assistant.historyEmpty,
            style: context.theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await MAlert.confirm(
      context,
      title: l10n.common.delete,
      message: _sessionTitle(session, l10n),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (ok) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    final onColor = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return Card.filled(
      margin: const .symmetric(vertical: 4),
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      clipBehavior: .antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const .fromLTRB(12, 4, 4, 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected
                ? scheme.onSecondaryContainer.withValues(alpha: 0.12)
                : scheme.primaryContainer,
            shape: .circle,
          ),
          child: Icon(
            LucideIcons.messagesSquare,
            size: 22,
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          _sessionTitle(session, l10n),
          maxLines: 1,
          overflow: .ellipsis,
          style: context.theme.typography.titleSmall.onSurface.copyWith(
            color: onColor,
          ),
        ),
        subtitle: Text(
          TimeFormat.relative(session.updatedAt),
          style: context.theme.typography.labelSmall.onSurfaceVariant.copyWith(
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        trailing: MMenuButton<String>(
          tooltip: l10n.common.more,
          onSelected: (_) => _confirmDelete(context),
          entries: [
            MMenuEntry(
              value: 'delete',
              label: l10n.common.delete,
              icon: LucideIcons.trash2,
              isDestructive: true,
            ),
          ],
          child: Padding(
            padding: const .all(12),
            child: Icon(
              LucideIcons.ellipsisVertical,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 全屏编辑。长内容在那个最多 6 行的输入框里改不动 —— 尤其是要往中间插话、
/// 或者粘一段长文进来的时候。
///
/// 只负责编辑：确认把文本交回输入框，发不发由用户回去决定。塞一个「发送」进来
/// 会让这一页多出一条与主流程并行的发送路径，而那条路径上没有模型选择、没有图片、
/// 也没有会话建立的那套判断。
class _FullscreenComposerPage extends StatefulWidget {
  final String text;

  const _FullscreenComposerPage({required this.text});

  @override
  State<_FullscreenComposerPage> createState() =>
      _FullscreenComposerPageState();
}

class _FullscreenComposerPageState extends State<_FullscreenComposerPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  )..selection = TextSelection.collapsed(offset: widget.text.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistant.composerFullscreen),
        actions: [
          Padding(
            padding: const .only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(_controller.text),
              child: Text(l10n.common.ok),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const .fromLTRB(16, 8, 16, 16),
          child: MField(
            controller: _controller,
            autofocus: true,
            // 撑满整页：高度由这层 Padding 的父级（Scaffold body）定。
            maxLines: null,
            expands: true,
            variant: .plain,
            showClear: false,
            hintText: l10n.assistant.inputHint,
          ),
        ),
      ),
    );
  }
}
