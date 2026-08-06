import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页的分类筛选维度。
///
/// 不能只用 `String? categoryId`：`null` 已经表示「全部」，而「没有分类的日记」需要
/// 第三种取值。这里用一个显式的小值类型，而不是塞哨兵字符串 —— 哨兵一旦漏进
/// `Diary.categoryId` 就是脏数据。
class DiaryFilter {
  /// 选中的分类 id；[isAll] 与 [uncategorized] 时为 null。
  final String? categoryId;

  /// 只看「没有分类」的日记。
  final bool uncategorized;

  const DiaryFilter._(this.categoryId, this.uncategorized);

  const DiaryFilter.all() : this._(null, false);

  const DiaryFilter.category(String id) : this._(id, false);

  const DiaryFilter.uncategorized() : this._(null, true);

  bool get isAll => categoryId == null && !uncategorized;

  @override
  bool operator ==(Object other) =>
      other is DiaryFilter &&
      other.categoryId == categoryId &&
      other.uncategorized == uncategorized;

  @override
  int get hashCode => Object.hash(categoryId, uncategorized);

  @override
  String toString() => isAll
      ? 'DiaryFilter.all()'
      : uncategorized
      ? 'DiaryFilter.uncategorized()'
      : 'DiaryFilter.category($categoryId)';
}

/// 首页当前的分类筛选。抽屉挂在根壳的 Scaffold 上、首页在 IndexedStack 里，两者不在
/// 同一棵 State 树里，所以这个状态必须提到 provider 上，不能留在首页的 State 字段里。
class DiaryFilterNotifier extends Notifier<DiaryFilter> {
  @override
  DiaryFilter build() => const DiaryFilter.all();

  void select(DiaryFilter filter) => state = filter;

  void reset() => state = const DiaryFilter.all();
}

final homeDiaryFilterProvider =
    NotifierProvider<DiaryFilterNotifier, DiaryFilter>(DiaryFilterNotifier.new);
