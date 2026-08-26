import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

/// 应用锁状态机的回归测试。「飞行中退格起第二个 _verify、五次机会实际不到五次」
/// 是修过的真实缺陷（见 lock_page._onBackspace 的注释），此前只能人肉复现。
/// Argon2 原语经 AppLockPin.verifier 注入（宿主单测无 Rust FFI）；lockType
/// 传 'pause' 使解锁走 Navigator.pop、不碰路由契约。
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
    // 第四位落下后延 120ms 才发起校验。
    await t.pump(const Duration(milliseconds: 120));
    await t.pump();
  }

  /// 错误分支的收尾：抖动动画（320ms 往返）+ 280ms 后清 pin 写提示。
  Future<void> settleFailure(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 400));
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

    // 飞行中退格 + 补位：修过的缺陷是这里会起第二个 _verify、多记一次失败。
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

    // 冷却期：键盘无效，不发起校验。
    await enterPin(t, '2222');
    expect(verifyCalls, 5, reason: '冷却期输入必须被挡住');

    // 冷却 30 秒逐秒走完后计数清零、提示消失。
    for (var s = 0; s < 30; s++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pump();
    expect(find.textContaining('尝试次数过多'), findsNothing);

    // 再错一次：从头数（还剩 4 次），而不是直接再进冷却。
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
    await t.pump(const Duration(milliseconds: 300));
    expect(verifyCalls, 1);
    expect(find.textContaining('还可重试'), findsNothing);
    // 已解锁态：锁形图标翻开；解锁后输入被挡住、不再发起校验。
    expect(find.byIcon(LucideIcons.lockOpen), findsOneWidget);
    await t.tap(find.text('1'), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 200));
    expect(verifyCalls, 1);
    // 结掉 280ms 的 pop 延迟，别留 pending timer（根路由 pop 是 no-op）。
    await t.pump(const Duration(milliseconds: 300));
  });
}
