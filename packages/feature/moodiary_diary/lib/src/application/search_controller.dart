import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_controller.freezed.dart';
part 'search_controller.g.dart';

@freezed
abstract class DiarySearchState with _$DiarySearchState {
  const factory DiarySearchState({
    @Default([]) List<DiarySearchHit> results,
    @Default(0) int totalCount,
    @Default(false) bool isSearching,
    @Default(false) bool isLoadingMore,
    Duration? elapsed,
    @Default('') String query,
    String? categoryId,
    @Default(DateRangePreset.all) DateRangePreset datePreset,
    DateTime? customStart,
    DateTime? customEnd,
    @Default(SearchSort.relevance) SearchSort sort,
  }) = _DiarySearchState;

  const DiarySearchState._();

  bool get hasMore => results.length < totalCount;
}

@riverpod
class DiarySearchController extends _$DiarySearchController {
  static const _pageSize = 30;

  late final _repository = getIt<DiaryRepository>();

  int _seq = 0;

  @override
  DiarySearchState build() {
    unawaited(_repository.warmUpSearch());
    return const DiarySearchState();
  }

  Future<void> search(String text) async {
    state = state.copyWith(query: text.trim());
    await _run();
  }

  Future<void> setCategory(String? categoryId) async {
    state = state.copyWith(categoryId: categoryId);
    await _run();
  }

  Future<void> setDatePreset(DateRangePreset preset) async {
    state = state.copyWith(
      datePreset: preset,
      customStart: null,
      customEnd: null,
    );
    await _run();
  }

  Future<void> setCustomRange(DateTime start, DateTime end) async {
    state = state.copyWith(
      datePreset: .custom,
      customStart: start,
      customEnd: end,
    );
    await _run();
  }

  Future<void> setSort(SearchSort sort) async {
    state = state.copyWith(sort: sort);
    await _run();
  }

  ({DateTime? start, DateTime? end}) _resolveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (state.datePreset) {
      case .all:
        return (start: null, end: null);
      case .last7Days:
        return (start: today.subtract(const Duration(days: 7)), end: null);
      case .last30Days:
        return (start: today.subtract(const Duration(days: 30)), end: null);
      case .thisYear:
        return (start: DateTime(now.year), end: null);
      case .custom:
        final end = state.customEnd;
        return (
          start: state.customStart,
          end: end == null
              ? null
              : DateTime(
                  end.year,
                  end.month,
                  end.day,
                ).add(const Duration(days: 1)),
        );
    }
  }

  Future<void> _run() async {
    final trimmed = state.query;
    if (trimmed.isEmpty) {
      _seq++;
      if (!ref.mounted) return;
      state = state.copyWith(
        results: [],
        totalCount: 0,
        isSearching: false,
        isLoadingMore: false,
        elapsed: null,
      );
      return;
    }
    final seq = ++_seq;
    // 换一次查询就作废在途的 loadMore：它会在 seq 检查处退出，不会自己把标志清掉
    state = state.copyWith(isSearching: true, isLoadingMore: false);
    final stopwatch = Stopwatch()..start();
    final range = _resolveRange();
    final (total, results) = await (
      _repository.countSearchDiaries(
        query: trimmed,
        categoryId: state.categoryId,
        start: range.start,
        end: range.end,
      ),
      _repository.searchDiaries(
        query: trimmed,
        categoryId: state.categoryId,
        start: range.start,
        end: range.end,
        sort: state.sort,
        limit: _pageSize,
      ),
    ).wait;
    stopwatch.stop();
    if (!ref.mounted || seq != _seq) return;
    state = state.copyWith(
      results: results,
      totalCount: total,
      isSearching: false,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<void> loadMore() async {
    if (state.isSearching || state.isLoadingMore || !state.hasMore) return;
    final seq = _seq;
    state = state.copyWith(isLoadingMore: true);
    final range = _resolveRange();
    final next = await _repository.searchDiaries(
      query: state.query,
      categoryId: state.categoryId,
      start: range.start,
      end: range.end,
      sort: state.sort,
      limit: _pageSize,
      offset: state.results.length,
    );
    if (!ref.mounted || seq != _seq) return;
    state = state.copyWith(
      results: [...state.results, ...next],
      isLoadingMore: false,
    );
  }

  void clear() {
    _seq++;
    if (!ref.mounted) return;
    state = const DiarySearchState();
  }

  static const _historyMax = 12;

  void recordHistory() {
    final q = state.query.trim();
    if (q.isEmpty) return;
    final hist = MoodiaryKVs.searchHistory.get() ?? const <String>[];
    final next = [q, ...hist.where((e) => e != q)].take(_historyMax).toList();
    MoodiaryKVs.searchHistory.set(next);
  }

  void removeHistory(String q) {
    final hist = MoodiaryKVs.searchHistory.get() ?? const <String>[];
    MoodiaryKVs.searchHistory.set(hist.where((e) => e != q).toList());
  }

  void clearHistory() => MoodiaryKVs.searchHistory.set(const <String>[]);
}
