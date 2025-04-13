import 'package:flutter/cupertino.dart';
import 'package:moodiary/l10n/l10n.dart';

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
      case Language.system:
        return context.l10n.settingLanguageSystem;
      case Language.chinese:
        return context.l10n.settingLanguageSimpleChinese;
      case Language.english:
        return context.l10n.settingLanguageEnglish;
    }
  }
}
