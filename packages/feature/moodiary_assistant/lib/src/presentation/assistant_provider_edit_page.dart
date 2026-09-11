import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/src/application/llm_provider_preset_controller.dart';
import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_assistant/src/data/llm_provider_repository.dart';
import 'package:moodiary_assistant/src/data/model_catalog_repository.dart';
import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_assistant/src/presentation/catalog_error.dart';
import 'package:moodiary_assistant/src/presentation/model_picker_sheet.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
import 'package:url_launcher/url_launcher.dart';

class AssistantProviderEditPage extends ConsumerStatefulWidget {
  final String? id;
  final String? presetId;

  const AssistantProviderEditPage({super.key, this.id, this.presetId});

  factory AssistantProviderEditPage.fromRoute(GoRouterState state) =>
      AssistantProviderEditPage(
        id: state.params['id'] as String?,
        presetId: state.params['preset_id'] as String?,
      );

  @override
  ConsumerState<AssistantProviderEditPage> createState() =>
      _AssistantProviderEditPageState();
}

class _AssistantProviderEditPageState
    extends ConsumerState<AssistantProviderEditPage> {
  late final _repo = getIt<LlmProviderRepository>();

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();

  AssistantProviderType _type = .openaiCompletions;
  String _presetId = '';
  String _defaultModel = '';

  List<String> _models = const [];

  String? _docUrl;
  bool _keyConfigured = false;
  bool _obscureKey = true;
  bool _loaded = false;
  bool _saving = false;
  bool _fetchingModels = false;
  bool _refreshingCatalog = false;

  bool _toolCall = false;
  bool _reasoning = false;
  bool _attachment = false;

  bool get _isNew => widget.id == null;

  bool get _isPreset => _presetId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id != null) {
      final provider = await _repo.getProvider(id);
      if (provider == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final key = await _repo.getKey(id);
      final preset = provider.isPreset
          ? await _findPreset(provider.presetId)
          : null;
      if (!mounted) return;
      setState(() {
        _name.text = provider.name;
        _baseUrl.text = provider.baseUrl;
        _type = provider.protocol;
        _presetId = provider.presetId;
        _defaultModel = provider.defaultModel;
        _models = provider.models;
        _docUrl = preset?.docUrl;
        _keyConfigured = key != null && key.isNotEmpty;
        _toolCall = provider.toolCall;
        _reasoning = provider.reasoning;
        _attachment = provider.attachment;
        _loaded = true;
      });
      return;
    }

    final presetId = widget.presetId;
    if (presetId != null) {
      final preset = await _findPreset(presetId);
      if (preset != null && mounted) {
        setState(() {
          _name.text = preset.name;
          _presetId = preset.id;
          _docUrl = preset.docUrl;
          _defaultModel = preset.models.isEmpty ? '' : preset.models.first.id;
          _loaded = true;
        });
        return;
      }
    }

    if (mounted) setState(() => _loaded = true);
  }

  Future<LlmProviderPreset?> _findPreset(String id) async {
    try {
      for (final p in await getIt<LlmPresetRepository>().load()) {
        if (p.id == id) return p;
      }
    } catch (_) {}
    return null;
  }

  LlmProvider get _draft => LlmProvider(
    id: widget.id ?? '',
    name: _name.text.trim(),
    type: _type.id,
    baseUrl: _baseUrl.text.trim(),
    defaultModel: _defaultModel,
    createdAt: .timestamp(),
    sortOrder: 0,
    presetId: _presetId,
    models: _models,
    toolCall: _toolCall,
    reasoning: _reasoning,
    attachment: _attachment,
  );

  Future<void> _pickDefaultModel() async {
    final l10n = context.l10n;
    final options = ModelResolver.optionsFor(_draft);
    if (options.isEmpty) {
      toast.info(message: l10n.assistant.modelListEmpty);
      return;
    }
    final choice = await showModelPicker(
      context,
      providerName: _name.text.trim(),
      options: options,
      modelId: _defaultModel,
      showEffort: false,
    );
    if (choice != null && mounted) {
      setState(() => _defaultModel = choice.modelId);
    }
  }

  Future<void> _refreshCatalog() async {
    if (_refreshingCatalog) return;
    setState(() => _refreshingCatalog = true);
    final l10n = context.l10n;
    try {
      final presets = await getIt<LlmPresetRepository>().refresh();
      if (!mounted) return;
      ref.invalidate(llmProviderPresetControllerProvider);
      final preset = presets.where((p) => p.id == _presetId).firstOrNull;
      setState(() => _docUrl = preset?.docUrl ?? _docUrl);
      toast.success(
        message: l10n.assistant.modelListFetched(
          count: preset?.models.length ?? 0,
        ),
      );
    } catch (e) {
      if (mounted) toast.error(message: assistantNetworkErrorText(e, l10n));
    } finally {
      if (mounted) setState(() => _refreshingCatalog = false);
    }
  }

  Future<void> _fetchModels() async {
    if (_fetchingModels) return;
    final l10n = context.l10n;
    final typed = _apiKey.text.trim();
    final stored = _isNew ? null : await _repo.getKey(widget.id!);
    final key = typed.isNotEmpty ? typed : (stored ?? '');
    if (key.isEmpty) {
      toast.info(message: l10n.assistant.modelListNeedKey);
      return;
    }
    setState(() => _fetchingModels = true);
    try {
      final ids = await getIt<ModelCatalogRepository>().fetch(
        protocol: _type,
        baseUrl: _baseUrl.text.trim(),
        apiKey: key,
      );
      if (!mounted) return;
      setState(() {
        _models = {..._models, ...ids}.toList()..sort();
        if (_defaultModel.isEmpty && ids.isNotEmpty) _defaultModel = ids.first;
      });
      toast.success(
        message: l10n.assistant.modelListFetched(count: ids.length),
      );
    } catch (e) {
      if (mounted) {
        toast.error(
          message:
              '${assistantNetworkErrorText(e, l10n)} · '
              '${l10n.assistant.modelListManualHint}',
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _addModelManually() async {
    final l10n = context.l10n;
    final id = await MAlert.prompt(
      context,
      title: l10n.assistant.modelListAdd,
      hintText: l10n.assistant.modelProviderModel,
    );
    final trimmed = id?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      _models = {..._models, trimmed}.toList()..sort();
      if (_defaultModel.isEmpty) _defaultModel = trimmed;
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_defaultModel.isEmpty) {
      toast.info(message: l10n.assistant.modelProviderNeedModel);
      return;
    }
    setState(() => _saving = true);

    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final key = _apiKey.text.trim();

    final String id;
    final LlmProvider toSave;
    if (_isNew) {
      toSave = .create(
        name: name,
        type: _type,
        baseUrl: baseUrl,
        defaultModel: _defaultModel,
        sortOrder: await _repo.nextSortOrder(),
        presetId: _presetId,
        models: _models,
        toolCall: _toolCall,
        reasoning: _reasoning,
        attachment: _attachment,
      );
      id = toSave.id;
    } else {
      final existing = await _repo.getProvider(widget.id!);
      if (existing == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      id = existing.id;
      toSave = existing.copyWith(
        name: name,
        type: _type.id,
        baseUrl: baseUrl,
        defaultModel: _defaultModel,
        models: _models,
        toolCall: _toolCall,
        reasoning: _reasoning,
        attachment: _attachment,
      );
    }

    // 必须先写 key 再 upsert：setKey 不发事件，upsert 才广播刷新
    if (key.isNotEmpty) await _repo.setKey(id, key);
    await _repo.upsertProvider(toSave);
    if (_isNew && (MoodiaryKVs.assistantActiveProviderId.get() ?? '').isEmpty) {
      MoodiaryKVs.assistantActiveProviderId.set(id);
    }

    if (mounted) {
      toast.success(message: l10n.assistant.modelProviderSaved);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openDocUrl() async {
    final uri = Uri.tryParse(_docUrl ?? '');
    if (uri != null) await launchUrl(uri, mode: .externalApplication);
  }

  InputDecoration _fieldDecoration({
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final scheme = context.theme.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      borderSide: width == 0 ? .none : BorderSide(color: color, width: width),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      isDense: true,
      contentPadding: const .symmetric(vertical: 14, horizontal: 12),
      border: border(scheme.outline, 0),
      enabledBorder: border(scheme.outline, 0),
      focusedBorder: border(scheme.primary, 1.5),
      errorBorder: border(scheme.error, 1),
      focusedErrorBorder: border(scheme.error, 1.5),
    );
  }

  Widget _buildProtocolSelector(Translations l10n) {
    String label(AssistantProviderType t) => switch (t) {
      .openaiCompletions => l10n.assistant.protocolOpenAiCompletions,
      .openaiResponses => l10n.assistant.protocolOpenAiResponses,
      .anthropicMessages => l10n.assistant.protocolAnthropicMessages,
    };
    return _LabeledField(
      label: l10n.assistant.protocolTitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in AssistantProviderType.values)
            ChoiceChip(
              label: Text(label(t)),
              selected: _type == t,
              onSelected: (_) => setState(() {
                _type = t;
                _models = const [];
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildModelSection(Translations l10n) {
    final scheme = context.theme.colors;
    final count = _isPreset
        ? ModelResolver.optionsFor(_draft).length
        : _models.length;
    return Column(
      crossAxisAlignment: .start,
      children: [
        _LabeledField(
          label: l10n.assistant.modelProviderDefaultModel,
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: AppBorderRadius.mediumBorderRadius,
            clipBehavior: .antiAlias,
            child: MInkWell(
              onTap: _pickDefaultModel,
              child: Padding(
                padding: const .symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.cpu,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _defaultModel.isEmpty
                            ? l10n.assistant.modelProviderNeedModel
                            : _defaultModel,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: _defaultModel.isEmpty
                            ? context
                                  .theme
                                  .typography
                                  .bodyMedium
                                  .onSurfaceVariant
                            : context.theme.typography.bodyMedium.onSurface,
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.assistant.modelListCount(count: count),
                style: context.theme.typography.bodySmall.onSurfaceVariant,
              ),
            ),
            if (_isPreset)
              TextButton.icon(
                onPressed: _refreshingCatalog ? null : _refreshCatalog,
                icon: _refreshingCatalog
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.rotateCw, size: 18),
                label: Text(l10n.assistant.modelListUpdate),
              )
            else ...[
              TextButton.icon(
                onPressed: _addModelManually,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(l10n.assistant.modelListAdd),
              ),
              TextButton.icon(
                onPressed: _fetchingModels ? null : _fetchModels,
                icon: _fetchingModels
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.rotateCw, size: 18),
                label: Text(l10n.assistant.modelListFetch),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCapabilities(Translations l10n) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        const SizedBox(height: 18),
        _SectionLabel(text: l10n.assistant.modelProviderCapabilities),
        Padding(
          padding: const .only(left: 4, top: 2, bottom: 2),
          child: Text(
            l10n.assistant.modelProviderCapabilitiesHint,
            style: context.theme.typography.bodySmall.onSurfaceVariant,
          ),
        ),
        _CapabilitySwitch(
          icon: LucideIcons.wrench,
          label: l10n.assistant.tool,
          value: _toolCall,
          onChanged: (v) => setState(() => _toolCall = v),
        ),
        _CapabilitySwitch(
          icon: LucideIcons.brain,
          label: l10n.assistant.modelProviderBadgeReasoning,
          value: _reasoning,
          onChanged: (v) => setState(() => _reasoning = v),
        ),
        _CapabilitySwitch(
          icon: LucideIcons.image,
          label: l10n.assistant.modelProviderBadgeVision,
          value: _attachment,
          onChanged: (v) => setState(() => _attachment = v),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? l10n.assistant.modelProviderEditNew
              : l10n.assistant.modelProviderEditEdit,
        ),
        actions: [
          Padding(
            padding: const .only(right: 8),
            child: _saving
                ? const Center(
                    child: Padding(
                      padding: .symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _loaded ? _save : null,
                    child: Text(l10n.common.save),
                  ),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: .translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const .all(16),
                  children: [
                    _LabeledField(
                      label: l10n.common.name,
                      child: TextFormField(
                        controller: _name,
                        textInputAction: .next,
                        decoration: _fieldDecoration(
                          hint: l10n.assistant.modelProviderNameHint,
                          icon: LucideIcons.idCard,
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? l10n.assistant.modelProviderNeedName
                            : null,
                      ),
                    ),
                    if (!_isPreset) ...[
                      const SizedBox(height: 18),
                      _buildProtocolSelector(l10n),
                      const SizedBox(height: 18),
                      _LabeledField(
                        label: l10n.assistant.modelProviderBaseUrl,
                        child: TextFormField(
                          controller: _baseUrl,
                          keyboardType: .url,
                          decoration: _fieldDecoration(
                            hint: l10n.assistant.modelProviderBaseUrlHint,
                            icon: LucideIcons.link,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _LabeledField(
                      label: l10n.assistant.modelProviderApiKey,
                      child: TextFormField(
                        controller: _apiKey,
                        obscureText: _obscureKey,
                        decoration: _fieldDecoration(
                          hint: _keyConfigured
                              ? l10n.assistant.modelProviderApiKeyHintSet
                              : l10n.assistant.modelProviderApiKeyHintUnset,
                          icon: LucideIcons.key,
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                            icon: Icon(
                              _obscureKey
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_docUrl != null)
                      Align(
                        alignment: .centerLeft,
                        child: TextButton.icon(
                          onPressed: _openDocUrl,
                          icon: const Icon(LucideIcons.externalLink, size: 18),
                          label: Text(l10n.assistant.modelProviderGetApiKey),
                        ),
                      ),
                    const SizedBox(height: 18),
                    _buildModelSection(l10n),
                    if (!_isPreset) _buildCapabilities(l10n),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.theme.typography.labelLarge.onSurfaceVariant,
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .only(left: 4, bottom: 6),
          child: Text(
            label,
            style: context.theme.typography.labelLarge.onSurfaceVariant,
          ),
        ),
        child,
      ],
    );
  }
}

class _CapabilitySwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CapabilitySwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Padding(
      padding: const .symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: context.theme.typography.bodyMedium.onSurface,
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
