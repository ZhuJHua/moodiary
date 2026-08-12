import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/category/category_manager_page.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

final _mui = MuiThemeData(brightness: Brightness.light);

void main() {
  testWidgets('editor returns entered name and picked color', (t) async {
    CategoryDraft? result;
    await t.pumpWidget(
      MuiTheme(
        data: _mui,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showCategoryEditor(
                      context,
                      initialName: '',
                      initialColor: null,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'travel');
    await t.tap(
      find.byKey(ValueKey('category-swatch-${kCategoryPalette[2].toARGB32()}')),
    );
    await t.tap(find.widgetWithText(FilledButton, '确认'));
    await t.pumpAndSettle();
    expect(result?.name, 'travel');
    expect(result?.color, kCategoryPalette[2].toARGB32());
  });
}
