import 'package:moodiary_data/moodiary_data.dart';

import 'diary_payloads.dart';

class CategoryToolQueries {
  CategoryToolQueries({required this.categories, required this.diaries});

  final CategoryRepository categories;
  final DiaryRepository diaries;

  Future<({List<Map<String, dynamic>> categories, int total})> list() async {
    final all = await categories.getAllCategories();
    final counts = (await diaries.diaryCountByCategory()).byCategory;
    return (
      categories: [
        for (final category in all)
          categoryInfo(category, diaryCount: counts[category.id] ?? 0),
      ],
      total: all.length,
    );
  }
}
