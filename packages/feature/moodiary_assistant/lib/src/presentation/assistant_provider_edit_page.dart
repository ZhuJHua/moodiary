import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_assistant/src/application/llm_provider_preset_controller.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class AssistantProviderEditPage extends ConsumerStatefulWidget {
  final String? id;
  final String? presetId;

  const AssistantProviderEditPage({super.key, this.id, this.presetId});

  @override
  ConsumerState<AssistantProviderEditPage> createState() =>
      _AssistantProviderEditPageState();
}

class _AssistantProviderEditPageState
    extends ConsumerState<AssistantProviderEditPage> {
  LlmProviderRepository get _repo => LlmProviderRepository.get();

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();

  AssistantProviderType _type = AssistantProviderType.openai;
  List<LlmModelPreset> _presetModels = const [];
  String? _apiKeyUrl;
  String _providerId = '';
  bool _keyConfigured = false;
  bool _obscureKey = true;
  bool _loaded = false;
  bool _saving = false;
  bool _showAllModels = false;
  String _modelQuery = '';

  bool get _isNew => widget.id == null;

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
    _model.dispose();
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
      final preset = provider.providerId.isNotEmpty
          ? await _findPreset(provider.providerId)
          : null;
      if (!mounted) return;
      setState(() {
        _name.text = provider.name;
        _baseUrl.text = provider.baseUrl;
        _model.text = provider.model;
        _type = provider.protocol;
        _providerId = provider.providerId;
        _presetModels = preset?.models ?? const [];
        _apiKeyUrl = preset?.docUrl;
        _keyConfigured = key != null && key.isNotEmpty;
        _loaded = true;
      });
      return;
    }

    final presetId = widget.presetId;
    if (presetId != null) {
      final preset = await _findPreset(presetId);
      if (preset != null) {
        if (!mounted) return;
        setState(() {
          _name.text = preset.name;
          _baseUrl.text = preset.baseUrl;
          _type = preset.protocol;
          _providerId = preset.id;
          _presetModels = preset.models;
          _model.text = preset.models.isNotEmpty ? preset.models.first.id : '';
          _apiKeyUrl = preset.docUrl;
          _loaded = true;
        });
        return;
      }
    }

    setState(() {
      _presetModels = const [];
      _loaded = true;
    });
  }

  Future<LlmProviderPreset?> _findPreset(String id) async {
    try {
      final presets = await ref.read(
        llmProviderPresetControllerProvider.future,
      );
      for (final p in presets) {
        if (p.id == id) return p;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _name.text.trim();
    final model = _model.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final key = _apiKey.text.trim();

    final String id;
    final LlmProvider toSave;
    if (_isNew) {
      toSave = LlmProvider.create(
        name: name,
        type: _type,
        baseUrl: baseUrl,
        model: model,
        sortOrder: await _repo.nextSortOrder(),
        providerId: _providerId,
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
        model: model,
      );
    }

    // 先写 key 再 upsert：upsert 会广播刷新事件，此时 key 已就位，
    // 否则列表/配置页会残留「没有 key」直到重启（setKey 在 upsert 之后且不发事件）。
    if (key.isNotEmpty) {
      await _repo.setKey(id, key);
    }
    await _repo.upsertProvider(toSave);
    if (_isNew) {
      final activeId = MoodiaryKVs.assistantActiveProviderId.get() ?? '';
      if (activeId.isEmpty) {
        await MoodiaryKVs.assistantActiveProviderId.set(id);
      }
    }

    if (mounted) {
      toast.success(message: l10n.modelProviderSaved);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openApiKeyUrl() async {
    final url = _apiKeyUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  InputDecoration _fieldDecoration({
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final scheme = context.colorScheme;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      borderSide: width == 0
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: border(scheme.outline, 0),
      enabledBorder: border(scheme.outline, 0),
      focusedBorder: border(scheme.primary, 1.5),
      errorBorder: border(scheme.error, 1),
      focusedErrorBorder: border(scheme.error, 1.5),
    );
  }

  InputDecoration _searchDecoration(String hint) {
    final scheme = context.colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      isDense: true,
      border: const OutlineInputBorder(
        borderRadius: AppBorderRadius.mediumBorderRadius,
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildModelSelector(AppLocalizations l10n) {
    final all = _presetModels;
    if (all.isEmpty) return const SizedBox.shrink();
    final toolModels = all.where((m) => m.toolCall).toList();
    final filterable = toolModels.isNotEmpty && toolModels.length < all.length;
    var visible = (_showAllModels || toolModels.isEmpty) ? all : toolModels;
    final showSearch = all.length > 6;
    final query = _modelQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      visible = visible
          .where(
            (m) =>
                m.name.toLowerCase().contains(query) ||
                m.id.toLowerCase().contains(query),
          )
          .toList();
    }
    final selected = _model.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SectionLabel(text: l10n.modelProviderPickModel)),
            if (filterable)
              TextButton(
                onPressed: () =>
                    setState(() => _showAllModels = !_showAllModels),
                child: Text(
                  _showAllModels
                      ? l10n.modelProviderShowToolOnly
                      : l10n.modelProviderShowAll,
                ),
              ),
          ],
        ),
        if (showSearch) ...[
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _modelQuery = v),
            decoration: _searchDecoration(l10n.modelProviderSearchModelHint),
          ),
        ],
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                l10n.modelProviderNoModelMatch,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final m in visible)
            _ModelTile(
              model: m,
              selected: m.id == selected,
              onTap: () => setState(() => _model.text = m.id),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = _providerId.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? l10n.modelProviderEditNew : l10n.modelProviderEditEdit,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _loaded ? _save : null,
                    child: Text(l10n.save),
                  ),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _LabeledField(
                      label: l10n.modelProviderName,
                      child: TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          hint: l10n.modelProviderNameHint,
                          icon: Icons.badge_outlined,
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? l10n.modelProviderNeedName
                            : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LabeledField(
                      label: l10n.modelProviderBaseUrl,
                      child: IgnorePointer(
                        ignoring: locked,
                        child: TextFormField(
                          controller: _baseUrl,
                          keyboardType: TextInputType.url,
                          readOnly: locked,
                          enableInteractiveSelection: !locked,
                          decoration: _fieldDecoration(
                            hint: l10n.modelProviderBaseUrlHint,
                            icon: Icons.link_rounded,
                            suffixIcon: locked
                                ? const Icon(Icons.lock_outline_rounded, size: 18)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LabeledField(
                      label: l10n.modelProviderApiKey,
                      child: TextFormField(
                        controller: _apiKey,
                        obscureText: _obscureKey,
                        decoration: _fieldDecoration(
                          hint: _keyConfigured
                              ? l10n.modelProviderApiKeyHintSet
                              : l10n.modelProviderApiKeyHintUnset,
                          icon: Icons.key_rounded,
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_apiKeyUrl != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _openApiKeyUrl,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(l10n.modelProviderGetApiKey),
                        ),
                      ),
                    const SizedBox(height: 18),
                    _LabeledField(
                      label: l10n.modelProviderModel,
                      child: TextFormField(
                        controller: _model,
                        decoration: _fieldDecoration(
                          icon: Icons.memory_rounded,
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? l10n.modelProviderNeedModel
                            : null,
                      ),
                    ),
                    _buildModelSelector(l10n),
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
      style: context.textTheme.labelLarge?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  final LlmModelPreset model;
  final bool selected;
  final VoidCallback onTap;

  const _ModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final badges = <Widget>[
      if (model.toolCall)
        _Badge(icon: Icons.build_rounded, text: l10n.modelProviderBadgeTools),
      if (model.reasoning)
        _Badge(
          icon: Icons.psychology_rounded,
          text: l10n.modelProviderBadgeReasoning,
        ),
      if (_formatContext(model.contextLimit) case final ctx?)
        _Badge(icon: Icons.unfold_more_rounded, text: ctx),
      if (_formatPrice(model.inputCost, model.outputCost) case final price?)
        _Badge(icon: Icons.payments_outlined, text: price),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.name, style: context.textTheme.titleSmall),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: badges),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatContext(int? n) {
  if (n == null || n <= 0) return null;
  if (n >= 1000000) {
    final m = n / 1000000;
    return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
  }
  if (n >= 1000) return '${(n / 1000).round()}K';
  return '$n';
}

String? _formatPrice(num? input, num? output) {
  if (input == null && output == null) return null;
  String f(num? v) => v == null ? '?' : '\$${_trimNum(v)}';
  return '${f(input)}/${f(output)}';
}

String _trimNum(num v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}
