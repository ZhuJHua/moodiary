import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/presentation/assistant_notice.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

void main() {
  Widget host(Widget child) {
    final data = buildMuiTheme(brightness: Brightness.light);
    return TranslationProvider(
      child: MuiTheme(
        data: data,
        child: MaterialApp(
          theme: data,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: .topLeft,
              child: SizedBox(width: 360, child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget detail(BuildContext context) =>
      const SizedBox(key: ValueKey('detail'), height: 120, width: 200);

  testWidgets('思考块展开后摘要行消失，标题行不动', (tester) async {
    await tester.pumpWidget(
      host(
        AssistantNotice(
          hideSummaryWhenExpanded: true,
          icon: LucideIcons.brain,
          kind: '已思考 6 秒',
          summary: '第一行思考',
          detail: detail,
        ),
      ),
    );
    expect(find.text('第一行思考'), findsOneWidget);
    final titleTop = tester.getTopLeft(find.text('已思考 6 秒')).dy;

    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();

    expect(find.text('第一行思考'), findsNothing);
    expect(find.byKey(const ValueKey('detail')), findsOneWidget);
    expect(tester.getTopLeft(find.text('已思考 6 秒')).dy, titleTop);
    expect(find.byIcon(LucideIcons.chevronDown), findsOneWidget);

    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();
    expect(find.text('第一行思考'), findsOneWidget);
  });

  testWidgets('工具块展开后摘要保留', (tester) async {
    await tester.pumpWidget(
      host(
        AssistantNotice(
          icon: LucideIcons.textSearch,
          kind: '查询日记',
          summary: '3 篇 · 周末',
          detail: detail,
        ),
      ),
    );
    await tester.tap(find.text('查询日记'));
    await tester.pumpAndSettle();
    expect(find.text('3 篇 · 周末'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail')), findsOneWidget);
  });

  testWidgets('工具详情分参数与结果两段', (tester) async {
    await tester.pumpWidget(
      host(
        const AssistantToolDetail(
          args: {
            'keywords': '周末',
            'limit': 8,
            'ids': ['a', 'b'],
          },
          result: '3 matches (showing 3)',
        ),
      ),
    );
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('结果'), findsOneWidget);
    expect(find.text('3 matches (showing 3)'), findsOneWidget);
    expect(
      find.text('keywords: 周末\nlimit: 8\nids: [\n  "a",\n  "b"\n]'),
      findsOneWidget,
    );
  });

  test('formatToolArgs 标量一行、结构缩进', () {
    expect(
      formatToolArgs({'a': 'x', 'b': true, 'c': null}),
      'a: x\nb: true\nc: null',
    );
    expect(
      formatToolArgs({
        'm': {'k': 1},
      }),
      'm: {\n  "k": 1\n}',
    );
  });
}
