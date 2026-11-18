import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

class _Categories extends Fake implements CategoryRepository {
  final saved = <Category>[];
  @override
  Stream<CategoryEvent> get categoryEvents => const Stream.empty();
  @override
  Future<List<Category>> getAllCategories() async => [...saved];
  @override
  Future<void> insertACategory(
    Category category, {
    bool fromSync = false,
  }) async => saved.add(category);
}

void main() {
  test('tag diff keeps unresolved IDs and removes every deselected alias', () {
    final old = Tag.legacy('old');
    final twin = old.copyWith(id: 'twin');
    final kept = Tag.legacy('kept');
    final deleted = old.copyWith(id: 'deleted', deleted: true);
    final byId = {
      for (final tag in [old, kept, twin, deleted]) tag.id: tag,
    };
    final ids = [old.id, 'unknown', kept.id, twin.id, deleted.id];
    final diff = tagSelectionDiff(ids, byId, (
      selected: ['added', 'kept'],
      created: ['new', 'added'],
    ));
    expect(diff.retained, ['unknown', kept.id, deleted.id]);
    expect(diff.addedNames, ['added', 'new']);
    expect(
      applyTagSelection(ids, diff.retained, [
        'added-id',
        kept.id,
        'new-id',
        'added-id',
      ]),
      ['unknown', kept.id, deleted.id, 'added-id', 'new-id'],
    );
    final unchanged = tagSelectionDiff(ids, byId, (
      selected: ['kept', 'old'],
      created: [],
    ));
    expect(applyTagSelection(ids, unchanged.retained, []), isNull);
  });

  testWidgets(
    'creating a category returns the category saved by the controller',
    (tester) async {
      final repository = _Categories();
      getIt.registerSingleton<CategoryRepository>(repository);
      addTearDown(getIt.reset);
      (bool, Category?)? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderedCategoriesProvider.overrideWithValue(const AsyncData([])),
            categoryDiaryCountsProvider.overrideWith(
              (ref) async => (byCategory: <String, int>{}, total: 0),
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildMuiTheme(brightness: .light),
              localizationsDelegates: const [
                ...GlobalMaterialLocalizations.delegates,
                GlobalMuiLocalizations.delegate,
              ],
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await CategoryPickerSheet.show(
                        context: context,
                        currentCategoryId: null,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), ' Travel ');
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.editor.createCategory(name: 'Travel')));
      await tester.pumpAndSettle();
      expect(repository.saved.single.categoryName, 'Travel');
      expect(result, (true, repository.saved.single));
    },
  );
}
