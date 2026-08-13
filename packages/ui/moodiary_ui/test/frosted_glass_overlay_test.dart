import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: FrostedGlassOverlayComponent(child: child));

  testWidgets('App 分支照常渲染 —— entry 挂错整屏会白', (tester) async {
    await tester.pumpWidget(host(const Text('app')));
    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('父级换 child 时 App entry 会跟着更新', (tester) async {
    await tester.pumpWidget(host(const Text('first')));
    expect(find.text('first'), findsOneWidget);

    // entry 的 builder 闭包捕获旧 child，没有 markNeedsBuild 就会停在上一帧。
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

    // MaterialApp / Overlay 自己也会插 IgnorePointer，取离遮罩最近的那个。
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
