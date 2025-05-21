import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageUtil {
  static const _storage = FlutterSecureStorage();

  static Future<void> setValue(String key, dynamic value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> getValue(String key) async {
    return await _storage.read(key: key);
  }

  static Future<void> remove(String key) async {
    await _storage.delete(key: key);
  }
}
