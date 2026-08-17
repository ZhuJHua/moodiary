import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final ThemeData _mui = buildMuiTheme(brightness: Brightness.light);

Widget host(Widget child) => MaterialApp(
  theme: _mui,
  home: Scaffold(body: Center(child: child)),
);

/// 找到 [MInkWell] 自己那层遮罩，返回它当前的颜色。
///
/// 取 `.last` 而不是 `.first`：遮罩是 Stack 的**第二个**孩子，深度优先遍历会先
/// 走完 child 子树 —— 嵌套场景下 `.first` 拿到的是内层那个 MInkWell 的遮罩。
Color? overlayColorOf(WidgetTester tester, Finder inkWell) {
  final box = tester.widget<ColoredBox>(
    find.descendant(of: inkWell, matching: find.byType(ColoredBox)).last,
  );
  return box.color;
}

bool isPressed(WidgetTester tester, Finder inkWell) =>
    overlayColorOf(tester, inkWell) != Colors.transparent;

void main() {
  testWidgets('按下出现遮罩，松手后延迟撤掉', (tester) async {
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
    expect(isPressed(tester, finder), isFalse);

    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();
    expect(isPressed(tester, finder), isTrue);

    await gesture.up();
    await tester.pump();
    // 松手当帧还留着 —— 否则快速点一下根本看不见反馈。
    expect(isPressed(tester, finder), isTrue);
    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 80));
    expect(isPressed(tester, finder), isFalse);
  });

  // 这是选自绘遮罩而不是 ink feature 的理由：反馈与背景解耦，
  // 不需要在自带底色的东西下面再垫一层 Material。
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
    await tester.pump(const Duration(milliseconds: 80));
  });

  // 一行里再放一颗按钮：按按钮时只有按钮高亮，整行不跟着亮。
  testWidgets('嵌套时内层赢，外层抑制自己的高亮', (tester) async {
    await tester.pumpWidget(
      host(
        MInkWell(
          key: const ValueKey('outer'),
          onTap: () {},
          child: SizedBox(
            width: 200,
            height: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: MInkWell(
                key: const ValueKey('inner'),
                onTap: () {},
                child: const SizedBox(width: 60, height: 60),
              ),
            ),
          ),
        ),
      ),
    );
    final outer = find.byKey(const ValueKey('outer'));
    final inner = find.byKey(const ValueKey('inner'));

    final gesture = await tester.startGesture(tester.getCenter(inner));
    // 内外两个 tap 识别器一起进 arena，谁都没立刻赢，`onTapDown` 因此被推迟到
    // kPressTimeout 之后 —— 嵌套 InkWell 也是这个行为。
    await tester.pump(const Duration(milliseconds: 150));
    expect(isPressed(tester, inner), isTrue);
    expect(isPressed(tester, outer), isFalse, reason: '内层按着的时候外层不该也亮');

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 80));
    expect(isPressed(tester, inner), isFalse);
    expect(isPressed(tester, outer), isFalse);
  });

  testWidgets('按外层空白处只有外层亮', (tester) async {
    await tester.pumpWidget(
      host(
        MInkWell(
          key: const ValueKey('outer'),
          onTap: () {},
          child: SizedBox(
            width: 200,
            height: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: MInkWell(
                key: const ValueKey('inner'),
                onTap: () {},
                child: const SizedBox(width: 40, height: 60),
              ),
            ),
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
    await tester.pump(const Duration(milliseconds: 80));
  });

  // `onTap: enabled ? handler : null` 是调用点的惯用写法，得表示「不可点」。
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
    expect(isPressed(tester, finder), isFalse);
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
    expect(isPressed(tester, finder), isFalse);
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
    // 可滚动区域里，tap 识别器要和 drag 抢 arena，`onTapDown` 被推迟到
    // kPressTimeout（100ms）之后才发 —— 这与 InkWell 的行为一致，不是回归。
    await tester.pump(const Duration(milliseconds: 150));
    expect(isPressed(tester, finder), isTrue);

    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(isPressed(tester, finder), isFalse, reason: '滚动抢走手势后不该还亮着');
    await gesture.up();
    await tester.pumpAndSettle();
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
    await tester.pump(const Duration(milliseconds: 80));
  });
}
