import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

void main() {
  Widget host({
    required ValueChanged<String> onSelected,
    String? selected,
    List<MoodiaryMenuEntry<String>>? entries,
  }) {
    return MuiTheme(
      data: _mui,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: MoodiaryMenuButton<String>(
              tooltip: 'more',
              selected: selected,
              onSelected: onSelected,
              entries:
                  entries ??
                  const [
                    MoodiaryMenuEntry(value: 'a', label: 'Apple'),
                    MoodiaryMenuEntry(value: 'b', label: 'Banana'),
                    MoodiaryMenuEntry(
                      value: 'c',
                      label: 'Cherry',
                      icon: LucideIcons.trash2,
                      isDestructive: true,
                    ),
                  ],
              child: const Padding(
                padding: .all(12),
                child: Icon(LucideIcons.ellipsisVertical),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens on tap and shows all entries', (tester) async {
    await tester.pumpWidget(host(onSelected: (_) {}));
    expect(find.text('Apple'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Cherry'), findsOneWidget);
  });

  testWidgets('selecting an entry fires onSelected and closes', (tester) async {
    String? picked;
    await tester.pumpWidget(host(onSelected: (v) => picked = v));

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();

    expect(picked, 'b');
    expect(find.text('Banana'), findsNothing);
  });

  testWidgets('barrier dismiss does not fire onSelected', (tester) async {
    var fired = false;
    await tester.pumpWidget(host(onSelected: (_) => fired = true));

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    // Tap outside the menu to dismiss.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(fired, isFalse);
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('selected entry shows a check mark', (tester) async {
    await tester.pumpWidget(host(onSelected: (_) {}, selected: 'b'));

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });

  testWidgets('disabled entry does not fire onSelected', (tester) async {
    String? picked;
    await tester.pumpWidget(
      host(
        onSelected: (v) => picked = v,
        entries: const [
          MoodiaryMenuEntry(value: 'a', label: 'Apple'),
          MoodiaryMenuEntry(value: 'b', label: 'Banana', enabled: false),
        ],
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();

    expect(picked, isNull);
    // Menu stays open since the disabled item ignores taps.
    expect(find.text('Apple'), findsOneWidget);
  });
}
