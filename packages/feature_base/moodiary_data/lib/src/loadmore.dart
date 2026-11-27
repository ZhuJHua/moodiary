import 'package:meta/meta.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

@immutable
class PagedList<T> {
  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  PagedList({
    required List<T> items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  }) : items = List.unmodifiable(items);

  PagedList<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) => PagedList(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
  );
}

mixin LoadMoreMixin<ItemT, StateT extends PagedList<ItemT>>
    on AnyNotifier<AsyncValue<StateT>, StateT> {
  int _epoch = 0;
  Object? _append;
  int _revision = 0;
  bool _missedEvent = false;
  bool _readingFirstPage = false;

  @protected
  Future<StateT> get future;

  bool get isRefreshing => _readingFirstPage || state.isRefreshing;
  bool get noMore => !state.isLoading && state.value?.hasMore == false;

  void markMissedEvent() {
    if (_readingFirstPage) {
      _missedEvent = true;
    } else {
      ref.invalidateSelf();
    }
  }

  void markPrefixMutated() {
    if (_append != null) _revision++;
  }

  Future<StateT> init() => _readFirstPage();

  Future<StateT> _readFirstPage({bool refresh = false}) async {
    final operationRef = ref;
    final epoch = ++_epoch;
    _append = null;
    _readingFirstPage = true;
    bool active() => operationRef.mounted && epoch == _epoch;
    try {
      final previous = refresh ? state.value : null;
      if (previous case final page? when page.isLoadingMore) {
        state = .data(
          buildPageState(
            items: page.items,
            hasMore: page.hasMore,
            isLoadingMore: false,
            loadMoreError: page.loadMoreError,
          ),
        );
      }
      while (active()) {
        _missedEvent = false;
        final rows = await load(limit: pageSize, offset: 0);
        if (!active()) break;
        final _ = state;
        if (!active()) break;
        if (_missedEvent) continue;
        final items = rows?.toList() ?? <ItemT>[];
        final page = buildPageState(
          items: items,
          hasMore: items.length >= pageSize,
          isLoadingMore: false,
        );
        if (refresh) state = .data(page);
        return page;
      }
      return buildPageState(items: [], hasMore: false, isLoadingMore: false);
    } finally {
      if (active()) {
        _readingFirstPage = false;
        if (refresh && _missedEvent) {
          _missedEvent = false;
          ref.invalidateSelf();
        }
      }
    }
  }

  Future<void> refresh() {
    if (state.hasValue) {
      return _readFirstPage(refresh: true).then((_) {});
    }
    ref.invalidateSelf();
    return future.then((_) {});
  }

  Future<bool> loadMore() async {
    final operationRef = ref;
    final epoch = _epoch;
    final current = state;
    final page = current.value;
    if (!operationRef.mounted ||
        epoch != _epoch ||
        current.hasError ||
        current.isLoading ||
        _readingFirstPage ||
        page == null ||
        !page.hasMore ||
        _append != null) {
      return false;
    }

    final token = _append = Object();
    bool active() =>
        operationRef.mounted && epoch == _epoch && identical(_append, token);
    StateT? currentPage() {
      if (!active()) return null;
      final latest = state.value;
      return active() ? latest : null;
    }

    var revision = _revision;
    var offset = page.items.length;
    var limit = pageSize;
    state = .data(
      buildPageState(items: page.items, hasMore: true, isLoadingMore: true),
    );
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        if (!active()) return false;
        final rows = await load(limit: limit, offset: offset);
        final latest = currentPage();
        if (latest == null) return false;
        if (revision != _revision) {
          revision = _revision;
          offset = 0;
          limit = latest.items.length + pageSize;
          continue;
        }
        final batch = rows?.toList() ?? <ItemT>[];
        final hasMore = batch.length >= limit;
        state = .data(
          buildPageState(
            items: offset == 0 ? batch : [...latest.items, ...batch],
            hasMore: hasMore,
            isLoadingMore: false,
          ),
        );
        return hasMore;
      }
      throw StateError('Page changed during each pagination query');
    } catch (error, stack) {
      final latest = currentPage();
      if (latest == null) return false;
      logger.e('Pagination failed', error: error, stackTrace: stack);
      state = .data(
        buildPageState(
          items: latest.items,
          hasMore: true,
          isLoadingMore: false,
          loadMoreError: error,
        ),
      );
      return false;
    } finally {
      if (active()) _append = null;
    }
  }

  @visibleForOverriding
  int get pageSize => 30;

  @visibleForOverriding
  Future<Iterable<ItemT>?> load({required int limit, required int offset});

  @visibleForOverriding
  StateT buildPageState({
    required List<ItemT> items,
    required bool hasMore,
    required bool isLoadingMore,
    Object? loadMoreError,
  });
}
