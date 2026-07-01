import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/feature/assistant/application/llm_provider_preset_controller.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// [id] 非空=编辑；[id] 空且 [presetId] 非空=从预设新建；两者皆空=空白新建。
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
  List<String> _presetModels = const [];
  String? _apiKeyUrl;
  bool _keyConfigured = false;
  bool _obscureKey = true;
  bool _loaded = false;
  bool _saving = false;

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
      if (!mounted) return;
      setState(() {
        _name.text = provider.name;
        _baseUrl.text = provider.baseUrl;
        _model.text = provider.model;
        _type = provider.protocol;
        _presetModels = provider.protocol.presetModels;
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
          _name.text = preset.localizedName(
            Localizations.localeOf(context).languageCode,
          );
          _baseUrl.text = preset.baseUrl;
          _type = preset.protocol;
          _presetModels = preset.models;
          _model.text = preset.models.isNotEmpty
              ? preset.models.first
              : _type.defaultModel;
          _apiKeyUrl = preset.apiKeyUrl;
          _loaded = true;
        });
        return;
      }
    }

    setState(() {
      _model.text = _type.defaultModel;
      _presetModels = _type.presetModels;
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
    } catch (_) {
      // 预设拉取失败时按空白新建。
    }
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
    if (_isNew) {
      final provider = LlmProvider.create(
        name: name,
        type: _type,
        baseUrl: baseUrl,
        model: model,
        sortOrder: await _repo.nextSortOrder(),
      );
      id = provider.id;
      await _repo.upsertProvider(provider);
      final activeId = MoodiaryKVs.assistantActiveProviderId.get() ?? '';
      if (activeId.isEmpty) {
        await MoodiaryKVs.assistantActiveProviderId.set(id);
      }
    } else {
      final existing = await _repo.getProvider(widget.id!);
      if (existing == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      id = existing.id;
      await _repo.upsertProvider(
        existing.copyWith(
          name: name,
          type: _type.id,
          baseUrl: baseUrl,
          model: model,
        ),
      );
    }

    // 编辑态留空表示保持原 Key 不变，仅在输入新 Key 时写入
    if (key.isNotEmpty) {
      await _repo.setKey(id, key);
    }

    if (mounted) {
      toast.success(message: l10n.modelProviderSaved);
      Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? l10n.modelProviderEditNew : l10n.modelProviderEditEdit,
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.modelProviderName,
                      hintText: l10n.modelProviderNameHint,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      filled: true,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? l10n.modelProviderNeedName
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(text: l10n.modelProviderProtocol),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AssistantProviderType>(
                      showSelectedIcon: false,
                      segments: [
                        for (final t in AssistantProviderType.values)
                          ButtonSegment(value: t, label: Text(t.label)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() {
                        _type = s.first;
                        if (_model.text.trim().isEmpty) {
                          _model.text = _type.defaultModel;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _baseUrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.modelProviderBaseUrl,
                      hintText: l10n.modelProviderBaseUrlHint,
                      prefixIcon: const Icon(Icons.link_rounded),
                      filled: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _apiKey,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: l10n.modelProviderApiKey,
                      hintText: _keyConfigured
                          ? l10n.modelProviderApiKeyHintSet
                          : l10n.modelProviderApiKeyHintUnset,
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                      filled: true,
                      border: const OutlineInputBorder(),
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
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _model,
                    decoration: InputDecoration(
                      labelText: l10n.modelProviderModel,
                      prefixIcon: const Icon(Icons.memory_rounded),
                      filled: true,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? l10n.modelProviderNeedModel
                        : null,
                  ),
                  if (_presetModels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final m in _presetModels)
                          ActionChip(
                            label: Text(m),
                            onPressed: () => setState(() => _model.text = m),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(l10n.save),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
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
