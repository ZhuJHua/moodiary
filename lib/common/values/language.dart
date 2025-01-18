import 'package:mood_diary/main.dart';

enum Language {
  system('system'),
  chinese('zh'),
  english('en');

  final String languageCode;

  const Language(this.languageCode);
}

extension LanguageExtension on Language {
  String get l10nText {
    switch (this) {
      case Language.system:
        return l10n.settingLanguageSystem;
      case Language.chinese:
        return l10n.settingLanguageSimpleChinese;
      case Language.english:
        return l10n.settingLanguageEnglish;
    }
  }
}
