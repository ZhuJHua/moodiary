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

  testWidgets('row and round trailing checkbox toggle once per tap', (
    tester,
  ) async {
    final calls = <bool>[];
    await pumpTile(tester, onChanged: calls.add);
    final tile = tester.widget<SettingListTile>(find.byType(SettingListTile));
    expect(tile.leading, isNull);
    expect(tile.trailing, isA<Checkbox>());
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox)).shape,
      isA<CircleBorder>(),
    );

    await tester.tap(find.text('Clean cache'));
    await tester.pump();
    expect(calls, [true]);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    // 和开关行一致：选中状态只由勾选框表达，不给整行着色（着色会盖住分割线）
    final selectedTile = tester.widget<SettingListTile>(
      find.byType(SettingListTile),
    );
    expect(selectedTile.tileColor, isNull);
    expect(selectedTile.selected, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(calls, [true, false]);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets('null onChanged disables both row and checkbox', (tester) async {
    await pumpTile(tester);
    expect(
      tester.widget<SettingListTile>(find.byType(SettingListTile)).onTap,
      isNull,
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    await tester.tap(find.text('Clean cache'));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });
}
