import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

void main() {
  // T = String? with a null-valued chip mirrors the home category "全部" usage.
  Widget host({
    required String? selected,
    required ValueChanged<String?> onSelected,
    Widget? trailing,
  }) {
    return MuiTheme(
      data: _mui,
      child: MaterialApp(
        home: Scaffold(
          body: MChipBar<String?>(
            selected: selected,
            onSelected: onSelected,
            trailing: trailing,
            items: const [
              MChipData(value: null, label: 'All'),
              MChipData(value: 'a', label: 'Work', accentColor: Colors.red),
              MChipData(value: 'b', label: 'Life'),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders all chips', (tester) async {
    await tester.pumpWidget(host(selected: null, onSelected: (_) {}));
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Life'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its value', (tester) async {
    String? picked = 'unset';
    var called = false;
    await tester.pumpWidget(
      host(
        selected: null,
        onSelected: (v) {
          picked = v;
          called = true;
        },
      ),
    );
    await tester.tap(find.text('Work'));
    await tester.pump();
    expect(called, isTrue);
    expect(picked, 'a');
  });

  testWidgets('the null-valued chip reports null (no crash)', (tester) async {
    var called = false;
    String? picked = 'unset';
    await tester.pumpWidget(
      host(
        selected: 'a',
        onSelected: (v) {
          called = true;
          picked = v;
        },
      ),
    );
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(called, isTrue);
    expect(picked, isNull);
  });

  testWidgets('selecting null highlights without throwing (ensureVisible)', (
    tester,
  ) async {
    await tester.pumpWidget(host(selected: 'a', onSelected: (_) {}));
    await tester.pumpWidget(host(selected: null, onSelected: (_) {}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a trailing widget', (tester) async {
    await tester.pumpWidget(
      host(
        selected: null,
        onSelected: (_) {},
        trailing: const Icon(LucideIcons.alignLeft),
      ),
    );
    expect(find.byIcon(LucideIcons.alignLeft), findsOneWidget);
  });
}
