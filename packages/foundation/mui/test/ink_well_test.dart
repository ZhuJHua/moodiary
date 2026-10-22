import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final ThemeData _mui = buildMuiTheme(brightness: Brightness.light);

Widget host(Widget child) => MaterialApp(
  theme: _mui,
  home: Scaffold(body: Center(child: child)),
);

Color? overlayColorOf(WidgetTester tester, Finder inkWell) {
  final box = tester.widget<ColoredBox>(
    find.descendant(of: inkWell, matching: find.byType(ColoredBox)).last,
  );
  return box.color;
}

double level(WidgetTester tester, Finder inkWell) => tester
    .widget<FadeTransition>(
      find.descendant(of: inkWell, matching: find.byType(FadeTransition)).last,
    )
    .opacity
    .value;

bool isPressed(WidgetTester tester, Finder inkWell) =>
    level(tester, inkWell) == 1;

Future<void> frames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

Widget nested({
  required VoidCallback? outerTap,
  VoidCallback? outerLongPress,
  required Widget inner,
}) => MInkWell(
  key: const ValueKey('outer'),
  onTap: outerTap,
  onLongPress: outerLongPress,
  child: SizedBox(
    width: 200,
    height: 60,
    child: Align(alignment: Alignment.centerRight, child: inner),
  ),
);

class _Probe extends StatefulWidget {
  final void Function() onInit;

  const _Probe({required this.onInit});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 100, height: 40);
}

void main() {
  testWidgets('按下出现遮罩，快速点按也至少留 100ms 再淡出', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        MInkWell(
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    expect(level(tester, finder), 0);

    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();
    expect(isPressed(tester, finder), isTrue);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 90));
    expect(isPressed(tester, finder), isTrue);
    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 20));
    await frames(tester);
    expect(level(tester, finder), inExclusiveRange(0, 1), reason: '要淡出，不是硬切');
    await tester.pumpAndSettle();
    expect(level(tester, finder), 0);
  });

  testWidgets('按住超过 100ms 再松手立刻开始淡出', (tester) async {
    await tester.pumpWidget(
      host(
        MInkWell(onTap: () {}, child: const SizedBox(width: 100, height: 40)),
      ),
    );
    final finder = find.byType(MInkWell);
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 300));
    expect(isPressed(tester, finder), isTrue);
    await gesture.up();
    await frames(tester);
    expect(level(tester, finder), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(level(tester, finder), 0);
  });

  testWidgets('同时有长按时，按住 100–200ms 的点按也留满 100ms', (tester) async {
    await tester.pumpWidget(
      host(
        MInkWell(
          onTap: () {},
          onLongPress: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 110));
    expect(isPressed(tester, finder), isTrue);
    await gesture.up();
    await frames(tester);
    expect(isPressed(tester, finder), isTrue, reason: '长按的取消不该截掉点按的最短显示');
    await tester.pumpAndSettle();
  });

  testWidgets('fade：按下立刻压内容透明度，松手淡回，不铺遮罩', (tester) async {
    await tester.pumpWidget(
      host(
        MInkWell.fade(
          onTap: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    final pressed = MuiTheme.viewOf(_mui).states.pressedContentOpacity;
    expect(
      find.descendant(of: finder, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    expect(level(tester, finder), 1);

    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();
    expect(level(tester, finder), pressed, reason: '按下立刻压暗，不渐变');

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 90));
    expect(level(tester, finder), pressed, reason: '快速点按也至少压暗 100ms');
    await tester.pump(const Duration(milliseconds: 20));
    await frames(tester);
    expect(level(tester, finder), inExclusiveRange(pressed, 1));
    await tester.pumpAndSettle();
    expect(level(tester, finder), 1);
  });

  testWidgets('没有祖先 Material 也能出反馈', (tester) async {
    await tester.pumpWidget(
      MuiTheme(
        data: _mui,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MInkWell(
            onTap: () {},
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();
    expect(isPressed(tester, finder), isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('嵌套时内层赢，外层抑制自己的高亮', (tester) async {
    await tester.pumpWidget(
      host(
        nested(
          outerTap: () {},
          inner: MInkWell(
            key: const ValueKey('inner'),
            onTap: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      ),
    );
    final outer = find.byKey(const ValueKey('outer'));
    final inner = find.byKey(const ValueKey('inner'));

    final gesture = await tester.startGesture(tester.getCenter(inner));
    await tester.pump(const Duration(milliseconds: 150));
    expect(isPressed(tester, inner), isTrue);
    expect(level(tester, outer), 0, reason: '内层按着的时候外层不该也亮');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(level(tester, inner), 0);
    expect(level(tester, outer), 0);
  });

  testWidgets('内层接手按压时外层遮罩立刻撤掉，不淡出', (tester) async {
    await tester.pumpWidget(
      host(
        nested(
          outerTap: null,
          outerLongPress: () {},
          inner: MInkWell(
            key: const ValueKey('inner'),
            onTap: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      ),
    );
    final outer = find.byKey(const ValueKey('outer'));
    final inner = find.byKey(const ValueKey('inner'));

    final gesture = await tester.startGesture(tester.getCenter(inner));
    await tester.pump();
    expect(isPressed(tester, outer), isTrue);

    await tester.pump(const Duration(milliseconds: 110));
    expect(isPressed(tester, inner), isTrue);
    expect(level(tester, outer), 0, reason: '外层被内层抑制时不该还在淡出');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('外层淡出途中内层被按下，外层立刻归零', (tester) async {
    await tester.pumpWidget(
      host(
        nested(
          outerTap: () {},
          inner: MInkWell(
            key: const ValueKey('inner'),
            onTap: () {},
            child: const SizedBox(width: 40, height: 60),
          ),
        ),
      ),
    );
    final outer = find.byKey(const ValueKey('outer'));
    final inner = find.byKey(const ValueKey('inner'));

    await tester.tapAt(tester.getTopLeft(outer) + const Offset(10, 30));
    await tester.pump(const Duration(milliseconds: 110));
    await frames(tester);
    expect(level(tester, outer), inExclusiveRange(0, 1));

    final gesture = await tester.startGesture(tester.getCenter(inner));
    await tester.pump(const Duration(milliseconds: 110));
    expect(isPressed(tester, inner), isTrue);
    expect(level(tester, outer), 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('内层点按后把自己移除或禁用，不在构建期间改外层', (tester) async {
    for (final disable in [false, true]) {
      var alive = true;
      await tester.pumpWidget(
        host(
          nested(
            outerTap: null,
            outerLongPress: () {},
            inner: StatefulBuilder(
              builder: (context, setState) => alive || disable
                  ? MInkWell(
                      key: const ValueKey('inner'),
                      enabled: alive,
                      onTap: () => setState(() => alive = false),
                      child: const SizedBox(width: 60, height: 60),
                    )
                  : const SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('inner')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(level(tester, find.byKey(const ValueKey('outer'))), 0);
    }
  });

  testWidgets('按外层空白处只有外层亮', (tester) async {
    await tester.pumpWidget(
      host(
        nested(
          outerTap: () {},
          inner: MInkWell(
            key: const ValueKey('inner'),
            onTap: () {},
            child: const SizedBox(width: 40, height: 60),
          ),
        ),
      ),
    );
    final outer = find.byKey(const ValueKey('outer'));
    final gesture = await tester.startGesture(
      tester.getTopLeft(outer) + const Offset(10, 30),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(isPressed(tester, outer), isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('一个回调都不传时不吃指针，点击穿到下面', (tester) async {
    var belowTaps = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 100,
          height: 40,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => belowTaps++,
                  child: const ColoredBox(color: Color(0xFF123456)),
                ),
              ),
              const Positioned.fill(child: MInkWell(child: SizedBox())),
            ],
          ),
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump();
    expect(belowTaps, 1);
    expect(level(tester, finder), 0);
  });

  testWidgets('enabled: false 不出反馈也不回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        MInkWell(
          enabled: false,
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
    expect(level(tester, finder), 0);
  });

  testWidgets('切换 enabled 或去掉 onTap 都不重建子树', (tester) async {
    var inits = 0;
    Future<void> mount(bool on, {required bool dropTap}) => tester.pumpWidget(
      host(
        MInkWell(
          enabled: on,
          onTap: on || !dropTap ? () {} : null,
          child: _Probe(onInit: () => inits++),
        ),
      ),
    );
    for (final dropTap in [false, true]) {
      await mount(true, dropTap: dropTap);
      await mount(false, dropTap: dropTap);
      await mount(true, dropTap: dropTap);
    }
    expect(inits, 1);
  });

  testWidgets('按住时被禁用，松手不再回调', (tester) async {
    var taps = 0;
    Future<void> mount(bool enabled) => tester.pumpWidget(
      host(
        MInkWell(
          enabled: enabled,
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await mount(true);
    final finder = find.byType(MInkWell);
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 150));
    await mount(false);
    expect(level(tester, finder), 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('按住时禁用再恢复，松手也不回调', (tester) async {
    var taps = 0;
    Future<void> mount(bool enabled) => tester.pumpWidget(
      host(
        MInkWell(
          enabled: enabled,
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await mount(true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MInkWell)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await mount(false);
    await tester.pump(const Duration(milliseconds: 50));
    await mount(true);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('长按被抢走后外层赢下点按，也要亮出按压', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        nested(
          outerTap: () => taps++,
          inner: MInkWell(
            key: const ValueKey('inner'),
            onLongPress: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      ),
    );
    final outer = find.byKey(const ValueKey('outer'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('inner'))),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(level(tester, outer), 0);
    await gesture.up();
    var peak = 0.0;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (level(tester, outer) > peak) peak = level(tester, outer);
    }
    expect(taps, 1);
    expect(peak, 1, reason: '真正触发 onTap 的那一层得有按压反馈');
    await tester.pumpAndSettle();
  });

  testWidgets('内外层一起被滚动取消时外层不闪', (tester) async {
    await tester.pumpWidget(
      host(
        ListView(
          children: [
            nested(
              outerTap: () {},
              inner: MInkWell(
                key: const ValueKey('inner'),
                onTap: () {},
                child: const SizedBox(width: 60, height: 60),
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final outer = find.byKey(const ValueKey('outer'));
    final inner = find.byKey(const ValueKey('inner'));
    final gesture = await tester.startGesture(tester.getCenter(inner));
    await tester.pump(const Duration(milliseconds: 150));
    expect(isPressed(tester, inner), isTrue);

    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(level(tester, outer), 0, reason: '外层不该在内层取消时闪一下');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('取消（被外层滚动抢走）时撤掉高亮', (tester) async {
    await tester.pumpWidget(
      host(
        ListView(
          children: [
            MInkWell(
              onTap: () {},
              child: const SizedBox(width: 100, height: 200),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 150));
    expect(isPressed(tester, finder), isTrue);

    await gesture.moveBy(const Offset(0, -60));
    await frames(tester);
    expect(isPressed(tester, finder), isFalse, reason: '滚动抢走手势后不该还亮着');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(level(tester, finder), 0);
  });

  testWidgets('overlayColor 可覆盖，默认取 pressedOpacity 档', (tester) async {
    await tester.pumpWidget(
      host(
        MInkWell(
          overlayColor: const Color(0xFF00FF00),
          onTap: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    final finder = find.byType(MInkWell);
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();
    expect(overlayColorOf(tester, finder), const Color(0xFF00FF00));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('固定高度下子节点撑满，不被顶到上边', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 32,
          child: MInkWell(
            onTap: () {},
            child: const Row(mainAxisSize: .min, children: [Text('胶囊')]),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Row)).height, 32);
  });
}
