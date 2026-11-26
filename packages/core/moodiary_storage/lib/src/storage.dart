import 'package:flutter/widgets.dart';

class KVNotifier<T extends Object> extends ValueNotifier<T> {
  final IKVStorage storage;
  final String key;

  final T defaultValue;

  bool _hasStoredValue;

  KVNotifier._(
    T? storedValue, {
    required this.defaultValue,
    required this.storage,
    required this.key,
  }) : _hasStoredValue = storedValue != null,
       super(storedValue ?? defaultValue);

  void _reset() => _update(storage.get<T>(key));

  void _update(T? storedValue) {
    final hasStoredValue = storedValue != null;
    final presenceChanged = hasStoredValue != _hasStoredValue;
    _hasStoredValue = hasStoredValue;
    final next = storedValue ?? defaultValue;
    if (presenceChanged && next == value) {
      notifyListeners();
    } else {
      super.value = next;
    }
  }

  @override
  set value(T newValue) {
    storage.set<T>(key, newValue);
  }

  void updateFromStorage(T newValue) {
    _update(newValue);
  }
}

abstract interface class IKVSource {
  T? get<T extends Object>(String key);
}

abstract class IKVStorage implements IKVSource {
  IKVStorage();

  final Map<String, KVNotifier> _notifiers = {};

  Future<void> init();

  @override
  T? get<T extends Object>(String key);

  @mustCallSuper
  void set<T extends Object>(String key, T value) {
    findNotifier<T>(key)?.updateFromStorage(value);
  }

  @mustCallSuper
  void remove(String key) {
    _notifiers[key]?._reset();
  }

  @mustCallSuper
  void clear() {
    for (final notifier in _notifiers.values.toList()) {
      notifier._reset();
    }
  }

  KVNotifier<T>? findNotifier<T extends Object>(String key) {
    return _notifiers[key] as KVNotifier<T>?;
  }

  KVNotifier<T> getNotifier<T extends Object>(String key, T defaultValue) {
    return _notifiers.putIfAbsent(
      key,
      () => KVNotifier<T>._(
        get<T>(key),
        defaultValue: defaultValue,
        storage: this,
        key: key,
      ),
    ) as KVNotifier<T>;
  }
}

abstract class ISecureKVStorage {
  Future<void> init();

  Future<String?> get(String key);

  Future<void> set(String key, String value);

  Future<void> remove(String key);

  Future<void> clear();
}
