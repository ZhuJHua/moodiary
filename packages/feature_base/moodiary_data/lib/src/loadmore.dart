import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

mixin LoadMoreMixin<T> on AnyNotifier<AsyncValue<List<T>>, List<T>> {
  bool _noMore = false;

  int _epoch = 0;

  bool _missedEvent = false;

  int get _offset => state.value?.length ?? 0;

  bool get noMore => _noMore;

  /// 首次加载期间到达的事件无处可并（state 还没有列表值），事件回调在丢弃处
  /// 置此标记；[init] 发现有遗漏即补一次 [refresh]——丢事件退化成一次多余重查，
  /// 分页 offset 天然对齐。
  void markMissedEvent() => _missedEvent = true;

  Future<List<T>> init() async {
    await _load();
    if (_missedEvent) {
      _missedEvent = false;
      await refresh();
    }
    return state.value ?? <T>[];
  }

  Future<void> _load({int offset = 0, bool refresh = false}) async {
    final epoch = _epoch;
    try {
      if (offset > 0) {
        state = const .loading();
      }
      final items = await load(limit: pageSize, offset: offset);
      if (epoch != _epoch) return;
      final current = refresh ? <T>[] : (state.value ?? <T>[]);
      final updated = [...current, ...?items];
      _noMore = items == null || items.length < pageSize;
      if (offset > 0 || refresh || current.isEmpty) {
        state = .data(updated);
      }
    } catch (e) {
      if (epoch != _epoch) return;
      if (offset == 0) {
        rethrow;
      } else {
        state = .error(e, .current);
      }
    }
  }

  Future<void> refresh() {
    _noMore = false;
    _epoch++;
    return _load(offset: 0, refresh: true);
  }

  /// 加载下一页，返回是否（可能）还有更多；false 供刷新组件置为「没有更多」。
  Future<bool> loadMore() async {
    if (!_noMore && !state.isLoading) {
      await _load(offset: _offset);
    }
    return !_noMore;
  }

  @visibleForOverriding
  int get pageSize => 30;

  @visibleForOverriding
  Future<Iterable<T>?> load({required int limit, required int offset});
}
