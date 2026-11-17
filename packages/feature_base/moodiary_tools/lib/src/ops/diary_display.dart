import 'package:moodiary_data/moodiary_data.dart';

const int excerptChars = 200;

Future<Map<String, String>> categoryNames(CategoryRepository categories) async {
  final all = await categories.getAllCategories();
  return {for (final category in all) category.id: category.categoryName};
}
