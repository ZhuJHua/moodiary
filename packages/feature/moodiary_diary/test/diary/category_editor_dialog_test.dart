import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/presentation/category/category_manager_page.dart';
import 'package:mui/mui.dart';

import '../support/pump.dart';

void main() {
  testWidgets('editor returns entered name and picked color', (t) async {
    CategoryDraft? result;
    await t.pumpWidget(
      muiTestApp(
        wrapScaffold: false,
        Builder(
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
