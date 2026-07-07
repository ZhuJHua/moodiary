import 'dart:async';

import 'package:chat_bottom_container/chat_bottom_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide DateFormat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart' as genui;
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_assistant/src/routes.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_assistant/src/application/isar_chat_controller.dart';
import 'package:moodiary_assistant/src/application/tool_permission_coordinator.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/presentation/tool_permission_card.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

enum _ToolPanel { tools }

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

  late final ToolPermissionCoordinator _permissions;
  late final ToolPermissionActionDelegate _permissionDelegate;

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
    if (mounted) setState(() => _ready = ready);
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
      _sending = false;
    });
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
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.privacy_tip_outlined),
        title: Text(l10n.assistantDisclaimerTitle),
        content: SingleChildScrollView(
          child: Text(l10n.assistantDisclaimerContent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.assistantDisclaimerDecline),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantDisclaimerAgree),
          ),
        ],
      ),
    );
    if (agreed == true) {
      await MoodiaryKVs.assistantDisclaimerAccepted.set(true);
      if (!mounted) return;
      setState(() => _disclaimerAccepted = true);
      await _refreshReady();
    }
  }

  Future<AssistantChatRequest?> _buildRequest(
    List<AssistantMessage> history, {
    required String systemPrompt,
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
      maxTokens: assistantMaxTokens,
      history: history,
      thinking: _thinking,
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
    if (decision == ToolPermissionDecision.allowAlways) {
      await MoodiaryKVs.assistantAlwaysAllowedTools.set([...always, tool.id]);
    }
    return decision == ToolPermissionDecision.allowOnce ||
        decision == ToolPermissionDecision.allowAlways;
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
    if (text.isEmpty || _sending || !_disclaimerAccepted) return;
    final gen = ++_generation;
    // 用户开启了新一轮对话：放弃上一次失败重生成遗留的旧回复（保留在库里，不删）。
    _staleReplyIds = [];

    if (_panelController.currentPanelType == ChatBottomPanelType.other) {
      _panelController.updatePanelType(ChatBottomPanelType.none);
    }

    final base = DateTime.timestamp();
    final userMsg = _chat.userMessage(text, createdAt: base);
    await _chat.insertMessage(userMsg);
    _inputController.clear();
    setState(() => _sending = true);

    await _generate(
      gen: gen,
      sessionSeedText: text,
      userMessage: userMsg,
      placeholderAt: base.add(const Duration(milliseconds: 1)),
    );
  }

  /// 重新回答：删掉最后一条用户消息之后的所有内容（AI 回复、权限卡片、报错文本），
  /// 再基于同一条用户消息重新跑一次生成。停止/报错后也可用它重试。
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
    // 旧回复只从内存移除；真正的落库删除推迟到新回复成功落库后（_purgeStaleReplies），
    // 这样重新生成失败（网络错误 / 供应商被移除）不会连旧答案一起丢掉。
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
      placeholderAt: DateTime.timestamp(),
    );
  }

  Future<void> _generate({
    required int gen,
    required String sessionSeedText,
    required TextMessage userMessage,
    required DateTime placeholderAt,
  }) async {
    final l10n = context.l10n;
    final systemPrompt = buildAssistantSystemPrompt(
      Localizations.localeOf(context).toLanguageTag(),
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

    final request = await _buildRequest(history, systemPrompt: systemPrompt);
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
                case AssistantStreamKind.text:
                  _appendDelta(event.text);
                case AssistantStreamKind.reasoning:
                  _appendReasoning(event.text);
                case AssistantStreamKind.tool:
                  // 模型开始调用工具 → 思考阶段结束，冻结计时（不计入工具执行 / 授权等待）。
                  _freezeThinkingOnTool();
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
            },
          );
    } catch (e) {
      _appendDelta('（请求失败：$e）');
      _finalizeStreaming(persist: false);
      if (mounted) setState(() => _sending = false);
    }
  }

  List<AssistantMessage> _buildHistory() {
    final result = <AssistantMessage>[];
    for (final m in _chat.messages) {
      if (m is! TextMessage || m.text.isEmpty) continue;
      final role = m.authorId == kAssistantUserId
          ? AssistantRole.user
          : AssistantRole.assistant;
      if (result.isNotEmpty && result.last.role == role) {
        result.last = AssistantMessage(
          role,
          '${result.last.content}\n\n${m.text}',
        );
      } else {
        result.add(AssistantMessage(role, m.text));
      }
    }
    return result;
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
    if (_panelController.currentPanelType == ChatBottomPanelType.other) {
      _panelController.updatePanelType(ChatBottomPanelType.keyboard);
    } else {
      _panelController.updatePanelType(
        ChatBottomPanelType.other,
        data: _ToolPanel.tools,
      );
    }
  }

  Future<void> _pickAndSendDiary() async {
    if (_sending) return;
    _panelController.updatePanelType(ChatBottomPanelType.none);
    _inputFocusNode.unfocus();
    final diary = await const AssistantDiaryPickerRoute().push<Diary>(context);
    if (diary == null || !mounted) return;
    await _submit(_formatDiaryMessage(diary));
  }

  String _formatDiaryMessage(Diary diary) {
    final l10n = context.l10n;
    final date = DateFormat.yMMMMEEEEd().format(diary.time);
    final title = diary.title.trim();
    final header = title.isEmpty ? date : '$date · $title';
    final body = diary.contentText.trim();
    return '${l10n.assistantSendDiaryLead}\n\n【$header】\n$body';
  }

  /// 点击消息列表时收起键盘与工具面板（焦点从输入框移开）。
  void _dismissComposer() {
    if (_panelController.currentPanelType == ChatBottomPanelType.other) {
      _panelController.updatePanelType(ChatBottomPanelType.none);
    }
    if (_inputFocusNode.hasFocus) _inputFocusNode.unfocus();
  }

  Widget _buildChat() {
    return Chat(
      chatController: _chat,
      currentUserId: kAssistantUserId,
      resolveUser: (id) async => User(id: id),
      theme: ChatTheme.fromThemeData(Theme.of(context)),
      builders: Builders(
        textMessageBuilder: _buildTextMessage,
        customMessageBuilder: _buildCustomMessage,
        composerBuilder: (_) => const SizedBox.shrink(),
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
      toolIcon: Icons.add_rounded,
      toolTooltip: context.l10n.assistantToolPanelTitle,
      thinking: _thinking,
      onToggleThinking: _toggleThinking,
    );

    return Column(
      children: [
        if (!_ready) _NotConfiguredBanner(onTap: _openSettings),
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Align(
            alignment: Alignment.topLeft,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ToolPanelItem(
                  icon: Icons.auto_stories_rounded,
                  label: l10n.assistantToolSendDiary,
                  onTap: _pickAndSendDiary,
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
      appBar: AppBar(title: Text(_session?.title ?? l10n.assistantNewChat)),
      body: chatArea,
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.assistantDisclaimerGateTitle,
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onReview,
              icon: const Icon(Icons.description_outlined),
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
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
  final VoidCallback onToggleThinking;

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
    required this.onToggleThinking,
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
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 文字输入区：独占上方，向上增高。
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !sending,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: l10n.assistantInputHint,
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                // 底部控制条：左「+」「深度思考」对齐，右发送 / 停止。
                Row(
                  children: [
                    IconButton(
                      tooltip: toolTooltip,
                      onPressed: sending ? null : onTool,
                      icon: Icon(toolIcon),
                      color: scheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 6),
                    _ThinkingToggle(enabled: thinking, onTap: onToggleThinking),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (sending) {
                          return IconButton.filled(
                            tooltip: l10n.assistantStop,
                            onPressed: onStop,
                            icon: const Icon(Icons.stop_rounded),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            padding: EdgeInsets.zero,
                          );
                        }
                        final canSend = value.text.trim().isNotEmpty;
                        return IconButton.filled(
                          onPressed: canSend ? onSend : null,
                          icon: const Icon(Icons.arrow_upward_rounded),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_rounded, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                l10n.assistantThinkingToggle,
                style: context.textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: enabled ? FontWeight.w600 : FontWeight.w400,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
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
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _UserBubble({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: SelectableText(
        text,
        style: TextStyle(color: scheme.onPrimaryContainer),
      ),
    );
    if (onRetry == null) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        _BubbleActionButton(
          icon: Icons.refresh_rounded,
          label: context.l10n.assistantRegenerate,
          onTap: onRetry!,
        ),
      ],
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;
  final String reasoning;
  final int thinkingMillis;
  final bool thinkingActive;
  final bool streaming;
  final VoidCallback? onRegenerate;

  const _AssistantBubble({
    required this.text,
    required this.reasoning,
    required this.thinkingMillis,
    required this.thinkingActive,
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
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      ),
    );
    final constraints = BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * 0.82,
    );

    // 有正文 → 正文气泡；无正文且未在思考 → 初始转圈气泡；
    // 无正文但正在 / 已思考 → 不显示气泡，交给上方思考块。
    Widget? bubble;
    if (hasText) {
      bubble = Container(
        constraints: constraints,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: decoration,
        child: SelectionArea(
          child: GptMarkdown(text, style: TextStyle(color: scheme.onSurface)),
        ),
      );
    } else if (!showThinking) {
      bubble = Container(
        constraints: constraints,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: stacked,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...stacked,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BubbleActionButton(
              icon: Icons.copy_rounded,
              label: l10n.assistantCopyTooltip,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: text));
                toast.success(message: l10n.assistantCopied);
              },
            ),
            if (onRegenerate != null)
              _BubbleActionButton(
                icon: Icons.refresh_rounded,
                label: l10n.assistantRegenerate,
                onTap: onRegenerate!,
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
      borderRadius: BorderRadius.circular(12),
      onTap: hasReasoning ? () => setState(() => _expanded = !_expanded) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
              Icon(
                Icons.psychology_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasReasoning) ...[
              const SizedBox(width: 2),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          if (_expanded && hasReasoning)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SelectionArea(
                child: GptMarkdown(
                  widget.reasoning,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => const AssistantSettingRoute().push(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // 唯一 heroTag：本页作为底部导航 tab 与首页 FAB 在 IndexedStack 中同时存活。
        heroTag: 'assistantSessionFab',
        onPressed: () => const AssistantConversationRoute().push(context),
        icon: const Icon(Icons.add_comment_rounded),
        label: Text(l10n.assistantNewChat),
      ),
      body: _SessionListView(
        currentId: null,
        onSelect: (session) =>
            AssistantConversationRoute(sessionId: session.id).push(context),
        onDelete: (session) => ChatRepository.get().deleteSession(session.id),
        // 底部留白，避免 FAB 遮住最后一条会话。
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
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
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
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

  static String _relativeTime(BuildContext context, DateTime utc) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final t = utc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    if (that == today) return DateFormat.Hm(locale).format(t);
    if (t.year == now.year) return DateFormat.MMMd(locale).format(t);
    return DateFormat.yMMMd(locale).format(t);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantSessionDelete),
        content: Text(session.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantSessionDelete),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final onColor = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected
                ? scheme.onSecondaryContainer.withValues(alpha: 0.12)
                : scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.forum_rounded,
            size: 22,
            color: selected ? scheme.onSecondaryContainer : scheme.primary,
          ),
        ),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleSmall?.copyWith(color: onColor),
        ),
        subtitle: Text(
          _relativeTime(context, session.updatedAt),
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
              icon: Icons.delete_outline_rounded,
              isDestructive: true,
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
