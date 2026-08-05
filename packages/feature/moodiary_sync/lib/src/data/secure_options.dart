import 'dart:convert';

import 'package:moodiary_core/moodiary_core.dart';

/// 含密钥的连接配置（S3 的 secretKey、WebDAV 的密码）存 SecureKV。
///
/// SecureKV 只收 String 且读写都是异步的，而 `isReady` / `displayName` /
/// `isConfigured()` 都是同步 getter，所以这里在进程内缓存一份：启动时 [load] 一次，
/// 之后同步读缓存，写入时同步更新缓存。
class SecureOptions {
  SecureOptions(this._key);

  final MoodiarySecureKVs _key;
  List<String> _cache = const <String>[];

  List<String> get value => _cache;

  Future<void> load() async {
    final raw = await _key.get();
    if (raw == null || raw.isEmpty) {
      _cache = const <String>[];
      return;
    }
    try {
      _cache = (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      // 存的东西不是我们写的形状（手工改过 / 换过格式），当作未配置而不是崩掉。
      _cache = const <String>[];
    }
  }

  Future<void> save(List<String> options) async {
    await _key.set(jsonEncode(options));
    _cache = options;
  }

  Future<void> clear() async {
    await _key.remove();
    _cache = const <String>[];
  }
}
