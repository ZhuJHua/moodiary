import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

mixin LoadMoreMixin<T> on AnyNotifier<AsyncValue<List<T>>, List<T>> {
  bool _noMore = false;

  int _epoch = 0;

  int get _offset => state.value?.length ?? 0;

  bool get noMore => _noMore;

  Future<List<T>> init() async {
    await _load();
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
