import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Widget _host({
  required int itemCount,
  String? title,
  double viewportHeight = 600,
  ScrollController? controller,
}) => MaterialApp(
  theme: buildMuiTheme(brightness: Brightness.light),
  home: Scaffold(
    body: SizedBox(
      height: viewportHeight,
      child: CustomScrollView(
        controller: controller,
        slivers: [
          MSliverSettingGroup(
            title: title,
            children: [
              for (var i = 0; i < itemCount; i++)
                SettingListTile(title: 'item$i', onTap: () {}),
            ],
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('n 项之间 n-1 条分隔线，首尾不画', (tester) async {
    await tester.pumpWidget(_host(itemCount: 3));
    expect(find.byType(SettingListTile), findsNWidgets(3));
    expect(find.byType(MSettingDivider), findsNWidgets(2));
  });

  testWidgets('分隔线是一个设备像素：thickness 0 即 Skia hairline', (tester) async {
    await tester.pumpWidget(_host(itemCount: 2));
    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.thickness, 0, reason: '改成 1/devicePixelRatio 会跨两行各画一半');
    expect(divider.height, 0, reason: '线本身不该占额外高度');
  });

  testWidgets('给了标题才有标题行', (tester) async {
    await tester.pumpWidget(_host(itemCount: 2));
    expect(find.byType(SettingTitleTile), findsNothing);

    await tester.pumpWidget(_host(itemCount: 2, title: '显示'));
    expect(find.byType(SettingTitleTile), findsOneWidget);
    expect(find.text('显示'), findsOneWidget);
  });

  group('可排序的组', () {
    final calls = <(int, int)>[];
    setUp(calls.clear);

    // 页面可滚动且设备 slop 小于 kTouchSlop，手柄才真要和滚动抢手势
    Future<void> pumpHost(WidgetTester tester, {bool reorderable = true}) {
      tester.view.gestureSettings = const ui.GestureSettings(
        physicalTouchSlop: 8,
      );
      addTearDown(tester.view.resetGestureSettings);
      return tester.pumpWidget(
        _ReorderHost(const ['a', 'b', 'c'], calls, reorderable: reorderable),
      );
    }

    // 真实触摸是一串小步 move，滚动的设备 slop 会先到
    Future<TestGesture> grabHandle(WidgetTester tester, int i) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(LucideIcons.gripVertical).at(i)),
      );
      for (var step = 0; step < 6; step++) {
        await gesture.moveBy(const Offset(0, 4));
        await tester.pump();
      }
      return gesture;
    }

    int visibleDividers(WidgetTester tester) => tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(MSettingDivider),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .where((o) => o.opacity == 1)
        .length;

    List<String> order(WidgetTester tester) => ['a', 'b', 'c']
      ..sort(
        (x, y) => tester
            .getTopLeft(find.text(x))
            .dy
            .compareTo(tester.getTopLeft(find.text(y)).dy),
      );

    testWidgets('只在相邻行之间画分隔线', (tester) async {
      await pumpHost(tester);
      expect(find.byType(SettingListTile), findsNWidgets(3));
      expect(visibleDividers(tester), 2);
    });

    testWidgets('拖手柄：落位动画结束才回调，to 按移除后的下标', (tester) async {
      await pumpHost(tester);
      final gesture = await grabHandle(tester, 0);
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, isEmpty);
      await tester.pumpAndSettle();
      expect(calls, [(0, 2)]);
      expect(order(tester), ['b', 'c', 'a']);
    });

    testWidgets('长按整行也能拖', (tester) async {
      await pumpHost(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SettingListTile).at(2)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, -160));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, [(2, 0)]);
      expect(order(tester), ['c', 'a', 'b']);
    });

    testWidgets('拖动中洞口两侧的分隔线隐藏，放下后恢复', (tester) async {
      await pumpHost(tester);
      final gesture = await grabHandle(tester, 1);
      await tester.pumpAndSettle();
      expect(visibleDividers(tester), 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(visibleDividers(tester), 2);
    });

    testWidgets('放回原位不回调', (tester) async {
      await pumpHost(tester);
      final gesture = await grabHandle(tester, 1);
      await gesture.moveBy(const Offset(0, -24));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(order(tester), ['a', 'b', 'c']);
    });

    testWidgets('无障碍：上移/下移', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHost(tester);
      final node = tester.getSemantics(find.text('a'));
      final down = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: '下移'),
      );
      expect(node.getSemanticsData().customSemanticsActionIds, [down]);
      node.owner!.performAction(node.id, SemanticsAction.customAction, down);
      await tester.pumpAndSettle();
      expect(calls, [(0, 1)]);
      expect(order(tester), ['b', 'a', 'c']);
      semantics.dispose();
    });

    testWidgets('关掉 reorderable：手柄、长按、无障碍动作都不排序', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHost(tester, reorderable: false);
      final gesture = await grabHandle(tester, 0);
      await gesture.moveBy(const Offset(0, 120));
      await gesture.up();
      await tester.pumpAndSettle();

      final press = await tester.startGesture(
        tester.getCenter(find.byType(SettingListTile).at(2)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await press.moveBy(const Offset(0, -160));
      await press.up();
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(order(tester), ['a', 'b', 'c']);
      expect(
        tester
            .getSemantics(find.text('a'))
            .getSemanticsData()
            .customSemanticsActionIds,
        anyOf(isNull, isEmpty),
      );
      semantics.dispose();
    });
  });

  group('圆角落在首末项上', () {
    final lg = buildMuiTheme(brightness: Brightness.light)
        .extension<MuiTokens>()!
        .radii
        .lg;

    List<BorderRadius> radiiOf(WidgetTester tester) => tester
        .widgetList<ClipRRect>(
          find.descendant(
            of: find.byType(MSliverSettingGroup),
            matching: find.byType(ClipRRect),
          ),
        )
        .map((c) => c.borderRadius as BorderRadius)
        .toList();

    testWidgets('首项只圆上面、末项只圆下面，中间项不包', (tester) async {
      await tester.pumpWidget(_host(itemCount: 3));
      final radii = radiiOf(tester);
      expect(radii.length, 2, reason: '中间那项不该多包一层');
      expect(radii.first, BorderRadius.vertical(top: Radius.circular(lg)));
      expect(radii.last, BorderRadius.vertical(bottom: Radius.circular(lg)));
    });

    testWidgets('只有一项时四个角都圆', (tester) async {
      await tester.pumpWidget(_host(itemCount: 1));
      expect(radiiOf(tester).single, BorderRadius.all(Radius.circular(lg)));
    });

    testWidgets('按压反馈是 MInkWell 的自绘遮罩，不吃 material 水波', (tester) async {
      await tester.pumpWidget(_host(itemCount: 2));
      expect(find.byType(MInkWell), findsNWidgets(2));
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });
  });
}

class _ReorderHost extends StatefulWidget {
  final List<String> initial;
  final List<(int, int)> calls;
  final bool reorderable;

  const _ReorderHost(this.initial, this.calls, {this.reorderable = true});

  @override
  State<_ReorderHost> createState() => _ReorderHostState();
}

class _ReorderHostState extends State<_ReorderHost> {
  late var _items = widget.initial;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildMuiTheme(brightness: Brightness.light),
    locale: const Locale('zh'),
    localizationsDelegates: const [
      ...GlobalMaterialLocalizations.delegates,
      GlobalMuiLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh'), Locale('en')],
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          MSliverReorderableSettingGroup<String>(
            items: _items,
            reorderable: widget.reorderable,
            onReorder: (from, to) => setState(() {
              widget.calls.add((from, to));
              _items = [..._items];
              _items.insert(to, _items.removeAt(from));
            }),
            itemBuilder: (_, item, handle) =>
                SettingListTile(title: item, trailing: handle),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ],
      ),
    ),
  );
}
