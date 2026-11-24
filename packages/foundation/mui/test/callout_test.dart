import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final _theme = buildMuiTheme(brightness: .light);

Future<void> _pump(WidgetTester tester, MCallout callout) => tester.pumpWidget(
  MaterialApp(
    theme: _theme,
    localizationsDelegates: const [GlobalMuiLocalizations.delegate],
    home: Scaffold(body: callout),
  ),
);

void main() {
  testWidgets('each level picks its icon and accent', (tester) async {
    final theme = MuiThemeData(_theme);
    for (final (level, icon, color) in [
      (
        MCalloutLevel.info,
        LucideIcons.info,
        theme.colors.harmonize(theme.info),
      ),
      (MCalloutLevel.success, LucideIcons.circleCheck, theme.success),
      (MCalloutLevel.warning, LucideIcons.triangleAlert, theme.warning),
      (MCalloutLevel.error, LucideIcons.circleAlert, theme.colors.error),
    ]) {
      await _pump(tester, MCallout(level: level, message: 'Body'));
      expect(tester.widget<Icon>(find.byIcon(icon)).color, color);
    }
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('title, action and dismiss', (tester) async {
    var actions = 0;
    var dismissals = 0;
    await _pump(
      tester,
      MCallout(
        level: .error,
        icon: LucideIcons.bellOff,
        title: 'Off',
        message: 'Body',
        actionLabel: 'Enable',
        onAction: () => actions++,
        onDismiss: () => dismissals++,
      ),
    );
    expect(find.text('Off'), findsOneWidget);
    expect(find.byIcon(LucideIcons.bellOff), findsOneWidget);
    await tester.tap(find.text('Enable'));
    await tester.tap(find.byTooltip('Close'));
    expect((actions, dismissals), (1, 1));
  });
}
