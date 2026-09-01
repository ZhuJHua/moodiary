import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

/// 复刻思考块的形状：Container(maxWidth 82%) > Column(mainAxisSize.min)，
/// 收起时宽度只有那行窄标题，展开时正文要吃满约束。
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
          // 必须是**松**约束：真实列表里条目外面是 Align。给紧约束的话
          // block 自己的 maxWidth 会被 enforce 夹掉，量的就不是同一回事了。
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

  // 上一版的 bug：拿「这块当时的宽度」去量，而不是拿它在真实树里那份约束。
  // 收起态下这块只有标题那么窄，正文在那个宽度上会多换好几行，量出来的高度偏大 ——
  // 补偿跟着偏，长内容甚至会把列表甩到内容之外。
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
