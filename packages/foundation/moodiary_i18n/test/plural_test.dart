import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

/// 复数是这套 i18n 里唯一有分支逻辑的部分，且中文那条要靠手动注册解析器才对
/// （slang 内置表里没有 zh，漏了只打日志不报错）。
void main() {
  setUpAll(() => setupPluralResolvers());

  test('中文只有 other 一种形式', () async {
    await LocaleSettings.setLocale(AppLocale.zh);
    expect(l10n.diary.timelineMonthCount(count: 1), '1 篇');
    expect(l10n.diary.timelineMonthCount(count: 5), '5 篇');
    expect(l10n.media.imageCount(count: 1), '1 张照片');
  });

  test('英文走 CLDR 单复数', () async {
    await LocaleSettings.setLocale(AppLocale.en);
    expect(l10n.diary.timelineMonthCount(count: 1), '1 entry');
    expect(l10n.diary.timelineMonthCount(count: 2), '2 entries');
    expect(l10n.media.imageCount(count: 1), '1 Photo');
    expect(l10n.media.imageCount(count: 3), '3 Photos');
  });

  test('渲染中文复数不再落到 slang 的兜底（那条 print 每次都打，release 也打）', () async {
    await LocaleSettings.setLocale(AppLocale.zh);
    final printed = <String>[];
    runZoned(
      () => l10n.diary.timelineMonthCount(count: 3),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => printed.add(line),
      ),
    );
    expect(printed, isEmpty, reason: 'setupPluralResolvers() 没生效');
  });

  test('语种由 GlobalLocaleState 持有，切了就跟着变', () async {
    await LocaleSettings.setLocale(AppLocale.zh);
    expect(LocaleSettings.currentLocale, AppLocale.zh);
    expect(l10n.common.ok, '确认');
    await LocaleSettings.setLocale(AppLocale.en);
    expect(l10n.common.ok, 'OK');
  });
}
