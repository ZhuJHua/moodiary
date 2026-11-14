import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

void main() {
  late BuildContext page;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MuiTheme(
      data: _mui,
      child: MaterialApp(
        theme: _mui,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          GlobalMuiLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        home: Builder(
          builder: (context) {
            page = context;
            return const Scaffold();
          },
        ),
      ),
    ),
  );

  Finder ring() => find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_CountdownRing',
  );

  const action = MSnackbarAction(label: 'Undo', onPressed: _noop);

  testWidgets('the ring shows only for a timed snackbar with an action', (
    tester,
  ) async {
    await pump(tester);
    MSnackbar.show(page, message: 'timed', action: action);
    await tester.pump();
    expect(ring(), findsOneWidget);

    MSnackbar.show(page, message: 'plain');
    await tester.pump();
    expect(find.text('timed'), findsNothing);
    expect(ring(), findsNothing);

    final dismiss = MSnackbar.show(
      page,
      message: 'sticky',
      action: action,
      duration: null,
    );
    await tester.pump();
    expect(ring(), findsNothing);
    dismiss();
    await tester.pumpAndSettle();
    expect(find.text('sticky'), findsNothing);
  });

  testWidgets('it closes by itself, and not while it is held', (tester) async {
    await pump(tester);
    MSnackbar.show(
      page,
      message: 'timed',
      duration: const Duration(seconds: 1),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('timed'), findsNothing);

    MSnackbar.show(page, message: 'held', duration: const Duration(seconds: 1));
    await tester.pump();
    final finger = await tester.startGesture(
      tester.getCenter(find.text('held')),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('held'), findsOneWidget);
    await finger.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('held'), findsNothing);
  });

  testWidgets('the action runs once and close leaves it alone', (tester) async {
    await pump(tester);
    var runs = 0;
    MSnackbar.show(
      page,
      message: 'first',
      action: MSnackbarAction(label: 'Undo', onPressed: () => runs++),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(runs, 1);
    expect(find.text('first'), findsNothing);

    MSnackbar.show(
      page,
      message: 'second',
      action: MSnackbarAction(label: 'Undo', onPressed: () => runs++),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(runs, 1);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('wide windows keep it to a readable width', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);
    MSnackbar.show(page, message: 'wide', duration: null, bottom: 40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final bar = find.ancestor(
      of: find.text('wide'),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(bar.first).width, 420);
    expect(tester.getBottomLeft(bar.first).dy, 860);
  });
}

void _noop() {}
