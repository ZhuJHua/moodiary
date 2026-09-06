import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:material_ui/material_ui.dart';

import 'strings.g.dart';

export 'strings.g.dart' show MuiLocalizationsData;

class GlobalMuiLocalizations
    extends LocalizationsDelegate<MuiLocalizationsData> {
  const GlobalMuiLocalizations();

  static const GlobalMuiLocalizations delegate = GlobalMuiLocalizations();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MuiLocalizationsData> load(Locale locale) {
    final match = AppLocaleUtils.parseLocaleParts(
      languageCode: locale.languageCode,
      scriptCode: locale.scriptCode,
      countryCode: locale.countryCode,
    );
    return SynchronousFuture(match.buildSync());
  }

  @override
  bool shouldReload(GlobalMuiLocalizations old) => false;
}

abstract final class MuiLocalizations {
  static MuiLocalizationsData of(BuildContext context) {
    final data = Localizations.of<MuiLocalizationsData>(
      context,
      MuiLocalizationsData,
    );
    assert(
      data != null,
      '找不到 MuiLocalizationsData。把 GlobalMuiLocalizations.delegate 加进 '
      'MaterialApp.localizationsDelegates，否则 mui 组件的通用词会回落到 base 语种。',
    );
    return data ?? _fallback;
  }

  static final MuiLocalizationsData _fallback = MuiLocalizationsData();
}

extension MuiL10nContext on BuildContext {
  MuiLocalizationsData get muiL10n => MuiLocalizations.of(this);
}
