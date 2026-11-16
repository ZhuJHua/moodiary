import 'package:moodiary_data/moodiary_data.dart';

/// Length of a diary preview.
const int excerptChars = 200;

/// Category id to display name, for the summaries that carry a category.
Future<Map<String, String>> categoryNames(CategoryRepository categories) async {
  final all = await categories.getAllCategories();
  return {for (final category in all) category.id: category.categoryName};
}
