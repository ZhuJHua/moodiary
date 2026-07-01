/// Moodiary 本地化包（foundation）：导出 gen-l10n 生成的 [AppLocalizations]，
/// 并提供 `context.l10n` 便捷取串。
library;

import 'package:flutter/widgets.dart';

import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
