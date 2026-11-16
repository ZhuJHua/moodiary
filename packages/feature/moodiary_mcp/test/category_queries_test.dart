import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_mcp/src/tools/category_queries.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'support.dart';

void main() {
  late MoodiaryDatabase db;
  late CategoryRepository categories;
  late DiaryRepository diaries;
  late McpCategoryQueries queries;

  setUp(() {
    db = openTestDatabase();
    categories = CategoryRepository(db);
    diaries = DiaryRepository(db);
    queries = McpCategoryQueries(categories: categories, diaries: diaries);
  });

  tearDown(() => db.close());

  group('list', () {
    test(
      'lists every category with only its own visible diary count',
      () async {
        final work = Category.create(categoryName: 'Work');
        await categories.insertACategory(work);
        final projects = Category.create(
          categoryName: 'Projects',
          parentId: work.id,
        );
        await categories.insertACategory(projects);
        await diaries.insertDiaries([
          makeDiary('d1', 'one', categoryId: work.id),
          makeDiary('d2', 'two', categoryId: projects.id),
          makeDiary('d3', 'three', categoryId: projects.id),
          makeDiary('d4', 'hidden', categoryId: work.id).copyWith(show: false),
        ]);

        final listed = await queries.list();
        final byId = {
          for (final category in listed.categories) category['id']: category,
        };

        expect(listed.total, 2);
        expect(listed.categories, hasLength(2));
        expect(byId[work.id]!['diaries'], 1);
        expect(byId[projects.id]!['diaries'], 2);
        for (final category in listed.categories) {
          expect(
            category.keys,
            unorderedEquals([
              'id',
              'name',
              'color',
              'colorHex',
              'lastModified',
              'diaries',
            ]),
          );
        }
      },
    );

    test('includes empty categories with a zero count', () async {
      await categories.insertACategory(Category.create(categoryName: 'Empty'));

      final listed = await queries.list();

      expect(listed.total, 1);
      expect(listed.categories.single['diaries'], 0);
    });
  });
}
