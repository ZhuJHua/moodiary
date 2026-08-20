import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class FlutterSecureStorageKVStorage implements ISecureKVStorage {
  late final FlutterSecureStorage _storage;

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
