import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

enum ExportScopeKind { all, category, dateRange, picked }

/// 导出范围。解析出的日记一律按时间正序 —— 合并成一个文件时时间轴才读得通。
///
/// 只给 [kind] 与 [detail]（分类名 / 日期区间这类用户数据），成句的描述在 UI 层按 l10n 拼；
/// 数据层不产出面向用户的字串。
sealed class ExportScope {
  const ExportScope();

  Future<List<Diary>> resolve();

  ExportScopeKind get kind;

  /// 范围里属于用户数据的那部分，没有则为 null。
  String? get detail => null;
}

class AllDiariesScope extends ExportScope {
  const AllDiariesScope();

  @override
  Future<List<Diary>> resolve() async =>
      _visibleSorted(await DiaryRepository.get().getAllDiaries());

  @override
  ExportScopeKind get kind => ExportScopeKind.all;
}

/// 指定分类（可多选）。空分类 id 代表「未分类」。
class CategoryScope extends ExportScope {
  final Set<String?> categoryIds;

  /// 分类名，已由调用方拼好（分类名是用户数据，不进 l10n）。
  final String names;

  const CategoryScope(this.categoryIds, this.names);

  @override
  Future<List<Diary>> resolve() async {
    final all = await DiaryRepository.get().getAllDiaries();
    return _visibleSorted(
      all.where((d) => categoryIds.contains(d.categoryId)).toList(),
    );
  }

  @override
  ExportScopeKind get kind => ExportScopeKind.category;

  @override
  String? get detail => names;
}

/// 时间区间，含起止两端（按本地日期比较）。
class DateRangeScope extends ExportScope {
  final DateTime from;
  final DateTime to;

  const DateRangeScope(this.from, this.to);

  @override
  Future<List<Diary>> resolve() async {
    final all = await DiaryRepository.get().getAllDiaries();
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
  ExportScopeKind get kind => ExportScopeKind.dateRange;

  @override
  String? get detail => '${_d(from)} – ${_d(to)}';

  static String _d(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';
}

/// 手动勾选的若干篇。
class PickedScope extends ExportScope {
  final Set<String> diaryIds;

  const PickedScope(this.diaryIds);

  @override
  Future<List<Diary>> resolve() async {
    final all = await DiaryRepository.get().getAllDiaries();
    return _visibleSorted(all.where((d) => diaryIds.contains(d.id)).toList());
  }

  @override
  ExportScopeKind get kind => ExportScopeKind.picked;
}

/// 回收站里的日记（show=false）永远不导出 —— 用户已经把它们删掉了。
List<Diary> _visibleSorted(List<Diary> diaries) {
  final visible = diaries.where((d) => d.show).toList();
  visible.sort((a, b) => a.time.compareTo(b.time));
  return visible;
}
