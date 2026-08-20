import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';
// 生成物不进 barrel（AppLocaleUtils 与 App 那份撞名），包内测试直接引。
import 'package:mui/src/i18n/strings.g.dart';

void main() {
  const delegate = GlobalMuiLocalizations.delegate;

  group('delegate 解析', () {
    ({String text, MuiLocale locale}) load(Locale locale) {
      late MuiLocalizationsData data;
      delegate.load(locale).then((v) => data = v);
      return (text: data.toastError, locale: data.$meta.locale);
    }

    test('load 是同步完成的', () {
      // lazy: false 让所有语种在编译期就在，delegate 因此能返回 SynchronousFuture：
      // `Localizations` 不会为它多等一帧，测试里也不用 pump 两次。
      // 上面那个 `.then` 立刻赋值就是这条的证据——异步的话下一行读 data 会抛。
      expect(load(const Locale('en')).text, 'Error');
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
      // 只报自己支持的两种，宿主一旦支持第三种语言就整个丢掉这份 delegate。
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
      home: Builder(builder: (context) => Text(context.muiL10n.toastError)),
    );

    testWidgets('跟随 MaterialApp.locale', (tester) async {
      await tester.pumpWidget(host(const Locale('zh')));
      expect(find.text('出错了'), findsOneWidget);

      await tester.pumpWidget(host(const Locale('en')));
      await tester.pump();
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('宿主漏挂 delegate：debug 断言', (tester) async {
      // release 里断言被剥掉，回落 base 语种而不是崩——组件库不该为几个通用词
      // 让宿主整个挂掉，但静默回落等于英文用户看到中文，所以 debug 下必须响。
      await tester.pumpWidget(host(const Locale('en'), withDelegate: false));
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  test('生成物里没有 deferred import', () {
    // slang.yaml 的 lazy 被打开就会变成 deferred，而 delegate 里用的 buildSync
    // 绕过 loadLibrary()：VM 上照跑，web 上直接抛。这条盯着那个开关。
    final generated = File('lib/src/i18n/strings.g.dart').readAsStringSync();
    expect(generated, isNot(contains('deferred as')));
  });
}
