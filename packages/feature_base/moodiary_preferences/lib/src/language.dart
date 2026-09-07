import 'package:flutter/widgets.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

enum Language {
  system('system'),
  chinese('zh'),
  english('en');

  final String languageCode;

  const Language(this.languageCode);
}

extension LanguageExtension on Language {
  String label(BuildContext context) {
    switch (this) {
      case .system:
        return context.l10n.app.languageSystem;
      case .chinese:
        return context.l10n.app.languageSimplifiedChinese;
      case .english:
        return context.l10n.app.languageEnglish;
    }
  }
}
