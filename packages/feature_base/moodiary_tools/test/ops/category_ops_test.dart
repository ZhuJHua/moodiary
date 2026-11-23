import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

void main() {
  late MoodiaryDatabase db;
  late CategoryRepository categories;
  late DiaryRepository diaries;
  late CategoryOps ops;

  setUp(() {
    db = openTestDatabase();
    categories = CategoryRepository(db);
    diaries = DiaryRepository(db);
    ops = CategoryOps(categories: categories);
  });

  tearDown(() => db.close());

  Matcher failsWith(DiaryOpsFailure failure) => throwsA(
    isA<DiaryOpsException>().having(
      (error) => error.failure,
      'failure',
      failure,
    ),
  );

  group('create', () {
    test('stores a trimmed name and colour without a parent', () async {
      final category = await ops.create(name: ' Work ', color: 0xFF112233);

      expect(category.categoryName, 'Work');
      expect(category.color, 0xFF112233);
      expect(category.parentId, isNull);
      expect(await categories.getCategoryById(category.id), category);
    });

    test('rejects an empty name', () async {
      await expectLater(
        ops.create(name: ' '),
        failsWith(DiaryOpsFailure.fieldRequired),
      );
      expect(await categories.getAllCategories(), isEmpty);
    });
  });

  group('update', () {
    test('renames and recolours while preserving the stored parent', () async {
      final category = Category(
        id: 'existing',
        categoryName: 'Work',
        parentId: 'legacy-parent',
        color: 0xFF112233,
        lastModified: DateTime.utc(2026, 1, 1),
      );
      await categories.insertACategory(category);

      final updated = await ops.update(
        id: category.id,
        name: ' Projects ',
        color: 0xFF445566,
        colorSet: true,
      );

      expect(updated.categoryName, 'Projects');
      expect(updated.color, 0xFF445566);
      expect(updated.parentId, category.parentId);
      expect(updated.lastModified.isAfter(category.lastModified), isTrue);
      expect(await categories.getCategoryById(category.id), updated);
    });

    test('keeps omitted colour and clears explicit null', () async {
      final category = await ops.create(name: 'Work', color: 0xFF112233);
      final renamed = await ops.update(id: category.id, name: 'Projects');
      expect(renamed.color, category.color);

      final cleared = await ops.update(id: category.id, colorSet: true);
      expect(cleared.color, isNull);
      expect(cleared.categoryName, 'Projects');
      expect(await categories.getCategoryById(category.id), cleared);
    });

    test('requires a change', () async {
      final category = await ops.create(name: 'Work');
      await expectLater(
        ops.update(id: category.id),
        failsWith(DiaryOpsFailure.noChanges),
      );
      expect(await categories.getCategoryById(category.id), category);
    });

    test('an unknown id is notFound', () async {
      await expectLater(
        ops.update(id: 'missing', name: 'Work'),
        failsWith(DiaryOpsFailure.notFound),
      );
    });
  });

  group('delete', () {
    test('deletes an empty category and leaves other rows untouched', () async {
      final category = await ops.create(name: 'Work');
      final child = Category(
        id: 'legacy-child',
        categoryName: 'Projects',
        parentId: category.id,
        lastModified: DateTime.utc(2026, 1, 1),
      );
      await categories.insertACategory(child);
      final events = <CategoryEvent>[];
      final subscription = categories.categoryEvents.listen(events.add);
      addTearDown(subscription.cancel);

      final result = await ops.delete(category.id);
      await Future<void>.delayed(Duration.zero);

      expect(result.deleted, isTrue);
      expect(result.category, category);
      expect((await categories.getCategoryById(category.id))?.deleted, isTrue);
      expect(await categories.getCategoryById(child.id), child);
      expect(await db.select(db.tombstones).get(), isEmpty);
      expect(events, [
        isA<CategoryUpserted>().having(
          (event) => event.category.deleted,
          'deleted',
          true,
        ),
      ]);
    });

    for (final visible in [true, false]) {
      test('deletes a category holding a diary with show=$visible', () async {
        final category = await ops.create(name: 'Work');
        await diaries.insertADiary(
          makeDiary(
            'd1',
            'body',
            categoryId: category.id,
          ).copyWith(show: visible),
        );

        final result = await ops.delete(category.id);

        expect(result.deleted, isTrue);
        expect(
          (await categories.getCategoryById(category.id))?.deleted,
          isTrue,
        );
        expect(
          (await diaries.getDiaryByBusinessId("d1"))?.categoryId,
          category.id,
        );
        expect(await db.select(db.tombstones).get(), isEmpty);
      });
    }

    test('an unknown id is notFound', () async {
      await expectLater(
        ops.delete('missing'),
        failsWith(DiaryOpsFailure.notFound),
      );
    });
  });
}
