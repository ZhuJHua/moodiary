// material_ui 转发的是 widgets.dart，而它对 foundation 是**选择性导出**，
// 不含 SynchronousFuture。
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:material_ui/material_ui.dart';

import 'strings.g.dart';

export 'strings.g.dart' show MuiLocalizationsData;

/// mui 那十来个通用词的 [LocalizationsDelegate]，宿主挂进 `localizationsDelegates`：
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [
///     ...GlobalMaterialLocalizations.delegates,
///     GlobalMuiLocalizations.delegate,
///   ],
/// )
/// ```
///
/// 走 `Localizations` 而不是 slang 自带的 `TranslationProvider`，是因为 mui 是被别人
/// import 的包：详见 `slang.yaml` 顶部。当前语种因此就是 `MaterialApp.locale` 解析出来的
/// 那个，宿主不需要知道 mui 内部用了 slang。
class GlobalMuiLocalizations
    extends LocalizationsDelegate<MuiLocalizationsData> {
  const GlobalMuiLocalizations();

  static const GlobalMuiLocalizations delegate = GlobalMuiLocalizations();

  /// 恒 true，匹配交给 [load] 自己做。
  ///
  /// 只报自己支持的两种语言会让宿主一旦支持第三种语言、且用户正用着它时整个丢掉这份
  /// delegate（`Localizations` 拿不到 delegate 就没有这一条数据），mui 的串于是全都
  /// 落到下面 [MuiLocalizations.of] 的兜底上。
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MuiLocalizationsData> load(Locale locale) {
    // 用 slang 自己的匹配器：先精确匹配，再只匹配 languageCode，都不中回落 base。
    final match = AppLocaleUtils.parseLocaleParts(
      languageCode: locale.languageCode,
      scriptCode: locale.scriptCode,
      countryCode: locale.countryCode,
    );
    // slang.yaml 钉了 lazy: false，所有语种在编译期就在，buildSync 处处安全 ——
    // 这里因此是同步的，`Localizations` 不会为它多等一帧，widget 测试也不用多 pump。
    return SynchronousFuture(match.buildSync());
  }

  @override
  bool shouldReload(GlobalMuiLocalizations old) => false;
}

/// 从 widget 树上取 mui 的通用词，通常写成 `context.muiL10n.ok`。
abstract final class MuiLocalizations {
  /// 宿主漏挂 [GlobalMuiLocalizations.delegate] 时：debug 断言亮出来，release 回落
  /// base 语种。
  ///
  /// 不直接抛：mui 是组件库，它只有十来个通用词，为此让宿主整个崩掉不成比例；但静默
  /// 回落等于英文用户看到中文，所以 debug 下必须响。
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

  /// base 语种的实例，只在漏挂 delegate 时用到。
  static final MuiLocalizationsData _fallback = MuiLocalizationsData();
}

extension MuiL10nContext on BuildContext {
  MuiLocalizationsData get muiL10n => MuiLocalizations.of(this);
}
