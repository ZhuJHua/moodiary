import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/application/context_compaction_controller.dart';
import 'package:moodiary_assistant/src/application/session_title_controller.dart';
import 'package:moodiary_assistant/src/data/agent_preset_repository.dart';
import 'package:moodiary_assistant/src/data/agent_preset_resolver.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_assistant/src/data/chat_repository.dart';
import 'package:moodiary_assistant/src/data/llm_provider_repository.dart';
import 'package:moodiary_assistant/src/data/memory_repository.dart';
import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_assistant/src/presentation/agent_preset_sheet.dart';
import 'package:moodiary_assistant/src/presentation/assistant_notice.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:moodiary_assistant/src/presentation/markdown_code_block.dart';
import 'package:moodiary_assistant/src/presentation/model_picker_sheet.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

enum _ComposerTool { diary, image }

const double _kComposerControlSize = 40;

const double _kComposerPadding = 8;

const double _kTitleInset = 6;

double _toolbarHeight(BuildContext context) {
  final typography = context.theme.typography;
  final scaler = MediaQuery.textScalerOf(context);
  double lineOf(TextStyle style) =>
      scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.4);
  final needed =
      lineOf(typography.titleMedium.emphasized.onSurface) +
      lineOf(typography.labelSmall.onSurfaceVariant) +
      20;
  return math.max(kToolbarHeight, needed);
}

Widget _codeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) => MarkdownCodeBlock(name: name, code: code);

class AssistantPage extends StatefulWidget {
  final String? initialSessionId;

  const AssistantPage({super.key, this.initialSessionId});

  factory AssistantPage.fromRoute(GoRouterState state) =>
      AssistantPage(initialSessionId: state.params['session_id'] as String?);

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

String _sessionTitle(ChatSession? session, Translations l10n) {
  final title = session?.title.trim() ?? '';
  return title.isEmpty ? l10n.assistant.newChat : title;
}

class _AssistantPageState extends State<AssistantPage> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _chatScroll = ScrollController();
  final _listKey = GlobalKey<AssistantChatListState>();

  late final AssistantChatController _chat;

  StreamSubscription<AssistantStreamEvent>? _streamSub;

  AssistantTurn? _streamingMessage;

  DateTime? _reasoningStart;
  String _streamingReasoning = '';
  int _thinkingMillis = 0;
  bool _thinkingActive = false;

  List<String> _staleReplyIds = [];

  int _generation = 0;

  bool _sending = false;
  bool _ready = true;
  bool _initialized = false;

  String _reasoningLevel = '';

  LlmProvider? _provider;
  String _modelId = '';

  bool _canSendImage = false;

  List<String> _reasoningLevels = const [];

  LlmModelPreset? _activeModel;

  int _maxTokens = assistantFallbackMaxTokens;

  bool _canUseTools = true;

  String? _pendingImageName;

  final ContextCompactionController _compaction = ContextCompactionController();
  final SessionTitleController _title = SessionTitleController();

  int _lastTurnInputTokens = 0;

  int _contextLimit = assistantDefaultContextBudget;

  double _composerHeight = 0;

  ChatSession? _session;

  bool _disclaimerAccepted = false;

  String _stagedProviderId = '';

  String _stagedPresetId = builtinAgentPresetId;

  bool _presetPickedExplicitly = false;

  String? _presetName;

  bool _presetMissing = false;

  @override
  void initState() {
    super.initState();
    _chat = AssistantChatController();
    _disclaimerAccepted =
        MoodiaryKVs.assistantDisclaimerAccepted.get() ?? false;
    _reasoningLevel = MoodiaryKVs.assistantReasoningEffort.get() ?? '';
    _refreshReady();
    unawaited(_initStagedPreset());
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
    final repo = getIt<LlmProviderRepository>();
    final session = _session;
    final pinned = session == null || session.providerId.isEmpty
        ? null
        : await repo.getProvider(session.providerId);
    final staged = pinned != null || _stagedProviderId.isEmpty
        ? null
        : await repo.getProvider(_stagedProviderId);
    final provider = pinned ?? staged ?? await repo.getActiveProvider();
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
        if (_reasoningLevel.isNotEmpty && !levels.contains(_reasoningLevel)) {
          _reasoningLevel = '';
        }
        if (!caps.attachment) _pendingImageName = null;
      });
    }
  }

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

  Future<void> _pickModel() async {
    if (_sending) return;
    final repo = getIt<LlmProviderRepository>();
    final providers = await repo.getAllProviders();
    final groups = <ProviderModels>[];
    for (final p in providers) {
      final options = ModelResolver.optionsFor(p);
      if (options.isEmpty) continue;
      final key = await repo.getKey(p.id);
      groups.add((
        provider: p,
        options: options,
        hasKey: key != null && key.isNotEmpty,
      ));
    }
    if (groups.isEmpty || !mounted) return;
    final choice = await showGlobalModelPicker(
      context,
      groups: groups,
      providerId: _provider?.id ?? '',
      modelId: _modelId,
      level: _reasoningLevel,
    );
    if (choice == null || !mounted) return;
    final session = _session;
    if (session != null) {
      final updated = session.copyWith(
        providerId: choice.providerId,
        model: choice.modelId,
        reasoningEffort: choice.level,
      );
      await getIt<ChatRepository>().upsertSession(updated);
      if (!mounted) return;
      setState(() => _session = updated);
    }
    setState(() {
      _stagedProviderId = choice.providerId;
      _modelId = choice.modelId;
      _reasoningLevel = choice.level;
    });
    MoodiaryKVs.assistantReasoningEffort.set(choice.level);
    await _refreshReady();
  }

  Future<void> _loadSessionById(String id) async {
    final session = await getIt<ChatRepository>().getSession(id);
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
      _reasoningLevel = session.reasoningEffort;
      _pendingImageName = null;
      _sending = false;
    });
    await _refreshReady();
    if (!mounted) return;
    await _syncPresetLabel(session);
    if (!mounted) return;
    _syncCompactionNotice();
    _syncModelSwitchNotices();
    _listKey.currentState?.pinToBottom();
  }

  Future<void> _initStagedPreset() async {
    final id = await AgentPresetResolver.defaultId();
    if (!mounted || _session != null) return;
    final preset = id == builtinAgentPresetId
        ? null
        : await getIt<AgentPresetRepository>().get(id);
    if (!mounted || _session != null) return;
    setState(() {
      _stagedPresetId = preset == null ? builtinAgentPresetId : preset.id;
      _presetName = preset?.name;
    });
  }

  Future<void> _syncPresetLabel(ChatSession session) async {
    final id = session.agentPresetId;
    if (id == null || id.isEmpty) {
      setState(() {
        _presetName = null;
        _presetMissing = false;
      });
      return;
    }
    final preset = await getIt<AgentPresetRepository>().get(id);
    if (!mounted || _session?.id != session.id) return;
    setState(() {
      _presetName = preset?.name;
      _presetMissing = preset == null;
    });
  }

  Future<ChatSession?> _ensureSession(
    String firstUserText, {
    required String persona,
    List<String>? tools,
  }) async {
    final existing = _session;
    if (existing != null) return existing;
    final provider = _provider;
    if (provider == null) return null;
    final session = ChatSession.create(
      providerId: provider.id,
      model: _modelId,
      reasoningEffort: _reasoningLevel,
      agentPresetId: _stagedPresetId.isEmpty ? null : _stagedPresetId,
      personaSnapshot: _stagedPresetId.isEmpty ? null : persona,
      toolsSnapshot: _stagedPresetId.isEmpty ? null : tools,
    );
    await getIt<ChatRepository>().upsertSession(session);
    _chat.sessionId = session.id;
    if (mounted) setState(() => _session = session);
    unawaited(_generateTitle(session, firstUserText));
    return session;
  }

  Future<void> _generateTitle(ChatSession session, String firstUserText) async {
    final provider = _provider;
    if (provider == null) return;
    final key = await getIt<LlmProviderRepository>().getKey(provider.id);
    if (key == null || key.isEmpty) return;
    if (!mounted || _session?.id != session.id) return;

    final updated = await _title.maybeTitle(
      session: session,
      firstUserText: firstUserText,
      provider: provider,
      model: _modelId,
      apiKey: key,
    );
    if (updated == null || !mounted || _session?.id != session.id) return;
    await getIt<ChatRepository>().upsertSession(updated);
    if (!mounted || _session?.id != session.id) return;
    setState(() => _session = updated);
  }

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
      ..selection = TextSelection.collapsed(offset: edited.length);
    _inputFocusNode.requestFocus();
  }

  Future<void> _openSettings() async {
    await const AssistantSettingRoute().push(context);
    await _refreshReady();
    if (_session == null && !_presetPickedExplicitly) {
      await _initStagedPreset();
    }
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
    required bool toolsActive,
    List<String>? allowedTools,
  }) async {
    final provider = _provider;
    if (provider == null) return null;
    final key = await getIt<LlmProviderRepository>().getKey(provider.id);
    if (key == null || key.isEmpty) return null;
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
      tools: toolsActive,
      allowedTools: allowedTools,
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
    final trailing = items.sublist(lastUserIdx + 1).toList();
    _chat.batch(() {
      for (final m in trailing) {
        _chat.remove(m);
        if (m is AssistantTurn) _staleReplyIds.add(m.id);
      }
    });
    _syncModelSwitchNotices();
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
    _listKey.currentState?.pinToBottom();
    final l10n = context.l10n;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final currentSession = _session;
    final String persona;
    final List<String>? allowedTools;
    if (currentSession != null) {
      persona = currentSession.personaSnapshot ?? defaultPersona;
      allowedTools = currentSession.toolsSnapshot;
    } else {
      final mount = await AgentPresetResolver.mountFor(_stagedPresetId);
      persona = mount.persona;
      allowedTools = mount.tools;
    }
    final toolsActive =
        _canUseTools && (allowedTools == null || allowedTools.isNotEmpty);
    final memories = await getIt<MemoryRepository>().getRecent(
      memoryInjectionLimit,
    );
    if (!mounted || gen != _generation) return;
    final systemPrompt = buildStableSystemPrompt(
      persona: persona,
      toolsEnabled: toolsActive,
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
      model: _modelId,
    );
    _chat.beginStreaming(placeholder);
    _streamingMessage = placeholder;
    _syncModelSwitchNotices();

    final history = _buildHistory();

    final request = await _buildRequest(
      history,
      systemPrompt: systemPrompt,
      volatilePrefix: volatilePrefix,
      toolsActive: toolsActive,
      allowedTools: allowedTools,
    );
    if (!mounted || gen != _generation) return;
    if (request == null) {
      _appendDelta(l10n.assistant.needProvider);
      _finalizeStreaming(persist: false);
      await _refreshReady();
      if (mounted && gen == _generation) setState(() => _sending = false);
      return;
    }

    final session = await _ensureSession(
      sessionSeedText,
      persona: persona,
      tools: allowedTools,
    );
    if (!mounted || gen != _generation) return;
    if (session != null) {
      await _chat.persist(userMessage);
      if (!mounted || gen != _generation) return;
    }

    final needApiKeyText = l10n.assistant.needApiKey;
    var errored = false;
    try {
      _streamSub = getIt<AssistantService>()
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
              _finalizeStreaming(persist: true);
              if (mounted) setState(() => _sending = false);
            },
            onDone: () {
              if (gen != _generation) return;
              if (errored) return;
              _finalizeStreaming(persist: true);
              if (mounted) setState(() => _sending = false);
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

    final session = _session;
    final summary = session?.compactedSummary;
    final watermark = session?.compactedUpToMessageId;
    var start = 0;
    if (summary != null && summary.isNotEmpty && watermark != null) {
      final at = raw.indexWhere((e) => e.id == watermark);
      if (at >= 0) start = at + 1;
    }
    final kept = raw.sublist(start);

    final result = <AssistantMessage>[];
    if (start > 0 && summary != null && summary.isNotEmpty) {
      result
        ..add(.user('[Summary of earlier conversation]\n$summary'))
        ..add(const .assistant('Understood — I have the earlier context.'));
    }

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

  String _withToolRecord(AssistantTurn turn) {
    final record = AssistantToolRegistry.recordOf(turn.toolCalls);
    if (record.isEmpty) return turn.text;
    return turn.text.isEmpty ? record : '$record\n\n${turn.text}';
  }

  Future<ChatSession?> _maybeCompact() async {
    final session = _session;
    if (session == null || _lastTurnInputTokens <= 0) return null;
    final provider = _provider;
    if (provider == null) return null;
    final key = await getIt<LlmProviderRepository>().getKey(provider.id);
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
    );
    if (updated == null || !mounted || _session?.id != session.id) return null;
    await getIt<ChatRepository>().upsertSession(updated);
    if (!mounted || _session?.id != session.id) return null;
    setState(() => _session = updated);
    _syncCompactionNotice();
    return updated;
  }

  void _syncCompactionNotice() {
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

  void _syncModelSwitchNotices() {
    _chat.batch(() {
      _chat.removeWhere((m) => m is AssistantModelSwitchNotice);
      for (final notice in modelSwitchNoticesFor(_chat.items)) {
        final idx = _chat.indexOfId(notice.beforeId);
        if (idx >= 0) _chat.insertAt(idx, notice);
      }
    });
  }

  Future<void> _restoreFullHistory() async {
    final session = _session;
    if (session == null || session.compactedSummary == null) return;
    final restored = session.copyWith(
      compactedSummary: null,
      compactedUpToMessageId: null,
      compactedAt: null,
      compactedInputTokensAtTrigger: null,
    );
    await getIt<ChatRepository>().upsertSession(restored);
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
    _syncModelSwitchNotices();
  }

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
    _freezeThinkingTimer();
    final cur = _streamingMessage;
    if (cur == null) return;
    _syncReasoning(cur.copyWith(text: cur.text + delta));
  }

  void _appendReasoning(String delta) {
    if (delta.isEmpty) return;
    final cur = _streamingMessage;
    if (cur == null) return;
    _reasoningStart ??= DateTime.timestamp();
    _thinkingActive = true;
    _streamingReasoning += delta;
    _syncReasoning(cur);
  }

  void _applyToolStarted(String callId, String name, String argsJson) {
    final cur = _streamingMessage;
    if (cur == null) return;
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

  void _freezeThinkingOnTool() {
    if (!_thinkingActive) return;
    _freezeThinkingTimer();
    final cur = _streamingMessage;
    if (cur != null) _syncReasoning(cur);
  }

  void _freezeThinkingTimer() {
    if (!_thinkingActive) return;
    _thinkingActive = false;
    final start = _reasoningStart;
    if (start != null) {
      _thinkingMillis += DateTime.timestamp().difference(start).inMilliseconds;
      _reasoningStart = null;
    }
  }

  int _liveThinkingMillis() {
    final start = _reasoningStart;
    if (_thinkingActive && start != null) {
      return _thinkingMillis +
          DateTime.timestamp().difference(start).inMilliseconds;
    }
    return _thinkingMillis;
  }

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

  Future<void> _pickImage() async {
    if (_sending) return;
    _inputFocusNode.unfocus();
    final files = await getIt<IFilePicker>().pickImages(context, maxAssets: 1);
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
      AssistantModelSwitchNotice(:final model) => _ModelSwitchChip(
        model: model,
      ),
    };
  }

  Widget _buildTurn(AssistantTurn turn) {
    final items = _chat.items;
    final isLast = items.isNotEmpty && items.last.id == turn.id;
    if (turn.fromUser) {
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

  Widget _buildScrollToBottom(
    BuildContext context,
    bool visible,
    VoidCallback onTap,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: _composerHeight + 8,
      child: Center(
        child: AnimatedSlide(
          offset: visible ? .zero : const Offset(0, 0.6),
          duration: Durations.short4,
          curve: Easing.standard,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Durations.short4,
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
      onSendDiary: _pickAndSendDiary,
      onSendImage: _canSendImage ? _pickImage : null,
      onFullscreen: _openFullscreenComposer,
      pendingImageName: _pendingImageName,
      onRemoveImage: _removePendingImage,
    );

    return Column(
      children: [
        if (!_ready) _NotConfiguredBanner(onTap: _openSettings),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildChat()),
              Positioned(
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
    final modelLabel = _activeModel?.name ?? _modelId;

    final Widget chatArea = !_disclaimerAccepted
        ? _DisclaimerGate(onReview: _showDisclaimer)
        : _buildConversation(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: _toolbarHeight(context),
        titleSpacing: NavigationToolbar.kMiddleSpacing - _kTitleInset,
        title: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const .symmetric(horizontal: _kTitleInset),
              child: Text(
                _sessionTitle(_session, l10n),
                maxLines: 1,
                overflow: .ellipsis,
                style:
                    context.theme.typography.titleMedium.emphasized.onSurface,
              ),
            ),
            Row(
              mainAxisSize: .min,
              children: [
                Flexible(
                  child: _PresetChip(
                    label:
                        _presetName ??
                        (_presetMissing
                            ? l10n.assistant.presetDeleted
                            : l10n.assistant.presetBuiltinName),
                    staged: _session == null,
                    onTap: _sending
                        ? null
                        : (_session == null ? _pickPreset : _showPresetInfo),
                  ),
                ),
                if (modelLabel.isNotEmpty) ...[
                  Text(
                    '·',
                    style: context.theme.typography.labelSmall.onSurfaceVariant,
                  ),
                  Flexible(
                    flex: 2,
                    child: _ModelChip(
                      modelLabel: modelLabel,
                      reasoningLevel: _reasoningLevel,
                      onTap: _sending ? null : _pickModel,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      body: chatArea,
    );
  }

  Future<void> _pickPreset() async {
    if (_sending || _session != null) return;
    final choice = await showAgentPresetPicker(
      context,
      selectedId: _stagedPresetId,
    );
    if (choice == null || !mounted || _session != null) return;
    setState(() {
      _stagedPresetId = choice.id;
      _presetName = choice.name;
      _presetMissing = false;
      _presetPickedExplicitly = true;
    });
  }

  void _showPresetInfo() {
    final l10n = context.l10n;
    showAgentPresetInfo(
      context,
      name:
          _presetName ??
          (_presetMissing
              ? l10n.assistant.presetDeleted
              : l10n.assistant.presetBuiltinName),
      persona: _session?.personaSnapshot ?? defaultPersona,
      tools: _session?.toolsSnapshot,
    );
  }
}

class _ModelSwitchChip extends StatelessWidget {
  final String model;

  const _ModelSwitchChip({required this.model});

  @override
  Widget build(BuildContext context) {
    return AssistantNotice(
      icon: LucideIcons.cpu,
      kind: context.l10n.assistant.modelSwitched(model: model),
    );
  }
}

class _CompactionNoticeChip extends StatelessWidget {
  final String summary;
  final VoidCallback onRestore;

  const _CompactionNoticeChip({required this.summary, required this.onRestore});

  @override
  Widget build(BuildContext context) {
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

class _AssistantComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onStop;

  final VoidCallback onSendDiary;

  final VoidCallback? onSendImage;
  final VoidCallback onFullscreen;
  final String? pendingImageName;
  final VoidCallback onRemoveImage;

  const _AssistantComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.onStop,
    required this.onSendDiary,
    required this.onSendImage,
    required this.onFullscreen,
    required this.pendingImageName,
    required this.onRemoveImage,
  });

  @override
  State<_AssistantComposer> createState() => _AssistantComposerState();
}

class _AssistantComposerState extends State<_AssistantComposer> {
  bool _overflowing = false;

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
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: .fromLTRB(12, 0, 12, 8 + MediaQuery.paddingOf(context).bottom),
        child: GestureDetector(
          behavior: .opaque,
          child: MGlassSurface(
            shape: const RoundedRectangleBorder(borderRadius: radius),
            child: Padding(
              padding: const .all(_kComposerPadding),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  if (widget.pendingImageName != null)
                    _ComposerImagePreview(
                      imageName: widget.pendingImageName!,
                      onRemove: widget.onRemoveImage,
                    ),
                  Padding(
                    padding: const .fromLTRB(8, 8, 8, 6),
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: (notification) {
                        final overflowing =
                            notification.metrics.maxScrollExtent > 0;
                        if (overflowing != _overflowing) {
                          setState(() => _overflowing = overflowing);
                        }
                        return false;
                      },
                      child: MField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: !widget.sending,
                        maxLines: _maxLines(context),
                        variant: .plain,
                        showClear: false,
                        textInputAction: .send,
                        hintText: l10n.assistant.inputHint,
                        onSubmitted: (_) => widget.onSend(),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      MMenuButton<_ComposerTool>(
                        tooltip: l10n.assistant.tool,
                        entries: [
                          MMenuEntry(
                            value: .diary,
                            label: l10n.assistant.toolSendDiary,
                            icon: LucideIcons.bookOpen,
                            enabled: !widget.sending,
                          ),
                          if (widget.onSendImage != null)
                            MMenuEntry(
                              value: .image,
                              label: l10n.assistant.toolSendImage,
                              icon: LucideIcons.image,
                              enabled: !widget.sending,
                            ),
                        ],
                        onSelected: (tool) => switch (tool) {
                          _ComposerTool.diary => widget.onSendDiary(),
                          _ComposerTool.image => widget.onSendImage?.call(),
                        },
                        child: SizedBox.square(
                          dimension: _kComposerControlSize,
                          child: Icon(
                            LucideIcons.plus,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: .min,
                        children: [
                          if (_overflowing) ...[
                            Tooltip(
                              message: l10n.assistant.composerFullscreen,
                              child: MInkWell(
                                shape: const CircleBorder(),
                                onTap: widget.onFullscreen,
                                child: SizedBox.square(
                                  dimension: _kComposerControlSize,
                                  child: Icon(
                                    LucideIcons.maximize2,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: widget.controller,
                            builder: (context, value, _) {
                              if (widget.sending) {
                                return MCircleButton(
                                  tooltip: l10n.assistant.stop,
                                  onPressed: widget.onStop,
                                  size: _kComposerControlSize,
                                  icon: const Icon(LucideIcons.square),
                                );
                              }
                              final canSend =
                                  value.text.trim().isNotEmpty ||
                                  widget.pendingImageName != null;
                              return MCircleButton(
                                tooltip: l10n.assistant.send,
                                onPressed: canSend ? widget.onSend : null,
                                size: _kComposerControlSize,
                                icon: const Icon(LucideIcons.arrowUp),
                              );
                            },
                          ),
                        ],
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
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final height = box.size.height;
      if ((height - _last).abs() < 0.5) return;
      _last = height;
      widget.onHeight(height);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
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

class _PresetChip extends StatelessWidget {
  final String label;

  final bool staged;

  final VoidCallback? onTap;

  const _PresetChip({
    required this.label,
    required this.staged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final content = Row(
      mainAxisSize: .min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: .ellipsis,
            style: typography.labelSmall.onSurfaceVariant,
          ),
        ),
        if (staged && onTap != null) ...[
          const SizedBox(width: 2),
          Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: context.theme.colors.onSurfaceVariant,
          ),
        ],
      ],
    );
    const inset = EdgeInsets.symmetric(horizontal: _kTitleInset, vertical: 2);
    if (onTap == null) return Padding(padding: inset, child: content);
    return MInkWell(
      shape: const StadiumBorder(),
      onTap: onTap,
      child: Padding(padding: inset, child: content),
    );
  }
}

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
        Flexible(
          child: Text(
            modelLabel,
            maxLines: 1,
            overflow: .ellipsis,
            style: typography.labelSmall.onSurfaceVariant,
          ),
        ),
        if (reasoningLevel.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(reasoningLevel, style: typography.labelSmall.onSurfaceVariant),
        ],
        if (!locked) ...[
          const SizedBox(width: 2),
          Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: context.theme.colors.onSurfaceVariant,
          ),
        ],
      ],
    );

    const inset = EdgeInsets.symmetric(horizontal: _kTitleInset, vertical: 2);
    if (locked) return Padding(padding: inset, child: label);
    return MInkWell(
      shape: const StadiumBorder(),
      onTap: onTap,
      child: Padding(padding: inset, child: label),
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

String _compactTokens(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

String _durationText(int millis) {
  final secs = millis / 1000;
  if (secs >= 10) return secs.toStringAsFixed(0);
  return (secs < 0.1 ? 0.1 : secs).toStringAsFixed(1);
}

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
          summary: _reasoningPeek(reasoning, tail: thinkingActive),
          detail: reasoning.isEmpty
              ? null
              : (context) => GptMarkdown(
                  reasoning,
                  style: context.theme.typography.bodySmall.onSurfaceVariant,
                  codeBuilder: _codeBlock,
                ),
        ),
      for (final call in toolCalls) _toolNotice(context, call),
      ?bubble,
    ];

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

Widget _toolNotice(BuildContext context, AssistantToolCall call) {
  final spec = AssistantToolRegistry.byId(call.name);
  final display = spec == null
      ? call.name
      : assistantToolDisplay(context, spec.tool).title;
  if (!call.done) {
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
      appBar: AppBar(
        title: Text(l10n.assistant.settingFunctionAIAssistant),
        actions: const [_ActiveModelAction(), SizedBox(width: 4)],
      ),
      body: _SessionListView(
        onSelect: (session) =>
            AssistantConversationRoute(sessionId: session.id).push(context),
        onDelete: (session) =>
            getIt<ChatRepository>().deleteSession(session.id),
        padding: .only(bottom: 8 + MediaQuery.paddingOf(context).bottom),
      ),
    );
  }
}

class _ActiveModelAction extends StatefulWidget {
  const _ActiveModelAction();

  @override
  State<_ActiveModelAction> createState() => _ActiveModelActionState();
}

class _ActiveModelActionState extends State<_ActiveModelAction> {
  LlmProvider? _active;
  bool _loaded = false;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = getIt<LlmProviderRepository>().providerEvents.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final active = await getIt<LlmProviderRepository>().getActiveProvider();
    if (!mounted) return;
    setState(() {
      _active = active;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final l10n = context.l10n;
    final active = _active;
    final typography = context.theme.typography;
    return MInkWell(
      shape: const StadiumBorder(),
      onTap: () async {
        await const AssistantSettingRoute().push(context);
        await _load();
      },
      child: Padding(
        padding: const .symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: .min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                active?.defaultModel ?? l10n.assistant.historyModelUnset,
                maxLines: 1,
                overflow: .ellipsis,
                style: active == null
                    ? typography.labelMedium.error
                    : typography.labelMedium.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              LucideIcons.chevronRight,
              size: 15,
              color: context.theme.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

enum SessionHistoryBucket { today, last7, earlier }

typedef SessionHistoryGroup = ({
  SessionHistoryBucket bucket,
  List<ChatSession> sessions,
});

List<SessionHistoryGroup> sessionHistoryGroups(
  List<ChatSession> sessions, {
  required DateTime now,
}) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final weekAgo = today.subtract(const Duration(days: 7));
  final buckets = <SessionHistoryBucket, List<ChatSession>>{};
  for (final session in sessions) {
    final at = session.updatedAt.toLocal();
    final bucket = !at.isBefore(today)
        ? SessionHistoryBucket.today
        : !at.isBefore(weekAgo)
        ? SessionHistoryBucket.last7
        : SessionHistoryBucket.earlier;
    (buckets[bucket] ??= <ChatSession>[]).add(session);
  }
  return [
    for (final bucket in SessionHistoryBucket.values)
      if (buckets[bucket] case final list?) (bucket: bucket, sessions: list),
  ];
}

sealed class _HistoryEntry {
  const _HistoryEntry();
}

class _HistoryHeader extends _HistoryEntry {
  final SessionHistoryBucket bucket;

  const _HistoryHeader(this.bucket);
}

class _HistoryRow extends _HistoryEntry {
  final ChatSession session;
  final SessionHistoryBucket bucket;

  const _HistoryRow(this.session, this.bucket);
}

class _SessionListView extends StatefulWidget {
  final void Function(ChatSession session) onSelect;

  final void Function(ChatSession session) onDelete;

  final EdgeInsetsGeometry padding;

  const _SessionListView({
    required this.onSelect,
    required this.onDelete,
    this.padding = EdgeInsets.zero,
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
    _sub = getIt<ChatRepository>().sessionEvents.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final sessions = await getIt<ChatRepository>().getAllSessions();
    if (mounted) setState(() => _sessions = sessions);
  }

  List<_HistoryEntry> _entries(List<ChatSession> sessions) {
    return [
      for (final group in sessionHistoryGroups(
        sessions,
        now: DateTime.now(),
      )) ...[
        _HistoryHeader(group.bucket),
        for (final session in group.sessions)
          _HistoryRow(session, group.bucket),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return switch (sessions) {
      null => const Center(child: CircularProgressIndicator()),
      [] => const _EmptySessions(),
      final list => Builder(
        builder: (context) {
          final entries = _entries(list);
          return ListView.builder(
            padding: widget.padding,
            itemCount: entries.length,
            itemBuilder: (context, index) => switch (entries[index]) {
              _HistoryHeader(:final bucket) => _HistoryGroupLabel(bucket),
              _HistoryRow(:final session, :final bucket) => _SessionTile(
                session: session,
                bucket: bucket,
                onTap: () => widget.onSelect(session),
                onDelete: () => widget.onDelete(session),
              ),
            },
          );
        },
      ),
    };
  }
}

class _HistoryGroupLabel extends StatelessWidget {
  final SessionHistoryBucket bucket;

  const _HistoryGroupLabel(this.bucket);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (bucket) {
      .today => l10n.assistant.historyToday,
      .last7 => l10n.assistant.historyLast7,
      .earlier => l10n.assistant.historyEarlier,
    };
    return Padding(
      padding: const .fromLTRB(16, 18, 16, 4),
      child: Text(
        label,
        style: context.theme.typography.labelSmall.onSurfaceVariant,
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.messagesSquare,
            size: 40,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
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

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final SessionHistoryBucket bucket;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.bucket,
    required this.onTap,
    required this.onDelete,
  });

  String _time() => switch (bucket) {
    .today => TimeFormat.clock(session.updatedAt),
    .last7 => TimeFormat.weekdayShort(session.updatedAt),
    .earlier => TimeFormat.relative(session.updatedAt),
  };

  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    return MAlert.confirm(
      context,
      title: l10n.common.delete,
      message: _sessionTitle(session, l10n),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final l10n = context.l10n;
    return Dismissible(
      key: ValueKey(session.id),
      direction: .endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: ColoredBox(
        color: scheme.errorContainer,
        child: Align(
          alignment: .centerRight,
          child: Padding(
            padding: const .only(right: 20),
            child: Icon(
              LucideIcons.trash2,
              size: 20,
              color: scheme.onErrorContainer,
            ),
          ),
        ),
      ),
      child: MInkWell(
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _sessionTitle(session, l10n),
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: typography.bodyMedium.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Text(_time(), style: typography.labelSmall.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

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
