import 'package:flutter/widgets.dart';

class KVNotifier<T extends Object> extends ValueNotifier<T> {
  final IKVStorage storage;
  final String key;

  KVNotifier._(super.value, {required this.storage, required this.key});

  @override
  set value(T newValue) {
    storage.set<T>(key, newValue);
  }

  void updateFromStorage(T newValue) {
    super.value = newValue;
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
    _notifiers.remove(key);
  }

  void clear();

  KVNotifier<T>? findNotifier<T extends Object>(String key) {
    return _notifiers[key] as KVNotifier<T>?;
  }

  KVNotifier<T> getNotifier<T extends Object>(String key, T defaultValue) {
    return _notifiers.putIfAbsent(
      key,
      () =>
          KVNotifier<T>._(get<T>(key) ?? defaultValue, storage: this, key: key),
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
