import 'package:moodiary_models/moodiary_models.dart';

Comparator<Diary> diarySortComparator(DiarySort sort) => _comparator(
  sort,
  (Diary diary) => diary.id,
  sort == .lastModifiedDesc
      ? (diary) => diary.lastModified
      : (diary) => diary.time,
);

Comparator<DiarySummary> diarySummarySortComparator(DiarySort sort) =>
    _comparator(
      sort,
      (DiarySummary diary) => diary.id,
      sort == .lastModifiedDesc
          ? (diary) => diary.lastModified
          : (diary) => diary.time,
    );

Comparator<T> _comparator<T>(
  DiarySort sort,
  String Function(T) id,
  DateTime Function(T) time,
) {
  int ascending(T first, T second) {
    final order = time(first).compareTo(time(second));
    return order != 0 ? order : id(first).compareTo(id(second));
  }

  return sort == .timeAsc
      ? ascending
      : (first, second) => ascending(second, first);
}
