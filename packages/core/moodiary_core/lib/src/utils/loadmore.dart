import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

mixin LoadMoreMixin<T> on AnyNotifier<AsyncValue<List<T>>, List<T>> {
  bool _noMore = false;

  int get _offset => state.value?.length ?? 0;

  bool get noMore => _noMore;

  Future<List<T>> init() async {
    await _load();
    return state.value ?? <T>[];
  }

  Future<void> _load({int offset = 0, bool refresh = false}) async {
    try {
      if (offset > 0) {
        state = const AsyncValue.loading();
      }
      final items = await load(limit: pageSize, offset: offset);
      final current = refresh ? <T>[] : (state.value ?? <T>[]);
      final updated = [...current, ...?items];
      _noMore = items == null || items.length < pageSize;
      if (offset > 0 || refresh || current.isEmpty) {
        state = AsyncValue.data(updated);
      }
    } catch (e) {
      if (offset == 0) {
        rethrow;
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> refresh() {
    _noMore = false;
    return _load(offset: 0, refresh: true);
  }

  Future<bool> loadMore() async {
    if (!_noMore && !state.isLoading) {
      await _load(offset: _offset);
      return true;
    } else {
      return false;
    }
  }

  @visibleForOverriding
  int get pageSize => 30;

  @visibleForOverriding
  Future<Iterable<T>?> load({required int limit, required int offset});
}
