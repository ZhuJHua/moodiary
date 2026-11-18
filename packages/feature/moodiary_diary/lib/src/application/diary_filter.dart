import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiaryFilter {
  final String? categoryId;

  final bool uncategorized;
  final String? tagName;

  const DiaryFilter._(this.categoryId, this.uncategorized, this.tagName);

  const DiaryFilter.all() : this._(null, false, null);

  const DiaryFilter.category(String id) : this._(id, false, null);

  const DiaryFilter.uncategorized() : this._(null, true, null);

  const DiaryFilter.tag(String name) : this._(null, false, name);

  bool get isAll => categoryId == null && !uncategorized && tagName == null;

  @override
  bool operator ==(Object other) =>
      other is DiaryFilter &&
      other.categoryId == categoryId &&
      other.uncategorized == uncategorized &&
      other.tagName == tagName;

  @override
  int get hashCode => Object.hash(categoryId, uncategorized, tagName);

  @override
  String toString() => isAll
      ? 'DiaryFilter.all()'
      : uncategorized
      ? 'DiaryFilter.uncategorized()'
      : tagName != null
      ? 'DiaryFilter.tag($tagName)'
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
