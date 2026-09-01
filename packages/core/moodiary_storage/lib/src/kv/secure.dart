import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

@Singleton(as: ISecureKVStorage)
class FlutterSecureStorageKVStorage implements ISecureKVStorage {
  late final FlutterSecureStorage _storage;

  /// [init] 只是构造 [FlutterSecureStorage]，没有 I/O，折进注册里不花时间。
  @FactoryMethod(preResolve: true)
  static Future<FlutterSecureStorageKVStorage> create() async {
    final storage = FlutterSecureStorageKVStorage();
    await storage.init();
    return storage;
  }

  @override
  Future<void> clear() {
    return _storage.deleteAll();
  }

  @override
  Future<String?> get(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> init() async {
    _storage = const FlutterSecureStorage();
  }

  @override
  Future<void> remove(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> set(String key, String value) async {
    await _storage.write(key: key, value: value);
  }
}
