import 'package:flutter/widgets.dart';
import 'package:moodiary_di/moodiary_di.dart';

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

/// 只读 KV 数据源。存在的理由只有一个：换后端时让 [MoodiaryKVs] 能把值从旧仓库搬到新仓库，
/// 而不必让 `values/kv.dart` 知道旧仓库是什么东西（见 `storage/kv/legacy_pref.dart`）。
abstract interface class IKVSource {
  T? get<T extends Object>(String key);
}

abstract class IKVStorage implements IKVSource {
  IKVStorage();

  factory IKVStorage.get() => getIt.get();

  final Map<String, KVNotifier> _notifiers = {};

  Future<void> init();

  @override
  T? get<T extends Object>(String key);

  /// 写入是**同步**的：后端是 mmap，没有平台通道往返可等，落盘交给内核。
  /// 由此 [KVNotifier] 的监听者在赋值当帧就收到通知，不再等一个平台往返。
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

/// 机密 KV。与 [IKVStorage] 相反，这套接口保持异步：后端是系统钥匙串 /
/// Keystore，每次读写都是一次真正的平台调用。
abstract class ISecureKVStorage {
  factory ISecureKVStorage.get() => getIt.get();

  Future<void> init();

  Future<String?> get(String key);

  Future<void> set(String key, String value);

  Future<void> remove(String key);

  Future<void> clear();
}
