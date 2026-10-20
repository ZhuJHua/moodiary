import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mobile/app/build_badge.dart';
import 'package:mui/mui.dart';

void main() {
  testWidgets('only Alpha paints a badge, below the system inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 48);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => BuildBadge(child: child!),
        home: const SizedBox.expand(),
      ),
    );

    final badge = find.byWidgetPredicate(
      (widget) => widget is Banner && widget.message == 'ALPHA',
    );
    expect(badge, appFlavor == 'alpha' ? findsOneWidget : findsNothing);
    if (appFlavor == 'alpha') {
      expect(tester.getTopLeft(badge).dy, 48);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'badge passes taps through and stays above new routes and dialogs',
    (tester) async {
      var taps = 0;
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => BuildBadge(child: child!),
          home: Builder(
            builder: (context) {
              pageContext = context;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      // This point lies on the diagonal ribbon.
      await tester.tapAt(const Offset(24, 24));
      expect(taps, 1);

      Navigator.of(pageContext).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, _, _) => Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      showDialog<void>(
        context: pageContext,
        builder: (_) => const Center(child: Text('dialog')),
      );
      await tester.pumpAndSettle();

      final badge = find.byWidgetPredicate(
        (widget) => widget is Banner && widget.message == 'ALPHA',
      );
      expect(badge, appFlavor == 'alpha' ? findsOneWidget : findsNothing);
      expect(find.text('dialog'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BuildBadge),
          matching: find.text('dialog'),
        ),
        findsOneWidget,
      );
      // The top-level paint must not prevent dismissing the dialog either.
      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
