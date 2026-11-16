import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 构建钩子生成，跑 build_runner 时可能还不存在，不走 flutter_gen
const _manifest = 'assets/licenses/third_party.json';

const _qweatherIcons = '''
QWeather Icons
Copyright QWeather
https://github.com/qwd/Icons

Licensed under the Creative Commons Attribution 4.0 International License.
https://creativecommons.org/licenses/by/4.0/''';

void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['QWeather Icons'], _qweatherIcons);
    final raw = await rootBundle.loadString(_manifest);
    for (final entry in jsonDecode(raw) as List) {
      final e = entry as Map<String, dynamic>;
      yield LicenseEntryWithLineBreaks(
        (e['packages'] as List).cast<String>(),
        e['text'] as String,
      );
    }
  });
}
