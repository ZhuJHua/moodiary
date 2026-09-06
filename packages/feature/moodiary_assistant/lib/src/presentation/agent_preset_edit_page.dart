import 'package:moodiary_assistant/src/data/agent_preset_repository.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

class AgentPresetEditPage extends StatefulWidget {
  final String? id;
  final String? fromId;

  const AgentPresetEditPage({super.key, this.id, this.fromId});

  @override
  State<AgentPresetEditPage> createState() => _AgentPresetEditPageState();
}

class _AgentPresetEditPageState extends State<AgentPresetEditPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _persona = TextEditingController();

  AgentPreset? _editing;
  bool _loaded = false;
  bool _saving = false;

  bool _customTools = false;
  final Set<String> _selectedTools = {};

  @override
  void initState() {
    super.initState();
    _load();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _persona.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id != null && id.isNotEmpty) {
      final preset = await getIt<AgentPresetRepository>().get(id);
      if (!mounted) return;
      if (preset == null) {
        Navigator.of(context).maybePop();
        return;
      }
      _editing = preset;
      _name.text = preset.name;
      _description.text = preset.description;
      _persona.text = preset.persona;
      _applyTools(preset.tools);
    } else {
      final fromId = widget.fromId;
      final source = fromId == null || fromId.isEmpty
          ? null
          : await getIt<AgentPresetRepository>().get(fromId);
      if (!mounted) return;
      final l10n = context.l10n;
      final sourceName = source?.name ?? l10n.assistant.presetBuiltinName;
      _name.text = l10n.assistant.presetCopyName(name: sourceName);
      _description.text = source?.description ?? '';
      _persona.text = source?.persona ?? defaultPersona;
      _applyTools(source?.tools);
    }
    setState(() => _loaded = true);
  }

  void _applyTools(List<String>? tools) {
    _customTools = tools != null;
    _selectedTools
      ..clear()
      ..addAll(tools ?? const []);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final description = _description.text.trim();
    var persona = _persona.text.trim();
    if (persona.length > personaMaxChars) {
      persona = persona.substring(0, personaMaxChars);
    }
    final tools = _customTools
        ? [
            for (final t in AssistantTool.values)
              if (_selectedTools.contains(t.id)) t.id,
          ]
        : null;
    final editing = _editing;
    final preset = editing == null
        ? AgentPreset.create(
            name: name,
            description: description,
            persona: persona,
            tools: tools,
          )
        : editing.copyWith(
            name: name,
            description: description,
            persona: persona,
            tools: tools,
            updatedAt: DateTime.timestamp(),
          );
    await getIt<AgentPresetRepository>().put(preset);
    if (!mounted) return;
    setState(() => _saving = false);
    toast.success(message: context.l10n.assistant.presetSaved);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing == null
              ? l10n.assistant.presetDerive
              : l10n.assistant.presetEditTitle,
        ),
        actions: [
          TextButton(
            onPressed: (_loaded && !_saving && _name.text.trim().isNotEmpty)
                ? _save
                : null,
            child: Text(l10n.common.save),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const .all(16),
              children: [
                TextField(
                  controller: _name,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: l10n.assistant.presetNameLabel,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.assistant.presetDescriptionLabel,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.assistant.presetCustomTools,
                        style: context
                            .theme
                            .typography
                            .labelLarge
                            .onSurfaceVariant,
                      ),
                    ),
                    Switch(
                      value: _customTools,
                      onChanged: (v) => setState(() => _customTools = v),
                    ),
                  ],
                ),
                if (_customTools) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tool in AssistantTool.values)
                        FilterChip(
                          label: Text(
                            assistantToolDisplay(context, tool).title,
                          ),
                          selected: _selectedTools.contains(tool.id),
                          onSelected: (v) => setState(() {
                            v
                                ? _selectedTools.add(tool.id)
                                : _selectedTools.remove(tool.id);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                TextField(
                  controller: _persona,
                  minLines: 10,
                  maxLines: null,
                  textAlignVertical: .top,
                  maxLength: personaMaxChars,
                  keyboardType: .multiline,
                  decoration: InputDecoration(
                    labelText: l10n.assistant.presetPersonaLabel,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                  ),
                ),
              ],
            ),
    );
  }
}
