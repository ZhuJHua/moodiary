import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

mixin LoadMoreMixin<T> on AnyNotifier<AsyncValue<List<T>>, List<T>> {
  bool _noMore = false;

  int _epoch = 0;

  bool _missedEvent = false;

  int get _offset => state.value?.length ?? 0;

  bool get noMore => _noMore;

  void markMissedEvent() => _missedEvent = true;

  Future<List<T>> init({bool refreshFirst = false}) async {
    final operationRef = ref;
    if (refreshFirst) {
      await refresh();
    } else {
      await _load();
    }
    if (!operationRef.mounted) return <T>[];
    if (_missedEvent) {
      _missedEvent = false;
      await refresh();
      if (!operationRef.mounted) return <T>[];
    }
    return state.value ?? <T>[];
  }

  Future<void> _load({int offset = 0, bool refresh = false}) async {
    final operationRef = ref;
    final epoch = _epoch;
    try {
      if (offset > 0) {
        state = const .loading();
      }
      final items = await load(limit: pageSize, offset: offset);
      if (!operationRef.mounted || epoch != _epoch) return;
      final existing = state.value;
      if (!operationRef.mounted || epoch != _epoch) return;
      final current = refresh ? <T>[] : (existing ?? <T>[]);
      final updated = [...current, ...?items];
      _noMore = items == null || items.length < pageSize;
      if (offset > 0 || refresh || current.isEmpty) {
        state = .data(updated);
      }
    } catch (e) {
      if (!operationRef.mounted || epoch != _epoch) return;
      if (offset > 0) {
        final _ = state;
        if (!operationRef.mounted || epoch != _epoch) return;
      }
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

  Future<bool> loadMore() async {
    final operationRef = ref;
    if (!_noMore && !state.isLoading) {
      await _load(offset: _offset);
    }
    return operationRef.mounted && !_noMore;
  }

  @visibleForOverriding
  int get pageSize => 30;

  @visibleForOverriding
  Future<Iterable<T>?> load({required int limit, required int offset});
}
