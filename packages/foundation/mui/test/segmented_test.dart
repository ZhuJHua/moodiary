import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

enum _Range { week, month, year }

Future<void> _pump(
  WidgetTester tester, {
  required _Range selected,
  ValueChanged<_Range>? onChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildMuiTheme(brightness: .light),
      home: Scaffold(
        body: MSegmentedControl<_Range>(
          selected: selected,
          onChanged: onChanged,
          options: const [
            MSegmentOption(value: .week, label: '周'),
            MSegmentOption(value: .month, label: '月'),
            MSegmentOption(value: .year, label: '年'),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('点按未选中的分段回调它的值', (tester) async {
    _Range? picked;
    await _pump(tester, selected: .month, onChanged: (v) => picked = v);

    await tester.tap(find.text('年'));
    expect(picked, _Range.year);
  });

  testWidgets('选中态写进语义，onChanged 为 null 时整组禁用', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: .month);

    expect(
      tester.getSemantics(find.bySemanticsLabel('月')),
      matchesSemantics(
        label: '月',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('周')),
      matchesSemantics(
        label: '周',
        isButton: true,
        hasSelectedState: true,
        hasEnabledState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('选中块用 secondaryContainer，文字跟随前景色', (tester) async {
    await _pump(tester, selected: .week, onChanged: (_) {});
    final context = tester.element(find.text('周'));
    final colors = context.theme.colors;

    final selectedBox = tester.widget<Container>(
      find.ancestor(of: find.text('周'), matching: find.byType(Container)).first,
    );
    expect(
      (selectedBox.decoration! as BoxDecoration).color,
      colors.secondaryContainer,
    );
    expect(
      tester.widget<Text>(find.text('周')).style!.color,
      colors.onSecondaryContainer,
    );
    expect(tester.widget<Text>(find.text('年')).style!.color, colors.onSurface);
  });
}
