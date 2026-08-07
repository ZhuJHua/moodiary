import 'dart:async';
import 'dart:io';

import 'package:chat_bottom_container/chat_bottom_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide DateFormat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart' as genui;
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:moodiary_assistant/src/application/context_compaction_controller.dart';
import 'package:moodiary_assistant/src/application/isar_chat_controller.dart';
import 'package:moodiary_assistant/src/application/tool_permission_coordinator.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_assistant/src/data/soul_repository.dart';
import 'package:moodiary_assistant/src/presentation/markdown_code_block.dart';
import 'package:moodiary_assistant/src/presentation/tool_permission_card.dart';
import 'package:moodiary_assistant/src/routes.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

enum _ToolPanel { tools }

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

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _chatScroll = ScrollController();

  late final IsarChatController _chat;

  final _panelController = ChatBottomPanelContainerController<_ToolPanel>();

  StreamSubscription<AssistantStreamEvent>? _streamSub;

  TextMessage? _streamingMessage;

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
  bool _thinking = false;

  /// 当前模型是否支持图片附件（决定是否显示「发送图片」入口）。
  bool _canSendImage = false;

  /// 当前模型是否支持推理（决定是否显示「深度思考」开关）。
  bool _canThink = false;

  /// 当前模型是否支持工具调用（不支持则本轮不挂载工具）。
  bool _canUseTools = true;

  /// 已选、待随下一条消息发送的图片文件名（image 目录内）。null 表示无待发图片。
  String? _pendingImageName;

  late final ToolPermissionCoordinator _permissions;
  late final ToolPermissionActionDelegate _permissionDelegate;

  final ContextCompactionController _compaction = ContextCompactionController();

  /// 最近一轮 provider 上报的输入 token 数（压缩触发判据）。0 表示尚无用量数据。
  int _lastTurnInputTokens = 0;

  /// 当前激活模型的上下文窗口（用于上下文占用指示与压缩阈值）。随 provider 变化刷新。
  int _contextLimit = assistantDefaultContextBudget;

  /// 「立即压缩」进行中，避免重复触发。
  bool _compacting = false;

  ChatSession? _session;

  bool _disclaimerAccepted = false;

  @override
  void initState() {
    super.initState();
    _chat = IsarChatController();
    _permissions = ToolPermissionCoordinator(
      catalog: assistantGenUiCatalog,
      onCardCreated: _insertPermissionCard,
    );
    _permissionDelegate = ToolPermissionActionDelegate(
      _permissions.handleAction,
    );
    _disclaimerAccepted =
        MoodiaryKVs.assistantDisclaimerAccepted.get() ?? false;
    _thinking = MoodiaryKVs.assistantThinkingEnabled.get() ?? false;
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
    final id = widget.initialSessionId;
    if (id != null) {
      _loadSessionById(id);
    } else {
      _chat.setMessages([_welcome()]);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _chatScroll.dispose();
    _streamSub?.cancel();
    _permissions.dispose();
    _chat.dispose();
    super.dispose();
  }

  TextMessage _welcome() =>
      _chat.assistantMessage(context.l10n.assistantWelcome);

  Future<void> _refreshReady() async {
    final provider = await LlmProviderRepository.get().getActiveProvider();
    final key = provider == null
        ? null
        : await LlmProviderRepository.get().getKey(provider.id);
    final ready = provider != null && key != null && key.isNotEmpty;
    final caps = provider == null
        ? const (tools: true, reasoning: false, attachment: false)
        : _capabilities(provider);
    final contextLimit = provider == null
        ? assistantDefaultContextBudget
        : _contextLimitFor(provider);
    if (mounted) {
      setState(() {
        _ready = ready;
        _canThink = caps.reasoning;
        _canSendImage = caps.attachment;
        _canUseTools = caps.tools;
        _contextLimit = contextLimit;
        // 切到不支持附件的模型：丢弃已选但还没发出的图片，避免发出去被供应商拒。
        if (!caps.attachment) _pendingImageName = null;
      });
    }
  }

  /// 解析当前供应商模型能力：preset 查本地缓存（绝不联网，未命中则保守关闭），自定义供应商用用户声明的标记。
  ({bool tools, bool reasoning, bool attachment}) _capabilities(
    LlmProvider provider,
  ) {
    if (provider.providerId.isNotEmpty) {
      for (final preset in LlmPresetRepository.get().cachedPresets()) {
        if (preset.id != provider.providerId) continue;
        for (final model in preset.models) {
          if (model.id == provider.model) {
            return (
              tools: model.toolCall,
              reasoning: model.reasoning,
              attachment: model.attachment,
            );
          }
        }
      }
      return const (tools: true, reasoning: false, attachment: false);
    }
    return (
      tools: provider.toolCall,
      reasoning: provider.reasoning,
      attachment: provider.attachment,
    );
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
    _permissions.reset();
    _streamingMessage = null;
    _staleReplyIds = [];
    await _chat.loadSession(session.id);
    if (!mounted) return;
    setState(() {
      _session = session;
      _thinking = session.thinking; // 恢复该会话自己的思考模式
      _pendingImageName = null;
      _sending = false;
    });
    // 会话若已压缩，按水位重新合成压缩提示 chip（完整消息仍在库里、照常展示）。
    _syncCompactionNotice();
    _jumpToBottomSoon();
  }

  Future<ChatSession?> _ensureSession(String firstUserText) async {
    final existing = _session;
    if (existing != null) return existing;
    final provider = await LlmProviderRepository.get().getActiveProvider();
    if (provider == null) return null;
    final title = firstUserText.length > 30
        ? '${firstUserText.substring(0, 30)}…'
        : firstUserText;
    final session = ChatSession.create(
      title: title,
      providerId: provider.id,
      model: provider.model,
      thinking: _thinking, // 定格当前（来自全局默认或用户在新会话里的选择）
    );
    await ChatRepository.get().upsertSession(session);
    _chat.sessionId = session.id;
    if (mounted) setState(() => _session = session);
    return session;
  }

  Future<void> _openSettings() async {
    await const AssistantSettingRoute().push(context);
    await _refreshReady();
  }

  Future<void> _showDisclaimer() async {
    final l10n = context.l10n;
    final agreed = await showMoodiaryConfirm(
      context,
      icon: LucideIcons.shieldAlert,
      title: l10n.assistantDisclaimerTitle,
      message: l10n.assistantDisclaimerContent,
      confirmLabel: l10n.assistantDisclaimerAgree,
      cancelLabel: l10n.assistantDisclaimerDecline,
      barrierDismissible: false,
    );
    if (agreed) {
      await MoodiaryKVs.assistantDisclaimerAccepted.set(true);
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
    final repo = LlmProviderRepository.get();
    final LlmProvider? provider = await repo.getActiveProvider();
    final key = provider == null ? null : await repo.getKey(provider.id);
    if (provider == null || key == null || key.isEmpty) return null;
    return AssistantChatRequest(
      type: provider.protocol,
      baseUrl: provider.baseUrl,
      apiKey: key,
      model: provider.model,
      systemPrompt: systemPrompt,
      volatilePrefix: volatilePrefix,
      maxTokens: assistantMaxTokens,
      history: history,
      thinking: _thinking && _canThink,
      tools: _canUseTools,
      onToolPermission: _requestToolPermission,
    );
  }

  void _toggleThinking() {
    final next = !_thinking;
    setState(() {
      _thinking = next;
      final s = _session;
      if (s != null) _session = s.copyWith(thinking: next);
    });
    // 更新「新会话默认」（最后一次用的）；已存在的会话则把模式落到会话本身。
    unawaited(MoodiaryKVs.assistantThinkingEnabled.set(next));
    final s = _session;
    if (s != null) unawaited(ChatRepository.get().upsertSession(s));
  }

  void _resetThinkingState() {
    _reasoningStart = null;
    _streamingReasoning = '';
    _thinkingMillis = 0;
    _thinkingActive = false;
  }

  Future<bool> _requestToolPermission(AssistantTool tool) async {
    final always =
        MoodiaryKVs.assistantAlwaysAllowedTools.get() ?? const <String>[];
    if (always.contains(tool.id)) return true;
    if (!mounted) return false;
    final decision = await _permissions.request(tool);
    if (decision == .allowAlways) {
      await MoodiaryKVs.assistantAlwaysAllowedTools.set([...always, tool.id]);
    }
    return decision == .allowOnce || decision == .allowAlways;
  }

  Future<void> _insertPermissionCard(String surfaceId) async {
    if (!mounted) return;
    final card = _chat.permissionCard(surfaceId);
    final streaming = _streamingMessage;
    final msgs = _chat.messages;
    final placeholderIsLast =
        streaming != null && msgs.isNotEmpty && msgs.last.id == streaming.id;
    if (placeholderIsLast && streaming.text.isEmpty) {
      await _chat.insertMessage(card, index: msgs.length - 1);
    } else {
      if (streaming != null && streaming.text.isNotEmpty) {
        final settled = _chat.settled(streaming);
        await _chat.updateMessage(streaming, settled);
        await _chat.persist(settled);
        _purgeStaleReplies();
      }
      await _chat.insertMessage(card);
      final next = _chat.assistantMessage('', streaming: true);
      await _chat.insertMessage(next);
      _streamingMessage = next;
      // 已定稿上一段回复，新气泡的思考从零计（避免把上一段的思考挪到新气泡）。
      _resetThinkingState();
    }
  }

  Future<void> _submit(String text) async {
    text = text.trim();
    final imageName = _pendingImageName;
    if ((text.isEmpty && imageName == null) ||
        _sending ||
        !_disclaimerAccepted) {
      return;
    }
    final imageLabel = context.l10n.assistantImageMessageLabel;
    final gen = ++_generation;
    // 用户开启了新一轮对话：放弃上一次失败重生成遗留的旧回复（保留在库里，不删）。
    _staleReplyIds = [];

    if (_panelController.currentPanelType == .other) {
      _panelController.updatePanelType(.none);
    }

    final base = DateTime.timestamp();
    final userMsg = _chat.userMessage(
      text,
      imageName: imageName,
      createdAt: base,
    );
    await _chat.insertMessage(userMsg);
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
    _permissions.reset();
    _streamingMessage = null;

    final msgs = _chat.messages;
    var lastUserIdx = -1;
    for (var i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      if (m is TextMessage && m.authorId == kAssistantUserId) {
        lastUserIdx = i;
        break;
      }
    }
    if (lastUserIdx == -1) return;
    final userMsg = msgs[lastUserIdx] as TextMessage;

    setState(() => _sending = true);
    // 旧回复先只从内存移除，落库删除推迟到新回复落库后（_purgeStaleReplies），避免重新生成失败时连旧答案一起丢掉。
    final trailing = msgs.sublist(lastUserIdx + 1).toList();
    for (final m in trailing) {
      await _chat.removeMessage(m);
      if (m is TextMessage) _staleReplyIds.add(m.id);
    }
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
    required TextMessage userMessage,
    required DateTime placeholderAt,
  }) async {
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
    final placeholder = _chat.assistantMessage(
      '',
      streaming: true,
      createdAt: placeholderAt,
    );
    await _chat.insertMessage(placeholder);
    _streamingMessage = placeholder;

    final history = _buildHistory();

    final request = await _buildRequest(
      history,
      systemPrompt: systemPrompt,
      volatilePrefix: volatilePrefix,
    );
    if (!mounted || gen != _generation) return;
    if (request == null) {
      _appendDelta(l10n.assistantNeedProvider);
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

    final needApiKeyText = l10n.assistantNeedApiKey;
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
                  // 模型开始调用工具 → 思考阶段结束，冻结计时（不计入工具执行 / 授权等待）。
                  _freezeThinkingOnTool();
                case .usage:
                  _applyUsage(event.inputTokens, event.outputTokens);
              }
            },
            onError: (Object e) {
              if (gen != _generation) return;
              _permissions.cancelPending();
              if (e is AssistantNotConfiguredException) {
                _appendDelta(needApiKeyText);
                _refreshReady();
              } else {
                _appendDelta('\n（出错：$e）');
              }
              _finalizeStreaming(persist: false);
              if (mounted) setState(() => _sending = false);
            },
            onDone: () {
              if (gen != _generation) return;
              _finalizeStreaming(persist: true);
              if (mounted) setState(() => _sending = false);
              // 本轮已落库、拿到 provider 上报的输入 token 后，按阈值尝试压缩上下文。
              unawaited(_maybeCompact());
            },
          );
    } catch (e) {
      _appendDelta('（请求失败：$e）');
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
    for (final m in _chat.messages) {
      if (m is! TextMessage) continue;
      final imageName = IsarChatController.imageNameOf(m);
      final hasImage = imageName.isNotEmpty;
      if (m.text.isEmpty && !hasImage) continue;
      raw.add((
        id: m.id,
        role: m.authorId == kAssistantUserId
            ? AssistantRole.user
            : AssistantRole.assistant,
        content: m.text,
        imagePath: hasImage ? AppFiles.getRealPath('image', imageName) : null,
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
      toast.success(message: l10n.assistantCompactionDone);
    } else {
      toast.info(message: l10n.assistantCompactionNothing);
    }
  }

  Future<ChatSession?> _runCompaction({required bool force}) async {
    final session = _session;
    if (session == null || (!force && _lastTurnInputTokens <= 0)) return null;
    final repo = LlmProviderRepository.get();
    final provider = await repo.getActiveProvider();
    if (provider == null) return null;
    final key = await repo.getKey(provider.id);
    if (key == null || key.isEmpty) return null;
    if (!mounted || _session?.id != session.id) return null;

    final ordered = <CompactionMessage>[
      for (final m in _chat.messages)
        if (m is TextMessage &&
            (m.text.isNotEmpty || IsarChatController.imageNameOf(m).isNotEmpty))
          (
            id: m.id,
            fromUser: m.authorId == kAssistantUserId,
            text: m.text.isEmpty ? '[图片]' : m.text,
          ),
    ];

    final updated = await _compaction.maybeCompact(
      session: session,
      orderedMessages: ordered,
      lastInputTokens: _lastTurnInputTokens,
      contextLimit: _contextLimitFor(provider),
      provider: provider,
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

  /// 解析激活模型的上下文窗口；preset 供应商查本地缓存，自定义 / 未命中用兜底预算。
  int _contextLimitFor(LlmProvider provider) {
    if (provider.providerId.isNotEmpty) {
      for (final preset in LlmPresetRepository.get().cachedPresets()) {
        if (preset.id != provider.providerId) continue;
        for (final model in preset.models) {
          if (model.id == provider.model) {
            return model.contextLimit ?? assistantDefaultContextBudget;
          }
        }
      }
    }
    return assistantDefaultContextBudget;
  }

  /// 按当前会话压缩水位，把提示 chip 对齐到边界：移除旧的、在水位消息后插入新的。
  void _syncCompactionNotice() {
    for (final m in List<Message>.of(_chat.messages)) {
      if (m is CustomMessage && m.metadata?[kCompactionNoticeKey] == true) {
        _chat.removeMessage(m);
      }
    }
    final session = _session;
    final watermark = session?.compactedUpToMessageId;
    if (session?.compactedSummary == null || watermark == null) return;
    final idx = _chat.messages.indexWhere((m) => m.id == watermark);
    if (idx < 0) return;
    _chat.insertMessage(_chat.compactionNotice(watermark), index: idx + 1);
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
    _permissions.cancelPending();
    _finalizeStreaming(persist: true);
    setState(() => _sending = false);
  }

  void _finalizeStreaming({required bool persist}) {
    final cur = _streamingMessage;
    _streamingMessage = null;
    if (cur == null) return;
    if (cur.text.isEmpty) {
      _chat.removeMessage(cur);
    } else {
      final settled = _chat.settled(cur);
      _chat.updateMessage(cur, settled);
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
    final repo = ChatRepository.get();
    for (final id in ids) {
      unawaited(repo.deleteMessage(id));
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

  /// 本轮结束的 token 用量：写回当前流式消息（随后 settled 保留、落库）。
  void _applyUsage(int inputTokens, int outputTokens) {
    if (inputTokens > 0) _lastTurnInputTokens = inputTokens;
    final cur = _streamingMessage;
    if (cur == null || (inputTokens <= 0 && outputTokens <= 0)) return;
    final next = _chat.applyUsage(
      cur,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );
    _chat.updateMessage(cur, next);
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
  void _syncReasoning(TextMessage message) {
    var next = message;
    if (_streamingReasoning.isNotEmpty) {
      next = _chat.applyReasoning(
        next,
        reasoning: _streamingReasoning,
        thinkingMillis: _liveThinkingMillis(),
        active: _thinkingActive,
      );
    }
    final cur = _streamingMessage;
    if (cur == null) return;
    _chat.updateMessage(cur, next);
    _streamingMessage = next;
  }

  void _jumpToBottomSoon() {
    for (final d in const [
      Duration(milliseconds: 16),
      Duration(milliseconds: 180),
    ]) {
      Future.delayed(d, () {
        if (!mounted || !_chatScroll.hasClients) return;
        _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      });
    }
  }

  void _toggleToolPanel() {
    if (_panelController.currentPanelType == .other) {
      _panelController.updatePanelType(.keyboard);
    } else {
      _panelController.updatePanelType(.other, data: .tools);
    }
  }

  Future<void> _pickAndSendDiary() async {
    if (_sending) return;
    _panelController.updatePanelType(.none);
    _inputFocusNode.unfocus();
    final diary = await const AssistantDiaryPickerRoute().push<Diary>(context);
    if (diary == null || !mounted) return;
    await _submit(_formatDiaryMessage(diary));
  }

  /// 相册选一张图，经 MediaManager 转码/压缩存进 image 目录，挂到输入框待发（可再配文字）。
  Future<void> _pickImage() async {
    if (_sending) return;
    _panelController.updatePanelType(.none);
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
    return '${l10n.assistantSendDiaryLead}\n\n【$header】\n$body';
  }

  /// 点击消息列表时收起键盘与工具面板（焦点从输入框移开）。
  void _dismissComposer() {
    if (_panelController.currentPanelType == .other) {
      _panelController.updatePanelType(.none);
    }
    if (_inputFocusNode.hasFocus) _inputFocusNode.unfocus();
  }

  Widget _buildChat() {
    return Chat(
      chatController: _chat,
      currentUserId: kAssistantUserId,
      resolveUser: (id) async => User(id: id),
      theme: .fromThemeData(Theme.of(context)),
      builders: Builders(
        textMessageBuilder: _buildTextMessage,
        customMessageBuilder: _buildCustomMessage,
        composerBuilder: (_) => const SizedBox.shrink(),
        // 只为换图标：ScrollToBottom 默认 Icons.keyboard_arrow_down。
        scrollToBottomBuilder: (context, animation, onPressed) =>
            ScrollToBottom(
              animation: animation,
              onPressed: onPressed,
              icon: const Icon(LucideIcons.chevronDown, size: 22),
            ),
        chatAnimatedListBuilder: (context, itemBuilder) => ChatAnimatedList(
          itemBuilder: itemBuilder,
          scrollController: _chatScroll,
          handleSafeArea: false,
          topPadding: 8,
          bottomPadding: 8,
          physics: const AlwaysScrollableScrollPhysics(),
        ),
      ),
    );
  }

  Widget _buildTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final isLast =
        _chat.messages.isNotEmpty && _chat.messages.last.id == message.id;
    if (isSentByMe) {
      // 用户消息落在末尾（首个 token 前被停止 / 本轮未产出回复）时也给出重试入口。
      return _UserBubble(
        text: message.text,
        imageName: IsarChatController.imageNameOf(message),
        onRetry: (!_sending && isLast) ? _regenerate : null,
      );
    }
    final hasUserTurn = _chat.messages.any(
      (m) => m is TextMessage && m.authorId == kAssistantUserId,
    );
    return _AssistantBubble(
      text: message.text,
      reasoning: IsarChatController.reasoningOf(message),
      thinkingMillis: IsarChatController.thinkingMillisOf(message),
      thinkingActive: IsarChatController.isThinking(message),
      inputTokens: IsarChatController.inputTokensOf(message),
      outputTokens: IsarChatController.outputTokensOf(message),
      streaming: IsarChatController.isStreaming(message),
      onRegenerate: (!_sending && isLast && hasUserTurn) ? _regenerate : null,
    );
  }

  Widget _buildCustomMessage(
    BuildContext context,
    CustomMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    if (message.metadata?[kCompactionNoticeKey] == true) {
      return _CompactionNoticeChip(
        summary: _session?.compactedSummary ?? '',
        onRestore: _restoreFullHistory,
      );
    }
    final surfaceId = message.metadata?[kPermissionSurfaceKey] as String?;
    if (surfaceId == null ||
        !_permissions.surfaces.activeSurfaceIds.contains(surfaceId)) {
      return const SizedBox.shrink();
    }
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth < 400 ? maxWidth : 400),
      child: genui.Surface(
        surfaceContext: _permissions.surfaces.contextFor(surfaceId),
        actionDelegate: _permissionDelegate,
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
      onTool: _toggleToolPanel,
      toolIcon: LucideIcons.plus,
      toolTooltip: context.l10n.assistantToolPanelTitle,
      thinking: _thinking,
      showThinking: _canThink,
      onToggleThinking: _toggleThinking,
      pendingImageName: _pendingImageName,
      onRemoveImage: _removePendingImage,
    );

    return Column(
      children: [
        if (!_ready) _NotConfiguredBanner(onTap: _openSettings),
        Expanded(
          child: Listener(
            behavior: .translucent,
            onPointerDown: (_) => _dismissComposer(),
            child: _buildChat(),
          ),
        ),
        composer,
        ChatBottomPanelContainer<_ToolPanel>(
          controller: _panelController,
          inputFocusNode: _inputFocusNode,
          panelBgColor: context.colorScheme.surfaceContainer,
          otherPanelWidget: (_) => _buildToolPanel(context),
        ),
      ],
    );
  }

  Widget _buildToolPanel(BuildContext context) {
    final l10n = context.l10n;
    final kb = _panelController.keyboardHeight;
    final height = kb > 0 ? kb : 300.0;
    return SizedBox(
      height: height,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const .fromLTRB(20, 18, 20, 8),
          child: Align(
            alignment: .topLeft,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ToolPanelItem(
                  icon: LucideIcons.bookOpen,
                  label: l10n.assistantToolSendDiary,
                  onTap: _pickAndSendDiary,
                ),
                if (_canSendImage)
                  _ToolPanelItem(
                    icon: LucideIcons.image,
                    label: l10n.assistantToolSendImage,
                    onTap: _pickImage,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final Widget chatArea = !_disclaimerAccepted
        ? _DisclaimerGate(onReview: _showDisclaimer)
        : _buildConversation(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_session?.title ?? l10n.assistantNewChat),
        actions: [
          if (_lastTurnInputTokens > 0 && _contextLimit > 0)
            _ContextUsagePill(
              usedTokens: _lastTurnInputTokens,
              contextLimit: _contextLimit,
            ),
          MoodiaryMenuButton<String>(
            tooltip: l10n.assistantMenuTooltip,
            entries: [
              MoodiaryMenuEntry(
                value: 'compact',
                label: l10n.assistantCompactNow,
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

/// AppBar 上下文占用指示：输入 token 占模型窗口百分比，接近/达到压缩阈值时变黄/变红。
class _ContextUsagePill extends StatelessWidget {
  final int usedTokens;
  final int contextLimit;

  const _ContextUsagePill({
    required this.usedTokens,
    required this.contextLimit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
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
          '${context.l10n.assistantContextUsageLabel} $percent% · '
          '$usedTokens / $contextLimit',
      child: Center(
        child: Container(
          margin: const .only(right: 4),
          padding: const .symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: .circular(12),
          ),
          child: Text(
            '$percent%',
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: .w600,
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
    final scheme = context.colorScheme;
    return Center(
      child: Padding(
        padding: const .symmetric(vertical: 8),
        child: InkWell(
          borderRadius: .circular(20),
          onTap: () => _showSheet(context),
          child: Container(
            padding: const .symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: .circular(20),
            ),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  LucideIcons.foldVertical,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.l10n.assistantCompactionNotice,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showMoodiarySheet<void>(
      context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return MoodiarySheetScaffold<void>(
          title: l10n.assistantCompactionSheetTitle,
          icon: LucideIcons.chevronsUpDown,
          actions: [
            MoodiaryAction(label: l10n.cancel),
            MoodiaryAction(
              label: l10n.assistantCompactionRestore,
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
                l10n.assistantCompactionSheetNote,
                style: sheetContext.textTheme.bodySmall?.copyWith(
                  color: sheetContext.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                summary.isEmpty ? '—' : summary,
                style: sheetContext.textTheme.bodyMedium,
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
    final scheme = context.colorScheme;
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
              l10n.assistantDisclaimerGateTitle,
              textAlign: .center,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onReview,
              icon: const Icon(LucideIcons.fileText),
              label: Text(l10n.assistantDisclaimerGateAction),
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
    final scheme = context.colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const .all(12),
          child: Row(
            children: [
              Icon(LucideIcons.triangleAlert, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.assistantNotConfiguredBanner,
                  style: TextStyle(color: scheme.onErrorContainer),
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
  final VoidCallback onTool;
  final IconData toolIcon;
  final String toolTooltip;
  final bool thinking;
  final bool showThinking;
  final VoidCallback onToggleThinking;
  final String? pendingImageName;
  final VoidCallback onRemoveImage;

  const _AssistantComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.onStop,
    required this.onTool,
    required this.toolIcon,
    required this.toolTooltip,
    required this.thinking,
    required this.showThinking,
    required this.onToggleThinking,
    required this.pendingImageName,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const .fromLTRB(12, 6, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: .circular(24),
            ),
            padding: const .fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                if (pendingImageName != null)
                  _ComposerImagePreview(
                    imageName: pendingImageName!,
                    onRemove: onRemoveImage,
                  ),
                // 文字输入区：独占上方，向上增高。
                Padding(
                  padding: const .fromLTRB(8, 2, 8, 6),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !sending,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: .send,
                    decoration: InputDecoration(
                      hintText: l10n.assistantInputHint,
                      border: .none,
                      isCollapsed: true,
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                // 底部控制条：左「深度思考」（模型支持推理才显示），右「+」与发送 / 停止一组。
                Row(
                  children: [
                    if (showThinking)
                      _ThinkingToggle(
                        enabled: thinking,
                        onTap: onToggleThinking,
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: toolTooltip,
                      onPressed: sending ? null : onTool,
                      icon: Icon(toolIcon),
                      color: scheme.onSurfaceVariant,
                      visualDensity: .compact,
                      constraints: const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      padding: .zero,
                    ),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (sending) {
                          return IconButton.filled(
                            tooltip: l10n.assistantStop,
                            onPressed: onStop,
                            icon: const Icon(LucideIcons.square),
                            visualDensity: .compact,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            padding: .zero,
                          );
                        }
                        final canSend =
                            value.text.trim().isNotEmpty ||
                            pendingImageName != null;
                        return IconButton.filled(
                          onPressed: canSend ? onSend : null,
                          icon: const Icon(LucideIcons.arrowUp),
                          visualDensity: .compact,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: .zero,
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
    );
  }
}

class _ThinkingToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ThinkingToggle({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final fg = enabled ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: enabled ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: .min,
            children: [
              Icon(LucideIcons.brain, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                l10n.assistantThinkingToggle,
                style: context.textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: enabled ? .w600 : .w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolPanelItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolPanelItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: .min,
        children: [
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: .circular(18),
            clipBehavior: .antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Icon(icon, color: scheme.primary, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: .ellipsis,
            textAlign: .center,
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 输入框上方的待发图片预览（缩略图 + 右上角移除）。
class _ComposerImagePreview extends StatelessWidget {
  final String imageName;
  final VoidCallback onRemove;

  const _ComposerImagePreview({
    required this.imageName,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const .fromLTRB(8, 6, 8, 2),
      child: Align(
        alignment: .centerLeft,
        child: Stack(
          clipBehavior: .none,
          children: [
            ClipRRect(
              borderRadius: .circular(12),
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
    final scheme = context.colorScheme;
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
            style: TextStyle(color: scheme.onPrimaryContainer),
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
          label: context.l10n.assistantRegenerate,
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

class _AssistantBubble extends StatelessWidget {
  final String text;
  final String reasoning;
  final int thinkingMillis;
  final bool thinkingActive;
  final int inputTokens;
  final int outputTokens;
  final bool streaming;
  final VoidCallback? onRegenerate;

  const _AssistantBubble({
    required this.text,
    required this.reasoning,
    required this.thinkingMillis,
    required this.thinkingActive,
    required this.inputTokens,
    required this.outputTokens,
    required this.streaming,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;

    final hasText = text.isNotEmpty;
    final showThinking = thinkingActive || reasoning.isNotEmpty;

    final decoration = BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: const .only(
        topLeft: .circular(16),
        topRight: .circular(16),
        bottomLeft: .circular(4),
        bottomRight: .circular(16),
      ),
    );
    final constraints = BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * 0.82,
    );

    // 有正文→正文气泡；无正文未思考→转圈气泡；无正文但思考中/已思考→不显示气泡，交给思考块。
    Widget? bubble;
    if (hasText) {
      bubble = Container(
        constraints: constraints,
        padding: const .symmetric(horizontal: 14, vertical: 10),
        decoration: decoration,
        child: SelectionArea(
          child: GptMarkdown(
            text,
            style: TextStyle(color: scheme.onSurface),
            codeBuilder: _codeBlock,
          ),
        ),
      );
    } else if (!showThinking) {
      bubble = Container(
        constraints: constraints,
        padding: const .symmetric(horizontal: 14, vertical: 10),
        decoration: decoration,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final stacked = <Widget>[
      if (showThinking)
        _ThinkingBlock(
          reasoning: reasoning,
          thinkingMillis: thinkingMillis,
          active: thinkingActive,
        ),
      ?bubble,
    ];

    // 流式中或还没有正文：只堆叠思考块 + 气泡，不显示操作按钮。
    if (!hasText || streaming) {
      return Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: stacked,
      );
    }

    final hasTokens = inputTokens > 0 || outputTokens > 0;
    return Column(
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
              label: l10n.assistantCopyTooltip,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: text));
                toast.success(message: l10n.assistantCopied);
              },
            ),
            if (onRegenerate != null)
              _BubbleActionButton(
                icon: LucideIcons.rotateCw,
                label: l10n.assistantRegenerate,
                onTap: onRegenerate!,
              ),
            if (hasTokens)
              Padding(
                padding: const .symmetric(horizontal: 6, vertical: 4),
                child: DefaultTextStyle.merge(
                  style: context.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
    );
  }
}

/// AI 回复上方的思考块：默认折叠，显示思考时长，点击展开思考正文（Markdown）。
class _ThinkingBlock extends StatefulWidget {
  final String reasoning;
  final int thinkingMillis;
  final bool active;

  const _ThinkingBlock({
    required this.reasoning,
    required this.thinkingMillis,
    required this.active,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  String _durationText() {
    final secs = widget.thinkingMillis / 1000;
    if (secs >= 10) return secs.toStringAsFixed(0);
    return (secs < 0.1 ? 0.1 : secs).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final hasReasoning = widget.reasoning.isNotEmpty;
    final label = widget.active
        ? l10n.assistantThinking
        : l10n.assistantThoughtFor(_durationText());

    final header = InkWell(
      borderRadius: .circular(12),
      onTap: hasReasoning ? () => setState(() => _expanded = !_expanded) : null,
      child: Padding(
        padding: const .symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: .min,
          children: [
            if (widget.active)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Icon(LucideIcons.brain, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: .ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasReasoning) ...[
              const SizedBox(width: 2),
              Icon(
                _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );

    return Container(
      margin: const .only(bottom: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: .circular(12),
      ),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          header,
          if (_expanded && hasReasoning)
            Padding(
              padding: const .fromLTRB(12, 0, 12, 10),
              child: SelectionArea(
                child: GptMarkdown(
                  widget.reasoning,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  codeBuilder: _codeBlock,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
    final scheme = context.colorScheme;
    return InkWell(
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
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
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
      appBar: AppBar(
        title: Text(l10n.settingFunctionAIAssistant),
        actions: [
          IconButton(
            tooltip: l10n.assistantConfigTooltip,
            icon: const Icon(LucideIcons.settings),
            onPressed: () => const AssistantSettingRoute().push(context),
          ),
        ],
      ),
      // 「新对话」不在本页了 —— 本页是根壳的一个 tab，入口是底栏胶囊右边那颗按钮
      // （站在助手 tab 上它就是新对话）。
      body: _SessionListView(
        currentId: null,
        onSelect: (session) =>
            AssistantConversationRoute(sessionId: session.id).push(context),
        onDelete: (session) => ChatRepository.get().deleteSession(session.id),
        // 根壳开了 extendBody，底栏整条带高已折进 padding.bottom，直接读来让开。
        padding: .fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
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
    final scheme = context.colorScheme;
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
            context.l10n.assistantHistoryEmpty,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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
    final ok = await showMoodiaryConfirm(
      context,
      title: l10n.assistantSessionDelete,
      message: session.title,
      confirmLabel: l10n.assistantSessionDelete,
      isDestructive: true,
    );
    if (ok) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
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
            color: selected ? scheme.onSecondaryContainer : scheme.primary,
          ),
        ),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: .ellipsis,
          style: context.textTheme.titleSmall?.copyWith(color: onColor),
        ),
        subtitle: Text(
          TimeFormat.relative(session.updatedAt),
          style: context.textTheme.labelSmall?.copyWith(
            color: selected
                ? scheme.onSecondaryContainer.withValues(alpha: 0.8)
                : scheme.onSurfaceVariant,
          ),
        ),
        trailing: MoodiaryMenuButton<String>(
          tooltip: l10n.more,
          onSelected: (_) => _confirmDelete(context),
          entries: [
            MoodiaryMenuEntry(
              value: 'delete',
              label: l10n.assistantSessionDelete,
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
