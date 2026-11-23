import 'dart:async';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'timeline_controller.g.dart';

@riverpod
Future<Map<DateTime, int>> timelineMonthCounts(
  Ref ref, {
  String? categoryId,
  bool uncategorized = false,
  String? tagName,
  required DiarySort sort,
}) async {
  final repository = getIt<DiaryRepository>();
  Timer? debounce;
  void invalidate(Object _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), ref.invalidateSelf);
  }

  final sub = repository.diaryEvents.listen(invalidate);
  final tags = tagName == null
      ? null
      : getIt<TagRepository>().tagEvents.listen(invalidate);
  final categories = uncategorized
      ? getIt<CategoryRepository>().categoryEvents.listen(invalidate)
      : null;
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
    categories?.cancel();
    tags?.cancel();
  });
  return repository.diaryCountByMonth(
    categoryId: categoryId,
    uncategorized: uncategorized,
    tagName: tagName,
    sort: sort,
  );
}
