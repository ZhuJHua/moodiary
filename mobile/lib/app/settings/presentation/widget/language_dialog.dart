import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;

class LanguageDialog extends ConsumerWidget {
  const LanguageDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = MoodiaryKVs.language.get() ?? Language.system.languageCode;
    final current = Language.values.firstWhere(
      (e) => e.languageCode == code,
      orElse: () => Language.system,
    );
    return SimpleDialog(
      title: Text(context.l10n.settingLanguage),
      children: [
        for (final lang in Language.values)
          _Option(
            label: lang.l10nText(context),
            selected: current == lang,
            onTap: () async {
              await MoodiaryKVs.language.set(lang.languageCode);
              ref.read(appSettingsControllerProvider.notifier).bumpLocale();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(selected ? LucideIcons.check : LucideIcons.languages),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
