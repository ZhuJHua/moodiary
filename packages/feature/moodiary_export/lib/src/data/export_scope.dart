import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

enum ExportScopeKind { all, category, dateRange, picked }

sealed class ExportScope {
  const ExportScope();

  Future<List<Diary>> resolve();

  ExportScopeKind get kind;

  String? get detail => null;
}

class AllDiariesScope extends ExportScope {
  const AllDiariesScope();

  @override
  Future<List<Diary>> resolve() async =>
      _visibleSorted(await getIt<DiaryRepository>().getAllDiaries());

  @override
  ExportScopeKind get kind => .all;
}

// categoryIds 里的 null 代表「未分类」
class CategoryScope extends ExportScope {
  final Set<String?> categoryIds;

  final String names;

  const CategoryScope(this.categoryIds, this.names);

  @override
  Future<List<Diary>> resolve() async {
    final all = await getIt<DiaryRepository>().getAllDiaries();
    return _visibleSorted(
      all.where((d) => categoryIds.contains(d.categoryId)).toList(),
    );
  }

  @override
  ExportScopeKind get kind => .category;

  @override
  String? get detail => names;
}

class DateRangeScope extends ExportScope {
  final DateTime from;
  final DateTime to;

  const DateRangeScope(this.from, this.to);

  @override
  Future<List<Diary>> resolve() async {
    final all = await getIt<DiaryRepository>().getAllDiaries();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return _visibleSorted(
      all.where((d) {
        final local = d.time.toLocal();
        return !local.isBefore(start) && !local.isAfter(end);
      }).toList(),
    );
  }

  @override
  ExportScopeKind get kind => .dateRange;

  @override
  String? get detail => '${_d(from)} – ${_d(to)}';

  static String _d(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';
}

class PickedScope extends ExportScope {
  final Set<String> diaryIds;

  const PickedScope(this.diaryIds);

  @override
  Future<List<Diary>> resolve() async {
    final repo = getIt<DiaryRepository>();
    final picked = <Diary>[];
    for (final id in diaryIds) {
      final d = await repo.getDiaryByBusinessId(id);
      if (d != null) picked.add(d);
    }
    return _visibleSorted(picked);
  }

  @override
  ExportScopeKind get kind => .picked;
}

List<Diary> _visibleSorted(List<Diary> diaries) {
  final visible = diaries.where((d) => d.show).toList();
  visible.sort((a, b) => a.time.compareTo(b.time));
  return visible;
}
