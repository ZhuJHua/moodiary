import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Widget block({required bool expanded, required double screenWidth}) =>
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
                  return block(expanded: expanded, screenWidth: screenWidth);
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

  testWidgets('离屏量出的展开差值 == 真实渲染的差值', (tester) async {
    final realCollapsed = await realHeight(tester, false);
    final realExpanded = await realHeight(tester, true);
    final realDelta = realExpanded - realCollapsed;
    expect(realDelta, greaterThan(0));

    double measure(bool expanded) => getWidgetSizeOffScreen(
      context: hostContext,
      viewSize: const Size(screenWidth, double.infinity),
      widget: block(expanded: expanded, screenWidth: screenWidth),
    ).height;

    expect(
      measure(true) - measure(false),
      moreOrLessEquals(realDelta, epsilon: 0.5),
    );
  });

  testWidgets('宽度给窄了高度就偏大：量的时候必须用真实约束', (tester) async {
    await realHeight(tester, true);

    double at(double width) => getWidgetSizeOffScreen(
      context: hostContext,
      viewSize: Size(width, double.infinity),
      widget: block(expanded: true, screenWidth: screenWidth),
    ).height;

    expect(
      at(140),
      greaterThan(at(screenWidth) * 1.5),
      reason: '窄宽度必须明显更高，否则这条测试没守住东西',
    );
  });
}
