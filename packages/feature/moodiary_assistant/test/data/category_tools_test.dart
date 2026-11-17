import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late CategoryRepository categories;
  late DiaryRepository diaries;

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    categories = CategoryRepository(db);
    diaries = DiaryRepository(db);
    getIt.registerSingleton<CategoryRepository>(categories);
    getIt.registerSingleton<DiaryRepository>(diaries);
    getIt.registerSingleton<MoodInsightsRepository>(MoodInsightsRepository(db));
  });

  tearDown(() async {
    await getIt.reset();
    await db.close();
  });

  Future<String> run(AssistantTool tool, Map<String, dynamic> input) =>
      AssistantToolRegistry.byId(tool.id)!.run(input);

  test('category schemas expose names and ids', () {
    for (final tool in [
      AssistantTool.createCategory,
      AssistantTool.updateCategory,
    ]) {
      final schema = AssistantToolRegistry.byId(tool.id)!.jsonSchema;
      final properties = schema['properties'] as Map;
      final items = (properties['items'] as Map)['items'] as Map;
      expect(
        (items['properties'] as Map).keys,
        tool == AssistantTool.createCategory
            ? ['name', 'color']
            : ['id', 'name', 'color'],
      );
    }
  });

  test('creates, renames and deletes a category', () async {
    final created = await run(.createCategory, {
      'items': [
        {'name': ' Work '},
      ],
    });
    final category = (await categories.getAllCategories()).single;
    expect(created, contains('Work'));
    expect(category.parentId, isNull);

    final renamed = await run(.updateCategory, {
      'items': [
        {'id': category.id, 'name': 'Projects'},
      ],
    });
    expect(renamed, contains('Projects'));
    expect(
      (await categories.getCategoryById(category.id))!.categoryName,
      'Projects',
    );

    final deleted = await run(.deleteCategory, {
      'ids': [category.id],
    });
    expect(deleted, contains('"ok":true'));
    expect(await categories.getCategoryById(category.id), isNull);
  });

  test('renaming and deleting preserve existing child links', () async {
    final category = Category.create(categoryName: 'Work');
    final child = Category.create(
      categoryName: 'Projects',
      parentId: category.id,
    );
    await categories.insertACategory(category);
    await categories.insertACategory(child);

    await run(.updateCategory, {
      'items': [
        {'id': child.id, 'name': 'Renamed'},
      ],
    });
    final renamed = (await categories.getCategoryById(child.id))!;
    expect(renamed.parentId, category.id);

    final deleted = await run(.deleteCategory, {
      'ids': [category.id],
    });
    expect(deleted, contains('"ok":true'));
    expect(await categories.getCategoryById(category.id), isNull);
    expect(await categories.getCategoryById(child.id), renamed);
  });

  test('refuses deletion while a recycled diary uses the category', () async {
    final category = Category.create(categoryName: 'Work');
    await categories.insertACategory(category);
    await diaries.insertADiary(
      Diary.empty(type: .tiptap).copyWith(categoryId: category.id, show: false),
    );

    final result = await run(.deleteCategory, {
      'ids': [category.id],
    });

    expect(result, contains('still holds diaries'));
    expect(await categories.getCategoryById(category.id), category);
  });
}
