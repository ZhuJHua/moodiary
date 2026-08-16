import 'package:flutter_test/flutter_test.dart';
// 生成物不进 barrel（会和 App 那份撞名），包内测试直接引。
import 'package:mui/src/l10n/i18n/mui_strings.g.dart';

void main() {
  /// mui 的语种是被动跟随的：宿主 App 调**它自己那份** `LocaleSettings.setLocale`，
  /// slang_flutter 的 `_GlobalKeyHandler` 是进程级单例，会遍历所有已注册的
  /// TranslationProvider（含 mui 的）逐个 `updateState`。
  ///
  /// 但那条路只在 mui 的 `translationMap` 已经装满时才成立 —— slang 默认
  /// `lazy: true` 会把非 base 语种做成 deferred import，而 deferred 的翻译类只有
  /// **mui 自己那份** `setLocale` 才会 `loadLibrary()`。没人调过，于是
  /// `translationMap[currentLocale] ?? translationMap[baseLocale]` 一路回落到 zh：
  /// 英文用户在每个 mui 组件里看到中文，冷启动必现。
  ///
  /// 所以 `slang.yaml` 里钉了 `lazy: false`。这条断言就是那颗钉子。
  test('所有语种在构造时就已装载，不依赖任何人调 mui 自己的 setLocale', () {
    expect(
      LocaleSettings.instance.translationMap.keys,
      containsAll(MuiAppLocale.values),
      reason: 'slang.yaml 的 lazy 被打开了？那样 mui 只会有 base 语种',
    );
  });

  test('取得到英文，且确实不是中文', () {
    final en = LocaleSettings.instance.getTranslations(MuiAppLocale.en);
    final zh = LocaleSettings.instance.getTranslations(MuiAppLocale.zh);

    expect(en.cancel, isNot(zh.cancel));
    expect(en.cancel, 'Cancel');
  });
}
