import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_controller.freezed.dart';
part 'search_controller.g.dart';

@freezed
abstract class DiarySearchState with _$DiarySearchState {
  const factory DiarySearchState({
    @Default([]) List<Diary> results,
    @Default([]) List<String> queryList,
    @Default(false) bool isSearching,
    Duration? elapsed,
    @Default('') String query,
    String? categoryId,
    @Default(DateRangePreset.all) DateRangePreset datePreset,
    DateTime? customStart,
    DateTime? customEnd,
    @Default(SearchSort.relevance) SearchSort sort,
  }) = _DiarySearchState;

  const DiarySearchState._();

  int get totalCount => results.length;
}

@riverpod
class DiarySearchController extends _$DiarySearchController {
  DiaryRepository get _repository => .get();

  int _seq = 0;
  bool _disposed = false;

  @override
  DiarySearchState build() {
    ref.onDispose(() => _disposed = true);
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

  /// 把时间范围预设解析成具体起止；end 为开区间上界（不含）。
  ({DateTime? start, DateTime? end}) _resolveRange() {
    final now = DateTime.now();
    // 统一按「天」对齐（零点），与 thisYear / custom 一致，避免随搜索时刻漂移而漏掉边界当天。
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
          // 含自定义结束日当天 → 上界取次日零点。
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
      if (_disposed) return;
      state = state.copyWith(
        results: [],
        queryList: [],
        isSearching: false,
        elapsed: null,
      );
      return;
    }
    final seq = ++_seq;
    state = state.copyWith(isSearching: true);
    final stopwatch = Stopwatch()..start();
    final tokenizeResult = await Tokenizer.tokenize(text: trimmed);
    final range = _resolveRange();
    final results = await _repository.searchDiaries(
      cutTokens: tokenizeResult.cut,
      cutForSearchTokens: tokenizeResult.cutForSearch,
      categoryId: state.categoryId,
      start: range.start,
      end: range.end,
      sort: state.sort,
    );
    stopwatch.stop();
    if (_disposed || seq != _seq) return;
    final queryList = {
      ...tokenizeResult.cut,
      ...tokenizeResult.cutForSearch,
    }.toList();
    state = state.copyWith(
      results: results,
      queryList: queryList,
      isSearching: false,
      elapsed: stopwatch.elapsed,
    );
  }

  void clear() {
    _seq++;
    if (_disposed) return;
    state = const DiarySearchState();
  }

  static const _historyMax = 12;

  /// 把当前查询记入搜索历史（最近在前、去重、截断到上限）。
  Future<void> recordHistory() async {
    final q = state.query.trim();
    if (q.isEmpty) return;
    final hist = MoodiaryKVs.searchHistory.get() ?? const <String>[];
    final next = [q, ...hist.where((e) => e != q)].take(_historyMax).toList();
    await MoodiaryKVs.searchHistory.set(next);
  }

  Future<void> removeHistory(String q) async {
    final hist = MoodiaryKVs.searchHistory.get() ?? const <String>[];
    await MoodiaryKVs.searchHistory.set(hist.where((e) => e != q).toList());
  }

  Future<void> clearHistory() async {
    await MoodiaryKVs.searchHistory.set(const <String>[]);
  }
}
