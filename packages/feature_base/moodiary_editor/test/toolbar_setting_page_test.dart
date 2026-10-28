// ignore_for_file: deprecated_member_use

import 'dart:ui' show CheckedState;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/src/presentation/toolbar_setting_page.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

void main() {
  setUp(() => getIt.registerSingleton<IKVStorage>(MemoryKVStorage()));
  tearDown(getIt.reset);

  testWidgets('tool row exposes checked semantics only in removal mode', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: buildMuiTheme(brightness: .light),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            builder: (context, child) =>
                MaterialUiCompatibilityBridge(child: child!),
            home: const ToolbarSettingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byType(SettingListTile).first;
      final label = tester.widget<SettingListTile>(row).title as String;
      expect(
        tester.getSemantics(row).getSemanticsData().flagsCollection.isChecked,
        CheckedState.none,
      );
      await tester.tap(find.byTooltip(l10n.editor.toolbar.removeTools));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          label: label,
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          label: label,
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(row).getSemanticsData().flagsCollection.isChecked,
        CheckedState.none,
      );
    } finally {
      semantics.dispose();
    }
  });
}
