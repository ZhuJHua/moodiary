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
  required DiarySort sort,
}) async {
  final repository = getIt<DiaryRepository>();
  Timer? debounce;
  final sub = repository.diaryEvents.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
  return repository.diaryCountByMonth(
    categoryId: categoryId,
    uncategorized: uncategorized,
    sort: sort,
  );
}
