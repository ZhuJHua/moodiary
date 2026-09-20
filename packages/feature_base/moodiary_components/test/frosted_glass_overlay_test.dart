import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: FrostedGlassOverlayComponent(child: child));

  testWidgets('父级换 child 时 App entry 会跟着更新', (tester) async {
    await tester.pumpWidget(host(const Text('first')));
    expect(find.text('first'), findsOneWidget);

    await tester.pumpWidget(host(const Text('second')));
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('静息态：遮罩存在但不模糊、不吃点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        GestureDetector(
          onTap: () => tapped = true,
          child: const SizedBox.expand(child: Text('app')),
        ),
      ),
    );

    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.enabled, isFalse, reason: '没切后台时不该真的跑模糊');

    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(BackdropFilter),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue, reason: '透明时必须让点击穿过去');

    await tester.tap(find.text('app'));
    expect(tapped, isTrue);
  });
}
