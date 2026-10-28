import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  var selected = false;
  setUp(() => selected = false);

  Future<void> pumpTile(WidgetTester tester, {ValueChanged<bool>? onChanged}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SettingCheckboxListTile(
                title: 'Clean cache',
                subtitle: 'Temporary files',
                value: selected,
                onChanged: onChanged == null
                    ? null
                    : (value) => setState(() {
                        selected = value;
                        onChanged(value);
                      }),
              ),
            ),
          ),
        ),
      );

  MSelectMark mark(WidgetTester tester) =>
      tester.widget<MSelectMark>(find.byType(MSelectMark));

  testWidgets('row and round select mark toggle once per tap', (tester) async {
    final calls = <bool>[];
    await pumpTile(tester, onChanged: calls.add);
    final tile = tester.widget<SettingListTile>(find.byType(SettingListTile));
    expect(tile.leading, isNull);
    expect(find.byType(Checkbox), findsNothing);
    expect(mark(tester).selected, isFalse);

    await tester.tap(find.text('Clean cache'));
    await tester.pump();
    expect(calls, [true]);
    expect(mark(tester).selected, isTrue);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    // 和开关行一致：选中状态只由勾选标记表达，不给整行着色（着色会盖住分割线）
    expect(
      tester.widget<SettingListTile>(find.byType(SettingListTile)).tileColor,
      isNull,
    );

    await tester.tap(find.byType(MSelectMark));
    await tester.pump();
    expect(calls, [true, false]);
    expect(mark(tester).selected, isFalse);
  });

  testWidgets('null onChanged disables the row and dims the mark', (
    tester,
  ) async {
    await pumpTile(tester);
    expect(
      tester.widget<SettingListTile>(find.byType(SettingListTile)).onTap,
      isNull,
    );
    expect(mark(tester).enabled, isFalse);
    await tester.tap(find.text('Clean cache'));
    await tester.pump();
    expect(mark(tester).selected, isFalse);
  });
  testWidgets('merged checkbox semantics include text, checked state and tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpTile(tester, onChanged: (_) {});
      expect(
        tester.getSemantics(find.byType(SettingCheckboxListTile)),
        matchesSemantics(
          label: 'Clean cache\nTemporary files',
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('Clean cache'));
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(SettingCheckboxListTile)),
        matchesSemantics(
          label: 'Clean cache\nTemporary files',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await pumpTile(tester);
      expect(
        tester.getSemantics(find.byType(SettingCheckboxListTile)),
        matchesSemantics(
          label: 'Clean cache\nTemporary files',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
