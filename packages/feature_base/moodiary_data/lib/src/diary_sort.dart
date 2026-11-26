import 'package:moodiary_models/moodiary_models.dart';

Comparator<Diary> diarySortComparator(DiarySort sort) => switch (sort) {
  // 第二排序键必须与 SQL 的 `, id DESC` 逐字段一致（分页 offset 依赖对齐）
  .timeDesc => (a, b) {
    final c = b.time.compareTo(a.time);
    return c != 0 ? c : b.id.compareTo(a.id);
  },
  .timeAsc => (a, b) {
    final c = a.time.compareTo(b.time);
    return c != 0 ? c : a.id.compareTo(b.id);
  },
  .lastModifiedDesc => (a, b) {
    final c = b.lastModified.compareTo(a.lastModified);
    return c != 0 ? c : b.id.compareTo(a.id);
  },
};
