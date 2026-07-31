import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'timeline_controller.g.dart';

/// 月份 -> 该月可见日记篇数（月首零点为键，本地时区）。
///
/// 走独立的聚合查询而不是数首页那条分页列表：列表一次只加载 30 条，从中数出来的是
/// 「加载到哪儿了」，不是这个月写了多少篇。[sort] 决定分桶字段，必须与时间线的分组键
/// 保持一致，否则表头数字会和它下面的条目对不上。
@riverpod
Future<Map<DateTime, int>> timelineMonthCounts(
  Ref ref, {
  String? categoryId,
  bool uncategorized = false,
  required DiarySort sort,
}) async {
  final repository = DiaryRepository.get();
  final sub = repository.diaryEvents.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repository.diaryCountByMonth(
    categoryId: categoryId,
    uncategorized: uncategorized,
    sort: sort,
  );
}
