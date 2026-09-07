import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';
import 'package:mui/src/i18n/strings.g.dart';

void main() {
  const delegate = GlobalMuiLocalizations.delegate;

  group('delegate 解析', () {
    ({String cancel, MuiLocale locale}) load(Locale locale) {
      late MuiLocalizationsData data;
      delegate.load(locale).then((v) => data = v);
      return (cancel: data.cancel, locale: data.$meta.locale);
    }

    test('load 是同步完成的', () {
      expect(load(const Locale('en')).cancel, 'Cancel');
    });

    test('精确命中', () {
      expect(load(const Locale('zh')).locale, MuiLocale.zh);
      expect(load(const Locale('en')).locale, MuiLocale.en);
    });

    test('带国家码的按语言回落', () {
      expect(load(const Locale('zh', 'CN')).locale, MuiLocale.zh);
      expect(load(const Locale('en', 'US')).locale, MuiLocale.en);
    });

    test('不认识的语种回落 base，而不是抛', () {
      expect(load(const Locale('fr')).locale, MuiLocale.zh);
    });

    test('isSupported 恒真', () {
      expect(delegate.isSupported(const Locale('fr')), isTrue);
    });
  });

  group('取串', () {
    Widget host(Locale locale, {bool withDelegate = true}) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: [
        ...GlobalMaterialLocalizations.delegates,
        if (withDelegate) delegate,
      ],
      home: Builder(builder: (context) => Text(context.muiL10n.cancel)),
    );

    testWidgets('跟随 MaterialApp.locale', (tester) async {
      await tester.pumpWidget(host(const Locale('zh')));
      expect(find.text('取消'), findsOneWidget);

      await tester.pumpWidget(host(const Locale('en')));
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('宿主漏挂 delegate：debug 断言', (tester) async {
      await tester.pumpWidget(host(const Locale('en'), withDelegate: false));
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  test('生成物里没有 deferred import', () {
    final generated = File('lib/src/i18n/strings.g.dart').readAsStringSync();
    expect(generated, isNot(contains('deferred as')));
  });
}
