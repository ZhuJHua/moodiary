import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiaryFilter {
  final String? categoryId;

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

class DiaryFilterNotifier extends Notifier<DiaryFilter> {
  @override
  DiaryFilter build() => const .all();

  void select(DiaryFilter filter) => state = filter;

  void reset() => state = const .all();
}

final homeDiaryFilterProvider =
    NotifierProvider<DiaryFilterNotifier, DiaryFilter>(DiaryFilterNotifier.new);
