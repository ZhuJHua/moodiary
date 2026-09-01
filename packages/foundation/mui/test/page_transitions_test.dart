import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final _theme = buildMuiTheme(brightness: Brightness.light);
const _radii = MuiRadii();
final _rounded = BorderRadius.horizontal(left: Radius.circular(_radii.md));

void main() {
  Widget host(TargetPlatform platform) => MaterialApp(
    theme: _theme.copyWith(platform: platform),
    home: Builder(
      builder: (context) => Scaffold(
        body: SizedBox.expand(
          key: const Key('home'),
          child: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: SizedBox.expand(key: Key('detail'))),
                ),
              ),
              child: const Text('push'),
            ),
          ),
        ),
      ),
    ),
  );

  /// 预测性返回是系统经 `flutter/backgesture` 发进来的，测试里照原样喂一遍。
  Future<void> backGesture(
    WidgetTester tester,
    String method, {
    double progress = 0,
  }) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.backGesture.name,
      SystemChannels.backGesture.codec.encodeMethodCall(
        MethodCall(method, {
          'touchOffset': const [0.0, 300.0],
          'progress': progress,
          'swipeEdge': 0,
        }),
      ),
      (_) {},
    );
    await tester.pump();
  }

  Iterable<T> above<T extends Widget>(WidgetTester tester, String page) =>
      tester.widgetList<T>(
        find.ancestor(of: find.byKey(Key(page)), matching: find.byType(T)),
      );

  Color? scrimAbove(WidgetTester tester, String page) {
    final boxes = above<DecoratedBox>(
      tester,
      page,
    ).where((box) => box.position == DecorationPosition.foreground);
    if (boxes.isEmpty) return null;
    return (boxes.single.decoration as BoxDecoration).color;
  }

  double dxOf(WidgetTester tester, String page) =>
      tester.getTopLeft(find.byKey(Key(page))).dx;

  group('平台分工', () {
    test('Android 是我们那套，iOS/macOS 是 Cupertino，桌面回落默认', () {
      final builders = _theme.pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.android],
        isA<MuiPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.macOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(builders[TargetPlatform.windows], isNull);
    });

    test('时长与官方 FadeForwards 对齐', () {
      final builder =
          _theme.pageTransitionsTheme.builders[TargetPlatform.android]!;
      expect(
        builder.transitionDuration,
        const Duration(
          milliseconds:
              FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
        ),
      );
    });

    testWidgets('iOS 走 Cupertino：左缘拖拽能返回', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.iOS));
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      var clock = Duration.zero;
      final gesture = await tester.startGesture(const Offset(5, 300));
      for (var i = 0; i < 4; i++) {
        clock += const Duration(milliseconds: 16);
        await gesture.moveBy(const Offset(120, 0), timeStamp: clock);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up(timeStamp: clock);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail')), findsNothing);
    });
  });

  group('Android 非手势', () {
    testWidgets('按钮推入走官方 FadeForwards：只横移四分之一屏并淡入', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      final width = tester.getSize(find.byKey(const Key('home'))).width;

      await tester.tap(find.text('push'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final incoming = dxOf(tester, 'detail');
      expect(incoming, greaterThan(0));
      // 我们那套是整屏推；官方那条只走四分之一。
      expect(incoming, lessThan(width * 0.25));

      // 官方那条自带淡入，我们那套没有。
      expect(
        above<FadeTransition>(tester, 'detail').map((f) => f.opacity.value),
        isNotEmpty,
      );
      // 也不该有我们的压暗与圆角。
      expect(scrimAbove(tester, 'home'), isNull);
      expect(
        above<ClipRRect>(tester, 'detail').map((c) => c.borderRadius),
        isNot(contains(_rounded)),
      );

      await tester.pumpAndSettle();
      expect(dxOf(tester, 'detail'), 0);
    });
  });

  group('Android 跟手', () {
    testWidgets('整屏跟手，旧页三分之一视差 + 压暗 + 左缘圆角', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      final width = tester.getSize(find.byKey(const Key('home'))).width;
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      await backGesture(tester, 'startBackGesture');
      await backGesture(tester, 'updateBackGestureProgress', progress: 0.4);

      // 跟手是线性的：进度 0.4 就该正好挪走四成屏宽。
      expect(dxOf(tester, 'detail'), closeTo(width * 0.4, 0.5));
      // 旧页同步跟着走，只走三分之一。
      expect(dxOf(tester, 'home'), closeTo(-width * 0.6 / 3, 0.5));

      final scrim = scrimAbove(tester, 'home')!;
      expect(scrim.a, greaterThan(0));
      expect(scrim.a, lessThanOrEqualTo(0.32));
      expect(scrim.withValues(alpha: 1), _theme.colorScheme.scrim);

      expect(
        above<ClipRRect>(tester, 'detail').map((c) => c.borderRadius),
        contains(_rounded),
      );
    });

    testWidgets('提交后接着往外走，不回弹重放', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      final width = tester.getSize(find.byKey(const Key('home'))).width;
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      await backGesture(tester, 'startBackGesture');
      await backGesture(tester, 'updateBackGestureProgress', progress: 0.4);
      await backGesture(tester, 'commitBackGesture');

      // 框架自带的 handleCommitBackGesture 会先把进度弹回 1.0 再倒放。
      expect(dxOf(tester, 'detail'), greaterThanOrEqualTo(width * 0.4 - 0.5));

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsNothing);
    });

    testWidgets('收尾是减速的，不是匀速跑到头', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      await backGesture(tester, 'startBackGesture');
      await backGesture(tester, 'updateBackGestureProgress', progress: 0.3);
      await backGesture(tester, 'commitBackGesture');
      // 松手那一帧收尾的 ticker 才起跑，位移还是 0，从下一帧开始量。
      await tester.pump(const Duration(milliseconds: 16));

      final detail = find.byKey(const Key('detail'));
      final steps = <double>[];
      var last = dxOf(tester, 'detail');
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (detail.evaluate().isEmpty) break;
        final now = dxOf(tester, 'detail');
        steps.add(now - last);
        last = now;
      }

      expect(steps.length, greaterThan(3));
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], lessThanOrEqualTo(steps[i - 1] + 0.01));
      }
      // 前半程走掉的明显多于后半程。匀速收尾两边一样多。
      final half = steps.length ~/ 2;
      final head = steps.take(half).reduce((a, b) => a + b);
      final tail = steps.skip(half).reduce((a, b) => a + b);
      expect(head, greaterThan(tail * 1.5));
    });

    testWidgets('取消后退回原位', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      await backGesture(tester, 'startBackGesture');
      await backGesture(tester, 'updateBackGestureProgress', progress: 0.4);
      await backGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail')), findsOneWidget);
      expect(dxOf(tester, 'detail'), 0);
    });

    testWidgets('手一碰就提交（一次 update 都没有）也要走完收尾', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      await backGesture(tester, 'startBackGesture');
      await backGesture(tester, 'commitBackGesture');
      await tester.pump(const Duration(milliseconds: 16));

      final width = tester.getSize(find.byType(MaterialApp)).width;
      expect(dxOf(tester, 'detail'), greaterThan(0));
      expect(dxOf(tester, 'detail'), lessThan(width));

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsNothing);
    });

    testWidgets('推入途中就能接手，横向位置接得上', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      await tester.tap(find.text('push'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final at = dxOf(tester, 'detail');
      expect(at, greaterThan(0));

      await backGesture(tester, 'startBackGesture');
      // 官方那条只横移四分之一屏，我们整屏推；接手时要折算，否则当场跳一大段。
      expect(dxOf(tester, 'detail'), closeTo(at, 0.5));

      await backGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail')), findsNothing);
    });

    /// flutter/flutter#174336 的作者踩过这条：`_backGestureObservers` 是「谁认领就发
    /// 给谁」，下层探测器若不判 `isCurrent` 就会把手势截走，顶层反而关不掉。
    /// 本仓的菜单、全屏对话框、视频页都是没有探测器的顶层。
    testWidgets('顶层没有探测器时，返回手势关掉的仍是顶层', (tester) async {
      await tester.pumpWidget(host(TargetPlatform.android));
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) =>
                const Scaffold(body: SizedBox.expand(key: Key('top'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await backGesture(tester, 'startBackGesture');
      await backGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('top')), findsNothing);
      expect(find.byKey(const Key('detail')), findsOneWidget);
    });
  });
}
