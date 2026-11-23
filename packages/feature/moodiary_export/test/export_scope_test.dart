import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_export/src/data/export_scope.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  test(
    'uncategorized includes every visible diary without an active category',
    () async {
      final db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final categories = CategoryRepository(db);
      final diaries = DiaryRepository(db);
      getIt.registerSingleton<CategoryRepository>(categories);
      getIt.registerSingleton<DiaryRepository>(diaries);
      addTearDown(getIt.reset);
      for (final id in ['active', 'deleted']) {
        await categories.insertACategory(
          Category.create(categoryName: id)
              .copyWith(id: id, deleted: id == 'deleted'),
        );
      }
      for (final id in [null, '', 'active', 'deleted', 'missing']) {
        await diaries.insertADiary(
          Diary.empty(type: .tiptap).copyWith(id: 'diary-$id', categoryId: id),
        );
      }
      final uncategorized = await const CategoryScope({null}, '').resolve();
      expect(
        uncategorized.map((d) => d.id),
        unorderedEquals([
          'diary-null',
          'diary-',
          'diary-deleted',
          'diary-missing',
        ]),
      );
      final selected = await const CategoryScope({
        'active',
        'deleted',
      }, '').resolve();
      expect(selected.map((d) => d.id), ['diary-active']);
    },
  );
}
