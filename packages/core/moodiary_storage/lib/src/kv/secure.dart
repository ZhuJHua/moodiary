import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

@Singleton(as: ISecureKVStorage)
class FlutterSecureStorageKVStorage implements ISecureKVStorage {
  late final FlutterSecureStorage _storage;

  // 清空走可重置的实例：Keystore 解不开旧密钥时普通实例连 deleteAll 都会失败
  static const FlutterSecureStorage _resettable = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  @FactoryMethod(preResolve: true)
  static Future<FlutterSecureStorageKVStorage> create() async {
    final storage = FlutterSecureStorageKVStorage();
    await storage.init();
    return storage;
  }

  @override
  Future<void> clear() {
    return _resettable.deleteAll();
  }

  @override
  Future<String?> get(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> init() async {
    // resetOnError 默认 true：Keystore 解密失败会静默清空整个仓库，连数据库密钥一起丢
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    );
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
