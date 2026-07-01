import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_controller.g.dart';

/// 该月可见日记（show=true 且非软删），按时间倒序。
@riverpod
Future<List<Diary>> monthDiaries(Ref ref, {required DateTime month}) async {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final list = await DiaryRepository.get().getDiariesByDateRange(
    start,
    end,
    all: true,
  );
  final filtered = list.where((d) => !d.deleted && d.show).toList()
    ..sort((a, b) => b.time.compareTo(a.time));
  return filtered;
}
