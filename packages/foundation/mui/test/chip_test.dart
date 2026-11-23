import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Future<void> _pump(WidgetTester tester, MChip chip, {double scale = 1}) =>
    tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Center(child: chip),
        ),
      ),
    );

void main() {
  testWidgets('minimum heights are exact and grow with scaled text', (
    tester,
  ) async {
    for (final (size, height) in [
      (MChipSize.small, 32),
      (MChipSize.medium, 36),
    ]) {
      final chip = MChip(label: 'Travel', size: size, onTap: () {});
      await _pump(tester, chip);
      expect(tester.getSize(find.byType(MChip)).height, height);
      await _pump(tester, chip, scale: 2);
      expect(tester.getSize(find.byType(MChip)).height, greaterThan(height));
    }
  });

  testWidgets('tonal, selected, ghost and disabled states use scheme colors', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final chip = find.byType(MChip);
    Color? fill() => tester
        .widget<Material>(
          find.descendant(of: chip, matching: find.byType(Material)),
        )
        .color;
    var taps = 0;
    void tap() => taps++;
    await _pump(tester, MChip(label: 'Travel', onTap: tap));
    final colors = tester.element(chip).theme.colors;
    final width = tester.getSize(chip).width;
    expect(fill(), colors.surfaceContainerHighest);
    await tester.tap(chip);
    expect(taps, 1);
    await _pump(tester, MChip(label: 'Travel', selected: true, onTap: tap));
    expect(fill(), colors.primaryContainer);
    expect(tester.getSize(chip).width, width);
    await _pump(tester, MChip(label: 'Create', variant: .ghost, onTap: tap));
    expect(fill(), Colors.transparent);
    expect(
      find.semantics.byLabel('Create').evaluate().single,
      isSemantics(hasSelectedState: false),
    );
    await _pump(tester, const MChip(label: 'Travel'));
    expect(fill(), colors.onSurface.withValues(alpha: 0.12));
    expect(
      find.semantics.byLabel('Travel').evaluate().single,
      isSemantics(hasEnabledState: true, isEnabled: false, hasTapAction: false),
    );
    await tester.tap(chip);
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('selected chip and remove button have independent actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    var removals = 0;
    await _pump(
      tester,
      MChip(
        label: 'Travel',
        semanticLabel: 'Travel tag',
        selected: true,
        onTap: () => taps++,
        onRemove: () => removals++,
        removeTooltip: 'Remove Travel',
      ),
    );
    expect(
      find.semantics.byLabel('Travel tag').evaluate().single,
      isSemantics(
        isButton: true,
        isSelected: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.semantics.byLabel('Remove Travel').evaluate().single,
      isSemantics(isButton: true, hasTapAction: true),
    );
    // flutter_test 的 byTooltip 只认 flutter 自带的 Tooltip，mui 用的是 material_ui 的。
    await tester.tap(find.byIcon(LucideIcons.x));
    expect((taps, removals), (0, 1));
    tester.semantics.tap(find.semantics.byLabel('Travel tag'));
    expect((taps, removals), (1, 1));
    semantics.dispose();
  });
}
