import 'package:flutter/material.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/values/language.dart';
import 'package:mood_diary/pages/home/setting/setting_logic.dart';
import 'package:mood_diary/utils/data/pref.dart';
import 'package:refreshed/refreshed.dart';

class LanguageDialogLogic extends GetxController {
  late final SettingLogic settingLogic = Bind.find<SettingLogic>();

  // 改变语言
  Future<void> changeLanguage(Language language) async {
    final originLanguage = language;
    if (language == Language.system) {
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
    await Get.updateLocale(Locale(language.languageCode));
    settingLogic.state.language.value = originLanguage;
    await PrefUtil.setValue<String>('language', originLanguage.languageCode);
  }
}
