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
import 'package:moodiary/app/router/router.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/core/values/assistant.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/feature/assistant/application/isar_chat_controller.dart';
import 'package:moodiary/feature/assistant/application/tool_permission_coordinator.dart';
import 'package:moodiary/feature/assistant/data/assistant.dart';
import 'package:moodiary/feature/assistant/presentation/tool_permission_card.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

/// 底部工具面板里的自定义面板类型（chat_bottom_container 的泛型 data）。
enum _ToolPanel { tools }

class AssistantPage extends ConsumerStatefulWidget {
  /// 会话详情页要打开的会话 id（null = 新会话）。
  final String? initialSessionId;

  const AssistantPage({super.key, this.initialSessionId});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _chatScroll = ScrollController();

  /// flutter_chat_ui 的消息控制器，背靠 Isar；流式增量经其 updateMessage 就地刷新单条消息，
  /// 列表位置在 AI 生成时保持稳定。
  late final IsarChatController _chat;

  /// 底部「键盘 ↔ 工具面板」平滑切换控制器（仅移动端使用）。
  final _panelController = ChatBottomPanelContainerController<_ToolPanel>();

  StreamSubscription<String>? _streamSub;

  /// 当前正在流式写入的助手占位泡；为 null 表示没有进行中的回复。
  TextMessage? _streamingMessage;

  /// 单调递增的「发送代次」。停止 / 切换 / 新建会话时自增，使停在 await 上的旧
  /// 一次发送在恢复后能识别自己已被取代而提前退出（避免订阅泄漏 / 交叉串流）。
  int _generation = 0;

  bool _sending = false;
  bool _ready = true;
  bool _initialized = false;

  /// 工具权限走 GenUI 卡片（A2UI surface），不再弹模态框。
  late final ToolPermissionCoordinator _permissions;
  late final ToolPermissionActionDelegate _permissionDelegate;

  /// null 表示尚未落库的新会话（首次发送时创建）。
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
    _refreshReady();
    // 延到下一帧弹免责声明，此时 context 可用。
    if (!_disclaimerAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDisclaimer();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首帧（context / l10n 可用）决定初始内容：打开指定会话或新会话。
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

  TextMessage _welcome() => _chat.assistantMessage(context.l10n.assistantWelcome);

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
      // 目标会话已不存在（脏 id / 深链失效）：退回列表，避免误当新会话落库。
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
    await _chat.loadSession(session.id);
    if (!mounted) return;
    setState(() {
      _session = session;
      _sending = false;
    });
    _jumpToBottomSoon();
  }

  /// 确保会话已落库；新会话用首条用户消息截断作标题、绑定当前激活 Provider。
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

  /// 同意后持久化并解锁聊天界面；拒绝保持「门」状态。
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

  /// 按激活 Provider 组装请求；Provider 缺失或无 Key 返回 null。[systemPrompt] 由调用方按界面语言生成。
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
      onToolPermission: _requestToolPermission,
    );
  }

  /// 命中「始终允许」直接放行；否则在聊天流里插一张 GenUI 权限卡片等用户决定，
  /// 决定后卡片原地更新为结果态（不移除）。
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

  /// 把权限卡片插入聊天流。占位泡尚无内容时插在其前（后续增量仍写入占位泡，
  /// 显示在卡片下方）；已有内容则先固化落库该段，卡片之后另起新泡接续。
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
      }
      await _chat.insertMessage(card);
      final next = _chat.assistantMessage('', streaming: true);
      await _chat.insertMessage(next);
      _streamingMessage = next;
    }
  }

  Future<void> _submit(String text) async {
    text = text.trim();
    if (text.isEmpty || _sending || !_disclaimerAccepted) return;
    final l10n = context.l10n;
    // 在 await 前取，避免跨异步用 context。
    final systemPrompt = buildAssistantSystemPrompt(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final gen = ++_generation;

    // 发送即收起底部工具面板，避免回复期间面板一直占据底部空间。
    if (_panelController.currentPanelType == ChatBottomPanelType.other) {
      _panelController.updatePanelType(ChatBottomPanelType.none);
    }

    final base = DateTime.timestamp();
    final userMsg = _chat.userMessage(text, createdAt: base);
    final placeholder = _chat.assistantMessage(
      '',
      streaming: true,
      createdAt: base.add(const Duration(milliseconds: 1)),
    );
    await _chat.insertMessage(userMsg);
    await _chat.insertMessage(placeholder);
    _streamingMessage = placeholder;
    _inputController.clear();
    setState(() => _sending = true);

    final history = _buildHistory();

    final request = await _buildRequest(history, systemPrompt: systemPrompt);
    // 在 await 期间被停止 / 切换会话 / 页面卸载：本次发送已作废，直接退出。
    if (!mounted || gen != _generation) return;
    if (request == null) {
      _appendDelta(l10n.assistantNeedProvider);
      _finalizeStreaming(persist: false);
      await _refreshReady();
      if (mounted && gen == _generation) setState(() => _sending = false);
      return;
    }

    // assistant 回复在 onDone 落库。
    final session = await _ensureSession(text);
    if (!mounted || gen != _generation) return;
    if (session != null) {
      await _chat.persist(userMsg);
      if (!mounted || gen != _generation) return;
    }

    try {
      _streamSub = AssistantService.get()
          .chat(request)
          .listen(
            (delta) {
              if (gen != _generation) return;
              _appendDelta(delta);
            },
            onError: (Object e) {
              if (gen != _generation) return;
              _permissions.cancelPending();
              if (e is AssistantNotConfiguredException) {
                _appendDelta(l10n.assistantNeedApiKey);
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

  /// 组装多轮上下文：只取文本项，且合并相邻同角色段（权限卡片会把一次回复
  /// 切成多段，部分 provider 不接受连续同角色消息）。
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

  /// 取消订阅经 async* 链路传到 Rust 中断在途请求；在途权限申请一并取消
  /// （卡片置「已取消」）；落库部分回复，无 token 则移除空占位泡。
  void _stop() {
    if (!_sending) return;
    _generation++;
    _streamSub?.cancel();
    _streamSub = null;
    _permissions.cancelPending();
    _finalizeStreaming(persist: true);
    setState(() => _sending = false);
  }

  /// 收尾流式占位泡：空泡移除；非空泡清掉流式标记（露出复制按钮），按需落库。
  void _finalizeStreaming({required bool persist}) {
    final cur = _streamingMessage;
    _streamingMessage = null;
    if (cur == null) return;
    if (cur.text.isEmpty) {
      _chat.removeMessage(cur);
    } else {
      final settled = _chat.settled(cur);
      _chat.updateMessage(cur, settled);
      if (persist) _chat.persist(settled);
    }
  }

  void _appendDelta(String delta) {
    final cur = _streamingMessage;
    if (cur == null || delta.isEmpty) return;
    final next = cur.copyWith(text: cur.text + delta);
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

  // ---- 工具面板 / 发送日记 ----

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

  // ---- 构建 ----

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
          // 用平台默认滚动效果（Android 拉伸 / iOS 回弹）并始终可拖动，
          // AlwaysScrollableScrollPhysics 会叠加到平台 physics 之上。
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
    if (isSentByMe) return _UserBubble(text: message.text);
    return _AssistantBubble(
      text: message.text,
      streaming: IsarChatController.isStreaming(message),
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
    );

    return Column(
      children: [
        if (!_ready) _NotConfiguredBanner(onTap: _openSettings),
        Expanded(child: _buildChat()),
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

    // 作为「会话详情」二级页（全屏 push 盖过玻璃底栏）。会话列表是 Tab 根页
    // [AssistantSessionListPage]，新建对话由玻璃底栏按钮触发。
    // resizeToAvoidBottomInset 关闭：底部 inset 交给 chat_bottom_container 接管，键盘↔面板平滑切换。
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

/// 聊天输入条：工具按钮 + 多行输入框 + 发送/停止。移动端工具按钮切换底部面板，
/// 桌面端工具按钮直接打开日记选择页。
class _AssistantComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onTool;
  final IconData toolIcon;
  final String toolTooltip;

  const _AssistantComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.onStop,
    required this.onTool,
    required this.toolIcon,
    required this.toolTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    // 底部 inset 由 chat_bottom_container 接管，这里不再额外留白。
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: toolTooltip,
              onPressed: sending ? null : onTool,
              icon: Icon(toolIcon),
              color: scheme.onSurfaceVariant,
            ),
            Expanded(
              child: Container(
                decoration: ShapeDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (sending) {
                          return IconButton.filled(
                            tooltip: l10n.assistantStop,
                            onPressed: onStop,
                            icon: const Icon(Icons.stop_rounded),
                          );
                        }
                        final canSend = value.text.trim().isNotEmpty;
                        return IconButton.filled(
                          onPressed: canSend ? onSend : null,
                          icon: const Icon(Icons.arrow_upward_rounded),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具面板里的一个工具项（圆角图标 + 标签）。
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

/// 用户气泡：右侧、primaryContainer 底色、可选中文本。对齐由 flutter_chat_ui 外层包装负责。
class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
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
  }
}

/// 助手气泡：左侧、surfaceContainerHighest 底色、markdown 渲染。空泡显示「思考中」转圈，
/// 非流式时下方带复制按钮。
class _AssistantBubble extends StatelessWidget {
  final String text;
  final bool streaming;

  const _AssistantBubble({required this.text, required this.streaming});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: text.isEmpty
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : SelectionArea(
              child: GptMarkdown(
                text,
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
    );

    if (text.isEmpty || streaming) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [bubble, _CopyButton(text: text)],
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String text;

  const _CopyButton({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        toast.success(message: l10n.assistantCopied);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              l10n.assistantCopyTooltip,
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

/// 移动端「智能助手」Tab 根页：会话管理列表。新建对话由玻璃底栏按钮触发（push 会话详情页）。
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
            tooltip: l10n.assistantNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => const AssistantConversationRoute().push(context),
          ),
          IconButton(
            tooltip: l10n.assistantConfigTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => const AssistantSettingRoute().push(context),
          ),
        ],
      ),
      body: _SessionListView(
        currentId: null,
        onSelect: (session) =>
            AssistantConversationRoute(sessionId: session.id).push(context),
        onDelete: (session) => ChatRepository.get().deleteSession(session.id),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      ),
    );
  }
}

/// 会话列表（自订阅 [ChatRepository.sessionEvents] 实时刷新）；桌面侧栏与移动端列表页共用。
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
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final textTheme = context.textTheme;
    final sessions = _sessions;
    return switch (sessions) {
      null => const Center(child: CircularProgressIndicator()),
      [] => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.assistantHistoryEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      final list => ListView.builder(
        padding: widget.padding,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final session = list[index];
          final selected = session.id == widget.currentId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Material(
              color: selected
                  ? scheme.secondaryContainer
                  : Colors.transparent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => widget.onSelect(session),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.chat_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: selected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              color: selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.assistantSessionDelete,
                        iconSize: 18,
                        color: selected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => widget.onDelete(session),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    };
  }
}
