import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'support.dart';

void main() {
  late MoodiaryDatabase db;
  late CategoryRepository categories;
  late DiaryRepository diaries;
  late CategoryOps ops;

  setUp(() {
    db = openTestDatabase();
    categories = CategoryRepository(db);
    diaries = DiaryRepository(db);
    ops = CategoryOps(categories: categories, diaries: diaries);
  });

  tearDown(() => db.close());

  Future<Category> newCategory(String name, {String? parentId}) async =>
      ops.create(name: name, parentId: parentId);

  group('delete', () {
    test('keeps the children untouched unless asked to reparent', () async {
      final parent = await newCategory('Parent');
      final child = await newCategory('Child', parentId: parent.id);

      final result = await ops.delete(parent.id);

      expect(result.deleted, isTrue);
      expect(result.category.id, parent.id);
      expect(result.reparented, isEmpty);
      final stored = (await categories.getCategoryById(child.id))!;
      expect(stored.parentId, parent.id);
      expect(stored.lastModified.isAtSameMomentAs(child.lastModified), isTrue);
    });

    test('reparents children to the root and reports them', () async {
      final parent = await newCategory('Parent');
      final first = await newCategory('First', parentId: parent.id);
      final second = await newCategory('Second', parentId: parent.id);
      final grandchild = await newCategory('Grandchild', parentId: first.id);

      final result = await ops.delete(parent.id, reparentChildren: true);

      expect(result.deleted, isTrue);
      expect(result.category.id, parent.id);
      expect(result.reparented.map((category) => category.id).toSet(), {
        first.id,
        second.id,
      });
      final all = {
        for (final category in await categories.getAllCategories())
          category.id: category,
      };
      expect(all.containsKey(parent.id), isFalse);
      expect(all[first.id]!.parentId, isNull);
      expect(all[second.id]!.parentId, isNull);
      // A grandchild keeps the parent that was not deleted.
      expect(all[grandchild.id]!.parentId, first.id);
    });

    test('bumps lastModified of every reparented child', () async {
      final parent = await newCategory('Parent');
      final child = await newCategory('Child', parentId: parent.id);

      final result = await ops.delete(parent.id, reparentChildren: true);

      final stored = await categories.getCategoryById(child.id);
      expect(stored!.parentId, isNull);
      expect(stored.lastModified.isAfter(child.lastModified), isTrue);
      expect(
        result.reparented.single.lastModified.isAtSameMomentAs(
          stored.lastModified,
        ),
        isTrue,
        reason: 'the report must carry the persisted row, not a copy',
      );
    });

    test('a category holding diaries is refused, nothing changes', () async {
      final parent = await newCategory('Parent');
      final child = await newCategory('Child', parentId: parent.id);
      await diaries.insertADiary(
        makeDiary('d1', 'body', categoryId: parent.id),
      );

      final result = await ops.delete(parent.id);

      expect(result.deleted, isFalse);
      expect(result.reparented, isEmpty);
      expect(await categories.getCategoryById(parent.id), isNotNull);
      expect((await categories.getCategoryById(child.id))!.parentId, parent.id);
    });

    test('an unknown id is notFound', () async {
      await expectLater(
        ops.delete('missing'),
        throwsA(
          isA<DiaryOpsException>().having(
            (error) => error.failure,
            'failure',
            DiaryOpsFailure.notFound,
          ),
        ),
      );
    });
  });

  group('update', () {
    test(
      'serializes concurrent reparents so they cannot close a cycle',
      () async {
        final first = await newCategory('First');
        final second = await newCategory('Second');

        final results = await Future.wait([
          ops
              .update(id: first.id, parentId: second.id, parentSet: true)
              .then<Object>(
                (category) => category,
                onError: (Object error) => error,
              ),
          ops
              .update(id: second.id, parentId: first.id, parentSet: true)
              .then<Object>(
                (category) => category,
                onError: (Object error) => error,
              ),
        ]);

        final updated = results.whereType<Category>();
        final refused = results.whereType<DiaryOpsException>();
        expect(updated, hasLength(1));
        expect(refused, hasLength(1));
        expect(refused.single.failure, DiaryOpsFailure.categoryCycle);
        final roots = (await categories.getAllCategories())
            .where((category) => category.parentId == null);
        expect(
          roots,
          hasLength(1),
          reason: 'the accepted reparent still leaves exactly one root',
        );
      },
    );
  });

  group('tree', () {
    test(
      'keeps direct diaries and rolls descendants into diariesTotal',
      () async {
        final root = await newCategory('Root');
        final child = await newCategory('Child', parentId: root.id);
        final leaf = await newCategory('Leaf', parentId: child.id);
        await diaries.insertDiaries([
          makeDiary('d1', 'one', categoryId: child.id),
          makeDiary('d2', 'two', categoryId: leaf.id),
        ]);

        final tree = await ops.tree();

        expect(tree.total, 3, reason: 'total counts categories, not diaries');
        final rootNode = tree.categories.single;
        expect(rootNode['diaries'], 0);
        expect(rootNode['diariesTotal'], 2);
        final childNode = (rootNode['children'] as List).single;
        expect(childNode['diaries'], 1);
        expect(childNode['diariesTotal'], 2);
        final leafNode = (childNode['children'] as List).single;
        expect(leafNode['diaries'], 1);
        expect(leafNode['diariesTotal'], 1);
      },
    );

    test('categoryInfo without a rollup reports the direct count', () {
      final category = Category.create(categoryName: 'Flat');
      final info = categoryInfo(category, diaryCount: 4);
      expect(info['diaries'], 4);
      expect(info['diariesTotal'], 4);
    });
  });
}
