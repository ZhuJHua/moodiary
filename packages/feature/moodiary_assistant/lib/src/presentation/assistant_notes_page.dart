import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class AssistantNotesPage extends StatefulWidget {
  const AssistantNotesPage({super.key});

  @override
  State<AssistantNotesPage> createState() => _AssistantNotesPageState();
}

class _AssistantNotesPageState extends State<AssistantNotesPage> {
  late final _text = TextEditingController(
    text: MoodiaryKVs.assistantUserNotes.get() ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    MoodiaryKVs.assistantUserNotes.set(_text.text.trim());
    toast.success(message: context.l10n.assistant.notesSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistant.notesTitle),
        actions: [
          TextButton(onPressed: _save, child: Text(l10n.common.save)),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const .fromLTRB(16, 0, 16, 32),
        children: [
          Text(
            l10n.assistant.notesLede,
            style: context.theme.typography.bodySmall.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          MField(
            controller: _text,
            label: l10n.assistant.notesFieldLabel,
            maxLines: 12,
            maxLength: assistantUserNotesMaxChars,
          ),
        ],
      ),
    );
  }
}
