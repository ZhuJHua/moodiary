import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

Future<void> applyStoredLanguage() async {
  final stored = MoodiaryKVs.language.get() ?? Language.system.languageCode;
  var language = Language.values.firstWhere(
    (e) => e.languageCode == stored,
    orElse: () => Language.system,
  );
  if (language == .system) {
    final systemLocale = await findSystemLocale();
    final systemLanguageCode = systemLocale.contains('_')
        ? systemLocale.split('_').first
        : systemLocale;
    language = Language.values.firstWhere(
      (e) => e.languageCode == systemLanguageCode,
      orElse: () => Language.english,
    );
  }
  Intl.defaultLocale = language.languageCode;
  await LocaleSettings.setLocale(switch (language) {
    .chinese => AppLocale.zh,
    .english || .system => AppLocale.en,
  });
}
