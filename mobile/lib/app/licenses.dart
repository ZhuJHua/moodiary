import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 构建钩子生成，跑 build_runner 时可能还不存在，不走 flutter_gen
const _manifest = 'assets/licenses/third_party.json';

void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
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
