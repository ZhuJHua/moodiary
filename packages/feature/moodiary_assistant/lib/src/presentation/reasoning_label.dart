import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

String reasoningLevelLabel(String level, Translations l10n) => switch (level) {
  reasoningOffValue => l10n.assistant.reasoningOff,
  'minimal' => l10n.assistant.reasoningLevelMinimal,
  'low' => l10n.assistant.reasoningLevelLow,
  'medium' => l10n.assistant.reasoningLevelMedium,
  'high' => l10n.assistant.reasoningLevelHigh,
  'max' => l10n.assistant.reasoningLevelMax,
  _ => level,
};
