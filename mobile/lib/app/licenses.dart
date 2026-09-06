import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_mobile/gen/assets.gen.dart';

void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    final raw = await rootBundle.loadString(Assets.licenses.thirdParty);
    for (final entry in jsonDecode(raw) as List) {
      final e = entry as Map<String, dynamic>;
      yield LicenseEntryWithLineBreaks(
        (e['packages'] as List).cast<String>(),
        e['text'] as String,
      );
    }
  });
}
