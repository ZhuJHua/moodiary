import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_mobile/gen/assets.gen.dart';

/// 把 Rust crates 与编辑器 npm 依赖的许可证并进关于页那份清单。
///
/// pub 依赖、Flutter/Dart SDK 与引擎那部分由 flutter tool 收进 `NOTICES`，
/// [LicenseRegistry] 默认就带着，这里只补它看不见的两条工具链。
/// 清单由 `dart tool/task.dart licenses` 生成，产物是提交的。
///
/// 回调是惰性的：只有打开许可证页时才会读那 600 多 KiB 的 asset。
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
