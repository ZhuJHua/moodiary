import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

void main() {
  late int verifyCalls;

  setUp(() {
    verifyCalls = 0;
    final secure = MemorySecureKVStorage();
    secure.data['password'] = r'$argon2-stored';
    getIt.pushNewScope(
      init: (gi) {
        gi.registerSingleton<IKVStorage>(MemoryKVStorage());
        gi.registerSingleton<ISecureKVStorage>(secure);
      },
    );
  });

  tearDown(() async {
    AppLockPin.verifier = (hash, pin) async => false;
    await getIt.popScope();
  });

  Widget host() => TranslationProvider(
    child: MuiTheme(
      data: _mui,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          GlobalMuiLocalizations.delegate,
        ],
        supportedLocales: AppLocaleUtils.supportedLocales,
        home: const LockPage(lockType: 'pause'),
      ),
    ),
  );

  Future<void> enterPin(WidgetTester t, String pin) async {
    for (final d in pin.split('')) {
      await t.tap(find.text(d));
      await t.pump();
    }
    await t.pump(kLockVerifyDelay + const Duration(milliseconds: 1));
    await t.pump();
  }

  Future<void> settleFailure(WidgetTester t) async {
    await t.pump(kLockClearDelay + const Duration(milliseconds: 20));
    await t.pump(kLockShakeDuration * 2 + const Duration(milliseconds: 20));
    await t.pump();
  }

  testWidgets('校验在飞时退格与输入都被挡住——不会起第二个 _verify', (t) async {
    final gate = Completer<bool>();
    AppLockPin.verifier = (hash, pin) {
      verifyCalls += 1;
      return gate.future;
    };
    await t.pumpWidget(host());
    await enterPin(t, '1111');
    expect(verifyCalls, 1, reason: '校验已发起且在飞');

    await t.tap(find.byIcon(LucideIcons.delete));
    await t.pump();
    await t.tap(find.text('2'));
    await t.pump(const Duration(milliseconds: 200));

    gate.complete(false);
    await t.pump();
    await settleFailure(t);
    expect(verifyCalls, 1, reason: '整个飞行窗口只允许一次校验');
    expect(find.textContaining('还可重试 4 次'), findsOneWidget);
  });

  testWidgets('连错五次进入冷却；冷却期输入无效；冷却结束计数清零', (t) async {
    AppLockPin.verifier = (hash, pin) async {
      verifyCalls += 1;
      return false;
    };
    await t.pumpWidget(host());

    for (var i = 0; i < 5; i++) {
      await enterPin(t, '1111');
      await settleFailure(t);
    }
    expect(verifyCalls, 5);
    expect(find.textContaining('尝试次数过多'), findsOneWidget);

    await enterPin(t, '2222');
    expect(verifyCalls, 5, reason: '冷却期输入必须被挡住');

    for (var s = 0; s < 30; s++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pump();
    expect(find.textContaining('尝试次数过多'), findsNothing);

    await enterPin(t, '3333');
    await settleFailure(t);
    expect(verifyCalls, 6);
    expect(find.textContaining('还可重试 4 次'), findsOneWidget);
  });

  testWidgets('校验通过：不计失败、进入已解锁态', (t) async {
    AppLockPin.verifier = (hash, pin) async {
      verifyCalls += 1;
      return pin == '1234';
    };
    await t.pumpWidget(host());
    await enterPin(t, '1234');
    await t.pump(kLockClearDelay + const Duration(milliseconds: 20));
    expect(verifyCalls, 1);
    expect(find.textContaining('还可重试'), findsNothing);
    expect(find.byIcon(LucideIcons.lockOpen), findsOneWidget);
    await t.tap(find.text('1'), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 200));
    expect(verifyCalls, 1);
    await t.pump(kLockClearDelay + const Duration(milliseconds: 20));
  });
}
