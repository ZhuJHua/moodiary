import 'package:moodiary_core/moodiary_core.dart';

/// 内存 KV，把 [MoodiaryKVs] 的读写接上。
final class MemoryKVStorage extends IKVStorage {
  final Map<String, Object> data = {};

  @override
  Future<void> init() async {}

  @override
  T? get<T extends Object>(String key) => data[key] as T?;

  @override
  void set<T extends Object>(String key, T value) {
    data[key] = value;
    super.set(key, value);
  }

  @override
  void remove(String key) {
    data.remove(key);
    super.remove(key);
  }

  @override
  void clear() => data.clear();
}

/// 内存 SecureKV。[failingKeys] / [failingReads] 里的键写入 / 读取时抛，
/// 用来模拟钥匙串不可用（设备锁定、Keystore 失效）。
final class MemorySecureKVStorage implements ISecureKVStorage {
  final Map<String, String> data = {};
  final Set<String> failingKeys = {};
  final Set<String> failingReads = {};

  @override
  Future<void> init() async {}

  @override
  Future<String?> get(String key) async {
    if (failingReads.contains(key)) throw StateError('keychain unavailable');
    return data[key];
  }

  @override
  Future<void> set(String key, String value) async {
    if (failingKeys.contains(key)) throw StateError('keychain unavailable');
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async => data.remove(key);

  @override
  Future<void> clear() async => data.clear();
}

/// 只读 KV 数据源的替身（旧 SharedPreferences 仓库）。
/// [throwingKeys] 里的键读取时抛 [TypeError]，模拟历史上换过类型的那一格。
final class MemoryKVSource implements IKVSource {
  final Map<String, Object> data = {};
  final Set<String> throwingKeys = {};

  @override
  T? get<T extends Object>(String key) {
    if (throwingKeys.contains(key)) throw TypeError();
    return data[key] as T?;
  }
}
