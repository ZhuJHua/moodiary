import 'package:flutter/cupertino.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

enum Language {
  system('system'),
  chinese('zh'),
  english('en');

  final String languageCode;

  const Language(this.languageCode);
}

extension LanguageExtension on Language {
  String l10nText(BuildContext context) {
    switch (this) {
      case .system:
        return context.l10n.settingLanguageSystem;
      case .chinese:
        return context.l10n.settingLanguageSimpleChinese;
      case .english:
        return context.l10n.settingLanguageEnglish;
    }
  }
}
