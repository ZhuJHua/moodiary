import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Widget _block({required bool expanded, required double screenWidth}) =>
    Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.82),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 120, height: 30),
          if (expanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                '这是一段很长的思考过程，长到必须换很多行才放得下。'
                '它的高度完全取决于可用宽度：宽度给窄了，行数就多，量出来的高度就偏大。'
                '这条测试要钉住的就是——离屏量出来的展开高度差，必须等于真实渲染出来的差值。',
              ),
            ),
        ],
      ),
    );

void main() {
  const screenWidth = 400.0;
  late BuildContext hostContext;

  Future<void> pumpHost(
    WidgetTester tester, {
    MuiRadii radii = const MuiRadii(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: Brightness.light, radii: radii),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Future<double> realHeight(WidgetTester tester, bool expanded) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: screenWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (context) {
                  hostContext = context;
                  return _block(expanded: expanded, screenWidth: screenWidth);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(Column)).height;
  }

  testWidgets('量出固定尺寸，不占帧也不进真实树', (tester) async {
    await pumpHost(tester);
    final size = getWidgetSizeOffScreen(
      context: hostContext,
      widget: const SizedBox(width: 120, height: 48),
      viewSize: const Size(400, double.infinity),
    );
    expect(size, const Size(120, 48));
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('宽度受限、高度不限时量出换行后的真实高度', (tester) async {
    await pumpHost(tester);
    const text = Text('这是一段会换行的长文本，用来验证高度是量出来的而不是估出来的。');

    final narrow = getWidgetSizeOffScreen(
      context: hostContext,
      widget: text,
      viewSize: const Size(120, double.infinity),
    );
    final wide = getWidgetSizeOffScreen(
      context: hostContext,
      widget: text,
      viewSize: const Size(600, double.infinity),
    );

    expect(narrow.width, lessThanOrEqualTo(120));
    expect(narrow.height, greaterThan(wide.height), reason: '窄的那次要换更多行');
  });

  testWidgets('主题随上下文带进离屏树', (tester) async {
    await pumpHost(tester, radii: const MuiRadii(lg: 37));
    final size = getWidgetSizeOffScreen(
      context: hostContext,
      widget: Builder(
        builder: (context) =>
            SizedBox(height: 10, width: context.theme.radii.lg),
      ),
      viewSize: const Size(400, double.infinity),
    );
    expect(size.width, 37, reason: '离屏树没接到宿主主题，取到的是兜底 token');
  });

  testWidgets('OffscreenMeasurer 复用脚手架连量多件，State 不跨件共享', (tester) async {
    await pumpHost(tester);
    final inits = <int>[];
    final measurer = OffscreenMeasurer(
      hostContext,
      viewSize: const Size(400, double.infinity),
    );
    addTearDown(measurer.dispose);

    expect(
      measurer.measure(_InitProbe(id: 1, height: 30, log: inits)).height,
      30,
    );
    expect(
      measurer.measure(_InitProbe(id: 2, height: 70, log: inits)).height,
      70,
    );
    expect(
      measurer
          .measure(const SelectionArea(child: SizedBox(width: 50, height: 44)))
          .height,
      44,
    );
    expect(inits, [1, 2, -1, -2], reason: '每件都该走自己的 initState，量完即释放');
    expect(find.byType(_InitProbe), findsNothing);
  });

  testWidgets('被量的子树里带 GlobalKey 会撞车（带 GlobalKey 的祖先包不进来）', (tester) async {
    final shared = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return SizedBox(key: shared, width: 10, height: 10);
            },
          ),
        ),
      ),
    );

    getWidgetSizeOffScreen(
      context: hostContext,
      widget: SizedBox(key: shared, width: 50, height: 50),
      viewSize: const Size(400, double.infinity),
    );
    await tester.pump();
    expect(
      tester.takeException(),
      isNotNull,
      reason: '同一个 GlobalKey 挂两处必须炸出来，而不是悄悄错位',
    );
  });

  testWidgets('离屏量出的展开差值 == 真实渲染的差值', (tester) async {
    final realCollapsed = await realHeight(tester, false);
    final realExpanded = await realHeight(tester, true);
    final realDelta = realExpanded - realCollapsed;
    expect(realDelta, greaterThan(0));

    double measure(bool expanded) => getWidgetSizeOffScreen(
      context: hostContext,
      viewSize: const Size(screenWidth, double.infinity),
      widget: _block(expanded: expanded, screenWidth: screenWidth),
    ).height;

    expect(
      measure(true) - measure(false),
      moreOrLessEquals(realDelta, epsilon: 0.5),
    );
  });
}

class _InitProbe extends StatefulWidget {
  const _InitProbe({required this.id, required this.height, required this.log});

  final int id;
  final double height;
  final List<int> log;

  @override
  State<_InitProbe> createState() => _InitProbeState();
}

class _InitProbeState extends State<_InitProbe> {
  @override
  void initState() {
    super.initState();
    widget.log.add(widget.id);
  }

  @override
  void dispose() {
    widget.log.add(-widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 100, height: widget.height);
}
