import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_controller.g.dart';

/// 该月可见日记（show=true 且非软删，可按 [categoryId] 过滤），按时间倒序。
@riverpod
Future<List<Diary>> monthDiaries(
  Ref ref, {
  required DateTime month,
  String? categoryId,
}) async {
  final repository = DiaryRepository.get();
  // 首页常驻（IndexedStack）时编辑器写库不会重建本 provider：订阅事件流自失效。
  final sub = repository.diaryEvents.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final list = await repository.getDiariesByDateRange(start, end, all: true);
  final filtered =
      list
          .where(
            (d) =>
                !d.deleted &&
                d.show &&
                (categoryId == null || d.categoryId == categoryId),
          )
          .toList()
        ..sort((a, b) => b.time.compareTo(a.time));
  return filtered;
}
