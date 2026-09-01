import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  late BuildContext hostContext;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: Brightness.light),
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

  testWidgets('量出固定尺寸，不占帧也不进真实树', (tester) async {
    await pumpHost(tester);
    final size = getWidgetSizeOffScreen(
      context: hostContext,
      widget: const SizedBox(width: 120, height: 48),
      viewSize: const Size(400, double.infinity),
    );
    expect(size, const Size(120, 48));
    // 被量的东西不该出现在真实树里。
    expect(find.byType(SizedBox), findsOneWidget); // 只有宿主那个 shrink
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

  // InheritedTheme 会被带过去，所以取主题的组件量得出来。
  testWidgets('主题随上下文带进离屏树', (tester) async {
    await pumpHost(tester);
    final size = getWidgetSizeOffScreen(
      context: hostContext,
      widget: Builder(
        builder: (context) =>
            SizedBox(height: 10, width: context.theme.colors.primary.a * 100),
      ),
      viewSize: const Size(400, double.infinity),
    );
    expect(size.width, 100);
  });

  testWidgets('重复调用不泄漏、结果稳定', (tester) async {
    await pumpHost(tester);
    for (var i = 0; i < 5; i++) {
      expect(
        getWidgetSizeOffScreen(
          context: hostContext,
          widget: const SizedBox(width: 33, height: 77),
          viewSize: const Size(400, double.infinity),
        ),
        const Size(33, 77),
      );
    }
    expect(tester.takeException(), isNull);
  });

  // 真实树里已经挂着同类型 widget 时再离屏建一份，不能互相干扰。
  // 唯一会炸的情况是被量的子树里带了 GlobalKey —— 那种 key 全进程唯一，
  // 同时挂两处就是「Multiple widgets used the same GlobalKey」。
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
}
