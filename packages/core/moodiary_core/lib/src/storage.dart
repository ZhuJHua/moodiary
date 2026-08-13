import 'package:flutter/widgets.dart';
import 'package:moodiary_core/src/di.dart';

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

abstract class IKVStorage {
  IKVStorage();

  factory IKVStorage.get() => getIt.get();

  final Map<String, KVNotifier> _notifiers = {};

  Future<void> init();

  T? get<T extends Object>(String key);

  @mustCallSuper
  Future<void> set<T extends Object>(String key, T value) async {
    final notifier = findNotifier<T>(key);
    notifier?.updateFromStorage(value);
  }

  @mustCallSuper
  Future<void> remove(String key) async {
    _notifiers.remove(key);
  }

  Future<void> clear();

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
  factory ISecureKVStorage.get() => getIt.get();

  Future<void> init();

  Future<String?> get(String key);

  Future<void> set(String key, String value);

  Future<void> remove(String key);

  Future<void> clear();
}
