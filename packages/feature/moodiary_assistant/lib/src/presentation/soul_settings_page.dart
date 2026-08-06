import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/soul_repository.dart';

/// 编辑用户自定义人格（SOUL），叠加在安全与工具规则之上；留空恢复默认。见 [SoulRepository]。
class AssistantSoulPage extends StatefulWidget {
  const AssistantSoulPage({super.key});

  @override
  State<AssistantSoulPage> createState() => _AssistantSoulPageState();
}

class _AssistantSoulPageState extends State<AssistantSoulPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final soul = await SoulRepository.get().read();
    if (!mounted) return;
    _controller.text = soul;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await SoulRepository.get().write(_controller.text);
    if (!mounted) return;
    setState(() => _saving = false);
    toast.success(message: context.l10n.assistantSoulSaved);
    Navigator.of(context).maybePop();
  }

  Future<void> _reset() async {
    await SoulRepository.get().resetToDefault();
    if (!mounted) return;
    _controller.text = defaultSoul;
    toast.success(message: context.l10n.assistantSoulResetDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantSoulPageTitle),
        actions: [
          TextButton(
            onPressed: (_loaded && !_saving) ? _save : null,
            child: Text(l10n.assistantSoulSave),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const .all(16),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  Card.filled(
                    color: scheme.surfaceContainerHighest,
                    margin: .zero,
                    child: Padding(
                      padding: const .all(12),
                      child: Row(
                        children: [
                          Icon(LucideIcons.heart, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.assistantSoulNote,
                              style: context.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: .top,
                      maxLength: soulMaxChars,
                      keyboardType: .multiline,
                      decoration: InputDecoration(
                        hintText: l10n.assistantSoulEditorHint,
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: scheme.surfaceContainerLow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: .centerStart,
                    child: TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(LucideIcons.rotateCcw),
                      label: Text(l10n.assistantSoulReset),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
