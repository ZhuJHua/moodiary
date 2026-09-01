import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// 把 KV 里的语言偏好落到 slang。
///
/// KV 只存偏好枚举（system / zh / en）；App 文案的语种真源是 slang 的 `GlobalLocaleState`
/// 单例。mui 那份不在这里——它跟随 `MaterialApp.locale`（走 `GlobalMuiLocalizations`
/// 这个 delegate），而 `MaterialApp.locale` 又取自本函数切好的 `TranslationProvider`。
///
/// 用异步的 [LocaleSettings.setLocale] 而不是 `setLocaleSync`：非 base 语种的翻译类是
/// deferred import 的（`lazy: true`），同步版会绕开 `loadLibrary()`。
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
    // system 在上面已经解析成具体语种了。
    .chinese => AppLocale.zh,
    .english || .system => AppLocale.en,
  });
}
